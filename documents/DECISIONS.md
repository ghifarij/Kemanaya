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
- **D-009 · 2026-11-16 · Savings are not a category. "Sisa bulan ini" = income − expenses, plus savings-rate %.** Computed, never entered. *(Sisa and savings rate removed from the app by D-070.)*
  **Why:** saving isn't spending; keeps "where did it go" honest.
- **D-010 · 2026-11-16 · Optional monthly budget for Kebutuhan and Keinginan**, shown as progress. *(Extended by D-041.)*
- **D-011 · 2026-11-16 · Out of scope for v1:** widgets, App Intents/Siri, recurring transactions, multiple accounts/wallets, savings goals, CSV import.
- **D-041 · 2026-11-17 · Budgets at two levels, both optional, one standing monthly amount each (extends D-010).** Approved by the user.
  - **Group budget:** Kebutuhan and Keinginan (D-010), shown on Home.
  - **Subcategory budget:** any expense subcategory (e.g. Kopi, Delivery), shown as progress on its card and in Breakdown. Income subcategories have no budget.
  - The amount applies every month until changed; there are no per-month budgets. Subcategory budgets need not add up to the group budget.
  - Under-budget copy may be positive; going over is stated neutrally, never celebrated or shamed (D-022).
  **Why:** the user wants to cap specific habits (coffee, delivery, minimarket runs) as well as each group as a whole.

## Home & insights

- **D-012 · 2026-11-16 · Home is built around pinned subcategory cards.** Default 6 pins in a 2×3 grid: **Makan, Kopi, Jajan, Parkir, Galon, Hiburan**. User can pin/unpin/reorder, max 9. Income subcategories can be pinned too. *(Layout, limits and mini-bars superseded by D-068.)*
  - Card shows: emoji, name, this month's total, tiny bar vs last month.
  - **Tap** → quick-add keypad with that subcategory preselected (amount + save = 2 taps).
  - **Long-press** → context menu: Lihat detail · Edit · Lepas pin.
  **Why:** fastest logging path and at-a-glance spending in one surface. User will judge after the first build — revisit then.
- **D-013 · 2026-11-16 · Add flow ≤ 3 taps:** "+" → big amount + custom rupiah keypad (`000` key, quick-amount chips) → tap subcategory to save *(tap-to-save superseded by D-067: tap selects, Simpan saves)*. Note and date optional (date defaults to today). Swipe to edit/delete rows.
- **D-043 · 2026-11-18 · Add-flow details (refines D-013).** Approved by the user.
  - **Entry point until Home (Phase 5):** a temporary "this month" transaction list is the root, with "+" in the toolbar and swipe actions on rows. Home replaces it as the root in Phase 5, and the list is the starting point for History (Phase 7). The design gallery stays reachable through its `-gallerySection` launch argument.
  - ~~**Amount:** type it on the rupiah keypad, or tap quick chips **+5rb · +10rb · +50rb · +100rb**, which *add* to the current amount. Both can be combined.~~ SUPERSEDED by D-044 (no chips).
  - **Kind:** a segmented control **Pengeluaran | Pemasukan** at the top of the sheet, defaulting to Pengeluaran. The grid shows Kebutuhan + Keinginan sections for expenses, or the flat income list.
  - **Delete:** swipe → "Hapus" → a confirmation dialog that names the amount and subcategory.
  **Why:** the user wants both fast chips and exact entry, and no accidental loss of money data.
- **D-044 · 2026-11-18 · Add-flow refinements after the Phase 4 review (amends D-012, D-013, D-043).** Approved by the user.
  - **No quick-amount chips.** The amount is typed on the rupiah keypad only (with the `000` key). Real prices are rarely round, so chips don't help. Supersedes the chips in D-013 and D-043.
  - **Dates:** any day from the start of the D-017 raw window to the **end of the current month**, so upcoming days of this month are allowed. Planning is per month: an entry planned on 1 Dec for later in December counts toward December's totals and budgets right away. Dates in later months are not allowed.
  - **Preselected subcategory** (pinned-card tap, Phase 5; edit): save with **Simpan**, or by tapping the already-highlighted tile.
  - **Wording:** editing is **"Ubah"** everywhere: the swipe action, the sheet title, and D-012's long-press menu item ("Lihat detail · Ubah · Lepas pin").
  **Why:** the user types exact amounts and plans spending a month at a time against the monthly budgets (D-041).
- **D-047 · 2026-11-19 · The add/edit sheet shows the selected subcategory next to the amount (refines D-043, D-044).** Approved by the user.
  - When a subcategory is selected, a label with its emoji and name (e.g. "☕ Kopi") sits beside or under the amount, in every layout.
  - **Regular text sizes:** on opening with a preselected subcategory, the grid still scrolls the tile into view.
  - **Large text sizes (scrolling layout, XX Large and up):** the sheet opens at the top, so the amount and keypad are visible. The label shows what is selected, and nothing scrolls to the tile.
  **Why:** at AX5 the sheet is one long column. Scrolling to the tile hid the amount and keypad, and you usually edit the amount. The label answers "what is selected?" without scrolling, and the same label serves the Phase 5 quick add from a pinned card.
