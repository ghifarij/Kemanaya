# Kemanaya — Progress

Status keys: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked.
Each phase is one branch + one PR (D-034) and passes the quality gate (D-032) before it is marked done.
Owner `user` = the user does it (Claude may teach/review); otherwise Claude/subagents.

## Phase 0 — Setup
- [x] Design interview (grilling) — all decisions in `DECISIONS.md` (2026-11-16)
- [x] Folder, `git init`, `CLAUDE.md`, `documents/`, `.mcp.json` (2026-11-16)
- [x] Initial commit on `main` (docs only) (2026-11-16)
- [x] **user** — create public GitHub repo `ghifarij/Kemanaya`, push `main`; squash-only merges + auto-delete branches (D-039) (2026-11-17)
- [ ] **user** — branch protection on `main` (require PR + passing CI)
- [x] Local git guardrail hook blocking pushes to `main` (git-guardrails skill) — reviewed by a subagent and fixed; table test 314/315 (`reset --keep` allowed on purpose) (2026-11-17)
- [x] Scaffold Xcode project: synchronized groups, `Kemanaya` / `KemanayaTests` / `KemanayaUITests`, local package `KemanayaCore` (D-036), `Config/Signing.xcconfig` + gitignored `Signing.local.xcconfig` (D-028), iOS 18.0 min, bundle id — reviewed by a subagent, no blocking issues (2026-11-17)
- [x] Verify clean build + empty test run via Xcode MCP — zero warnings, 3/3 tests green on iPhone 17 Pro (26.5), iPhone 16 Pro (18.6) and iPhone Duo (27.1); 3/3 green on iPhone SE (18.3); light / dark / AX5 screenshots reviewed on all four (2026-11-17)

## Phase 0.5 — CI (owner: user)
- [ ] **user** — check Xcode versions on GitHub macOS runner
- [ ] **user** — `.github/workflows/ci.yml`: SwiftLint → build → unit tests (Claude reviews)
- [ ] **user** — `.swiftlint.yml`

## Phase 1 — Spike: backup bookmark (D-019)
_Deferred by the user on 2026-11-17: build the app first (Phases 2–5), run the spike later. It must still pass before Phase 9 (backup)._
- [ ] Throwaway screen: pick folder → save bookmark → write file → relaunch → write again
- [ ] Verified on iPhone 15 (free signing)
- [ ] Verified on iPhone XR (iOS 18)
- [ ] Verified after delete + reinstall → restore works
- [ ] Record result in DECISIONS (confirm D-019 or switch to manual fallback)

