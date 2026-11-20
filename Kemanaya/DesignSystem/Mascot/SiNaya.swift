import SwiftUI

/// Si Naya, the mascot: a curious lime coin with eyes (D-022, D-063).
///
/// Drawn only from SwiftUI shapes laid out in a unit square, so it scales to any frame (always 1:1)
/// and the app icon is rendered from the same geometry. It appears only on onboarding, empty states
/// and the app icon, and never reacts to spending: no mood is celebratory.
///
/// Colors (D-040): the coin is the vivid `pemasukan` lime, which is decoration, with a
/// `pemasukanStrong` rim and edge; the face is `onPemasukan`, the ink that always sits on lime.
/// Highlights are the lime mixed toward white. Every token has its high-contrast variant.
struct SiNaya: View {
    enum Mood: CaseIterable, Hashable {
        /// Head tilted, eyes glancing up to the side, one brow raised, a small "o". For onboarding.
        case curious
        /// Relaxed eyes and a soft smile. For empty states.
        case calm
        /// Eyes closed in a drowsy curve, two small z's, leaning the other way. For nothing-to-show or error states.
        case sleepy
    }

    let mood: Mood
    private let label: Text?
    private let blinks: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBlinking = false

    /// A decorative Si Naya, hidden from VoiceOver.
    /// - Parameter blinks: an occasional blink; never with Reduce Motion or when sleepy.
    init(mood: Mood = .curious, blinks: Bool = true) {
        self.mood = mood
        self.label = nil
        self.blinks = blinks
    }

    /// A Si Naya that VoiceOver reads as an image, for places where it carries meaning.
    init(mood: Mood = .curious, label: Text, blinks: Bool = true) {
        self.mood = mood
        self.label = label
        self.blinks = blinks
    }

    /// A ready-made VoiceOver label for ``init(mood:label:blinks:)``.
    static var defaultLabel: Text {
        Text("Si Naya, maskot Kemanaya", comment: "VoiceOver label of the mascot, a coin with eyes named Si Naya.")
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            coin(side: side)
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? Text(verbatim: ""))
        .accessibilityAddTraits(.isImage)
        .accessibilityHidden(label == nil)
        .task(id: blinkEnabled) { await blinkLoop() }
    }

    // MARK: - Drawing

    private var coinFill: Color { Color(.pemasukan) }
    private var edge: Color { Color(.pemasukanStrong) }
    private var ink: Color { Color(.onPemasukan) }
    private var highlight: Color { Color(.pemasukan).mix(with: .white, by: 0.7) }

    /// The whole coin in a `side` × `side` square. All lengths are fractions of `side`.
    private func coin(side s: CGFloat) -> some View {
        ZStack {
            // Body and the slightly darker edge band, a coin's raised border.
            Circle().fill(coinFill)
                .frame(width: 0.92 * s, height: 0.92 * s)
            Circle().strokeBorder(edge.opacity(0.22), lineWidth: 0.09 * s)
                .frame(width: 0.92 * s, height: 0.92 * s)
            // Embossed inner ring where the band meets the face.
            Circle().stroke(edge.opacity(0.55), lineWidth: 0.016 * s)
                .frame(width: 0.74 * s, height: 0.74 * s)
            // Outer rim.
            Circle().strokeBorder(edge, lineWidth: 0.036 * s)
                .frame(width: 0.92 * s, height: 0.92 * s)
            shine(side: s)
            face(side: s)
        }
        .frame(width: s, height: s)
        .rotationEffect(.degrees(Geometry.tilt(mood)))
    }

    /// A cartoon shine on the upper-left of the edge band: a short arc and a dot.
    private func shine(side s: CGFloat) -> some View {
        ZStack {
            ArcShape(radius: 0.415, start: 196, end: 238)
                .stroke(highlight, style: StrokeStyle(lineWidth: 0.034 * s, lineCap: .round))
            Circle().fill(highlight)
                .frame(width: 0.034 * s, height: 0.034 * s)
                .position(Geometry.point(onRadius: 0.415, degrees: 254, side: s))
        }
        .frame(width: s, height: s)
    }

    @ViewBuilder
    private func face(side s: CGFloat) -> some View {
        let eyes = Geometry.eyes(mood)
        ZStack {
            ForEach(eyes.centers.indices, id: \.self) { index in
                eye(size: eyes.size, side: s)
                    .position(x: eyes.centers[index].x * s, y: eyes.centers[index].y * s)
            }
            brows(side: s)
            mouth(side: s)
        }
        .frame(width: s, height: s)
    }

    @ViewBuilder
    private func eye(size: CGSize, side s: CGFloat) -> some View {
        let width = size.width * s
        let height = size.height * s
        if mood == .sleepy {
            // Eyes closed in a drowsy curve.
            CurveShape(from: CGPoint(x: 0, y: 0.2), control: CGPoint(x: 0.5, y: 1.1), to: CGPoint(x: 1, y: 0.2))
                .stroke(ink, style: StrokeStyle(lineWidth: 0.03 * s, lineCap: .round))
                .frame(width: width, height: height)
        } else {
            ZStack {
                Ellipse().fill(ink)
                Circle().fill(highlight)
                    .frame(width: 0.36 * width, height: 0.36 * width)
                    .offset(x: 0.18 * width, y: -0.22 * height)
            }
            .frame(width: width, height: height)
            .scaleEffect(x: 1, y: isBlinking ? 0.08 : 1)
        }
    }

    @ViewBuilder
    private func brows(side s: CGFloat) -> some View {
        switch mood {
        case .curious:
            let style = StrokeStyle(lineWidth: 0.03 * s, lineCap: .round)
            // Left brow nearly level, right brow raised and arched: "hm?".
            CurveShape(from: CGPoint(x: 0.345, y: 0.345), control: CGPoint(x: 0.395, y: 0.33), to: CGPoint(x: 0.45, y: 0.342))
                .stroke(ink, style: style)
            CurveShape(from: CGPoint(x: 0.585, y: 0.31), control: CGPoint(x: 0.64, y: 0.255), to: CGPoint(x: 0.7, y: 0.3))
                .stroke(ink, style: style)
        case .calm:
            EmptyView()
        case .sleepy:
            // Two small z's drifting up to the right, drawn as paths.
            let style = StrokeStyle(lineWidth: 0.022 * s, lineCap: .round, lineJoin: .round)
            ZShape().stroke(ink, style: style)
                .frame(width: 0.07 * s, height: 0.07 * s)
                .position(x: 0.625 * s, y: 0.33 * s)
            ZShape().stroke(ink, style: style)
                .frame(width: 0.042 * s, height: 0.042 * s)
                .position(x: 0.695 * s, y: 0.265 * s)
        }
    }

    @ViewBuilder
    private func mouth(side s: CGFloat) -> some View {
        switch mood {
        case .curious:
            Ellipse()
                .fill(ink)
                .frame(width: 0.06 * s, height: 0.075 * s)
                .position(x: 0.535 * s, y: 0.655 * s)
        case .calm:
            CurveShape(from: CGPoint(x: 0.43, y: 0.615), control: CGPoint(x: 0.5, y: 0.68), to: CGPoint(x: 0.57, y: 0.615))
                .stroke(ink, style: StrokeStyle(lineWidth: 0.03 * s, lineCap: .round))
        case .sleepy:
            Ellipse()
                .fill(ink)
                .frame(width: 0.045 * s, height: 0.05 * s)
                .position(x: 0.5 * s, y: 0.65 * s)
        }
    }

    // MARK: - Blink

    private var blinkEnabled: Bool {
        blinks && !reduceMotion && mood != .sleepy
    }

    /// A quick blink every few seconds while visible. The first one waits, so a fresh screen is still.
    private func blinkLoop() async {
        isBlinking = false
        guard blinkEnabled else { return }
        while true {
            do {
                try await Task.sleep(for: .seconds(Double.random(in: 4.5...7)))
                withAnimation(.easeIn(duration: 0.07)) { isBlinking = true }
                try await Task.sleep(for: .milliseconds(130))
                withAnimation(.easeOut(duration: 0.1)) { isBlinking = false }
            } catch {
                isBlinking = false
                return
            }
        }
    }
}

