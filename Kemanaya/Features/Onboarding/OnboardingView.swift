import KemanayaCore
import SwiftUI

/// The first-launch introduction (D-063): three skippable pages in a full-screen cover.
/// 1. What Kemanaya answers: "Kemana ya uangku?".
/// 2. The pinned cards (D-068), on two sample cards: needs on the left and wants on the right, tap to
///    log, long-press for the menu, what a card's bottom line means, and the month summary above them.
/// 3. Kebutuhan vs Keinginan and the optional budgets set from Atur or a card's menu (D-069), with
///    **Mulai** and a secondary **Pulihkan dari cadangan** (D-060).
///
/// Si Naya appears on every page, curious or calm, never reacting to money (D-022). **Lewati** on the
/// first two pages finishes at once. Pages swipe, and **Lanjut** moves on; with Reduce Motion the page
/// changes without the slide. VoiceOver moves to the new page's title.
///
/// **Fit (D-071):** up to XXXL every page fits whole, without scrolling, on the smallest target phone
/// (iPhone 13, 390×844 pt). A page shows the roomiest of its layouts that fits (``PageDensity``): a
/// smaller Si Naya and tighter spacing first, then without the sample cards, then the smallest Si Naya
/// and spacing. Text is never shrunk. At the accessibility sizes the page scrolls instead, and so does
/// a page that still doesn't fit as `minimal` (Display Zoom, unusual sizes; D-072).
struct OnboardingView: View {
    /// Mulai or Lewati.
    let onFinish: () -> Void
    /// Pulihkan dari cadangan.
    let onRestore: () -> Void

    private static let pageCount = 3

    @State private var page: Int
    @AccessibilityFocusState private var focusedTitle: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameter initialPage: the page to open on, from 0; previews use it.
    init(initialPage: Int = 0, onFinish: @escaping () -> Void, onRestore: @escaping () -> Void) {
        _page = State(initialValue: initialPage)
        self.onFinish = onFinish
        self.onRestore = onRestore
    }

    private var isLastPage: Bool { page == Self.pageCount - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $page) {
                OnboardingPage(index: 0, mood: .curious, mascotSize: 140, focusedTitle: $focusedTitle) {
                    Text("Kemana ya uangku?", comment: "Onboarding page 1 title: the question the app answers, 'Where did my money go?'.")
                } content: { density in
                    WelcomeContent(density: density)
                }
                .tag(0)
                OnboardingPage(index: 1, mood: .calm, mascotSize: 56, focusedTitle: $focusedTitle) {
                    Text("Kartu untuk catat cepat", comment: "Onboarding page 2 title: the pinned cards on Home are for quick logging.")
                } content: { density in
                    CardsContent(density: density)
                }
                .tag(1)
                OnboardingPage(index: 2, mood: .curious, mascotSize: 72, focusedTitle: $focusedTitle) {
                    Text("Kebutuhan dan Keinginan", comment: "Onboarding page 3 title: the two expense groups, needs and wants.")
                } content: { density in
                    GroupsContent(density: density)
                    RestoreButton(action: onRestore)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            bottomBar
        }
        .foregroundStyle(Color(.textPrimary))
        .background(Color(.appBackground).ignoresSafeArea())
        .onChange(of: page) {
            focusedTitle = page
        }
    }

    // MARK: - Bars

