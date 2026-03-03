//
//  FullTextFetcher.swift
//  Legado-iOS
//
//  RSS 全文抓取服务
//  P1-T4 实现
//

import Foundation
import SwiftSoup

// MARK: - 全文抓取结果

struct FullTextResult {
    let title: String
    let content: String
    let author: String?
    let publishDate: Date?
    let coverImage: String?
    let sourceUrl: String
}

// MARK: - 全文抓取器

class FullTextFetcher {
    
    // MARK: - 单例
    
    static let shared = FullTextFetcher()
    
    private init() {}
    
    // MARK: - 公开方法
    
    /// 从 URL 抓取全文内容
    /// - Parameters:
    ///   - url: 文章 URL
    ///   - rules: 可选的自定义提取规则
    /// - Returns: 抓取结果
    func fetchFullText(from url: String, rules: ExtractionRules? = nil) async throws -> FullTextResult {
        guard let articleUrl = URL(string: url) else {
            throw FullTextError.invalidUrl
        }
        
        // 发送请求
        var request = URLRequest(url: articleUrl)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw FullTextError.httpError
        }
        
        // 检测编码
        let encoding = detectEncoding(from: httpResponse, data: data)
        let htmlString = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) ?? ""
        
        guard !htmlString.isEmpty else {
            throw FullTextError.emptyContent
        }
        
        // 解析内容
        return try parseHtml(htmlString, url: url, rules: rules)
    }
    
    /// 批量抓取全文
    func fetchMultiple(from urls: [String]) async -> [(url: String, result: Result<FullTextResult, Error>)] {
        await withTaskGroup(of: (String, Result<FullTextResult, Error>).self) { group in
            for url in urls {
                group.addTask {
                    do {
                        let result = try await self.fetchFullText(from: url)
                        return (url, .success(result))
                    } catch {
                        return (url, .failure(error))
                    }
                }
            }
            
            var results: [(String, Result<FullTextResult, Error>)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    // MARK: - 私有方法
    
    private func detectEncoding(from response: HTTPURLResponse, data: Data) -> String.Encoding {
        // 从 Content-Type 头获取编码
        if let contentType = response.value(forHTTPHeaderField: "Content-Type") {
            if contentType.contains("charset=utf-8") || contentType.contains("charset=UTF-8") {
                return .utf8
            }
            if contentType.contains("charset=gbk") || contentType.contains("charset=GBK") {
                return .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
            }
            if contentType.contains("charset=gb2312") {
                return .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)))
            }
        }
        
        // 从 HTML meta 标签获取编码
        if let htmlPrefix = String(data: data.prefix(1024), encoding: .utf8),
           let match = htmlPrefix.range(of: "charset=[\"']?([^\"'\\s>]+)", options: .regularExpression) {
            let charset = String(htmlPrefix[match].dropFirst(8))
            if charset.lowercased() == "utf-8" { return .utf8 }
            if charset.lowercased() == "gbk" || charset.lowercased() == "gb2312" {
                return .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
            }
        }
        
        return .utf8
    }
    
    private func parseHtml(_ html: String, url: String, rules: ExtractionRules?) throws -> FullTextResult {
        let doc = try SwiftSoup.parse(html)
        
        // 提取标题
        let title = try extractTitle(doc: doc, rules: rules)
        
        // 提取正文
        let content = try extractContent(doc: doc, rules: rules)
        
        // 提取作者
        let author = try? extractAuthor(doc: doc, rules: rules)
        
        // 提取发布时间
        let publishDate = extractPublishDate(doc: doc, rules: rules)
        
        // 提取封面图片
        let coverImage = try? extractCoverImage(doc: doc, rules: rules)
        
        return FullTextResult(
            title: title,
            content: content,
            author: author,
            publishDate: publishDate,
            coverImage: coverImage,
            sourceUrl: url
        )
    }
    
    // MARK: - 标题提取
    
    private func extractTitle(doc: Document, rules: ExtractionRules?) throws -> String {
        // 优先使用自定义规则
        if let titleSelector = rules?.titleSelector {
            if let element = try doc.select(titleSelector).first() {
                return try element.text()
            }
        }
        
        // 尝试 og:title
        if let ogTitle = try? doc.select("meta[property=og:title]").attr("content"), !ogTitle.isEmpty {
            return ogTitle
        }
        
        // 尝试 <title> 标签
        if let title = try? doc.title(), !title.isEmpty {
            // 清理标题后缀（如 " - 网站名"）
            return cleanTitle(title)
        }
        
        // 尝试 h1
        if let h1 = try? doc.select("h1").first()?.text(), !h1.isEmpty {
            return h1
        }
        
        return "未知标题"
    }
    
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        let suffixes = [" - ", " | ", " _ ", " — ", "——"]
        
        for suffix in suffixes {
            if let range = cleaned.range(of: suffix) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - 正文提取
    
    private func extractContent(doc: Document, rules: ExtractionRules?) throws -> String {
        // 优先使用自定义规则
        if let contentSelector = rules?.contentSelector {
            let elements = try doc.select(contentSelector)
            if !elements.isEmpty() {
                return try extractTextFromElements(elements)
            }
        }
        
        // 尝试常见的正文选择器
        let contentSelectors = [
            "article",
            "[itemprop=articleBody]",
            ".article-content",
            ".post-content",
            ".entry-content",
            ".content",
            "#article-content",
            "#content",
            ".article-body",
            ".post-body",
            ".story-content",
            ".news-content"
        ]
        
        for selector in contentSelectors {
            let elements = try doc.select(selector)
            if !elements.isEmpty() {
                let text = try extractTextFromElements(elements)
                if text.count > 200 { // 确保内容足够长
                    return text
                }
            }
        }
        
        // 使用 Readability 算法
        return try extractUsingReadability(doc: doc)
    }
    
    private func extractTextFromElements(_ elements: Elements) throws -> String {
        var paragraphs: [String] = []
        
        for element in elements {
            // 获取所有段落
            let ps = try element.select("p")
            if !ps.isEmpty() {
                for p in ps {
                    let text = try p.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        paragraphs.append(text)
                    }
                }
            } else {
                // 没有段落标签，直接获取文本
                let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    paragraphs.append(text)
                }
            }
        }
        
        return paragraphs.joined(separator: "\n\n")
    }
    
    // MARK: - Readability 算法简化版
    
    private func extractUsingReadability(doc: Document) throws -> String {
        // 获取所有候选元素
        let candidates = try doc.select("div, article, section")
        
        var bestElement: Element?
        var bestScore = 0
        
        for candidate in candidates {
            let score = calculateContentScore(candidate)
            if score > bestScore {
                bestScore = score
                bestElement = candidate
            }
        }
        
        if let best = bestElement {
            return try extractTextFromElements(Elements([best]))
        }
        
        // 降级：返回 body 的文本
        if let body = try? doc.select("body").first() {
            return try body.text()
        }
        
        return ""
    }
    
    private func calculateContentScore(_ element: Element) -> Int {
        var score = 0
        
        // 获取类名和 ID
        let className = (try? element.className()) ?? ""
        let id = (try? element.id()) ?? ""
        let combined = (className + " " + id).lowercased()
        
        // 正向加分
        if combined.contains("content") { score += 50 }
        if combined.contains("article") { score += 50 }
        if combined.contains("post") { score += 30 }
        if combined.contains("story") { score += 30 }
        if combined.contains("entry") { score += 30 }
        
        // 负向扣分
        if combined.contains("comment") { score -= 50 }
        if combined.contains("sidebar") { score -= 50 }
        if combined.contains("footer") { score -= 30 }
        if combined.contains("header") { score -= 30 }
        if combined.contains("nav") { score -= 30 }
        if combined.contains("ad") { score -= 30 }
        if combined.contains("advertisement") { score -= 50 }
        
        // 段落数量加分
        if let pCount = try? element.select("p").count, pCount > 3 {
            score += pCount * 5
        }
        
        // 文本长度加分
        if let text = try? element.text(), text.count > 200 {
            score += min(text.count / 10, 100)
        }
        
        return score
    }
    
    // MARK: - 作者提取
    
    private func extractAuthor(doc: Document, rules: ExtractionRules?) throws -> String? {
        if let authorSelector = rules?.authorSelector {
            if let author = try? doc.select(authorSelector).first()?.text() {
                return author
            }
        }
        
        // 尝试 meta 标签
        let authorSelectors = [
            "meta[name=author]",
            "meta[property=article:author]",
            "[itemprop=author]",
            ".author",
            ".post-author"
        ]
        
        for selector in authorSelectors {
            if let element = try? doc.select(selector).first() {
                if selector.hasPrefix("meta") {
                    return try? element.attr("content")
                } else {
                    return try? element.text()
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 发布时间提取
    
    private func extractPublishDate(doc: Document, rules: ExtractionRules?) -> Date? {
        if let dateSelector = rules?.dateSelector {
            if let dateStr = try? doc.select(dateSelector).first()?.text() {
                return parseDate(dateStr)
            }
        }
        
        // 尝试 meta 标签
        let dateSelectors = [
            "meta[property=article:published_time]",
            "meta[name=pubdate]",
            "meta[name=publishdate]",
            "meta[name=date]",
            "time[datetime]",
            "[itemprop=datePublished]"
        ]
        
        for selector in dateSelectors {
            if let element = try? doc.select(selector).first() {
                let dateStr = selector.hasPrefix("meta") ? (try? element.attr("content")) : (try? element.attr("datetime"))
                if let str = dateStr ?? (try? element.text()), let date = parseDate(str) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatters: [DateFormatter] = {
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd HH:mm:ss",
                "yyyy-MM-dd",
                "EEE, dd MMM yyyy HH:mm:ss Z"
            ]
            
            return formats.map { format in
                let f = DateFormatter()
                f.dateFormat = format
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }
        }()
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString.trimmingCharacters(in: .whitespaces)) {
                return date
            }
        }
        
        return nil
    }
    
    // MARK: - 封面图片提取
    
    private func extractCoverImage(doc: Document, rules: ExtractionRules?) throws -> String? {
        if let imageSelector = rules?.imageSelector {
            if let src = try? doc.select(imageSelector).first()?.attr("src") {
                return src
            }
        }
        
        // 尝试 og:image
        if let ogImage = try? doc.select("meta[property=og:image]").attr("content"), !ogImage.isEmpty {
            return ogImage
        }
        
        // 尝试 article:image
        if let articleImage = try? doc.select("meta[property=article:image]").attr("content"), !articleImage.isEmpty {
            return articleImage
        }
        
        // 尝试第一个图片
        if let firstImage = try? doc.select("article img, .content img, .post-content img").first()?.attr("src") {
            return firstImage
        }
        
        return nil
    }
}

// MARK: - 提取规则

struct ExtractionRules {
    var titleSelector: String?
    var contentSelector: String?
    var authorSelector: String?
    var dateSelector: String?
    var imageSelector: String?
    
    static let `default` = ExtractionRules()
}

// MARK: - 错误类型

enum FullTextError: LocalizedError {
    case invalidUrl
    case httpError
    case emptyContent
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl: return "无效的 URL"
        case .httpError: return "HTTP 请求失败"
        case .emptyContent: return "内容为空"
        case .parseError(let msg): return "解析错误：\(msg)"
        }
    }
}