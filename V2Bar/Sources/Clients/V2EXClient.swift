import ComposableArchitecture

struct V2EXClient: Sendable {
    var validateToken: @Sendable (String) async throws -> V2EXTokenInfo
    var fetchTokenInfo: @Sendable (String) async throws -> V2EXTokenInfo
    var fetchProfile: @Sendable (String) async throws -> V2EXUserProfile
    var fetchNotifications: @Sendable (String) async throws -> [V2EXNotification]
}

extension V2EXClient: DependencyKey {
    static let liveValue: Self = {
        let service = V2EXService()
        return Self(
            validateToken: { try await service.request(.token(token: $0)) },
            fetchTokenInfo: { try await service.request(.token(token: $0)) },
            fetchProfile: { try await service.request(.profile(token: $0)) },
            fetchNotifications: { try await service.request(.notifications(token: $0)) }
        )
    }()

    static let testValue = Self(
        validateToken: { _ in throw V2EXClientError.invalidResponse },
        fetchTokenInfo: { _ in throw V2EXClientError.invalidResponse },
        fetchProfile: { _ in throw V2EXClientError.invalidResponse },
        fetchNotifications: { _ in throw V2EXClientError.invalidResponse }
    )
}

extension DependencyValues {
    var v2exClient: V2EXClient {
        get { self[V2EXClient.self] }
        set { self[V2EXClient.self] = newValue }
    }
}
