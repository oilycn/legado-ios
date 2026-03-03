//
//  BookSource+CoreDataClass.swift
//  Legado-iOS
//
//  书源实体
//

import Foundation
import CoreData

@objc(BookSource)
public class BookSource: NSManagedObject {
    // MARK: - 基础信息
    @NSManaged public var sourceId: UUID
    @NSManaged public var bookSourceUrl: String
    @NSManaged public var bookSourceName: String
    @NSManaged public var bookSourceGroup: String?
    @NSManaged public var bookSourceType: Int32
    @NSManaged public var bookUrlPattern: String?
    
    // MARK: - 状态
    @NSManaged public var customOrder: Int32
    @NSManaged public var enabled: Bool
    @NSManaged public var enabledExplore: Bool
    @NSManaged public var enabledCookieJar: Bool
    
    // MARK: - 网络配置
    @NSManaged public var concurrentRate: String?
    @NSManaged public var header: String?
    @NSManaged public var loginUrl: String?
    @NSManaged public var loginUi: String?
    @NSManaged public var loginCheckJs: String?
    @NSManaged public var coverDecodeJs: String?
    @NSManaged public var jsLib: String?
    
    // MARK: - 注释
    @NSManaged public var bookSourceComment: String?
    @NSManaged public var variableComment: String?
    
    // MARK: - 统计
    @NSManaged public var lastUpdateTime: Int64
    @NSManaged public var respondTime: Int64
    @NSManaged public var weight: Int32
    
    // MARK: - URL
    @NSManaged public var exploreUrl: String?
    @NSManaged public var exploreScreen: String?
    @NSManaged public var searchUrl: String?
    
    // MARK: - 规则 (JSON 存储)
    @NSManaged public var ruleSearchData: Data?
    @NSManaged public var ruleExploreData: Data?
    @NSManaged public var ruleBookInfoData: Data?
    @NSManaged public var ruleTocData: Data?
    @NSManaged public var ruleContentData: Data?
    @NSManaged public var ruleReviewData: Data?
    
    // MARK: - 自定义变量
    @NSManaged public var variable: String?
    
    // MARK: - 关系
    @NSManaged public var books: NSSet?
}

// MARK: - Fetch Request
extension BookSource {
    @nonobjc class func fetchRequest() -> NSFetchRequest<BookSource> {
        return NSFetchRequest<BookSource>(entityName: "BookSource")
    }
}

// MARK: - 计算属性
extension BookSource {
    var displayName: String {
        if let group = bookSourceGroup, !group.isEmpty {
            return "\(bookSourceName) (\(group))"
        }
        return bookSourceName
    }
    
    var isAudio: Bool {
        bookSourceType == 1
    }
    
    var isImage: Bool {
        bookSourceType == 2
    }
    
    var isValid: Bool {
        !bookSourceUrl.isEmpty && !bookSourceName.isEmpty
    }
}

// MARK: - 规则结构体
extension BookSource {
    /// 发现规则
    struct ExploreRule: Codable {
        var exploreList: String?
        var name: String?
        var author: String?
        var intro: String?
        var bookUrl: String?
        var coverUrl: String?
        var lastChapter: String?
    }
    
    /// 搜索规则
    struct SearchRule: Codable {
        var checkKeyWord: String?
        var bookList: String?
        var name: String?
        var author: String?
        var intro: String?
        var bookUrl: String?
        var coverUrl: String?
        var lastChapter: String?
        var wordCount: String?
        var kind: String?
    }
    
    /// 书籍信息规则
    struct BookInfoRule: Codable {
        var initRule: String?
        var name: String?
        var author: String?
        var intro: String?
        var coverUrl: String?
        var tocUrl: String?
        var lastChapter: String?
        var wordCount: String?
        var downloadUrls: String?
        
        enum CodingKeys: String, CodingKey {
            case initRule = "init"
            case name, author, intro, coverUrl, tocUrl, lastChapter, wordCount, downloadUrls
        }
    }
    
    /// 目录规则
    struct TocRule: Codable {
        var chapterList: String?
        var chapterName: String?
        var chapterUrl: String?
        var isVip: String?
        var isPay: String?
        var updateTime: String?
        var nextTocUrl: String?
    }
    
    /// 正文规则
    struct ContentRule: Codable {
        var content: String?
        var title: String?
        var nextContentUrl: String?
        var webJs: String?
        var sourceRegex: String?
        var replaceRegex: String?
        var imageStyle: String?
        var payAction: String?
    }
    
    /// 段评规则
    struct ReviewRule: Codable {
        var reviewList: String?
        var reviewContent: String?
        var reviewAuthor: String?
        var reviewTime: String?
    }
}

// MARK: - 规则访问器
extension BookSource {
    func getExploreRule() -> ExploreRule? {
        guard let data = ruleExploreData else { return nil }
        return try? JSONDecoder().decode(ExploreRule.self, from: data)
    }
    
    func setExploreRule(_ rule: ExploreRule) {
        ruleExploreData = try? JSONEncoder().encode(rule)
    }
    
    func getSearchRule() -> SearchRule? {
        guard let data = ruleSearchData else { return nil }
        return try? JSONDecoder().decode(SearchRule.self, from: data)
    }
    
    func setSearchRule(_ rule: SearchRule) {
        ruleSearchData = try? JSONEncoder().encode(rule)
    }
    
    func getBookInfoRule() -> BookInfoRule? {
        guard let data = ruleBookInfoData else { return nil }
        return try? JSONDecoder().decode(BookInfoRule.self, from: data)
    }
    
    func setBookInfoRule(_ rule: BookInfoRule) {
        ruleBookInfoData = try? JSONEncoder().encode(rule)
    }
    
    func getTocRule() -> TocRule? {
        guard let data = ruleTocData else { return nil }
        return try? JSONDecoder().decode(TocRule.self, from: data)
    }
    
    func setTocRule(_ rule: TocRule) {
        ruleTocData = try? JSONEncoder().encode(rule)
    }
    
    func getContentRule() -> ContentRule? {
        guard let data = ruleContentData else { return nil }
        return try? JSONDecoder().decode(ContentRule.self, from: data)
    }
    
    func setContentRule(_ rule: ContentRule) {
        ruleContentData = try? JSONEncoder().encode(rule)
    }
    
    func getReviewRule() -> ReviewRule? {
        guard let data = ruleReviewData else { return nil }
        return try? JSONDecoder().decode(ReviewRule.self, from: data)
    }
    
    func setReviewRule(_ rule: ReviewRule) {
        ruleReviewData = try? JSONEncoder().encode(rule)
    }
}

// MARK: - 初始化
extension BookSource {
    static func create(in context: NSManagedObjectContext) -> BookSource {
        let entity = NSEntityDescription.entity(forEntityName: "BookSource", in: context)!
        let source = BookSource(entity: entity, insertInto: context)
        source.sourceId = UUID()
        source.enabled = true
        source.enabledExplore = true
        source.enabledCookieJar = false
        source.bookSourceType = 0
        source.customOrder = 0
        source.weight = 0
        source.respondTime = 180000
        return source
    }
}
