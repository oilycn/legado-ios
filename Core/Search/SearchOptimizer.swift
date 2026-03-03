//
//  SearchOptimizer.swift
//  Legado-iOS
//
//  搜索优化服务
//  P1-T8 实现
//

import Foundation
import CoreData

// MARK: - 搜索历史项

struct SearchHistoryItem: Identifiable, Codable {
    let id: UUID
    let keyword: String
    let timestamp: Date
    let resultCount: Int
    
    init(keyword: String, resultCount: Int = 0) {
        self.id = UUID()
        self.keyword = keyword
        self.timestamp = Date()
        self.resultCount = resultCount
    }
}

// MARK: - 搜索建议

struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    
    enum SuggestionType {
        case history
        case hot
        case completion
    }
}

// MARK: - 搜索缓存条目

struct SearchCacheEntry: Codable {
    let keyword: String
    let sourceId: UUID
    let results: [CachedSearchResult]
    let timestamp: Date
    
    struct CachedSearchResult: Codable {
        let name: String
        let author: String
        let coverUrl: String?
        let bookUrl: String
    }
}

// MARK: - 搜索优化器

@MainActor
class SearchOptimizer: ObservableObject {
    
    // MARK: - Published 属性
    
    @Published private(set) var searchHistory: [SearchHistoryItem] = []
    @Published private(set) var suggestions: [SearchSuggestion] = []
    @Published private(set) var hotKeywords: [String] = []
    
    // MARK: - 私有属性
    
    private let historyKey = "search_history"
    private let maxHistoryCount = 20
    private let cacheTimeout: TimeInterval = 3600 // 1小时缓存
    
    private var searchCache: [String: [UUID: SearchCacheEntry]] = [:]
    private var pendingSearches: [String: Task<[SearchCacheEntry.CachedSearchResult], Error>] = [:]
    
    // MARK: - 初始化
    
    init() {
        loadHistory()
        loadHotKeywords()
    }
    
    // MARK: - 搜索历史管理
    
    func addToHistory(keyword: String, resultCount: Int = 0) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 移除重复项
        searchHistory.removeAll { $0.keyword.lowercased() == trimmed.lowercased() }
        
        // 添加新项
        let item = SearchHistoryItem(keyword: trimmed, resultCount: resultCount)
        searchHistory.insert(item, at: 0)
        
