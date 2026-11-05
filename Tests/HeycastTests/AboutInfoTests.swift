import Testing

@testable import Heycast

@Suite struct AboutInfoTests {
    @Test func showsReleaseVersionAndBuild() {
        let info = AboutInfo(name: "Heycast", version: "0.1.0", build: "7")
        #expect(info.versionText == "Version 0.1.0 (7)")
    }

    @Test func omitsBuildWhenItRepeatsTheVersion() {
        let info = AboutInfo(name: "Heycast", version: "0.1.0", build: "0.1.0")
        #expect(info.versionText == "Version 0.1.0")
    }

    @Test func omitsMissingBuild() {
        let info = AboutInfo(name: "Heycast", version: "0.1.0", build: nil)
        #expect(info.versionText == "Version 0.1.0")
    }

    @Test func unbundledBuildIsADevelopmentBuild() {
        #expect(AboutInfo(name: "Heycast", version: nil, build: "1").versionText == "Development build")
        #expect(AboutInfo(name: "Heycast", version: "", build: nil).versionText == "Development build")
    }
}
