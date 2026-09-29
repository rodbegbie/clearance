import Foundation

// Reduces raw HTML embedded in a local Markdown document to a small allowlist of presentational tags.
// Everything else is shown as literal text, comments are dropped, and open tags are tracked so
// the output stays balanced. The allowlist is a trimmed-down version of GitHub's html-pipeline.
struct RawHTMLSanitizer {
    private var openTags: [String] = []

    var openTagCount: Int { openTags.count }

    mutating func sanitize(_ rawHTML: String) -> String {
        let nsRawHTML = rawHTML as NSString
        var output = ""
        var cursor = 0

        for match in Self.tokenRegex.matches(in: rawHTML, range: NSRange(location: 0, length: nsRawHTML.length)) {
            output += Self.escapeText(
                nsRawHTML.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            )
            cursor = match.range.location + match.range.length

            if match.range(at: 1).location != NSNotFound {
                continue
            }

            let name = nsRawHTML.substring(with: match.range(at: 3)).lowercased()
            guard Self.allowedElements.contains(name) else {
                output += Self.escapeText(nsRawHTML.substring(with: match.range))
                continue
            }

            if match.range(at: 2).length > 0 {
                output += closeElement(name)
            } else {
                output += openElement(name, attributeString: nsRawHTML.substring(with: match.range(at: 4)))
            }
        }

        output += Self.escapeText(nsRawHTML.substring(from: cursor))
        return output
    }

    mutating func closeTags(above depth: Int) -> String {
        guard openTags.count > depth else {
            return ""
        }

        let closers = openTags[depth...].reversed().map { "</\($0)>" }.joined()
        openTags.removeSubrange(depth...)
        return closers
    }

    static func imageTag(attributeString: String) -> String {
        var attributes: [String: String] = [:]
        for (name, value) in parseAttributes(attributeString) where imageAttributeNames.contains(name) {
            if name == "src" && !isSafeImageSource(value) {
                continue
            }
            attributes[name] = value
        }

        var html = "<img"
        for name in imageAttributeNames {
            guard let value = attributes[name], !value.isEmpty else {
                continue
            }
            html += " \(name)=\"\(escapeAttribute(value))\""
        }
        return html + " />"
    }

    static func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func escapeAttribute(_ text: String) -> String {
        escapeText(text)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private mutating func openElement(_ name: String, attributeString: String) -> String {
        if name == "img" {
            return Self.imageTag(attributeString: attributeString)
        }

        let attributes = Self.filteredAttributes(for: name, in: attributeString)
        if Self.voidElements.contains(name) {
            return "<\(name)\(attributes) />"
        }

        openTags.append(name)
        return "<\(name)\(attributes)>"
    }

    private mutating func closeElement(_ name: String) -> String {
        guard let index = openTags.lastIndex(of: name) else {
            return ""
        }
        return closeTags(above: index)
    }

    private static func filteredAttributes(for element: String, in attributeString: String) -> String {
        let permitted = globalAttributeNames.union(elementAttributeNames[element] ?? [])
        var seen: Set<String> = []
        var html = ""

        for (name, value) in parseAttributes(attributeString) where permitted.contains(name) {
            guard seen.insert(name).inserted, let safeValue = sanitizedValue(value, forAttribute: name) else {
                continue
            }
            html += " \(name)=\"\(escapeAttribute(safeValue))\""
        }
        return html
    }

    private static func sanitizedValue(_ value: String, forAttribute name: String) -> String? {
        switch name {
        case "open":
            return ""
        case "href":
            return isSafeLink(value) ? value : nil
        case "align":
            return ["left", "right", "center", "justify"].contains(value.lowercased()) ? value.lowercased() : nil
        case "dir":
            return ["ltr", "rtl", "auto"].contains(value.lowercased()) ? value.lowercased() : nil
        case "colspan", "rowspan":
            return value.range(of: #"^[0-9]{1,3}$"#, options: .regularExpression) != nil ? value : nil
        default:
            return value.isEmpty ? nil : value
        }
    }

    private static func parseAttributes(_ attributeString: String) -> [(name: String, value: String)] {
        let nsAttributeString = attributeString as NSString
        let range = NSRange(location: 0, length: nsAttributeString.length)

        return attributeRegex.matches(in: attributeString, range: range).map { match in
            let name = nsAttributeString.substring(with: match.range(at: 1)).lowercased()
            let valueRange = [2, 3, 4]
                .map { match.range(at: $0) }
                .first { $0.location != NSNotFound }
            let rawValue = valueRange.map { nsAttributeString.substring(with: $0) } ?? ""
            return (name, decodeHTMLEntities(rawValue).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func isSafeLink(_ link: String) -> Bool {
        let normalized = withoutWhitespaceAndControls(link)
        guard !normalized.isEmpty else {
            return false
        }

        guard let delimiter = normalized.firstIndex(where: { ":/?#".contains($0) }),
              normalized[delimiter] == ":" else {
            return true
        }
        return safeLinkSchemes.contains(normalized[..<delimiter].lowercased())
    }

    private static func isSafeImageSource(_ source: String) -> Bool {
        let normalized = withoutWhitespaceAndControls(source).lowercased()
        return !normalized.isEmpty && !normalized.hasPrefix("javascript:") && !normalized.hasPrefix("vbscript:")
    }

    // Browsers ignore tabs, newlines and other control characters inside a URL scheme.
    private static func withoutWhitespaceAndControls(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { $0.value > 0x20 && $0.value != 0x7F }))
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static let tokenRegex = try! NSRegularExpression(
        pattern: #"(<!--[\s\S]*?(?:-->|\z))|<(/?)([A-Za-z][A-Za-z0-9-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>"#
    )
    private static let attributeRegex = try! NSRegularExpression(
        pattern: #"(?<![\w:-])([A-Za-z][A-Za-z0-9:-]*)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?"#
    )

    private static let allowedElements: Set<String> = [
        "details", "summary",
        "a", "abbr", "b", "del", "em", "i", "ins", "kbd", "mark", "s", "small", "span", "strong", "sub", "sup",
        "br", "hr", "img", "div", "p",
        "table", "thead", "tbody", "tr", "th", "td"
    ]
    private static let voidElements: Set<String> = ["br", "hr", "img"]
    private static let safeLinkSchemes: Set<String> = ["http", "https", "mailto"]
    private static let imageAttributeNames = ["src", "alt", "title", "width", "height"]
    private static let globalAttributeNames: Set<String> = ["title", "lang", "dir"]
    private static let elementAttributeNames: [String: Set<String>] = [
        "a": ["href"],
        "details": ["open"],
        "div": ["align"],
        "p": ["align"],
        "th": ["align", "colspan", "rowspan"],
        "td": ["align", "colspan", "rowspan"]
    ]
}
