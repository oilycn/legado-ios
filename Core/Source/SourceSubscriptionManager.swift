//
//  SourceSubscriptionManager.swift
//  Legado-iOS
//
//  书源订阅管理器 - 支持从网络订阅源自动更新书源
//  P2-T5 实现
//

import Foundation
import CoreData

// MARK: - 书源订阅配置

struct SourceSubscription: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var lastUpdateTime: Date?
    var autoUpdate: Bool
    var updateInterval: TimeInterval // 秒
    var enabled: Bool
    
    init(name: String, url: String, autoUpdate: Bool = true, updateInterval: TimeInterval = 86400) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.lastUpdateTime = nil
        self.autoUpdate = autoUpdate
        self.updateInterval = updateInterval
        self.enabled = true
    }
}

// MARK: - 书源订阅管理器

@MainActor
class SourceSubscriptionManager: ObservableObject {
    
    // MARK: - Published 属性
    
    @Published private(set) var subscriptions: [SourceSubscription] = []
    @Published var isUpdating = false
    @Published var lastUpdateError: String?
    @Published var updateProgress: Double = 0
    
    // MARK: - 私有属性
    
    private let subscriptionsKey = "source_subscriptions"
    private let lastUpdateKey = "source_subscription_last_update"
    
    // MARK: - 初始化
    
    init() {
        loadSubscriptions()
    }
    
    // MARK: - 公开方法
    
    /// 添加订阅
    func addSubscription(name: String, url: String, autoUpdate: Bool = true) {
        let subscription = SourceSubscription(name: name, url: url, autoUpdate: autoUpdate)
        subscriptions.append(subscription)
        saveSubscriptions()
    }
    
    /// 删除订阅
    func removeSubscription(at index: Int) {
        guard subscriptions.indices.contains(index) else { return }
        subscriptions.remove(at: index)
        saveSubscriptions()
    }
    
    /// 删除订阅（通过 ID）
    func removeSubscription(id: UUID) {
        subscriptions.removeAll { $0.id == id }
        saveSubscriptions()
    }
    
    /// 更新订阅
    func updateSubscription(_ subscription: SourceSubscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
            saveSubscriptions()
        }
    }
    
    /// 检查订阅是否需要更新
    func needsUpdate(_ subscription: SourceSubscription) -> Bool {
        guard subscription.autoUpdate else { return false }
        
        guard let lastUpdate = subscription.lastUpdateTime else {
            return true
        }
        
        return Date().timeIntervalSince(lastUpdate) > subscription.updateInterval
    }
    
    /// 更新单个订阅
    func updateSubscription(id: UUID) async throws {
        guard let subscription = subscriptions.first(where: { $0.id == id }) else {
            throw SubscriptionError.subscriptionNotFound
        }
        
        try await updateFromSubscription(subscription)
    }
    
    /// 更新所有需要更新的订阅
    func updateAllSubscriptions() async {
        guard !isUpdating else { return }
        
        isUpdating = true
        updateProgress = 0
        lastUpdateError = nil
        
        let total = Double(subscriptions.filter { $0.enabled && needsUpdate($0) }.count)
        var completed = 0.0
        
        for subscription in subscriptions where subscription.enabled && needsUpdate(subscription) {
            do {
                try await updateFromSubscription(subscription)
            } catch {
                print("订阅更新失败 [\(subscription.name)]: \(error)")
            }
            
            completed += 1
            updateProgress = completed / total
        }
        
        isUpdating = false
        updateProgress = 1.0
        
        // 记录最后更新时间
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
    }
    
    /// 从订阅 URL 导入书源
    func importFromUrl(_ url: String) async throws -> Int {
        let sources = try await fetchSources(from: url)
        try await importSources(sources)
        return sources.count
    }
    
    /// 导出书源为订阅格式
    func exportSourcesAsSubscription(sources: [BookSource], format: ExportFormat = .json) -> Data? {
        let exportSources = sources.map { ExportableSource(from: $0) }
        
        switch format {
        case .json:
            return try? JSONEncoder().encode(exportSources)
        case .jsonLines:
            let lines = exportSources.compactMap { try? JSONEncoder().encode($0) }
            let combined = lines.map { String(data: $0, encoding: .utf8) ?? "" }.joined(separator: "\n")
            return combined.data(using: .utf8)
        }
    }
    
    // MARK: - 私有方法
    
    private func updateFromSubscription(_ subscription: SourceSubscription) async throws {
        let sources = try await fetchSources(from: subscription.url)
        try await importSources(sources)
        
        // 更新订阅的最后更新时间
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index].lastUpdateTime = Date()
            saveSubscriptions()
        }
    }
    
    private func fetchSources(from urlString: String) async throws -> [ExportableSource] {
        guard let url = URL(string: urlString) else {
            throw SubscriptionError.invalidUrl
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw SubscriptionError.networkError
        }
        
        // 尝试解析为 JSON 数组
        if let sources = try? JSONDecoder().decode([ExportableSource].self, from: data) {
            return sources
        }
        
        // 尝试解析为 JSON Lines 格式
        var sources: [ExportableSource] = []
        let lines = String(data: data, encoding: .utf8)?.components(separatedBy: .newlines) ?? []
        
        for line in lines {
            guard !line.isEmpty, let lineData = line.data(using: .utf8) else { continue }
            if let source = try? JSONDecoder().decode(ExportableSource.self, from: lineData) {
                sources.append(source)
            }
        }
        
        if sources.isEmpty {
            throw SubscriptionError.parseError
        }
        
        return sources
    }
    
    private func importSources(_ sources: [ExportableSource]) async throws {
        let context = CoreDataStack.shared.viewContext
        
        for source in sources {
            // 检查是否已存在
            let request = BookSource.fetchRequest()
            request.predicate = NSPredicate(format: "bookSourceUrl == %@", source.bookSourceUrl)
            
            let existing = try? context.fetch(request)
            
            if let existing = existing?.first {
                // 更新现有书源
                updateBookSource(existing, with: source)
            } else {
                // 创建新书源
                let newSource = BookSource.create(in: context)
                updateBookSource(newSource, with: source)
            }
        }
        
        try CoreDataStack.shared.save()
    }
    
    private func updateBookSource(_ bookSource: BookSource, with source: ExportableSource) {
        bookSource.bookSourceUrl = source.bookSourceUrl
        bookSource.bookSourceName = source.bookSourceName
        bookSource.bookSourceGroup = source.bookSourceGroup
        bookSource.bookSourceType = Int32(source.bookSourceType ?? 0)
        bookSource.bookUrlPattern = source.bookUrlPattern
        bookSource.header = source.header
        bookSource.concurrentRate = source.concurrentRate
        bookSource.loginUrl = source.loginUrl
        bookSource.searchUrl = source.searchUrl
        bookSource.exploreUrl = source.exploreUrl
        bookSource.enabled = source.enabled ?? true
        bookSource.enabledExplore = source.enabledExplore ?? true
        bookSource.weight = Int32(source.weight ?? 0)
        bookSource.lastUpdateTime = Int64(Date().timeIntervalSince1970)
        
        // 规则数据
        if let searchRule = source.ruleSearch {
            bookSource.ruleSearchData = try? JSONEncoder().encode(searchRule)
        }
        
        if let exploreRule = source.ruleExplore {
            bookSource.ruleExploreData = try? JSONEncoder().encode(exploreRule)
        }
        
        if let bookInfoRule = source.ruleBookInfo {
            bookSource.ruleBookInfoData = try? JSONEncoder().encode(bookInfoRule)
        }
        
        if let tocRule = source.ruleToc {
            bookSource.ruleTocData = try? JSONEncoder().encode(tocRule)
        }
        
        if let contentRule = source.ruleContent {
            bookSource.ruleContentData = try? JSONEncoder().encode(contentRule)
        }
    }
    
    private func loadSubscriptions() {
        guard let data = UserDefaults.standard.data(forKey: subscriptionsKey),
              let decoded = try? JSONDecoder().decode([SourceSubscription].self, from: data) else {
            subscriptions = []
            return
        }
        subscriptions = decoded
    }
    
    private func saveSubscriptions() {
        guard let data = try? JSONEncoder().encode(subscriptions) else { return }
        UserDefaults.standard.set(data, forKey: subscriptionsKey)
    }
}

