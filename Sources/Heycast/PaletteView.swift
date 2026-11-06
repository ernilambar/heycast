import AppKit
import SwiftUI

/// What a palette opening searches: everything, or snippets only.
enum PaletteScope: Equatable, Sendable {
    case all
    case snippets

    var searchPrompt: String {
        switch self {
        case .all: "Search applications and snippets…"
        case .snippets: "Search snippets…"
        }
    }
}

@MainActor
final class PaletteModel: ObservableObject {
    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            updateResults()
        }
    }
    @Published private(set) var results: [PaletteItem] = []
    @Published private(set) var selectionIndex = 0
    @Published private(set) var isLoading = false
    @Published private(set) var scope: PaletteScope = .all

    private let usageStore: UsageStore
    private var snippetsDirectory: URL
    private var usage = UsageRanking.empty
    private var applications: [LaunchableApp] = []
    private var snippets: [Snippet] = []
    private var invalidSnippets: [InvalidSnippet] = []
    private var scanTask: Task<Void, Never>?
    private var scanAgain = false

    init(
        usageStore: UsageStore = .shared,
        snippetsDirectory: URL = AppConfig.load().snippetsDirectoryURL()
    ) {
        self.usageStore = usageStore
        self.snippetsDirectory = snippetsDirectory
    }

    var selected: PaletteItem? {
        results.indices.contains(selectionIndex) ? results[selectionIndex] : nil
    }

    /// Follows a changed `snippetsDirectory` without a relaunch.
    func setSnippetsDirectory(_ url: URL) {
        guard url.standardizedFileURL != snippetsDirectory.standardizedFileURL else { return }
        snippetsDirectory = url
        loadSnippets()
        updateResults()
    }

    func reset(scope: PaletteScope = .all) {
        self.scope = scope
        usage = usageStore.ranking()
        // Snippets are re-read on every open, so editing a file shows up
        // without restarting the app.
        loadSnippets()
        query = ""
        selectionIndex = 0
        updateResults()
        refreshApplications()
    }

    private func loadSnippets() {
        let scan = SnippetLibrary.scan(from: snippetsDirectory)
        snippets = scan.snippets
        invalidSnippets = scan.invalid
    }

    /// Rescans the install roots on every open, so an app installed while
    /// Heycast runs appears the next time the palette opens. Opens that arrive
    /// during a scan collapse into one follow-up scan.
    func refreshApplications() {
        guard scanTask == nil else {
            scanAgain = true
            return
        }

        isLoading = applications.isEmpty
        scanTask = Task { [weak self] in
            let apps = await ApplicationCatalog.load()
            guard let self else { return }
            self.scanTask = nil
            NSLog("Heycast: catalog: %d applications", apps.count)

            if apps != self.applications {
                let previousSelection = self.selected
                self.applications = apps
                self.updateResults(keepingSelection: previousSelection)
            }
            self.isLoading = false

            if self.scanAgain {
                self.scanAgain = false
                self.refreshApplications()
            }
        }
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let count = results.count
        selectionIndex = (selectionIndex + delta + count) % count
    }

    func select(_ item: PaletteItem) {
        guard let index = results.firstIndex(of: item) else { return }
        selectionIndex = index
    }

    /// Re-ranks after a query or catalog change. A background rescan keeps the
    /// highlighted row when it still exists, so typing during a scan is not
    /// interrupted by the selection jumping back to the first result.
    private func updateResults(keepingSelection selected: PaletteItem? = nil) {
        results = PaletteSearch.rank(
            applications: scope == .all ? applications : [],
            snippets: snippets,
            invalidSnippets: scope == .snippets ? invalidSnippets : [],
            commands: scope == .all ? PaletteCommand.allCases : [],
            matching: query,
            usage: usage
        )

        if let selected, let index = results.firstIndex(of: selected) {
            selectionIndex = index
        } else {
            selectionIndex = 0
        }
    }
}

@MainActor
private final class ApplicationIconCache {
    static let shared = ApplicationIconCache()

    private var icons: [URL: NSImage] = [:]

    func image(for url: URL) -> NSImage {
        if let image = icons[url] { return image }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        icons[url] = image
        return image
    }
}

