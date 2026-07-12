import ComposableArchitecture
import ServiceManagement

enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled:
            self = .enabled
        case .notRegistered:
            self = .disabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .unavailable
        @unknown default:
            self = .unavailable
        }
    }
}

struct LaunchAtLoginClient: Sendable {
    var status: @Sendable () async -> LaunchAtLoginStatus
    var setEnabled: @Sendable (Bool) async throws -> Void
}

extension LaunchAtLoginClient: DependencyKey {
    static let liveValue = Self(
        status: {
            LaunchAtLoginStatus(SMAppService.mainApp.status)
        },
        setEnabled: { isEnabled in
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
        }
    )

    static let testValue = noop

    static let noop = Self(
        status: { .unavailable },
        setEnabled: { _ in }
    )
}

extension DependencyValues {
    var launchAtLoginClient: LaunchAtLoginClient {
        get { self[LaunchAtLoginClient.self] }
        set { self[LaunchAtLoginClient.self] = newValue }
    }
}
