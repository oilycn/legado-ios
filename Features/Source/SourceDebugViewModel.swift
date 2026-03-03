//
//  SourceDebugViewModel.swift
//  Legado-iOS
//
//  书源调试器 ViewModel
//  P0-T8 实现
//

import Foundation
import SwiftUI

// MARK: - 调试日志

struct DebugLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let level: LogLevel
    let message: String
    let detail: String?
    
    enum LogLevel {
        case info
        case success
        case warning
        case error
        case rule
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .rule: return "chevron.right"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .rule: return .purple
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .info: return .blue.opacity(0.1)
            case .success: return .green.opacity(0.1)
            case .warning: return .orange.opacity(0.1)
            case .error: return .red.opacity(0.1)
            case .rule: return .purple.opacity(0.1)
            }
        }
    }
}

// MARK: - 结果项

struct DebugResultItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let url: String?
    let coverUrl: String?
    let rawData: [String: String]?
}

// MARK: - ViewModel

@MainActor
class SourceDebugViewModel: ObservableObject {
    // MARK: - 输入状态
    
    @Published var debugType: DebugType = .search
    @Published var searchKeyword: String = ""
    @Published var exploreUrl: String = ""
    @Published var bookInfoUrl: String = ""
    @Published var contentUrl: String = ""
    
    // MARK: - 输出状态
    
    @Published var isExecuting: Bool = false
    @Published var errorMessage: String?
    @Published var debugLogs: [DebugLog] = []
    @Published var resultItems: [DebugResultItem] = []
    @Published var rawResponse: String?
    
    // MARK: - 书源信息
    
    private(set) var source: BookSource?
    
    var searchUrl: String? { source?.searchUrl }
    var exploreRuleSummary: String {
        guard let data = source?.ruleExploreData,
              let rule = try? JSONDecoder().decode(BookSource.ExploreRule.self, from: data) else {
            return "未配置"
        }
        return "列表: \(rule.exploreList ?? "-")\n书名: \(rule.name ?? "-")"
    }
    var contentRuleSummary: String {
        guard let data = source?.ruleContentData,
              let rule = try? JSONDecoder().decode(BookSource.ContentRule.self, from: data) else {
            return "未配置"
        }
        return "内容: \(rule.content ?? "-")"
    }
    
    // MARK: - 调试器
    
    private let debugger = RuleDebugger()
    
    // MARK: - 调试类型
    
    enum DebugType: String, CaseIterable, Identifiable {
        case search = "搜索"
        case explore = "发现"
        case bookInfo = "书籍"
        case content = "正文"
        
        var id: String { rawValue }
        
        var displayName: String { rawValue }
    }
    
    // MARK: - 初始化
    
    init(source: BookSource?) {
        self.source = source
    }
    
    // MARK: - 操作
    
    func clearResults() {
        debugLogs = []
        resultItems = []
        rawResponse = nil
        errorMessage = nil
    }
    
    func executeDebug() async {
        guard let source = source else {
            errorMessage = "未选择书源"
            return
        }
        
        clearResults()
        isExecuting = true
        
        do {
            switch debugType {
            case .search:
                try await executeSearchDebug(source: source)
            case .explore:
                try await executeExploreDebug(source: source)
            case .bookInfo:
                try await executeBookInfoDebug(source: source)
            case .content:
                try await executeContentDebug(source: source)
            }
        } catch {
            addLog(level: .error, message: "执行失败", detail: error.localizedDescription)
            errorMessage = error.localizedDescription
        }
        
        isExecuting = false
    }
    
    func executeStepByStep() async {
        guard let source = source else {
            errorMessage = "未选择书源"
            return
        }
        
        // 单步执行模式：显示每一步的规则和结果
        addLog(level: .info, message: "开始单步执行", detail: nil)
        await executeDebug()
    }
    
    func selectResultItem(_ item: DebugResultItem) {
        // 选择结果项后，将其 URL 填充到下一步调试
        switch debugType {
        case .search, .explore:
            if let url = item.url {
                bookInfoUrl = url
                debugType = .bookInfo
            }
        case .bookInfo:
            if let url = item.url {
                contentUrl = url
                debugType = .content
            }
        case .content:
            break
        }
    }
    
