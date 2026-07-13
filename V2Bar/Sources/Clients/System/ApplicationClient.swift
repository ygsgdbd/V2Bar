import AppKit
import ComposableArchitecture
import ServiceManagement

struct ApplicationClient: Sendable {
    var open: @MainActor @Sendable (URL) -> Bool
    var openLoginItemsSettings: @MainActor @Sendable () -> Void
    var quit: @MainActor @Sendable () -> Void
}

extension ApplicationClient: DependencyKey {
    static let liveValue = Self(
        open: { NSWorkspace.shared.open($0) },
        openLoginItemsSettings: {
            SMAppService.openSystemSettingsLoginItems()
        },
        quit: {
            NSApplication.shared.terminate(nil)
        }
    )

    static let testValue = noop

    static let noop = Self(
        open: { _ in false },
        openLoginItemsSettings: {},
        quit: {}
    )
}

extension DependencyValues {
    var applicationClient: ApplicationClient {
        get { self[ApplicationClient.self] }
        set { self[ApplicationClient.self] = newValue }
    }
}
