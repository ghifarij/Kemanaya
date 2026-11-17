import KemanayaCore
import Testing

struct AppInfoTests {
    @Test func appNameIsKemanaya() {
        #expect(AppInfo.name == "Kemanaya")
    }
}
