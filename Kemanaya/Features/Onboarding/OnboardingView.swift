import KemanayaCore
import SwiftUI

/// The first-launch introduction (D-063): three skippable pages in a full-screen cover.
/// 1. What Kemanaya answers: "Kemana ya uangku?".
/// 2. The pinned cards: tap to log, long-press for the menu, and the mini-bar legend (thick bar = this
///    month, thin bar = last month, D-040), shown on a sample card.
/// 3. Kebutuhan vs Keinginan and optional budgets, with **Mulai** and a secondary **Pulihkan dari
///    cadangan** (D-060).
///
/// Si Naya appears on every page, curious or calm, never reacting to money (D-022). **Lewati** on the
/// first two pages finishes at once. Pages swipe, and **Lanjut** moves on; with Reduce Motion the page
/// changes without the slide. Each page scrolls, so nothing is cut at the largest text sizes, and
/// VoiceOver moves to the new page's title.
struct OnboardingView: View {
    /// Mulai or Lewati.
    let onFinish: () -> Void
    /// Pulihkan dari cadangan.
    let onRestore: () -> Void

    private static let pageCount = 3

    @State private var page: Int
    @AccessibilityFocusState private var focusedTitle: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                } content: {
                    WelcomeContent()
                }
                .tag(0)
                // The fullest page: a smaller Si Naya and tighter rows keep it whole at the default size.
                OnboardingPage(index: 1, mood: .calm, mascotSize: 56, focusedTitle: $focusedTitle) {
                    Text("Kartu untuk catat cepat", comment: "Onboarding page 2 title: the pinned cards on Home are for quick logging.")
                } content: {
                    CardsContent()
                }
                .tag(1)
                OnboardingPage(index: 2, mood: .curious, mascotSize: 72, focusedTitle: $focusedTitle) {
                    Text("Kebutuhan dan Keinginan", comment: "Onboarding page 3 title: the two expense groups, needs and wants.")
                } content: {
                    GroupsContent()
                    // At the accessibility sizes it scrolls with the page, so the fixed bar stays small.
                    if dynamicTypeSize.isAccessibilitySize {
                        RestoreButton(action: onRestore)
                    }
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

    /// The page dots, Lanjut or Mulai, and on the last page Pulihkan dari cadangan. Its height is the same
    /// on every page: the restore row keeps its place, invisible, before the last page. A bar that grew on
    /// the last page shrank the pager under a page already laid out, which hid page 3's last line behind
    /// the dots.
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
            // At the accessibility sizes it scrolls with page 3 instead, so the fixed bar stays small.
            if !dynamicTypeSize.isAccessibilitySize {
                RestoreButton(action: onRestore)
                    .opacity(isLastPage ? 1 : 0)
                    .disabled(!isLastPage)
                    .accessibilityHidden(!isLastPage)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Page

/// One page: Si Naya, the title and the page's content, scrolling when it doesn't fit. While more of
/// the page lies below, its bottom edge fades out, so a line cut by the pager reads as "scroll for more"
/// rather than a clipped layout; the fade goes away at the end of the page.
private struct OnboardingPage<Content: View>: View {
    let index: Int
    let mood: SiNaya.Mood
    let mascotSize: CGFloat
    let focusedTitle: AccessibilityFocusState<Int?>.Binding
    let title: Text
    let content: Content

    @State private var hasMoreBelow = false

    private let fadeHeight: CGFloat = 32

    init(
        index: Int,
        mood: SiNaya.Mood,
        mascotSize: CGFloat,
        focusedTitle: AccessibilityFocusState<Int?>.Binding,
        @ViewBuilder title: () -> Text,
        @ViewBuilder content: () -> Content
    ) {
        self.index = index
        self.mood = mood
        self.mascotSize = mascotSize
        self.focusedTitle = focusedTitle
        self.title = title()
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EmptyStateMascot(mood: mood, size: mascotSize)
                    .frame(maxWidth: .infinity)
                title
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused(focusedTitle, equals: index)
                    .accessibilityIdentifier("onboarding.title.\(index + 1)")
                content
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

/// Page 2: the pinned cards, on a sample card that can't be tapped. Its rows sit closer than the other
/// pages' so the whole page fits above the dots at the default text size.
private struct CardsContent: View {
    private let tint = CategoryTint.keinginan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BodyText(Text(
                "Kartu di Beranda adalah kategori pilihanmu. Ganti pilihannya kapan saja lewat Atur.",
                comment: "Onboarding page 2: the cards on Home are the pinned subcategories; Atur (the button above them) changes which."
            ))
            SubcategoryCard(emoji: "☕", name: "Kopi", tint: tint, thisMonth: 245_000, lastMonth: 280_000) {} contextMenu: {}
                .frame(maxWidth: 220)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            legend
            PointRow(systemImage: "hand.tap") {
                Text("Ketuk kartu untuk mencatat.", comment: "Onboarding page 2: tapping a card logs a transaction into it.")
            }
            PointRow(systemImage: "ellipsis.circle") {
                Text(
                    "Tekan lama kartu untuk melihat detail, mengubah, atau melepas pinnya.",
                    comment: "Onboarding page 2: long-pressing a card opens its menu (Lihat detail, Ubah, Lepas pin)."
                )
            }
        }
    }

    /// The card's two bars, explained (D-040): there's no legend on the cards themselves.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            LegendRow(height: 8, color: Color(tint.bar)) {
                Text("Batang tebal: bulan ini", comment: "Onboarding page 2, mini-bar legend: the thick bar on a card is this month.")
            }
            LegendRow(height: 4, color: Color(.textSecondary)) {
                Text("Batang tipis: bulan lalu", comment: "Onboarding page 2, mini-bar legend: the thin bar on a card is last month.")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Page 3: the two expense groups and the optional budgets (D-003, D-010, D-041).
private struct GroupsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BodyText(Text(
                "Setiap pengeluaran masuk ke salah satu kelompok:",
                comment: "Onboarding page 3: every expense belongs to one of the two groups below."
            ))
            GroupTile(tint: .kebutuhan, title: Text(ExpenseGroup.kebutuhan.title)) {
                Text(
                    "Yang perlu dibayar, misalnya makan, listrik, dan transportasi.",
                    comment: "Onboarding page 3: what Kebutuhan (needs) means, with examples."
                )
            }
            GroupTile(tint: .keinginan, title: Text(ExpenseGroup.keinginan.title)) {
                Text(
                    "Yang kamu pilih untuk dinikmati, misalnya kopi, jajan, dan hiburan.",
                    comment: "Onboarding page 3: what Keinginan (wants) means, with examples. Neutral, never judging."
                )
            }
            PointRow(systemImage: "gauge.with.dots.needle.33percent") {
                Text(
                    "Anggaran itu pilihan. Atur di Pengaturan kalau kamu mau, per kelompok atau per kategori.",
                    comment: "Onboarding page 3: budgets are optional and set in Pengaturan, per group or per subcategory."
                )
            }
        }
    }
}

// MARK: - Pieces

/// The secondary "Pulihkan dari cadangan" (D-060): in the fixed bar, or at the end of page 3 at the
/// accessibility sizes.
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
                .frame(minWidth: 28)
                .accessibilityHidden(true)
            text
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A sample bar and what it means.
private struct LegendRow: View {
    let height: CGFloat
    let color: Color
    let text: Text

    @ScaledMetric(relativeTo: .caption) private var scale: CGFloat = 1

    init(height: CGFloat, color: Color, @ViewBuilder text: () -> Text) {
        self.height = height
        self.color = color
        self.text = text()
    }

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(color)
                .frame(width: 44, height: height * scale)
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
    let detail: Text

    init(tint: CategoryTint, title: Text, @ViewBuilder detail: () -> Text) {
        self.tint = tint
        self.title = title
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
        .padding(16)
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
