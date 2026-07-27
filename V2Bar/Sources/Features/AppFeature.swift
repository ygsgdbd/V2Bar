import ComposableArchitecture
import Foundation
import Sharing

enum AutoRefreshMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case onMenuOpen
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case off

    var id: Self { self }

    var title: String {
        switch self {
        case .onMenuOpen: "打开菜单时"
        case .fiveMinutes: "每 5 分钟"
        case .fifteenMinutes: "每 15 分钟"
        case .thirtyMinutes: "每 30 分钟"
        case .off: "关闭"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .fiveMinutes: 300
        case .fifteenMinutes: 900
        case .thirtyMinutes: 1_800
        case .onMenuOpen, .off: nil
        }
    }
}

enum RefreshDomain: CaseIterable, Equatable, Hashable, Sendable {
    case tokenInfo
    case profile
    case notifications
}

enum AccountRefreshStatus: Equatable, Sendable {
    case refreshing
    case updated(Date)
    case notUpdated
}

struct RefreshResult: Equatable, Sendable {
    var tokenInfo: Result<V2EXTokenInfo, V2EXClientError>
    var profile: Result<V2EXUserProfile, V2EXClientError>
    var notifications: Result<[V2EXNotification], V2EXClientError>
    var avatarData: Result<Data?, V2EXClientError>?

