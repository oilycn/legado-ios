//
//  BookProgress+CoreDataClass.swift
//  Legado-iOS
//
//  书籍进度同步数据结构 — 对标 Android BookProgress
//  注意：Android 中 BookProgress 不是 Room Entity，是纯数据类
//  iOS 中同样使用 struct（非 CoreData 实体），用于 WebDAV 进度同步
//

import Foundation

struct BookProgress: Codable {
    var name: String = ""
    var author: String = ""
    var durChapterIndex: Int = 0
    var durChapterPos: Int = 0
    var durChapterTime: Int64 = 0
    var durChapterTitle: String?

    /// 从 Book 实体创建进度快照
    static func from(book: Book) -> BookProgress {
        BookProgress(
            name: book.name,
            author: book.author,
            durChapterIndex: Int(book.durChapterIndex),
            durChapterPos: Int(book.durChapterPos),
            durChapterTime: book.durChapterTime,
            durChapterTitle: book.durChapterTitle
        )
    }

    /// 将进度应用到 Book 实体
    func apply(to book: Book) {
        book.durChapterIndex = Int32(durChapterIndex)
        book.durChapterPos = Int32(durChapterPos)
        book.durChapterTime = durChapterTime
        book.durChapterTitle = durChapterTitle
    }

    /// 文件名，用于 WebDAV 同步
    var fileName: String {
        "\(name)_\(author).json"
    }
}
