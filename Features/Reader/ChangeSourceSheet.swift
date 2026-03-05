//
//  ChangeSourceSheet.swift
//  Legado-iOS
//
//  换源对话框 - 参考 Android ChangeBookSourceDialog
//  在阅读界面中支持一键换源，对比不同书源的最新章节
//

import SwiftUI
import CoreData

// MARK: - 换源数据模型

/// 换源搜索结果
struct ChangeSourceResult: Identifiable {
    let id = UUID()
    let source: BookSource
    let latestChapter: String
    let chapterCount: Int
    let bookUrl: String
    let tocUrl: String
    let isCurrentSource: Bool
    var isLoading: Bool = false
    var loadError: String?
}

// MARK: - 换源 ViewModel

@MainActor
class ChangeSourceViewModel: ObservableObject {
    @Published var results: [ChangeSourceResult] = []
    @Published var isSearching = false
    @Published var searchProgress: Double = 0
    @Published var errorMessage: String?
    
    private var searchTasks: [Task<Void, Never>] = []
    private let ruleEngine = RuleEngine()
    
    /// 搜索可用书源
    func searchSources(for book: Book) async {
        isSearching = true
        searchProgress = 0
        results = []
        errorMessage = nil
        
        // 取消之前的搜索
        cancelSearch()
        
        let context = CoreDataStack.shared.viewContext
        
        // 获取所有启用的书源
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES AND searchUrl != nil AND searchUrl != ''")
        request.sortDescriptors = [NSSortDescriptor(key: "weight", ascending: false)]
        
        guard let sources = try? context.fetch(request), !sources.isEmpty else {
            errorMessage = "没有可用的书源"
            isSearching = false
            return
        }
        
        let totalSources = sources.count
        var completedCount = 0
        
        // 并发搜索，限制并发数
        let semaphore = DispatchSemaphore(value: 5) // 最多 5 个并发
        
        for source in sources {
            let isCurrentSource = source.bookSourceUrl == book.origin
            
            let task = Task { [weak self] in
                guard !Task.isCancelled else { return }
                
                do {
                    // 在书源中搜索当前书名
                    let searchResults = try await WebBook.searchBook(
                        source: source,
                        key: book.name
                    )
                    
                    // 找到匹配的书籍（书名+作者匹配）
                    let matched = searchResults.first { searchBook in
                        searchBook.name == book.name &&
                        (book.author.isEmpty || searchBook.author == book.author)
                    }
                    
                    if let matchedBook = matched {
                        let result = ChangeSourceResult(
                            source: source,
                            latestChapter: matchedBook.lastChapter ?? "未知",
                            chapterCount: 0,
                            bookUrl: matchedBook.bookUrl,
                            tocUrl: "",
                            isCurrentSource: isCurrentSource
                        )
                            source: source,
                            latestChapter: matchedBook.latestChapterTitle ?? "未知",
                            chapterCount: Int(matchedBook.totalChapterNum),
                            bookUrl: matchedBook.bookUrl,
                            tocUrl: matchedBook.tocUrl ?? "",
                            isCurrentSource: isCurrentSource
                        )
                        
                        await MainActor.run {
                            self?.results.append(result)
                            self?.sortResults()
                        }
                    }
                } catch {
                    // 搜索失败时静默忽略（书源可能不可用）
                    print("换源搜索失败[\(source.bookSourceName)]: \(error.localizedDescription)")
                }
                
                await MainActor.run {
                    completedCount += 1
                    self?.searchProgress = Double(completedCount) / Double(totalSources)
                }
            }
            
            searchTasks.append(task)
        }
        
        // 等待所有搜索完成
        for task in searchTasks {
            await task.value
        }
        
        isSearching = false
        
