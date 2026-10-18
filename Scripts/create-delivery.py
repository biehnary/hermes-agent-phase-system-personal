#!/usr/bin/env python3
"""Write the owned configuration deliverable; run once during initial delivery."""
from pathlib import Path
import json
import plistlib
root = Path(__file__).resolve().parent.parent
config = root / 'Config'
if (config / 'Identity.xcconfig').exists():
    raise SystemExit('Refusing to overwrite existing identity/signing settings. Edit project.yml directly, then run generate-project.sh.')
config.mkdir(exist_ok=True)
(config / 'Identity.xcconfig').write_text('''// Change these ONCE to identifiers you own before device/cloud distribution.
// Both local and Cloud configurations include this file; never suffix by configuration.
PHASE_IOS_BUNDLE_IDENTIFIER = dev.phase-system.ios
PHASE_MAC_BUNDLE_IDENTIFIER = dev.phase-system.mac
''')
(config / 'Local.xcconfig').write_text('''#include "Identity.xcconfig"
PHASE_CLOUDKIT_CONTAINER =
CODE_SIGNING_ALLOWED = NO
''')
(config / 'Cloud.example.xcconfig').write_text('''// Copy to Cloud.xcconfig and fill the two empty values. Do not commit that file.
// Select your real Apple Developer Team and one shared CloudKit container for BOTH targets.
DEVELOPMENT_TEAM =
PHASE_CLOUDKIT_CONTAINER =
CODE_SIGN_STYLE = Automatic
CODE_SIGNING_ALLOWED = YES
''')
for name, apns, environment in [('CloudDebug', 'development', 'Development'), ('CloudRelease', 'production', 'Production')]:
    (config / f'{name}.xcconfig').write_text(f'''#include "Identity.xcconfig"
// Optional only so LOCAL builds can load the project before cloud enrollment.
// Scripts/check-cloud-config.sh makes this file mandatory for Cloud builds.
#include? "Cloud.xcconfig"
PHASE_APNS_ENVIRONMENT = {apns}
PHASE_CLOUDKIT_ENVIRONMENT = {environment}
''')
common_info = {'CFBundleDevelopmentRegion':'ko', 'CFBundleDisplayName':'Phase System', 'CFBundleExecutable':'$(EXECUTABLE_NAME)', 'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion':'6.0', 'CFBundleName':'$(PRODUCT_NAME)', 'CFBundlePackageType':'APPL', 'CFBundleShortVersionString':'$(MARKETING_VERSION)', 'CFBundleVersion':'$(CURRENT_PROJECT_VERSION)', 'PHASE_CLOUDKIT_CONTAINER':'$(PHASE_CLOUDKIT_CONTAINER)'}
for platform in ['iOS', 'macOS']:
    info = dict(common_info)
    if platform == 'iOS':
        info.update({'LSRequiresIPhoneOS':True, 'UILaunchScreen':{}, 'UIBackgroundModes':['remote-notification'], 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'], 'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']})
    else:
        info.update({'LSMinimumSystemVersion':'$(MACOSX_DEPLOYMENT_TARGET)', 'NSPrincipalClass':'NSApplication', 'LSApplicationCategoryType':'public.app-category.productivity'})
    with (config / f'Info-{platform}.plist').open('wb') as file:
        plistlib.dump(info, file)
mac_local = {'com.apple.security.app-sandbox':True, 'com.apple.security.network.client':True, 'com.apple.security.files.user-selected.read-write':True}
with (config / 'macOS-Local.entitlements').open('wb') as file:
    plistlib.dump(mac_local, file)
for platform in ['iOS','macOS']:
    entitlements = dict(mac_local) if platform == 'macOS' else {}
    entitlements.update({'com.apple.developer.icloud-container-identifiers':['$(PHASE_CLOUDKIT_CONTAINER)'], 'com.apple.developer.icloud-services':['CloudKit'], 'com.apple.developer.icloud-container-environment':'$(PHASE_CLOUDKIT_ENVIRONMENT)', ('aps-environment' if platform == 'iOS' else 'com.apple.developer.aps-environment'):'$(PHASE_APNS_ENVIRONMENT)'})
    with (config / f'{platform}-Cloud.entitlements').open('wb') as file:
        plistlib.dump(entitlements, file)
configs = {'Debug':'debug','Release':'release','CloudDebug':'debug','CloudRelease':'release'}
spec = {'name':'PhaseSystem', 'options':{'minimumXcodeGenVersion':'2.44.1', 'xcodeVersion':'16.0', 'deploymentTarget':{'iOS':'17.0','macOS':'14.0'}, 'defaultConfig':'Debug', 'createIntermediateGroups':True}, 'configs':configs, 'configFiles':{'Debug':'Config/Local.xcconfig','Release':'Config/Local.xcconfig','CloudDebug':'Config/CloudDebug.xcconfig','CloudRelease':'Config/CloudRelease.xcconfig'}, 'packages':{'PhaseCore':{'path':'.'}}, 'settings':{'base':{'SWIFT_VERSION':'5.0','MARKETING_VERSION':'1.0.0','CURRENT_PROJECT_VERSION':'1','GENERATE_INFOPLIST_FILE':'NO','ENABLE_USER_SCRIPT_SANDBOXING':'NO'}}, 'targets':{}, 'schemes':{}}
for name, platform, identity in [('PhaseSystem','iOS','IOS'),('PhaseSystemMac','macOS','MAC')]:
    base = {'PRODUCT_BUNDLE_IDENTIFIER':f'$(PHASE_{identity}_BUNDLE_IDENTIFIER)', 'INFOPLIST_FILE':f'Config/Info-{platform}.plist'}
    if platform == 'iOS':
        base.update({'TARGETED_DEVICE_FAMILY':'1,2','SUPPORTS_MACCATALYST':'NO','SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD':'NO'})
    target_configs = {}
    for cfg in configs:
        values = {}
        if cfg.startswith('Cloud'):
            values.update({'CODE_SIGN_ENTITLEMENTS':f'Config/{platform}-Cloud.entitlements'})
        else:
            values['CODE_SIGN_ENTITLEMENTS'] = 'Config/macOS-Local.entitlements' if platform == 'macOS' else ''
        target_configs[cfg] = values
    spec['targets'][name] = {'type':'application','platform':platform,'sources':[{'path':'App'}], 'dependencies':[{'package':'PhaseCore'}], 'settings':{'base':base,'configs':target_configs}, 'preBuildScripts':[{'name':'Validate explicit Cloud configuration','script':'"${SRCROOT}/Scripts/check-cloud-config.sh"','basedOnDependencyAnalysis':False}]}
    spec['schemes'][name] = {'build':{'targets':{name:'all'}},'run':{'config':'Debug'},'archive':{'config':'Release'}}
    spec['schemes'][name+'Cloud'] = {'build':{'targets':{name:'all'}},'run':{'config':'CloudDebug'},'archive':{'config':'CloudRelease'}}
spec['targets']['PhasePersistenceTests'] = {
    'type': 'bundle.unit-test', 'platform': 'macOS',
    'sources': [{'path': 'Tests/ApplePersistenceTests'}],
    'dependencies': [{'target': 'PhaseSystemMac'}, {'package': 'PhaseCore'}],
    'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': '$(PHASE_MAC_BUNDLE_IDENTIFIER).tests', 'GENERATE_INFOPLIST_FILE': 'YES'}}
}
spec['schemes']['PhaseSystemMac']['test'] = {'config': 'Debug', 'targets': ['PhasePersistenceTests']}
# JSON is a strict YAML subset; standard Python can validate without external packages.
(root / 'project.yml').write_text(json.dumps(spec, ensure_ascii=False, indent=2)+'\n')
print('Wrote project.yml and Config/*')
