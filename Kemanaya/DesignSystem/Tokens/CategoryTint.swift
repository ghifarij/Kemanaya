import KemanayaCore
import SwiftUI

/// The color family a card or bar belongs to (D-022). ``init(kind:group:)`` maps the domain onto it.
///
/// `nonisolated` so domain code can use it off the main actor. The generated asset symbols
/// (`ColorResource.kebutuhanSurface`, …) are main-actor isolated under this target's default
/// isolation, so the resources are built by name here; `TokenContrastTests` checks every one
/// against its generated symbol, so a typo fails the tests.
nonisolated enum CategoryTint: CaseIterable, Sendable {
    case kebutuhan
    case keinginan
    case pemasukan

    /// Kebutuhan / Keinginan for expenses by group, Pemasukan for income (D-003, D-005).
    /// An expense without a group can't exist (``SubcategoryRules``); it falls back to Kebutuhan.
    init(kind: TransactionKind, group: ExpenseGroup?) {
        switch (kind, group) {
        case (.income, _): self = .pemasukan
        case (.expense, .keinginan): self = .keinginan
        case (.expense, .kebutuhan), (.expense, nil): self = .kebutuhan
        }
    }

    /// Solid card background.
    var surface: ColorResource {
        switch self {
        case .kebutuhan: Self.token("kebutuhanSurface")
        case .keinginan: Self.token("keinginanSurface")
        case .pemasukan: Self.token("pemasukanSurface")
        }
    }

    /// Text and amounts on ``surface``. Lime always carries dark text, in every appearance.
    var content: ColorResource {
        switch self {
        case .kebutuhan, .keinginan: Self.token("textPrimary")
        case .pemasukan: Self.token("onPemasukan")
        }
    }

    /// Quieter marks and captions on ``surface``, e.g. last month's bar.
    /// Lime has no grey that holds contrast in dark mode, so it keeps its dark text color.
    var secondaryContent: ColorResource {
        switch self {
        case .kebutuhan, .keinginan: Self.token("textSecondary")
        case .pemasukan: Self.token("onPemasukan")
        }
    }

    /// Bars and other data marks drawn on ``surface`` (≥ 3:1 against it).
    var bar: ColorResource {
        switch self {
        case .kebutuhan: Self.token("kebutuhanStrong")
        case .keinginan: Self.token("keinginanStrong")
        case .pemasukan: Self.token("pemasukanStrong")
        }
    }

    private static func token(_ name: String) -> ColorResource {
        ColorResource(name: name, bundle: .main)
    }
}
