import Foundation
import Testing
@testable import Kemanaya

struct KemanayaTests {
    /// The tests are hosted by the app, so `Bundle.main` is the app bundle (D-001).
    @Test func testsRunInsideTheAppBundle() {
        #expect(Bundle.main.bundleIdentifier == "com.afgaghifari.kemanaya")
    }
}
