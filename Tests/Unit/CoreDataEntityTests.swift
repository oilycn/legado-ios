//
//  CoreDataEntityTests.swift
//  Legado-iOS Tests
//
//  全部 19 个 CoreData 实体的运行时验证测试
//  验证 xcdatamodeld 注册正确、fetchRequest 可执行、CRUD 正常
//

import XCTest
import CoreData
@testable import Legado

final class CoreDataEntityTests: XCTestCase {
    
    var context: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        // 使用内存中的 store 避免影响真实数据
        let container = NSPersistentContainer(name: "Legado")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        await withCheckedContinuation { continuation in
            container.loadPersistentStores { _, error in
                XCTAssertNil(error, "CoreData store 加载失败: \(error?.localizedDescription ?? "")")
                continuation.resume()
            }
        }
        
        context = container.viewContext
    }
    
    override func tearDown() async throws {
        context = nil
        try await super.tearDown()
    }
    
    // MARK: - 实体注册验证（19 个实体）
    
    /// 验证所有 19 个实体在 NSManagedObjectModel 中注册
    func testAllEntitiesRegistered() {
        let entityNames = [
            "Book", "BookSource", "BookChapter", "Bookmark", "ReplaceRule",
            "BookGroup", "SearchBook", "SearchKeyword",
            "RssSource", "RssArticle", "RssReadRecord", "RssStar",
            "CacheEntry", "Cookie", "ReadRecord",
            "HttpTTS", "DictRule", "RuleSub", "TxtTocRule"
        ]
        
        for name in entityNames {
            let entity = NSEntityDescription.entity(forEntityName: name, in: context)
            XCTAssertNotNil(entity, "实体 '\(name)' 未在 xcdatamodeld 中注册")
        }
    }
    
    /// 验证实体总数为 19
    func testEntityCount() {
        let model = context.persistentStoreCoordinator?.managedObjectModel
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.entities.count, 19, "应有 19 个 CoreData 实体")
    }
    
    // MARK: - fetchRequest 验证
    
    func testBookFetchRequest() throws {
        let request = Book.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testBookSourceFetchRequest() throws {
        let request = BookSource.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testBookChapterFetchRequest() throws {
        let request = BookChapter.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testBookmarkFetchRequest() throws {
        let request = Bookmark.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testReplaceRuleFetchRequest() throws {
        let request = ReplaceRule.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testBookGroupFetchRequest() throws {
        let request = BookGroup.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testSearchBookFetchRequest() throws {
        let request = SearchBook.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testSearchKeywordFetchRequest() throws {
        let request = SearchKeyword.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testRssSourceFetchRequest() throws {
        let request = RssSource.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testRssArticleFetchRequest() throws {
        let request = RssArticle.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testRssReadRecordFetchRequest() throws {
        let request = RssReadRecord.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testRssStarFetchRequest() throws {
        let request = RssStar.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testCacheEntryFetchRequest() throws {
        let request = CacheEntry.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testCookieFetchRequest() throws {
        let request = Cookie.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testReadRecordFetchRequest() throws {
        let request = ReadRecord.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testHttpTTSFetchRequest() throws {
        let request = HttpTTS.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testDictRuleFetchRequest() throws {
        let request = DictRule.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testRuleSubFetchRequest() throws {
        let request = RuleSub.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    func testTxtTocRuleFetchRequest() throws {
        let request = TxtTocRule.fetchRequest()
        let results = try context.fetch(request)
        XCTAssertNotNil(results)
    }
    
    // MARK: - CRUD 测试（每个新实体）
    
    func testBookGroupCRUD() throws {
        let group = BookGroup.create(in: context, groupName: "测试分组")
        XCTAssertEqual(group.groupName, "测试分组")
        XCTAssertTrue(group.enableRefresh)
        XCTAssertTrue(group.show)
        
        try context.save()
        
        let fetched = try context.fetch(BookGroup.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.groupName, "测试分组")
        
        context.delete(group)
        try context.save()
        
        let afterDelete = try context.fetch(BookGroup.fetchRequest())
        XCTAssertEqual(afterDelete.count, 0)
    }
    
    func testSearchBookCRUD() throws {
        let sb = SearchBook.create(in: context)
        sb.name = "搜索测试"
        sb.bookUrl = "https://test.com/book1"
        try context.save()
        
        let fetched = try context.fetch(SearchBook.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "搜索测试")
    }
    
    func testSearchKeywordCRUD() throws {
        let kw = SearchKeyword.create(in: context, word: "关键词测试")
        XCTAssertEqual(kw.word, "关键词测试")
        XCTAssertEqual(kw.usage, 1)
        try context.save()
        
        let fetched = try context.fetch(SearchKeyword.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
    }
    
    func testRssSourceCRUD() throws {
        let source = RssSource.create(in: context)
        source.sourceName = "RSS测试源"
        source.sourceUrl = "https://rss.test.com"
        try context.save()
        
        let fetched = try context.fetch(RssSource.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sourceName, "RSS测试源")
    }
    
    func testRssArticleCRUD() throws {
        let article = RssArticle.create(in: context)
        article.title = "RSS文章测试"
        article.origin = "test-origin"
        article.link = "https://test.com/article"
        try context.save()
        
        let fetched = try context.fetch(RssArticle.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
    }
    
    func testRssReadRecordCRUD() throws {
        let record = RssReadRecord.create(in: context, origin: "test", link: "https://test.com")
        XCTAssertEqual(record.record, "test##https://test.com")
        XCTAssertTrue(record.read)
        try context.save()
        
        let fetched = try context.fetch(RssReadRecord.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
    }
    
    func testRssStarCRUD() throws {
        let star = RssStar.create(in: context)
        star.title = "收藏"
        star.origin = "test"
        star.link = "https://test.com"
        try context.save()
        
        let fetched = try context.fetch(RssStar.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
    }
    
    func testCacheEntryCRUD() throws {
        let cache = CacheEntry.create(in: context, key: "test-key", value: "test-value")
        XCTAssertFalse(cache.isExpired)
        try context.save()
        
        let fetched = try context.fetch(CacheEntry.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.key, "test-key")
    }
    
    func testCookieCRUD() throws {
        let cookie = Cookie.create(in: context, url: "https://test.com", cookie: "session=abc123")
        try context.save()
        
        let fetched = try context.fetch(Cookie.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.cookie, "session=abc123")
    }
    
    func testHttpTTSCRUD() throws {
        let tts = HttpTTS.create(in: context)
        tts.name = "TTS测试"
        tts.url = "https://tts.test.com"
        try context.save()
        
        let fetched = try context.fetch(HttpTTS.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
    }
    
    func testDictRuleCRUD() throws {
        let rule = DictRule.create(in: context)
        rule.name = "词典规则测试"
        rule.urlRule = "https://dict.test.com/?word={{key}}"
        rule.showRule = "body"
        try context.save()
        
        let fetched = try context.fetch(DictRule.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
    }
    
    func testRuleSubCRUD() throws {
        let sub = RuleSub.create(in: context)
        sub.name = "订阅测试"
        sub.url = "https://sub.test.com"
        sub.type = 0
        try context.save()
        
        let fetched = try context.fetch(RuleSub.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
    }
    
    func testTxtTocRuleCRUD() throws {
        let toc = TxtTocRule.create(in: context)
        toc.name = "TXT目录规则测试"
        toc.rule = "^第.+章"
        try context.save()
        
        let fetched = try context.fetch(TxtTocRule.fetchRequest())
        XCTAssertEqual(fetched.count, 1)
    }
    
    // MARK: - 关系测试
    
    func testBookChapterRelationship() throws {
        let book = Book.create(in: context)
        book.name = "关系测试书"
        book.author = "测试作者"
        book.bookUrl = "https://test.com/book"
        book.tocUrl = ""
        book.origin = "test"
        book.originName = "测试源"
        
        let chapter = BookChapter(context: context)
        chapter.chapterId = UUID()
        chapter.bookId = book.bookId
        chapter.chapterUrl = "https://test.com/chapter1"
        chapter.index = 0
        chapter.title = "第一章"
        chapter.book = book
        
        try context.save()
        
        // 验证关系
        XCTAssertEqual(book.chapters?.count, 1)
        XCTAssertEqual(chapter.book?.name, "关系测试书")
    }
    
    func testBookBookmarkRelationship() throws {
        let book = Book.create(in: context)
        book.name = "书签测试书"
        book.author = "测试作者"
        book.bookUrl = "https://test.com/book"
        book.tocUrl = ""
        book.origin = "test"
        book.originName = "测试源"
        
        let bookmark = Bookmark(context: context)
        bookmark.bookmarkId = UUID()
        bookmark.bookId = book.bookId
        bookmark.chapterIndex = 0
        bookmark.chapterTitle = "第一章"
        bookmark.content = "书签内容"
        bookmark.createDate = Date()
        bookmark.book = book
        
        try context.save()
        
        // 验证关系
        XCTAssertEqual(book.bookmarks?.count, 1)
        XCTAssertEqual(bookmark.book?.name, "书签测试书")
    }
    
    func testBookSourceRelationship() throws {
        let source = BookSource(context: context)
        source.sourceId = UUID()
        source.bookSourceUrl = "https://source.test.com"
        source.bookSourceName = "测试源"
        
        let book = Book.create(in: context)
        book.name = "源关系测试"
        book.author = "测试"
        book.bookUrl = "https://test.com/book"
        book.tocUrl = ""
        book.origin = source.bookSourceUrl
        book.originName = source.bookSourceName
        book.source = source
        
        try context.save()
        
        // 验证关系
        XCTAssertEqual(source.books?.count, 1)
        XCTAssertEqual(book.source?.bookSourceName, "测试源")
    }
    
    // MARK: - 级联删除测试
    
    func testCascadeDeleteBookChapters() throws {
        let book = Book.create(in: context)
        book.name = "级联删除测试"
        book.author = "测试"
        book.bookUrl = "https://test.com/cascade"
        book.tocUrl = ""
        book.origin = "test"
        book.originName = "测试"
        
        for i in 0..<5 {
            let chapter = BookChapter(context: context)
            chapter.chapterId = UUID()
            chapter.bookId = book.bookId
            chapter.chapterUrl = "https://test.com/chapter\(i)"
            chapter.index = Int32(i)
            chapter.title = "第\(i)章"
            chapter.book = book
        }
        
        try context.save()
        
        // 验证 5 个章节存在
        let chaptersBefore = try context.fetch(BookChapter.fetchRequest())
        XCTAssertEqual(chaptersBefore.count, 5)
        
        // 删除 book → 章节应级联删除
        context.delete(book)
        try context.save()
        
        let chaptersAfter = try context.fetch(BookChapter.fetchRequest())
        XCTAssertEqual(chaptersAfter.count, 0, "删除 Book 后其章节应级联删除")
    }
}
