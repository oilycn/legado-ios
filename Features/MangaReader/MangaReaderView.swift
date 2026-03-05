//
//  MangaReaderView.swift
//  Legado-iOS
//
//  漫画阅读器 - 支持 type=2 书源
//  图片列表 + 缩放 + 懒加载
//

import SwiftUI

struct MangaReaderView: View {
    @StateObject private var viewModel = MangaReaderViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showUI = true
    @State private var currentImageIndex = 0
    
    let book: Book
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.images.isEmpty {
                ProgressView("加载中...")
                    .foregroundColor(.white)
            } else if viewModel.images.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("暂无图片")
                        .foregroundColor(.gray)
                    if let error = viewModel.errorMessage {
                        Text(error).font(.caption).foregroundColor(.red)
                    }
                }
            } else {
                // 图片列表（纵向长条模式）
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(viewModel.images.enumerated()), id: \.offset) { index, imageURL in
                            ZoomableImageView(url: imageURL) {
                                withAnimation { showUI.toggle() }
                            }
                            .id(imageURL)
                            .onAppear { currentImageIndex = index }
                        }
                        
                        // 加载更多
                        if viewModel.hasMoreImages {
                            ProgressView()
                                .padding()
                                .onAppear { Task { await viewModel.loadMoreImages() } }
                        }
                    }
                }
            }
            
            // 顶部工具栏
            if showUI {
                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").foregroundColor(.white)
                        }
                        Text(book.name).foregroundColor(.white).lineLimit(1)
                        Spacer()
                        Text("\(currentImageIndex + 1)/\(viewModel.images.count)")
                            .font(.caption).foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .statusBar(hidden: !showUI)
        .onAppear { Task { await viewModel.loadBook(book) } }
    }
}

// MARK: - ViewModel

@MainActor
class MangaReaderViewModel: ObservableObject {
    @Published var images: [String] = []
    @Published var isLoading = false
    @Published var hasMoreImages = false
    @Published var errorMessage: String?
    @Published var currentChapterIndex = 0
    
    private var chapters: [BookChapter] = []
    private var currentBook: Book?
    
    func loadBook(_ book: Book) async {
        currentBook = book
        isLoading = true
        
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        if let result = try? context.fetch(request) {
            chapters = result
            currentChapterIndex = Int(book.durChapterIndex)
            if let chapter = chapters[safe: currentChapterIndex] {
                await loadChapter(chapter)
            }
        }
        
        isLoading = false
    }
    
    func loadChapter(_ chapter: BookChapter) async {
        guard let book = currentBook, let source = book.source else { return }
        
        do {
            let content = try await WebBook.getContent(source: source, book: book, chapter: chapter)
            let imageURLs = content.imageURLs
            
            if !imageURLs.isEmpty {
                images = imageURLs
                hasMoreImages = false
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
    
    func loadMoreImages() async {
        // 加载下一章
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
        if let chapter = chapters[safe: currentChapterIndex] {
            await loadChapter(chapter)
        }
    }
}

// MARK: - 可缩放图片视图

struct ZoomableImageView: View {
    let url: String
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1 { withAnimation { scale = 1; lastScale = 1 } }
                                    if scale > 5 { withAnimation { scale = 5; lastScale = 5 } }
                                }
                        )
                        .onTapGesture { onTap() }
                        .onAppear { isLoading = false }
                case .failure:
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle).foregroundColor(.gray)
                        Button("重试") { /* reload */ }
                    }
                    .frame(height: 300)
                default:
                    ProgressView()
                        .frame(height: 300)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}