// MARK: - Geometry

/// Si Naya's layout in a unit square, shared by the view and the app icon.
private enum Geometry {
    /// Whole-coin tilt in degrees. Curious leans toward where it looks; sleepy leans the other way.
    static func tilt(_ mood: SiNaya.Mood) -> Double {
        switch mood {
        case .curious: -8
        case .calm: 0
        case .sleepy: 7
        }
    }

    /// Eye centers and size. Curious eyes glance up and to the right.
    static func eyes(_ mood: SiNaya.Mood) -> (centers: [CGPoint], size: CGSize) {
        switch mood {
        case .curious:
            ([CGPoint(x: 0.405, y: 0.46), CGPoint(x: 0.64, y: 0.455)], CGSize(width: 0.11, height: 0.16))
        case .calm:
            ([CGPoint(x: 0.385, y: 0.47), CGPoint(x: 0.615, y: 0.47)], CGSize(width: 0.1, height: 0.135))
        case .sleepy:
            ([CGPoint(x: 0.385, y: 0.48), CGPoint(x: 0.615, y: 0.48)], CGSize(width: 0.11, height: 0.06))
        }
    }

    /// A point on a circle around the center, in points. Degrees run clockwise from the right (y down).
    static func point(onRadius radius: CGFloat, degrees: Double, side: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: (0.5 + radius * cos(radians)) * side, y: (0.5 + radius * sin(radians)) * side)
    }
}

/// An arc around the center of its square, with the radius as a fraction of the side.
nonisolated private struct ArcShape: Shape {
    let radius: CGFloat
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius * min(rect.width, rect.height),
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: false
        )
        return path
    }
}

/// A quadratic curve with unit-square control points.
nonisolated private struct CurveShape: Shape {
    let from: CGPoint
    let control: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        func scaled(_ point: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
        }
        var path = Path()
        path.move(to: scaled(from))
        path.addQuadCurve(to: scaled(to), control: scaled(control))
        return path
    }
}

/// A "z" filling its rect, for the sleepy mood.
nonisolated private struct ZShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

#Preview("Curious") {
    SiNaya(mood: .curious)
        .frame(width: 240, height: 240)
        .padding()
        .background(Color(.appBackground))
}

#Preview("Calm") {
    SiNaya(mood: .calm)
        .frame(width: 240, height: 240)
        .padding()
        .background(Color(.appBackground))
}

#Preview("Sleepy") {
    SiNaya(mood: .sleepy)
        .frame(width: 240, height: 240)
        .padding()
        .background(Color(.appBackground))
}

#Preview("Sizes and backgrounds") {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            ForEach(SiNaya.Mood.allCases, id: \.self) { mood in
                SiNaya(mood: mood).frame(width: 96, height: 96)
            }
        }
        HStack(spacing: 16) {
            ForEach(SiNaya.Mood.allCases, id: \.self) { mood in
                SiNaya(mood: mood).frame(width: 48, height: 48)
            }
        }
        SiNaya(mood: .curious)
            .frame(width: 120, height: 120)
            .padding(24)
            .background(Color(.brand), in: .rect(cornerRadius: 28, style: .continuous))
    }
    .padding()
    .background(Color(.appBackground))
}
