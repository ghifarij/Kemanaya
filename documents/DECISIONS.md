# Kemanaya — Decisions

Single source of truth for every product, design and engineering decision.
Append new decisions; when one is overturned, mark it `SUPERSEDED by D-xxx` instead of deleting it.

Format: `D-NNN · date · decision` → **Why**.

---

## Product

- **D-001 · 2026-11-16 · Name: Kemanaya** ("Kemana ya?" — where did my money go?). Folder `~/Vibecoding/Kemanaya`, targets `Kemanaya`, `KemanayaTests`, `KemanayaUITests`, bundle id `com.afgaghifari.kemanaya`.
  **Why:** short, Indonesian, states the app's question.
- **D-002 · 2026-11-16 · Tracks expenses (Pengeluaran) and income (Pemasukan).** Each transaction has a kind: `expense` | `income`.
  **Why:** the user wants to see where money goes *relative to* what came in.
- **D-003 · 2026-11-16 · Expenses have exactly two fixed parent groups: Kebutuhan (needs) and Keinginan (wants).** Groups are not user-editable.
  **Why:** the needs-vs-wants split is the core insight of the app.
- **D-004 · 2026-11-16 · Every expense subcategory belongs to exactly one group, permanently.** No per-transaction override toggle. (e.g. Makan is always Kebutuhan; eating out is the separate subcategory Nongkrong under Keinginan.)
  **Why:** user decision — simplest mental model, zero extra taps.
- **D-005 · 2026-11-16 · Income subcategories are a flat list (no groups).**
- **D-006 · 2026-11-16 · Subcategories are user-editable:** add, rename, change emoji, reorder, hide. Deleting a subcategory that has transactions or rollups *hides* it instead.
  **Why:** keep history and recaps intact.
- **D-007 · 2026-11-16 · Naming rule: subcategory names are one word, ≤ 10 characters, each with an emoji.** Subcategories are named by purpose, never by brand (Ojol, not Grab).
  **Why:** names must fit on pinned cards; brands span several purposes.
- **D-008 · 2026-11-16 · Seed subcategories:**
  - **Pemasukan:** Gaji 💼 · Bonus 🎉 · Sampingan 💻 · Usaha 🏪 · Investasi 📈 · Hadiah 🎁 · Refund ↩️ · Lainnya ✨
  - **Kebutuhan:** Makan 🍚 · Dapur 🥬 · Galon 💧 · Gas 🔥 · Listrik ⚡ · Air 🚰 · WiFi 📶 · Pulsa 📱 · Sewa 🏠 · Cicilan 💳 · Ojol 🛵 · Bensin ⛽ · Parkir 🅿️ · Tol 🛣️ · Transport 🚆 · Kesehatan 💊 · Pendidikan 📚 · Asuransi 🛡️ · Laundry 🧺 · Sedekah 🤲 · Rumah 🧹 · Servis 🔧
  - **Keinginan:** Kopi ☕ · Jajan 🍿 · Nongkrong 🍽️ · Delivery 🥡 · Olshop 📦 · Fashion 👕 · Skincare 🧴 · Hiburan 🎬 · Streaming 📺 · Game 🎮 · Hobi 🎨 · Gadget 🎧 · Liburan 🏖️ · Kado 🎁
  **Why:** Sedekah is a commitment → Kebutuhan. THR merged into Bonus. Expense gift is "Kado" so it never collides with income "Hadiah".
- **D-009 · 2026-11-16 · Savings are not a category. "Sisa bulan ini" = income − expenses, plus savings-rate %.** Computed, never entered.
  **Why:** saving isn't spending; keeps "where did it go" honest.
- **D-010 · 2026-11-16 · Optional monthly budget for Kebutuhan and Keinginan**, shown as progress.
- **D-011 · 2026-11-16 · Out of scope for v1:** widgets, App Intents/Siri, recurring transactions, multiple accounts/wallets, savings goals, CSV import.

## Home & insights

- **D-012 · 2026-11-16 · Home is built around pinned subcategory cards.** Default 6 pins in a 2×3 grid: **Makan, Kopi, Jajan, Parkir, Galon, Hiburan**. User can pin/unpin/reorder, max 9. Income subcategories can be pinned too.
  - Card shows: emoji, name, this month's total, tiny bar vs last month.
  - **Tap** → quick-add keypad with that subcategory preselected (amount + save = 2 taps).
  - **Long-press** → context menu: Lihat detail · Edit · Lepas pin.
  **Why:** fastest logging path and at-a-glance spending in one surface. User will judge after the first build — revisit then.