## Phase 2 — Design system (D-021, D-022, D-025)
_Done 2026-11-17 on `feat/phase-2-design-system` (stacked on `fix/hook-false-positive`; rebase onto `main` after PR #2 merges). Notes for later: `KeypadKey.Kind` moves into KemanayaCore with the Phase 4 keypad reducer; check in Accessibility Inspector that VoiceOver offers the card context menu before Phase 5; Phase 5's real card menu must use catalog strings._
- [x] Color tokens (light/dark/increased contrast, AA-checked): 15 color sets, contrast enforced by `TokenContrastTests`, D-040 (2026-11-17)
- [x] Typography (SF Pro Rounded Heavy amounts, monospaced digits): `Font.amountHero/Large/Medium/Small`, `.brandTitle` (2026-11-17)
- [x] Glass modifier with iOS 18 fallback: `kemanayaGlass(in:interactive:)`, the only `#available`; material fallback checked on 18.6 (2026-11-17)
- [x] Components: subcategory card, amount text, split bar, keypad key, plus `RupiahFormatter`, `ContrastRatio`, `SplitShare`, `MonthComparison` in KemanayaCore. Temporary `DesignGalleryView` is the root (launch arg `-gallerySection cards|split|keypad|glass|type|colors` for screenshots). Independent review: no blocking findings; all 8 nits fixed (HC `surface` now differs from the background, `CategoryTint` nonisolated, dead API removed, translator comments). Gate on 26.5 + 18.6: zero warnings, 44/44 tests, light / dark / AX5 / Increase Contrast screenshots reviewed (2026-11-17)

## Phase 3 — Domain & data
_Done 2026-11-17 on `feat/phase-3-domain-data`. The user chose to keep `KemanayaCore` iOS-only (no `.macOS` platform, D-036 unchanged), so core tests run through the Xcode MCP on a simulator. IDR formatting already shipped in Phase 2 (`RupiahFormatter`). Notes for later from the review: (a) Phase 9 must decide, and record in a D-entry, how D-019 detects a "fresh install" now that the seed runs on first launch, e.g. "no transactions and seed untouched", or restore replaces all subcategories. Seeded subcategories have fixed UUIDs so a restore can upsert onto them. (b) Before Phase 12 puts real data on devices, replace the `fatalError` on a store that won't open with a non-destructive error screen. (c) `KemanayaSchemaV1` is frozen once a device has real data; later model changes need V2 plus a migration stage._
- [x] SwiftData models: `Subcategory`, `MoneyTransaction` (named so it doesn't clash with `SwiftUI.Transaction`; stable `id`, copies kind/group for predicates), `MonthlyRollup` (`#Unique` month + subcategory), `AppSettings` (group budgets); subcategory budgets on `Subcategory` (D-041). `KemanayaSchemaV1` + migration plan, `#Index` on date (2026-11-17)
- [x] Seed data (D-008) with fixed UUIDs + default pins (D-012), idempotent; verified on a fresh install on iOS 18.6 (44 rows, 6 pins, seeded once) (2026-11-17)
- [x] IDR formatting, month bucketing (Gregorian, time zone injected), aggregation (`MonthSummary`, sisa + savings rate, `BudgetProgress` at both levels), `Ledger` fetch layer + Swift Testing. Independent review: nothing blocking; 6 should-fix + all nits fixed. Gate on 26.5 + 18.6: clean build, zero warnings, 139/139 tests, on-disk store checked; no UI change, gallery screenshot unchanged (2026-11-17)

## Phase 4 — Add transaction (D-013, D-043, D-044)
_Done 2026-11-18 on `feat/phase-4-add-transaction`; follow-up fixes (a) and (c) below go in a separate `fix/` branch._

**Resume here (Phase 4):**
1. [x] Implementation by a subagent (keypad reducer, `Ledger+Writes`, add/edit sheet, temporary month list root, UI tests). 191/191 tests passed and zero warnings on 26.5 and on 18.6, which the orchestrator verified.
2. [x] Independent review: 1 blocking finding (a failed save isn't rolled back, so a retry duplicates), 6 should-fix, 9 nits. The user's answers became D-044 (no chips; dates up to the end of the current month; tapping the highlighted tile saves; "Ubah").
3. [x] Fix round by the implementer subagent (2026-11-18): D-044 plus B1, S1–S6 and nits N1–N5 and N7–N9.
   - Its own run on iPhone 17 Pro (26.5): 0 warnings and 208/208 tests (core 185 · app 17 · UI 6). Its last edit, a doc comment in `KemanayaUITests.swift`, was not rebuilt.
   - **Chips:** removed.
   - **`AddDraft` (new, KemanayaCore):** holds the sheet's rules.
   - **`KeyResult`:** the cap haptic plays only on a rejected key.
   - **Saves:**
     - `Ledger+Writes` rolls back a failed save. An update saves its old values first and restores them, because `rollback()` doesn't undo changed values on an already-saved model.
     - The tests inject a failing save through an internal `Ledger.init(context:timeZone:save:)`.
   - **Dates:**
     - `RetentionWindow.entryLimit` = the first instant of next month.
     - If the date is untouched, a new entry gets the save time and an edit keeps its date.
     - A picked day gets the current time of day (new) or the original time (edit).
   - **Delete:** a `PendingDelete` snapshot, delete by id, and the dialog attached to each row. On iOS 26.5 it now shows as a bottom action sheet with **Batal**.
   - **File moves:** `DomainNames.swift` became `DesignSystem/Copy/DisplayNames.swift` (Gregorian date formatting lives there), and previews and `PreviewStore` are behind `#if DEBUG`.
   - **New judgment calls:**
     - A hidden preselected subcategory gives no selection; the sheet opens on that kind's grid.
     - The alert copy "Belum bisa disimpan" and "Belum terhapus".
     - The DatePicker is forced to the Gregorian calendar.
   - **Not checked:** the SE simulator layout (only the preview canvas), and the delete dialog on iOS 18.
4. [~] Orchestrator gate:
   - [x] zero warnings (full recompile) and tests green on iPhone 17 Pro (26.5) and iPhone 16 Pro (18.6): 208/208 on both (2026-11-18). One 26.5 run failed with an incomplete result bundle (infrastructure, no test failure); the rerun was green.
   - [x] Re-review of the fix round (2026-11-18): non-blocking. Should-fix: no test retries a failed add with a real save, so a duplicate through the inverse `Subcategory.transactions` is unchecked. Nits: orphan move on a failed update, `keeping:` widens only the lower bound, `validate` has no lower bound, unused `PendingDelete.emoji`, a wrong popover comment, "Edit" left in the gallery and a `SubcategoryCard` comment.
   - [x] Fix round 2 via a subagent (2026-11-18):
     - **A1 retry test:** it failed before the fix. After a failed add + `rollback()`, `makan.transactions` still held the discarded row in memory; on disk there was no duplicate. Fix: `Ledger+Writes` unlinks the new row with `detachFromSubcategory()` before rolling back.
     - **A2:** a failed update restores the whole subcategory link, including a nil one (orphans).
     - **A3:** `RetentionWindow` `keeping:` widens both bounds, so an untouched edit keeps its exact date.
     - **A4:** adds enforce the D-017 window start (new `TransactionError.dateBeforeRawWindow`, alert copy in the catalog); updates may keep an existing date.
     - **A5–A7:** done (`PendingDelete.emoji` removed, dialog comment fixed, "Ubah" in the gallery and the `SubcategoryCard` comment).
     - **Tour:** `KemanayaUITests/ScreenshotTourUITests.swift` has `testTourLight/Dark/AX5`, about 100 s / 100 s / 200 s on 26.5. Attachments are named `<variant>-<NN>-<state>`, plus `ax5-06b-month-rows-bottom`. New identifier `add.scroll` on the sheet's scroll views.
     - The subagent's own run on 26.5: 0 warnings, 219/219 tests. **Not verified by it:** the final tour on 18.6 (an earlier AX5 run there failed on stray synthesized taps).
     - **Findings to act on:**
       - (a) `ax5-08` on 26.5: the delete dialog is a narrow popover anchored to the row, breaking words mid-word ("transak/si", "Rp18.00/0"). iOS 18 shows an action sheet with Batal. This needs a fix, e.g. present it from the list rather than the row.
       - (b) On iOS 18, synthesized scroll gestures sometimes fired a tile or key. In add mode a tile tap saves, so check on a real XR that a swipe over the grid can't save by accident.
   - [x] Orchestrator gate after fix round 2: 26.5 build after a forced recompile, 0 warnings (2026-11-18).
     - 26.5: **219/219 passed**, no runtime warnings (result bundle `Test-Kemanaya-2026.11.18_21-37-23`). The MCP task reported "Failed to retrieve the requested log section"; that is a bridge log error, and the bundle itself is complete and green.
     - 26.5 tour reviewed (light / dark / AX5, 25 shots), with these findings:
       - (a) confirmed: in `ax5-08` the delete popover breaks words mid-word. In light and dark it is a narrow popover anchored to the row, with blurred ghost pills beside "Hapus".
       - (c) new: the edit sheet (`07`) opens on the Kebutuhan grid. The selected tile (Kopi, Keinginan) is off-screen, so the user can't see what is selected.
       - (d) note: in AX5 on 26.5, scrolled tiles and keys show faded under the sheet title. This is the system scroll-edge effect, so we leave it.
     - 18.6: **219/219 passed** (2026-11-18). Tour reviewed (light / dark / AX5, 24 shots).
       - The material fallback is correct, and the toolbar gets a solid background when scrolled.
       - The delete dialog is a bottom action sheet with **Batal** and wraps cleanly in AX5, so (a) affects only 26.5.
       - (c) also shows on 18.6.
       - Row times follow each simulator's 12/24-hour setting ("9.45 PM" on 26.5, "21.54" on 18.6), which is correct.
     - **Next:** send one brief to the implementer subagent:
       1. (a) Present the delete confirmation so iOS 26 shows it as a sheet or alert, not a popover anchored to the row. For example, attach it to the list instead of the row, or use `.alert`. It must keep D-043's text naming the amount and subcategory.
       2. (c) The edit sheet scrolls its grid to the selected tile when it opens.

       Then re-gate on 26.5 + 18.6 and re-shoot `07` and `08`.
   - [x] screenshots reviewed in light / dark / AX5 of the month list (empty and with rows), the add sheet, the edit sheet, the delete dialog, and the note-field focus with the keyboard up, on 26.5 and 18.6. Then fix (a) via a subagent and re-shoot `08`.
   - ~~iPhone SE (18.3) layout of the sheet, plus a Duo check~~ dropped by the user (D-045)
5. [x] D-037 check, commit, push, PR (2026-11-18). The user chose to merge Phase 4 now. (a) and (c) follow in a separate `fix/` branch, which goes through the same gate and its own PR.
   - Defaults the user didn't object to; mention them in the PR: the 12-digit cap (input past it is ignored, with a warning haptic), tiles disabled at 0, switching kind keeps the amount and the selection, and hidden subcategories stay editable for existing transactions.

- [x] Rupiah keypad (no chips, D-044), subcategory grid, optional note/date
- [x] Edit / delete via swipe
- [x] UI test for the add flow, plus the screenshot tour

### Phase 4 follow-up — branch `fix/phase-4-delete-dialog-edit-scroll`
_PR #6 merged 2026-11-18. Started 2026-11-19._
- [x] (a) delete confirmation shows as a sheet/alert on iOS 26, not a row-anchored popover (D-043 text kept) (2026-11-19)
  - A list-level `confirmationDialog` was still a 240pt popover on 26.5, so the subagent switched to an `.alert` attached once to the list. It shows the same text, **Hapus** (destructive) and **Batal**.
  - On iOS 18 it is now a centred alert instead of the bottom action sheet, so both OSes match.
- [x] (c) edit sheet scrolls its grid to the selected tile on open (2026-11-19)
  - `ScrollViewReader` + `scrollTo(id, anchor: .center)` runs once on the first grid load, with no animation. Switching kind doesn't jump.
  - A hidden preselected subcategory still gives no selection and no scroll.
  - **Open question for the user:** in AX5 the whole sheet scrolls, so centring the tile pushes the amount and keypad off-screen.
  - New UI test `testEditOpensWithTheSelectedTileInView`. Tour `07` asserts that Kopi is hittable; `08` asserts **Batal**.
- [x] Gate on 26.5 + 18.6 (zero warnings, tests green), re-shoot tour `07` and `08` in light / dark / AX5 (2026-11-19)
  - Orchestrator: forced recompile of the changed files, zero warnings, **220/220** on iPhone 17 Pro (26.5) and iPhone 16 Pro (18.6).
  - Reviewed all 12 `07` / `08` shots: the alert wraps on whole words in AX5 on both OSes, and Kopi is in view in every variant.
- [x] D-037 check, commit, push, PR (2026-11-19)
- [x] D-047 (approved 2026-11-19): label of the selected subcategory next to the amount. At large text sizes, open at the top with no scroll to the tile. Added to PR #7 (2026-11-19).
  - Done via a subagent: a "☕ Kopi" chip under the amount on the tile's tint (`add.selected`, VoiceOver "Dipilih: Kopi"); `scrollingLayout` no longer scrolls to the tile.
  - Orchestrator gate: forced recompile, 0 warnings and **220/220** on 26.5 + 18.6 (one 26.5 run first failed with an incomplete result bundle, an infrastructure error; the rerun was green). `07` shots reviewed in light / dark / AX5 on both OSes.
  - Not checked: a very long user-made subcategory name (truncation), VoiceOver on a device.

## Phase 5 — Home (D-012, D-009, D-010, D-041, D-047, D-048)
_Done 2026-11-19, merged as PR #9 (Phase 5 alone; see D-052's update)._

**Resume here (Phase 5):**
0. [x] Branch `feat/phase-5-home`, rebased onto `main` after PR #7 merged (2026-11-19). PR #7 merged **without** the D-047 commits (pushed after the squash-merge), so they went to PR #8 (`fix/phase-4-subcategory-label`, merged 2026-11-19). This branch now sits on `main` after #8; it holds no commits of its own yet. The worktree `../Kemanaya-phase5` was removed on 2026-11-19 and its uncommitted work moved to the main checkout, so Phase 5 is built here now.
1. [x] Implementation by a subagent (2026-11-19). Its own runs: 26.5 **256/256** after a forced recompile, 0 warnings; 18.6 256/256 before its last UI-helper change, then HomeUITests + tours 10/10. New: `HomeOverview`, `Ledger+Pins`, `PinError` (core); `Features/Home/` (HomeView, MonthSummaryCard, PinManagerSheet), `BudgetMeter`, `CurrentMonthTracking`, `DebugSample` (`-debugSample budgets|transactions|full`, only with `-inMemoryStore`); `HomeUITests` (7); tour extended to shots 01–14. Test containers are now created under a lock (a Core Data crash in parallel creation).
   - **Open judgment calls for the user:** empty state = no transactions *this month* (cards stay); placeholder when no pins; Riwayat keeps its own "+"; copy ("Catat cepat", "Rasio tabungan", "Belum ada pemasukan", "Atur kartu", "Selesai", unpin/pin failure alerts); hidden pinned subcategories don't count toward 9; tab icons `house` / `list.bullet`; over budget shows "Lewat Rp…" in the group colour, no red.
   - **Not verified:** VoiceOver actions (card menu, Atur up/down), dragging a newly pinned row, landscape, Increase Contrast, devices.
   - Fallbacks (D-031): `xcrun xcresulttool` to export attachments and test results (the MCP doesn't expose attachments).
   Brief = D-009, D-010, D-012, D-021, D-022, D-025, D-041, D-044, D-047, D-048, plus the notes below.
   - Native tab bar **Beranda** · **Riwayat**. Riwayat = the current `MonthListView`. Home's toolbar has "+".
   - Pinned card grid from `Ledger` pinned subcategories (max 9). Tap = quick add with the subcategory preselected (D-044: save with Simpan or by tapping the highlighted tile; D-047 label). Long-press menu = **Lepas pin** only.
   - Month total, sisa + savings rate (D-009), Kebutuhan vs Keinginan `SplitBar`, card total + tiny bar vs last month (`MonthComparison`).
   - Budget progress (group on Home, subcategory on the card) only when a budget is set. A DEBUG launch argument seeds budgets for tests and screenshots.
   - **Atur** sheet: pin toggles and drag-to-reorder, refuses a 10th pin with a note.
   - Never celebrate spending (D-022). Strings in the catalog, Indonesian first. Phase 2 note: check that VoiceOver offers the card context menu.
   - Extend the screenshot tour with Home states (empty, with data, with budgets, Atur sheet).
2. [~] Independent review by a second subagent → fix round.
   - [x] Review (2026-11-19): nothing blocking.
     - **S1:** hidden pins keep their old `pinOrder` and can tie with visible pins after a renumber (it can't happen until Phase 10 can hide subcategories).
     - **S2:** a time-zone change within the same month doesn't rebuild Home's or Riwayat's `@Query` date ranges.
     - **Nits:**
       - N1: a generic `"%@, %@"` catalog key in SubcategoryCard.
       - N2: the "Belum tersimpan" comment is reused for pin failures.
       - N3: `cardValue` is read once without waiting, which can race.
       - N4: the reorder-drag UI test relies on coordinates.
       - N5: PinManagerSheet repeats the sectioning that `Ledger.gridSections` already does.
     - Spec questions went to the user. Answers became D-049 (hiding unpins) and D-050 (Riwayat keeps "+", over budget stays in the group colour, note under a negative savings rate). Also accepted: the empty state means no transactions this month, with cards still showing.
   - [x] Fix round via a subagent (2026-11-19): D-049 (`Ledger.hide`/`unhide`; pins counted and renumbered across all subcategories), D-050 (`MonthSummary.isSavingsRateNegative` + note), S2 (`CurrentMonth` tracks the time zone too), N1–N5 (`SubcategorySection.sections(from:kinds:)` in Core). The subagent's runs: 0 warnings, **264/264** on 26.5 and 18.6. Its judgment calls: the note follows "spending > income" even when the rate rounds to 0%; no defensive hidden filter on pins (D-049 guarantees it).
3. [~] Orchestrator gate. Per D-052, it runs while Phase 6 is built on the same branch.
   - [x] 26.5: forced recompile (140 compile tasks), **0 warnings** (2026-11-19).
   - [x] 26.5 tests: **264/264** (2026-11-19; 37 "not run" were Phase 6 tests added during the run). [x] 18.6: a frozen copy of b52a837 in the scratchpad, its own workspace and DerivedData, forced recompile, **0 warnings**. [x] 18.6 tests: **264/264** (2026-11-19). · [ ] tour reviewed in light / dark / AX5 (at the combined gate, together with Phase 6's shots).
4. [x] D-037 check (only the existing bundle ID; no personal data or screenshots), commit (2026-11-19). The PR is combined with Phase 6 (D-052).

- [ ] Pinned cards grid (tap = quick add, long-press menu)
- [ ] Month total, sisa + savings rate, Kebutuhan vs Keinginan split bar, budget progress
- [ ] Pin management

## Phase 6 — Breakdown & Trend (D-014, D-051)
_Done 2026-11-19 on `feat/phase-6-analisis` (from `main` after #9); PR opened for the user to merge._

**Resume here (Phase 6):**
1. [x] Implementation by a subagent. Brief = D-009, D-012, D-014, D-017, D-022, D-023, D-025, D-036, D-041, D-043, D-044, D-050, D-051. Core first (month stepper bounds, breakdown ranking and shares, daily and weekly buckets, 6-month series) with Swift Testing, then the Analisis tab, the subcategory detail and "Lihat detail" in the card menu. Use the DEBUG sample data for screenshots. Extend the tour with Analisis states (empty, with data, filtered, detail, Mingguan, AX5).
   - Done 2026-11-19. Core `Analysis/` (ExpenseFilter, AnalysisMonthRange, Breakdown with largest-remainder %, SpendingTrend Mon–Sun weeks clipped to the month, MonthlyFlowSeries, SubcategoryDetail, `RupiahFormatter.compact`). App `Features/Analysis/` (AnalysisView, MonthStepper, BreakdownSection, TrendSection, SubcategoryDetailView), Analisis tab, Lihat detail, shared `TransactionActions`, `ChoiceChips`, new token `pemasukanChart`. Tour shots 15–20.
   - Subagent runs on 26.5: 0 warnings, unit tests **302/302**, AnalysisUITests 4/4, tours light / dark / AX5 passed (before D-054). Nothing on 18.6.
   - Judgment calls: the 6-month chart ignores the group filter (grey pengeluaran, green pemasukan), the dark-mode lime `pemasukanChart`, a native large title on Analisis, the filter above the donut, axis labels capped at 18 pt at AX5, one VoiceOver element per month.
2. [x] Independent review (2026-11-19): nothing blocking.
   - **Should-fix:**
     - S1: pengeluaran and pemasukan bars differ only in hue (1.08:1).
     - S2: the six-month chart's VoiceOver elements overlap (wrap them in an HStack).
     - S3: month titles format in the device's live time zone (`DisplayNames` gregorian style).
   - **Nits:** dead MonthStepper identifiers, unused Core API, the sort mismatch in SubcategoryDetail, the empty-filter copy, the logger category, two weak UI-test assertions, `month.*` identifiers reused in the detail.
   - The user's answers became D-055, with a Phase 8 note: compare against rollups.
   - [x] Fix round + Fast/Full test plans via a subagent (2026-11-19):
     - S1: the new `chartNeutral` token (light #8C8792: 3.50 on surface, 1.77 against pemasukan). The selected-month band was lowered to 8%.
     - S2: VoiceOver elements wrapped in an `HStack`.
     - S3: `gregorian(locale:timeZone:)`, also fixed in Home and Riwayat.
     - All nits fixed. Swipe identifiers are now `transaction.row.*` and `transaction.delete.confirm`.
     - `Fast.xctestplan` (the default) and `Full.xctestplan` are in the scheme.
3. [x] Orchestrator fast gate (D-054), 2026-11-19:
   - **26.5:** forced recompile (157 tasks), 0 warnings, Fast **303/303**, AnalysisUITests **4/4**.
   - **18.6:** forced recompile, 0 warnings, Fast **303/303**, AnalysisUITests **4/4**.
   - In the fix round, `testEmptyMonthShows…` flaked once on a stepper tap (it passed when re-run). It passed on both OS versions in the gate; watch it.
   - The full UI suite and the tour weren't run (D-054). The builder ran the tours once before D-054, and they passed.
   - Xcode note: only the user's own window (`windowtab-…`) should be open. A second MCP handle for the same project keeps its own active test plan.
4. [x] D-037 check (clean), commit, push, PR (2026-11-19).
- [x] Chore with Phase 6's commit (via a subagent, after the builder finishes so the scheme isn't edited under it): add a **Fast** (KemanayaCoreTests + KemanayaTests) and a **Full** test plan to the scheme (D-054).

## Phase 7 — History (13-month window, search, grouped by day) (D-053)
_Scope decided 2026-11-19 → D-053, search refined by D-057. **Done, PR open** on `feat/phase-7-history` (from `main` after #10 merged, 2026-11-19). Brief the implementer with D-054's test rule and the Xcode lock (D-052)._

**Phase 7 steps:**
1. [x] Implementation by a subagent (done 2026-11-20: 0 warnings, unit tests 324/324 on 26.5, HistoryUITests written, not run). Brief = D-016, D-017, D-022, D-023, D-036, D-043, D-044, D-050, D-052 (Xcode lock), D-053. Core first (day and month grouping with totals, search matching that covers amount digits, paged window fetch) with Swift Testing, then the Riwayat list. Extend the tour with History states (long list, search results, no results, AX5).
   - Sub-steps:
     - [x] a. Core: day and month grouping with totals
     - [x] b. Core: search matching, including amount digits
     - [x] c. Core: paged window fetch
     - [x] d. App: History list replaces the Riwayat month list
     - [x] e. App: search, empty state, and the "+" / edit / delete wiring
     - [x] f. HistoryUITests and tour shots
     - [x] g. 0 warnings and unit tests green on 26.5 (HistoryUITests written, not run: D-056)
2. [x] Independent review by a second subagent → fix round (2026-11-20). The review found nothing blocking: 3 should-fix items and 6 nits, all fixed. The user pointed search at Apple's HIG ("focus on what iOS search meant to be") → D-057: live prefix amount matching, subcategory suggestions, no stored history, and History never hides a later-dated entry.
3. [x] Orchestrator fast gate (D-056), 2026-11-20: a forced recompile gives 0 warnings on 26.5 and 18.6, and the Fast plan passes 336/336 on both. No UI tests ran. The Fast plan's buildForTesting does not compile KemanayaUITests, so the UI test files were checked with XcodeRefreshCodeIssuesInFile (0 issues). The real compile happens in Phase 11's full run.
4. [x] D-037 check, commit, push, PR (2026-11-20).
## Phase 8 — Retention: rollup + purge + yearly recap (D-017)
## Phase 9 — Backup / restore / CSV export (D-019, D-020)
_**Done, PR open.** Phases 8 and 9 share one branch and one PR (D-058): `feat/phase-8-9-retention-backup` from `main` after #11 merged (2026-11-20). Scope: D-059 (Phase 8) and D-060 (Phase 9), the orchestrator's calls on the user's instruction. Gate per D-056 (no UI tests). The Phase 1 spike moves to Phase 12 (D-060)._

**Phase 8 + 9 steps:**
1. [x] Phase 8 implementation by a subagent (2026-11-20, commit f2a9a62): `Retention.run` (one month per save, merges into existing rollups), `MonthTotals` (a month = raw rows + rollups, D-055), `RetentionRunner` on launch / foreground / month change, the Rekap tahunan screen in Analisis, DebugSample with old months, UI test + tour shots 24–25 written, not run. 0 warnings, Fast 361/361 on 26.5.
2. [x] Phase 9 implementation by a subagent (2026-11-20, commit ccede1b): Core `Backup` (format v1, byte-stable JSON, validate, replace-all restore in one save), `TransactionCSV`, `BackupFileWriter` (.prev rotation, coordinated atomic write); app `AutoBackup` (debounced on did-save, on launch, on background), the Pengaturan tab, the restore flow shared with Home's fresh-install link. Fresh store never overwrites an existing backup file. 0 warnings, Fast 386/386 on 26.5. SettingsUITests + tour shots 26 written, not run.
3. [x] Independent review of both phases → fix round.
   - Review (2026-11-20): the money logic holds. Retention is atomic per month, and raw + rollups never double count.
     - **B1:** a store with only a few entries could push a real backup out after two writes.
     - **S2:** a restore deleted models that open screens still held.
     - **S3:** no safety copy before a restore.
     - **S4:** validation gaps, including amounts that could overflow.
     - **S5:** retention's rollback could discard unrelated pending edits.
     - **S6:** the background flush could be cut off.
     - Plus 5 nits, including a CSV formula-injection one. The fixes were recorded in D-060's "Backup safety" list.
   - Early gate before the fixes: 18.6 had 0 warnings (325 compile entries), and Fast passed 386/386.
   - Fix round (2026-11-20, commit cb4e23d): every finding fixed. The work added `AutoBackupPolicy` (a fresh store never writes, and a found backup is renamed to `-kept-` on the first real write), the before-restore copy, a rebuild of the tabs after a restore, stricter validation, `SaturatingSum`, retention that skips while edits are pending, a background task for the flush, and CSV formula escaping. Judgment calls: retention skips rather than saving pending edits, and the rollup cap is exactly max × count.
4. [x] Orchestrator fast gate (D-056), 2026-11-20: a forced recompile (328 compile entries) gives 0 warnings on 26.5 and 18.6, and Fast passes **405/405** on both. No UI tests ran. SettingsUITests, the recap UI test and tour shots 24–26 are written; their first compile and run happen in Phase 11.
5. [x] D-037 check (clean: no screenshots, team id, email or paths; the log subsystem is the bundle id, as before), commit, push, PR (2026-11-20).
- **For Phase 12 on real devices:** run the Phase 1 bookmark spike through Pengaturan (pick an iCloud Drive folder, relaunch, re-sign after 7 days, delete and reinstall, then restore). Also check coordinated iCloud writes, the `.prev` and `-kept-` files, and that the folder picker opens in folder mode.
## Phase 10 — Settings: subcategory management, budgets
## Phase 11 — Onboarding, Si Naya mascot, app icon, English localization, polish
_**In progress.** Phases 10 and 11 share one branch and one PR (D-061): `feat/phase-10-11-settings-polish` from `main` after #12 merged (2026-11-20). Scope: D-062 (Phase 10) and D-063 (Phase 11), the orchestrator's calls. Phase 11 ends with the full UI run and screenshot tour (D-056)._
1. [x] Phase 10 implementation via a subagent (D-062), done 2026-11-20.
   - The subagent fixed the test compile errors and checked the Core work against D-062 (it was complete), then added `SubcategoryDraftTests`.
   - App: `RupiahKeypad` (pulled out of the add sheet), `BudgetAmountSheet`, `SubcategoryListView`, `SubcategoryEditorSheet`; Pengaturan is now Anggaran → Subkategori → Cadangan & Ekspor → Tentang; the card menu is Lihat detail · Ubah · Lepas pin.
   - UI tests written, not run (D-056): SettingsUITests (+5), tour shots 26b–32.
   - Judgment calls:
     - "Lihat pengenalan lagi" appears only once Phase 11 passes its closure.
     - Delete and hide confirmations are alerts, as in TransactionActions.
     - Hidden rows only offer Tampilkan.
     - The group is read-only when editing.
     - "Hapus anggaran" uses the brand colour, not red, and has no confirmation.
     - Name problems show in secondary text with an icon.
   - Open for the user: the system `EditButton` says "Edit", not Indonesian; the emoji field can't open the emoji keyboard directly.
   - Orchestrator gate: a forced recompile gives 0 warnings on 26.5 and 18.6, and Fast passes **490/490** on both.
   - Resumed 2026-11-20: Core writes (`Ledger+Subcategories`, `SubcategoryDraft`, `SubcategoryError`, `SubcategoryRules.nameProblem`, `BudgetError.overMaximum`) and `LedgerSubcategoryTests` (44 tests) were on disk; the test file didn't compile (2 errors, `MonthKey` force unwraps). No app views yet. A new subagent finishes Core + the app side.
2. [x] Si Naya artwork and app icon via a parallel subagent (D-063, D-030: separate folders).
   - Found finished after the session stopped (2026-11-20): `DesignSystem/Mascot/SiNaya.swift` (moods curious / calm / sleepy, gallery section `mascot`), 1024 px light / dark / tinted icon PNGs wired in `AppIcon.appiconset`.
3. [x] Onboarding, empty states, store error screen via a subagent (D-063, D-064), done 2026-11-20.
   - Onboarding (`OnboardingPolicy` in Core, 3 pages, Lewati / Mulai / Pulihkan, Lihat pengenalan lagi wired); UI tests only see it with `-showOnboarding`.
   - Si Naya empty states on Home, Riwayat, search and Analisis.
   - `StoreErrorView` replaces the `fatalError` (D-064); `-simulateStoreError plain|exports` for tests.
   - OnboardingUITests (8) + tour shots 33–34 written, not run.
   - The orchestrator's check on 26.5: forced recompile, 0 warnings, Fast **498/498**.
4. [x] English translations via a subagent (D-063, D-065), done 2026-11-20. All 247 keys have `en` (the orchestrator counted them itself), there are no leaks, dates follow `\.locale`, and the build has 0 warnings. The leftovers go to the fix round:
   - the D-065 key splits and compact suffixes
   - onboarding page 3's budget line is hidden by the page indicator
   - HomeView's `#Preview` doesn't compile (`__designTimeSelection` ambiguity)
5. [~] Independent review of Phases 10 and 11, then one fix round.
6. [ ] Orchestrator gate: forced recompile with 0 warnings and unit tests on 26.5 and 18.6, then the full UI suite and the screenshot tour on both, light / dark / AX5 review, plus an English pass. Fix what breaks.
7. [ ] D-037 check, commit, push, PR.
- **Resume here if the session stops (usage limit):** steps 1 and 2 were running as two parallel subagents, writing **uncommitted** files on this branch. To continue: (a) delete the stale Xcode lock `.xcode-busy` in the session scratchpad if it exists; (b) `git status` to see what they left; (c) build with the Xcode MCP (iPhone 17 Pro 26.5, Fast plan) and run the unit tests; (d) brief a new subagent to finish what is missing against D-062 (Phase 10: Ledger subcategory/budget writes + tests, Pengaturan Anggaran / Subkategori / Tentang, editor sheet, card menu Ubah, UI tests written but not run) and D-063 (Si Naya in `DesignSystem/Mascot/`, app icon PNGs in `AppIcon.appiconset`); (e) commit, then carry on from step 3.
## Phase 12 — Install on iPhone 15, iPhone XR and iPhone 13 (D-046); 7-day re-sign routine

---

## Resume here (Phase 0, branch `chore/phase-0-scaffold`)
Everything below `main`'s docs commit is **untracked on disk**: `.claude/hooks/`, `.claude/settings.json`, `Config/`, `Kemanaya.xcodeproj/`, `Kemanaya/`, `KemanayaCore/`, `KemanayaTests/`, `KemanayaUITests/`. The orchestrator wrote it inline instead of delegating; the user wants subagents (CLAUDE.md), so nothing is committed until a subagent has reviewed it.
1. [x] **Subagent review** (2026-11-17): project, package, sources and gitignore have no blocking issues. The hook had 3 push-to-`main` bypasses (quoting/`sh -c`/`eval`, `heads/main`, abbreviated push options) plus loose dangerous-pattern matching.
2. [x] **Fixes via a subagent:** done 2026-11-17, and the orchestrator re-ran the hook table: 314/315 match. The one difference, `git reset --keep`, is allowed on purpose because it is the safe alternative to `--hard`. `.gitignore` now has `*.xcresult` + `.claude/worktrees/`, and `.mcp.json` uses the absolute bridge path (D-038). **After the restart (2026-11-17):** tests are 3/3 green under the MCP on iPhone 17 Pro (26.5) and iPhone 16 Pro (18.6). A clean MCP build **still** shows `-Wincompatible-sysroot` on `KemanayaCoreTests`. The bridge no longer has `SDKROOT`, but the headless `Xcode Service` helper (started 21:00, before the restart) still passes `SDKROOT=…MacOSX.sdk` to `SWBBuildService`. The user quit the helper and reconnected the MCP. The clean rebuild has **zero warnings** and tests are 3/3 green on both simulators, so D-038 is verified.
3. [x] **Phase-close checks** (D-029), 2026-11-17: iPhone SE 3rd gen (18.3): tests 3/3, light / dark / AX5 screenshots OK. iPhone Duo (27.1): MCP build with zero warnings, tests 3/3, screenshots OK. Note for Phase 5: on Duo the system status column takes space on the trailing edge, so safe-area-centered content sits left of the physical center. That is expected, but the Home layout must account for it.
4. [x] **MCP-only warning:** the user chose launching without `xcrun` → D-038, verified 2026-11-17.
5. [x] Fallbacks logged under D-031.
6. [x] D-037 check done 2026-11-17 (no team id, email, UDIDs, paths or screenshots). PR #1 squash-merged by the user (2026-11-17).
7. [x] Hook false positive fixed via a subagent (2026-11-17): the hook now parses quotes, heredocs and `$(…)`, so a commit message or PR body that mentions a push is data, while `sh -c` / `eval` strings and substitutions are still checked. The orchestrator re-ran the table (180/180) plus 14 extra cases, all OK. Known limits: input that can't be parsed is refused; lines that pipe into a shell fall back to the old quote-blind check; `python3 -c` strings are not inspected.
- Notes for later: `objectVersion = 110` (Xcode 27 format) may not open on the GitHub runner, so check this in Phase 0.5. The scheme's Test action includes UI tests, and CI may want `-skip-testing:KemanayaUITests`. Before Phase 3 SwiftData, decide whether `KemanayaCore` adds `.macOS(.v15)` so `swift test` runs on the Mac (new D-entry). Landscape is allowed (template default) and no D-entry covers it yet.

## Log
- **2026-11-16** — Grilling session complete (D-001…D-035). Next: Phase 0 in a new session (Fable) started from `~/Vibecoding/Kemanaya`.
- **2026-11-16** — Phase 0 started: docs committed on `main`; hook + Xcode scaffold written and verified on two simulators, pending review (see Resume here).
- **2026-11-17** — Phase 0 work verified: hook and scaffold reviewed and fixed via subagents, D-038 confirmed (zero warnings under the MCP), phase-close checks on SE and Duo passed. Squash-only merging recorded as D-039. Committed on `chore/phase-0-scaffold`; the PR waits on the GitHub repo.
- **2026-11-17** — PR #1 merged. The user deferred the Phase 1 spike; next up is Phase 2 (design system) once the hook fix is committed.
- **2026-11-17** — Phase 2 design system done via a subagent, reviewed by a second subagent, and verified by the orchestrator (zero warnings, 44/44 tests on 26.5 + 18.6, screenshots in light / dark / AX5 / Increase Contrast). The user approved the color rules → D-040.
- **2026-11-17** — Phase 3 domain & data done via a subagent, reviewed by a second subagent, and verified by the orchestrator (zero warnings, 139/139 tests on 26.5 + 18.6, fresh-install seed checked in the on-disk store). The user approved two-level budgets → D-041. Next: Phase 4 (add transaction).
- **2026-11-18** — Phase 4 add transaction done via subagents: two review rounds, two fix rounds, D-043/D-044/D-045/D-046. The orchestrator verified it: zero warnings, 219/219 tests on 26.5 + 18.6, screenshot tour reviewed in light / dark / AX5. The PR is opened for the user to merge. Follow-up `fix/` branch: (a) the delete popover on iOS 26, (c) the edit sheet scrolling to the selected tile.
- **2026-11-19** — Phase 4 follow-up via a subagent. The delete confirmation is now an alert, fixing the popover on iOS 26, and the edit sheet scrolls to the selected tile. The orchestrator verified it: zero warnings, 220/220 on 26.5 + 18.6, `07` / `08` shots reviewed in light / dark / AX5. PR #7 opened on `fix/phase-4-delete-dialog-edit-scroll`. The user approved D-047 (label of the selected subcategory), added to PR #7, and D-048 (Phase 5 scope: tab bar, Lepas pin only, Atur sheet, budgets hidden until set). Next: Phase 5 (Home), see its Resume here.
