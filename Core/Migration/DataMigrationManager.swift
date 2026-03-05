//
//  DataMigrationManager.swift
//  Legado-iOS
//
//  数据迁移管理器 - 支持从 Android Legado 和其他阅读应用迁移数据
//  P2-T6 实现
//

import Foundation
import CoreData
import UIKit

// MARK: - 迁移类型

enum MigrationType: String, CaseIterable {
    case legadoAndroid = "Legado Android"
    case legadoIOS = "Legado iOS"
    case jsonBackup = "JSON 备份"
    
    var displayName: String { rawValue }
}

// MARK: - 迁移结果

struct MigrationResult {
    var booksImported: Int = 0
    var sourcesImported: Int = 0
    var bookmarksImported: Int = 0
    var rulesImported: Int = 0
    var errors: [String] = []
    
    var isSuccess: Bool {
        booksImported > 0 || sourcesImported > 0 || bookmarksImported > 0 || rulesImported > 0
    }
    
    var summary: String {
        var parts: [String] = []
        if booksImported > 0 { parts.append("书籍 \(booksImported) 本") }
        if sourcesImported > 0 { parts.append("书源 \(sourcesImported) 个") }
        if bookmarksImported > 0 { parts.append("书签 \(bookmarksImported) 个") }
        if rulesImported > 0 { parts.append("替换规则 \(rulesImported) 条") }
        
        return parts.isEmpty ? "未导入任何数据" : "成功导入：" + parts.joined(separator: "、")
    }
}

// MARK: - 数据迁移管理器

@MainActor
class DataMigrationManager: ObservableObject {
    
    // MARK: - Published 属性
    
    @Published var isMigrating = false
    @Published var migrationProgress: Double = 0
    @Published var migrationResult: MigrationResult?
    
    // MARK: - 公开方法
    
    /// 从文件迁移数据
    func migrateFromFile(_ url: URL, type: MigrationType) async -> MigrationResult {
        isMigrating = true
        migrationProgress = 0
        
        var result = MigrationResult()
        
        do {
            let data = try Data(contentsOf: url)
            
            switch type {
            case .legadoAndroid:
                result = try await migrateFromLegadoAndroid(data)
            case .legadoIOS:
                result = try await migrateFromLegadoIOS(data)
            case .jsonBackup:
                result = try await migrateFromJSON(data)
            }
        } catch {
            result.errors.append(error.localizedDescription)
        }
        
        migrationResult = result
        isMigrating = false
        migrationProgress = 1.0
        
        return result
    }
    
