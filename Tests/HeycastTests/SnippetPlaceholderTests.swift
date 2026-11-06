import Foundation
import Testing

@testable import Heycast

@Suite struct SnippetPlaceholderTests {
    /// 2023-11-14T22:13:20Z.
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let fixedUUID = UUID(uuidString: "00000000-0000-4000-8000-000000000000")!
    private let utc = TimeZone(identifier: "UTC")!

    private func expand(
        _ body: String,
        clipboard: @escaping () -> String? = { nil }
    ) -> String {
        SnippetPlaceholders.expand(
            body,
            at: fixedDate,
            timeZone: utc,
            clipboard: clipboard,
            uuid: { fixedUUID }
        )
    }

    @Test func expandsDateAndTimeInLocalZone() {
        #expect(expand("{date}") == "2023-11-14")
        #expect(expand("{time}") == "22:13")
        #expect(expand("On {date} at {time}.") == "On 2023-11-14 at 22:13.")
    }

    @Test func expandsClipboardOncePerPaste() {
        var reads = 0
        let result = expand("{clipboard}-{clipboard}") {
            reads += 1
            return "copied"
        }

        #expect(result == "copied-copied")
        #expect(reads == 1)
    }

    @Test func missingClipboardExpandsToNothing() {
        #expect(expand("[{clipboard}]") == "[]")
    }

    @Test func expandsUUID() {
        #expect(expand("{uuid}") == fixedUUID.uuidString)
    }

    @Test func doubledBracesAreLiterals() {
        #expect(expand("{{date}}") == "{date}")
        #expect(expand("{{}}") == "{}")
        #expect(expand("{date} {{ and }} {time}") == "2023-11-14 { and } 22:13")
    }

    @Test func unknownPlaceholdersStayAsWritten() {
        #expect(expand("{unknown}") == "{unknown}")
        #expect(expand("a {DATE} b") == "a {DATE} b")
        #expect(expand("unclosed {date") == "unclosed {date")
    }

    @Test func textWithoutPlaceholdersIsUnchanged() {
        #expect(expand("Best regards,\nNilambar\n") == "Best regards,\nNilambar\n")
    }
}
