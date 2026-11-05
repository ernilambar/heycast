import AppKit
import SwiftUI

@MainActor
final class PaletteModel: ObservableObject {
    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            updateResults()
        }
    }
    @Published private(set) var results: [LaunchableApp] = []
    @Published private(set) var selectionIndex = 0
    @Published private(set) var isLoading = false

    private var applications: [LaunchableApp] = []
    private var hasLoadedApplications = false

    var selected: LaunchableApp? {
        results.indices.contains(selectionIndex) ? results[selectionIndex] : nil
    }

    func reset() {
        query = ""
        selectionIndex = 0
        updateResults()
        loadApplicationsIfNeeded()
    }

    func loadApplicationsIfNeeded() {
        guard !hasLoadedApplications else { return }
        hasLoadedApplications = true
        isLoading = true

        Task {
            let apps = await ApplicationCatalog.load()
            applications = apps
            isLoading = false
            updateResults()
        }
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let count = results.count
        selectionIndex = (selectionIndex + delta + count) % count
    }

    func select(_ app: LaunchableApp) {
        guard let index = results.firstIndex(of: app) else { return }
        selectionIndex = index
    }

    private func updateResults() {
        results = ApplicationSearch.rank(applications, matching: query)
        selectionIndex = 0
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
    let onOpen: (LaunchableApp) -> Void
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Search applications…", text: $model.query)
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
            if model.isLoading {
                messageRow("Loading applications…", showsProgress: true)
            } else if model.results.isEmpty {
                messageRow(emptyMessage, showsProgress: false)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(model.results) { app in
                                ApplicationRow(
                                    app: app,
                                    isSelected: model.selected == app,
                                    action: {
                                        model.select(app)
                                        onOpen(app)
                                    }
                                )
                                .id(app.id)
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

            Text("↑↓ select   ↩ open   esc close")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(height: PaletteControllerLayout.footerHeight)
        .padding(.top, PaletteControllerLayout.footerSpacing)
    }

    private var resultAreaHeight: CGFloat {
        PaletteControllerLayout.resultAreaHeight(for: model.results.count)
    }

    private var emptyMessage: String {
        let trimmed = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No applications found." : "No applications match “\(trimmed)”."
    }

    private var resultCountText: String {
        switch model.results.count {
        case 0: "No results"
        case 1: "1 application"
        default: "\(model.results.count) applications"
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

private struct ApplicationRow: View {
    let app: LaunchableApp
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(nsImage: ApplicationIconCache.shared.image(for: app.url))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 22, height: 22)

                Text(app.name)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
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
