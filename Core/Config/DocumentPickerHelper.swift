//
//  DocumentPickerHelper.swift
//  Legado-iOS
//

import UIKit
import UniformTypeIdentifiers

class DocumentPickerHelper: NSObject, UIDocumentPickerDelegate {
    static let shared = DocumentPickerHelper()

    private var onPick: (([URL]) -> Void)?

    func present(contentTypes: [UTType], onPick: @escaping ([URL]) -> Void) {
        self.onPick = onPick
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        topViewController()?.present(picker, animated: true)
    }

    private func topViewController() -> UIViewController? {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        else { return nil }
        var top = rootVC
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        onPick?(urls)
        onPick = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onPick = nil
    }
}
