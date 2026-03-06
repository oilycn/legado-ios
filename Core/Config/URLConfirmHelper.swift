import SwiftUI

struct URLConfirmHelper {
    private static let whitelistedDomains = [
        "github.com",
        "gedoor.github.io",
        "legado.top"
    ]
    
    static func open(url: URL, from viewController: UIViewController? = nil, confirmationHandler: @escaping (Bool) -> Void) {
        if isWhitelisted(url) {
            UIApplication.shared.open(url)
            confirmationHandler(true)
        } else {
            showConfirmation(for: url, confirmationHandler: confirmationHandler)
        }
    }
    
    static func isWhitelisted(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return whitelistedDomains.contains { host.contains($0) }
    }
    
    private static func showConfirmation(for url: URL, confirmationHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "打开外部链接",
            message: "确定要打开以下链接吗？\n\n\(url.absoluteString)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            confirmationHandler(false)
        })
        
        alert.addAction(UIAlertAction(title: "打开", style: .default) { _ in
            UIApplication.shared.open(url)
            confirmationHandler(true)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

extension View {
    func openURLWithConfirmation(_ url: URL, isPresented: Binding<Bool>, onConfirm: @escaping (Bool) -> Void) -> some View {
        self.alert("打开外部链接", isPresented: isPresented) {
            Button("取消", role: .cancel) { onConfirm(false) }
            Button("打开") {
                UIApplication.shared.open(url)
                onConfirm(true)
            }
        } message: {
            Text("确定要打开以下链接吗？\n\(url.absoluteString)")
        }
    }
}