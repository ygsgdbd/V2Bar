import ComposableArchitecture
import Clocks
import XCTest

@testable import V2Bar

@MainActor
final class AppFeatureTests: XCTestCase {
    func testTaskWithoutTokenOnlyLoadsLaunchAtLoginStatus() async {
        let store = TestStore(initialState: AppFeature.State(token: "")) {
            AppFeature()
        } withDependencies: {
            $0.launchAtLoginClient.status = { .requiresApproval }
            $0.v2exClient.fetchTokenInfo = { _ in XCTFail("Unexpected request"); throw V2EXClientError.invalidResponse }
            $0.v2exClient.fetchProfile = { _ in XCTFail("Unexpected request"); throw V2EXClientError.invalidResponse }
            $0.v2exClient.fetchNotifications = { _ in XCTFail("Unexpected request"); throw V2EXClientError.invalidResponse }
        }

        await store.send(.task)
        await store.receive(.launchAtLoginResponse(.requiresApproval)) {
            $0.launchAtLoginStatus = .requiresApproval
        }
    }

    func testTaskWithTokenFetchesAccountAndNotifications() async {
        let calls = StartupRefreshCallRecorder()
        let store = TestStore(initialState: AppFeature.State(token: "token")) {
            AppFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_000)
            $0.launchAtLoginClient.status = { .disabled }
            $0.v2exClient.fetchTokenInfo = { token in
                await calls.recordTokenInfo(token)
                return .fixture
            }
            $0.v2exClient.fetchProfile = { token in
                await calls.recordProfile(token)
                return .fixture(username: "yangguan")
            }
            $0.v2exClient.fetchNotifications = { token in
                await calls.recordNotifications(token)
                return [.fixture]
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.task)
        for _ in 0..<100 where await calls.totalCallCount < 3 {
            await Task.yield()
        }

        let tokenInfoTokens = await calls.tokenInfoTokens
        let profileTokens = await calls.profileTokens
        let notificationTokens = await calls.notificationTokens
        XCTAssertEqual(tokenInfoTokens, ["token"])
        XCTAssertEqual(profileTokens, ["token"])
        XCTAssertEqual(notificationTokens, ["token"])
    }

    func testReadmeDemoIgnoresTokenActions() async {
        let store = TestStore(
            initialState: AppFeature.State(token: "demo-token", isReadmeDemo: true)
        ) {
            AppFeature()
        } withDependencies: {
            $0.tokenPromptClient.prompt = { _ in
                XCTFail("README demo must not prompt for a token")
                return nil
            }
            $0.v2exClient.validateToken = { _ in
                XCTFail("README demo must not validate tokens")
                throw V2EXClientError.invalidResponse
            }
            $0.v2exClient.fetchTokenInfo = { _ in
                XCTFail("README demo must not refresh")
                throw V2EXClientError.invalidResponse
            }
        }

        await store.send(.autoRefreshModeTapped(.fiveMinutes))
        await store.send(.tokenEditTapped)
        await store.send(.tokenPromptResponse("new-token"))
    }

    func testReadmeDemoIgnoresSystemMutationActions() async {
        let store = TestStore(
            initialState: AppFeature.State(token: "demo-token", isReadmeDemo: true)
        ) {
            AppFeature()
        } withDependencies: {
            $0.launchAtLoginClient.setEnabled = { _ in
                XCTFail("README demo must not change launch at login")
            }
            $0.updaterClient.checkForUpdates = {
                XCTFail("README demo must not start the updater")
            }
        }

        await store.send(.launchAtLoginTapped(true))
        await store.send(.checkForUpdatesTapped)
    }

    func testLaunchAtLoginIgnoresChangesWhileSetting() async {
        let calls = LaunchAtLoginCallRecorder()
        let gate = AsyncStream<Void>.makeStream()
        let store = TestStore(initialState: AppFeature.State(token: "token")) {
            AppFeature()
        } withDependencies: {
            $0.launchAtLoginClient.setEnabled = { enabled in
                await calls.append(enabled)
                if !enabled {
                    for await _ in gate.stream { break }
                }
            }
            $0.launchAtLoginClient.status = { .disabled }
        }
        await store.send(.launchAtLoginTapped(false)) {
            $0.isSettingLaunchAtLogin = true
        }
        for _ in 0..<100 where await calls.values.count < 1 {
            await Task.yield()
        }
        await store.send(.launchAtLoginTapped(true))
        for _ in 0..<100 where await calls.values.count < 2 {
            await Task.yield()
        }

        let recordedValues = await calls.values
        XCTAssertEqual(recordedValues, [false])
        gate.continuation.yield()
        await store.receive(.launchAtLoginSetFinished(.disabled, nil)) {
            $0.isSettingLaunchAtLogin = false
        }
    }

