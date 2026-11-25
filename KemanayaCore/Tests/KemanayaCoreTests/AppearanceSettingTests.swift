import KemanayaCore
import Testing

struct AppearanceSettingTests {
    @Test func defaultIsAutomatic() {
        #expect(AppearanceSetting.default == .automatic)
        #expect(AppearanceSetting(storedValue: nil) == .automatic)
    }

    @Test func rawValuesAreStable() {
        #expect(AppearanceSetting.allCases.map(\.rawValue) == ["automatic", "light", "dark"])
        #expect(AppearanceSetting.storageKey == "appearance")
    }

    @Test func storedValuesRoundTripAndUnknownFallsBack() {
        for setting in AppearanceSetting.allCases {
            #expect(AppearanceSetting(storedValue: setting.rawValue) == setting)
        }
        #expect(AppearanceSetting(storedValue: "sepia") == .automatic)
        #expect(AppearanceSetting(storedValue: "") == .automatic)
    }
}
