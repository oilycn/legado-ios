//
//  DiscoveryView.swift
//  Legado-iOS
//
//  发现页视图 - 展示书源发现内容
//  P2-T4 实现
//

import SwiftUI
import CoreData

// MARK: - 发现页视图

struct DiscoveryView: View {
    @StateObject private var viewModel = DiscoveryViewModel()
    @State private var selectedCategory: String?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 分类标签
                categoryTags
                
                // 内容列表
                if viewModel.isLoading && viewModel.discoveredBooks.isEmpty {
                    loadingView
                } else if viewModel.discoveredBooks.isEmpty {
                    emptyView
                } else {
                    discoveredBooksList
                }
            }
            .padding()
        }
        .navigationTitle("发现")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadDiscoveryContent()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - 分类标签
    
    private var categoryTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 全部
                CategoryTag(
                    title: "全部",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                    Task { await viewModel.loadCategory(nil) }
                }
                
                ForEach(viewModel.categories, id: \.self) { category in
                    CategoryTag(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                        Task { await viewModel.loadCategory(category) }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - 加载中视图
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在加载...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - 空视图
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("暂无发现内容")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("请确保已添加支持发现功能的书源")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("刷新") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - 发现书籍列表
    
    private var discoveredBooksList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.discoveredBooks) { book in
                DiscoveredBookCard(book: book) {
                    // 添加到书架
                    Task { await viewModel.addToBookshelf(book) }
                }
            }
            
            // 加载更多
            if viewModel.hasMore {
                LoadMoreView {
                    await viewModel.loadMore()
                }
            }
        }
    }
}

// MARK: - 分类标签

struct CategoryTag: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// MARK: - 发现书籍卡片

struct DiscoveredBookCard: View {
    let book: DiscoveredBook
    let onAddToBookshelf: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            AsyncImage(url: book.coverUrl.flatMap { URL(string: $0) }) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    defaultCover
                default:
                    ProgressView()
                }
            }
            .frame(width: 60, height: 80)
            .cornerRadius(8)
            
            // 书籍信息
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let intro = book.intro, !intro.isEmpty {
                    Text(intro)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(book.sourceName)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // 添加按钮
            Button(action: onAddToBookshelf) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    private var defaultCover: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "book.closed")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 加载更多视图

struct LoadMoreView: View {
    let action: () async -> Void
    
    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("加载更多...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - 发现书籍模型

struct DiscoveredBook: Identifiable {
    let id = UUID()
    let name: String
    let author: String
    let coverUrl: String?
    let intro: String?
    let bookUrl: String
    let sourceId: UUID
    let sourceName: String
}

// MARK: - ViewModel

@MainActor
class DiscoveryViewModel: ObservableObject {
    @Published var discoveredBooks: [DiscoveredBook] = []
    @Published var categories: [String] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var errorMessage: String?
    
    private var currentPage = 1
    private var currentCategory: String?
    
    func loadDiscoveryContent() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let sources = try getEnabledDiscoverySources()
            
            if sources.isEmpty {
                isLoading = false
                return
            }
            
            var allBooks: [DiscoveredBook] = []
            var allCategories: Set<String> = []
            
            for source in sources {
                let (books, cats) = try await fetchDiscoveryFromSource(source)
                allBooks.append(contentsOf: books)
                allCategories.formUnion(cats)
            }
            
            discoveredBooks = allBooks
            categories = Array(allCategories).sorted()
            hasMore = !allBooks.isEmpty
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadCategory(_ category: String?) async {
        currentCategory = category
        currentPage = 1
        discoveredBooks = []
        await loadDiscoveryContent()
    }
    
    func loadMore() async {
        currentPage += 1
        await loadDiscoveryContent()
    }
    
    func refresh() async {
        currentPage = 1
        discoveredBooks = []
        hasMore = true
        await loadDiscoveryContent()
    }
    
    func addToBookshelf(_ book: DiscoveredBook) async {
        let context = CoreDataStack.shared.viewContext
        
        // 检查是否已存在
        let request = Book.fetchRequest()
        request.predicate = NSPredicate(format: "bookUrl == %@", book.bookUrl)
        
        if let existing = try? context.fetch(request), !existing.isEmpty {
            return // 已存在
        }
        
        let newBook = Book.create(in: context)
        newBook.name = book.name
        newBook.author = book.author
        newBook.coverUrl = book.coverUrl
        newBook.intro = book.intro ?? ""
        newBook.bookUrl = book.bookUrl
        newBook.origin = book.sourceId.uuidString
        newBook.originName = book.sourceName
        
        try? CoreDataStack.shared.save()
    }
    
    private func getEnabledDiscoverySources() throws -> [BookSource] {
        let context = CoreDataStack.shared.viewContext
        let request = BookSource.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES AND enabledExplore == YES")
        
        return try context.fetch(request)
    }
    
    private func fetchDiscoveryFromSource(_ source: BookSource) async throws -> ([DiscoveredBook], [String]) {
        guard let exploreUrl = source.exploreUrl, !exploreUrl.isEmpty else {
            return ([], [])
        }
        
        // 解析发现 URL
        var books: [DiscoveredBook] = []
        var categories: [String] = []
        
        // 解析发现规则
        guard let ruleData = source.ruleExploreData,
              let rule = try? JSONDecoder().decode(BookSource.ExploreRule.self, from: ruleData) else {
            return ([], [])
        }
        
        // 获取发现内容
        let httpClient = HTTPClient.shared
        let (html, _) = try await httpClient.getHtml(urlString: exploreUrl)
        
        // 解析书籍列表
        let ruleEngine = RuleEngine()
        let context = ExecutionContext()
        context.document = html
        context.baseURL = URL(string: source.bookSourceUrl)
        
        guard let exploreListRule = rule.exploreList else { return ([], []) }
        
        let listResult = try ruleEngine.executeSingle(rule: exploreListRule, context: context)
        
        guard case .list(let elements) = listResult else { return ([], []) }
        
        for element in elements {
            let itemContext = ExecutionContext()
            itemContext.document = element
            itemContext.baseURL = URL(string: source.bookSourceUrl)
            
            var bookName = ""
            var bookAuthor = ""
            var bookCover: String?
            var bookUrl = ""
            
            if let nameRule = rule.name {
                bookName = try? ruleEngine.executeSingle(rule: nameRule, context: itemContext).string ?? ""
            }
            
            if let authorRule = rule.author {
                bookAuthor = try? ruleEngine.executeSingle(rule: authorRule, context: itemContext).string ?? ""
            }
            
            if let coverRule = rule.coverUrl {
                bookCover = try? ruleEngine.executeSingle(rule: coverRule, context: itemContext).string
            }
            
            if let urlRule = rule.bookUrl {
                bookUrl = try? ruleEngine.executeSingle(rule: urlRule, context: itemContext).string ?? ""
            }
            
            if !bookName.isEmpty && !bookUrl.isEmpty {
                books.append(DiscoveredBook(
                    name: bookName,
                    author: bookAuthor,
                    coverUrl: bookCover,
                    intro: nil,
                    bookUrl: bookUrl,
                    sourceId: source.sourceId,
                    sourceName: source.bookSourceName
                ))
            }
        }
        
        // 提取分类
        if let classifyRule = rule.classify {
            let classifyResult = try? ruleEngine.executeSingle(rule: classifyRule, context: context)
            if case .list(let cats) = classifyResult {
                categories = cats.map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
        
        return (books, categories)
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        DiscoveryView()
    }
}