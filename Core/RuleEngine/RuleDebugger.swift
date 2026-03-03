//
//  RuleDebugger.swift
//  Legado-iOS
//
//  规则调试器：执行书源规则并返回调试信息
//  P0-T8 实现
//

import Foundation

// MARK: - 调试回调

struct DebugLogEntry {
    let level: DebugLog.LogLevel
    let message: String
    let detail: String?
}

typealias DebugLogHandler = (DebugLogEntry) -> Void

// MARK: - 调试结果

struct DebugSearchResult {
    let items: [DebugBookItem]
    let rawResponse: String?
}

struct DebugExploreResult {
    let items: [DebugBookItem]
    let rawResponse: String?
}

struct DebugBookInfoResult {
    let bookInfo: DebugBookInfo?
    let rawResponse: String?
}

struct DebugContentResult {
    let content: String?
    let rawResponse: String?
}

// MARK: - 数据模型

struct DebugBookItem {
    let name: String?
    let author: String?
    let bookUrl: String?
    let coverUrl: String?
    let intro: String?
    let rawData: [String: String]?
}

struct DebugBookInfo {
    let name: String?
    let author: String?
    let coverUrl: String?
    let intro: String?
    let tocUrl: String?
    let lastChapter: String?
    let rawData: [String: String]?
}

// MARK: - 规则调试器

class RuleDebugger {
    
    private let httpClient = HTTPClient.shared
    private let ruleEngine = RuleEngine()
    
    // MARK: - 搜索调试
    
    func debugSearch(
        source: BookSource,
        keyword: String,
        logHandler: @escaping DebugLogHandler
    ) async throws -> DebugSearchResult {
        guard let searchUrl = source.searchUrl else {
            throw DebugError.noRule
        }
        
        // 1. 构建 URL
        logHandler(DebugLogEntry(level: .rule, message: "构建搜索 URL", detail: searchUrl))
        
        let renderedUrl = try renderUrl(searchUrl, source: source, keyword: keyword)
        logHandler(DebugLogEntry(level: .info, message: "渲染后 URL", detail: renderedUrl))
        
        // 2. 发送请求
        logHandler(DebugLogEntry(level: .info, message: "发送请求...", detail: nil))
        
        let (html, _) = try await httpClient.getHtml(urlString: renderedUrl)
        
        let rawResponse = String(html.prefix(5000))
        logHandler(DebugLogEntry(level: .success, message: "响应成功", detail: "\(html.count) 字符"))
        
        // 3. 解析搜索规则
        guard let ruleData = source.ruleSearchData else {
            logHandler(DebugLogEntry(level: .warning, message: "无搜索规则", detail: nil))
            return DebugSearchResult(items: [], rawResponse: rawResponse)
        }
        
        let searchRule = try JSONDecoder().decode(BookSource.SearchRule.self, from: ruleData)
        
        // 4. 执行规则
        let items = try executeSearchRule(
            html: html,
            rule: searchRule,
            baseUrl: source.bookSourceUrl,
            logHandler: logHandler
        )
        
        return DebugSearchResult(items: items, rawResponse: rawResponse)
    }
    
    // MARK: - 发现调试
    
    func debugExplore(
        source: BookSource,
        exploreUrl: String?,
        logHandler: @escaping DebugLogHandler
    ) async throws -> DebugExploreResult {
        let url = exploreUrl ?? source.exploreUrl
        
        guard let url = url, !url.isEmpty else {
            throw DebugError.emptyUrl
        }
        
        logHandler(DebugLogEntry(level: .rule, message: "发现 URL", detail: url))
        
        let (html, _) = try await httpClient.getHtml(urlString: url)
        
        let rawResponse = String(html.prefix(5000))
        logHandler(DebugLogEntry(level: .success, message: "响应成功", detail: "\(html.count) 字符"))
        
        guard let ruleData = source.ruleExploreData else {
            return DebugExploreResult(items: [], rawResponse: rawResponse)
        }
        
        let exploreRule = try JSONDecoder().decode(BookSource.ExploreRule.self, from: ruleData)
        
        let items = try executeExploreRule(
            html: html,
            rule: exploreRule,
            baseUrl: source.bookSourceUrl,
            logHandler: logHandler
        )
        
        return DebugExploreResult(items: items, rawResponse: rawResponse)
    }
    
    // MARK: - 书籍信息调试
    
