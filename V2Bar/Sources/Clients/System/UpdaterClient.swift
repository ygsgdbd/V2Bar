import ComposableArchitecture

struct UpdaterClient: Sendable {
    var checkForUpdates: @MainActor @Sendable () -> Void
}

extension UpdaterClient: DependencyKey {
    static let liveValue = noop
    static let testValue = noop

    static let noop = Self(checkForUpdates: {})
}

extension DependencyValues {
    var updaterClient: UpdaterClient {
        get { self[UpdaterClient.self] }
        set { self[UpdaterClient.self] = newValue }
    }
}
