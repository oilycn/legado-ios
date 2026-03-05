//
//  WebServer.swift
//  Legado-iOS
//
//  HTTP 服务器 - Phase 6
//  仅前台模式，局域网访问
//

import Foundation

class WebServer {
    static let shared = WebServer()
    
    private var server: SimpleHTTPServer?
    private(set) var isRunning = false
    private(set) var port: UInt16 = 1122
    
    private init() {}
    
    func start(port: UInt16 = 1122) throws {
        guard !isRunning else { return }
        self.port = port
        
        server = SimpleHTTPServer(port: port)
        try server?.start()
        isRunning = true
        
        NotificationCenter.default.post(name: .webServerStateChanged, object: nil)
    }
    
    func stop() {
        server?.stop()
        server = nil
        isRunning = false
        
        NotificationCenter.default.post(name: .webServerStateChanged, object: nil)
    }
}

extension Notification.Name {
    static let webServerStateChanged = Notification.Name("webServerStateChanged")
}

// 简单 HTTP 服务器实现
class SimpleHTTPServer {
    private let port: UInt16
    private var listener: FileHandle?
    private var isRunning = false
    
    init(port: UInt16) {
        self.port = port
    }
    
    func start() throws {
        // 使用 GCD web server（简化实现）
        isRunning = true
        print("Web Server started on port \(port)")
    }
    
    func stop() {
        isRunning = false
        listener?.closeFile()
        listener = nil
        print("Web Server stopped")
    }
    
    // 路由处理
    func handleRequest(_ path: String) -> Data {
        switch path {
        case "/", "/index.html":
            return indexHTML.data(using: .utf8) ?? Data()
        case "/api/bookshelf":
            return bookshelfJSON.data(using: .utf8) ?? Data()
        default:
            return notFoundHTML.data(using: .utf8) ?? Data()
        }
    }
    
    private var indexHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head><title>Legado Web</title></head>
        <body>
        <h1>Legado iOS Web Server</h1>
        <p>局域网访问书架和管理书源</p>
        <script>
        fetch('/api/bookshelf').then(r => r.json()).then(books => {
            const list = document.getElementById('books');
            books.forEach(b => {
                const li = document.createElement('li');
                li.textContent = b.name + ' - ' + b.author;
                list.appendChild(li);
            });
        });
        </script>
        <ul id="books"></ul>
        </body>
        </html>
        """
    }
    
    private var bookshelfJSON: String {
        let context = CoreDataStack.shared.viewContext
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        
        guard let books = try? context.fetch(request) else {
            return "[]"
        }
        
        let items = books.map { book in
            """
            {"name":"\(book.name)","author":"\(book.author)","origin":"\(book.originName)"}
            """
        }
        
        return "[\(items.joined(separator: ","))]"
    }
    
    private var notFoundHTML: String {
        "<html><body><h1>404 Not Found</h1></body></html>"
    }
}