        if results.isEmpty {
            errorMessage = "未找到其他可用书源"
        }
    }
    
    /// 执行换源
    func changeSource(
        result: ChangeSourceResult,
        for book: Book
    ) async throws {
        let context = CoreDataStack.shared.viewContext
        
        // 更新 book 的书源信息
        book.origin = result.source.bookSourceUrl
        book.originName = result.source.bookSourceName
        book.bookUrl = result.bookUrl
        book.tocUrl = result.tocUrl
        book.latestChapterTitle = result.latestChapter
        book.updatedAt = Date()
        
        // 关联新书源
        book.source = result.source
        
        // 删除旧章节缓存
        if let chapters = book.chapters as? Set<BookChapter> {
            for chapter in chapters {
                context.delete(chapter)
            }
        }
        
        // 重新获取目录
        let webChapters = try await WebBook.getChapterList(
            source: result.source,
            book: book
        )
        
        for web in webChapters {
            let chapter = BookChapter.create(
                in: context,
                bookId: book.bookId,
                url: web.url,
                index: Int32(web.index),
                title: web.title
            )
            chapter.book = book
            chapter.sourceId = result.source.sourceId.uuidString
            chapter.isVIP = web.isVip
        }
        
        book.totalChapterNum = Int32(webChapters.count)
        
        // 保持阅读进度（通过章节标题匹配）
        if let currentTitle = book.durChapterTitle {
            if let matchedIndex = webChapters.firstIndex(where: { $0.title == currentTitle }) {
                book.durChapterIndex = Int32(matchedIndex)
            } else {
                // 标题不匹配时，按比例定位
                let progress = Double(book.durChapterIndex) / max(1, Double(book.totalChapterNum))
                book.durChapterIndex = Int32(Double(webChapters.count) * progress)
            }
        }
        
        try context.save()
    }
    
    /// 取消搜索
    func cancelSearch() {
        for task in searchTasks {
            task.cancel()
        }
        searchTasks.removeAll()
    }
    
    /// 排序结果（当前源置顶，其余按章节数降序）
    private func sortResults() {
        results.sort { a, b in
            if a.isCurrentSource { return true }
            if b.isCurrentSource { return false }
            return a.chapterCount > b.chapterCount
        }
    }
}

// MARK: - 换源 Sheet 视图

struct ChangeSourceSheet: View {
    @StateObject private var viewModel = ChangeSourceViewModel()
    @Binding var isPresented: Bool
    let book: Book
    let onSourceChanged: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索进度
                if viewModel.isSearching {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.searchProgress)
                            .accentColor(.blue)
                        
                        Text("正在搜索可用书源... (\(Int(viewModel.searchProgress * 100))%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // 结果列表
                if viewModel.results.isEmpty && !viewModel.isSearching {
                    emptyStateView
                } else {
                    resultListView
                }
            }
            .navigationTitle("换源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        viewModel.cancelSearch()
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSearching {
                        Button("停止") {
                            viewModel.cancelSearch()
                            viewModel.isSearching = false
                        }
                    } else {
                        Button("重搜") {
                            Task { await viewModel.searchSources(for: book) }
                        }
                    }
                }
            }
            .task {
                await viewModel.searchSources(for: book)
            }
        }
    }
    
    // MARK: - 空状态
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(viewModel.errorMessage ?? "暂无结果")
                .foregroundColor(.secondary)
            
            Button("重新搜索") {
                Task { await viewModel.searchSources(for: book) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 结果列表
    
    private var resultListView: some View {
        List {
            ForEach(viewModel.results) { result in
                SourceResultRow(result: result) {
                    Task {
                        do {
                            try await viewModel.changeSource(
                                result: result,
                                for: book
                            )
                            onSourceChanged()
                            isPresented = false
                        } catch {
                            viewModel.errorMessage = "换源失败: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - 书源结果行

struct SourceResultRow: View {
    let result: ChangeSourceResult
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 书源图标
                VStack {
                    Image(systemName: result.isCurrentSource ? "checkmark.circle.fill" : "doc.text")
                        .font(.title2)
                        .foregroundColor(result.isCurrentSource ? .green : .blue)
                }
                .frame(width: 40)
                
                // 书源信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(result.source.bookSourceName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if result.isCurrentSource {
                            Text("当前")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("最新: \(result.latestChapter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if result.chapterCount > 0 {
                        Text("共 \(result.chapterCount) 章")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 选择箭头
                if !result.isCurrentSource {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(result.isCurrentSource)
    }
}
