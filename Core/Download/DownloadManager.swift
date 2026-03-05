//
//  DownloadManager.swift
//  Legado-iOS
//
//  后台下载管理器 - Phase 6
//

import Foundation
import CoreData

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloads: [DownloadTask] = []
    @Published var isDownloading: Bool = false
    
    private var urlSession: URLSession?
    private var backgroundCompletionHandler: (() -> Void)?
    
    struct DownloadTask: Identifiable {
        let id = UUID()
        let bookId: UUID
        let bookName: String
        var progress: Double = 0
        var status: Status = .pending
        
        enum Status { case pending, downloading, paused, completed, failed }
    }
    
    private init() {
        setupURLSession()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.legado.ios.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }
    
    func downloadChapters(for book: Book, chapterIndices: [Int]) async {
        // 创建下载任务
        let task = DownloadTask(bookId: book.bookId, bookName: book.name)
        downloads.append(task)
        
        isDownloading = true
        
        // 获取章节列表
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<BookChapter> = BookChapter.fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@ AND index IN %@", book.bookId as CVarArg, chapterIndices.map { Int32($0) })
        
        guard let chapters = try? context.fetch(request) else { return }
        
        for chapter in chapters {
            await downloadChapter(chapter, for: book)
            
            // 更新进度
            if let index = downloads.firstIndex(where: { $0.bookId == book.bookId }) {
                downloads[index].progress = Double(chapter.index + 1) / Double(chapters.count)
            }
        }
        
        // 完成下载
        if let index = downloads.firstIndex(where: { $0.bookId == book.bookId }) {
            downloads[index].status = .completed
            downloads[index].progress = 1.0
        }
        
        isDownloading = false
    }
    
    private func downloadChapter(_ chapter: BookChapter, for book: Book) async {
        guard let source = book.source else { return }
        
        do {
            let content = try await WebBook.getContent(source: source, book: book, chapter: chapter)
            
            // 缓存内容
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("ChapterCache")
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            let fileURL = cacheDir.appendingPathComponent("\(chapter.chapterId.uuidString).txt")
            try content.content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // 更新章节
            chapter.cachePath = fileURL.path
            chapter.isCached = true
            try chapter.managedObjectContext?.save()
        } catch {
            print("下载章节失败: \(error)")
        }
    }
    
    func pauseDownload(for bookId: UUID) {
        if let index = downloads.firstIndex(where: { $0.bookId == bookId }) {
            downloads[index].status = .paused
        }
    }
    
    func cancelDownload(for bookId: UUID) {
        downloads.removeAll { $0.bookId == bookId }
    }
}