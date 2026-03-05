//
//  BookExporter.swift
//  Legado-iOS
//
//  书籍导出为 EPUB/TXT
//

import Foundation
import UIKit

class BookExporter {
    static func exportToTXT(book: Book, chapters: [BookChapter]) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(book.name)_\(book.author).txt".replacingOccurrences(of: " ", with: "_")
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        var content = "\(book.name)\n作者: \(book.author)\n\n"
        
        for chapter in chapters {
            content += "\n\n========== \(chapter.title) ==========\n\n"
            if let chapterContent = try? await loadChapterContent(chapter) {
                content += chapterContent
            }
        }
        
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    static func exportToEPUB(book: Book, chapters: [BookChapter]) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let epubDir = tempDir.appendingPathComponent("epub_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: epubDir, withIntermediateDirectories: true)
        
        // 创建 EPUB 结构
        let metaInfDir = epubDir.appendingPathComponent("META-INF")
        let oebpsDir = epubDir.appendingPathComponent("OEBPS")
        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)
        
        // container.xml
        let containerXML = """
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        try containerXML.write(to: metaInfDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)
        
        // content.opf
        let contentOPF = generateContentOPF(book: book, chapters: chapters)
        try contentOPF.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)
        
        // 章节文件
        for (index, chapter) in chapters.enumerated() {
            let chapterContent = try await loadChapterContent(chapter)
            let html = generateChapterHTML(title: chapter.title, content: chapterContent)
            try html.write(to: oebpsDir.appendingPathComponent("chapter_\(index).xhtml"), atomically: true, encoding: .utf8)
        }
        
        // 打包为 .epub
        let epubURL = tempDir.appendingPathComponent("\(book.name).epub")
        try zipDirectory(at: epubDir, to: epubURL)
        
        // 清理临时目录
        try? FileManager.default.removeItem(at: epubDir)
        
        return epubURL
    }
    
    private static func loadChapterContent(_ chapter: BookChapter) async throws -> String {
        if let cachePath = chapter.cachePath, FileManager.default.fileExists(atPath: cachePath) {
            return try String(contentsOfFile: cachePath, encoding: .utf8)
        }
        return "内容未缓存"
    }
    
    private static func generateContentOPF(book: Book, chapters: [BookChapter]) -> String {
        var manifest = ""
        var spine = ""
        
        for i in 0..<chapters.count {
            manifest += "<item id=\"chapter_\(i)\" href=\"chapter_\(i).xhtml\" media-type=\"application/xhtml+xml\"/>\n"
            spine += "<itemref idref=\"chapter_\(i)\"/>\n"
        }
        
        return """
        <?xml version="1.0"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>\(book.name)</dc:title>
            <dc:creator>\(book.author)</dc:creator>
            <dc:language>zh</dc:language>
          </metadata>
          <manifest>
            \(manifest)
          </manifest>
          <spine>
            \(spine)
          </spine>
        </package>
        """
    }
    
    private static func generateChapterHTML(title: String, content: String) -> String {
        let escapedContent = content
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br/>")
        
        return """
        <?xml version="1.0"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>\(title)</title></head>
        <body>
        <h1>\(title)</h1>
        <p>\(escapedContent)</p>
        </body>
        </html>
        """
    }
    
    private static func zipDirectory(at source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: [])
        
        // 简单打包（实际应用中应使用 proper ZIP 库）
        let data = try files.map { try Data(contentsOf: $0) }.reduce(Data(), +)
        try data.write(to: destination)
    }
}