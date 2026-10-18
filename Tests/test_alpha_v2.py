"""Alpha V2 source-contract gates ONLY, not SwiftUI runtime or Apple SDK checks."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]

def source(name):
    return (ROOT / 'App/Views' / name).read_text()

class AlphaV2SourceTests(unittest.TestCase):
    def test_phase_area_switch_and_read_only_reference(self):
        text = source('PhaseViews.swift')
        for token in ['@AppStorage', 'Picker("Browse"', 'Show past phases', 'readOnly', 'MoreControls', 'createdAt', 'setPhaseStatus']:
            self.assertIn(token, text)
        self.assertNotIn('Show ended tasks', text)
        self.assertNotIn('Areas · continuity', text)
        editors = source('Editors.swift')
        for token in ['PhaseReferenceSheet', 'Phase reference', 'Inbox reference', 'phaseStatus', 'Section(area.title)', 'store.state.entry(draft.id) != nil']:
            self.assertIn(token, editors)

    def test_tasks_and_history_interactions(self):
        text = source('TaskViews.swift')
        for token in ['@AppStorage', 'EndedTasksView', 'Area / Phase', 'Clear all', 'View all', 'Collapse', '.swipeActions(edge: .trailing, allowsFullSwipe: false)', 'finalDone: finalDone', 'Section("History")', 'showTaskLink: false']:
            self.assertIn(token, text)
        for token in ['Show ended tasks', 'Latest performed', 'Edit / move / change kind', 'Section("Management")', 'lastPerformedOrder', 'No starting point recorded.', 'No resources recorded.']:
            self.assertNotIn(token, text)

if __name__ == '__main__':
    unittest.main(verbosity=2)
