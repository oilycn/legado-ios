//
//  SearchContentView.swift
//  Legado-iOS
//
//  书内全文搜索 - Phase 4
//

import SwiftUI
import CoreData

struct SearchContentView: View {
    @StateObject private var viewModel: SearchContentViewModel
    @Binding var isPresented: Bool
    let onResultTap: (Int, Int) -> Void
    
    init(book: Book, isPresented: Binding<Bool>, onResultTap: @escaping (Int, Int) -> Void) {
        _viewModel = StateObject(wrappedValue: SearchContentViewModel(book: book))
        _isPresented = isPresented
        self.onResultTap = onResultTap
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchText, isSearching: $viewModel.isSearching) {
                    Task { await viewModel.search() }
                }
                
                if viewModel.isSearching {
                    ProgressView("搜索中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.results.isEmpty {
                    if viewModel.searchText.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass").font(.system(size: 48)).foregroundColor(.gray)
                            Text("输入关键词搜索章节内容").foregroundColor(.gray)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "xmark.magnifyingglass").font(.system(size: 48)).foregroundColor(.gray)
                            Text("未找到结果").foregroundColor(.gray)
                        }
                    }
                } else {
                    List(viewModel.results) { result in
                        Button {
                            onResultTap(result.chapterIndex, result.position)
                            isPresented = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.chapterTitle).font(.headline)
                                Text(result.preview).font(.caption).foregroundColor(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("书内搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { isPresented = false }
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @Binding var isSearching: Bool
    let onSearch: () -> Void
    
    var body: some View {
        HStack {
            TextField("搜索章节内容", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit { onSearch() }
            
            if !text.isEmpty {
                Button("清除") { text = "" }
            }
            Button("搜索", action: onSearch)
        }
        .padding()
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let chapterIndex: Int
    let chapterTitle: String
    let position: Int
    let preview: String
}

@MainActor
class SearchContentViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var results: [SearchResult] = []
    @Published var searchHistory: [String] = []
    
    private let book: Book
    private var chapters: [BookChapter] = []
    
    init(book: Book) {
        self.book = book
        loadChapters()
        loadHistory()
    }
    
    private func loadChapters() {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", book.bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        chapters = (try? context.fetch(request)) ?? []
    }
    
    private func loadHistory() {
        if let history = UserDefaults.standard.stringArray(forKey: "searchContentHistory") {
            searchHistory = history
        }
    }
    
    func search() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        results = []
        
        for chapter in chapters {
            if let content = loadChapterContent(chapter),
               let range = content.range(of: searchText, options: .caseInsensitive) {
                let start = content.index(range.lowerBound, offsetBy: -30, limitedBy: content.startIndex) ?? content.startIndex
                let end = content.index(range.upperBound, offsetBy: 30, limitedBy: content.endIndex) ?? content.endIndex
                let preview = String(content[start..<end])
                
                results.append(SearchResult(
                    chapterIndex: Int(chapter.index),
                    chapterTitle: chapter.title,
                    position: content.distance(from: content.startIndex, to: range.lowerBound),
                    preview: "...\(preview)..."
                ))
            }
        }
        
        isSearching = false
        saveHistory()
    }
    
    private func loadChapterContent(_ chapter: BookChapter) -> String? {
        if let cachePath = chapter.cachePath, FileManager.default.fileExists(atPath: cachePath) {
            return try? String(contentsOfFile: cachePath, encoding: .utf8)
        }
        return nil
    }
    
    private func saveHistory() {
        if !searchHistory.contains(searchText) {
            searchHistory.insert(searchText, at: 0)
            if searchHistory.count > 10 { searchHistory.removeLast() }
            UserDefaults.standard.set(searchHistory, forKey: "searchContentHistory")
        }
    }
}