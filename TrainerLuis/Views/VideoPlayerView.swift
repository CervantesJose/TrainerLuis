import SwiftUI
import WebKit

struct VideoPlayerView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let embedURL = Self.embedURL(from: urlString), let url = URL(string: embedURL) else {
            return
        }
        webView.load(URLRequest(url: url))
    }

    static func embedURL(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Already an embed URL
        if trimmed.contains("youtube.com/embed/") { return trimmed }

        // youtu.be short link
        if let range = trimmed.range(of: "youtu.be/") {
            let videoID = String(trimmed[range.upperBound...]).components(separatedBy: "?").first ?? ""
            return "https://www.youtube.com/embed/\(videoID)"
        }

        // Full watch URL
        if let components = URLComponents(string: trimmed),
           let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return "https://www.youtube.com/embed/\(videoID)"
        }

        return trimmed
    }

    static func isValidVideoURL(_ raw: String) -> Bool {
        embedURL(from: raw) != nil
    }
}

#Preview {
    VideoPlayerView(urlString: "https://www.youtube.com/watch?v=nKVZBKoB6P4")
}