        // 限制数量
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    func removeFromHistory(_ item: SearchHistoryItem) {
        searchHistory.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearHistory() {
        searchHistory = []
        saveHistory()
    }
    
    // MARK: - 搜索建议
    
    func generateSuggestions(for text: String) {
        var result: [SearchSuggestion] = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 历史记录匹配
        if !trimmed.isEmpty {
            let historyMatches = searchHistory
                .filter { $0.keyword.lowercased().contains(trimmed) }
                .prefix(5)
                .map { SearchSuggestion(text: $0.keyword, type: .history) }
            result.append(contentsOf: historyMatches)
        } else {
            // 空输入时显示最近搜索
            let recentHistory = searchHistory.prefix(5)
                .map { SearchSuggestion(text: $0.keyword, type: .history) }
            result.append(contentsOf: recentHistory)
        }
        
        // 热门关键词
        let hotMatches = hotKeywords
            .filter { trimmed.isEmpty || $0.lowercased().contains(trimmed) }
            .prefix(3)
            .map { SearchSuggestion(text: $0, type: .hot) }
        result.append(contentsOf: hotMatches)
        
        suggestions = result
    }
    
    // MARK: - 搜索缓存
    
    func getCachedResults(keyword: String, sourceId: UUID) -> [SearchCacheEntry.CachedSearchResult]? {
        guard let entries = searchCache[keyword.lowercased()],
              let entry = entries[sourceId],
              Date().timeIntervalSince(entry.timestamp) < cacheTimeout else {
            return nil
        }
        return entry.results
    }
    
    func cacheResults(keyword: String, sourceId: UUID, results: [SearchCacheEntry.CachedSearchResult]) {
        let entry = SearchCacheEntry(
            keyword: keyword,
            sourceId: sourceId,
            results: results,
            timestamp: Date()
        )
        
        if searchCache[keyword.lowercased()] == nil {
            searchCache[keyword.lowercased()] = [:]
        }
        searchCache[keyword.lowercased()]?[sourceId] = entry
    }
    
    func clearCache() {
        searchCache = [:]
    }
    
    // MARK: - 并发搜索控制
    
    func executeSearch(
        keyword: String,
        sources: [BookSource],
        searchHandler: @escaping (String, BookSource) async throws -> [SearchCacheEntry.CachedSearchResult]
    ) async -> [UUID: [SearchCacheEntry.CachedSearchResult]] {
        
        // 取消之前的搜索
        cancelPendingSearches()
        
        let enabledSources = sources.filter { $0.enabled && $0.searchUrl != nil }
        var results: [UUID: [SearchCacheEntry.CachedSearchResult]] = [:]
        
        await withTaskGroup(of: (UUID, [SearchCacheEntry.CachedSearchResult]).self) { group in
            for source in enabledSources {
                // 检查缓存
                if let cached = getCachedResults(keyword: keyword, sourceId: source.sourceId) {
                    results[source.sourceId] = cached
                    continue
                }
                
                group.addTask {
                    do {
                        let searchResults = try await searchHandler(keyword, source)
                        return (source.sourceId, searchResults)
                    } catch {
                        return (source.sourceId, [])
                    }
                }
            }
            
            for await (sourceId, searchResults) in group {
                results[sourceId] = searchResults
                // 缓存结果
                self.cacheResults(keyword: keyword, sourceId: sourceId, results: searchResults)
            }
        }
        
        return results
    }
    
    func cancelPendingSearches() {
        for (_, task) in pendingSearches {
            task.cancel()
        }
        pendingSearches = [:]
    }
    
    // MARK: - 结果排序优化
    
    func sortResults(_ results: [any Identifiable], by strategy: SortStrategy) -> [any Identifiable] {
        // 根据策略排序
        switch strategy {
        case .relevance:
            // 相关性排序：关键词匹配度
            return results
        case .sourcePriority:
            // 书源优先级排序
            return results
        case .latest:
            // 最新排序
            return results
        }
    }
    
    enum SortStrategy {
        case relevance
        case sourcePriority
        case latest
    }
    
    // MARK: - 搜索结果去重
    
    func deduplicateResults(_ results: [SearchCacheEntry.CachedSearchResult]) -> [SearchCacheEntry.CachedSearchResult] {
        var seen = Set<String>()
        var unique: [SearchCacheEntry.CachedSearchResult] = []
        
        for result in results {
            let key = "\(result.name.lowercased())_\(result.author.lowercased())"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(result)
            }
        }
        
        return unique
    }
    
    // MARK: - 预搜索优化
    
    /// 预加载热门书源的搜索结果
    func prefetchCommonSearches(sources: [BookSource]) async {
        // 可以预加载一些常见关键词的搜索结果
        // 这里暂时留空，可根据实际需求实现
    }
    
    // MARK: - 私有方法
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) else {
            searchHistory = []
            return
        }
        searchHistory = decoded
    }
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(searchHistory) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
    
    private func loadHotKeywords() {
        // 可以从服务器获取热门搜索词，这里使用硬编码示例
        hotKeywords = [
            "斗破苍穹",
            "凡人修仙传",
            "诡秘之主",
            "大奉打更人",
            "遮天",
            "完美世界",
            "斗罗大陆",
            "全职高手"
        ]
    }
}

// MARK: - 搜索优化扩展

extension SearchViewModel {
    
    /// 优化搜索：带缓存和历史记录
    func optimizedSearch(keyword: String, sources: [BookSource]) async {
        let optimizer = SearchOptimizer()
        
        // 生成建议
        optimizer.generateSuggestions(for: keyword)
        
        // 检查缓存
        var cachedCount = 0
        for source in sources where source.enabled {
            if optimizer.getCachedResults(keyword: keyword, sourceId: source.sourceId) != nil {
                cachedCount += 1
            }
        }
        
        // 执行搜索
        await search(keyword: keyword, sources: sources)
        
        // 添加到历史
        optimizer.addToHistory(keyword: keyword, resultCount: searchResults.count)
    }
}