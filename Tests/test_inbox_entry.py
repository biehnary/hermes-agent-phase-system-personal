"""Source wiring regression; actual gesture recognition needs Apple UI testing."""
import unittest
from pathlib import Path

class InboxEntryTests(unittest.TestCase):
    def test_capture_and_list_use_mutually_exclusive_gestures(self):
        source = (Path(__file__).resolve().parents[1] / 'App/Views/RootView.swift').read_text()
        block = source.split('.safeAreaInset(edge: .bottom, alignment: .trailing) {', 1)[1].split('\n  }\n}', 1)[0]
        self.assertIn('LongPressGesture(minimumDuration: 0.5)', block)
        self.assertIn('.exclusively(before: TapGesture())', block)
        self.assertIn('case .first(true): sheet = .inboxList', block)
        self.assertIn('case .second: sheet = .entry(Entry(kind: .inbox))', block)
        self.assertIn('.accessibilityAction(named: Text("Open Inbox"))', block)

if __name__ == '__main__':
    unittest.main()