- **D-013 · 2026-11-16 · Add flow ≤ 3 taps:** "+" → big amount + custom rupiah keypad (`000` key, quick-amount chips) → tap subcategory to save. Note and date optional (date defaults to today). Swipe to edit/delete rows.
- **D-014 · 2026-11-16 · v1 insight screens:** Home (month total, sisa, Kebutuhan vs Keinginan split bar, budget), Breakdown (donut + ranked list per subcategory, drill-down), Trend (Swift Charts daily/weekly bars, month-over-month), History (searchable, grouped by day), Yearly recap (D-017).

## Data

- **D-015 · 2026-11-16 · Persistence: SwiftData, local only. No CloudKit / iCloud sync.** Each device has its own independent data (iPhone XR and iPhone 15 are not synced).
  **Why:** no paid Apple Developer Program membership (D-024).
- **D-016 · 2026-11-16 · Money is IDR only, stored as integer rupiah (`Int64`), no decimals.** Displayed as `Rp45.000`.
  **Why:** no floating-point rounding errors.
- **D-017 · 2026-11-16 · Retention: rolling 13 calendar months of raw transactions + permanent monthly rollups + yearly recap.**
  - Raw window = `startOfMonth(now) − 12 months` … now. In Nov 2026 the whole of Nov 2025 is visible; on 1 Dec 2026 Nov 2025's raw transactions are purged.
  - **Before purging a month, roll it up**: per subcategory → total, count, plus snapshots of name, emoji, kind, group. Rollups are kept forever (~40 rows/month).
  - **Yearly recap** for every completed year = rollups + raw. The 2026 recap is available from 1 Jan 2027 and stays forever; its individual transactions do not.
  - Purge runs at most once per month (on launch / foreground), one month at a time, in device-local calendar.
  **Why:** user wants a bounded window but a permanent year review. Rolling purge removes one month at a time (no Jan-1 wipe) and always keeps "this month vs same month last year".
- **D-018 · 2026-11-16 · Index transactions on `date`** (SwiftData `#Index`, iOS 18+). Every screen fetches a date range, never the whole table.
- **D-019 · 2026-11-16 · Backup that survives app deletion: auto-backup JSON to a user-chosen Files folder** (iCloud Drive recommended).
  - User picks a folder once (Settings › Cadangan Otomatis); the app persists a **security-scoped bookmark** — works without entitlements on free signing.
  - Writes `Kemanaya-backup.json` + previous copy `Kemanaya-backup.prev.json` (protects against a torn write). Write 5 s after the last change (debounced) and once on launch.
  - Full fidelity: transactions, subcategories, pins, rollups, budgets, settings. Versioned schema field.
  - Fresh install with empty store → offer **"Pulihkan dari cadangan"** (restore).
  - Size: ~0.8 MB typical, ~2 MB heavy (raw capped by D-017; rollups add ~70 KB/year); ≤ ~5 MB with both files.
  **Why:** the app sandbox is wiped on delete; iCloud containers/App Groups need a paid account. Files + bookmarks don't.
  **Risk:** bookmark persistence on free signing must be proven by the Phase 1 spike on real devices. Fallback: manual export/import only.
- **D-020 · 2026-11-16 · Manual "Ekspor CSV"** (Settings) for spreadsheets, in v1.

## Brand & design

- **D-021 · 2026-11-16 · Follow current Apple HIG (Liquid Glass) for system chrome; the brand lives in the content layer.** Tab bar, nav bars, toolbars, sheets, system buttons stay native. Cards, charts, keypad, typography and color carry the brand.
- **D-022 · 2026-11-16 · Brand direction "Pop" (playful) with trust guardrails.**
  - **Palette:** brand **Electric Violet `#6C3BFF`**; **Kebutuhan = Violet**, **Keinginan = Hot Coral `#FF5A5F`**, **Pemasukan = Lime `#C6F432`** (always dark text on lime). Warm off-white background; near-black in dark mode. Every color has light / dark / increased-contrast variants, all WCAG AA.
  - **Type:** SF Pro Rounded **Heavy** for amounts and titles, monospaced digits for all amounts; SF Pro for body. Full Dynamic Type.
  - **Icons:** emoji for subcategories (user-chosen). SF Symbols for UI chrome.
  - **Cards:** solid, chunky, tinted surfaces sitting under the glass chrome.
  - **Motion:** springy card presses, success haptic on save.
  - **Guardrail:** never celebrate spending. Positive copy/confetti only for good savings rate or staying under budget. Amounts always high-contrast, no gradients behind numbers.
  - **Mascot "Si Naya"** — a curious coin with eyes; app icon, empty states, onboarding only.
  - **Voice:** friendly, non-judgmental Indonesian ("Bulan ini kamu paling banyak di Kopi ☕").
  **Why:** user chose playful (Pop); guardrails keep a money app trustworthy.
