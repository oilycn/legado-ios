//
//  BookDeduplicator.swift
//  Legado-iOS
//
//  基于 bookUrl 的书籍去重工具
//  iOS 使用 UUID 作为内部主键，Android 使用 bookUrl 作为主键
//  导入/同步时通过 bookUrl 匹配去重，避免重复记录
//

import Foundation
import CoreData

final class BookDeduplicator {
    
    // MARK: - 批量去重导入
    
    /// 导入书籍数组，基于 bookUrl 去重
    /// - 已存在的 bookUrl → 更新已有记录
    /// - 不存在的 bookUrl → 创建新记录（UUID 自动生成）
    /// - Parameters:
    ///   - books: 待导入的书籍数据数组
    ///   - context: CoreData 上下文
    /// - Returns: 导入结果（新增数量、更新数量）
    @discardableResult
    static func deduplicateOnImport(
        books: [BookImportData],
        context: NSManagedObjectContext
    ) throws -> ImportResult {
        var newCount = 0
        var updateCount = 0
        
        for bookData in books {
            let bookUrl = bookData.bookUrl
            
            // 跳过空 bookUrl
            guard !bookUrl.isEmpty else { continue }
            
            let existing = try findBook(byBookUrl: bookUrl, in: context)
            
            if let existingBook = existing {
                // 已存在 → 更新
                bookData.apply(to: existingBook)
                existingBook.updatedAt = Date()
                updateCount += 1
            } else {
                // 不存在 → 创建新记录
                let newBook = Book.create(in: context)
                bookData.apply(to: newBook)
                newCount += 1
            }
        }
        
        if context.hasChanges {
            try context.save()
        }
        
        return ImportResult(newCount: newCount, updateCount: updateCount)
    }
    
    // MARK: - 单本去重导入
    
    /// 导入单本书籍，基于 bookUrl 去重
    /// - Returns: 导入或更新后的 Book 对象
    @discardableResult
    static func importBook(
        _ bookData: BookImportData,
        context: NSManagedObjectContext
    ) throws -> Book {
        let bookUrl = bookData.bookUrl
        
        if !bookUrl.isEmpty, let existing = try findBook(byBookUrl: bookUrl, in: context) {
            bookData.apply(to: existing)
            existing.updatedAt = Date()
            return existing
        } else {
            let newBook = Book.create(in: context)
            bookData.apply(to: newBook)
            return newBook
        }
    }
    
    // MARK: - 查询
    
    /// 根据 bookUrl 查找书籍
    static func findBook(byBookUrl bookUrl: String, in context: NSManagedObjectContext) throws -> Book? {
        let request = Book.fetchRequest()
        request.predicate = NSPredicate(format: "bookUrl == %@", bookUrl)
        request.fetchLimit = 1
        let results = try context.fetch(request)
        return results.first
    }
    
    /// 检查 bookUrl 是否已存在
    static func exists(bookUrl: String, in context: NSManagedObjectContext) throws -> Bool {
        let request = Book.fetchRequest()
        request.predicate = NSPredicate(format: "bookUrl == %@", bookUrl)
        return try context.count(for: request) > 0
    }
    
    // MARK: - 清理重复
    
    /// 清理已有的重复记录（保留最新的）
    /// - Returns: 删除的重复记录数量
    @discardableResult
    static func cleanDuplicates(in context: NSManagedObjectContext) throws -> Int {
        let request = Book.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        let allBooks = try context.fetch(request)
        
        var seenUrls = Set<String>()
        var deletedCount = 0
        
        for book in allBooks {
            let url = book.bookUrl
            guard !url.isEmpty else { continue }
            
            if seenUrls.contains(url) {
                // 重复 → 删除（已按 updatedAt 降序，先出现的是最新的）
                context.delete(book)
                deletedCount += 1
            } else {
                seenUrls.insert(url)
            }
        }
        
        if context.hasChanges {
            try context.save()
        }
        
        return deletedCount
    }
}

// MARK: - 导入数据结构

/// 书籍导入数据（与 CoreData 解耦，用于 JSON 解析 → 导入流程）
struct BookImportData: Codable {
    var name: String = ""
    var author: String = ""
    var bookUrl: String = ""
    var tocUrl: String = ""
    var origin: String = ""
    var originName: String = ""
    var kind: String?
    var coverUrl: String?
    var intro: String?
    var latestChapterTitle: String?
    var latestChapterTime: Int64 = 0
    var totalChapterNum: Int32 = 0
    var durChapterTitle: String?
    var durChapterIndex: Int32 = 0
    var durChapterPos: Int32 = 0
    var durChapterTime: Int64 = 0
    var canUpdate: Bool = true
    var order: Int32 = 0
    var originOrder: Int32 = 0
    var customTag: String?
    var group: Int64 = 0
    var customCoverUrl: String?
    var customIntro: String?
    var type: Int32 = 0
    var wordCount: String?
    var variable: String?
    var charset: String?
    
    /// 将导入数据应用到 Book 实体
    func apply(to book: Book) {
        book.name = name
        book.author = author
        book.bookUrl = bookUrl
        book.tocUrl = tocUrl
        book.origin = origin
        book.originName = originName
        book.kind = kind
        book.coverUrl = coverUrl
        book.intro = intro
        book.latestChapterTitle = latestChapterTitle
        book.latestChapterTime = latestChapterTime
        book.totalChapterNum = totalChapterNum
        book.durChapterTitle = durChapterTitle
        book.durChapterIndex = durChapterIndex
        book.durChapterPos = durChapterPos
        book.durChapterTime = durChapterTime
        book.canUpdate = canUpdate
        book.order = order
        book.originOrder = originOrder
        book.customTag = customTag
        book.group = group
        book.customCoverUrl = customCoverUrl
        book.customIntro = customIntro
        book.type = type
        book.wordCount = wordCount
        book.variable = variable
        book.charset = charset
    }
}

// MARK: - 导入结果

struct ImportResult {
    let newCount: Int
    let updateCount: Int
    
    var totalCount: Int { newCount + updateCount }
    var description: String {
        "导入完成：新增 \(newCount) 本，更新 \(updateCount) 本"
    }
}
