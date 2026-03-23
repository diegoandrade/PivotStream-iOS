//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Diego Andrade on 3/22/26.
//
import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        extractSharedContent { [weak self] text in
            guard let self, let text, !text.isEmpty else {
                self?.cancel()
                return
            }
            self.openMainApp(with: text)
        }
    }

    // MARK: - Extract shared text or URL

    private func extractSharedContent(completion: @escaping (String?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(nil)
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Plain text
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                        let text = data as? String
                        DispatchQueue.main.async { completion(text) }
                    }
                    return
                }

                // URL — pass it as text so the app can display/read it
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                        let text = (data as? URL)?.absoluteString
                        DispatchQueue.main.async { completion(text) }
                    }
                    return
                }
            }
        }

        completion(nil)
    }

    // MARK: - Hand off to main app

    private func openMainApp(with text: String) {
        // Encode text and build the deep-link URL
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "pivotstream://read?text=\(encoded)") else {
            cancel()
            return
        }

        // Save to shared UserDefaults as a fallback for App Group handoff
        if let defaults = UserDefaults(suiteName: "group.com.yourname.pivotstream") {
            defaults.set(text, forKey: "pendingText")
        }

        // Open the main app via URL scheme
        var responder: UIResponder? = self
        while let next = responder?.next {
            responder = next
            if let app = responder as? UIApplication {
                app.open(url)
                break
            }
        }

        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "PivotStreamShareExtension",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "No shareable content found."]
        ))
    }
}
