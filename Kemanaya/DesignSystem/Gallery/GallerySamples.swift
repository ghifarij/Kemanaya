import KemanayaCore
import SwiftUI

/// Realistic sample data for the design gallery: the default pins (D-012, D-068) with seed emoji (D-008),
/// some with a budget so both of the compact card's third lines show.
struct GallerySample: Identifiable {
    let emoji: String
    let name: String
    let tint: CategoryTint
    let thisMonth: Int64
    let lastMonth: Int64
    var monthlyBudget: Int64?

    var id: String { name }

    var budget: BudgetProgress? {
        monthlyBudget.flatMap { BudgetProgress(spent: thisMonth, budget: $0) }
    }

    /// Kebutuhan column, in pin order.
    static let kebutuhanCards: [GallerySample] = [
        GallerySample(emoji: "🍚", name: "Makan", tint: .kebutuhan, thisMonth: 1_250_000, lastMonth: 1_410_000),
        GallerySample(emoji: "🅿️", name: "Parkir", tint: .kebutuhan, thisMonth: 54_000, lastMonth: 61_000, monthlyBudget: 100_000),
        GallerySample(emoji: "💧", name: "Galon", tint: .kebutuhan, thisMonth: 40_000, lastMonth: 20_000),
    ]

    /// Keinginan column, in pin order: Kopi under its budget, Jajan over.
    static let keinginanCards: [GallerySample] = [
        GallerySample(emoji: "☕", name: "Kopi", tint: .keinginan, thisMonth: 245_000, lastMonth: 280_000, monthlyBudget: 300_000),
        GallerySample(emoji: "🍿", name: "Jajan", tint: .keinginan, thisMonth: 186_500, lastMonth: 186_500, monthlyBudget: 150_000),
    ]

    /// Pinned income rows.
    static let incomeRows: [GallerySample] = [
        GallerySample(emoji: "💼", name: "Gaji", tint: .pemasukan, thisMonth: 8_500_000, lastMonth: 8_500_000),
        GallerySample(emoji: "🎁", name: "Bonus", tint: .pemasukan, thisMonth: 0, lastMonth: 1_000_000),
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
