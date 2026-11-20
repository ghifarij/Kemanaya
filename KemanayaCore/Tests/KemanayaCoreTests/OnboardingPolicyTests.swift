import Foundation
import KemanayaCore
import Testing

struct OnboardingPolicyTests {
    /// A private, empty `UserDefaults` suite for one test.
    private static func freshDefaults() -> UserDefaults {
        let name = "OnboardingPolicyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func firstLaunchShowsTheIntroduction() {
        let policy = OnboardingPolicy(defaults: Self.freshDefaults())
        #expect(!policy.hasSeen)
        #expect(policy.showsAtLaunch)
    }

    @Test func finishingItIsRemembered() {
        let defaults = Self.freshDefaults()
        OnboardingPolicy(defaults: defaults).recordSeen()
        let nextLaunch = OnboardingPolicy(defaults: defaults)
        #expect(nextLaunch.hasSeen)
        #expect(!nextLaunch.showsAtLaunch)
        #expect(defaults.bool(forKey: OnboardingPolicy.seenKey))
    }

    @Test func aThrowawayStoreNeverShowsItByItself() {
        let policy = OnboardingPolicy(defaults: nil)
        #expect(!policy.showsAtLaunch)
        #expect(!policy.hasSeen)
    }

    @Test func aRequestShowsItEvenWhenSeenOrThrowaway() {
        let defaults = Self.freshDefaults()
        OnboardingPolicy(defaults: defaults).recordSeen()
        #expect(OnboardingPolicy(defaults: defaults, isRequested: true).showsAtLaunch)
        #expect(OnboardingPolicy(defaults: nil, isRequested: true).showsAtLaunch)
    }

    /// A UI test that finishes the requested introduction must not mark the device's real flag.
    @Test func aThrowawayStoreRemembersNothing() {
        let policy = OnboardingPolicy(defaults: nil, isRequested: true)
        policy.recordSeen()
        #expect(!policy.hasSeen)
        #expect(policy.showsAtLaunch)
    }
}
