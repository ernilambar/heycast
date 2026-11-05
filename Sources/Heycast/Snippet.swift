import Foundation

/// One user-authored snippet: a keyword and the text it expands to.
///
/// Snippets are plain Markdown files in the snippets folder, so they stay
/// readable and editable outside Heycast. The filename is irrelevant; the
/// front matter carries the identity.
struct Snippet: Identifiable, Hashable, Sendable {
    /// Where the pasted text comes from.
    enum Source: Hashable, Sendable {
        /// The body, pasted as written.
        case text
        /// The body is a script; its standard output is pasted.
        case inlineScript
        /// An executable file outside the snippet; its standard output is pasted.
        case scriptFile(URL)
    }

    /// What the snippet is matched and displayed by, e.g. `;sig`.
    let keyword: String
    /// Human-readable title; defaults to the keyword when front matter omits it.
    let name: String
    /// Exact text pasted when the snippet is activated, or the script source
    /// for `.inlineScript`. Empty for `.scriptFile`.
    let body: String
    let url: URL
    var source: Source = .text

    var isScript: Bool { source != .text }

    var id: URL { url }
}

/// Reads the snippets folder. Each `.md` file must open with a front-matter
/// block delimited by `---` lines:
///
///     ---
///     keyword: ;sig
///     name: Email signature
///     ---
///
///     Best regards,
///     Nilambar
///
/// Two front-matter fields turn a snippet into a script whose standard output
/// is pasted instead of the body:
///
/// - `type: script` runs the body. Its `#!` line picks the interpreter;
///   without one it runs with `/bin/zsh`.
/// - `script: <path>` runs an executable file and ignores the body. `~`
///   expands to the home folder; a relative path resolves against the
///   snippet file's folder.
///
/// Files without front matter, without a keyword, with an unknown `type`, or
/// with an empty body (other than `script:` ones) are skipped: there is
/// nothing to match or paste. The body is everything after
/// the closing `---` line, kept exactly as written (leading blank lines and
/// the trailing newline included), so a snippet pastes the same text in every
/// editor that authored it.
enum SnippetLibrary {
    static let fileExtension = "md"

    /// Every valid snippet in `directory`, ordered by keyword. Reads are
    /// non-recursive: the folder is flat by design, so a stray `.md` in a
    /// subfolder cannot silently join the palette.
    static func load(from directory: URL) -> [Snippet] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let snippets = entries
            .filter { $0.pathExtension.caseInsensitiveCompare(fileExtension) == .orderedSame }
            .compactMap { url -> Snippet? in
                guard let data = try? Data(contentsOf: url) else {
                    NSLog("Heycast: cannot read snippet %@", url.path)
                    return nil
                }
                guard let snippet = parse(data, url: url) else {
                    NSLog("Heycast: skipping snippet without usable front matter: %@", url.path)
                    return nil
                }
                return snippet
            }

        return snippets.sorted {
            let comparison = $0.keyword.localizedStandardCompare($1.keyword)
            if comparison == .orderedSame {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return comparison == .orderedAscending
        }
    }

    static func parse(_ data: Data, url: URL) -> Snippet? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return parse(text, url: url)
    }

    static func parse(_ text: String, url: URL) -> Snippet? {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        guard let opening = lines.first, opening.trimmingCharacters(in: .whitespaces) == "---" else {
            return nil
        }
        guard let closing = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return nil
        }

        var fields: [String: String] = [:]
        for line in lines[1..<closing] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            fields[key] = unquoted(line[line.index(after: colon)...])
        }

        guard let keyword = fields["keyword"], !keyword.isEmpty else { return nil }
        let name = fields["name"].flatMap { $0.isEmpty ? nil : $0 } ?? keyword

        if let path = fields["script"], !path.isEmpty {
            let file = resolve(path, relativeTo: url.deletingLastPathComponent())
            return Snippet(keyword: keyword, name: name, body: "", url: url, source: .scriptFile(file))
        }

        let source: Snippet.Source
        switch fields["type"]?.lowercased() ?? "" {
        case "", "text": source = .text
        case "script": source = .inlineScript
        default: return nil
        }

        let body = lines[(closing + 1)...].joined(separator: "\n")
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        return Snippet(keyword: keyword, name: name, body: body, url: url, source: source)
    }

    private static func resolve(_ path: String, relativeTo directory: URL) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }
        return directory.appendingPathComponent(expanded).standardizedFileURL
    }

    /// Surrounding whitespace and one pair of matching quotes come off, so
    /// `keyword: ";sig"` and `keyword: ;sig` behave the same.
    private static func unquoted(_ raw: Substring) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)
        if value.count >= 2,
           (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }
        return value
    }
}