- **D-048 · 2026-11-19 · Phase 5 Home scope (refines D-012, D-021, D-041, D-043).** Approved by the user.
  - **Navigation:** a native tab bar (D-021). Phase 5 has **Beranda** (Home, the root) and **Riwayat** (the month transaction list from D-043, the starting point for History in Phase 7). **Analisis** arrives with Phase 6 and **Pengaturan** with Phase 10. "+" stays in Home's toolbar.
  - **Card long-press menu:** Phase 5 ships only the item that works, **Lepas pin**. **Lihat detail** arrives with Breakdown (Phase 6) and **Ubah** (edit the subcategory) with Settings (Phase 10). D-012's full menu is the end state.
  - **Pin management:** an **Atur** button above the cards opens a sheet. It lists all visible subcategories with a pin toggle, and the pinned ones sit at the top with drag-to-reorder. A 10th pin is refused with a short note (max 9, D-012).
  - **Budgets before Settings:** group and card budget progress shows only when a budget exists, so Phase 5 Home shows none on a fresh install. A DEBUG-only launch argument seeds budgets so the progress UI can be tested and screenshotted.
  **Why:** ship only working controls, keep native chrome, and don't pull Phase 6/10 work forward.
- **D-049 · 2026-11-19 · Hiding a subcategory unpins it (refines D-012).** Approved by the user.
  - Hiding a pinned subcategory clears its pin (`isPinned = false`, no `pinOrder`), and the remaining pins renumber `0..<n`. Unhiding doesn't pin it again.
  - So every pin is visible, the max-9 rule counts all pins, and no two pins share a `pinOrder`.
  - The rule lives in `Ledger` and ships with Phase 5, so Phase 10's hide control only calls it.
  **Why:** a "pinned but hidden" state let order numbers tie and could give 10 cards after unhiding (Phase 5 review, S1).
- **D-050 · 2026-11-19 · Phase 5 Home details (refines D-009, D-022, D-041, D-048).** Approved by the user.
  - **Riwayat keeps its own "+"** alongside Home's. Both open the same add sheet.
  - **Over budget:** the meter keeps the group's Strong colour (Keinginan's is a red, #D9343B) with "Lewat Rp…". The overflow gets no other colour.
  - **Negative savings rate:** when spending exceeds income, the rate (e.g. "-15%") gets a short note under it, "Pengeluaran melebihi pemasukan", in a neutral secondary colour. No alarm colour and no judging wording.
  **Why:** a negative number on its own is easy to misread, and a factual note explains it without alarm (D-022).
- **D-051 · 2026-11-19 · Phase 6 Analisis scope (refines D-014, D-012, D-048).** Approved by the user.
  - **Navigation:** a third tab, **Analisis**: one scrolling page with Breakdown (Rincian) first and Trend (Tren) below. No segmented picker.
  - **Period:** a month stepper at the top ("‹ November 2026 ›") that starts on the current month and goes back as far as the 13-month detail window (D-017). It sets the month for the whole page.
  - **Breakdown:** a donut and a ranked list of **expense** subcategories for the month, with a **Semua · Kebutuhan · Keinginan** filter. Income isn't in the donut (Home shows it).
  - **Drill-down:** tapping a ranked row opens the subcategory detail. So does the card menu's **Lihat detail**, which now joins Lepas pin (D-012). The detail shows the month's total, budget progress when a budget is set (D-041), the comparison with last month, and that month's transactions (tap = Ubah, swipe = Hapus, as in Riwayat).
  - **Trend:**
    - (a) A Swift Charts bar chart of the month's spending with a **Harian · Mingguan** switch. The bars stack Kebutuhan and Keinginan in their group colours and follow the group filter.
    - (b) Month-over-month: paired bars for **pengeluaran and pemasukan** over the 6 months ending at the selected month, with the selected month highlighted.
  - Never celebrate spending (D-022): differences are neutral numbers, with no praise or alarm colours.
  **Why:** one page keeps the tab bar small and reads top to bottom. The month stepper and group filter give enough control without adding History (Phase 7) early.
