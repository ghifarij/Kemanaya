import SwiftUI

/// Brand type scale (D-022). Every font is tied to a text style, so it follows Dynamic Type.
/// Amounts and titles: SF Pro Rounded Heavy; amounts also use monospaced digits.
/// Body copy uses the system fonts (`.body`, `.subheadline`, …) directly.
extension Font {
    /// The amount being typed on the keypad.
    static let amountHero = Font.system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit()
    /// Month totals on Home.
    static let amountLarge = Font.system(.title, design: .rounded, weight: .heavy).monospacedDigit()
    /// Card totals.
    static let amountMedium = Font.system(.title3, design: .rounded, weight: .heavy).monospacedDigit()
    /// Amounts in rows and lists.
    static let amountSmall = Font.system(.body, design: .rounded, weight: .heavy).monospacedDigit()
    /// Screen and section titles.
    static let brandTitle = Font.system(.title2, design: .rounded, weight: .heavy)
}