    /// Lewati, on every page but the last, which has Mulai. The bar keeps its height so the pages don't jump.
    private var topBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: onFinish) {
                Text("Lewati", comment: "Onboarding: skips the introduction and opens the app.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.brand))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .opacity(isLastPage ? 0 : 1)
            .disabled(isLastPage)
            .accessibilityHidden(isLastPage)
            .accessibilityIdentifier("onboarding.skip")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    /// The page dots and Lanjut or Mulai. Its height is the same on every page: a bar that grew on the
    /// last page shrank the pager under a page already laid out. Pulihkan dari cadangan is page 3's last
    /// line instead, so the bar stays two rows high and the pages get the height (D-071).
    private var bottomBar: some View {
        VStack(spacing: 12) {
            PageDots(current: page, count: Self.pageCount)
            if isLastPage {
                Button(action: onFinish) {
                    PrimaryButtonLabel(text: Text("Mulai", comment: "Onboarding's last page: closes the introduction and starts using the app."))
                }
                .buttonStyle(.springy)
                .accessibilityIdentifier("onboarding.start")
            } else {
                Button {
                    withAnimation(reduceMotion ? nil : .default) { page += 1 }
                } label: {
                    PrimaryButtonLabel(text: Text("Lanjut", comment: "Onboarding: goes to the next page of the introduction."))
                }
                .buttonStyle(.springy)
                .accessibilityIdentifier("onboarding.next")
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Page

/// How much room a page's layout takes (D-071). Up to XXXL a page shows the first of `regular`,
/// `tight`, `compact` and `minimal` that fits its height, and `minimal` in a scroll view when none
/// does (D-072); at the accessibility sizes it is `scrolling`.
private enum PageDensity {
    /// The page's own Si Naya size and roomy spacing.
    case regular
    /// A smaller Si Naya and tighter spacing.
    case tight
    /// As `tight`, without the sample cards.
    case compact
    /// The smallest Si Naya, the tightest spacing, and no sample cards.
    case minimal
    /// The accessibility sizes: the page scrolls, so the spacing stays roomy and everything is shown.
    case scrolling

    /// Between Si Naya, the title and the content, and between the content's blocks.
    var spacing: CGFloat {
        switch self {
        case .regular, .scrolling: 20
        case .tight, .compact: 14
        case .minimal: 10
        }
    }

    /// Between the lines of a list of points.
    var rowSpacing: CGFloat {
        switch self {
        case .regular, .scrolling: 14
        case .tight, .compact: 10
        case .minimal: 8
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .regular, .scrolling: 16
        case .tight, .compact: 12
        case .minimal: 8
        }
    }

    /// The group tiles' inner padding.
    var tilePadding: CGFloat {
        switch self {
        case .regular, .scrolling: 16
        case .tight, .compact, .minimal: 12
        }
    }

    /// Page 2's sample cards: an illustration, so it goes first when room is short.
    var showsIllustration: Bool {
        switch self {
        case .regular, .tight, .scrolling: true
        case .compact, .minimal: false
        }
    }

    /// Si Naya's side, from the page's own size. `EmptyStateMascot` makes it smaller at the
    /// accessibility sizes.
    func mascotSide(_ regular: CGFloat) -> CGFloat {
        switch self {
        case .regular, .scrolling: regular
        case .tight, .compact: min(regular, 72)
        case .minimal: min(regular, 44)
        }
    }
}

/// One page: Si Naya, the title and the page's content.
///
/// Up to XXXL the page shows the roomiest ``PageDensity`` that fits, without scrolling. When even
/// `minimal` doesn't fit (Display Zoom, unusual sizes), the `minimal` layout scrolls rather than cut
/// text (D-072); its last lines then sit below the page dots, so D-071's UI test still catches a fit
/// regression on the target phones. At the accessibility sizes the page always scrolls. While more of
/// a scrolling page lies below, its bottom edge fades out, so a line cut by the pager reads as "scroll
/// for more"; the fade goes away at the end of the page.
private struct OnboardingPage<Content: View>: View {
    let index: Int
    let mood: SiNaya.Mood
    let mascotSize: CGFloat
    let focusedTitle: AccessibilityFocusState<Int?>.Binding
    let title: Text
    let content: (PageDensity) -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasMoreBelow = false

    private let fadeHeight: CGFloat = 32

    init(
        index: Int,
        mood: SiNaya.Mood,
        mascotSize: CGFloat,
        focusedTitle: AccessibilityFocusState<Int?>.Binding,
        @ViewBuilder title: () -> Text,
        @ViewBuilder content: @escaping (PageDensity) -> Content
    ) {
        self.index = index
        self.mood = mood
        self.mascotSize = mascotSize
        self.focusedTitle = focusedTitle
        self.title = title()
        self.content = content
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            scrollingPage(.scrolling)
        } else {
            // ViewThatFits shows its last candidate when none fits, so the scroll view only appears
            // after all four fixed layouts have been tried.
            ViewThatFits(in: .vertical) {
                stack(.regular)
                stack(.tight)
                stack(.compact)
                stack(.minimal)
                scrollingPage(.minimal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func stack(_ density: PageDensity) -> some View {
        VStack(alignment: .leading, spacing: density.spacing) {
            EmptyStateMascot(mood: mood, size: density.mascotSide(mascotSize))
                .frame(maxWidth: .infinity)
            title
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused(focusedTitle, equals: index)
                .accessibilityIdentifier("onboarding.title.\(index + 1)")
            content(density)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, density.verticalPadding)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.page.\(index + 1)")
    }

    private func scrollingPage(_ density: PageDensity) -> some View {
        ScrollView {
            stack(density)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let visibleBottom = geometry.contentOffset.y + geometry.containerSize.height - geometry.contentInsets.bottom
            return visibleBottom < geometry.contentSize.height - 1
        } action: { _, moreBelow in
            hasMoreBelow = moreBelow
        }
        .mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(
                    colors: [.black, .black.opacity(hasMoreBelow ? 0 : 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: fadeHeight)
            }
            .animation(.easeOut(duration: 0.2), value: hasMoreBelow)
        }
    }
}

// MARK: - Page contents

/// Page 1: what the app is for, and where the data lives (D-015).
private struct WelcomeContent: View {
    let density: PageDensity

    var body: some View {
        VStack(alignment: .leading, spacing: density.spacing) {
            BodyText(Text(
                "Kemanaya membantumu menjawabnya. Catat pengeluaran dan pemasukan dalam beberapa ketukan, lalu lihat ke mana uangmu pergi tiap bulan.",
                comment: "Onboarding page 1: what the app does. Log expenses and income in a few taps, then see where the money went each month."
            ))
            PointRow(systemImage: "lock.iphone") {
                Text(
                    "Semua datamu tersimpan di iPhone ini saja, tanpa akun.",
                    comment: "Onboarding page 1: all data stays on this iPhone only, no account needed (D-015)."
                )
            }
        }
    }
}

/// Page 2: the D-068 compact cards, on two sample cards that can't be tapped, then one line per thing
/// to know: the columns, tap, long-press, the bottom line, and the month summary.
private struct CardsContent: View {
    let density: PageDensity

    var body: some View {
        VStack(alignment: .leading, spacing: density.spacing) {
            if density.showsIllustration {
                SampleCards()
            }
            VStack(alignment: .leading, spacing: density.rowSpacing) {
                PointRow(systemImage: "rectangle.split.2x1") {
                    Text(
                        "Kebutuhan di kiri, Keinginan di kanan. Pilih kartunya lewat Atur.",
                        comment: "Onboarding page 2: Home shows Kebutuhan (needs) cards in the left column and Keinginan (wants) in the right; Atur (the button above them) picks which cards (D-068)."
                    )
                }
                PointRow(systemImage: "hand.tap") {
                    Text(
                        "Ketuk kartu, isi jumlahnya, lalu Simpan.",
                        comment: "Onboarding page 2: tapping a card opens the add sheet for it; type the amount, then Simpan (Save) (D-067)."
                    )
                }
                PointRow(systemImage: "ellipsis.circle") {
                    Text(
                        "Tekan lama untuk detail, anggaran, ubah, atau lepas pin.",
                        comment: "Onboarding page 2: long-pressing a card opens its menu: Lihat detail, Atur anggaran, Ubah, Lepas pin (D-069). Keep it short."
                    )
                }
                PointRow(systemImage: "text.below.photo") {
                    Text(
                        "Baris bawah: sisa anggaran, atau bulan lalu kalau tanpa anggaran.",
                        comment: "Onboarding page 2: a card's bottom line shows the budget left ('sisa'), or last month's total when the card has no budget (D-068)."
                    )
                }
                PointRow(systemImage: "calendar") {
                    Text(
                        "Ketuk ringkasan bulan di atas untuk melihat catatan bulan ini.",
                        comment: "Onboarding page 2: tapping the month summary at the top of Home opens this month's transactions (D-068)."
                    )
                }
            }
        }
    }
}

/// A Kebutuhan card with a budget and a Keinginan card without one, side by side as on Home (stacked at
/// the accessibility sizes), so both kinds of bottom line show. Decoration only: VoiceOver skips them.
private struct SampleCards: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            SubcategoryCard(
                emoji: "🍚",
                name: SubcategoryNames.seed("Makan"),
                tint: .kebutuhan,
                thisMonth: 1_250_000,
                lastMonth: 1_400_000,
                budget: BudgetProgress(spent: 1_250_000, budget: 1_500_000)
            ) {} contextMenu: {}
            SubcategoryCard(emoji: "☕", name: SubcategoryNames.seed("Kopi"), tint: .keinginan, thisMonth: 245_000, lastMonth: 280_000) {} contextMenu: {}
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Page 3: the two expense groups and the optional budgets (D-003, D-010, D-041, D-069).
private struct GroupsContent: View {
    let density: PageDensity

    var body: some View {
        VStack(alignment: .leading, spacing: density.rowSpacing) {
            BodyText(Text(
                "Setiap pengeluaran masuk ke salah satu kelompok:",
                comment: "Onboarding page 3: every expense belongs to one of the two groups below."
            ))
            GroupTile(tint: .kebutuhan, title: Text(ExpenseGroup.kebutuhan.title), padding: density.tilePadding) {
                Text(
                    "Yang perlu dibayar, misalnya makan, listrik, dan transportasi.",
                    comment: "Onboarding page 3: what Kebutuhan (needs) means, with examples."
                )
            }
            GroupTile(tint: .keinginan, title: Text(ExpenseGroup.keinginan.title), padding: density.tilePadding) {
                Text(
                    "Yang kamu pilih untuk dinikmati, misalnya kopi, jajan, dan hiburan.",
                    comment: "Onboarding page 3: what Keinginan (wants) means, with examples. Neutral, never judging."
                )
            }
            PointRow(systemImage: "gauge.with.dots.needle.33percent") {
                Text(
                    "Anggaran itu pilihan. Pasang lewat Atur di Beranda atau menu kartu.",
                    comment: "Onboarding page 3: budgets are optional; set them from Atur (the button above Home's cards) or a card's long-press menu (D-069)."
                )
            }
            .padding(.top, density.spacing - density.rowSpacing)
        }
    }
}

// MARK: - Pieces

/// The secondary "Pulihkan dari cadangan" (D-060), page 3's last line.
private struct RestoreButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Pulihkan dari cadangan", comment: "Restores all data from a backup file: Pengaturan's row, the link in Home's empty state on a fresh install, and onboarding's last page.")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.brand))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityHint(Text(
            "Pilih berkas cadangan Kemanaya untuk memulihkan datamu.",
            comment: "VoiceOver hint of onboarding's Pulihkan dari cadangan button: it closes the introduction and opens the backup file picker."
        ))
        .accessibilityIdentifier("onboarding.restore")
    }
}

private struct BodyText: View {
    let text: Text

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        text
            .font(.body)
            .foregroundStyle(Color(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// An SF Symbol beside a line of text; the symbol goes above it at the accessibility sizes.
private struct PointRow: View {
    let systemImage: String
    let text: Text

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// One width for every symbol, so the lines of a list start at the same place.
    @ScaledMetric(relativeTo: .title3) private var symbolWidth: CGFloat = 28

    init(systemImage: String, @ViewBuilder text: () -> Text) {
        self.systemImage = systemImage
        self.text = text()
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        layout {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color(.brand))
                .frame(width: symbolWidth)
                .accessibilityHidden(true)
            text
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A group's name and meaning on its card surface, as on Home's cards (D-040).
private struct GroupTile: View {
    let tint: CategoryTint
    let title: Text
    let padding: CGFloat
    let detail: Text

    init(tint: CategoryTint, title: Text, padding: CGFloat, @ViewBuilder detail: () -> Text) {
        self.tint = tint
        self.title = title
        self.padding = padding
        self.detail = detail()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title
                .font(.headline)
                .foregroundStyle(Color(tint.content))
            detail
                .font(.subheadline)
                .foregroundStyle(Color(tint.secondaryContent))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(tint.surface), in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The main action: `textPrimary` filled, `appBackground` text, the pair ChoiceChips uses (D-040).
private struct PrimaryButtonLabel: View {
    let text: Text

    var body: some View {
        text
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(.appBackground))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color(.textPrimary), in: .capsule)
            .contentShape(.capsule)
    }
}

/// Which page is showing. VoiceOver reads it as "Halaman 1 dari 3".
private struct PageDots: View {
    let current: Int
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(Color(index == current ? .textPrimary : .textSecondary))
                    .opacity(index == current ? 1 : 0.5)
                    .frame(width: index == current ? 20 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? nil : .default, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "Halaman \(current + 1) dari \(count)",
            comment: "VoiceOver label of the onboarding page indicator, e.g. 'Halaman 1 dari 3' (page 1 of 3)."
        ))
        .accessibilityIdentifier("onboarding.pageDots")
    }
}

#Preview("Page 1") {
    OnboardingView(onFinish: {}, onRestore: {})
}

#Preview("Page 2") {
    OnboardingView(initialPage: 1, onFinish: {}, onRestore: {})
}

#Preview("Page 3") {
    OnboardingView(initialPage: 2, onFinish: {}, onRestore: {})
}
