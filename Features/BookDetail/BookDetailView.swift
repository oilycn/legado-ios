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
    @State private var navigatingToReader = false
    @Environment(\.dismiss) var dismiss
    
    let book: Book
    
    init(book: Book) {
        self.book = book
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(book: book))
    }
    
    var body: some View {
        ZStack {
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

            if viewModel.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()

                ProgressView("处理中...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
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
        .navigationDestination(isPresented: $navigatingToReader) {
            ReaderView(book: book)
        }
        .background {
            // 背景模糊效果
            if let coverUrl = book.displayCoverUrl, !coverUrl.isEmpty {
                AsyncImage(url: URL(string: coverUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 30)
                            .overlay(Color.black.opacity(0.6))
                            .ignoresSafeArea()
                    default:
                        Color.clear
                    }
                }
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.loadChapters()
        }
    }
    
    // MARK: - 书籍头部
    private var bookHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            // 封面 - 增强阴影效果
            BookCoverView(url: book.displayCoverUrl)
                .frame(width: 120, height: 160)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
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
            Button(action: {
                if viewModel.startReading() {
                    navigatingToReader = true
                }
            }) {
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
                            Button(action: {
                                if viewModel.readChapter(chapter) {
                                    navigatingToReader = true
                                }
                            }) {
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
    private static let favoriteTag = "favorite"
    
    init(book: Book) {
        self.book = book
        self.currentSource = book.source
        self.isFavorite = Self.tags(from: book.customTag).contains(Self.favoriteTag)
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
    
    @discardableResult
    func startReading() -> Bool {
        prepareReading(startAt: nil)
    }

    @discardableResult
    func readChapter(_ chapter: ChapterPreview) -> Bool {
        prepareReading(startAt: chapter.index, chapterTitle: chapter.title)
    }
    
    func refreshBookInfo() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let source = try resolveSource()
            try await WebBook.getBookInfo(source: source, book: book)
            let chapterCount = try await refreshChapterList(source: source)
            book.totalChapterNum = Int32(chapterCount)
            try CoreDataStack.shared.save()
            await loadChapters()
            showingAlert = true
            alertMessage = "刷新完成（共 \(chapterCount) 章）"
        } catch {
            showingAlert = true
            alertMessage = "刷新失败：\(error.localizedDescription)"
        }
    }
    
    func toggleFavorite() {
        var tags = Self.tags(from: book.customTag)
        if tags.contains(Self.favoriteTag) {
            tags.remove(Self.favoriteTag)
        } else {
            tags.insert(Self.favoriteTag)
        }

        book.customTag = Self.encodeTags(tags)
        isFavorite = tags.contains(Self.favoriteTag)

        do {
            try CoreDataStack.shared.save()
        } catch {
            context.rollback()
            isFavorite = Self.tags(from: book.customTag).contains(Self.favoriteTag)
            showingAlert = true
            alertMessage = "收藏状态保存失败：\(error.localizedDescription)"
        }
    }
    
    func cacheAllChapters() {
        Task {
            await cacheAllChaptersTask()
        }
    }

    private func cacheAllChaptersTask() async {
        guard !book.isLocal else {
            showingAlert = true
            alertMessage = "本地书籍无需缓存"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let source = try resolveSource()

            _ = try await refreshChapterList(source: source)
            let request = BookChapter.fetchRequest(byBookId: book.bookId)
            let chapters = try context.fetch(request)

            var cachedCount = 0
            var failedCount = 0

            for chapter in chapters {
                if chapter.isCached, cacheFileExists(for: chapter) {
                    continue
                }

                do {
                    let content = try await WebBook.getContent(source: source, book: book, chapter: chapter)
                    try cacheChapterToDisk(chapter: chapter, content: content)
                    cachedCount += 1

                    if cachedCount % 20 == 0 {
                        try CoreDataStack.shared.save()
                    }
                } catch {
                    failedCount += 1
                }
            }

            try CoreDataStack.shared.save()
            await loadChapters()
            showingAlert = true
            if failedCount > 0 {
                alertMessage = "缓存完成：新增 \(cachedCount) 章，失败 \(failedCount) 章"
            } else {
                alertMessage = "缓存完成：新增 \(cachedCount) 章"
            }
        } catch {
            showingAlert = true
            alertMessage = "缓存失败：\(error.localizedDescription)"
        }
    }

    private func resolveSource() throws -> BookSource {
        if let currentSource {
            return currentSource
        }

        guard let sourceUUID = UUID(uuidString: book.origin) else {
            throw NSError(domain: "BookDetailViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到书源"])
        }

        let request: NSFetchRequest<BookSource> = BookSource.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "sourceId == %@", sourceUUID as CVarArg)
        if let source = try context.fetch(request).first {
            currentSource = source
            return source
        }

        throw NSError(domain: "BookDetailViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "未找到书源"])
    }

    private func refreshChapterList(source: BookSource) async throws -> Int {
        let webChapters = try await WebBook.getChapterList(source: source, book: book)

        let request = BookChapter.fetchRequest(byBookId: book.bookId)
        let existing = try context.fetch(request)

        var existingByUrl: [String: BookChapter] = [:]
        for chapter in existing where !chapter.chapterUrl.isEmpty {
            if existingByUrl[chapter.chapterUrl] == nil {
                existingByUrl[chapter.chapterUrl] = chapter
            }
        }

        var newUrlSet = Set<String>()
        newUrlSet.reserveCapacity(webChapters.count)

        for web in webChapters {
            let url = web.url
            guard !url.isEmpty else { continue }
            newUrlSet.insert(url)

            if let chapter = existingByUrl[url] {
                chapter.title = web.title
                chapter.index = Int32(web.index)
                chapter.isVIP = web.isVip
                chapter.updateTime = Int64(Date().timeIntervalSince1970)
            } else {
                let chapter = BookChapter.create(
                    in: context,
                    bookId: book.bookId,
                    url: url,
                    index: Int32(web.index),
                    title: web.title
                )
                chapter.book = book
                chapter.sourceId = source.sourceId.uuidString
                chapter.isVIP = web.isVip
            }
        }

        for chapter in existing where !newUrlSet.contains(chapter.chapterUrl) {
            context.delete(chapter)
        }

        book.totalChapterNum = Int32(webChapters.count)
        try CoreDataStack.shared.save()
        return webChapters.count
    }

    private func chapterCacheDir() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("chapters", isDirectory: true)
    }

    private func cacheFileURL(for chapter: BookChapter) -> URL? {
        if let cachePath = chapter.cachePath, !cachePath.isEmpty {
            if cachePath.hasPrefix("/") {
                return URL(fileURLWithPath: cachePath)
            }
            return chapterCacheDir().appendingPathComponent(cachePath)
        }
        return nil
    }

    private func cacheFileExists(for chapter: BookChapter) -> Bool {
        guard let url = cacheFileURL(for: chapter) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private func cacheChapterToDisk(chapter: BookChapter, content: String) throws {
        let dir = chapterCacheDir()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let fileName = "\(chapter.bookId.uuidString)_\(chapter.index).txt"
        let fileURL = dir.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        chapter.isCached = true
        chapter.cachePath = fileName
    }

    @discardableResult
    private func prepareReading(startAt chapterIndex: Int?, chapterTitle: String? = nil) -> Bool {
        if let chapterIndex {
            let safeIndex = max(0, chapterIndex)
            book.durChapterIndex = Int32(safeIndex)
            book.durChapterPos = 0
            book.durChapterTitle = chapterTitle
        } else {
            if book.durChapterIndex < 0 {
                book.durChapterIndex = 0
            }
            if book.durChapterPos < 0 {
                book.durChapterPos = 0
            }
        }
        book.durChapterTime = Int64(Date().timeIntervalSince1970)

        do {
            try CoreDataStack.shared.save()
            return true
        } catch {
            context.rollback()
            showingAlert = true
            alertMessage = "保存阅读进度失败：\(error.localizedDescription)"
            return false
        }
    }

    private static func tags(from raw: String?) -> Set<String> {
        guard let raw, !raw.isEmpty else { return [] }
        let values = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Set(values)
    }

    private static func encodeTags(_ tags: Set<String>) -> String? {
        guard !tags.isEmpty else { return nil }
        return tags.sorted().joined(separator: ",")
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
