import UIKit
import WebKit
import UniformTypeIdentifiers

final class WebViewController: UIViewController, WKUIDelegate, WKScriptMessageHandler, UIDocumentPickerDelegate {

    private enum PickerMode { case open, save }

    private var webView: WKWebView!
    private var pickerMode: PickerMode = .open
    private var openCompletion: (([URL]?) -> Void)?
    private var openedFiles: [String: URL] = [:]

    private let background = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)

    override func loadView() {
        view = UIView()
        view.backgroundColor = background
    }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalSchemeHandler(), forURLScheme: "gridcraft")
        config.defaultWebpagePreferences.preferredContentMode = .desktop

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Bridge.script,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))
        controller.add(self, name: "saveFile")
        config.userContentController = controller

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = background
        webView.scrollView.backgroundColor = background
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isInspectable = true

        view.addSubview(webView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: guide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: guide.trailingAnchor)
        ])

        webView.load(URLRequest(url: URL(string: "gridcraft://app/index.html")!))
    }

    // MARK: Opening files

    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        guard presentedViewController == nil else { completionHandler(nil); return }
        pickerMode = .open
        openCompletion = completionHandler
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: false)
        picker.allowsMultipleSelection = parameters.allowsMultipleSelection
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: Saving files

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "saveFile",
              let body = message.body as? [String: Any],
              let rawName = body["name"] as? String,
              let b64 = body["data"] as? String,
              let data = Data(base64Encoded: b64),
              presentedViewController == nil else { return }

        let name = rawName.replacingOccurrences(of: "/", with: "_")

        if let original = openedFiles[name] {
            let alert = UIAlertController(
                title: "Save “\(name)”",
                message: "You opened this file from Files. What would you like to do?",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Replace Original", style: .default) { _ in
                self.overwrite(original, with: data)
            })
            alert.addAction(UIAlertAction(title: "Save as New Copy…", style: .default) { _ in
                self.export(name: name, data: data)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        } else {
            export(name: name, data: data)
        }
    }

    private func export(name: String, data: Data) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent(name)
            try data.write(to: file)
            pickerMode = .save
            let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
            picker.delegate = self
            present(picker, animated: true)
        } catch {
            showMessage("Couldn’t prepare file", error.localizedDescription)
        }
    }

    private func overwrite(_ url: URL, with data: Data) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
            do { try data.write(to: writeURL) } catch { writeError = error }
        }
        if let e = (coordError as Error?) ?? writeError {
            showMessage("Couldn’t save", e.localizedDescription)
        }
    }

    private func showMessage(_ title: String, _ text: String) {
        let a = UIAlertController(title: title, message: text, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: Picker results

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        switch pickerMode {
        case .open:
            var results: [URL] = []
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let folder = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let copy = folder.appendingPathComponent(url.lastPathComponent)
                var coordError: NSError?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
                    try? FileManager.default.copyItem(at: readURL, to: copy)
                }
                if FileManager.default.fileExists(atPath: copy.path) {
                    results.append(copy)
                    openedFiles[url.lastPathComponent] = url
                }
            }
            openCompletion?(results.isEmpty ? nil : results)
            openCompletion = nil
        case .save:
            if let url = urls.first { openedFiles[url.lastPathComponent] = url }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        if pickerMode == .open {
            openCompletion?(nil)
            openCompletion = nil
        }
    }
}
