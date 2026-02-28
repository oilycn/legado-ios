//
//  BookChapter+CoreDataClass.swift
//  Legado-iOS
//
//  书籍目录章节实体
//

import Foundation
import CoreData

@objc(BookChapter)
public class BookChapter: NSManagedObject {
    // MARK: - 基本信息
    @NSManaged public var chapterId: UUID
    @NSManaged public var bookId: UUID
    
    // MARK: - 章节内容
    @NSManaged public var chapterUrl: String
    @NSManaged public var index: Int32
    @NSManaged public var title: String
    
    // MARK: - 付费信息
    @NSManaged public var isVIP: Bool
    @NSManaged public var isPay: Bool
    
    // MARK: - 统计
    @NSManaged public var wordCount: Int32
    @NSManaged public var updateTime: Int64
    
    // MARK: - 缓存
    @NSManaged public var isCached: Bool
    @NSManaged public var cachePath: String?
    @NSManaged public var contentHash: String?
    
    // MARK: - 书源信息
    @NSManaged public var sourceId: String?
    @NSManaged public var tag: String?
    
    // MARK: - 关系
    @NSManaged public var book: Book?
}

// MARK: - Fetch Request
extension BookChapter {
    @nonobjc class func fetchRequest() -> NSFetchRequest<BookChapter> {
        return NSFetchRequest<BookChapter>(entityName: "BookChapter")
    }
    
    class func fetchRequest(byBookId bookId: UUID) -> NSFetchRequest<BookChapter> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "bookId == %@", bookId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        return request
    }
}

// MARK: - 计算属性
extension BookChapter {
    var displayTitle: String { title }
    
    var isPurchased: Bool {
        return !isVIP || !isPay
    }
    
    var displayIndex: String {
        return "\(index + 1)"
    }
    
    var cacheKey: String {
        return "\(bookId.uuidString)_\(index)"
    }
}

// MARK: - 初始化
extension BookChapter {
    static func create(in context: NSManagedObjectContext) -> BookChapter {
        let entity = NSEntityDescription.entity(forEntityName: "BookChapter", in: context)!
        let chapter = BookChapter(entity: entity, insertInto: context)
        chapter.chapterId = UUID()
        chapter.index = 0
        chapter.isVIP = false
        chapter.isPay = false
        chapter.isCached = false
        chapter.wordCount = 0
        chapter.updateTime = Int64(Date().timeIntervalSince1970)
        return chapter
    }
    
    static func create(
        in context: NSManagedObjectContext,
        bookId: UUID,
        url: String,
        index: Int32,
        title: String
    ) -> BookChapter {
        let chapter = create(in: context)
        chapter.bookId = bookId
        chapter.chapterUrl = url
        chapter.index = index
        chapter.title = title
        return chapter
    }
}

// MARK: - 比较
extension BookChapter {
    func compare(byIndex other: BookChapter) -> ComparisonResult {
        if index < other.index { return .orderedAscending }
        if index > other.index { return .orderedDescending }
        return .orderedSame
    }
}
