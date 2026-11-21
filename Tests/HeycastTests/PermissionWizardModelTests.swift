import Foundation
import Testing

@testable import Heycast

@Suite struct PermissionWizardModelTests {
    @Test func moveStepOnlyOutsideApplications() {
        #expect(
            !PermissionWizardModel.needsMoveToApplications(
                for: URL(fileURLWithPath: "/Applications/Heycast.app")
            )
        )
        #expect(
            PermissionWizardModel.needsMoveToApplications(
                for: URL(fileURLWithPath: "/Users/someone/Downloads/Heycast.app")
            )
        )
        #expect(
            PermissionWizardModel.needsMoveToApplications(
                for: URL(fileURLWithPath: "/Users/someone/Code/heycast/dist/Heycast.app")
            )
        )
    }
}
