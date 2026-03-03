import Foundation

enum WebDAVError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case xmlParseFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无效的 WebDAV 响应"
        case .unauthorized:
            return "WebDAV 认证失败，请检查用户名和密码"
        case .httpError(let statusCode):
            return "WebDAV 请求失败（HTTP \(statusCode)）"
        case .xmlParseFailed:
            return "WebDAV 目录解析失败"
        }
    }
}

class WebDAVClient {
    let baseURL: URL
    let credentials: WebDAVCredentials

    private let session: URLSession
    private let webDAVDateFormatters: [DateFormatter] = {
        let rfc1123 = DateFormatter()
        rfc1123.locale = Locale(identifier: "en_US_POSIX")
        rfc1123.timeZone = TimeZone(secondsFromGMT: 0)
        rfc1123.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        let iso8601 = DateFormatter()
        iso8601.locale = Locale(identifier: "en_US_POSIX")
        iso8601.timeZone = TimeZone(secondsFromGMT: 0)
        iso8601.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        return [rfc1123, iso8601]
    }()

    init(baseURL: URL, credentials: WebDAVCredentials) {
        self.baseURL = WebDAVClient.normalizedBaseURL(baseURL)
        self.credentials = credentials

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }

    func list(path: String) async throws -> [WebDAVFile] {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <d:propfind xmlns:d="DAV:">
            <d:prop>
                <d:displayname />
                <d:getcontentlength />
                <d:getlastmodified />
                <d:getetag />
                <d:resourcetype />
            </d:prop>
        </d:propfind>
        """.data(using: .utf8)

        var request = try makeRequest(path: path, method: "PROPFIND", body: body)
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await send(request, validStatusCodes: [200, 207])
        let parser = WebDAVPropfindParser(dateParser: { [weak self] value in
            self?.parseWebDAVDate(value)
        })
        guard let nodes = parser.parse(data: data) else {
            throw WebDAVError.xmlParseFailed
        }

        let requestRelativePath = normalizeRelativePath(path)
        var files: [WebDAVFile] = []

        for node in nodes {
            guard let relativePath = normalizeRelativePathFromHref(node.href), !relativePath.isEmpty else {
                continue
            }

            if normalizeRelativePath(relativePath) == requestRelativePath {
                continue
            }

            let name: String
            if !node.displayName.isEmpty {
                name = node.displayName
            } else {
                name = URL(fileURLWithPath: relativePath).lastPathComponent
            }

            files.append(
                WebDAVFile(
                    path: "/\(relativePath)",
                    name: name,
                    isDirectory: node.isDirectory,
                    size: node.isDirectory ? nil : node.size,
                    lastModified: node.lastModified,
                    etag: node.etag
                )
            )
        }

        return files
    }

    func download(path: String) async throws -> Data {
        let request = try makeRequest(path: path, method: "GET")
        let (data, _) = try await send(request)
        return data
    }

    func upload(path: String, data: Data) async throws {
        var request = try makeRequest(path: path, method: "PUT", body: data)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        _ = try await send(request, validStatusCodes: [200, 201, 204])
    }

    func createDirectory(path: String) async throws {
        let request = try makeRequest(path: path, method: "MKCOL")
        _ = try await send(request, validStatusCodes: [201, 405])
    }

    func delete(path: String) async throws {
        let request = try makeRequest(path: path, method: "DELETE")
        _ = try await send(request, validStatusCodes: [200, 202, 204, 404])
    }

    func exists(path: String) async throws -> Bool {
        let request = try makeRequest(path: path, method: "HEAD")
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return true
        case 401, 403:
            throw WebDAVError.unauthorized
        case 404:
            return false
        case 405:
            return try await existsWithPropfind(path: path)
        default:
            throw WebDAVError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func existsWithPropfind(path: String) async throws -> Bool {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <d:propfind xmlns:d="DAV:">
            <d:prop>
                <d:resourcetype />
            </d:prop>
        </d:propfind>
        """.data(using: .utf8)

        var request = try makeRequest(path: path, method: "PROPFIND", body: body)
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200, 207:
            return true
        case 404:
            return false
        case 401, 403:
            throw WebDAVError.unauthorized
        default:
            throw WebDAVError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func makeRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest {
        let url = resolvedURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 60
        request.setValue("Basic \(basicAuthorizationToken())", forHTTPHeaderField: "Authorization")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        return request
    }

    private func send(_ request: URLRequest, validStatusCodes: Set<Int> = Set(200..<300)) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw WebDAVError.unauthorized
        }

