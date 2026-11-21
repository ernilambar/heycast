import Foundation

/// One user-authored snippet: a keyword and the text it expands to.
///
/// Snippets are plain Markdown files in the snippets folder, so they stay
/// readable and editable outside Heycast. The filename is irrelevant; the
/// front matter carries the identity.
struct Snippet: Identifiable, Hashable, Sendable {
    /// Where the pasted text comes from.
    enum Source: Hashable, Sendable {
        /// The body, pasted with placeholders expanded.
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

/// A snippet file that could not be used. The palette lists these in the
/// snippets scope so a silently skipped file is visible and revealable.
struct InvalidSnippet: Identifiable, Hashable, Sendable {
    let url: URL
    let reason: String

    var id: URL { url }

    /// Filename without `.md`, used as the row title.
    var name: String {
        url.deletingPathExtension().lastPathComponent
    }
}

/// Result of reading a snippets folder: usable snippets and the files that
/// failed validation.
struct SnippetScan: Sendable {
    let snippets: [Snippet]
    let invalid: [InvalidSnippet]
}

/// Why a snippet file was rejected. The text is shown in the palette, so it
/// says what to fix rather than only naming a parser state.
enum SnippetParseError: Error, Equatable, Sendable {
    case notUTF8
    case missingFrontMatter
    case missingKeyword
    case unknownType(String)
    case emptyBody

    var reason: String {
        switch self {
        case .notUTF8:
            "Not UTF-8 text."
        case .missingFrontMatter:
            "No front matter; start the file with ---."
        case .missingKeyword:
            "Front matter has no keyword."
        case .unknownType(let type):
            "Unknown type “\(type)”. Use text or script."
        case .emptyBody:
            "The body is empty."
        }
    }
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
/// with an empty body (other than `script:` ones) are returned as invalid with
/// a reason instead of being dropped: the palette shows them. The body is
/// everything after the closing `---` line, kept exactly as written so
/// placeholders expand at paste time, not here.
enum SnippetLibrary {
    static let fileExtension = "md"

    /// Every snippet in `directory` plus the files that failed validation.
    /// Reads are non-recursive: the folder is flat by design, so a stray `.md`
    /// in a subfolder cannot silently join the palette.
    static func scan(from directory: URL) -> SnippetScan {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return SnippetScan(snippets: [], invalid: [])
        }

        var snippets: [Snippet] = []
        var invalid: [InvalidSnippet] = []

        for url in entries
        where url.pathExtension.caseInsensitiveCompare(fileExtension) == .orderedSame {
            guard let data = try? Data(contentsOf: url) else {
                invalid.append(
                    InvalidSnippet(url: url, reason: "Cannot read the file.")
                )
                continue
            }

            switch validate(data, url: url) {
            case .success(let snippet):
                snippets.append(snippet)
            case .failure(let error):
                NSLog("Heycast: snippet %@: %@", url.path, error.reason)
                invalid.append(InvalidSnippet(url: url, reason: error.reason))
            }
        }

        snippets.sort {
            let comparison = $0.keyword.localizedStandardCompare($1.keyword)
            if comparison == .orderedSame {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return comparison == .orderedAscending
        }
        invalid.sort {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        return SnippetScan(snippets: snippets, invalid: invalid)
    }

    static func parse(_ data: Data, url: URL) -> Snippet? {
        try? validate(data, url: url).get()
    }

    static func parse(_ text: String, url: URL) -> Snippet? {
        try? validate(text, url: url).get()
    }

    static func validate(_ data: Data, url: URL) -> Result<Snippet, SnippetParseError> {
        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(.notUTF8)
        }
        return validate(text, url: url)
    }

    static func validate(_ text: String, url: URL) -> Result<Snippet, SnippetParseError> {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        guard let opening = lines.first, opening.trimmingCharacters(in: .whitespaces) == "---" else {
            return .failure(.missingFrontMatter)
        }
        guard let closing = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else {
            return .failure(.missingFrontMatter)
        }

        var fields: [String: String] = [:]
        for line in lines[1..<closing] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            fields[key] = unquoted(line[line.index(after: colon)...])
        }

        guard let keyword = fields["keyword"], !keyword.isEmpty else {
            return .failure(.missingKeyword)
        }
        let name = fields["name"].flatMap { $0.isEmpty ? nil : $0 } ?? keyword

        if let path = fields["script"], !path.isEmpty {
            let file = resolve(path, relativeTo: url.deletingLastPathComponent())
            return .success(
                Snippet(
                    keyword: keyword,
                    name: name,
                    body: "",
                    url: url,
                    source: .scriptFile(file)
                )
            )
        }

        let source: Snippet.Source
        let kind = fields["type"]?.lowercased() ?? ""
        switch kind {
        case "", "text":
            source = .text
        case "script":
            source = .inlineScript
        default:
            return .failure(.unknownType(kind))
        }

        let body = lines[(closing + 1)...].joined(separator: "\n")
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyBody)
        }

        return .success(
            Snippet(keyword: keyword, name: name, body: body, url: url, source: source)
        )
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

/// Expands the placeholders a text snippet supports.
///
/// Called when the snippet is pasted or typed out, never when it is parsed, so
/// `{date}`, `{time}` and `{clipboard}` describe the moment of use. Script
/// snippets are not expanded: their output is pasted as printed.
///
/// `{{` and `}}` produce a literal brace. An unknown `{name}` stays as written
/// and is logged once per process.
enum SnippetPlaceholders {
    static func expand(
        _ body: String,
        at date: Date,
        timeZone: TimeZone = .current,
        clipboard: () -> String?,
        uuid: () -> UUID
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let dateText = String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
        let timeText = String(
            format: "%02d:%02d",
            parts.hour ?? 0,
            parts.minute ?? 0
        )

        // Read the pasteboard only when the body asks for it, and once for
        // repeated placeholders.
        var clipboardText: String?

        var result = ""
        result.reserveCapacity(body.count)

        var index = body.startIndex
        while index < body.endIndex {
            let character = body[index]

            if character == "{" {
                let afterBrace = body.index(after: index)

                if afterBrace < body.endIndex, body[afterBrace] == "{" {
                    result.append("{")
                    index = body.index(after: afterBrace)
                    continue
                }

                if let closing = body[afterBrace...].firstIndex(of: "}") {
                    let name = String(body[afterBrace..<closing])
                    switch name {
                    case "date":
                        result.append(dateText)
                    case "time":
                        result.append(timeText)
                    case "clipboard":
                        if clipboardText == nil {
                            clipboardText = clipboard() ?? ""
                        }
                        result.append(clipboardText ?? "")
                    case "uuid":
                        result.append(uuid().uuidString)
                    default:
                        logUnknown(name)
                        result.append("{")
                        result.append(name)
                        result.append("}")
                    }
                    index = body.index(after: closing)
                    continue
                }
            } else if character == "}" {
                let afterBrace = body.index(after: index)
                if afterBrace < body.endIndex, body[afterBrace] == "}" {
                    result.append("}")
                    index = body.index(after: afterBrace)
                    continue
                }
            }

            result.append(character)
            index = body.index(after: index)
        }

        return result
    }

    private static let logLock = NSLock()
    nonisolated(unsafe) private static var loggedUnknown: Set<String> = []

    /// One log line per unknown placeholder per process; pasting the same
    /// tolerance note on every use would bury the rest of the log.
    private static func logUnknown(_ name: String) {
        logLock.lock()
        defer { logLock.unlock() }
        guard loggedUnknown.insert(name).inserted else { return }
        NSLog(
            "Heycast: unknown snippet placeholder {%@}; leaving it as written",
            name
        )
    }
}
