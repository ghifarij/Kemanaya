import KemanayaCore
import Testing

struct ContrastRatioTests {
    private let black = SRGBColor(hex: 0x000000)
    private let white = SRGBColor(hex: 0xFFFFFF)

    @Test func blackOnWhiteIs21() {
        #expect(abs(ContrastRatio.between(black, white) - 21) < 0.0001)
    }

    @Test func identicalColorsAre1() {
        let violet = SRGBColor(hex: 0x6C3BFF)
        #expect(ContrastRatio.between(violet, violet) == 1)
    }

    @Test func isSymmetric() {
        let coral = SRGBColor(hex: 0xFF5A5F)
        #expect(ContrastRatio.between(coral, white) == ContrastRatio.between(white, coral))
    }

    @Test func luminanceEndpoints() {
        #expect(black.relativeLuminance == 0)
        #expect(abs(white.relativeLuminance - 1) < 0.0001)
    }

    /// Reference values: #767676 is the darkest gray that passes AA on white (4.54:1),
    /// #777777 is the lightest that fails (4.48:1).
    @Test func knownReferenceGrays() {
        let passing = ContrastRatio.between(SRGBColor(hex: 0x767676), white)
        let failing = ContrastRatio.between(SRGBColor(hex: 0x777777), white)
        #expect(abs(passing - 4.54) < 0.01)
        #expect(abs(failing - 4.48) < 0.01)
        #expect(passing >= ContrastRatio.normalText)
        #expect(failing < ContrastRatio.normalText)
    }

    @Test func hexInitializerReadsChannels() {
        #expect(SRGBColor(hex: 0xFF0000) == SRGBColor(red: 1, green: 0, blue: 0))
        #expect(SRGBColor(hex: 0x00FF00) == SRGBColor(red: 0, green: 1, blue: 0))
        #expect(SRGBColor(hex: 0x0000FF) == SRGBColor(red: 0, green: 0, blue: 1))
    }
}