    /// 从 Android Legado 备份迁移
    func migrateFromLegadoAndroid(_ data: Data) async throws -> MigrationResult {
        var result = MigrationResult()
        
        // Android Legado 使用 ZIP 压缩的备份
        // 这里假设已经解压，处理 JSON 文件
        
        // 尝试解析为字典格式（Android 备份结构）
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 处理书籍
            if let books = json["bookshelf"] as? [[String: Any]] {
                result.booksImported = try await importBooks(books, format: .android)
            }
            
            // 处理书源
            if let sources = json["bookSource"] as? [[String: Any]] {
                result.sourcesImported = try await importSources(sources, format: .android)
            }
            
            // 处理书签
            if let bookmarks = json["bookmark"] as? [[String: Any]] {
                result.bookmarksImported = try await importBookmarks(bookmarks, format: .android)
            }
            
            // 处理替换规则
            if let rules = json["replaceRule"] as? [[String: Any]] {
                result.rulesImported = try await importRules(rules, format: .android)
            }
        }
        // 尝试解析为数组格式（单个文件）
        else if let sources = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // 可能是书源数组
            result.sourcesImported = try await importSources(sources, format: .android)
        }
        
        return result
    }
    
    /// 从 iOS Legado 备份迁移
    func migrateFromLegadoIOS(_ data: Data) async throws -> MigrationResult {
        var result = MigrationResult()
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MigrationError.invalidFormat
        }
        
        if let books = json["books"] as? [[String: Any]] {
            result.booksImported = try await importBooks(books, format: .ios)
        }
        
        if let sources = json["sources"] as? [[String: Any]] {
            result.sourcesImported = try await importSources(sources, format: .ios)
        }
        
        if let bookmarks = json["bookmarks"] as? [[String: Any]] {
            result.bookmarksImported = try await importBookmarks(bookmarks, format: .ios)
        }
        
        if let rules = json["rules"] as? [[String: Any]] {
            result.rulesImported = try await importRules(rules, format: .ios)
        }
        
        return result
    }
    
    /// 从通用 JSON 备份迁移
    func migrateFromJSON(_ data: Data) async throws -> MigrationResult {
        var result = MigrationResult()
        
        // 尝试自动检测格式
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            // 检测是书源还是书籍
            if let first = array.first {
                if first["bookSourceUrl"] != nil {
                    result.sourcesImported = try await importSources(array, format: .auto)
                } else if first["bookUrl"] != nil {
                    result.booksImported = try await importBooks(array, format: .auto)
                }
            }
        } else if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 字典格式
            result = try await migrateFromLegadoIOS(data)
        }
        
        return result
    }
    
    /// 导出数据
    func exportData(includeBooks: Bool = true, includeSources: Bool = true, includeBookmarks: Bool = true, includeRules: Bool = true) -> Data? {
        var exportData: [String: Any] = [
            "version": "1.0",
            "exportTime": Date().timeIntervalSince1970,
            "platform": "iOS"
        ]
        
        let context = CoreDataStack.shared.viewContext
        
        if includeBooks {
            let request = Book.fetchRequest()
            if let books = try? context.fetch(request) {
                exportData["books"] = books.map { exportBook($0) }
            }
        }
        
        if includeSources {
            let request = BookSource.fetchRequest()
            if let sources = try? context.fetch(request) {
                exportData["sources"] = sources.map { exportSource($0) }
            }
        }
        
        if includeBookmarks {
            let request = Bookmark.fetchRequest()
            if let bookmarks = try? context.fetch(request) {
                exportData["bookmarks"] = bookmarks.map { exportBookmark($0) }
            }
        }
        
        if includeRules {
            let request = ReplaceRule.fetchRequest()
            if let rules = try? context.fetch(request) {
                exportData["rules"] = rules.map { exportRule($0) }
            }
        }
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    // MARK: - 私有方法
    
    private enum ImportFormat {
        case android
        case ios
        case auto
    }
    
    private func importBooks(_ books: [[String: Any]], format: ImportFormat) async throws -> Int {
        let context = CoreDataStack.shared.viewContext
        var count = 0
        
        for bookData in books {
            let book = Book.create(in: context)
            
            // 映射字段
            book.name = bookData["name"] as? String ?? bookData["bookName"] as? String ?? ""
            book.author = bookData["author"] as? String ?? ""
            book.bookUrl = bookData["bookUrl"] as? String ?? ""
            book.tocUrl = bookData["tocUrl"] as? String ?? ""
            book.coverUrl = bookData["coverUrl"] as? String
            book.intro = bookData["intro"] as? String
            
            // 阅读进度
            if let durChapterIndex = bookData["durChapterIndex"] as? Int {
                book.durChapterIndex = Int32(durChapterIndex)
            }
            if let durChapterPos = bookData["durChapterPos"] as? Int {
                book.durChapterPos = Int32(durChapterPos)
            }
            
            // 书源信息
            book.origin = bookData["origin"] as? String ?? bookData["bookSourceUrl"] as? String ?? ""
            book.originName = bookData["originName"] as? String ?? bookData["bookSourceName"] as? String ?? ""

            
            count += 1
            migrationProgress = Double(count) / Double(books.count) * 0.4
        }
        
        try CoreDataStack.shared.save()
        return count
    }
    
    private func importSources(_ sources: [[String: Any]], format: ImportFormat) async throws -> Int {
        let context = CoreDataStack.shared.viewContext
        var count = 0
        
        for sourceData in sources {
            let source = BookSource.create(in: context)
            
            source.bookSourceUrl = sourceData["bookSourceUrl"] as? String ?? ""
            source.bookSourceName = sourceData["bookSourceName"] as? String ?? ""
            source.bookSourceGroup = sourceData["bookSourceGroup"] as? String
            source.searchUrl = sourceData["searchUrl"] as? String
            source.exploreUrl = sourceData["exploreUrl"] as? String
            source.header = sourceData["header"] as? String
            source.enabled = sourceData["enabled"] as? Bool ?? true
            source.enabledExplore = sourceData["enabledExplore"] as? Bool ?? true
            
            if let weight = sourceData["weight"] as? Int {
                source.weight = Int32(weight)
            }
            
            // 规则
            if let ruleSearch = sourceData["ruleSearch"] as? [String: Any] {
                source.ruleSearchData = try? JSONSerialization.data(withJSONObject: ruleSearch)
            }
            
            if let ruleExplore = sourceData["ruleExplore"] as? [String: Any] {
                source.ruleExploreData = try? JSONSerialization.data(withJSONObject: ruleExplore)
            }
            
            if let ruleBookInfo = sourceData["ruleBookInfo"] as? [String: Any] {
                source.ruleBookInfoData = try? JSONSerialization.data(withJSONObject: ruleBookInfo)
            }
            
            if let ruleToc = sourceData["ruleToc"] as? [String: Any] {
                source.ruleTocData = try? JSONSerialization.data(withJSONObject: ruleToc)
            }
            
            if let ruleContent = sourceData["ruleContent"] as? [String: Any] {
                source.ruleContentData = try? JSONSerialization.data(withJSONObject: ruleContent)
            }
            
            count += 1
            migrationProgress = 0.4 + Double(count) / Double(sources.count) * 0.3
        }
        
        try CoreDataStack.shared.save()
        return count
    }
    
    private func importBookmarks(_ bookmarks: [[String: Any]], format: ImportFormat) async throws -> Int {
        let context = CoreDataStack.shared.viewContext
        var count = 0
        
        for bookmarkData in bookmarks {
            let bookmark = Bookmark.create(in: context)
            
            bookmark.chapterTitle = bookmarkData["chapterName"] as? String ?? ""
            bookmark.content = bookmarkData["content"] as? String ?? ""
            
            if let chapterIndex = bookmarkData["chapterIndex"] as? Int {
                bookmark.chapterIndex = Int32(chapterIndex)
            }

            
            count += 1
            migrationProgress = 0.7 + Double(count) / Double(bookmarks.count) * 0.15
        }
        
        try CoreDataStack.shared.save()
        return count
    }
    
    private func importRules(_ rules: [[String: Any]], format: ImportFormat) async throws -> Int {
        let context = CoreDataStack.shared.viewContext
        var count = 0
        
        for ruleData in rules {
            let rule = ReplaceRule.create(in: context)
            
            rule.name = ruleData["name"] as? String ?? ""
            rule.pattern = ruleData["pattern"] as? String ?? ""
            rule.replacement = ruleData["replacement"] as? String ?? ""
            rule.scope = ruleData["scope"] as? String ?? "global"
            rule.isRegex = ruleData["isRegex"] as? Bool ?? false
            rule.enabled = ruleData["enabled"] as? Bool ?? true
            
            if let priority = ruleData["priority"] as? Int {
                rule.priority = Int32(priority)
            }
            
            count += 1
            migrationProgress = 0.85 + Double(count) / Double(rules.count) * 0.15
        }
        
        try CoreDataStack.shared.save()
        return count
    }
    
    private func exportBook(_ book: Book) -> [String: Any] {
        return [
            "name": book.name,
            "author": book.author,
            "bookUrl": book.bookUrl,
            "tocUrl": book.tocUrl ?? "",
            "coverUrl": book.coverUrl ?? "",
            "intro": book.intro ?? "",
            "durChapterIndex": book.durChapterIndex,
            "durChapterPos": book.durChapterPos,
            "origin": book.origin ?? "",
            "originName": book.originName ?? ""
        ]
    }
    
    private func exportSource(_ source: BookSource) -> [String: Any] {
        var data: [String: Any] = [
            "bookSourceUrl": source.bookSourceUrl,
            "bookSourceName": source.bookSourceName,
            "bookSourceGroup": source.bookSourceGroup ?? "",
            "searchUrl": source.searchUrl ?? "",
            "exploreUrl": source.exploreUrl ?? "",
            "enabled": source.enabled,
            "weight": source.weight
        ]
        
        if let ruleSearchData = source.ruleSearchData,
           let ruleSearch = try? JSONSerialization.jsonObject(with: ruleSearchData) {
            data["ruleSearch"] = ruleSearch
        }
        
        if let ruleExploreData = source.ruleExploreData,
           let ruleExplore = try? JSONSerialization.jsonObject(with: ruleExploreData) {
            data["ruleExplore"] = ruleExplore
        }
        
        return data
    }
    
    private func exportBookmark(_ bookmark: Bookmark) -> [String: Any] {
        return [
            "chapterName": bookmark.chapterTitle,
            "content": bookmark.content,
            "chapterIndex": bookmark.chapterIndex
        ]
    }
    }

    private func exportRule(_ rule: ReplaceRule) -> [String: Any] {
        return [
            "name": rule.name,
            "pattern": rule.pattern,
            "replacement": rule.replacement,
            "scope": rule.scope,
            "isRegex": rule.isRegex,
            "enabled": rule.enabled,
            "priority": rule.priority
        ]
    }
}

// MARK: - 迁移错误

enum MigrationError: LocalizedError {
    case invalidFormat
    case unsupportedFormat
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "无效的数据格式"
        case .unsupportedFormat: return "不支持的迁移格式"
        case .importFailed(let msg): return "导入失败：\(msg)"
        }
    }
}