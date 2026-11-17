import SwiftUI

/// Realistic sample data for the design gallery: the default pins (D-012) with seed emoji (D-008).
struct GallerySample: Identifiable {
    let emoji: String
    let name: String
    let tint: CategoryTint
    let thisMonth: Int64
    let lastMonth: Int64

    var id: String { name }

    static let pinnedCards: [GallerySample] = [
        GallerySample(emoji: "🍚", name: "Makan", tint: .kebutuhan, thisMonth: 1_250_000, lastMonth: 1_410_000),
        GallerySample(emoji: "☕", name: "Kopi", tint: .keinginan, thisMonth: 312_000, lastMonth: 245_000),
        GallerySample(emoji: "🍿", name: "Jajan", tint: .keinginan, thisMonth: 186_500, lastMonth: 186_500),
        GallerySample(emoji: "🅿️", name: "Parkir", tint: .kebutuhan, thisMonth: 54_000, lastMonth: 61_000),
        GallerySample(emoji: "💧", name: "Galon", tint: .kebutuhan, thisMonth: 40_000, lastMonth: 20_000),
        GallerySample(emoji: "🎬", name: "Hiburan", tint: .keinginan, thisMonth: 0, lastMonth: 150_000),
        GallerySample(emoji: "💼", name: "Gaji", tint: .pemasukan, thisMonth: 8_500_000, lastMonth: 8_500_000),
    ]

    static let colorTokens: [(name: String, color: ColorResource)] = [
        ("brand", .brand),
        ("appBackground", .appBackground),
        ("surface", .surface),
        ("textPrimary", .textPrimary),
        ("textSecondary", .textSecondary),
        ("kebutuhan", .kebutuhan),
        ("kebutuhanSurface", .kebutuhanSurface),
        ("kebutuhanStrong", .kebutuhanStrong),
        ("keinginan", .keinginan),
        ("keinginanSurface", .keinginanSurface),
        ("keinginanStrong", .keinginanStrong),
        ("pemasukan", .pemasukan),
        ("pemasukanSurface", .pemasukanSurface),
        ("pemasukanStrong", .pemasukanStrong),
        ("onPemasukan", .onPemasukan),
    ]
}
