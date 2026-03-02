//
//  RSSSubscriptionView.swift
//  Legado-iOS
//
//  RSS 订阅源功能 - 支持添加、管理和阅读 RSS 订阅
//

import SwiftUI
import CoreData

// MARK: - RSS 订阅源数据模型
struct RSSSource: Identifiable, Codable {
    var id = UUID()
    var name: String
    var url: String
    var iconUrl: String?
    var lastUpdateTime: Date?
    var sortOrder: Int = 0
    var enabled: Bool = true
    var sourceGroup: String?
}

struct RSSArticle: Identifiable {
    var id = UUID()
    var title: String = ""
    var link: String = ""
    var description: String?
    var pubDate: Date?
    var author: String?
    var imageUrl: String?
    var isRead: Bool = false
    var sourceName: String = ""
}

// MARK: - RSS 解析器
class RSSParser {
    
    /// 解析 RSS/Atom feed
    static func parse(xmlData: Data, sourceUrl: String) -> [RSSArticle] {
        let parser = XMLFeedParser(data: xmlData, sourceUrl: sourceUrl)
        parser.parse()
        return parser.articles
    }
    
    /// 从 URL 获取并解析 RSS
    static func fetchAndParse(url: String) async throws -> (name: String, articles: [RSSArticle]) {
        guard let feedUrl = URL(string: url) else {
            throw RSSError.invalidUrl
        }
        
        var request = URLRequest(url: feedUrl)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let parser = XMLFeedParser(data: data, sourceUrl: url)
        parser.parse()
        
        return (parser.feedTitle ?? "未知订阅", parser.articles)
    }
}

