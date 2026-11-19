import SwiftUI
import WebKit

/// Plays an exercise's demo video inline, using SwiftUI's native `WebView`.
struct VideoPlayerView: View {
    let urlString: String

    @State private var page: WebPage = {
        var configuration = WebPage.Configuration()
        configuration.mediaPlaybackBehavior = .allowsInlinePlayback
        return WebPage(configuration: configuration)
    }()

    var body: some View {
        WebView(page)
            .scrollDisabled(true)
            .background(.black)
            .task(id: urlString) {
                guard let embedURL = Self.embedURL(from: urlString), let url = URL(string: embedURL) else {
                    return
                }
                page.load(url)
            }
    }

    static func embedURL(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Already an embed URL
        if trimmed.contains("youtube.com/embed/") { return trimmed }

        // youtu.be short link
        if let range = trimmed.range(of: "youtu.be/") {
            let videoID = trimmed[range.upperBound...].split(separator: "?").first.map(String.init) ?? ""
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
        .aspectRatio(16 / 9, contentMode: .fit)
}
