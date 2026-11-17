import SwiftUI

extension View {
    /// The only way custom content gets glass (D-025): Liquid Glass on iOS 26+,
    /// `.ultraThinMaterial` on iOS 18–25. Feature code never checks availability itself.
    func kemanayaGlass(in shape: some Shape) -> some View {
        modifier(KemanayaGlassModifier(shape: shape))
    }
}

private struct KemanayaGlassModifier<GlassShape: Shape>: ViewModifier {
    let shape: GlassShape

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

#Preview {
    ZStack {
        HStack(spacing: 0) {
            Color(.kebutuhan)
            Color(.keinginan)
            Color(.pemasukan)
        }
        Text(verbatim: "Kemanaya")
            .font(.brandTitle)
            .padding()
            .kemanayaGlass(in: .capsule)
    }
    .ignoresSafeArea()
}
