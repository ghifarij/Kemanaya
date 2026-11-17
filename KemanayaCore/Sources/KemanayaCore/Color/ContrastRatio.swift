/// WCAG 2.x contrast ratio between two colors, from 1 (identical) to 21 (black on white).
public enum ContrastRatio {
    /// AA, normal text.
    public static let normalText = 4.5
    /// AA, non-text UI such as bars, fills and focus indicators (WCAG 1.4.11).
    public static let nonText = 3.0
    /// AAA, normal text. The target for the Increase Contrast variants.
    public static let enhancedText = 7.0

    /// The ratio is symmetric: the order of the two colors does not matter.
    public static func between(_ first: SRGBColor, _ second: SRGBColor) -> Double {
        let a = first.relativeLuminance
        let b = second.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
