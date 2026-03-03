import Foundation
import JavaScriptCore

class JSBridge {
    weak var context: ExecutionContext?
    weak var ruleEngine: RuleEngine?

    func inject(into jsContext: JSContext) {
        injectJavaObject(into: jsContext)
        injectSourceObject(into: jsContext)
        injectCookieObject(into: jsContext)
    }

    private func injectJavaObject(into jsContext: JSContext) {
        let javaObject = JSValue(newObjectIn: jsContext)

        let ajaxBlock: @convention(block) (String) -> String = { url in
            guard !url.isEmpty else { return "" }

            let headers = self.parseSourceHeaders()
            return JSBridgeHTTPClient.syncGet(url: url, headers: headers) ?? ""
        }

        let getStringBlock: @convention(block) (String) -> String = { url in
            return ajaxBlock(url)
        }

        let getStringAsyncBlock: @convention(block) (String) -> Void = { url in
            guard !url.isEmpty else { return }

            let headers = self.parseSourceHeaders()
            JSBridgeHTTPClient.asyncGet(url: url, headers: headers) { result in
                DispatchQueue.main.async {
                    self.context?.variables["result"] = result ?? ""
                }
            }
        }

        let putBlock: @convention(block) (String, String) -> Void = { key, value in
            self.context?.variables[key] = value
        }

        let getBlock: @convention(block) (String) -> String = { key in
            return self.context?.variables[key] ?? ""
        }

        let logBlock: @convention(block) (String) -> Void = { message in
            print("[JSBridge] \(message)")
        }

        javaObject?.setObject(ajaxBlock, forKeyedSubscript: "ajax" as NSString)
        javaObject?.setObject(getStringBlock, forKeyedSubscript: "getString" as NSString)
        javaObject?.setObject(getStringAsyncBlock, forKeyedSubscript: "getStringAsync" as NSString)
        javaObject?.setObject(putBlock, forKeyedSubscript: "put" as NSString)
        javaObject?.setObject(getBlock, forKeyedSubscript: "get" as NSString)
        javaObject?.setObject(logBlock, forKeyedSubscript: "log" as NSString)

        jsContext.setValue(javaObject, forKey: "java")
    }

    private func injectSourceObject(into jsContext: JSContext) {
        let sourceObject = JSValue(newObjectIn: jsContext)
        jsContext.setValue(sourceObject, forKey: "source")

        let getSourceUrl: @convention(block) () -> String = {
            return self.context?.source?.bookSourceUrl ?? ""
        }

        let getSourceName: @convention(block) () -> String = {
            return self.context?.source?.bookSourceName ?? ""
        }

        let getLoginUrl: @convention(block) () -> String = {
            return self.context?.source?.loginUrl ?? ""
        }

        let getHeader: @convention(block) () -> String = {
            return self.context?.source?.header ?? ""
        }

        jsContext.setValue(getSourceUrl, forKey: "__legado_source_bookSourceUrl")
        jsContext.setValue(getSourceName, forKey: "__legado_source_bookSourceName")
        jsContext.setValue(getLoginUrl, forKey: "__legado_source_loginUrl")
        jsContext.setValue(getHeader, forKey: "__legado_source_header")

        _ = jsContext.evaluateScript(
            """
            if (typeof source === 'undefined') { source = {}; }
            Object.defineProperty(source, 'bookSourceUrl', { configurable: true, enumerable: true, get: __legado_source_bookSourceUrl });
            Object.defineProperty(source, 'bookSourceName', { configurable: true, enumerable: true, get: __legado_source_bookSourceName });
            Object.defineProperty(source, 'loginUrl', { configurable: true, enumerable: true, get: __legado_source_loginUrl });
            Object.defineProperty(source, 'header', { configurable: true, enumerable: true, get: __legado_source_header });
            """
        )
    }

