# UI acceptance

## Verification boundaries

Apple SDKs are unavailable here. Source assertions and Swift syntax parsing are not an Apple build, SwiftUI type-check, simulator run, or device acceptance. All device scenarios below remain pending until exercised on iOS and macOS.

## Required acceptance checks (specified before the UI fixes)

1. **Done and resume:** record Done on a task with an existing next-start hint. Leave the new hint blank: saving clears the old hint and resume uses the latest Done text. Enter a new hint: resume uses that hint. The editor explains blank semantics. Editing/deleting an older Done does not rewrite the task's current next-start. Failed saves retain the sheet and draft.
2. **Spotlight:** only starred tasks appear, never phases or areas (including legacy starred phases). Empty copy says tasks only. Each row shows task title, phase title (or Unassigned), and current next-start or latest Done text, limited to two preview lines. No search/kind/status filters. Manual reorder still works.
3. **Tasks reading order:** manual order is default. Optional sort explicitly says oldest performed first, with never-performed tasks first and no urgency/priority language. Within phase groups, dated tasks ascend by last performed; equal dates retain deterministic manual order. Filtered/sorted lists cannot rewrite manual order.
4. **Task row stars:** every Tasks row has an always-visible star ON/OFF button separate from the navigation link. Clicking the star changes Spotlight without navigating. Ended tasks cannot be newly starred; labels expose current state and action to accessibility.
5. **Classification:** Area creation/edit/read is lightweight title and description plus archive/classification navigation, not Phase goal/status/bottleneck/expected-change fields. Phase retains full context fields. No Phase or Area Spotlight controls. Archiving changes no tasks or historical captured classifications.
6. **Navigation and capture:** root actions toolbar is attached to content inside each NavigationStack. From all tabs and from a pushed task detail, floating Inbox dump stays available. Save/cancel returns to exactly the same tab/detail without resetting navigation. Test compact iPhone and wide iPad/macOS. Root Actions exposes full Markdown export and Inbox list.
7. **Task detail:** prominent Record Done appears before potentially long Resume/Resources content. Resume uses the current hint or latest performed text, not latest notes. Resources retain original text; detected safe HTTP(S) URLs also appear as clickable Links. Non-web/custom schemes are not auto-opened. Test multiple URLs and long/multiline content.
8. **Record audit:** Done rows expose edit/delete with confirmation. Lifecycle-event rows expose neither edit nor delete in Daily Log, Phase history, or Area continuity. End/reopen audit remains visible and does not contribute a Done mark.
9. **Daily Log:** contribution grid is binary: one identical mark per date containing any Done, never a count/intensity. Clicking a date selects its records. Multiple Done records that day do not add marks. Event-only dates appear in the date list, never contribution cells. No artificial dates or scoring.
10. **Failures/accessibility:** mutation failure keeps draft/sheet and shows one alert above the active editor; retry works. Check keyboard, VoiceOver labels, selected date, star state, destructive confirmation, long text, scrolling, export/cancel, inbox edit/delete, and sheet presentation from pushed details.

## Integration contract

- Root receives `AppStore` through environment; UI owns `UIPresentationState` for topmost-sheet error delivery.
- Every mutation uses `store.apply`; editors dismiss only after success.
- New Done passes the entered next-start directly, including blank; core owns normalization and latest-Done fallback.
- Task editor clears direct areaID so recording resolves the current phase's area. Past records keep their captured phase/area.
- Task manual ordering submits every task ID, retaining untouched positions. Spotlight is task-only in core and UI.
- Phase/Area are archived rather than destructively deleted. Done deletion does not change current next-start. Lifecycle audit has no UI deletion path.

## Execution results

- Acceptance scenarios above were rewritten before production edits. Pre-fix inspection confirmed the violations. Python assertion attempts were blocked by unattended execution policy, so there is no executable RED claim.
- Post-fix shell source regression gates passed: direct next-start forwarding/no preservation variable; tasks-only empty copy; two-line Spotlight preview; ascending performed comparator; separate TaskListRow; clickable resource Link; no Phase Spotlight mutation.
- Swift formatting completed on the four modified Swift files.
- Swift 6.2.4 `swiftc -frontend -parse -swift-version 5 -target arm64-apple-ios17.0 App/Views/*.swift`: exit 0 after formatting.
- Equivalent syntax parse with `-target arm64-apple-macosx14.0`: exit 0 after formatting.
- Inspected DailyLogView and core doneDays: unique Done dates, binary marks, date-selection buttons, separate event-inclusive date list; no changes needed to the grid.
- Confirmed parent core integration supplies task-only Spotlight and latest-Done-text resume fallback. No core, persistence, or configuration files were changed by this UI work.
- Apple SDK build, platform type-checking, simulator/device rendering, actual navigation/sheets/toolbars, URL opening, VoiceOver, drag reordering, export, and persistence-failure UI cannot be verified in this Linux environment. Syntax parsing does not resolve SwiftUI APIs or prove runtime behavior.