    func testMenuOpenRefreshDefersResultsUntilMenuCloses() async {
        let profile = V2EXUserProfile.fixture(username: "yangguan")
        let store = TestStore(
            initialState: AppFeature.State(token: "token", autoRefreshMode: .onMenuOpen)
        ) {
            AppFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_000)
            $0.v2exClient.fetchTokenInfo = { _ in .fixture }
            $0.v2exClient.fetchProfile = { _ in profile }
            $0.v2exClient.fetchNotifications = { _ in [] }
        }

        await store.send(.menuPresented) {
            $0.isMenuOpenRefreshInFlight = true
            $0.isMenuPresented = true
        }
        XCTAssertFalse(store.state.isRefreshing)
        let refresh = RefreshResult(
            tokenInfo: .success(.fixture),
            profile: .success(profile),
            notifications: .success([]),
            avatarData: .success(nil)
        )
        await store.receive(.refreshResponse(refresh)) {
            $0.deferredRefresh = refresh
            $0.isMenuOpenRefreshInFlight = false
        }

        await store.send(.menuDismissed) {
            $0.isMenuPresented = false
            $0.tokenInfo = .fixture
            $0.profile = profile
            $0.knownNotificationIDs = []
            $0.notifications = []
            $0.deferredRefresh = nil
            $0.lastUpdated = Date(timeIntervalSince1970: 1_000)
        }
    }

    func testMenuAutoRefreshDoesNotOverwriteDeferredResult() async {
        let deferred = RefreshResult(
            tokenInfo: .success(.fixture),
            profile: .success(.fixture(username: "first-user")),
            notifications: .success([]),
            avatarData: .success(nil)
        )
        var state = AppFeature.State(token: "token", autoRefreshMode: .off)
        state.isMenuPresented = true
        state.deferredRefresh = deferred
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.v2exClient.fetchTokenInfo = { _ in
                XCTFail("Unexpected second refresh")
                throw V2EXClientError.invalidResponse
            }
        }

        XCTAssertEqual(store.state.deferredRefresh, deferred)
        await store.send(.autoRefreshModeTapped(.onMenuOpen)) {
            $0.$autoRefreshMode.withLock { $0 = .onMenuOpen }
        }
        XCTAssertEqual(store.state.deferredRefresh, deferred)
    }

    func testInvalidCandidateTokenDoesNotReplaceExistingToken() async {
        let store = TestStore(initialState: AppFeature.State(token: "old-token")) {
            AppFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_000)
            $0.v2exClient.validateToken = { _ in throw V2EXClientError.unauthorized }
            $0.tokenPromptClient.showError = { _ in }
        }

        await store.send(.tokenPromptResponse("new-token")) {
            $0.isValidatingToken = true
            $0.errorMessage = nil
        }
        await store.receive(.tokenValidationResponse("new-token", .failure(.unauthorized))) {
            $0.isValidatingToken = false
            $0.errorMessage = V2EXClientError.unauthorized.localizedDescription
        }
        XCTAssertEqual(store.state.token, "old-token")
    }

    func testLogoutClearsAccountData() async {
        var state = AppFeature.State(token: "token")
        state.tokenInfo = .fixture
        state.profile = .fixture(username: "yangguan")
        state.notifications = [.fixture]
        state.knownNotificationIDs = [V2EXNotification.fixture.id]
        state.newNotificationIDs = [V2EXNotification.fixture.id]

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.logoutTapped) {
            $0.$token.withLock { $0 = "" }
            $0.tokenInfo = nil
            $0.profile = nil
            $0.knownNotificationIDs = nil
            $0.newNotificationIDs = []
            $0.notifications = []
            $0.avatarData = nil
            $0.errorMessage = nil
            $0.inFlightRefreshes = []
            $0.deferredRefresh = nil
        }
    }

    func testPartialRefreshPreservesPreviousProfile() async {
        let oldProfile = V2EXUserProfile.fixture(username: "old-user")
        var state = AppFeature.State(token: "token")
        state.profile = oldProfile
        state.inFlightRefreshes = Set(RefreshDomain.allCases)
        let now = Date(timeIntervalSince1970: 2_000)
        let refresh = RefreshResult(
            tokenInfo: .success(.fixture),
            profile: .failure(.transport("offline")),
            notifications: .success([.fixture])
        )
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = now
        }

        await store.send(.refreshResponse(refresh)) {
            $0.inFlightRefreshes = []
            $0.tokenInfo = .fixture
            $0.knownNotificationIDs = [V2EXNotification.fixture.id]
            $0.notifications = [.fixture]
            $0.errorMessage = "offline"
            $0.lastUpdated = now
        }
        XCTAssertEqual(store.state.profile, oldProfile)
    }

    func testFailedRefreshPreservesLastUpdated() async {
        let previousUpdate = Date(timeIntervalSince1970: 1_000)
        var state = AppFeature.State(token: "token")
        state.lastUpdated = previousUpdate
        state.inFlightRefreshes = Set(RefreshDomain.allCases)
        let failure = Result<V2EXTokenInfo, V2EXClientError>.failure(.transport("offline"))
        let refresh = RefreshResult(
            tokenInfo: failure,
            profile: .failure(.transport("offline")),
            notifications: .failure(.transport("offline"))
        )
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 2_000)
        }

        await store.send(.refreshResponse(refresh)) {
            $0.inFlightRefreshes = []
            $0.errorMessage = "offline"
        }
        XCTAssertEqual(store.state.lastUpdated, previousUpdate)
    }

    func testAutoRefreshCanBeTurnedOff() async {
        let store = TestStore(initialState: AppFeature.State(token: "token")) {
            AppFeature()
        }

        await store.send(.autoRefreshModeTapped(.off)) {
            $0.$autoRefreshMode.withLock { $0 = .off }
        }
    }

    func testAutoRefreshWithoutTokenDoesNotStartTimer() async {
        let clock = TestClock()
        let store = TestStore(initialState: AppFeature.State(token: "")) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.autoRefreshModeTapped(.fiveMinutes)) {
            $0.$autoRefreshMode.withLock { $0 = .fiveMinutes }
        }
        await clock.advance(by: .seconds(300))
    }

    func testAppStorageLoadsLegacyTokenAndRefreshMode() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set("legacy-token", forKey: "token")
        defaults.set(AutoRefreshMode.fifteenMinutes.rawValue, forKey: "autoRefreshMode")

        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = AppFeature.State()
            XCTAssertEqual(state.token, "legacy-token")
            XCTAssertEqual(state.autoRefreshMode, .fifteenMinutes)
        }
    }

    func testRecentNotificationsRemainChronologicalAndLimitedToTen() {
        var state = AppFeature.State(token: "token")
        state.notifications = (0..<12).map { index in
            V2EXNotification(
                id: index,
                memberId: index,
                forMemberId: 1,
                text: "通知 \(index)",
                payload: nil,
                payloadRendered: "",
                created: index,
                member: .init(username: "member\(index)")
            )
        }

        XCTAssertEqual(state.recentNotifications.map(\.id), Array((2..<12).reversed()))
    }

    func testRecentNotificationGroupsMergeTopicsAndLimitToFive() {
        var state = AppFeature.State(token: "token")
        state.notifications = [
            notification(id: 12, topicID: 100, created: 12),
            notification(id: 11, topicID: 100, created: 11),
            notification(id: 10, topicID: 200, created: 10),
            notification(id: 9, topicID: 300, created: 9),
            notification(id: 8, topicID: 400, created: 8),
            notification(id: 7, topicID: 500, created: 7),
            notification(id: 6, topicID: 600, created: 6),
            notification(id: 5, topicID: 700, created: 5),
            notification(id: 4, topicID: 800, created: 4),
            notification(id: 3, topicID: 900, created: 3),
            notification(id: 2, topicID: 1_000, created: 2),
            notification(id: 1, topicID: 1_100, created: 1),
        ]

        XCTAssertEqual(
            state.recentNotificationGroups.map(\.id),
            [.topic(100), .topic(200), .topic(300), .topic(400), .topic(500)]
        )
        XCTAssertEqual(state.recentNotificationGroups.first?.notifications.map(\.id), [12, 11])
    }

    func testNotificationRefreshTracksNewIDsAfterInitialBaseline() async {
        let initial = notification(id: 1, topicID: 100, created: 1)
        let added = notification(id: 2, topicID: 100, created: 2)
        let store = TestStore(initialState: AppFeature.State(token: "token")) {
            AppFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_000)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.refreshResponse(refreshResult(notifications: .success([initial]))))
        XCTAssertEqual(store.state.knownNotificationIDs, [initial.id])
        XCTAssertTrue(store.state.newNotificationIDs.isEmpty)

        await store.send(.refreshResponse(refreshResult(notifications: .success([added, initial]))))
        XCTAssertEqual(store.state.knownNotificationIDs, [initial.id, added.id])
        XCTAssertEqual(store.state.newNotificationIDs, [added.id])

        await store.send(.refreshResponse(refreshResult(notifications: .success([added, initial]))))
        XCTAssertEqual(store.state.newNotificationIDs, [added.id])
    }

    func testOpeningNotificationClearsNewStateForItsTopic() async {
        let first = notification(id: 1, topicID: 100, created: 1)
        let second = notification(id: 2, topicID: 100, created: 2)
        var openedURL: URL?
        var state = AppFeature.State(token: "token")
        state.notifications = [second, first]
        state.knownNotificationIDs = [first.id, second.id]
        state.newNotificationIDs = [first.id, second.id]
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.applicationClient.open = {
                openedURL = $0
                return true
            }
        }

        await store.send(.notificationTapped(second.id)) {
            $0.newNotificationIDs = []
        }
        XCTAssertEqual(openedURL, URL(string: "https://www.v2ex.com/t/100#reply2"))
    }

    func testOpeningNotificationGroupUsesCanonicalTopicURL() async {
        let notification = notification(id: 1, topicID: 100, created: 1)
        var openedURL: URL?
        var state = AppFeature.State(token: "token")
        state.notifications = [notification]
        state.knownNotificationIDs = [notification.id]
        state.newNotificationIDs = [notification.id]
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.applicationClient.open = {
                openedURL = $0
                return true
            }
        }

        await store.send(.notificationGroupOpenTapped(.topic(100))) {
            $0.newNotificationIDs = []
        }
        XCTAssertEqual(openedURL, URL(string: "https://www.v2ex.com/t/100"))
    }

    func testFailedNotificationRefreshDoesNotCreateBaseline() async {
        let initial = notification(id: 1, topicID: 100, created: 1)
        let store = TestStore(initialState: AppFeature.State(token: "token")) {
            AppFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_000)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.refreshResponse(refreshResult(notifications: .failure(.transport("offline")))))
        XCTAssertNil(store.state.knownNotificationIDs)

        await store.send(.refreshResponse(refreshResult(notifications: .success([initial]))))
        XCTAssertEqual(store.state.knownNotificationIDs, [initial.id])
        XCTAssertTrue(store.state.newNotificationIDs.isEmpty)
    }

    func testAccountRefreshStatus() {
        var state = AppFeature.State(token: "token")
        XCTAssertEqual(state.accountRefreshStatus, .notUpdated)

        let date = Date(timeIntervalSince1970: 1_000)
        state.lastUpdated = date
        XCTAssertEqual(state.accountRefreshStatus, .updated(date))

        state.inFlightRefreshes = [.profile]
        XCTAssertEqual(state.accountRefreshStatus, .refreshing)
    }

    private func notification(id: Int, topicID: Int, created: Int) -> V2EXNotification {
        V2EXNotification(
            id: id,
            memberId: id,
            forMemberId: 1,
            text: #"<a href="/member/member\#(id)">member\#(id)</a> 回复了 <a href="/t/\#(topicID)#reply\#(id)">主题 \#(topicID)</a>"#,
            payload: "回复 \(id)",
            payloadRendered: "回复 \(id)",
            created: created,
            member: .init(username: "member\(id)")
        )
    }

    private func refreshResult(
        notifications: Result<[V2EXNotification], V2EXClientError>
    ) -> RefreshResult {
        RefreshResult(
            tokenInfo: .failure(.transport("ignored")),
            profile: .failure(.transport("ignored")),
            notifications: notifications
        )
    }
}

