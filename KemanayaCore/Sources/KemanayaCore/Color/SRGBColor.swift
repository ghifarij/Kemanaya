import Foundation

/// An opaque sRGB color with components in `0...1`, used for contrast math.
public struct SRGBColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Creates a color from `0xRRGGBB`.
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// WCAG 2.x relative luminance, from 0 (black) to 1 (white).
    public var relativeLuminance: Double {
        0.2126 * Self.linearized(red) + 0.7152 * Self.linearized(green) + 0.0722 * Self.linearized(blue)
    }

    /// Converts a gamma-encoded sRGB component to linear light.
    /// Uses the sRGB threshold 0.04045 (WCAG 2.x prints 0.03928; both agree for 8-bit values).
    private static func linearized(_ component: Double) -> Double {
        let value = min(max(component, 0), 1)
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}
