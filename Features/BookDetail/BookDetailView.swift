//
//  BookDetailView.swift
//  Legado-iOS
//
//  书籍详情视图（完善版）
//

import SwiftUI
import CoreData

struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @State private var showingChapterList = false
    @State private var showingSourceSelection = false
    @Environment(\.dismiss) var dismiss
    
    let book: Book
    
    init(book: Book) {
        self.book = book
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(book: book))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 封面和基本信息
                bookHeader
                
                // 操作按钮
                actionButtons
                
                // 简介
                if let intro = book.displayIntro, !intro.isEmpty {
                    introductionSection
                }
                
                // 目录预览
                tocPreviewSection
                
                // 书籍信息
                bookInfoSection
            }
            .padding()
        }
        .navigationTitle("书籍详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewModel.toggleFavorite() }) {
                        Label(
                            viewModel.isFavorite ? "取消收藏" : "收藏",
                            systemImage: viewModel.isFavorite ? "heart.fill" : "heart"
                        )
                    }
                    
                    Button(action: { showingSourceSelection = true }) {
                        Label("换源", systemImage: "arrow.2.circlepath")
                    }
                    
                    Button(action: { viewModel.cacheAllChapters() }) {
                        Label("缓存全本", systemImage: "arrow.down.circle")
                    }
                    
                    Divider()
                    
                    Button("刷新书籍信息") {
                        Task { await viewModel.refreshBookInfo() }
                    }
                    
                    Divider()
                    
                    Button("删除", role: .destructive) {
                        viewModel.deleteBook(book)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showingChapterList) {
            ChapterListView(viewModel: ReaderViewModel(), book: book)
        }
        .sheet(isPresented: $showingSourceSelection) {
            SourceSelectionSheet(book: book, selectedSource: $viewModel.currentSource)
        }
        .alert("提示", isPresented: $viewModel.showingAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .task {
            await viewModel.loadChapters()
        }
    }
    
    // MARK: - 书籍头部
    private var bookHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            BookCoverView(url: book.displayCoverUrl)
                .frame(width: 120, height: 160)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .shadow(radius: 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(book.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text(book.author)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if let kind = book.kind, !kind.isEmpty {
                    Text(kind)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                if let wordCount = book.wordCount {
                    Label(wordCount, systemImage: "text.word.count")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 阅读进度
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("阅读进度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(book.readProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    ProgressView(value: book.readProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.startReading() }) {
                Label(book.readProgress > 0 ? "继续阅读" : "开始阅读", systemImage: "book.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button(action: { showingChapterList = true }) {
                Label("目录", systemImage: "list.bullet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - 简介
    private var introductionSection: some View {
        SectionCard(title: "简介") {
            Text(book.displayIntro ?? "")
                .font(.body)
                .lineSpacing(4)
                .lineLimit(viewModel.isIntroExpanded ? nil : 4)
            
            if (book.displayIntro ?? "").count > 100 {
                Button(action: { viewModel.isIntroExpanded.toggle() }) {
                    Text(viewModel.isIntroExpanded ? "收起" : "展开")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - 目录预览
    private var tocPreviewSection: some View {
        SectionCard(title: "目录") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("共 \(book.totalChapterNum) 章")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let latest = book.latestChapterTitle {
                        Text("最新：\(latest)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if !viewModel.previewChapters.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.previewChapters) { chapter in
                            Button(action: { viewModel.readChapter(chapter) }) {
                                HStack {
                                    Text("\(chapter.index + 1). \(chapter.title)")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if chapter.isCached {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    
                    if viewModel.previewChapters.count < book.totalChapterNum {
                        Button(action: { showingChapterList = true }) {
                            Text("查看全部章节 →")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 书籍信息
    private var bookInfoSection: some View {
        SectionCard(title: "书籍信息") {
            Grid {
                GridRow {
                    Label("书源", systemImage: "link")
                    Text(book.originName)
                }
                
                GridRow {
                    Label("章节", systemImage: "list.bullet")
                    Text("\(book.totalChapterNum) 章")
                }
                
                GridRow {
                    Label("进度", systemImage: "gauge")
                    Text("\(Int(book.readProgress * 100))%")
                }
                
                if let wordCount = book.wordCount {
                    GridRow {
                        Label("字数", systemImage: "text.alignleft")
                        Text(wordCount)
                    }
                }
            }
            .font(.caption)
        }
    }
}

// MARK: - Section Card
struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            content
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - ViewModel
@MainActor
class BookDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isFavorite = false
    @Published var isIntroExpanded = false
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var currentSource: BookSource?
    @Published var previewChapters: [ChapterPreview] = []
    
    let book: Book
    private let context = CoreDataStack.shared.viewContext
    
    init(book: Book) {
        self.book = book
        self.currentSource = book.source
    }
    
    func loadChapters() async {
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BookChapter.index, ascending: true)]
        request.fetchLimit = 5
        
        do {
            let chapters = try context.fetch(request)
            previewChapters = chapters.map { ChapterPreview(
                id: $0.chapterId,
                index: Int($0.index),
                title: $0.title,
                isCached: $0.isCached
            )}
        } catch {
            print("加载章节失败: \(error)")
        }
    }
    
    func startReading() {
        // TODO: 导航到阅读器
        showingAlert = true
        alertMessage = "阅读器功能开发中"
    }
    
    func readChapter(_ chapter: ChapterPreview) {
        // TODO: 导航到阅读器指定章节
        showingAlert = true
        alertMessage = "即将阅读：\(chapter.title)"
    }
    
    func refreshBookInfo() async {
        isLoading = true
        // TODO: 实现刷新
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
        showingAlert = true
        alertMessage = "刷新完成"
    }
    
    func toggleFavorite() {
        isFavorite.toggle()
        // TODO: 保存到 CoreData
    }
    
    func cacheAllChapters() {
        showingAlert = true
        alertMessage = "缓存功能开发中"
    }
    
    func deleteBook(_ book: Book) {
        context.delete(book)
        try? CoreDataStack.shared.save()
    }
}

// MARK: - 章节预览
struct ChapterPreview: Identifiable {
    let id: UUID
    let index: Int
    let title: String
    let isCached: Bool
}

// MARK: - 书源选择 Sheet
struct SourceSelectionSheet: View {
    let book: Book
    @Binding var selectedSource: BookSource?
    @Environment(\.dismiss) var dismiss
    @State private var sources: [BookSource] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sources, id: \.sourceId) { source in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(source.bookSourceName)
                                .font(.body)
                            Text(source.bookSourceGroup ?? "默认分组")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if source.sourceId == selectedSource?.sourceId {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSource = source
                        dismiss()
                    }
                }
            }
            .navigationTitle("选择书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .task {
                await loadSources()
            }
        }
    }
    
    private func loadSources() async {
        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES")
        
        do {
            sources = try CoreDataStack.shared.viewContext.fetch(request)
        } catch {
            print("加载书源失败: \(error)")
        }
    }
}

// MARK: - 预览
#Preview {
    NavigationView {
        BookDetailView(book: Book())
    }
}