    func debugBookInfo(
        source: BookSource,
        bookUrl: String,
        logHandler: @escaping DebugLogHandler
    ) async throws -> DebugBookInfoResult {
        logHandler(DebugLogEntry(level: .rule, message: "书籍 URL", detail: bookUrl))
        
        let (html, _) = try await httpClient.getHtml(urlString: bookUrl)
        
        let rawResponse = String(html.prefix(5000))
        logHandler(DebugLogEntry(level: .success, message: "响应成功", detail: "\(html.count) 字符"))
        
        guard let ruleData = source.ruleBookInfoData else {
            return DebugBookInfoResult(bookInfo: nil, rawResponse: rawResponse)
        }
        
        let bookInfoRule = try JSONDecoder().decode(BookSource.BookInfoRule.self, from: ruleData)
        
        let info = try executeBookInfoRule(
            html: html,
            rule: bookInfoRule,
            baseUrl: source.bookSourceUrl,
            logHandler: logHandler
        )
        
        return DebugBookInfoResult(bookInfo: info, rawResponse: rawResponse)
    }
    
    // MARK: - 正文调试
    
    func debugContent(
        source: BookSource,
        contentUrl: String,
        logHandler: @escaping DebugLogHandler
    ) async throws -> DebugContentResult {
        logHandler(DebugLogEntry(level: .rule, message: "章节 URL", detail: contentUrl))
        
        let (html, _) = try await httpClient.getHtml(urlString: contentUrl)
        
        let rawResponse = String(html.prefix(5000))
        logHandler(DebugLogEntry(level: .success, message: "响应成功", detail: "\(html.count) 字符"))
        
        guard let ruleData = source.ruleContentData else {
            return DebugContentResult(content: nil, rawResponse: rawResponse)
        }
        
        let contentRule = try JSONDecoder().decode(BookSource.ContentRule.self, from: ruleData)
        
        let content = try executeContentRule(
            html: html,
            rule: contentRule,
            logHandler: logHandler
        )
        
        return DebugContentResult(content: content, rawResponse: rawResponse)
    }
    
    // MARK: - 规则执行
    
    private func executeSearchRule(
        html: String,
        rule: BookSource.SearchRule,
        baseUrl: String,
        logHandler: DebugLogHandler
    ) throws -> [DebugBookItem] {
        var items: [DebugBookItem] = []
        
        // 执行列表规则
        logHandler(DebugLogEntry(level: .rule, message: "执行列表规则", detail: rule.bookList))
        
        let context = ExecutionContext()
        context.document = html
        context.baseURL = URL(string: baseUrl)
        
        guard let bookListRule = rule.bookList, !bookListRule.isEmpty else {
            logHandler(DebugLogEntry(level: .warning, message: "列表规则为空", detail: nil))
            return items
        }
        
        let listResult = try ruleEngine.executeSingle(rule: bookListRule, context: context)
        
        guard case .list(let elements) = listResult else {
            logHandler(DebugLogEntry(level: .warning, message: "列表规则未返回列表", detail: nil))
            return items
        }
        
        logHandler(DebugLogEntry(level: .success, message: "找到 \(elements.count) 个列表项", detail: nil))
        
        // 解析每个列表项
        for (index, element) in elements.enumerated() {
            let itemContext = ExecutionContext()
            itemContext.document = element
            itemContext.baseURL = URL(string: baseUrl)
            
            var itemData: [String: String] = [:]
            
            // 书名
            if let nameRule = rule.name, !nameRule.isEmpty {
                let nameResult = try? ruleEngine.executeSingle(rule: nameRule, context: itemContext)
                itemData["name"] = nameResult?.string
            }
            
            // 作者
            if let authorRule = rule.author, !authorRule.isEmpty {
                let authorResult = try? ruleEngine.executeSingle(rule: authorRule, context: itemContext)
                itemData["author"] = authorResult?.string
            }
            
            // 书籍 URL
            if let bookUrlRule = rule.bookUrl, !bookUrlRule.isEmpty {
                let urlResult = try? ruleEngine.executeSingle(rule: bookUrlRule, context: itemContext)
                itemData["bookUrl"] = urlResult?.string
            }
            
            // 封面
            if let coverRule = rule.coverUrl, !coverRule.isEmpty {
                let coverResult = try? ruleEngine.executeSingle(rule: coverRule, context: itemContext)
                itemData["coverUrl"] = coverResult?.string
            }
            
            // 简介
            if let introRule = rule.intro, !introRule.isEmpty {
                let introResult = try? ruleEngine.executeSingle(rule: introRule, context: itemContext)
                itemData["intro"] = introResult?.string
            }
            
            let item = DebugBookItem(
                name: itemData["name"],
                author: itemData["author"],
                bookUrl: itemData["bookUrl"],
                coverUrl: itemData["coverUrl"],
                intro: itemData["intro"],
                rawData: itemData
            )
            
            items.append(item)
            
            if index < 3 {
                logHandler(DebugLogEntry(
                    level: .info,
                    message: "结果 #\(index + 1)",
                    detail: "\(item.name ?? "-") - \(item.author ?? "-")"
                ))
            }
        }
        
        return items
    }
    
