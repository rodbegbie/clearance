import Foundation
import Down

struct RenderedHTMLBuilder {
    func build(document: ParsedMarkdownDocument) -> String {
        let bodyHTML = (try? Down(markdownString: document.body).toHTML()) ?? "<pre>\(escapeHTML(document.body))</pre>"
        let frontmatterHTML = frontmatterTableHTML(from: document.flattenedFrontmatter)

        return """
        <!doctype html>
        <html lang=\"en\">
        <head>
          <meta charset=\"utf-8\" />
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
          <style>
          \(stylesheet())
          </style>
        </head>
        <body>
          <main class=\"document\">
            \(frontmatterHTML)
            <article class=\"markdown\">\(bodyHTML)</article>
          </main>
        </body>
        </html>
        """
    }

    private func frontmatterTableHTML(from frontmatter: [String: String]) -> String {
        guard !frontmatter.isEmpty else {
            return ""
        }

        let rows = frontmatter.keys.sorted().map { key in
            let value = frontmatter[key] ?? ""
            return "<tr><th>\(escapeHTML(key))</th><td>\(escapeHTML(value))</td></tr>"
        }.joined()

        return """
        <section class=\"frontmatter\">
          <h2>Metadata</h2>
          <table>
            <tbody>
              \(rows)
            </tbody>
          </table>
        </section>
        """
    }

    private func stylesheet() -> String {
        if let cssURL = Bundle.main.url(forResource: "render", withExtension: "css"),
           let css = try? String(contentsOf: cssURL) {
            return css
        }

        return """
        :root { color-scheme: light dark; }
        body { margin: 0; font-family: Georgia, 'Iowan Old Style', serif; background: #f4f3ee; color: #1e1b18; }
        .document { max-width: 860px; margin: 32px auto; padding: 0 24px 64px; }
        .frontmatter { background: rgba(255,255,255,0.8); border: 1px solid #d9d4c8; border-radius: 12px; padding: 12px 16px; margin-bottom: 22px; }
        .frontmatter h2 { margin: 0 0 8px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.06em; color: #6d665b; }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 8px 10px; vertical-align: top; border-top: 1px solid #e8e2d7; font-size: 13px; }
        th { width: 35%; color: #6b6459; font-weight: 600; }
        .markdown { background: rgba(255,255,255,0.8); border: 1px solid #d9d4c8; border-radius: 12px; padding: 24px; box-shadow: 0 12px 24px rgba(32, 28, 24, 0.08); }
        .markdown h1, .markdown h2, .markdown h3 { font-family: 'Palatino Linotype', 'Book Antiqua', Palatino, serif; }
        .markdown p { line-height: 1.65; }
        .markdown code { background: #efece3; padding: 2px 6px; border-radius: 6px; font-size: 0.9em; }
        .markdown pre { background: #1f2430; color: #f1f4f8; padding: 14px; border-radius: 10px; overflow-x: auto; }
        """
    }

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
