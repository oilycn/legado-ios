import SwiftUI
import WebKit

struct VerificationWebView: UIViewControllerRepresentable {
    let url: URL
    let onComplete: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor)
        ])
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onComplete: () -> Void
        
        init(onComplete: @escaping () -> Void) {
            self.onComplete = onComplete
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                let cookies = HTTPCookieStorage.shared.cookies(for: httpResponse.url ?? URL(string: "about:blank")!) ?? []
                saveCookies(cookies)
            }
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.cookie") { result, error in
                if let cookieString = result as? String {
                    self.parseAndSaveCookies(cookieString, from: webView.url)
                }
            }
        }
        
        private func saveCookies(_ cookies: [HTTPCookie]) {
            let context = CoreDataStack.shared.viewContext
            for cookie in cookies {
                let cookieEntity = Cookie.create(in: context)
                cookieEntity.url = cookie.domain
                cookieEntity.cookie = "\(cookie.name)=\(cookie.value)"
            }
            try? context.save()
        }
        
        private func parseAndSaveCookies(_ cookieString: String, from url: URL?) {
            let context = CoreDataStack.shared.viewContext
            let pairs = cookieString.components(separatedBy: ";")
            for pair in pairs {
                let trimmed = pair.trimmingCharacters(in: .whitespaces)
                if let equalsIndex = trimmed.firstIndex(of: "=") {
                    let name = String(trimmed[..<equalsIndex])
                    let value = String(trimmed[trimmed.index(after: equalsIndex)...])
                    let cookieEntity = Cookie.create(in: context)
                    cookieEntity.url = url?.host ?? ""
                    cookieEntity.cookie = "\(name)=\(value)"
                }
            }
            try? context.save()
        }
    }
}

struct SourceLoginView: View {
    @Binding var isPresented: Bool
    let source: BookSource
    let onLoginComplete: () -> Void
    
    var body: some View {
        NavigationView {
            if let loginUrl = URL(string: source.loginUrl ?? "") {
                VerificationWebView(url: loginUrl) {
                    onLoginComplete()
                    isPresented = false
                }
                .navigationTitle("登录 - \(source.bookSourceName)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { isPresented = false }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            onLoginComplete()
                            isPresented = false
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("无效的登录地址")
                        .foregroundColor(.secondary)
                    Button("关闭") { isPresented = false }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}