// MARK: - 可导出书源

struct ExportableSource: Codable {
    let bookSourceUrl: String
    let bookSourceName: String
    var bookSourceGroup: String?
    var bookSourceType: Int?
    var bookUrlPattern: String?
    var header: String?
    var concurrentRate: String?
    var loginUrl: String?
    var searchUrl: String?
    var exploreUrl: String?
    var enabled: Bool?
    var enabledExplore: Bool?
    var weight: Int?
    
    var ruleSearch: BookSource.SearchRule?
    var ruleExplore: BookSource.ExploreRule?
    var ruleBookInfo: BookSource.BookInfoRule?
    var ruleToc: BookSource.TocRule?
    var ruleContent: BookSource.ContentRule?
    
    init(from source: BookSource) {
        self.bookSourceUrl = source.bookSourceUrl
        self.bookSourceName = source.bookSourceName
        self.bookSourceGroup = source.bookSourceGroup
        self.bookSourceType = Int(source.bookSourceType)
        self.bookUrlPattern = source.bookUrlPattern
        self.header = source.header
        self.concurrentRate = source.concurrentRate
        self.loginUrl = source.loginUrl
        self.searchUrl = source.searchUrl
        self.exploreUrl = source.exploreUrl
        self.enabled = source.enabled
        self.enabledExplore = source.enabledExplore
        self.weight = Int(source.weight)
        
        self.ruleSearch = try? source.ruleSearchData.flatMap { try JSONDecoder().decode(BookSource.SearchRule.self, from: $0) }
        self.ruleExplore = try? source.ruleExploreData.flatMap { try JSONDecoder().decode(BookSource.ExploreRule.self, from: $0) }
        self.ruleBookInfo = try? source.ruleBookInfoData.flatMap { try JSONDecoder().decode(BookSource.BookInfoRule.self, from: $0) }
        self.ruleToc = try? source.ruleTocData.flatMap { try JSONDecoder().decode(BookSource.TocRule.self, from: $0) }
        self.ruleContent = try? source.ruleContentData.flatMap { try JSONDecoder().decode(BookSource.ContentRule.self, from: $0) }
    }
}

// MARK: - 导出格式

enum ExportFormat {
    case json
    case jsonLines
}

// MARK: - 错误类型

enum SubscriptionError: LocalizedError {
    case invalidUrl
    case networkError
    case parseError
    case subscriptionNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl: return "无效的订阅 URL"
        case .networkError: return "网络请求失败"
        case .parseError: return "解析书源失败"
        case .subscriptionNotFound: return "订阅不存在"
        }
    }
}