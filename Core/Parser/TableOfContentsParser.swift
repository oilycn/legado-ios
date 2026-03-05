//
//  TableOfContentsParser.swift
//  Legado-iOS
//
//  目录解析器
//

import Foundation
import CoreData

// MARK: - 目录规则结构体
struct RuleToc: Codable {
    var chapterList: String?
    var chapterName: String?
    var chapterUrl: String?
    var nextTocUrl: String?
    var updateTime: String?
}

// MARK: - 规则解析器占位
class RuleParser {
    static func parse(html: String, rule: String) throws -> String {
        // 简化实现：返回原始HTML或按规则提取
        if rule.isEmpty {
            return html
        }
        // TODO: 实现完整的规则解析
        return html
    }
}

/// 目录解析器
class TableOfContentsParser {

    
    struct ChapterInfo {
        let title: String
        let url: String
        let index: Int
    }
    
    /// 从书源解析目录
    static func parse(from html: String, ruleToc: RuleToc) async throws -> [ChapterInfo] {
        var chapters: [ChapterInfo] = []
        
        // 1. 提取章节列表 HTML
        let listHTML: String
        if let chapterList = ruleToc.chapterList,
           !chapterList.isEmpty,
           let extracted = try? RuleParser.parse(html: html, rule: chapterList) {
            listHTML = extracted
        } else {
            listHTML = html
        }
        
        // 2. 提取所有章节链接
        let chapterElements = extractChapterElements(from: listHTML, rule: ruleToc)
        
        // 3. 解析每个章节
        for (index, element) in chapterElements.enumerated() {
            if let chapter = parseChapter(from: element, rule: ruleToc, index: index) {
                chapters.append(chapter)
            }
        }
        
        return chapters
    }
    
    /// 提取章节元素列表
    private static func extractChapterElements(from html: String, rule: RuleToc) -> [String] {
        var elements: [String] = []
        
        // 使用 chapterList 规则或默认的 <a> 标签
        let pattern: String
        if let listRule = rule.chapterList, !listRule.isEmpty {
            // 自定义列表规则
            pattern = "<[^>]+>.*?</[^>]+>"
        } else {
            // 默认提取所有 <a> 标签
            pattern = #"<a[^>]*href="[^"]*"[^>]*>[^<]*</a>"#
        }
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return elements
        }
        
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        
        for match in matches {
            if let range = Range(match.range, in: html) {
                elements.append(String(html[range]))
            }
        }
        
        return elements
    }
    
    /// 解析单个章节
    private static func parseChapter(from element: String, rule: RuleToc, index: Int) -> ChapterInfo? {
        // 提取 URL
        let urlPattern = #"href="([^"]+)""#
        guard let url = extractFirstMatch(in: element, pattern: urlPattern) else {
            return nil
        }
        
        // 提取标题
        let title: String
        if let nameRule = rule.chapterName,
           !nameRule.isEmpty,
           let extracted = try? RuleParser.parse(html: element, rule: nameRule) {
            title = extracted
        } else {
            // 默认提取标签内容
            title = extractFirstMatch(in: element, pattern: #">([^<]+)<"#) ?? "第\(index + 1)章"
        }
        
        return ChapterInfo(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url,
            index: index
        )
    }
    
    /// 解析下一页 URL
    static func parseNextPageURL(from html: String, rule: RuleToc, baseURL: String) -> String? {
        guard let nextPageRule = rule.nextTocUrl,
              !nextPageRule.isEmpty,
              let nextURL = try? RuleParser.parse(html: html, rule: nextPageRule) else {
            return nil
        }
        
        return resolveURL(baseURL: baseURL, relativeURL: nextURL)
    }
    
    /// 解析章节更新时间
    static func parseUpdateTime(from html: String, rule: RuleToc) -> Date? {
        guard let updateRule = rule.updateTime,
              !updateRule.isEmpty,
              let timeString = try? RuleParser.parse(html: html, rule: updateRule) else {
            return nil
        }
        
        // 尝试多种日期格式
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MM-dd HH:mm",
            "yyyy年MM月dd日"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: timeString) {
                return date
            }
        }
        
        return nil
    }
    
    // MARK: - 辅助方法
    
    private static func extractFirstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
    
    private static func resolveURL(baseURL: String, relativeURL: String) -> String {
        if relativeURL.hasPrefix("http") {
            return relativeURL
        }
        
        guard let base = URL(string: baseURL) else {
            return relativeURL
        }
        
        return URL(string: relativeURL, relativeTo: base)?.absoluteString ?? relativeURL
    }
}