        guard validStatusCodes.contains(httpResponse.statusCode) else {
            throw WebDAVError.httpError(statusCode: httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    private func resolvedURL(path: String) -> URL {
        let normalized = normalizeRelativePath(path)
        guard !normalized.isEmpty else {
            return baseURL
        }

        var url = baseURL
        normalized.split(separator: "/").forEach { part in
            url.appendPathComponent(String(part))
        }
        return url
    }

    private func normalizeRelativePath(_ path: String) -> String {
        path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func normalizeRelativePathFromHref(_ href: String) -> String? {
        guard let hrefURL = URL(string: href, relativeTo: baseURL)?.absoluteURL else {
            return nil
        }

        let basePath = decodedPath(baseURL)
        var resourcePath = decodedPath(hrefURL)

        if resourcePath.hasPrefix(basePath) {
            resourcePath = String(resourcePath.dropFirst(basePath.count))
        }

        return normalizeRelativePath(resourcePath)
    }

    private func decodedPath(_ url: URL) -> String {
        let path = url.path
        return path.removingPercentEncoding ?? path
    }

    private func parseWebDAVDate(_ value: String) -> Date? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }

        for formatter in webDAVDateFormatters {
            if let date = formatter.date(from: text) {
                return date
            }
        }

        return nil
    }

    private func basicAuthorizationToken() -> String {
        let raw = "\(credentials.username):\(credentials.password)"
        let data = Data(raw.utf8)
        return data.base64EncodedString()
    }

    private static func normalizedBaseURL(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var path = components?.path ?? ""
        if path.isEmpty {
            path = "/"
        }
        if !path.hasSuffix("/") {
            path += "/"
        }
        components?.path = path
        return components?.url ?? url
    }
}

private struct WebDAVPropfindNode {
    var href: String = ""
    var displayName: String = ""
    var isDirectory: Bool = false
    var size: Int64?
    var lastModified: Date?
    var etag: String?
}

private final class WebDAVPropfindParser: NSObject, XMLParserDelegate {
    private var nodes: [WebDAVPropfindNode] = []
    private var currentNode: WebDAVPropfindNode?
    private var currentElement: String = ""
    private var currentText: String = ""
    private var insideResponse = false
    private let dateParser: (String) -> Date?

    init(dateParser: @escaping (String) -> Date?) {
        self.dateParser = dateParser
    }

    func parse(data: Data) -> [WebDAVPropfindNode]? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse() ? nodes : nil
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        let localName = localElementName(elementName)
        currentElement = localName
        currentText = ""

        if localName == "response" {
            insideResponse = true
            currentNode = WebDAVPropfindNode()
            return
        }

        guard insideResponse else {
            return
        }

        if localName == "collection" {
            currentNode?.isDirectory = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let localName = localElementName(elementName)
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard insideResponse else {
            currentElement = ""
            currentText = ""
            return
        }

        switch localName {
        case "href":
            currentNode?.href = value
        case "displayname":
            currentNode?.displayName = value
        case "getcontentlength":
            currentNode?.size = Int64(value)
        case "getlastmodified":
            currentNode?.lastModified = dateParser(value)
        case "getetag":
            currentNode?.etag = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        case "response":
            if let node = currentNode, !node.href.isEmpty {
                nodes.append(node)
            }
            currentNode = nil
            insideResponse = false
        default:
            break
        }

        currentElement = ""
        currentText = ""
    }

    private func localElementName(_ elementName: String) -> String {
        elementName.split(separator: ":").last?.lowercased() ?? elementName.lowercased()
    }
}