    private func injectCookieObject(into jsContext: JSContext) {
        let cookieObject = JSValue(newObjectIn: jsContext)

        let getCookieBlock: @convention(block) (String) -> String = { url in
            guard let cookieURL = URL(string: url),
                  let cookies = HTTPCookieStorage.shared.cookies(for: cookieURL),
                  !cookies.isEmpty else {
                return ""
            }

            return cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        }

        let setCookieBlock: @convention(block) (String, String) -> Void = { url, cookie in
            guard let cookieURL = URL(string: url), !cookie.isEmpty else { return }

            let parsedCookies = HTTPCookie.cookies(
                withResponseHeaderFields: ["Set-Cookie": cookie],
                for: cookieURL
            )

            if parsedCookies.isEmpty {
                if let simpleCookie = JSBridge.makeSimpleCookie(cookie, for: cookieURL) {
                    HTTPCookieStorage.shared.setCookie(simpleCookie)
                }
                return
            }

            for item in parsedCookies {
                HTTPCookieStorage.shared.setCookie(item)
            }
        }

        let removeCookieBlock: @convention(block) (String) -> Void = { url in
            guard let cookieURL = URL(string: url),
                  let cookies = HTTPCookieStorage.shared.cookies(for: cookieURL) else {
                return
            }

            for item in cookies {
                HTTPCookieStorage.shared.deleteCookie(item)
            }
        }

        cookieObject?.setObject(getCookieBlock, forKeyedSubscript: "get" as NSString)
        cookieObject?.setObject(setCookieBlock, forKeyedSubscript: "set" as NSString)
        cookieObject?.setObject(removeCookieBlock, forKeyedSubscript: "remove" as NSString)

        jsContext.setValue(cookieObject, forKey: "cookie")
    }

    private func parseSourceHeaders() -> [String: String]? {
        guard let headerString = context?.source?.header,
              let data = headerString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let headers = json as? [String: String] {
            return headers
        }

        if let dict = json as? [String: Any] {
            var headers: [String: String] = [:]
            for (key, value) in dict {
                headers[key] = "\(value)"
            }
            return headers.isEmpty ? nil : headers
        }

        return nil
    }

    private static func makeSimpleCookie(_ cookie: String, for url: URL) -> HTTPCookie? {
        guard let rawPair = cookie.split(separator: ";", maxSplits: 1).first else {
            return nil
        }

        let pair = rawPair.trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = pair.split(separator: "=", maxSplits: 1).map(String.init)

        guard segments.count == 2,
              let host = url.host,
              !segments[0].isEmpty else {
            return nil
        }

        let properties: [HTTPCookiePropertyKey: Any] = [
            .name: segments[0],
            .value: segments[1],
            .domain: host,
            .path: "/"
        ]

        return HTTPCookie(properties: properties)
    }
}

class JSBridgeHTTPClient {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    static func syncGet(url: String, headers: [String: String]?) -> String? {
        guard let request = makeRequest(url: url, headers: headers) else {
            return nil
        }

        let semaphore = DispatchSemaphore(value: 0)
        var output: String?
        var task: URLSessionDataTask?

        task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                print("[JSBridgeHTTPClient] syncGet error: \(error.localizedDescription)")
                return
            }

            guard let data else {
                return
            }

            if let response = response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                print("[JSBridgeHTTPClient] syncGet status: \(response.statusCode)")
                return
            }

            output = decode(data: data, response: response)
        }

        task?.resume()

        let timeout = DispatchTime.now() + .seconds(10)
        if semaphore.wait(timeout: timeout) == .timedOut {
            task?.cancel()
            print("[JSBridgeHTTPClient] syncGet timeout: \(url)")
            return nil
        }

        return output
    }

    static func asyncGet(
        url: String,
        headers: [String: String]?,
        completion: @escaping (String?) -> Void
    ) {
        guard let request = makeRequest(url: url, headers: headers) else {
            completion(nil)
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error {
                print("[JSBridgeHTTPClient] asyncGet error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data else {
                completion(nil)
                return
            }

            if let response = response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                print("[JSBridgeHTTPClient] asyncGet status: \(response.statusCode)")
                completion(nil)
                return
            }

            completion(decode(data: data, response: response))
        }.resume()
    }

    private static func makeRequest(url: String, headers: [String: String]?) -> URLRequest? {
        guard let targetURL = URL(string: url) else {
            return nil
        }

        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private static func decode(data: Data, response: URLResponse?) -> String? {
        if let httpResponse = response as? HTTPURLResponse,
           let encodingName = httpResponse.textEncodingName {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                if let text = String(data: data, encoding: String.Encoding(rawValue: nsEncoding)) {
                    return text
                }
            }
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        return String(data: data, encoding: .isoLatin1)
    }
}
