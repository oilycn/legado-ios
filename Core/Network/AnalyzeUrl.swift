//
//  AnalyzeUrl.swift
//  Legado-iOS
//
//  URL 解析与构建器 - 参考原版 AnalyzeUrl.kt
//  支持 {{key}}、{{page}} 变量替换、POST body 解析、headers 解析
//

import Foundation

/// URL 解析结果
struct AnalyzedUrl {
    var url: String
    var method: HTTPMethod = .get
    var body: String?
    var headers: [String: String] = [:]
    var charset: String?
    var webView: Bool = false
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }
}

/// URL 构建器 - 将书源中的规则 URL 解析为实际可用的请求
class AnalyzeUrl {
    
    /// 解析搜索/发现 URL
    /// - Parameters:
    ///   - ruleUrl: 规则 URL，如 "https://example.com/search?q={{key}}&page={{page}},{"method":"POST"}"
    ///   - key: 搜索关键词
    ///   - page: 页码
    ///   - baseUrl: 书源 URL（用于解析相对路径）
    ///   - source: 书源（用于获取 headers 等配置）
    /// - Returns: 解析后的 URL 结构
    static func analyze(
        ruleUrl: String,
        key: String? = nil,
        page: Int = 1,
        baseUrl: String? = nil,
        source: BookSource? = nil
    ) -> AnalyzedUrl {
        var result = AnalyzedUrl(url: "")
        let templateContext = buildTemplateContext(key: key, page: page, source: source)
        
        // 1. 分离 URL 和配置 JSON
        var urlPart = ruleUrl
        var configJson: [String: Any]?
        
        // 检查是否有 JSON 配置（以 , + { 分隔）
        if let jsonStart = findJsonConfig(in: ruleUrl) {
            urlPart = String(ruleUrl[..<jsonStart.lowerBound])
            let jsonStr = String(ruleUrl[jsonStart.lowerBound...])
            if let data = jsonStr.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                configJson = json
            }
        }
        
        // 2. 变量替换
        urlPart = replaceVariables(urlPart, context: templateContext)
        
        // 3. 解析 HTTP 方法
        if let method = configJson?["method"] as? String {
            result.method = method.uppercased() == "POST" ? .post : .get
        }
        
        // 4. 解析 POST body
        if let body = configJson?["body"] as? String {
            result.body = replaceVariables(body, context: templateContext)
        }
        
        // 5. 解析 headers
        if let headers = configJson?["headers"] as? [String: String] {
            result.headers = headers.mapValues { replaceVariables($0, context: templateContext) }
        }
        
        // 6. 解析编码
        if let charset = configJson?["charset"] as? String {
            result.charset = charset
        }
        
        // 7. 是否需要 WebView
        if let webView = configJson?["webView"] as? Bool {
            result.webView = webView
        }
        
        // 8. 处理 URL 中的 POST 参数（用 , 分隔的旧格式）
        if result.method == .get && urlPart.contains(",{") == false {
            // 检查是否是 URL,body 的旧格式
            let parts = urlPart.split(separator: "\n", maxSplits: 1)
            if parts.count == 2 {
                urlPart = String(parts[0])
                result.body = replaceVariables(String(parts[1]), context: templateContext)
                result.method = .post
            }
        }
        
        // 9. 处理相对 URL
        if !urlPart.hasPrefix("http"), let base = baseUrl {
            if urlPart.hasPrefix("/") {
                // 取 baseUrl 的 scheme + host
                if let baseURL = URL(string: base),
                   let scheme = baseURL.scheme,
                   let host = baseURL.host {
                    let port = baseURL.port.map { ":\($0)" } ?? ""
                    urlPart = "\(scheme)://\(host)\(port)\(urlPart)"
                }
            } else {
                urlPart = base.hasSuffix("/") ? base + urlPart : base + "/" + urlPart
            }
        }
        