// MARK: - 目录获取服务
class TableOfContentsService {
    
    static let shared = TableOfContentsService()
    
    /// 获取书籍目录
    func fetchTableOfContents(book: Book, source: BookSource) async throws -> [BookChapter] {
        // 1. 检查本地缓存
        let cachedChapters = try await loadCachedChapters(book: book)
        if !cachedChapters.isEmpty {
            return cachedChapters
        }
        
        // 2. 从书源获取
        let tocURL = book.tocUrl
        guard let ruleTocData = source.ruleTocData,
              let ruleToc = try? JSONDecoder().decode(RuleToc.self, from: ruleTocData) else {
            throw ReaderError.noSource
        }
        
        // 3. 解析目录页面
        let chapters = try await parseTOCPage(url: tocURL, ruleToc: ruleToc, source: source)
        
        // 4. 保存到 CoreData
        try await saveChapters(chapters, book: book)
        
        // 5. 返回保存后的章节
        return try await loadCachedChapters(book: book)
    }
    
    /// 解析目录页面（支持分页）
    private func parseTOCPage(url: String, ruleToc: RuleToc, source: BookSource, accumulated: [TableOfContentsParser.ChapterInfo] = []) async throws -> [TableOfContentsParser.ChapterInfo] {
        guard let tocURL = URL(string: url) else {
            throw ReaderError.networkFailure
        }
        
        // 下载页面
        let (data, _) = try await URLSession.shared.data(from: tocURL)
        guard let html = String(data: data, encoding: .utf8) else {
            throw ReaderError.parseFailed("无法解码页面")
        }
        
        // 解析当前页目录
        var chapters = try await TableOfContentsParser.parse(from: html, ruleToc: ruleToc)
        
        // 合并之前页的结果
        let startIndex = accumulated.count
        chapters = chapters.map { chapterInfo in
            TableOfContentsParser.ChapterInfo(
                title: chapterInfo.title,
                url: chapterInfo.url,
                index: chapterInfo.index + startIndex
            )
        }
        
        var allChapters = accumulated + chapters
        
        // 检查是否有下一页
        if let nextPageURL = TableOfContentsParser.parseNextPageURL(from: html, rule: ruleToc, baseURL: url) {
            // 递归获取下一页
            allChapters = try await parseTOCPage(
                url: nextPageURL,
                ruleToc: ruleToc,
                source: source,
                accumulated: allChapters
            )
        }
        
        return allChapters
    }
    
    /// 加载本地缓存的目录
    private func loadCachedChapters(book: Book) async throws -> [BookChapter] {
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BookChapter.index, ascending: true)]
        
        return try CoreDataStack.shared.viewContext.fetch(request)
    }
    
    /// 保存章节到 CoreData
    private func saveChapters(_ chapters: [TableOfContentsParser.ChapterInfo], book: Book) async throws {
        let context = CoreDataStack.shared.viewContext
        
        // 删除旧章节
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        let oldChapters = try context.fetch(request)
        oldChapters.forEach { context.delete($0) }
        
        // 创建新章节
        for info in chapters {
            let chapter = BookChapter(context: context)
            chapter.chapterId = UUID()
            chapter.bookId = book.bookId
            chapter.index = Int32(info.index)
            chapter.title = info.title
            chapter.chapterUrl = info.url
            chapter.isVIP = false
            chapter.isPay = false
            chapter.wordCount = 0
            chapter.updateTime = 0
            chapter.isCached = false
        }
        
        // 更新书籍信息
        book.totalChapterNum = Int32(chapters.count)
        book.tocUrl = chapters.first?.url ?? book.tocUrl
        
        try CoreDataStack.shared.save()
    }
    
    /// 刷新目录
    func refreshTableOfContents(book: Book, source: BookSource) async throws -> [BookChapter] {
        // 清除缓存
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        let chapters = try CoreDataStack.shared.viewContext.fetch(request)
        chapters.forEach { CoreDataStack.shared.viewContext.delete($0) }
        try CoreDataStack.shared.save()
        
        // 重新获取
        return try await fetchTableOfContents(book: book, source: source)
    }
}

// MARK: - 阅读器错误类型
enum ReaderError: LocalizedError {
    case noSource
    case networkFailure
    case parseFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noSource: return "书源不可用"
        case .networkFailure: return "网络请求失败"
        case .parseFailed(let reason): return "解析失败：\(reason)"
        }
    }
}
