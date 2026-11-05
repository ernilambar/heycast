import Foundation
import Testing

@testable import Heycast

private let snippetURL = URL(fileURLWithPath: "/tmp/heycast-tests/script.md")

private func inline(_ body: String) -> Snippet {
    Snippet(keyword: ";s", name: "Script", body: body, url: snippetURL, source: .inlineScript)
}

@Suite struct SnippetScriptParsingTests {
    @Test func typeScriptMakesAnInlineScript() {
        let snippet = SnippetLibrary.parse(
            "---\nkeyword: ;dns\ntype: script\n---\necho hi\n",
            url: snippetURL
        )

        #expect(snippet?.source == .inlineScript)
        #expect(snippet?.body == "echo hi\n")
    }

    @Test func scriptPathNeedsNoBody() {
        let snippet = SnippetLibrary.parse(
            "---\nkeyword: ;dns\nscript: /usr/local/bin/dns\n---\n",
            url: snippetURL
        )

        #expect(snippet?.source == .scriptFile(URL(fileURLWithPath: "/usr/local/bin/dns")))
    }

    @Test func scriptPathExpandsTilde() {
        let snippet = SnippetLibrary.parse(
            "---\nkeyword: ;dns\nscript: ~/bin/dns.py\n---\n",
            url: snippetURL
        )

        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(snippet?.source == .scriptFile(home.appendingPathComponent("bin/dns.py").standardizedFileURL))
    }

    @Test func relativeScriptPathResolvesAgainstSnippetFolder() {
        let snippet = SnippetLibrary.parse(
            "---\nkeyword: ;dns\nscript: scripts/dns.sh\n---\n",
            url: snippetURL
        )

        #expect(snippet?.source == .scriptFile(URL(fileURLWithPath: "/tmp/heycast-tests/scripts/dns.sh")))
    }

    @Test func unknownTypeIsSkipped() {
        #expect(
            SnippetLibrary.parse("---\nkeyword: ;x\ntype: macro\n---\nBody\n", url: snippetURL) == nil
        )
    }

    @Test func plainSnippetsStayText() {
        let snippet = SnippetLibrary.parse("---\nkeyword: ;x\n---\nBody\n", url: snippetURL)
        #expect(snippet?.source == .text)
        #expect(snippet?.isScript == false)
    }
}

@Suite struct SnippetRunnerTests {
    @Test func textSnippetsReturnTheBodyVerbatim() async throws {
        let snippet = Snippet(keyword: ";t", name: "T", body: "Body\n", url: snippetURL)
        #expect(try await SnippetRunner.resolve(snippet) == "Body\n")
    }

    @Test func inlineScriptWithoutShebangRunsInZsh() async throws {
        let output = try await SnippetRunner.resolve(inline("print -r -- ${ZSH_VERSION:+zsh}\n"))
        #expect(output == "zsh")
    }

    @Test func shebangPicksTheInterpreter() async throws {
        let output = try await SnippetRunner.resolve(inline("\n#!/usr/bin/perl\nprint \"perl\\n\";\n"))
        #expect(output == "perl")
    }

    @Test func onlyOneTrailingNewlineIsStripped() async throws {
        let output = try await SnippetRunner.resolve(inline("printf 'a\\n\\n'"))
        #expect(output == "a\n")
    }

    @Test func multilineOutputIsKept() async throws {
        let output = try await SnippetRunner.resolve(inline("cat <<EOF\nHi,\n\nRegards,\nEOF\n"))
        #expect(output == "Hi,\n\nRegards,")
    }

    @Test func nonZeroExitFailsWithStderr() async {
        do {
            _ = try await SnippetRunner.resolve(inline("echo nope >&2\nexit 3\n"))
            Issue.record("expected failure")
        } catch let failure as SnippetRunner.Failure {
            #expect(failure.description == "exited with status 3: nope")
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test func emptyOutputFails() async {
        await #expect(throws: SnippetRunner.Failure.self) {
            try await SnippetRunner.resolve(inline("true\n"))
        }
    }

    @Test func slowScriptsTimeOut() async {
        let started = Date()
        do {
            _ = try await SnippetRunner.resolve(inline("sleep 10\n"), timeout: 0.3)
            Issue.record("expected timeout")
        } catch let failure as SnippetRunner.Failure {
            #expect(failure.description == "timed out")
        } catch {
            Issue.record("unexpected error \(error)")
        }
        #expect(Date().timeIntervalSince(started) < 3)
    }

    @Test func scriptFileRunsAndMissingFileFails() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("heycast-runner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("hello.sh")
        try "#!/bin/sh\necho hello\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)

        let snippet = Snippet(keyword: ";h", name: "H", body: "", url: snippetURL, source: .scriptFile(file))
        #expect(try await SnippetRunner.resolve(snippet) == "hello")

        let missing = Snippet(
            keyword: ";m", name: "M", body: "", url: snippetURL,
            source: .scriptFile(directory.appendingPathComponent("missing.sh"))
        )
        await #expect(throws: SnippetRunner.Failure.self) {
            try await SnippetRunner.resolve(missing)
        }
    }
}
