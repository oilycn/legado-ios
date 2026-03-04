//
//  BookDeduplicatorTests.swift
//  Legado-iOS Tests
//
//  BookDeduplicator 去重逻辑测试
//

import XCTest
import CoreData
@testable import Legado

final class BookDeduplicatorTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        let container = NSPersistentContainer(name: "Legado")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        await withCheckedContinuation { continuation in
            container.loadPersistentStores { _, error in
                XCTAssertNil(error)
                continuation.resume()
            }
        }
        
        context = container.viewContext
    }
    
    override func tearDown() async throws {
        context = nil
        try await super.tearDown()
    }
    
    // MARK: - 单本导入测试
    
    /// 测试导入新书
    func testImportNewBook() throws {
        let data = BookImportData(
            name: "测试书",
            author: "测试作者",
            bookUrl: "https://test.com/book1",
            tocUrl: "https://test.com/book1/toc",
            origin: "test-source",
            originName: "测试源"
        )
        
        let book = try BookDeduplicator.importBook(data, context: context)
        try context.save()
        
        XCTAssertEqual(book.name, "测试书")
        XCTAssertEqual(book.bookUrl, "https://test.com/book1")
        XCTAssertNotNil(book.bookId) // UUID 自动生成
        
        let allBooks = try context.fetch(Book.fetchRequest())
        XCTAssertEqual(allBooks.count, 1)
    }
    
    /// 测试导入已存在的 bookUrl → 更新而非创建
    func testImportDuplicateBookUrl() throws {
        // 先导入
        let data1 = BookImportData(
            name: "初始书名",
            author: "作者A",
            bookUrl: "https://test.com/book1",
            tocUrl: "",
            origin: "source1",
            originName: "源1"
        )
        let book1 = try BookDeduplicator.importBook(data1, context: context)
        try context.save()
        
        let originalUUID = book1.bookId
        
        // 再次导入同一 bookUrl，不同名字
        let data2 = BookImportData(
            name: "更新后书名",
            author: "作者B",
            bookUrl: "https://test.com/book1",
            tocUrl: "",
            origin: "source1",
            originName: "源1"
        )
        let book2 = try BookDeduplicator.importBook(data2, context: context)
        try context.save()
        
        // 应该是同一个对象
        XCTAssertEqual(book2.bookId, originalUUID, "UUID 不应改变")
        XCTAssertEqual(book2.name, "更新后书名", "名字应更新")
        
        let allBooks = try context.fetch(Book.fetchRequest())
        XCTAssertEqual(allBooks.count, 1, "应只有 1 条记录")
    }
    
    // MARK: - 批量导入测试
    
    /// 测试批量导入去重
    func testBatchDeduplicateOnImport() throws {
        let books = [
            BookImportData(name: "书1", author: "A", bookUrl: "url1", tocUrl: "", origin: "s", originName: "s"),
            BookImportData(name: "书2", author: "B", bookUrl: "url2", tocUrl: "", origin: "s", originName: "s"),
            BookImportData(name: "书3", author: "C", bookUrl: "url3", tocUrl: "", origin: "s", originName: "s"),
        ]
        
        let result = try BookDeduplicator.deduplicateOnImport(books: books, context: context)
        
        XCTAssertEqual(result.newCount, 3)
        XCTAssertEqual(result.updateCount, 0)
        XCTAssertEqual(result.totalCount, 3)
        
        // 再次导入，其中 2 本重复，1 本新增
        let books2 = [
            BookImportData(name: "书1更新", author: "A", bookUrl: "url1", tocUrl: "", origin: "s", originName: "s"),
            BookImportData(name: "书2更新", author: "B", bookUrl: "url2", tocUrl: "", origin: "s", originName: "s"),
            BookImportData(name: "书4", author: "D", bookUrl: "url4", tocUrl: "", origin: "s", originName: "s"),
        ]
        
        let result2 = try BookDeduplicator.deduplicateOnImport(books: books2, context: context)
        
        XCTAssertEqual(result2.newCount, 1)
        XCTAssertEqual(result2.updateCount, 2)
        
        let allBooks = try context.fetch(Book.fetchRequest())
        XCTAssertEqual(allBooks.count, 4, "应有 4 条不同 bookUrl 的记录")
    }
    
    // MARK: - 边界测试
    
    /// 测试空 bookUrl 的处理
    func testEmptyBookUrl() throws {
        let data = BookImportData(name: "空URL书", bookUrl: "", origin: "s", originName: "s")
        
        // 空 bookUrl 跳过
        let result = try BookDeduplicator.deduplicateOnImport(books: [data], context: context)
        XCTAssertEqual(result.newCount, 0)
        XCTAssertEqual(result.updateCount, 0)
    }
    
    /// 测试查询不存在的 bookUrl
    func testFindNonexistentBook() throws {
        let book = try BookDeduplicator.findBook(byBookUrl: "nonexistent", in: context)
        XCTAssertNil(book)
    }
    
    /// 测试 exists 方法
    func testExistsMethod() throws {
        XCTAssertFalse(try BookDeduplicator.exists(bookUrl: "url1", in: context))
        
        let data = BookImportData(name: "书", bookUrl: "url1", origin: "s", originName: "s")
        try BookDeduplicator.importBook(data, context: context)
        try context.save()
        
        XCTAssertTrue(try BookDeduplicator.exists(bookUrl: "url1", in: context))
    }
    
    // MARK: - 重复清理测试
    
    /// 测试清理重复记录
    func testCleanDuplicates() throws {
        // 手动创建重复记录（绕过 Deduplicator）
        for i in 0..<3 {
            let book = Book.create(in: context)
            book.name = "重复书 \(i)"
            book.author = "作者"
            book.bookUrl = "same-url"
            book.tocUrl = ""
            book.origin = "s"
            book.originName = "s"
            book.updatedAt = Date().addingTimeInterval(TimeInterval(i * 60))
        }
        try context.save()
        
        let before = try context.fetch(Book.fetchRequest())
        XCTAssertEqual(before.count, 3)
        
        let deleted = try BookDeduplicator.cleanDuplicates(in: context)
        XCTAssertEqual(deleted, 2, "应删除 2 条重复记录")
        
        let after = try context.fetch(Book.fetchRequest())
        XCTAssertEqual(after.count, 1, "应保留最新的 1 条")
    }
    
    // MARK: - ImportResult 测试
    
    func testImportResultDescription() {
        let result = ImportResult(newCount: 5, updateCount: 3)
        XCTAssertEqual(result.totalCount, 8)
        XCTAssertTrue(result.description.contains("5"))
        XCTAssertTrue(result.description.contains("3"))
    }
}
