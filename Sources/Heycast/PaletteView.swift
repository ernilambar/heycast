import SwiftUI

@MainActor
final class PaletteModel: ObservableObject {
    @Published var query = ""

    func reset() {
        query = ""
    }
}

struct PaletteView: View {
    @ObservedObject var model: PaletteModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("Ask heycast…", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22))
                    .focused($isFocused)
            }

            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)

            Text(model.query.isEmpty ? "Hello, world." : "Hello, \(model.query).")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text("esc to close")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(
            width: PaletteControllerLayout.width,
            height: PaletteControllerLayout.height,
            alignment: .topLeading
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.12))
        )
        .onAppear { isFocused = true }
    }
}

/// Single source of truth for the panel geometry shared by the AppKit
/// window and the SwiftUI content.
enum PaletteControllerLayout {
    static let width: CGFloat = 620
    static let height: CGFloat = 132
}
