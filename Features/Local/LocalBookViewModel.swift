//
//  LocalBookViewModel.swift
//  Legado-iOS
//
//  本地书籍 ViewModel
//

import Foundation
import CoreData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class LocalBookViewModel: ObservableObject {
    @Published var localBooks: [Book] = []
    @Published var isImporting = false
    @Published var errorMessage: String?
    
    // MARK: - 导入本地书籍
    func importBook(url: URL) async throws -> Book {
        isImporting = true
        
        do {
            let context = CoreDataStack.shared.viewContext
            let book = Book.create(in: context)
            
            // 获取文件信息
            let fileName = url.lastPathComponent
            let fileExtension = url.pathExtension.lowercased()
            
            // 设置基本信息
            book.name = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
            book.author = "未知"
            book.type = fileExtension == "epub" ? 1 : 0
            book.origin = "local"
            book.originName = fileName
            book.bookUrl = url.path
            book.tocUrl = ""
            book.canUpdate = false  // 本地书籍不更新
            
            // 根据类型解析
            if fileExtension == "txt" {
                try await parseTXT(file: url, book: book)
            } else if fileExtension == "epub" {
                try await parseEPUB(file: url, book: book)
            } else {
                throw LocalBookError.unsupportedFormat
            }
            
            // 保存
            try CoreDataStack.shared.save()
            
            isImporting = false
            await loadLocalBooks()
            
            return book
        } catch {
            isImporting = false
            throw error
        }
    }
    
    // MARK: - 加载本地书籍
    func loadLocalBooks() async {
        do {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "origin == 'local'")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            localBooks = try CoreDataStack.shared.viewContext.fetch(request)
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: - 解析 TXT
    private func parseTXT(file url: URL, book: Book) async throws {
        // 尝试检测编码
        let encoding = try await detectEncoding(file: url)
        
        // 读取内容
        let content = try String(contentsOf: url, encoding: encoding)
        
        // 智能分章
        let chapters = splitChapters(content: content)
        
        // 设置章节数
        book.totalChapterNum = Int32(chapters.count)
        
        // 创建章节记录
        let context = CoreDataStack.shared.viewContext
        for (index, chapter) in chapters.enumerated() {
            let bookChapter = BookChapter.create(
                in: context,
                bookId: book.bookId,
                url: "\(index)",
                index: Int32(index),
                title: chapter.title
            )
            bookChapter.wordCount = Int32(chapter.content.count)
            bookChapter.isCached = true
            bookChapter.cachePath = url.path
        }
        
        // 设置第一章为当前
        book.durChapterIndex = 0
        if let firstChapter = chapters.first {
            book.durChapterTitle = firstChapter.title
        }
    }
    
    // MARK: - 解析 EPUB
    private func parseEPUB(file url: URL, book: Book) async throws {
        // 使用 EPUBParser 解析
        let epubBook = try await EPUBParser.parse(file: url)
        
        // 设置书籍信息
        book.name = epubBook.title
        book.author = epubBook.author
        book.totalChapterNum = Int32(epubBook.chapters.count)
        
        // 保存封面
        if let coverData = epubBook.coverImage {
            let coverURL = try await saveCoverImage(coverData, bookId: book.bookId)
            book.coverUrl = coverURL.path
        }
        
        // 创建章节记录
        let context = CoreDataStack.shared.viewContext
        for chapter in epubBook.chapters {
            let bookChapter = BookChapter.create(
                in: context,
                bookId: book.bookId,
                url: chapter.href,
                index: Int32(chapter.index),
                title: chapter.title
            )
            bookChapter.wordCount = Int32(chapter.content.count)
            bookChapter.isCached = true
        }
        
        // 保存元数据
        if let description = epubBook.metadata["description"] {
            book.intro = description
        }
        
        // 设置第一章
        book.durChapterIndex = 0
        if let firstChapter = epubBook.chapters.first {
            book.durChapterTitle = firstChapter.title
        }
    }
    
    // MARK: - 检测编码
    private func detectEncoding(file url: URL) async throws -> String.Encoding {
        // 读取前 1000 字节检测编码
        let handle = try FileHandle(forReadingFrom: url)
        let data = handle.readData(ofLength: 1000)
        try handle.close()
        
        // 检测 BOM
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return .utf8
        } else if data.starts(with: [0xFF, 0xFE]) {
            return .utf16
        } else if data.starts(with: [0xFE, 0xFF]) {
            return .utf16BigEndian
        }
        
        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        if String(data: data, encoding: gb18030) != nil {
            return gb18030
        }
        
        // 默认 UTF-8
        return .utf8
    }
    
    // MARK: - 智能分章
    private func splitChapters(content: String) -> [(title: String, content: String)] {
        // 章节匹配正则
        let chapterPatterns = [
            #"^第 [零一二三四五六七八九十百千万 0-9]+[章回卷节部篇]"#,
            #"^第 [0-9]+ 章"#,
            #"^Chapter [0-9]+"#,
            #"^\s*第 [0-9 一二三四五六七八九十]+节"#
        ]
        
        var chapters: [(title: String, content: String)] = []
        var currentTitle: String?
        var currentContent = ""
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            var isChapterStart = false
            
            for pattern in chapterPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        isChapterStart = true
                        break
                    }
                }
            }
            
            if isChapterStart {
                // 保存前一章
                if let title = currentTitle, !currentContent.isEmpty {
                    chapters.append((title, currentContent.trimmingCharacters(in: .whitespaces)))
                }
                
                // 新章节
                currentTitle = line.trimmingCharacters(in: .whitespaces)
                currentContent = ""
            } else {
                currentContent += line + "\n"
            }
        }
        
        // 添加最后一章
        if let title = currentTitle, !currentContent.isEmpty {
            chapters.append((title, currentContent.trimmingCharacters(in: .whitespaces)))
        }
        
        // 如果没有检测到章节，返回全部内容作为一章
        if chapters.isEmpty {
            return [("第一章", content)]
        }
        
        return chapters
    }
    
    // MARK: - 保存封面图片
    private func saveCoverImage(_ data: Data, bookId: UUID) async throws -> URL {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bookDir = documentsPath.appendingPathComponent("covers", isDirectory: true)
        
        if !fileManager.fileExists(atPath: bookDir.path) {
            try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
        }
        
        let coverURL = bookDir.appendingPathComponent("\(bookId.uuidString).jpg")
        try data.write(to: coverURL)
        
        return coverURL
    }
    
    // MARK: - 删除本地书籍
    func deleteBook(_ book: Book) {
        // 如果是本地文件，删除文件
        if book.origin == "local" {
            try? FileManager.default.removeItem(atPath: book.bookUrl)
        }
        
        CoreDataStack.shared.viewContext.delete(book)
        try? CoreDataStack.shared.save()
        
        Task {
            await loadLocalBooks()
        }
    }
}