- **D-023 · 2026-11-16 · Localization: Indonesian first, English second**, via String Catalogs. Code, comments and docs in English.

- **D-040 · 2026-11-17 · Color tokens and data-mark rule (refines D-022).** Approved by the user.
  - The D-022 hexes stay exact as the **vivid** tokens `kebutuhan` / `keinginan` / `pemasukan` (+ `brand` = `AccentColor`), used for decoration only: swatches, illustration, glass backdrops.
  - **Bars and data marks** use AA-safe **Strong** tokens (light base): `kebutuhanStrong #6C3BFF`, `keinginanStrong #D9343B`, `pemasukanStrong #4A6B00`.
  - Text never sits in a vivid color. Cards use tinted surfaces (`kebutuhanSurface`, `keinginanSurface`) with `textPrimary` / `textSecondary`. **Pemasukan cards are solid lime with `onPemasukan` (near-black) text in every appearance, dark mode included.**
  - Card mini-bars: thick bar = this month in the Strong color, thin bar = last month in the card's secondary content color. There is no visible legend; onboarding explains it (Phase 11) and VoiceOver reads it.
  - Every token has light / dark / light+HC / dark+HC variants in `Assets.xcassets/Colors`. Increased contrast swaps to a pure white / pure black background and darker brand colors.
  - `KemanayaTests/TokenContrastTests` enforces every pair the components draw: text ≥ 4.5:1 (≥ 7:1 in high contrast), non-text ≥ 3:1. A new color pair needs a row there.
  - `AmountText` never wraps or truncates digits. It stays on one line and scales down (min 0.4×).
  **Why:** coral `#FF5A5F` is 2.9:1 and lime ~1.3:1 on the off-white background, so the brand hexes can't carry data or text and still meet D-022's AA rule.

## Platform & architecture

- **D-024 · 2026-11-16 · No paid Apple Developer Program. Free Personal Team signing, personal devices only.**
  - Installed builds expire after **7 days** → re-run from Xcode to refresh. Data survives re-install as long as the app isn't deleted and the bundle id is unchanged.
  - Max 3 sideloaded apps per device.
- **D-025 · 2026-11-16 · Minimum iOS 18.0, built with the iOS 27.1 SDK (Xcode 27.1).**
  - Devices: **iPhone XR (iOS 18 max)** and **iPhone 15 (iOS 26+)**.
  - System chrome gets Liquid Glass automatically on iOS 26+ and the classic look on iOS 18.
  - Custom glass goes through **one design-system modifier**: Liquid Glass on iOS 26+, `.ultraThinMaterial` fallback on iOS 18. No scattered `#available` checks in feature code.
  **Why:** user wants to run on the XR too.
- **D-026 · 2026-11-16 · Stack: SwiftUI + SwiftData + `@Observable`. No third-party dependencies.** Feature folders (`Features/AddTransaction`, `Features/Home`, …) plus a shared `DesignSystem/`.
- **D-027 · 2026-11-16 · Tests: Swift Testing for domain logic** (aggregation, date bucketing, rollup/purge, IDR formatting, backup encode/decode); XCUITest for the add flow.
- **D-028 · 2026-11-16 · Xcode project uses file-system-synchronized groups** (Xcode 16+ format); generated by Claude, fallback = user creates via Xcode template. Shared `Config/*.xcconfig`, following Fuely's layout.
  **Why:** new files need no `project.pbxproj` edits → no merge conflicts between subagents.
  - Signing: committed `Config/Signing.xcconfig` (`DEVELOPMENT_TEAM =` + `#include? "Signing.local.xcconfig"`); the real team id lives only in gitignored `Config/Signing.local.xcconfig`.
  - Build settings carried over from Fuely: `CODE_SIGN_STYLE = Automatic`, `GENERATE_INFOPLIST_FILE = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`, `STRING_CATALOG_GENERATE_SYMBOLS = YES`, `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`, `TARGETED_DEVICE_FAMILY = 1`, `IPHONEOS_DEPLOYMENT_TARGET = 18.0`, Swift 6 language mode.
  - No app extensions: free signing allows only 10 App IDs per 7 days.