    // MARK: - 私有方法
    
    private func executeSearchDebug(source: BookSource) async throws {
        guard !searchKeyword.isEmpty else {
            throw DebugError.emptyKeyword
        }
        
        addLog(level: .info, message: "搜索调试开始", detail: "关键词: \(searchKeyword)")
        
        let results = try await debugger.debugSearch(
            source: source,
            keyword: searchKeyword
        ) { [weak self] log in
            self?.addLog(level: log.level, message: log.message, detail: log.detail)
        }
        
        rawResponse = results.rawResponse
        
        resultItems = results.items.map { item in
            DebugResultItem(
                title: item.name ?? "未知书名",
                subtitle: item.author ?? "未知作者",
                url: item.bookUrl,
                coverUrl: item.coverUrl,
                rawData: item.rawData
            )
        }
        
        addLog(level: .success, message: "搜索完成", detail: "找到 \(results.items.count) 条结果")
    }
    
    private func executeExploreDebug(source: BookSource) async throws {
        addLog(level: .info, message: "发现调试开始", detail: nil)
        
        let results = try await debugger.debugExplore(
            source: source,
            exploreUrl: exploreUrl.isEmpty ? nil : exploreUrl
        ) { [weak self] log in
            self?.addLog(level: log.level, message: log.message, detail: log.detail)
        }
        
        rawResponse = results.rawResponse
        
        resultItems = results.items.map { item in
            DebugResultItem(
                title: item.name ?? "未知书名",
                subtitle: item.author ?? "未知作者",
                url: item.bookUrl,
                coverUrl: item.coverUrl,
                rawData: item.rawData
            )
        }
        
        addLog(level: .success, message: "发现完成", detail: "找到 \(results.items.count) 条结果")
    }
    
    private func executeBookInfoDebug(source: BookSource) async throws {
        guard !bookInfoUrl.isEmpty else {
            throw DebugError.emptyUrl
        }
        
        addLog(level: .info, message: "书籍信息调试开始", detail: "URL: \(bookInfoUrl)")
        
        let result = try await debugger.debugBookInfo(
            source: source,
            bookUrl: bookInfoUrl
        ) { [weak self] log in
            self?.addLog(level: log.level, message: log.message, detail: log.detail)
        }
        
        rawResponse = result.rawResponse
        
        if let info = result.bookInfo {
            resultItems = [
                DebugResultItem(
                    title: info.name ?? "未知书名",
                    subtitle: info.author ?? "未知作者",
                    url: info.tocUrl ?? bookInfoUrl,
                    coverUrl: info.coverUrl,
                    rawData: info.rawData
                )
            ]
            addLog(level: .success, message: "书籍信息获取成功", detail: nil)
        }
    }
    
    private func executeContentDebug(source: BookSource) async throws {
        guard !contentUrl.isEmpty else {
            throw DebugError.emptyUrl
        }
        
        addLog(level: .info, message: "正文调试开始", detail: "URL: \(contentUrl)")
        
        let result = try await debugger.debugContent(
            source: source,
            contentUrl: contentUrl
        ) { [weak self] log in
            self?.addLog(level: log.level, message: log.message, detail: log.detail)
        }
        
        rawResponse = result.rawResponse
        
        if let content = result.content {
            resultItems = [
                DebugResultItem(
                    title: "正文内容",
                    subtitle: "\(content.count) 字符",
                    url: contentUrl,
                    coverUrl: nil,
                    rawData: ["content": content]
                )
            ]
            addLog(level: .success, message: "正文获取成功", detail: "\(content.count) 字符")
        }
    }
    
    private func addLog(level: DebugLog.LogLevel, message: String, detail: String?) {
        debugLogs.append(DebugLog(level: level, message: message, detail: detail))
    }
}

// MARK: - 错误类型

enum DebugError: LocalizedError {
    case emptyKeyword
    case emptyUrl
    case noRule
    case networkError(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyKeyword:
            return "请输入搜索关键词"
        case .emptyUrl:
            return "请输入 URL"
        case .noRule:
            return "书源缺少必要规则"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .parseError(let message):
            return "解析错误: \(message)"
        }
    }
}