- **D-052 · 2026-11-19 · Phases 5 and 6 share one branch and one PR (exception to D-034's branch per phase).** Approved by the user.
  - Phase 5 is committed on `feat/phase-5-6-home-analisis` before its gate finishes, and Phase 6 is built on the same branch right away.
  - The orchestrator's test runs go on in the background. The full gate (both OS versions, tour in light / dark / AX5) runs on the combined result before the PR. Its results are recorded in PROGRESS when they arrive.
  - Because Xcode and the simulators are shared, builds and tests take turns: nobody builds or tests while the lock file `.xcode-busy` (in the session scratchpad) exists.
  **Why:** the user wants to move to the next phase quickly instead of waiting for each gate.
  - **Update 2026-11-19:** the user merged Phase 5 by itself as PR #9. Phase 6 moved to its own branch, `feat/phase-6-analisis`, with its own PR, and Phase 7 gets `feat/phase-7-history` (back to D-034's branch per phase). The Xcode lock rule stays.
- **D-053 · 2026-11-19 · Phase 7 History scope (refines D-014, D-017, D-043, D-048).** Approved by the user.
  - **Riwayat becomes History:** one continuous list over the whole 13-month raw window (D-017), newest first, loaded as you scroll. Each month starts with a header showing that month's total, and each day has a sticky header.
  - **Day header:** the date (e.g. "Kamis, 19 Nov") and that day's pengeluaran total. On days with income, a separate "+Rp…" in neutral text. No judging colours (D-022).
  - **Search:** native `.searchable`. It matches the subcategory name and the note (case- and diacritic-insensitive), and digits match the amount ("18000" and "18.000" both find Rp18.000). Results keep the day grouping.
  - **No filters** beyond search: no kind or group chips and no date-range picker.
  - Rows keep D-043's actions (tap = Ubah, swipe = Hapus), and Riwayat keeps its "+" (D-050).
  **Why:** one scrolling list is the natural way to look back. Search covers the "when did I buy that?" question without adding filter UI.
- **D-054 · 2026-11-19 · Fast gate by default; the full UI suite and the screenshot tour run only when the user asks (amends D-032).** Approved by the user.
  - **Per phase (implementer, fix round, orchestrator gate):** build with zero warnings, run the unit tests (KemanayaCoreTests and KemanayaTests, about 3 s), and run once only the UI tests the phase added or changed. The gate runs on 26.5 and 18.6.
  - **Full run, only on the user's request:** all UI tests plus the screenshot tour, with the light / dark / AX5 review on both OS versions. The tour code is still written and kept compiling each phase so it can run at any time.
  - A Fast test plan (unit tests only) and a Full test plan (everything) are added to the scheme so the Xcode MCP can switch between them.
  **Why:** measured on Phase 5, the unit tests take ~3 s, while the UI tests take ~6 min and the tour ~11 min per OS. The full suite ran several times per phase. The user wants the app finished first and on their phone soon, and will ask for the full run.
- **D-055 · 2026-11-19 · Phase 6 Analisis details (refines D-040, D-051).** Approved by the user.
  - **6-month chart:** ignores the Semua / Kebutuhan / Keinginan filter, because income has no group. Pengeluaran uses a lighter neutral (`chartNeutral`) and pemasukan uses a new data-mark token, `pemasukanChart` (lime in dark mode). The two bars differ in lightness as well as hue, and both tokens have rows in TokenContrastTests. This adds to D-040's Strong set.
  - **Layout:** Analisis uses the native large title (D-021), the filter sits above the donut, and chart axis labels stop growing at 18 pt at AX5 (the numbers are also in VoiceOver and the ranked list).
  - **Weeks:** Monday to Sunday, clipped to the month (4–6 weeks), whatever the device's first weekday.
  - **Months before the raw window:** from Phase 8, "vs last month" and the 6-month chart read the permanent monthly rollups (D-017) for months whose raw data has been purged, so they never compare against a false Rp0.
  **Why:** the implementer's calls, checked by the independent review and approved by the user. The neutral was lightened because grey and olive measured 1.08:1 and were indistinguishable for colour-blind users.
- **D-056 · 2026-11-20 · No UI tests in Phases 7–10; one full UI run in Phase 11 (amends D-054).** Approved by the user.
  - **Phases 7–10 gate:** build with zero warnings plus the unit tests (KemanayaCoreTests and KemanayaTests) on 26.5 and 18.6. No UI tests run, not even the phase's own. The phase still writes or updates its UI tests and tour shots, and keeps them compiling.
  - **Phase 11:** run the full UI suite and the screenshot tour once on both OS versions, with the light / dark / AX5 review, and fix what breaks before the Phase 12 install.
  - The user can still ask for a full run at any time.
  **Why:** the UI tests are the slow part and need approval prompts. The user wants the app on their phone soon. Unit tests still cover the money math and the Phase 8 purge.
- **D-057 · 2026-11-20 · Riwayat search follows Apple's HIG "Searching" and "Search fields" (refines D-053).** Direction from the user: "focus on what iOS search meant to be".
  - **Live refinement:** results narrow on every keystroke, with no submit step. A digits query matches amounts whose rupiah digits **start with** what has been typed. "18" shows Rp18.000, Rp180.000, Rp1.800 and so on, and "18000" or "18.000" narrows to Rp18.000, Rp180.000, Rp18.000.000 and so on: separators are ignored, so the digits 18000 are a prefix of the digits 180000. "Rp", ".", "," and spaces are ignored. A digits query still matches the note as text too. This replaces exact matching, which showed nothing until the whole amount was typed (HIG: "start search immediately when a person types").
  - **Predictive suggestions while typing:** when the query is not empty, `.searchSuggestions` lists up to 5 subcategory names that contain the query, folded the same way, as completions. Choosing one fills the field. There is **no stored search history**, because this is personal finance data (HIG: "Take privacy into consideration before displaying search history").
  - **Placement:** an inline field above the list it searches, always visible and pinned under the nav bar (`.navigationBarDrawer(.always)`). It is local to Riwayat, which already holds every transaction (HIG: inline search filters the content it sits beside). It is not a search tab, because Home and Analisis have nothing else to search.
  - **Scope is always shown:** the placeholder says what is searched ("Cari kategori, catatan, atau jumlah"), and the no-results text names the 13-month window. No scope bar or tokens, because D-053 says no filters.
  - **Results:** they stay grouped by month and day, newest first, which is the HIG's "categorize results". While a search is active, header totals add up only the matching rows, so the header always equals the rows under it.
  - **History never hides an entry:** its fetch has no upper date bound, so an entry dated in a later month (possible after a time-zone change, D-044) appears at the top instead of being invisible until that month comes. Home and Analisis stay bounded by month.
  - Kept as D-053 states: income-only days and months show just "+Rp…", never "Rp0". Day headers show the date ("Kamis, 19 Nov"), not "Hari ini" / "Kemarin".
  **Why:** the user asked for search that behaves the way iOS search is meant to. The independent review found exact matching too strict for typing, and found that the month-bounded fetch could hide an entry.
- **D-058 · 2026-11-20 · Phases 8 and 9 share one branch and one PR (exception to D-034, like D-052).** Requested by the user: "Finish phase 8 and 9 simultaneously in one branch with same pr". The branch is `feat/phase-8-9-retention-backup`. Phase 8 is built first, then Phase 9 on top, then one independent review covers both, then one fix round, the fast gate (D-056) and one PR. The user was away and asked the orchestrator to use its recommended answer for every scope question, so D-059 and D-060 are the orchestrator's calls, open to the user's change at review.
  **Why:** the user wants to move faster with fewer merge stops.
- **D-059 · 2026-11-20 · Phase 8 Retention scope (refines D-017, D-055).** The orchestrator's recommendations, taken on the user's instruction (D-058).
  - **When it runs:** on launch and whenever the app returns to the foreground. It is a no-op unless a transaction is dated before the raw window start (D-017, device-local time zone). There is no stored "last run" month, because the check is one indexed fetch with a limit of 1. "At most once per month" holds because only month changes move the window.
  - **One month at a time:** the oldest month that has raw transactions is rolled up and its transactions deleted in **one save**, so a crash leaves either the whole month raw or the whole month rolled up. The loop repeats until nothing is older than the window, so an app left closed for 3 months catches up on the next launch.
  - **Rollup rows:** one per (month, subcategory), with total, count and snapshots of name, emoji, kind and group (the existing `MonthlyRollup`). If a row for that month and subcategory already exists (e.g. after a restore), the new totals are **added** to it and the snapshots are refreshed.
  - **Reading old months (D-055):** one Core source answers "the totals of month X": raw transactions inside the window, rollups outside it. Analisis's "vs last month" and the 6-month chart, Home's card bar vs last month, and the subcategory detail's comparison all go through it, so no screen compares against a false Rp0.
  - **Yearly recap:** a **"Rekap tahunan"** row at the end of Analisis opens a recap with a year stepper ("‹ 2026 ›"), from the earliest year with data to the current year. The current year shows "sampai hari ini" (year to date), so the user does not wait until January 2027 to see one. Completed years are permanent (rollups + raw). Contents: pengeluaran and pemasukan totals, the Kebutuhan / Keinginan split, a 12-month bar chart (pengeluaran and pemasukan, the D-055 colours), and the ranked expense subcategories with totals. Neutral numbers only (D-022). There are no transaction rows, because purged months have none.
  - **Schema:** `KemanayaSchemaV1` may still change, because no device has real data until Phase 12 (Phase 3 note c).
  **Why:** a single atomic save per month is the simplest way to never lose or double-count money. The year-to-date recap gives value in the first year.
- **D-060 · 2026-11-20 · Phase 9 Backup, restore and CSV scope (refines D-019, D-020; Phase 1 spike deferred).** The orchestrator's recommendations, taken on the user's instruction (D-058).
  - **Spike deferred to Phase 12:** the Phase 1 bookmark spike needs real devices, so it runs during the Phase 12 install. To make that safe, Phase 9 ships **both** paths: the automatic folder backup (D-019) and the manual fallback (export a backup file through the share sheet / "Simpan ke File", import one with the file picker). If the bookmark fails on free signing, the manual path still works and only the automatic backup is switched off.
  - **Pengaturan tab now:** a fourth tab, **Pengaturan**, arrives in Phase 9 with only a **Cadangan & Ekspor** section: "Folder cadangan otomatis" (pick or change the folder, last backup time or the last error), "Cadangkan sekarang", "Ekspor cadangan", "Pulihkan dari cadangan" and "Ekspor CSV". Phase 10 adds subcategories and budgets to the same tab (D-048 said Phase 10).
  - **Backup file:** JSON with `formatVersion: 1`, `exportedAt` and the app version. It holds everything: subcategories (with pins and budgets), transactions, rollups and settings. The round trip is exact, including dates to the millisecond. The folder bookmark is stored in `UserDefaults`, not in the backup, because it only works on the device that made it.
  - **Writing:** `Kemanaya-backup.json`, with the old copy moved to `Kemanaya-backup.prev.json` first. The write is atomic and coordinated (`NSFileCoordinator`, for iCloud Drive). It runs 5 s after the last saved change (debounced, from SwiftData's did-save notification) and once on launch. A stale bookmark is refreshed. A failure is logged and shown in Pengaturan, never as an alert.
  - **Restore = replace everything:** after the user picks a file, a confirmation shows its date and how many transactions it has ("Ganti semua data dengan cadangan ini?"). One save deletes all current data and inserts the backup. Retention (D-059) runs right after, because an old backup can hold months that should be rolled up. A file with a newer `formatVersion` or bad content is refused with a message, and nothing changes.
  - **Fresh install (Phase 3 note a):** "fresh" means no transactions and no rollups (the seed doesn't count). Then Home's empty state shows a **"Pulihkan dari cadangan"** link to the same restore flow. Phase 11's onboarding may move it.
  - **CSV (D-020):** one file, `Kemanaya-transaksi-YYYY-MM-DD.csv`, holding the raw transactions in the window, oldest first. Columns: Tanggal (yyyy-MM-dd), Waktu (HH:mm), Jenis, Kelompok, Subkategori, Catatan, Jumlah (a plain integer, in rupiah). It uses RFC 4180 quoting, UTF-8 with a BOM (so Excel shows emoji and accents), and the share sheet. Rollups are not in the CSV; the yearly recap covers them.
  - **Backup safety (added after the Phase 8–9 review, 2026-11-20):**
    - **Fresh store:** a store with no transactions and no rollups never writes a backup. A seed-only file has no value, and writing one could replace a real backup after a reinstall.
    - **Backup found in a newly picked folder:** if the folder already holds a `Kemanaya-backup.json` that this install did not write, the first real write first renames it to `Kemanaya-backup-kept-YYYY-MM-DD.json`. It is never moved into `.prev`, where the next write would delete it.
    - **Before a restore:** when a folder is set and the store isn't fresh, the current data is saved first as `Kemanaya-backup-before-restore.json`, so a mistaken restore can be undone.
    - **After a restore:** the tabs are rebuilt, so no open screen holds a deleted record.
    - **Validation:** a backup is refused when an amount or budget is over the keypad maximum, a rollup's total or count is impossible, pins are duplicated, there are too many pins, or a hidden subcategory is pinned.
    - **CSV:** a field starting with `=`, `+`, `-` or `@` gets a leading `'`, so a spreadsheet never runs it as a formula.
  **Why:** shipping the fallback removes the spike's risk instead of waiting on it. Replace-all restore can't merge two histories wrongly. One CSV opens anywhere.
- **D-061 · 2026-11-20 · Phases 10 and 11 share one branch and one PR (exception to D-034, like D-058).** Requested by the user: "continue phase 10 & 11". The branch is `feat/phase-10-11-settings-polish`. Phase 10 is built first; the Si Naya artwork and app icon may be built in parallel with it (separate folders, D-030). Onboarding, empty states and English come after Phase 10, then one independent review of both phases, one fix round, and the Phase 11 full run (D-056): the whole UI suite and the screenshot tour on 26.5 and 18.6 with the light / dark / AX5 review. D-062 and D-063 are the orchestrator's calls under the user's standing instruction to take its recommendations and keep moving fast, open to the user's change at review.
  **Why:** the user wants fewer merge stops before the Phase 12 install.
- **D-062 · 2026-11-20 · Phase 10 Settings scope: subcategories and budgets (refines D-006, D-007, D-012, D-041, D-048, D-049, D-060).** The orchestrator's recommendations (D-061).
  - **Pengaturan layout,** top to bottom: **Anggaran** (budgets), **Subkategori**, **Cadangan & Ekspor** (D-060, unchanged), **Tentang** (app version, "Lihat pengenalan lagi" from Phase 11).
  - **Group budgets (D-010, D-041):** two rows, Kebutuhan and Keinginan, each showing its amount or "Belum diatur". Tapping one opens a sheet with the app's rupiah keypad, **Simpan**, and **Hapus anggaran** when one is set. Zero is not a budget: saving 0 clears it. The keypad maximum applies.
  - **Subkategori:** a "Kelola subkategori" row opens a list with a **Pengeluaran | Pemasukan** segmented control. Expenses show Kebutuhan and Keinginan sections; income is one list. Each row shows emoji, name, the budget when set, and a pin glyph when pinned. **Edit** mode drags to reorder within a section; the order is the add sheet's grid order. Hidden subcategories sit in a **Tersembunyi** section at the bottom, each with **Tampilkan** (unhide, not re-pinned, D-049). A "+" adds one.
  - **Editor sheet (add and Ubah):** emoji (one emoji, `SubcategoryRules.isValidEmoji`), name (one word, ≤ 10 characters, D-007, with a live counter and the reason when invalid), group (Kebutuhan / Keinginan, chosen when adding an expense subcategory and fixed afterwards, D-004; income has none, D-005), and a monthly budget for expense subcategories (optional, same keypad). **Simpan** is disabled until valid.
  - **Unique names:** a name may not match another subcategory's name of either kind, ignoring case and diacritics, so search, CSV and the recap never show two "Kopi" rows. A hidden one counts.
  - **Remove:** "Hapus subkategori" in the editor. With no transactions and no rollups, it is deleted after a confirmation. With any, it is **hidden** instead and the confirmation says so (D-006); hiding unpins it (D-049). A subcategory that is the last visible one of its kind or group can't be hidden or deleted, so the add sheet always has a tile.
  - **Renaming:** transactions follow the subcategory, so History and Analisis show the new name. Rollups keep their snapshot names (D-059), so the recap shows the old name for purged months.
  - **Card menu end state (D-012, D-048):** Home's long-press menu becomes **Lihat detail · Ubah · Lepas pin**; Ubah opens the same editor.
  - **Writes live in `Ledger`** (KemanayaCore) with Swift Testing coverage; the views only call them. Every write is one save, rolled back on failure.
  **Why:** one place for each setting, the D-007 rule enforced where names are typed, and no way to lose history (D-006) or leave the add sheet empty.
- **D-063 · 2026-11-20 · Phase 11 scope: onboarding, Si Naya, app icon, English, polish (refines D-022, D-023, D-040, D-056, D-060).** The orchestrator's recommendations (D-061).
  - **Si Naya:** a curious coin with eyes, drawn in SwiftUI shapes (no bitmaps) from the decoration tokens, with a few fixed moods (curious, calm, sleepy). It appears only on onboarding, empty states and the app icon (D-022), and never reacts to spending.
  - **App icon:** Si Naya on the brand violet, as 1024 px PNGs for the light, dark and tinted appearances, rendered from the same geometry. The generator is a throwaway script outside the repo; only the PNGs are committed.
  - **Onboarding:** three skippable pages on first launch, as a full-screen cover: (1) what Kemanaya answers, (2) pinned cards: tap to log, long-press for the menu, and the mini-bar legend (thick bar = this month, thin bar = last month, D-040), (3) Kebutuhan vs Keinginan and optional budgets, with **Mulai** and a secondary **Pulihkan dari cadangan** that opens the D-060 restore flow. A "seen" flag lives in `UserDefaults`; Pengaturan's "Lihat pengenalan lagi" shows it again. UI tests skip it unless a launch argument asks for it.
  - **Empty states:** Si Naya with one calm line on Home (no transactions this month), Riwayat (nothing in the window), search with no results and Analisis (no spending in the month). Home keeps the fresh-install "Pulihkan dari cadangan" link.
  - **English (D-023):** every string in the catalog gets an English translation, with Indonesian as the source. The fixed groups and kinds translate (Needs, Wants, Expense, Income). Subcategory names are user data and stay as entered, so the seed stays Indonesian. Amounts stay `Rp45.000` in both languages (D-016); dates follow the app language.
  - **Store that won't open (Phase 3 note b):** the `fatalError` becomes a non-destructive error screen that explains the problem, offers "Ekspor cadangan" when possible, and never deletes the store.
  - **Gate (D-056):** the full UI suite and the screenshot tour run once on 26.5 and 18.6, plus a short English pass, with the light / dark / AX5 review. Everything that breaks is fixed before the PR.
  **Why:** finish everything the user sees before the Phase 12 install, with the mascot kept to the places D-022 allows.
- **D-064 · 2026-11-20 · The store error screen offers two honest exports (refines D-063).** The orchestrator's call under D-061, open to the user's change at review.
  - A real "Ekspor cadangan" builds its JSON from the open store, so it can't run when the store won't open. The screen offers instead:
    - **Ekspor cadangan terakhir:** only when a backup folder is set. It shares a copy of that folder's existing backup file, which Pulihkan can use.
    - **Simpan salinan berkas data:** only when the database file exists. It shares copies of the raw store files (with `-wal` and `-shm`) and says plainly that this isn't a backup and can't be used with Pulihkan.
  - Neither option ever writes, moves or migrates the store. When neither is available, the screen says there is nothing to save and asks the user to reopen the app.
  - Search with no results shows Si Naya **curious**; the other empty states show **calm**.
  **Why:** only offer what can actually work, and give support a copy of the raw data without risking it.
- **D-065 · 2026-11-20 · English wording (refines D-023, D-063).** The orchestrator's calls under D-061, open to the user's change at review.
  - The tabs are Home / History / **Insights** / Settings. The groups are Needs / Wants and the kinds are Expense / Income. The tagline is "Where did my money go?". Kemanaya and Si Naya stay as they are.
  - **Sentence case** everywhere, matching the Indonesian source.
  - Keys that serve two meanings get split, so English can differ where it needs to:
    - Pengeluaran / Pemasukan as a segment or CSV value vs. a chart or recap caption ("Expenses").
    - Anggaran / Subkategori as a Settings section header vs. a label or CSV column.
  - Chart axis compact amounts follow the app language: `Rp250rb` / `Rp1,5jt` in Indonesian, `Rp250K` / `Rp1.5M` in English. Full amounts stay `Rp45.000` in both (D-016).
  - The CSV file name stays `Kemanaya-transaksi-<date>.csv` in both languages, so file names stay stable across a language switch.
  **Why:** natural English without changing the money format, and file names that don't depend on the device language.
- **D-066 · 2026-11-20 · Answers to the Phase 10–11 review's spec questions (refines D-022, D-060, D-062, D-063).** The orchestrator's calls under D-061 and the user's 2026-11-20 instruction to decide and batch-review later.
  - **Recap names:** the year recap labels every subcategory that still exists with its current name; snapshot names show only for deleted subcategories (Phase 8 behaviour). This replaces D-062's "old name for purged months" wording.
  - **Si Naya on the store error screen is allowed:** that screen counts as an empty state (sleepy mood, D-063).
  - **Restore refuses files that break D-062's rules** rather than repairing them: an invalid name (spaces, length, empty), duplicate names after case/diacritic/width folding, an invalid emoji, or a kind/group with no visible subcategory. Refused the same way as the existing pin checks (adds to D-060's validation list).
  - **Hidden subcategories without history** keep only Tampilkan; the user unhides first, then deletes. No extra path for a case only a hand-made file can produce.
  - **Pulihkan from onboarding** marks onboarding seen even if the file picker is cancelled; Home keeps its own restore link.
  - **Store error "Ekspor cadangan terakhir"** shows only when the backup file actually exists in the folder (a read-only check at launch), per D-064's "only offer what works".
  **Why:** keeps behaviour already tested, keeps restore strict and simple, and never offers a button that can't work.
- **D-067 · 2026-11-21 · Add sheet: a real keypad keyboard and an explicit Simpan (supersedes D-013's tap-to-save; refines D-043, D-044, D-047).** Approved by the user.
  - **One keyboard at a time:** the rupiah keypad becomes the amount field's input view, a real keyboard, so iOS swaps it with the system keyboard when focus moves between the amount and Catatan. The two never overlap, and both are dismissed the same way (drag the list, or tap outside). Tapping the amount brings the keypad back.
  - **When it shows:** focused on open when adding ("+" and the pinned-card quick log). Not focused when editing (Ubah), so the whole grid is visible. With the keypad dismissed, every subcategory is visible.
  - **Tapping a subcategory only selects it** (single selection, highlighted, named next to the amount per D-047). **Simpan** (top right) saves in every flow: "+", quick log and Ubah. The add flow becomes ≤ 4 taps: "+" → amount → subcategory → Simpan.
  **Why:** the user found the keypad and the note keyboard inconsistent and overlapping, and a tap that saves at once logs mistaken taps.
- **D-068 · 2026-11-21 · Home rework: compact hero, needs | wants columns, income rows, compact cards (supersedes D-012's 2×3 grid, max 9 and mini-bars; refines D-040, D-048, D-050).** Approved by the user.
  - **Hero = stacked rows:** title row "November 2026 ›", the month's total spending ("terpakai bulan ini"), then one row each for Kebutuhan and Keinginan: spent / group budget with a bar, or, without a group budget, the group's share of spending. No income, sisa or savings rate on Home. Existing text sizes stay. The empty month keeps the calm Si Naya line and the restore link.
  - **Hero tap (Apple pattern, not a tab switch):** the whole hero is one button with a chevron and pushes **this month's transactions** inside Home's navigation stack, newest first, grouped by day; tap = Ubah, swipe = Hapus, as in Riwayat. The Riwayat tab stays the full 13-month history with search.
  - **Columns:** Kebutuhan pins in a left column, Keinginan pins in a right column, each in pin order; the columns can differ in length. A group with no pins shows a dashed "＋ Pin" placeholder that opens Atur. At accessibility text sizes the columns stack, needs first.
  - **Income:** pinned income subcategories are thin full-width rows ("💼 Gaji ……… Rp8.500.000") in their own block below both columns, in pin order; a tap is a quick log.
  - **Compact card, three lines:** emoji + name, this month's total, then either a thin budget bar with "sisa Rp…" / "lewat Rp…" (neutral, D-022) when the subcategory has a budget, or "Bulan lalu Rp…" without one. The two comparison bars and the budget ring are removed; the comparison with last month stays in Lihat detail.
  - **Pin limits:** 6 Kebutuhan, 6 Keinginan, 3 Pemasukan. The Atur sheet has Kebutuhan / Keinginan / Pemasukan sections and reorders within a section. Restore validation (D-060) checks the per-group limits. The default pins already split 3 / 3.
  **Why:** the hero pushed the cards below the fold, the two bars were unclear, and the app's point is where money goes in needs vs wants; income is a bonus.
- **D-069 · 2026-11-21 · Budgets are set where they are seen (refines D-041, D-048, D-062).** Approved by the user.
  - **Atur sheet:** each section header carries its group budget ("Kebutuhan · Anggaran Rp4jt ›" or "Atur anggaran ›"); each subcategory row shows its budget or "—", and tapping the row opens the budget keypad (D-062's sheet). The pin toggle stays on the row.
  - **Card menu:** Lihat detail · **Atur anggaran** · Ubah · Lepas pin.
  - **Hero:** when a group has no budget, the hero shows a quiet "Atur anggaran" link that opens the Atur sheet.
  - Pengaturan keeps its budget rows.
  **Why:** the user could not find how to set a subcategory budget; three levels deep in Pengaturan is not intuitive.
- **D-070 · 2026-11-21 · Analisis: top 5, a full breakdown screen, one income line, no sisa (supersedes D-009's sisa and savings rate and D-050's negative-rate note; refines D-051, D-055).** Approved by the user.
  - **Rincian:** the donut, then the **top 5** subcategories by amount spent (the donut's order), then **Lihat semua ›**, which pushes a dedicated screen with the donut and the full ranked list. Rows still open the subcategory detail. Nothing is added above the donut.
  - **Income line:** one line between Rincian and Tren: "Pengeluaran Rp4,25jt dari pemasukan Rp8,5jt", for the selected month.
  - **Sisa bulan ini, rasio tabungan and "Pengeluaran melebihi pemasukan" are removed** from the app.
  - **No income filter:** "Semua" would stop meaning all, and one or two income sources make a donut that says nothing.
  **Why:** keep the donut the highlight, reach Tren, 6 bulan and Rekap tahunan without a long scroll, and show income only as context for spending.
- **D-071 · 2026-11-21 · Onboarding fits the screen on every target phone (refines D-063; amends D-045).** Approved by the user.
  - Every onboarding page fits without scrolling on **iPhone 13, iPhone 15, iPhone XR, iPhone 16 Pro and iPhone 17 Pro**, at every standard text size up to XXXL. Accessibility sizes and Display Zoom may scroll; text is never truncated or shrunk.
  - Checked on **iPhone 13 and iPhone XR simulators (iOS 18.6)** in addition to D-045's two; iPhone 13 (390×844 pt) is the smallest. The user confirms on the real phones.
  - Page 2 explains the D-068 compact card instead of the two-bar legend.
  **Why:** the user's phones must show each page whole.
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
  - Devices: **iPhone XR (iOS 18 max)** and **iPhone 15 (iOS 26+)**. *(iPhone 13 added by D-046.)*
  - System chrome gets Liquid Glass automatically on iOS 26+ and the classic look on iOS 18.
  - Custom glass goes through **one design-system modifier**: Liquid Glass on iOS 26+, `.ultraThinMaterial` fallback on iOS 18. No scattered `#available` checks in feature code.
  **Why:** user wants to run on the XR too.
- **D-046 · 2026-11-18 · The wife's iPhone 13 is a target device too (extends D-025).** Approved by the user. Phase 12 installs on the iPhone 15, the iPhone XR and the iPhone 13. Like the others, the iPhone 13 has its own unsynced data (D-015) and needs a re-sign from Xcode every 7 days (D-024).
  **Why:** the user's wife will use the app on her iPhone 13.
- **D-026 · 2026-11-16 · Stack: SwiftUI + SwiftData + `@Observable`. No third-party dependencies.** Feature folders (`Features/AddTransaction`, `Features/Home`, …) plus a shared `DesignSystem/`.
- **D-027 · 2026-11-16 · Tests: Swift Testing for domain logic** (aggregation, date bucketing, rollup/purge, IDR formatting, backup encode/decode); XCUITest for the add flow.
- **D-028 · 2026-11-16 · Xcode project uses file-system-synchronized groups** (Xcode 16+ format); generated by Claude, fallback = user creates via Xcode template. Shared `Config/*.xcconfig`, following Fuely's layout.
  **Why:** new files need no `project.pbxproj` edits → no merge conflicts between subagents.
  - Signing: committed `Config/Signing.xcconfig` (`DEVELOPMENT_TEAM =` + `#include? "Signing.local.xcconfig"`); the real team id lives only in gitignored `Config/Signing.local.xcconfig`.
  - Build settings carried over from Fuely: `CODE_SIGN_STYLE = Automatic`, `GENERATE_INFOPLIST_FILE = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`, `STRING_CATALOG_GENERATE_SYMBOLS = YES`, `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`, `TARGETED_DEVICE_FAMILY = 1`, `IPHONEOS_DEPLOYMENT_TARGET = 18.0`, Swift 6 language mode.
  - No app extensions: free signing allows only 10 App IDs per 7 days.
- **D-029 · 2026-11-16 · Simulators:** iPhone 17 Pro (iOS 26.5) and iPhone 16 Pro (iOS 18.6) for every slice. ~~Also check iPhone SE 3rd gen (iOS 18.3, smallest screen) and iPhone Duo (iOS 27.1, adaptive layout) before a phase closes.~~ SUPERSEDED by D-045. Behaviour bugs often appear only on the oldest runtime — test iOS 18 every time.
- **D-045 · 2026-11-18 · No iPhone SE or iPhone Duo checks (amends D-029).** Approved by the user. The gate runs on iPhone 17 Pro (iOS 26.5) and iPhone 16 Pro (iOS 18.6) only, at phase close too. *(Onboarding fit also checks iPhone 13 and XR, D-071.)*
  **Why:** the checks took too long for devices nobody uses. The app runs on the user's iPhone XR and iPhone 15, and the user's wife uses an iPhone XR and an iPhone 13. Those are all 6.1" screens on iOS 18 or later, close to the two gate simulators.
- **D-036 · 2026-11-16 · Pure logic lives in a local Swift package `KemanayaCore`** (`swift-tools-version: 6.0`, `.iOS(.v18)`) with its own Swift Testing target: SwiftData models, formatting, month bucketing, aggregation, rollup/purge, backup/CSV encoding, copy strings logic. The app target holds views, design system and wiring only. Test-first where practical.
  **Why:** proven in Fuely; keeps logic testable and the app target thin.

## Workflow

- **D-030 · 2026-11-16 · Claude is the orchestrator; feature work goes to subagents.** One subagent at a time; two in parallel only when they touch separate feature folders and no shared files (data model, design system, project file).
- **D-031 · 2026-11-16 · Builds go through the Xcode MCP (`xcrun mcpbridge`) first;** `xcodebuild` / `simctl` only for what the MCP cannot do — log the reason here when that happens. The orchestrator runs every verification build, one at a time. *(Launch command amended by D-038.)*
  - Fallback log:
    - 2026-11-16 · `xcodebuild build-for-testing` (once): to confirm the `-Wincompatible-sysroot` linker warning was specific to the MCP. Plain `xcodebuild` built with zero warnings (see D-038).
    - 2026-11-16 · `xcrun simctl` for appearance, Dynamic Type size and screenshots: the MCP's device-interaction tools accept only the iOS 27.1 simulator, so they can't drive the iOS 26.5, 18.6 or 18.3 runtimes.
    - 2026-11-17 · `xcrun simctl uninstall` + `get_app_container`: the MCP can't uninstall an app or locate its data container, and Phase 3 had to prove a fresh-install launch seeds the on-disk SwiftData store exactly once on iOS 18.6.
    - 2026-11-18 · `xcodebuild test` by the Phase 4 fix-round subagent on 18.6 / 18.3: it was told not to change the shared Xcode active destination. `xcrun xcresulttool export attachments` for the gate screenshots: the MCP test tools don't expose XCTest attachments, and the MCP device tools only drive iOS 27.1.
    - 2026-11-20 · `xcodebuild build-for-testing` / `test` (Fast plan, fresh DerivedData in the scratchpad) by the Phase 10–11 fix-round subagent: Xcode wasn't running, so the MCP had no workspace open. The orchestrator then reopened the project and re-verified through the MCP.
    - 2026-11-21/22 · `xcodebuild test -testPlan Full -only-testing:…` (scratch DerivedData) by the Phase 11.5 subagents for UI tests and screenshot runs: the MCP refuses UI tests ("KemanayaUITests isn't a member of the active scheme"), and its device tools only drive iOS 27.1. `xcrun simctl create` for the iPhone 13 and iPhone XR simulators (iOS 18.6) that D-071 needs. Builds and unit tests stayed on the MCP.
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
- **D-042 · 2026-11-17 · `.gitattributes` marks `.claude/**` as `linguist-vendored`,** so GitHub's language bar counts only the app's code. The hook stays committed and working. Approved by the user.
  **Why:** the 14 KB guardrail hook made the repo show as mostly Shell.
