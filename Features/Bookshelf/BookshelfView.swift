//
//  BookshelfView.swift
//  Legado-iOS
//
//  书架主界面
//

import SwiftUI
import CoreData

struct BookshelfView: View {
    @StateObject private var viewModel = BookshelfViewModel()
    @StateObject private var localBookViewModel = LocalBookViewModel()
    @State private var showingSourceManage = false
    @State private var showingAddBook = false
    @State private var showingSearch = false
    
    var body: some View {
        Group {
            if viewModel.books.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "书架空空如也",
                    subtitle: "点击右上角添加书籍或导入书源",
                    imageName: "books.vertical"
                )
            } else {
                bookshelfContent
            }
        }
        .navigationTitle("书架")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Picker("", selection: $viewModel.viewMode) {
                    Image(systemName: "square.grid.2x2")
                        .tag(BookshelfViewModel.ViewMode.grid)
                    Image(systemName: "list.bullet")
                        .tag(BookshelfViewModel.ViewMode.list)
                }
                .pickerStyle(.segmented)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showingSearch = true }) {
                        Image(systemName: "magnifyingglass")
                    }

                    Button(action: { showingSourceManage = true }) {
                        Image(systemName: "gearshape")
                    }
                    
                    Button(action: { showingAddBook = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSourceManage) {
            SourceManageView()
        }
        .sheet(isPresented: $showingAddBook) {
            AddBookView { url in
                Task {
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    do {
                        try await localBookViewModel.importBook(url: url)
                        await viewModel.loadBooks()
                    } catch {
                        print("导入失败：\(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            NavigationStack { SearchResultView() }
        }
        .alert("导入成功", isPresented: Binding(
            get: { localBookViewModel.successMessage != nil },
            set: { if !$0 { localBookViewModel.successMessage = nil } }
        )) {
            Button("确定", role: .cancel) { localBookViewModel.successMessage = nil }
        } message: {
            Text(localBookViewModel.successMessage ?? "")
        }
        .alert("导入失败", isPresented: Binding(
            get: { localBookViewModel.errorMessage != nil },
            set: { if !$0 { localBookViewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { localBookViewModel.errorMessage = nil }
        } message: {
            Text(localBookViewModel.errorMessage ?? "未知错误")
        }
        .task {
            await viewModel.loadBooks()
        }
        .refreshable {
            await viewModel.refreshBooks()
        }
    }
    
    @ViewBuilder
    private var bookshelfContent: some View {
        switch viewModel.viewMode {
        case .grid:
            bookGridView
        case .list:
            bookListView
        }
    }
    
    private var bookGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.books, id: \.bookId) { book in
                    NavigationLink(destination: ReaderView(book: book)) {
                        BookGridItemView(book: book)
                    }
                    .buttonStyle(.plain)
                }
                
                // 加载更多指示器
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if viewModel.hasMore {
                    // 接近底部时加载更多
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task {
                                await viewModel.loadMoreBooks()
                            }
                        }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshBooks()
        }
    }
    
    private var bookListView: some View {
        List {
            ForEach(viewModel.books, id: \.bookId) { book in
                NavigationLink(destination: ReaderView(book: book)) {
                    BookListItemView(book: book)
                }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    viewModel.removeBook(viewModel.books[index])
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 网格项
struct BookGridItemView: View {
    let book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面
            BookCoverView(url: book.coverUrl)
                .frame(maxWidth: .infinity)
                .aspectRatio(3/4, contentMode: .fill)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // 书名
            Text(book.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            // 作者
            Text(book.author)
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.secondary)
            
            // 进度条
            ProgressView(value: book.readProgress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
    }
}

// MARK: - 列表项
struct BookListItemView: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            BookCoverView(url: book.coverUrl)
                .frame(width: 60, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 4) {
                // 书名
                Text(book.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // 作者
                Text(book.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // 最新章节
                if let chapter = book.latestChapterTitle {
                    Text(chapter)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 进度
                HStack {
                    ProgressView(value: book.readProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                    
                    Text("\(Int(book.readProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 封面视图
struct BookCoverView: View {
    let url: String?
    @State private var imageData: Data?
    
    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "books.vertical")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .task {
            if let urlString = url, !urlString.isEmpty {
                await loadImage(urlString: urlString)
            }
        }
    }
    
    private func loadImage(urlString: String) async {
        // 使用 ImageCacheManager 实现内存+磁盘缓存
        let cached = await ImageCacheManager.shared.loadImage(from: urlString)
        if let cached = cached {
            imageData = cached.pngData()
        }
    }
}

// MARK: - 空状态
struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let imageName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: imageName)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 预览
#Preview {
    BookshelfView()
}
