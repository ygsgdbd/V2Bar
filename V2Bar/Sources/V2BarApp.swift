import AppKit
import ComposableArchitecture
import Sparkle
import SwiftUI

#if V2BAR_DEV
import Atlantis
#endif

@main
struct V2BarApp: App {
    let menuTrackingObservers: [NSObjectProtocol]
    let readmeBackdropWindow: NSWindow?
    let readmeColorScheme: ColorScheme?
    let store: StoreOf<AppFeature>
    let updaterController: SPUStandardUpdaterController

    init() {
#if V2BAR_DEV
        Atlantis.start()
#endif
#if DEBUG
        let readmeConfiguration = ReadmeScreenshotConfiguration(arguments: ProcessInfo.processInfo.arguments)
        if readmeConfiguration != nil {
            prepareDependencies {
                $0.defaultAppStorage = UserDefaults(suiteName: "V2Bar.ReadmeDemo")!
            }
        }
        readmeConfiguration?.applyAppearance()
        let readmeAppearance = readmeConfiguration?.appAppearance
        readmeBackdropWindow = readmeConfiguration?.makeBackdropWindow()
        readmeColorScheme = readmeConfiguration?.colorScheme
        let initialState = readmeConfiguration?.initialState(now: Date()) ?? AppFeature.State()
        let startsLiveServices = readmeConfiguration == nil
#else
        let readmeAppearance: NSAppearance? = nil
        readmeBackdropWindow = nil
        readmeColorScheme = nil
        let initialState = AppFeature.State()
        let startsLiveServices = true
#endif
        let updater = SPUStandardUpdaterController(
            startingUpdater: startsLiveServices,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = updater
        let store = Store(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            if startsLiveServices {
                $0.updaterClient.checkForUpdates = {
                    updater.checkForUpdates(nil)
                }
            } else {
                $0.imageClient = .testValue
                $0.launchAtLoginClient = .noop
                $0.tokenPromptClient = .noop
                $0.updaterClient = .noop
                $0.v2exClient = .testValue
            }
        }
        self.store = store
        menuTrackingObservers = [
            NotificationCenter.default.addObserver(
                forName: NSMenu.didBeginTrackingNotification,
                object: nil,
                queue: .main
            ) { notification in
                MainActor.assumeIsolated {
                    if let menu = notification.object as? NSMenu, let readmeAppearance {
                        menu.appearance = readmeAppearance
                        menu.items.forEach { $0.submenu?.appearance = readmeAppearance }
                    }
                    guard MenuBarView.isRootMenuTrackingNotification(notification) else { return }
                    store.send(.menuPresented)
                }
            },
            NotificationCenter.default.addObserver(
                forName: NSMenu.didEndTrackingNotification,
                object: nil,
                queue: .main
            ) { notification in
                MainActor.assumeIsolated {
                    guard MenuBarView.isRootMenuTrackingNotification(notification) else { return }
                    store.send(.menuDismissed)
                }
            },
        ]
        if !Self.isTesting, startsLiveServices {
            store.send(.task)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
                .preferredColorScheme(readmeColorScheme)
        } label: {
            Text("V2")
                .font(.custom("Futura", size: 12))
                .fontWeight(.medium)
                .accessibilityLabel("V2")
        }
        .menuBarExtraStyle(.menu)
    }

    private static var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
