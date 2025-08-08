
import SwiftUI
@preconcurrency import WebKit

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

struct WebView: NSViewRepresentable {
    
    var webView: WKWebView = WKWebView()
    var url: URL?
    @Binding var reload: Bool
    private let downloadCompleted: (URL) -> ()
    
    init(url: URL?, reload: Binding<Bool>, downloadCompleted: @escaping(URL) -> ()) {
        self.url = url
        _reload = reload
        self.downloadCompleted = downloadCompleted
    }
    
    func makeNSView(context: Context) -> WKWebView {
        print("WebView makeNSView")
        guard let url = url else {
            return webView
        }
        
        let request = URLRequest(url: url)
        webView.setValue(false, forKey: "drawsBackground")
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.load(request)
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        print("WebView updateNSView")
        if (reload) {
            webView.reload()
            reload = false
        }
    }
    
    func onDownloadCompleted(_ filePathDestination: URL) {
        downloadCompleted(filePathDestination)
    }
    
    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKDownloadDelegate {
        var parent: WebView
        private var filePathDestination: URL?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let langStr = {
                switch Locale.current.language.languageCode?.identifier {
                case "fr":
                    return "fr"
                default:
                    return "en"
                }
            }()
            
            let htmlPath = Bundle.main.path(forResource: "errorPage.\(langStr)", ofType: "html")
            let htmlUrl = URL(fileURLWithPath: htmlPath!, isDirectory: false)
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download, preferences)
            } else {
                decisionHandler(.allow, preferences)
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                decisionHandler(.download)
            }
        }
        
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            if let path = getDownloadPath(suggestedFilename as NSString) {
                filePathDestination = path
                completionHandler(path)
            } else {
                // Fallback to a temporary location if we couldn't compute a path
                let fallback = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedFilename)
                filePathDestination = fallback
                completionHandler(fallback)
            }
        }
        
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }
        
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }
        
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            print("Failed to download: \(error)")
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            
            return nil
        }
        
        func downloadDidFinish(_ download: WKDownload) {
            guard let filePathDestination = filePathDestination else {
                return
            }
            parent.onDownloadCompleted(filePathDestination)
            cleanUp()
        }
        
        private func getDownloadPath(_ suggestedFilename: NSString, _ counter: Int = 0) -> URL? {
            do {
                guard let downloadDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
                    print("no downloads path")
                    return nil
                }
                try FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
                
                // Add "(x)" in case the file already exists
                let pathExtension = suggestedFilename.pathExtension
                let pathPrefix = suggestedFilename.deletingPathExtension
                let counterSuffix = counter > 0 ? "(\(counter))" : ""
                let fileName = "\(pathPrefix)\(counterSuffix).\(pathExtension)"
                
                let path = downloadDirectory.appendingPathComponent(fileName)
                if (FileManager.default.fileExists(atPath: path.path)) {
                    return getDownloadPath(suggestedFilename, counter + 1)
                }
                
                return path
            } catch {
                print(error)
                return nil
            }
        }
        
        private func cleanUp() {
            filePathDestination = nil
        }
        
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            
            let alert = NSAlert()
            alert.messageText = prompt
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
            textField.stringValue = defaultText ?? ""
            alert.accessoryView = textField
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                completionHandler(textField.stringValue)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}
