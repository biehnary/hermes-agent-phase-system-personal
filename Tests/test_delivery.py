"""Source/configuration delivery gates, NOT Apple type checking or CloudKit tests."""
import json
import plistlib
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]

class DeliveryTests(unittest.TestCase):
    def test_persistence_is_disk_backed_cloudkit_and_transactional(self):
        text = (ROOT / 'App/Persistence.swift').read_text()
        for token in ['@Model', 'cloudKitDatabase: cloudDatabase', '.private(containerID)', '.none', 'context.save()', 'context.rollback()', 'PhaseReplica.changes', 'PhaseReplica.state', 'NSPersistentCloudKitContainer.eventChangedNotification']:
            self.assertIn(token, text)
        self.assertNotIn('try! ', text)
        self.assertIn('isStoredInMemoryOnly: inMemory', text)
        self.assertLess(text.index('try context.save()'), text.index('state = merged'))

    def test_app_entry_has_error_recovery_and_refresh(self):
        text = (ROOT / 'App/PhaseSystemApp.swift').read_text()
        for token in ['@main', 'RootView()', '.environment(store)', 'scenePhase', 'store.refresh()', 'Retry', 'registerForRemoteNotifications']:
            self.assertIn(token, text)
        self.assertNotIn('fatalError(', text)

    def test_projects_share_cloud_identity_without_local_entitlements(self):
        spec = json.loads((ROOT / 'project.yml').read_text())
        self.assertNotIn('PHASE_CLOUDKIT_CONTAINER', spec['settings']['base'], 'Project settings must not override Cloud.xcconfig with an empty container')
        self.assertEqual(set(spec['targets']) & {'PhaseSystem', 'PhaseSystemMac'}, {'PhaseSystem', 'PhaseSystemMac'})
        for name, platform in [('PhaseSystem', 'iOS'), ('PhaseSystemMac', 'macOS')]:
            target = spec['targets'][name]
            self.assertEqual(target['settings']['configs']['CloudDebug']['CODE_SIGN_ENTITLEMENTS'], f'Config/{platform}-Cloud.entitlements')
            self.assertNotIn('Cloud', target['settings']['configs']['Debug']['CODE_SIGN_ENTITLEMENTS'])
            ent = plistlib.loads((ROOT / f'Config/{platform}-Cloud.entitlements').read_bytes())
            self.assertEqual(ent['com.apple.developer.icloud-container-identifiers'], ['$(PHASE_CLOUDKIT_CONTAINER)'])
            self.assertEqual(ent['com.apple.developer.icloud-services'], ['CloudKit'])
            info = plistlib.loads((ROOT / f'Config/Info-{platform}.plist').read_bytes())
            self.assertEqual(info['PHASE_CLOUDKIT_CONTAINER'], '$(PHASE_CLOUDKIT_CONTAINER)')
        self.assertTrue((ROOT / 'PhaseSystem.xcodeproj/project.pbxproj').is_file())

    def test_cloud_guard_rejects_missing_team_and_container(self):
        env = {'PATH': '/usr/bin:/bin', 'CONFIGURATION': 'CloudDebug', 'DEVELOPMENT_TEAM': '', 'PHASE_CLOUDKIT_CONTAINER': ''}
        result = subprocess.run(['bash', 'Scripts/check-cloud-config.sh'], cwd=ROOT, env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('error:', result.stderr)
        env.update(DEVELOPMENT_TEAM='ABCDEFGHIJ', PHASE_CLOUDKIT_CONTAINER='iCloud.dev.phasealpha')
        result = subprocess.run(['bash', 'Scripts/check-cloud-config.sh'], cwd=ROOT, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        env.update(CONFIGURATION='Debug', DEVELOPMENT_TEAM='', PHASE_CLOUDKIT_CONTAINER='')
        result = subprocess.run(['bash', 'Scripts/check-cloud-config.sh'], cwd=ROOT, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_no_private_json_import_or_nextstart_history_ui(self):
        ui = '\n'.join(p.read_text() for p in (ROOT / 'App/Views').glob('*.swift'))
        self.assertNotIn('fileImporter', ui)
        self.assertNotIn('entry.nextStart', ui)
        self.assertIn('try $0.reorderSpotlight(ids)', ui)
        self.assertIn('nextStart: nextStart', ui)

if __name__ == '__main__':
    unittest.main(verbosity=2)
