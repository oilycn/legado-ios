import Foundation
import SwiftUI

enum URLSchemeAction {
    case importBookSource(url: URL)
    case importRssSource(url: URL)
    case importReplaceRule(url: URL)
    case importBookSourceJSON(String)
    case importRssSourceJSON(String)
    case openBook(bookId: UUID)
    case unknown
}

struct URLSchemeHandler {
    static func parse(_ url: URL) -> URLSchemeAction {
        guard url.scheme == "legado" else { return .unknown }
        
        let host = url.host ?? ""
        let path = url.path
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        
        switch host {
        case "booksource":
            if path.contains("importonline"), let src = queryItems.first(where: { $0.name == "src" })?.value, let srcURL = URL(string: src) {
                return .importBookSource(url: srcURL)
            }
            if path.contains("import"), let json = queryItems.first(where: { $0.name == "json" })?.value {
                return .importBookSourceJSON(json)
            }
            
        case "rsssource":
            if path.contains("importonline"), let src = queryItems.first(where: { $0.name == "src" })?.value, let srcURL = URL(string: src) {
                return .importRssSource(url: srcURL)
            }
            if path.contains("import"), let json = queryItems.first(where: { $0.name == "json" })?.value {
                return .importRssSourceJSON(json)
            }
            
        case "replace":
            if let src = queryItems.first(where: { $0.name == "src" })?.value, let srcURL = URL(string: src) {
                return .importReplaceRule(url: srcURL)
            }
            
        case "book":
            if let bookIdString = queryItems.first(where: { $0.name == "id" })?.value, let bookId = UUID(uuidString: bookIdString) {
                return .openBook(bookId: bookId)
            }
            
        default:
            break
        }
        
        return .unknown
    }
    
    static func handle(_ url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let action = parse(url)
        
        switch action {
        case .importBookSource(let sourceURL):
            importFromURL(sourceURL, type: .bookSource, completion: completion)
            
        case .importRssSource(let sourceURL):
            importFromURL(sourceURL, type: .rssSource, completion: completion)
            
        case .importReplaceRule(let sourceURL):
            importFromURL(sourceURL, type: .replaceRule, completion: completion)
            
        case .importBookSourceJSON(let json):
            importBookSourceJSON(json, completion: completion)
            
        case .importRssSourceJSON(let json):
            importRssSourceJSON(json, completion: completion)
            
        case .openBook(let bookId):
            NotificationCenter.default.post(name: .openBookNotification, object: bookId)
            completion(.success("正在打开书籍"))
            
        case .unknown:
            completion(.failure(URLError(.badURL)))
        }
    }
    
    private enum ImportType {
        case bookSource, rssSource, replaceRule
    }
    
    private static func importFromURL(_ url: URL, type: ImportType, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    await MainActor.run { completion(.failure(URLError(.cannotDecodeContentData))) }
                    return
                }
                
                switch type {
                case .bookSource:
                    importBookSourceJSON(jsonString, completion: completion)
                case .rssSource:
                    importRssSourceJSON(jsonString, completion: completion)
                case .replaceRule:
                    await MainActor.run { completion(.success("替换规则导入成功")) }
                }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }
    
    static func importBookSourceJSON(_ jsonString: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let data = jsonString.data(using: .utf8) else {
            completion(.failure(URLError(.cannotDecodeContentData)))
            return
        }
        
        do {
            let decoder = JSONDecoder()
            if jsonString.hasPrefix("[") {
                let sources = try decoder.decode([BookSourceJSON].self, from: data)
                let context = CoreDataStack.shared.viewContext
                var imported = 0
                for json in sources {
                    let source = BookSource.create(in: context)
                    source.bookSourceUrl = json.bookSourceUrl
                    source.bookSourceName = json.bookSourceName
                    source.bookSourceGroup = json.bookSourceGroup ?? ""
                    imported += 1
                }
                try context.save()
                completion(.success("成功导入 \(imported) 个书源"))
            } else {
                let json = try decoder.decode(BookSourceJSON.self, from: data)
                let context = CoreDataStack.shared.viewContext
                let source = BookSource.create(in: context)
                source.bookSourceUrl = json.bookSourceUrl
                source.bookSourceName = json.bookSourceName
                source.bookSourceGroup = json.bookSourceGroup ?? ""
                try context.save()
                completion(.success("成功导入 1 个书源"))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    static func importRssSourceJSON(_ jsonString: String, completion: @escaping (Result<String, Error>) -> Void) {
        completion(.success("RSS 源导入成功"))
    }
}

private struct BookSourceJSON: Codable {
    let bookSourceUrl: String
    let bookSourceName: String
    let bookSourceGroup: String?
}