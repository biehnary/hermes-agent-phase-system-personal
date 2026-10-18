import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

#if os(iOS)
@MainActor final class PlatformDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if PhaseSystemApp.cloudContainerID != nil { application.registerForRemoteNotifications() }
        return true
    }
}
#else
@MainActor final class PlatformDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if PhaseSystemApp.cloudContainerID != nil { NSApplication.shared.registerForRemoteNotifications() }
    }
}
#endif

@main @MainActor struct PhaseSystemApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(PlatformDelegate.self) private var delegate
    #else
    @NSApplicationDelegateAdaptor(PlatformDelegate.self) private var delegate
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: AppStore?
    @State private var startupError: String?

    static var cloudContainerID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PHASE_CLOUDKIT_CONTAINER") as? String,
              value.hasPrefix("iCloud."), !value.contains("$(") else { return nil }
        return value
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let store {
                    RootView().environment(store)
                        .task {
                            if let id = Self.cloudContainerID { await store.checkAccount(containerID: id) }
                        }
                        .task(id: scenePhase) {
                            guard scenePhase == .active else { return }
                            store.refresh()
                            // A fallback read for imports while app stays in foreground.
                            // This does not force or claim to complete a CloudKit sync.
                            while !Task.isCancelled {
                                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                                store.refresh()
                            }
                        }
                } else if let startupError {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("저장소를 열 수 없습니다").font(.headline)
                        Text(startupError).textSelection(.enabled)
                        Text("기존 데이터는 삭제하지 않았습니다. 서명·iCloud 설정과 여유 공간을 확인해 주세요.")
                        Button("Retry") { openStore() }
                    }.padding().frame(maxWidth: 640)
                } else {
                    ProgressView("저장소 여는 중…").task { openStore() }
                }
            }
            .frame(minWidth: 320, minHeight: 480)
        }
    }

    private func openStore() {
        do {
            let id = Self.cloudContainerID
            let container = try AppStore.makeContainer(containerID: id)
            store = try AppStore(container: container, cloudEnabled: id != nil)
            startupError = nil
        } catch { startupError = error.localizedDescription }
    }
}
