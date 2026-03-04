//
//  ReaderViewModelTests.swift
//  Legado-iOS Tests
//
//  阅读器 ViewModel 单元测试
//

import XCTest
import CoreData
@testable import Legado

@MainActor
final class ReaderViewModelTests: XCTestCase {
    
    var viewModel: ReaderViewModel!
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        context = CoreDataStack.shared.viewContext
        viewModel = ReaderViewModel()
    }
    
    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }
    
    // MARK: - 测试用例
    
    /// 测试加载章节
    func testLoadChapter() async throws {
        let book = Book.create(in: context)
        book.name = "测试书籍"
        
        let chapter = BookChapter.create(
            in: context,
            bookId: book.bookId,
            url: "chapter_1",
            index: 0,
            title: "第一章"
        )
        
        try context.save()
        
        viewModel.currentBook = book
        viewModel.currentChapter = chapter
        
        await viewModel.loadChapter()
        
        XCTAssertNotNil(viewModel.currentContent)
    }
    
    /// 测试下一章
    func testNextChapter() async throws {
        let book = Book.create(in: context)
        book.totalChapterNum = 3
        
        let chapter1 = BookChapter.create(in: context, bookId: book.bookId, url: "c1", index: 0, title: "第一章")
        let chapter2 = BookChapter.create(in: context, bookId: book.bookId, url: "c2", index: 1, title: "第二章")
        
        try context.save()
        
        viewModel.currentBook = book
        viewModel.currentChapter = chapter1
        viewModel.currentChapterIndex = 0
        
        await viewModel.nextChapter()
        
        XCTAssertEqual(viewModel.currentChapterIndex, 1)
        XCTAssertEqual(viewModel.currentChapter?.title, "第二章")
    }
    
    /// 测试上一章
    func testPreviousChapter() async throws {
        let book = Book.create(in: context)
        book.totalChapterNum = 3
        
        let chapter1 = BookChapter.create(in: context, bookId: book.bookId, url: "c1", index: 0, title: "第一章")
        let chapter2 = BookChapter.create(in: context, bookId: book.bookId, url: "c2", index: 1, title: "第二章")
        
        try context.save()
        
        viewModel.currentBook = book
        viewModel.currentChapter = chapter2
        viewModel.currentChapterIndex = 1
        
        await viewModel.prevChapter()
        
        XCTAssertEqual(viewModel.currentChapterIndex, 0)
        XCTAssertEqual(viewModel.currentChapter?.title, "第一章")
    }
    
    /// 测试阅读进度保存
    func testReadingProgressSave() async throws {
        let book = Book.create(in: context)
        book.name = "测试书籍"
        book.totalChapterNum = 10
        
        let chapter = BookChapter.create(
            in: context,
            bookId: book.bookId,
            url: "chapter_5",
            index: 4,
            title: "第五章"
        )
        
        try context.save()
        
        viewModel.currentBook = book
        viewModel.currentChapter = chapter
        viewModel.currentChapterIndex = 4
        viewModel.durChapterPos = 1000
        
        await viewModel.saveReadingProgress()
        
        XCTAssertEqual(book.durChapterIndex, 4)
        XCTAssertEqual(book.durChapterPos, 1000)
        XCTAssertEqual(book.durChapterTitle, "第五章")
    }

    func testPagingProgressUpdatesDurChapterPos() async throws {
        let book = Book.create(in: context)
        book.name = "测试书籍"

        let chapter = BookChapter.create(
            in: context,
            bookId: book.bookId,
            url: "chapter_1",
            index: 0,
            title: "第一章"
        )

        try context.save()

        viewModel.currentBook = book
        viewModel.currentChapter = chapter
        viewModel.currentChapterIndex = 0

        viewModel.currentPageIndex = 5

        XCTAssertEqual(viewModel.durChapterPos, 5)
        XCTAssertEqual(book.durChapterPos, 5)
    }
    
    /// 测试字体大小调整
    func testFontSizeAdjustment() async {
        XCTAssertEqual(viewModel.fontSize, 18)
        
        await viewModel.setFontSize(24)
        XCTAssertEqual(viewModel.fontSize, 24)
        
        await viewModel.setFontSize(14)
        XCTAssertEqual(viewModel.fontSize, 14)
        
        // 测试边界
        await viewModel.setFontSize(8)
        XCTAssertGreaterThanOrEqual(viewModel.fontSize, 8)
        
        await viewModel.setFontSize(32)
        XCTAssertLessThanOrEqual(viewModel.fontSize, 32)
    }
    
    /// 测试主题切换
    func testThemeChange() async {
        XCTAssertEqual(viewModel.theme, .light)
        
        await viewModel.setTheme(.dark)
        XCTAssertEqual(viewModel.theme, .dark)
        
        await viewModel.setTheme(.light)
        XCTAssertEqual(viewModel.theme, .light)
    }
    
    /// 测试目录加载
    func testChapterListLoading() async throws {
        let book = Book.create(in: context)
        book.name = "测试书籍"
        book.totalChapterNum = 10
        
        for i in 0..<10 {
            BookChapter.create(
                in: context,
                bookId: book.bookId,
                url: "chapter_\(i)",
                index: Int32(i),
                title: "第\(i + 1)章"
            )
        }
        
        try context.save()
        
        viewModel.currentBook = book
        await viewModel.loadChapterList()
        
        XCTAssertEqual(viewModel.chapterList.count, 10)
    }
}