    init(
        tokenInfo: Result<V2EXTokenInfo, V2EXClientError>,
        profile: Result<V2EXUserProfile, V2EXClientError>,
        notifications: Result<[V2EXNotification], V2EXClientError>,
        avatarData: Result<Data?, V2EXClientError>? = nil
    ) {
        self.tokenInfo = tokenInfo
        self.profile = profile
        self.notifications = notifications
        self.avatarData = avatarData
    }
}

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        @Shared var token: String
        @Shared var autoRefreshMode: AutoRefreshMode
        var avatarData: Data?
        var deferredRefresh: RefreshResult?
        var errorMessage: String?
        var inFlightRefreshes: Set<RefreshDomain> = []
        var isMenuOpenRefreshInFlight = false
        var isMenuPresented = false
        var isReadmeDemo = false
        var isSettingLaunchAtLogin = false
        var isValidatingToken = false
        var validatingToken: String?
        var knownNotificationIDs: Set<Int>?
        var lastUpdated: Date?
        var launchAtLoginStatus: LaunchAtLoginStatus = .disabled
        var newNotificationIDs: Set<Int> = []
        var notifications: [V2EXNotification] = []
        var profile: V2EXUserProfile?
        var tokenInfo: V2EXTokenInfo?

        init(
            token: Shared<String> = Shared(wrappedValue: "", .appStorage("token")),
            autoRefreshMode: Shared<AutoRefreshMode> = Shared(
                wrappedValue: .onMenuOpen,
                .appStorage("autoRefreshMode")
            ),
            isReadmeDemo: Bool = false
        ) {
            self._token = token
            self._autoRefreshMode = autoRefreshMode
            self.isReadmeDemo = isReadmeDemo
        }

        init(
            token: String,
            autoRefreshMode: AutoRefreshMode = .onMenuOpen,
            isReadmeDemo: Bool = false
        ) {
            self.init(
                token: Shared(value: token),
                autoRefreshMode: Shared(value: autoRefreshMode),
                isReadmeDemo: isReadmeDemo
            )
        }

        var hasToken: Bool {
            !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var isRefreshing: Bool {
            !inFlightRefreshes.isEmpty
        }

        var launchAtLoginEnabled: Bool {
            launchAtLoginStatus == .enabled || launchAtLoginStatus == .requiresApproval
        }

        var maskedToken: String {
            guard hasToken else { return "未设置" }
            guard token.count > 8 else { return String(repeating: "•", count: token.count) }
            return "\(token.prefix(4))••••\(token.suffix(4))"
        }

        var recentNotifications: [V2EXNotification] {
            Array(
                notifications
                    .sorted { ($0.created, $0.id) > ($1.created, $1.id) }
                    .prefix(10)
            )
        }

        var recentNotificationGroups: [NotificationTopicGroup] {
            NotificationTopicGroup.makeGroups(
                from: recentNotifications,
                newNotificationIDs: newNotificationIDs,
                limit: 5
            )
        }

        var accountRefreshStatus: AccountRefreshStatus {
            if isRefreshing { return .refreshing }
            if let lastUpdated { return .updated(lastUpdated) }
            return .notUpdated
        }
    }

    enum Action: Equatable, Sendable {
        case task
        case menuPresented
        case menuDismissed
        case refreshResponse(String, RefreshResult)
        case autoRefreshModeTapped(AutoRefreshMode)
        case autoRefreshTick
        case tokenEditTapped
        case tokenPromptResponse(String?)
        case tokenValidationResponse(String, Result<V2EXTokenInfo, V2EXClientError>)
        case logoutTapped
        case launchAtLoginTapped(Bool)
        case launchAtLoginResponse(LaunchAtLoginStatus)
        case launchAtLoginSetFinished(LaunchAtLoginStatus, String?)
        case openLoginItemsSettingsTapped
        case openURLTapped(URL)
        case notificationGroupOpenTapped(NotificationGroupID)
        case notificationTapped(Int)
        case checkForUpdatesTapped
        case quitTapped
    }

    @Dependency(\.applicationClient) var applicationClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now
    @Dependency(\.imageClient) var imageClient
    @Dependency(\.launchAtLoginClient) var launchAtLoginClient
    @Dependency(\.tokenPromptClient) var tokenPromptClient
    @Dependency(\.updaterClient) var updaterClient
    @Dependency(\.v2exClient) var v2exClient

    private enum CancelID {
        case autoRefresh
        case refresh
        case tokenValidation
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.isReadmeDemo else { return .none }
                var effects: [Effect<Action>] = [loadLaunchAtLoginStatus()]
                if state.hasToken {
                    effects.append(startRefresh(&state))
                    effects.append(autoRefreshEffect(for: state.autoRefreshMode))
                }
                return .merge(effects)

            case .menuPresented:
                state.isMenuPresented = true
                guard !state.isReadmeDemo,
                      state.hasToken,
                      state.autoRefreshMode == .onMenuOpen,
                      !state.isRefreshing,
                      !state.isMenuOpenRefreshInFlight
                else {
                    return .none
                }
                return startMenuOpenRefresh(&state)

            case .menuDismissed:
                state.isMenuPresented = false
                guard let result = state.deferredRefresh else { return .none }
                state.deferredRefresh = nil
                state.inFlightRefreshes = []
                state.isMenuOpenRefreshInFlight = false
                apply(result, to: &state)
                return .none

            case let .refreshResponse(token, result):
                guard token == state.token else { return .none }
                if state.isMenuPresented {
                    state.isMenuOpenRefreshInFlight = false
                    state.deferredRefresh = result
                } else {
                    state.inFlightRefreshes = []
                    state.isMenuOpenRefreshInFlight = false
                    apply(result, to: &state)
                }
                return .none

            case let .autoRefreshModeTapped(mode):
                guard !state.isReadmeDemo else { return .none }
                state.$autoRefreshMode.withLock { $0 = mode }
                let timer = autoRefreshEffect(for: mode)
                guard state.hasToken else { return .cancel(id: CancelID.autoRefresh) }
                if mode == .onMenuOpen,
                   state.isMenuPresented,
                   !state.isRefreshing,
                   !state.isMenuOpenRefreshInFlight,
                   state.deferredRefresh == nil {
                    return .merge(.cancel(id: CancelID.autoRefresh), startMenuOpenRefresh(&state))
                }
                return timer

            case .autoRefreshTick:
                guard !state.isReadmeDemo,
                      state.hasToken,
                      !state.isMenuPresented,
                      !state.isRefreshing
                else {
                    return .none
                }
                return startRefresh(&state)

            case .tokenEditTapped:
                guard !state.isReadmeDemo else { return .none }
                let existingToken = state.hasToken ? state.token : nil
                return .run { send in
                    await send(.tokenPromptResponse(await tokenPromptClient.prompt(existingToken)))
                }

            case let .tokenPromptResponse(candidate):
                guard !state.isReadmeDemo else { return .none }
                guard let candidate else { return .none }
                let token = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !token.isEmpty else { return .none }
                state.isValidatingToken = true
                state.validatingToken = token
                state.errorMessage = nil
                return .run { send in
                    do {
                        await send(.tokenValidationResponse(token, .success(try await v2exClient.validateToken(token))))
                    } catch {
                        await send(.tokenValidationResponse(token, .failure(mapError(error))))
                    }
                }
                .cancellable(id: CancelID.tokenValidation, cancelInFlight: true)

            case let .tokenValidationResponse(candidate, result):
                guard !state.isReadmeDemo else { return .none }
                guard state.validatingToken == candidate else { return .none }
                state.isValidatingToken = false
                state.validatingToken = nil
                switch result {
                case let .success(tokenInfo):
                    let storedToken = state.token.trimmingCharacters(in: .whitespacesAndNewlines)
                    let didChangeAccount = candidate != storedToken
                    if didChangeAccount {
                        resetAccountState(&state)
                    }
                    state.$token.withLock { $0 = candidate }
                    state.tokenInfo = tokenInfo
                    let refreshEffects = Effect<Action>.merge(
                        startRefresh(&state),
                        autoRefreshEffect(for: state.autoRefreshMode)
                    )
                    guard didChangeAccount else { return refreshEffects }
                    return .concatenate(
                        .cancel(id: CancelID.refresh),
                        refreshEffects
                    )
                case let .failure(error):
                    state.errorMessage = error.localizedDescription
                    return .run { _ in
                        await tokenPromptClient.showError(error.localizedDescription)
                    }
                }

            case .logoutTapped:
                state.isValidatingToken = false
                state.validatingToken = nil
                state.$token.withLock { $0 = "" }
                resetAccountState(&state)
                return .merge(
                    .cancel(id: CancelID.refresh),
                    .cancel(id: CancelID.autoRefresh),
                    .cancel(id: CancelID.tokenValidation)
                )

            case let .launchAtLoginTapped(enabled):
                guard !state.isReadmeDemo, !state.isSettingLaunchAtLogin else { return .none }
                state.isSettingLaunchAtLogin = true
                state.launchAtLoginStatus = enabled ? .enabled : .disabled
                return .run { send in
                    do {
                        try await launchAtLoginClient.setEnabled(enabled)
                        await send(.launchAtLoginSetFinished(await launchAtLoginClient.status(), nil))
                    } catch {
                        await send(
                            .launchAtLoginSetFinished(
                                await launchAtLoginClient.status(),
                                error.localizedDescription
                            )
                        )
                    }
                }

            case let .launchAtLoginResponse(status):
                guard !state.isSettingLaunchAtLogin else { return .none }
                state.launchAtLoginStatus = status
                return .none

            case let .launchAtLoginSetFinished(status, errorMessage):
                state.isSettingLaunchAtLogin = false
                state.launchAtLoginStatus = status
                state.errorMessage = errorMessage
                return .none

            case .openLoginItemsSettingsTapped:
                guard !state.isReadmeDemo else { return .none }
                return .run { _ in await applicationClient.openLoginItemsSettings() }

            case let .openURLTapped(url):
                return .run { _ in _ = await applicationClient.open(url) }

            case let .notificationGroupOpenTapped(groupID):
                let topicURL = state.recentNotificationGroups
                    .first { $0.id == groupID }?
                    .topicURL
                markNotificationGroupSeen(groupID, in: &state)
                guard let topicURL else { return .none }
                return .run { _ in _ = await applicationClient.open(topicURL) }

            case let .notificationTapped(notificationID):
                guard let notification = state.notifications.first(where: { $0.id == notificationID }) else {
                    return .none
                }
                markNotificationGroupSeen(notification.groupID, in: &state)
                guard let topicURL = notification.topicURL else { return .none }
                return .run { _ in _ = await applicationClient.open(topicURL) }

            case .checkForUpdatesTapped:
                guard !state.isReadmeDemo else { return .none }
                return .run { _ in await updaterClient.checkForUpdates() }

            case .quitTapped:
                return .run { _ in await applicationClient.quit() }
            }
        }
    }

    private func startRefresh(_ state: inout State) -> Effect<Action> {
        state.inFlightRefreshes = Set(RefreshDomain.allCases)
        state.errorMessage = nil
        return refreshEffect(token: state.token)
    }

    private func startMenuOpenRefresh(_ state: inout State) -> Effect<Action> {
        state.isMenuOpenRefreshInFlight = true
        return refreshEffect(token: state.token)
    }

    private func refreshEffect(token: String) -> Effect<Action> {
        return .run { send in
            async let tokenInfo = result { try await v2exClient.fetchTokenInfo(token) }
            async let profile = result { try await v2exClient.fetchProfile(token) }
            async let notifications = result { try await v2exClient.fetchNotifications(token) }

            let tokenInfoResult = await tokenInfo
            let profileResult = await profile
            let notificationsResult = await notifications
            let avatarResult: Result<Data?, V2EXClientError>?
            if case let .success(profile) = profileResult, let url = profile.avatarURL {
                avatarResult = await result { try await Optional(imageClient.load(url)) }
            } else if case .success = profileResult {
                avatarResult = .success(nil)
            } else {
                avatarResult = nil
            }

            await send(
                .refreshResponse(
                    token,
                    RefreshResult(
                        tokenInfo: tokenInfoResult,
                        profile: profileResult,
                        notifications: notificationsResult,
                        avatarData: avatarResult
                    )
                )
            )
        }
        .cancellable(id: CancelID.refresh, cancelInFlight: true)
    }

    private func apply(_ result: RefreshResult, to state: inout State) {
        var errors: [String] = []
        var didUpdateCoreData = false
        switch result.tokenInfo {
        case let .success(value):
            state.tokenInfo = value
            didUpdateCoreData = true
        case let .failure(error): errors.append(error.localizedDescription)
        }
        switch result.profile {
        case let .success(value):
            state.profile = value
            didUpdateCoreData = true
        case let .failure(error): errors.append(error.localizedDescription)
        }
        switch result.notifications {
        case let .success(value):
            let currentNotificationIDs = Set(value.map(\.id))
            if let knownNotificationIDs = state.knownNotificationIDs {
                state.newNotificationIDs.formUnion(
                    currentNotificationIDs.subtracting(knownNotificationIDs)
                )
                state.knownNotificationIDs?.formUnion(currentNotificationIDs)
            } else {
                state.knownNotificationIDs = currentNotificationIDs
            }
            state.notifications = value
            didUpdateCoreData = true
        case let .failure(error): errors.append(error.localizedDescription)
        }
        if let avatarData = result.avatarData {
            switch avatarData {
            case let .success(value): state.avatarData = value
            case let .failure(error): errors.append(error.localizedDescription)
            }
        }
        state.errorMessage = errors.first
        if didUpdateCoreData {
            state.lastUpdated = now
        }
    }

    private func markNotificationGroupSeen(
        _ groupID: NotificationGroupID,
        in state: inout State
    ) {
        let notificationIDs = state.notifications
            .filter { $0.groupID == groupID }
            .map(\.id)
        state.newNotificationIDs.subtract(notificationIDs)
    }

    private func resetNotificationTracking(_ state: inout State) {
        state.knownNotificationIDs = nil
        state.newNotificationIDs = []
    }

    private func resetAccountState(_ state: inout State) {
        state.avatarData = nil
        state.deferredRefresh = nil
        state.errorMessage = nil
        state.inFlightRefreshes = []
        state.isMenuOpenRefreshInFlight = false
        state.lastUpdated = nil
        resetNotificationTracking(&state)
        state.notifications = []
        state.profile = nil
        state.tokenInfo = nil
    }

    private func loadLaunchAtLoginStatus() -> Effect<Action> {
        .run { send in
            await send(.launchAtLoginResponse(await launchAtLoginClient.status()))
        }
    }

    private func autoRefreshEffect(for mode: AutoRefreshMode) -> Effect<Action> {
        guard let interval = mode.interval else {
            return .cancel(id: CancelID.autoRefresh)
        }
        return .run { send in
            for await _ in clock.timer(interval: .seconds(interval)) {
                await send(.autoRefreshTick)
            }
        }
        .cancellable(id: CancelID.autoRefresh, cancelInFlight: true)
    }
}

private func result<Value: Sendable>(
    _ operation: @Sendable () async throws -> Value
) async -> Result<Value, V2EXClientError> {
    do {
        return .success(try await operation())
    } catch {
        return .failure(mapError(error))
    }
}

private func mapError(_ error: Error) -> V2EXClientError {
    if let error = error as? V2EXClientError {
        return error
    }
    return .transport(error.localizedDescription)
}