// MARK: - 错误类型
enum LocalBookError: LocalizedError {
    case unsupportedFormat
    case fileNotFound
    case parseFailed
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "不支持的文件格式"
        case .fileNotFound: return "文件不存在"
        case .parseFailed: return "解析失败"
        case .notImplemented: return "功能尚未实现"
        }
    }
}

// MARK: - 本地书籍视图
struct LocalBookView: View {
    @StateObject private var viewModel = LocalBookViewModel()
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.localBooks.isEmpty {
                    EmptyStateView(
                        title: "暂无本地书籍",
                        subtitle: "点击右上角导入 TXT 或 EPUB 文件",
                        imageName: "book.closed"
                    )
                } else {
                    List {
                        ForEach(viewModel.localBooks, id: \.bookId) { book in
                        HStack {
                            BookCoverView(url: book.coverUrl)
                                .frame(width: 50, height: 70)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            
                            VStack(alignment: .leading) {
                                Text(book.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text("\(book.totalChapterNum) 章")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(book.originName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.deleteBook(book)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("本地书籍")
            .toolbar {
                ToolbarItem {
                    Button(action: { showingFilePicker = true }) {
                        Label("导入", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.plainText, .epub],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        Task {
                            let granted = url.startAccessingSecurityScopedResource()
                            defer {
                                if granted {
                                    url.stopAccessingSecurityScopedResource()
                                }
                            }
                            try? await viewModel.importBook(url: url)
                        }
                    }
                case .failure(let error):
                    print("导入失败：\(error)")
                }
            }
            .task {
                await viewModel.loadLocalBooks()
            }
        }
    }
}

#Preview {
    LocalBookView()
}