struct PaletteView: View {
    @ObservedObject var model: PaletteModel
    let onActivate: (PaletteItem) -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(model.scope.searchPrompt, text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22))
                    .focused($isFocused)
                    .onSubmit(onSubmit)
            }
            .frame(height: PaletteControllerLayout.searchHeight)

            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .padding(.top, PaletteControllerLayout.dividerSpacing)

            resultList
                .padding(.vertical, PaletteControllerLayout.listPadding)

            footer
        }
        .padding(.horizontal, PaletteControllerLayout.horizontalPadding)
        .padding(.vertical, PaletteControllerLayout.verticalPadding)
        .frame(
            width: PaletteControllerLayout.width,
            height: PaletteControllerLayout.height(for: model.results.count),
            alignment: .topLeading
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.12))
        )
        .onAppear { isFocused = true }
    }

    private var resultList: some View {
        Group {
            if model.isLoading && model.scope == .all {
                messageRow("Loading applications…", showsProgress: true)
            } else if model.results.isEmpty {
                messageRow(emptyMessage, showsProgress: false)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(model.results) { item in
                                PaletteRow(
                                    item: item,
                                    isSelected: model.selected == item,
                                    action: {
                                        model.select(item)
                                        onActivate(item)
                                    }
                                )
                                .id(item.id)
                            }
                        }
                    }
                    .scrollIndicators(.visible)
                    .frame(height: resultAreaHeight)
                    .onChange(of: model.query) {
                        guard let selected = model.selected else { return }
                        proxy.scrollTo(selected.id, anchor: .top)
                    }
                    .onChange(of: model.selectionIndex) {
                        guard let selected = model.selected else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(selected.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(height: resultAreaHeight, alignment: .top)
    }

    private var footer: some View {
        HStack {
            Text(resultCountText)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()

            Text(actionHintText)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(height: PaletteControllerLayout.footerHeight)
        .padding(.top, PaletteControllerLayout.footerSpacing)
    }

    private var resultAreaHeight: CGFloat {
        PaletteControllerLayout.resultAreaHeight(for: model.results.count)
    }

    /// Only the actions that work for the selected row are advertised; a
    /// command row has no path to copy and no bundle identifier.
    private var actionHintText: String {
        guard let item = model.selected else {
            return "↑↓ select   esc close"
        }

        switch item {
        case .application(let app):
            var hints = "↩ open   ⌘↩ reveal   ⌥⌘C path"
            if app.bundleIdentifier != nil {
                hints += "   ⌥⌘B ID"
            }
            return hints + "   esc"
        case .snippet:
            return "↩ paste   ⌘↩ reveal   ⌥⌘C path   esc"
        case .invalidSnippet:
            return "⌘↩ reveal   ⌥⌘C path   esc"
        case .command:
            return "↩ run   esc"
        }
    }

    private var emptyMessage: String {
        let trimmed = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return model.scope == .snippets ? "No snippets." : "Nothing to show."
        }
        return "No results match “\(trimmed)”."
    }

    private var resultCountText: String {
        switch model.results.count {
        case 0: "No results"
        case 1: "1 result"
        default: "\(model.results.count) results"
        }
    }

    private func messageRow(_ message: String, showsProgress: Bool) -> some View {
        HStack(spacing: 8) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: PaletteControllerLayout.rowHeight)
    }
}

private struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon
                    .frame(width: 22, height: 22)

                Text(item.title)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                if let snippet = item.snippet {
                    Text(snippet.keyword)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                        .lineLimit(1)
                } else if let issue = item.invalidSnippet {
                    Text(issue.reason)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : .orange)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(issue.reason)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: PaletteControllerLayout.rowHeight)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.9) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var icon: some View {
        switch item {
        case .application(let app):
            Image(nsImage: ApplicationIconCache.shared.image(for: app.url))
                .resizable()
                .interpolation(.high)
        case .snippet(let snippet):
            Image(systemName: snippet.isScript ? "terminal" : "text.quote")
                .font(.system(size: 15))
                .foregroundStyle(isSelected ? .white : .secondary)
        case .invalidSnippet:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : .orange)
        case .command(let command):
            Image(systemName: command.symbol)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : .secondary)
        }
    }
}

/// Single source of truth for the panel geometry shared by the AppKit
/// window and the SwiftUI content.
enum PaletteControllerLayout {
    static let width: CGFloat = 620
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 16
    static let searchHeight: CGFloat = 32
    static let dividerSpacing: CGFloat = 12
    static let rowHeight: CGFloat = 38
    static let listPadding: CGFloat = 8
    static let footerSpacing: CGFloat = 10
    static let footerHeight: CGFloat = 16
    static let maxVisibleRows = 7

    static func resultAreaHeight(for count: Int) -> CGFloat {
        CGFloat(min(max(count, 1), maxVisibleRows)) * rowHeight
    }

    static func height(for count: Int) -> CGFloat {
        verticalPadding * 2
            + searchHeight
            + dividerSpacing
            + 1
            + listPadding * 2
            + resultAreaHeight(for: count)
            + footerSpacing
            + footerHeight
    }
}
