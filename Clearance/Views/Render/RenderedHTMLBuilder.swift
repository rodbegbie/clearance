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
          <meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; style-src 'unsafe-inline'; img-src data: file:;\" />
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
        :root {
          color-scheme: light dark;
          --bg: #fdf6e3;
          --surface: rgba(238, 232, 213, 0.94);
          --border: rgba(88, 110, 117, 0.26);
          --text: #657b83;
          --muted: #586e75;
          --heading: #268bd2;
          --code-bg: #0f3742;
          --code-text: #d4e3e7;
          --inline-bg: rgba(147, 161, 161, 0.26);
          --inline-text: #859900;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --bg: #002b36;
            --surface: rgba(7, 54, 66, 0.9);
            --border: rgba(147, 161, 161, 0.25);
            --text: #839496;
            --muted: #586e75;
            --heading: #5fa8d7;
            --code-bg: #00232c;
            --code-text: #c8d9dd;
            --inline-bg: rgba(147, 161, 161, 0.14);
            --inline-text: #7bd1bd;
          }
        }
        body { margin: 0; font-family: Georgia, 'Iowan Old Style', serif; background: var(--bg); color: var(--text); }
        .document { max-width: 860px; margin: 32px auto; padding: 0 24px 64px; }
        .frontmatter { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 12px 16px; margin-bottom: 22px; }
        .frontmatter h2 { margin: 0 0 8px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 8px 10px; vertical-align: top; border-top: 1px solid var(--border); font-size: 13px; }
        th { width: 35%; color: var(--muted); font-weight: 600; }
        .markdown { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 24px; }
        .markdown h1, .markdown h2, .markdown h3 { color: var(--heading); font-family: 'Palatino Linotype', 'Book Antiqua', Palatino, serif; }
        .markdown p { line-height: 1.65; }
        .markdown code { background: var(--inline-bg); color: var(--inline-text); padding: 2px 6px; border-radius: 6px; font-size: 0.9em; }
        .markdown pre { background: var(--code-bg); color: var(--code-text); padding: 14px; border-radius: 10px; overflow-x: auto; }
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
