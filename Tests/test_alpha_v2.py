"""Alpha V2 source-contract gates ONLY, not SwiftUI runtime or Apple SDK checks."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

def source(name):
    return (ROOT / 'App/Views' / name).read_text()

class AlphaV2SourceTests(unittest.TestCase):
    def test_publish_ignore_protects_local_data_and_credentials(self):
        text = (ROOT / '.gitignore').read_text()
        for token in ['.tools/', '.build/', 'Scripts/.cache/', 'Config/Cloud.xcconfig', 'DerivedData/', '*.xcarchive', '*.p12', '*.mobileprovision', '.env', '*.sqlite', 'logs/*', '!logs/v2-verification.log', '!logs/v2-source-gates.log']:
            self.assertIn(token, text)

    def test_verifier_discovers_all_python_gates_without_regeneration(self):
        text = (ROOT / 'Scripts/verify.sh').read_text()
        self.assertIn("unittest discover -s Tests -p 'test_*.py'", text)
        self.assertIn('PHASE_REGENERATE_PROJECT', text)

    def test_daily_calendar_modes_and_week_summary(self):
        text = source('DailyLogView.swift')
        for token in ['@AppStorage("v2.daily.mode")', '= "week"', 'Text("Month")', 'Text("Week")', 'LazyVGrid', 'ScrollViewReader', 'scrollTo', 'performedAreaDays', 'doneDays', 'recordTimeline', 'No records', 'selectedDate']:
            self.assertIn(token, text)
        for token in ['Dates with records', 'DisclosureGroup', 'Performed days yet', 'Record something you performed']:
            self.assertNotIn(token, text)

    def test_spotlight_and_contextual_root(self):
        text = source('RootView.swift')
        spotlight = text.split('struct SpotlightView: View {', 1)[1]
        for token in ['List(selection: $selection)', '.tag(entry.id)', '.swipeActions(edge: .trailing', 'Undo', 'Remove selected', '.onMove', 'taskCardColor', 'safeAreaInset(edge: .top)', 'areaTitle']:
            self.assertIn(token, spotlight)
        self.assertIn('if state.entry(id)?.isSpotlight == true', spotlight)
        for token in ['Move up', 'Move down', 'No starting point recorded.', 'Section { Text(store.syncSummary)']:
            self.assertNotIn(token, spotlight)
        self.assertIn('if screen == .phases', text)
        self.assertNotIn('if entry.kind == .task && entry.isSpotlight', text)

    def test_phase_area_switch_and_read_only_reference(self):
        text = source('PhaseViews.swift')
        for token in ['@AppStorage', 'Picker("Browse"', 'Show past phases', 'readOnly', 'MoreControls', 'createdAt', 'setPhaseStatus']:
            self.assertIn(token, text)
        self.assertIn('showLifecycle: true', text)
        self.assertNotIn('Show ended tasks', text)
        self.assertNotIn('Areas · continuity', text)
        editors = source('Editors.swift')
        for token in ['PhaseReferenceSheet', 'Phase reference', 'Inbox reference', 'phaseStatus', 'Section(area.title)', 'store.state.entry(draft.id) != nil']:
            self.assertIn(token, editors)

    def test_tasks_and_history_interactions(self):
        text = source('TaskViews.swift')
        for token in ['@AppStorage', 'EndedTasksView', 'Area / Phase', 'Clear all', 'View all', 'Collapse', '.swipeActions(edge: .trailing, allowsFullSwipe: false)', 'finalDone: finalDone', 'Section("History")', 'showTaskLink: false']:
            self.assertIn(token, text)
        self.assertIn('label: { recordContent }', text)
        for token in ['Show ended tasks', 'Latest performed', 'Edit / move / change kind', 'Section("Management")', 'lastPerformedOrder', 'No starting point recorded.', 'No resources recorded.']:
            self.assertNotIn(token, text)

if __name__ == '__main__':
    unittest.main(verbosity=2)