private extension V2EXTokenInfo {
    static let fixture = Self(
        token: "token",
        scope: "everything",
        expiration: 86_400,
        goodForDays: 1,
        totalUsed: 1,
        lastUsed: 1,
        created: 1
    )
}

private actor LaunchAtLoginCallRecorder {
    private(set) var values: [Bool] = []

    func append(_ value: Bool) {
        values.append(value)
    }
}

private actor StartupRefreshCallRecorder {
    private(set) var notificationTokens: [String] = []
    private(set) var profileTokens: [String] = []
    private(set) var tokenInfoTokens: [String] = []

    var totalCallCount: Int {
        notificationTokens.count + profileTokens.count + tokenInfoTokens.count
    }

    func recordTokenInfo(_ token: String) {
        tokenInfoTokens.append(token)
    }

    func recordProfile(_ token: String) {
        profileTokens.append(token)
    }

    func recordNotifications(_ token: String) {
        notificationTokens.append(token)
    }
}

private extension V2EXUserProfile {
    static func fixture(username: String) -> Self {
        Self(
            id: 1,
            username: username,
            url: "https://www.v2ex.com/member/\(username)",
            website: nil,
            twitter: nil,
            psn: nil,
            github: nil,
            btc: nil,
            location: nil,
            tagline: nil,
            bio: nil,
            avatarMini: nil,
            avatarNormal: nil,
            avatarLarge: nil,
            avatarXlarge: nil,
            avatarXxlarge: nil,
            created: 1,
            lastModified: 1
        )
    }
}

private extension V2EXNotification {
    static let fixture = Self(
        id: 1,
        memberId: 1,
        forMemberId: 2,
        text: "回复了主题",
        payload: "回复内容",
        payloadRendered: "回复内容",
        created: 1,
        member: .init(username: "member")
    )
}
