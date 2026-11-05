import Darwin
import Foundation

/// Produces the text a snippet pastes: the body as written, or the standard
/// output of its script.
///
/// Scripts run off the main thread with the login shell's `PATH`, so
/// `#!/usr/bin/env python3` finds the same interpreter Terminal does. Output
/// goes to files rather than pipes: a background child that keeps the
/// descriptor open cannot stall the paste, and nothing fills up and blocks.
enum SnippetRunner {
    enum Failure: Error, CustomStringConvertible {
        case launch(String)
        case exit(Int32, String)
        case unsafeFile(String, String)
        case timedOut
        case emptyOutput
        case invalidOutput

        var description: String {
            switch self {
            case .launch(let reason): "could not start: \(reason)"
            case .exit(let status, let stderr):
                stderr.isEmpty ? "exited with status \(status)" : "exited with status \(status): \(stderr)"
            case .unsafeFile(let path, let reason): "refused: \(path) \(reason)"
            case .timedOut: "timed out"
            case .emptyOutput: "printed nothing"
            case .invalidOutput: "printed text that is not UTF-8"
            }
        }
    }

    static let defaultTimeout: TimeInterval = 5

    /// The text to paste, or `nil` after logging why the script failed.
    static func text(for snippet: Snippet) async -> String? {
        do {
            return try await resolve(snippet)
        } catch {
            NSLog("Heycast: snippet “%@” script %@", snippet.keyword, String(describing: error))
            return nil
        }
    }

    static func resolve(_ snippet: Snippet, timeout: TimeInterval = defaultTimeout) async throws -> String {
        switch snippet.source {
        case .text:
            return snippet.body
        case .inlineScript:
            try checkOwnership(of: snippet.url)
            return try await offMain { try runInline(snippet.body, timeout: timeout) }
        case .scriptFile(let file):
            try checkOwnership(of: snippet.url)
            try checkOwnership(of: file)
            return try await offMain { try run(file, timeout: timeout) }
        }
    }

    /// Refuses code that someone else could have written, like `ssh` does
    /// with its config: the file must belong to you or root and must not be
    /// writable by group or others. Symlinks are followed, so the check
    /// applies to the file that actually runs. A missing file passes here and
    /// fails at launch with the clearer error.
    static func checkOwnership(of url: URL) throws {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return }

        if info.st_uid != getuid(), info.st_uid != 0 {
            throw Failure.unsafeFile(url.path, "is owned by another user")
        }
        if info.st_mode & (S_IWGRP | S_IWOTH) != 0 {
            throw Failure.unsafeFile(url.path, "is writable by group or others")
        }
    }

    private static func offMain(_ work: @escaping @Sendable () throws -> String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    /// Writes the body to an executable file so the kernel honors its `#!`
    /// line. Leading blank lines come off first: a shebang must open the file.
    private static func runInline(_ body: String, timeout: TimeInterval) throws -> String {
        var source = Substring(body)
        while let newline = source.firstIndex(of: "\n"),
              source[..<newline].allSatisfy(\.isWhitespace) {
            source = source[source.index(after: newline)...]
        }
        let script = source.hasPrefix("#!") ? String(source) : "#!/bin/zsh\n" + source

        let directory = try makeWorkDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("snippet")
        try Data(script.utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        return try run(file, timeout: timeout, workDirectory: directory)
    }

    private static func run(_ executable: URL, timeout: TimeInterval) throws -> String {
        let directory = try makeWorkDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        return try run(executable, timeout: timeout, workDirectory: directory)
    }

    private static func run(_ executable: URL, timeout: TimeInterval, workDirectory: URL) throws -> String {
        let stdoutURL = workDirectory.appendingPathComponent("stdout")
        let stderrURL = workDirectory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdout.close()
            try? stderr.close()
        }

        let process = Process()
        process.executableURL = executable
        process.environment = environment
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdout
        process.standardError = stderr

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            throw Failure.launch(error.localizedDescription)
        }

        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if exited.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
            }
            throw Failure.timedOut
        }

        guard process.terminationStatus == 0 else {
            let message = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
            throw Failure.exit(
                process.terminationStatus,
                message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        guard let output = String(data: try Data(contentsOf: stdoutURL), encoding: .utf8) else {
            throw Failure.invalidOutput
        }
        let text = trimmingOneTrailingNewline(output)
        guard !text.isEmpty else { throw Failure.emptyOutput }
        return text
    }

    /// `echo`, `print` and heredocs all end with a newline nobody wants pasted;
    /// only one comes off, so deliberate blank lines survive.
    static func trimmingOneTrailingNewline(_ text: String) -> String {
        if text.hasSuffix("\r\n") { return String(text.dropLast(2)) }
        if text.hasSuffix("\n") { return String(text.dropLast()) }
        return text
    }

    private static func makeWorkDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("heycast-script-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// The app's environment with `PATH` taken from the login shell. Apps
    /// started from Finder or at login only see `/usr/bin:/bin:/usr/sbin:/sbin`.
    private static let environment: [String: String] = {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = loginShellPath() ?? fallbackPath(environment["PATH"])
        return environment
    }()

    private static func loginShellPath() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"].flatMap { $0.isEmpty ? nil : $0 } ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", "printf %s \"$PATH\""]
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let output = Pipe()
        process.standardOutput = output

        do {
            try process.run()
        } catch {
            NSLog("Heycast: cannot read PATH from %@: %@", shell, error.localizedDescription)
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty
        else {
            NSLog("Heycast: cannot read PATH from %@", shell)
            return nil
        }
        return path
    }

    private static func fallbackPath(_ current: String?) -> String {
        let extra = ["/opt/homebrew/bin", "/usr/local/bin"]
        let base = current?.split(separator: ":").map(String.init) ?? ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        return (extra.filter { !base.contains($0) } + base).joined(separator: ":")
    }
}