        // 10. 合并书源 headers
        if let source = source, let headerStr = source.header,
           let data = headerStr.data(using: .utf8),
           let sourceHeaders = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            for (key, value) in sourceHeaders where result.headers[key] == nil {
                result.headers[key] = replaceVariables(value, context: templateContext)
            }
        }
        
        // 11. 添加默认 User-Agent
        if result.headers["User-Agent"] == nil {
            result.headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1"
        }
        
        result.url = urlPart
        return result
    }
    
    // MARK: - 变量替换
    
    /// 替换 URL 中的变量占位符
    private static func replaceVariables(_ input: String, context: ExecutionContext) -> String {
        TemplateEngine.render(input, context: context)
    }

    private static func buildTemplateContext(key: String?, page: Int, source: BookSource?) -> ExecutionContext {
        let context = ExecutionContext()

        if let key {
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            context.variables["key"] = encodedKey
            context.variables["searchKey"] = encodedKey
        }

        context.variables["page"] = "\(page)"
        context.variables["page-1"] = "\(page - 1)"

        if let variable = source?.variable,
           let data = variable.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (name, value) in json {
                if let string = value as? String {
                    context.variables[name] = string
                } else if let bool = value as? Bool {
                    context.variables[name] = bool ? "true" : "false"
                } else if let number = value as? NSNumber {
                    context.variables[name] = number.stringValue
                }
            }
        }

        return context
    }
    
    // MARK: - JSON 配置查找
    
    /// 在 URL 字符串中查找 JSON 配置的起始位置
    private static func findJsonConfig(in url: String) -> Range<String.Index>? {
        // 查找 ,{ 模式，但要排除 URL 本身包含的 { }
        var braceDepth = 0
        var lastCommaIndex: String.Index?
        
        for i in url.indices {
            let char = url[i]
            if char == "{" {
                if braceDepth == 0 && lastCommaIndex != nil {
                    return lastCommaIndex!..<url.endIndex
                }
                braceDepth += 1
            } else if char == "}" {
                braceDepth -= 1
            } else if char == "," && braceDepth == 0 {
                lastCommaIndex = i
            }
        }
        
        return nil
    }
    
    // MARK: - 发起请求
    
    /// 使用解析后的 URL 发起网络请求并返回响应内容
    static func getResponseBody(
        analyzedUrl: AnalyzedUrl,
        charset: String.Encoding = .utf8
    ) async throws -> (body: String, url: String) {
        guard let url = URL(string: analyzedUrl.url) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = analyzedUrl.method.rawValue
        request.timeoutInterval = 30
        
        // 设置 headers
        for (key, value) in analyzedUrl.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 设置 body
        if let body = analyzedUrl.body {
            request.httpBody = body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 处理编码
        let encoding = detectEncoding(data: data, response: response, charset: analyzedUrl.charset)
        let body = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) ?? ""
        
        let finalUrl = (response as? HTTPURLResponse)?.url?.absoluteString ?? analyzedUrl.url
        
        return (body, finalUrl)
    }
    
    // MARK: - 编码检测
    
    /// 自动检测响应内容的编码
    private static func detectEncoding(data: Data, response: URLResponse, charset: String?) -> String.Encoding {
        // 1. 优先使用书源指定的编码
        if let charset = charset {
            switch charset.lowercased() {
            case "gbk", "gb2312", "gb18030":
                return String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(
                        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
                    )
                )
            case "big5":
                return String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(
                        CFStringEncoding(CFStringEncodings.big5.rawValue)
                    )
                )
            default:
                break
            }
        }
        
        // 2. 从 HTTP 响应头检测
        if let httpResponse = response as? HTTPURLResponse,
           let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
            if contentType.lowercased().contains("gbk") || contentType.lowercased().contains("gb2312") {
                return String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(
                        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
                    )
                )
            }
        }
        
        // 3. 从 HTML meta 标签检测
        if data.count > 0 {
            let prefix = String(data: data.prefix(1024), encoding: .ascii) ?? ""
            if prefix.lowercased().contains("charset=gbk") ||
               prefix.lowercased().contains("charset=gb2312") {
                return String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(
                        CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
                    )
                )
            }
        }
        
        // 4. 默认 UTF-8
        return .utf8
    }
}