// MARK: - XML Feed 解析器
private class XMLFeedParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let sourceUrl: String
    
    var feedTitle: String?
    var articles: [RSSArticle] = []
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentAuthor = ""
    private var currentImageUrl = ""
    private var isInItem = false
    private var isInEntry = false  // Atom format
    private var isInChannel = false
    
    init(data: Data, sourceUrl: String) {
        self.data = data
        self.sourceUrl = sourceUrl
    }
    
    func parse() {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        
        switch elementName {
        case "item":
            isInItem = true
            resetCurrentValues()
        case "entry":
            isInEntry = true
            resetCurrentValues()
        case "channel":
            isInChannel = true
        case "link":
            if isInEntry || isInItem {
                if let href = attributeDict["href"] {
                    currentLink = href
                }
            }
        case "enclosure", "media:content", "media:thumbnail":
            if let url = attributeDict["url"], currentImageUrl.isEmpty {
                currentImageUrl = url
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch currentElement {
        case "title":
            if isInItem || isInEntry {
                currentTitle += trimmed
            } else if isInChannel && feedTitle == nil {
                feedTitle = (feedTitle ?? "") + trimmed
            }
        case "link":
            if isInItem || isInEntry {
                currentLink += trimmed
            }
        case "description", "summary", "content":
            if isInItem || isInEntry {
                currentDescription += trimmed
            }
        case "pubDate", "published", "updated":
            if isInItem || isInEntry {
                currentPubDate += trimmed
            }
        case "author", "dc:creator":
            if isInItem || isInEntry {
                currentAuthor += trimmed
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            var article = RSSArticle()
            article.title = currentTitle
            article.link = currentLink
            article.description = stripHtmlTags(currentDescription)
            article.pubDate = parseDate(currentPubDate)
            article.author = currentAuthor
            article.imageUrl = currentImageUrl.isEmpty ? extractImageFromHtml(currentDescription) : currentImageUrl
            
            if !article.title.isEmpty {
                articles.append(article)
            }
            
            isInItem = false
            isInEntry = false
        } else if elementName == "channel" {
            isInChannel = false
        }
    }
    
    private func resetCurrentValues() {
        currentTitle = ""
        currentLink = ""
        currentDescription = ""
        currentPubDate = ""
        currentAuthor = ""
        currentImageUrl = ""
    }
    
    private func parseDate(_ dateStr: String) -> Date? {
        let formatters: [DateFormatter] = {
            let formats = [
                "EEE, dd MMM yyyy HH:mm:ss Z",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd HH:mm:ss"
            ]
            return formats.map { format in
                let f = DateFormatter()
                f.dateFormat = format
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }
        }()
        
        for formatter in formatters {
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }
    
    private func stripHtmlTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractImageFromHtml(_ html: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: #"<img[^>]+src="([^"]+)""#),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }
        return nil
    }
}

// MARK: - RSS ViewModel
@MainActor
class RSSViewModel: ObservableObject {
    @Published var sources: [RSSSource] = []
    @Published var articles: [RSSArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let sourcesKey = "rss_sources"
    
    init() {
        loadSources()
    }
    
    func loadSources() {
        if let data = UserDefaults.standard.data(forKey: sourcesKey),
           let decoded = try? JSONDecoder().decode([RSSSource].self, from: data) {
            sources = decoded
        }
    }
    
    func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: sourcesKey)
        }
    }
    
    func addSource(name: String, url: String, group: String? = nil) {
        let source = RSSSource(name: name, url: url, sourceGroup: group)
        sources.append(source)
        saveSources()
    }
    
    func removeSource(at index: Int) {
        sources.remove(at: index)
        saveSources()
    }
    
    func refreshAll() async {
        isLoading = true
        errorMessage = nil
        var allArticles: [RSSArticle] = []
        
        for source in sources where source.enabled {
            do {
                let (_, articles) = try await RSSParser.fetchAndParse(url: source.url)
                let tagged = articles.map { article -> RSSArticle in
                    var a = article
                    a.sourceName = source.name
                    return a
                }
                allArticles.append(contentsOf: tagged)
            } catch {
                print("RSS 加载失败 [\(source.name)]: \(error)")
            }
        }
        
        // 按发布时间排序
        articles = allArticles.sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
        isLoading = false
    }
}

// MARK: - RSS 订阅管理视图
struct RSSSubscriptionView: View {
    @StateObject private var viewModel = RSSViewModel()
    @State private var showingAddSource = false
    @State private var newSourceName = ""
    @State private var newSourceUrl = ""
    
    var body: some View {
        List {
            if viewModel.sources.isEmpty {
                VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 40))
                            .foregroundColor(.orange.opacity(0.6))
                        Text("还没有订阅源")
                            .font(.headline)
                        Text("点击右上角 + 添加 RSS 订阅")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    // 订阅源列表
                    Section("订阅源") {
                        ForEach(viewModel.sources) { source in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.name)
                                        .font(.headline)
                                    Text(source.url)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Circle()
                                    .fill(source.enabled ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .onDelete { indexSet in
                            if let index = indexSet.first {
                                viewModel.removeSource(at: index)
                            }
                        }
                    }
                    
                    // 文章列表
                    if !viewModel.articles.isEmpty {
                        Section("最新文章") {
                            ForEach(viewModel.articles.prefix(50)) { article in
                                Link(destination: URL(string: article.link) ?? URL(string: "about:blank")!) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(article.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        
                                        HStack {
                                            Text(article.sourceName)
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            
                                            if let date = article.pubDate {
                                                Text("·")
                                                    .foregroundColor(.secondary)
                                                Text(date, style: .relative)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        if let desc = article.description, !desc.isEmpty {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("订阅源")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSource = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { Task { await viewModel.refreshAll() } }) {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task {
                await viewModel.refreshAll()
            }
            .alert("添加订阅源", isPresented: $showingAddSource) {
                TextField("名称", text: $newSourceName)
                TextField("RSS URL", text: $newSourceUrl)
                    .textInputAutocapitalization(.never)
                Button("取消", role: .cancel) { }
                Button("添加") {
                        Task { await viewModel.refreshAll() }
                    }
                }
            }
        }
        .task {
            await viewModel.refreshAll()
        }
    }
}

// MARK: - 错误类型

// MARK: - 错误类型
enum RSSError: LocalizedError {
    case invalidUrl
    case parseFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl: return "无效的 RSS URL"
        case .parseFailed: return "RSS 解析失败"
        case .networkError(let msg): return "网络错误：\(msg)"
        }
    }
}