    private func executeExploreRule(
        html: String,
        rule: BookSource.ExploreRule,
        baseUrl: String,
        logHandler: DebugLogHandler
    ) throws -> [DebugBookItem] {
        var items: [DebugBookItem] = []
        
        logHandler(DebugLogEntry(level: .rule, message: "执行发现列表规则", detail: rule.exploreList))
        
        let context = ExecutionContext()
        context.document = html
        context.baseURL = URL(string: baseUrl)
        
        guard let exploreListRule = rule.exploreList, !exploreListRule.isEmpty else {
            return items
        }
        
        let listResult = try ruleEngine.executeSingle(rule: exploreListRule, context: context)
        
        guard case .list(let elements) = listResult else {
            return items
        }
        
        logHandler(DebugLogEntry(level: .success, message: "找到 \(elements.count) 个列表项", detail: nil))
        
        for element in elements {
            let itemContext = ExecutionContext()
            itemContext.document = element
            itemContext.baseURL = URL(string: baseUrl)
            
            var itemData: [String: String] = [:]
            
            if let nameRule = rule.name, !nameRule.isEmpty {
                itemData["name"] = try? ruleEngine.executeSingle(rule: nameRule, context: itemContext).string
            }
            
            if let authorRule = rule.author, !authorRule.isEmpty {
                itemData["author"] = try? ruleEngine.executeSingle(rule: authorRule, context: itemContext).string
            }
            
            if let bookUrlRule = rule.bookUrl, !bookUrlRule.isEmpty {
                itemData["bookUrl"] = try? ruleEngine.executeSingle(rule: bookUrlRule, context: itemContext).string
            }
            
            items.append(DebugBookItem(
                name: itemData["name"],
                author: itemData["author"],
                bookUrl: itemData["bookUrl"],
                coverUrl: nil,
                intro: nil,
                rawData: itemData
            ))
        }
        
        return items
    }
    
    private func executeBookInfoRule(
        html: String,
        rule: BookSource.BookInfoRule,
        baseUrl: String,
        logHandler: DebugLogHandler
    ) throws -> DebugBookInfo {
        let context = ExecutionContext()
        context.document = html
        context.baseURL = URL(string: baseUrl)
        
        var data: [String: String] = [:]
        
        if let nameRule = rule.name, !nameRule.isEmpty {
            data["name"] = try? ruleEngine.executeSingle(rule: nameRule, context: context).string
        }
        
        if let authorRule = rule.author, !authorRule.isEmpty {
            data["author"] = try? ruleEngine.executeSingle(rule: authorRule, context: context).string
        }
        
        if let coverRule = rule.coverUrl, !coverRule.isEmpty {
            data["coverUrl"] = try? ruleEngine.executeSingle(rule: coverRule, context: context).string
        }
        
        if let introRule = rule.intro, !introRule.isEmpty {
            data["intro"] = try? ruleEngine.executeSingle(rule: introRule, context: context).string
        }
        
        if let tocRule = rule.tocUrl, !tocRule.isEmpty {
            data["tocUrl"] = try? ruleEngine.executeSingle(rule: tocRule, context: context).string
        }
        
        if let lastChapterRule = rule.lastChapter, !lastChapterRule.isEmpty {
            data["lastChapter"] = try? ruleEngine.executeSingle(rule: lastChapterRule, context: context).string
        }
        
        logHandler(DebugLogEntry(level: .success, message: "书籍信息解析完成", detail: nil))
        
        return DebugBookInfo(
            name: data["name"],
            author: data["author"],
            coverUrl: data["coverUrl"],
            intro: data["intro"],
            tocUrl: data["tocUrl"],
            lastChapter: data["lastChapter"],
            rawData: data
        )
    }
    
    private func executeContentRule(
        html: String,
        rule: BookSource.ContentRule,
        logHandler: DebugLogHandler
    ) throws -> String? {
        let context = ExecutionContext()
        context.document = html
        
        guard let contentRule = rule.content, !contentRule.isEmpty else {
            logHandler(DebugLogEntry(level: .warning, message: "正文规则为空", detail: nil))
            return nil
        }
        
        logHandler(DebugLogEntry(level: .rule, message: "执行正文规则", detail: contentRule))
        
        let result = try ruleEngine.executeSingle(rule: contentRule, context: context)
        
        if let content = result.string {
            logHandler(DebugLogEntry(level: .success, message: "正文获取成功", detail: "\(content.count) 字符"))
            return content
        }
        
        return nil
    }
    
    // MARK: - URL 渲染
    
    private func renderUrl(_ template: String, source: BookSource, keyword: String) throws -> String {
        var url = template
        
        // 替换搜索关键词
        url = url.replacingOccurrences(of: "{{key}}", with: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)
        url = url.replacingOccurrences(of: "{{searchKey}}", with: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)
        
        // 使用模板引擎渲染
        let context = ExecutionContext()
        context.variables["key"] = keyword
        context.variables["searchKey"] = keyword
        
        return url
    }
}