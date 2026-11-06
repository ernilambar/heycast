import AppKit
import SwiftUI

/// What the About window shows. Reading the bundle is separated from the
/// formatting so the version string is testable without a built app.
struct AboutInfo: Equatable {
    let name: String
    let version: String?
    let build: String?

    static func current(_ bundle: Bundle = .main) -> AboutInfo {
        AboutInfo(
            name: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Heycast",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    /// The release version and, when it adds information, the build number.
    /// A bare executable has no plist, so it reads as a development build.
    var versionText: String {
        guard let version, !version.isEmpty else { return "Development build" }
        guard let build, !build.isEmpty, build != version else {
            return "Version \(version)"
        }
        return "Version \(version) (\(build))"
    }
}

/// Compact About panel: icon, version and the project links. Heycast has no
/// Dock icon or app menu, so this is the only place the version is shown.
struct AboutView: View {
    let info: AboutInfo
    let icon: NSImage

    private static let website = URL(string: "https://www.nilambar.net")!
    private static let source = URL(string: "https://github.com/ernilambar/heycast")!
    private static let license = URL(string: "https://github.com/ernilambar/heycast/blob/main/LICENSE")!

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityLabel("Heycast app icon")

                Text(info.name)
                    .font(.system(size: 24, weight: .semibold))

                Text(info.versionText)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                // The one-sentence positioning; see docs/positioning.md.
                Text("A menu-bar launcher for everyday Mac work.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)

                Text("No telemetry. No analytics, no crash reporting.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            // fullSizeContentView puts the traffic lights over the top-leading
            // corner, so the icon starts below them.
            .padding(.top, 44)

            Spacer(minLength: 20)

            Divider()
                .padding(.horizontal, 40)

            HStack(spacing: 14) {
                Link("Website", destination: Self.website)
                Link("GitHub", destination: Self.source)
                Link("MIT License", destination: Self.license)
            }
            .font(.system(size: 12))
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 40)

            Text("© 2026 Nilambar Sharma")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.vertical, 10)
        }
        .frame(width: 340, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