- **D-029 · 2026-11-16 · Simulators:** iPhone 17 Pro (iOS 26.5) and iPhone 16 Pro (iOS 18.6) for every slice. Also check iPhone SE 3rd gen (iOS 18.3, smallest screen) and iPhone Duo (iOS 27.1, adaptive layout) before a phase closes. Behaviour bugs often appear only on the oldest runtime — test iOS 18 every time.
- **D-036 · 2026-11-16 · Pure logic lives in a local Swift package `KemanayaCore`** (`swift-tools-version: 6.0`, `.iOS(.v18)`) with its own Swift Testing target: SwiftData models, formatting, month bucketing, aggregation, rollup/purge, backup/CSV encoding, copy strings logic. The app target holds views, design system and wiring only. Test-first where practical.
  **Why:** proven in Fuely; keeps logic testable and the app target thin.

## Workflow

- **D-030 · 2026-11-16 · Claude is the orchestrator; feature work goes to subagents.** One subagent at a time; two in parallel only when they touch separate feature folders and no shared files (data model, design system, project file).
- **D-031 · 2026-11-16 · Builds go through the Xcode MCP (`xcrun mcpbridge`) first;** `xcodebuild` / `simctl` only for what the MCP cannot do — log the reason here when that happens. The orchestrator runs every verification build, one at a time. *(Launch command amended by D-038.)*
  - Fallback log:
    - 2026-11-16 · `xcodebuild build-for-testing` (once): to confirm the `-Wincompatible-sysroot` linker warning was specific to the MCP. Plain `xcodebuild` built with zero warnings (see D-038).
    - 2026-11-16 · `xcrun simctl` for appearance, Dynamic Type size and screenshots: the MCP's device-interaction tools accept only the iOS 27.1 simulator, so they can't drive the iOS 26.5, 18.6 or 18.3 runtimes.
- **D-032 · 2026-11-16 · Quality gate per slice:** clean build with zero warnings · tests green · screenshots reviewed by the orchestrator in light, dark, and largest accessibility Dynamic Type on both simulators (D-029) · DECISIONS.md and PROGRESS.md updated.
- **D-033 · 2026-11-16 · Reuse Fuely's proven conventions** (build commands, docs layout, MCP workflow); nothing Fuely-specific.
- **D-038 · 2026-11-17 · `.mcp.json` launches the bridge by absolute path** (`/Applications/Xcode.app/Contents/Developer/usr/bin/mcpbridge`), not through `xcrun mcpbridge`. Approved by the user.
  **Why:** `xcrun` exports `SDKROOT=…/MacOSX.sdk` to the bridge, and the headless build service inherits it. That produced a `-Wincompatible-sysroot` linker warning on `KemanayaCoreTests` that only appears in MCP builds and breaks the zero-warnings gate (D-032). The path needs updating if Xcode is installed elsewhere (e.g. `Xcode-beta.app`).
  **Verified 2026-11-17:** a clean MCP build has zero warnings on iPhone 17 Pro (26.5) and iPhone 16 Pro (18.6), with tests 3/3 green. Gotcha: the headless `Xcode Service` helper outlives the bridge and keeps the environment it started with. When switching from the old launch, quit it once (`pkill -f "Xcode Service.app"`), then reconnect the MCP with `/mcp`.

## Git & CI

- **D-034 · 2026-11-16 · Public GitHub repo. One branch + one PR per slice; no direct pushes to `main`.**
  - Claude creates branches (`feat/…`, `fix/…`, `chore/…`), commits, pushes the branch and opens the PR with `gh`.
  - **The user reviews and merges.**
  - `main` protected twice: local Claude Code hook (git-guardrails skill) + GitHub branch protection (set up by the user).
  **Why:** public repo = free unlimited macOS CI minutes and a portfolio piece; the user stays in control of `main`.
- **D-035 · 2026-11-16 · CI (GitHub Actions): SwiftLint → build → unit tests on simulator, on every PR. No signing/distribution.**
  - **The user writes all CI/DevOps files; Claude teaches and reviews** (DevOps learning goal).
  - Set up right after the project scaffold so it guards every slice.
  - First check: which Xcode versions the GitHub macOS runner image provides (27.1 may lag).
- **D-037 · 2026-11-16 · Public-repo hygiene: before every commit, inspect the staged diff for personal data** — team id, device names/UDIDs, email, real transaction data, screenshots. Screenshots are confidential: review them from a gitignored folder, never commit them.
  **Why:** the repo is public (D-034).
- **D-039 · 2026-11-17 · PRs are merged by squash only** (one commit on `main` per PR, titled after the PR). The user merges, on GitHub or with `gh pr merge <n> --squash --delete-branch`. Approved by the user.
  **Why:** `main` keeps one readable commit per slice, while the branch can hold as many work-in-progress commits as needed.
