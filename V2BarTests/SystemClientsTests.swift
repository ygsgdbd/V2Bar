import AppKit
import ComposableArchitecture
import ServiceManagement
import XCTest
@testable import V2Bar

final class SystemClientsTests: XCTestCase {
    @MainActor
    func testApplicationClientForwardsSystemActions() {
        let recorder = ApplicationRecorder()
        let url = URL(string: "https://www.v2ex.com")!
        let client = ApplicationClient(
            open: { receivedURL in
                recorder.openedURL = receivedURL
                return true
            },
            openLoginItemsSettings: {
                recorder.didOpenLoginItemsSettings = true
            },
            quit: {
                recorder.didQuit = true
            }
        )

        XCTAssertTrue(client.open(url))
        client.openLoginItemsSettings()
        client.quit()

        XCTAssertEqual(recorder.openedURL, url)
        XCTAssertTrue(recorder.didOpenLoginItemsSettings)
        XCTAssertTrue(recorder.didQuit)
    }

    func testLaunchAtLoginStatusMapsServiceManagementStatuses() {
        XCTAssertEqual(LaunchAtLoginStatus(.enabled), .enabled)
        XCTAssertEqual(LaunchAtLoginStatus(.notRegistered), .disabled)
        XCTAssertEqual(LaunchAtLoginStatus(.requiresApproval), .requiresApproval)
        XCTAssertEqual(LaunchAtLoginStatus(.notFound), .unavailable)
    }

    func testLaunchAtLoginClientForwardsStatusAndSetting() async throws {
        let recorder = LaunchAtLoginRecorder()
        let client = LaunchAtLoginClient(
            status: { .requiresApproval },
            setEnabled: { isEnabled in
                await recorder.record(isEnabled)
            }
        )

        let status = await client.status()
        try await client.setEnabled(false)
        let isEnabled = await recorder.value

        XCTAssertEqual(status, .requiresApproval)
        XCTAssertEqual(isEnabled, false)
    }

    func testLaunchAtLoginStatusUsesOnlyValidFallbackForCurrentExecutable() throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        var cleanupCalls: [[String]] = []

        try fixture.writeLaunchAgent(executablePath: fixture.executableURL.path)
        XCTAssertEqual(
            LaunchAtLoginClient.status(environment: fixture.environment()),
            .enabled
        )
        XCTAssertEqual(
            LaunchAtLoginClient.status(
                environment: fixture.environment(legacyPlistStatus: { _ in .requiresApproval })
            ),
            .requiresApproval
        )
        XCTAssertEqual(
            LaunchAtLoginClient.status(
                environment: fixture.environment(legacyPlistStatus: { _ in .notRegistered })
            ),
            .disabled
        )

        try fixture.writeLaunchAgent(
            executablePath: "/Applications/OldV2Bar.app/Contents/MacOS/V2Bar"
        )
        XCTAssertEqual(
            LaunchAtLoginClient.status(
                environment: fixture.environment(
                    runLaunchctl: { cleanupCalls.append($0) }
                )
            ),
            .disabled
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))

        try Data("not a property list".utf8).write(to: fixture.plistURL, options: .atomic)
        XCTAssertEqual(
            LaunchAtLoginClient.status(
                environment: fixture.environment(
                    runLaunchctl: { cleanupCalls.append($0) }
                )
            ),
            .disabled
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))

        try fixture.writeLaunchAgent(
            executablePath: fixture.executableURL.path,
            runAtLoad: false
        )
        XCTAssertEqual(
            LaunchAtLoginClient.status(
                environment: fixture.environment(
                    runLaunchctl: { cleanupCalls.append($0) }
                )
            ),
            .disabled
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))
        XCTAssertEqual(
            cleanupCalls,
            Array(repeating: ["bootout", fixture.serviceTarget], count: 3)
        )
    }

    func testLaunchAtLoginStatusDoesNotReportDisabledWhenStaleFallbackBootoutFails() throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        try fixture.writeLaunchAgent(
            executablePath: "/Applications/OldV2Bar.app/Contents/MacOS/V2Bar"
        )

        let status = LaunchAtLoginClient.status(
            environment: fixture.environment(
                runLaunchctl: { _ in throw NSError(domain: "bootout", code: 1) }
            )
        )

        XCTAssertEqual(status, .enabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))
    }

    func testLaunchAtLoginInstallsFallbackWhenNativeServiceRequiresApproval() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        var launchctlCalls: [[String]] = []

        let environment = fixture.environment(
            serviceManagementStatus: { .requiresApproval },
            runLaunchctl: { launchctlCalls.append($0) }
        )
        try await LaunchAtLoginClient.setEnabled(true, environment: environment)

        XCTAssertEqual(LaunchAtLoginClient.status(environment: environment), .enabled)
        XCTAssertEqual(
            launchctlCalls,
            [
                ["bootout", fixture.serviceTarget],
                ["bootstrap", "gui/501", fixture.stagingPlistURL.path],
            ]
        )
        let plist = try fixture.propertyList()
        XCTAssertEqual(plist["ProgramArguments"] as? [String], [fixture.executableURL.path])
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stagingDirectoryURL.path))
    }

    func testLaunchAtLoginInstallsFallbackWhenNativeRegistrationFails() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }

        let environment = fixture.environment(
            registerMainApp: { throw NSError(domain: "register", code: 1) }
        )
        try await LaunchAtLoginClient.setEnabled(true, environment: environment)

        XCTAssertEqual(LaunchAtLoginClient.status(environment: environment), .enabled)
        XCTAssertEqual(
            try fixture.propertyList()["ProgramArguments"] as? [String],
            [fixture.executableURL.path]
        )
    }

    func testLaunchAtLoginNativeSuccessRemovesFallback() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        try fixture.writeLaunchAgent(executablePath: fixture.executableURL.path)
        let nativeStatus = NativeLaunchAtLoginStatus(.notRegistered)
        var launchctlCalls: [[String]] = []

        let environment = fixture.environment(
            serviceManagementStatus: { nativeStatus.value },
            registerMainApp: { nativeStatus.value = .enabled },
            runLaunchctl: { launchctlCalls.append($0) }
        )
        try await LaunchAtLoginClient.setEnabled(true, environment: environment)

        XCTAssertEqual(launchctlCalls, [["bootout", fixture.serviceTarget]])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))
    }

    func testLaunchAtLoginNativeSuccessReturnsFallbackCleanupFailure() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        try fixture.writeLaunchAgent(executablePath: fixture.executableURL.path)
        let nativeStatus = NativeLaunchAtLoginStatus(.notRegistered)

        do {
            try await LaunchAtLoginClient.setEnabled(
                true,
                environment: fixture.environment(
                    serviceManagementStatus: { nativeStatus.value },
                    registerMainApp: { nativeStatus.value = .enabled },
                    runLaunchctl: { _ in throw NSError(domain: "bootout", code: 1) }
                )
            )
            XCTFail("Expected fallback cleanup failure")
        } catch {
            XCTAssertEqual((error as NSError).domain, "bootout")
        }

        XCTAssertEqual(nativeStatus.value, .enabled)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))
    }

    func testLaunchAtLoginDisableIgnoresNativeNotRegisteredErrorAndRemovesFallback() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        try fixture.writeLaunchAgent(executablePath: fixture.executableURL.path)
        var launchctlCalls: [[String]] = []

        try await LaunchAtLoginClient.setEnabled(
            false,
            environment: fixture.environment(
                unregisterMainApp: { throw NSError(domain: "unregister", code: 1) },
                runLaunchctl: { launchctlCalls.append($0) }
            )
        )

        XCTAssertEqual(launchctlCalls, [["bootout", fixture.serviceTarget]])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))
    }

    func testLaunchAtLoginDisableReturnsNativeErrorWhenNativeServiceRemainsEnabled() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }

        do {
            try await LaunchAtLoginClient.setEnabled(
                false,
                environment: fixture.environment(
                    serviceManagementStatus: { .enabled },
                    unregisterMainApp: { throw NSError(domain: "unregister", code: 1) }
                )
            )
            XCTFail("Expected native unregister failure")
        } catch {
            XCTAssertEqual((error as NSError).domain, "unregister")
        }
    }

    func testLaunchAtLoginDisableReturnsBootoutFailureAfterRemovingPlist() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        try fixture.writeLaunchAgent(executablePath: fixture.executableURL.path)

        do {
            try await LaunchAtLoginClient.setEnabled(
                false,
                environment: fixture.environment(
                    runLaunchctl: { _ in throw NSError(domain: "bootout", code: 1) }
                )
            )
            XCTFail("Expected fallback bootout failure")
        } catch {
            XCTAssertEqual((error as NSError).domain, "bootout")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))
    }

    func testLaunchAtLoginDisableReturnsPlistRemovalFailure() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        try fixture.writeLaunchAgent(executablePath: fixture.executableURL.path)

        do {
            try await LaunchAtLoginClient.setEnabled(
                false,
                environment: fixture.environment(
                    removeItemAt: { _ in throw NSError(domain: "remove", code: 1) }
                )
            )
            XCTFail("Expected fallback plist removal failure")
        } catch {
            XCTAssertEqual((error as NSError).domain, "remove")
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.plistURL.path))
    }

    func testLaunchAtLoginFirstInstallFailureLeavesNoFallbackFiles() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        var launchctlCalls: [[String]] = []

        do {
            try await LaunchAtLoginClient.setEnabled(
                true,
                environment: fixture.environment(
                    serviceManagementStatus: { .requiresApproval },
                    runLaunchctl: { arguments in
                        launchctlCalls.append(arguments)
                        if arguments.first == "bootstrap" {
                            throw NSError(domain: "bootstrap", code: 1)
                        }
                    }
                )
            )
            XCTFail("Expected fallback bootstrap failure")
        } catch {
            XCTAssertEqual((error as NSError).domain, "bootstrap")
        }

        XCTAssertEqual(
            launchctlCalls,
            [
                ["bootout", fixture.serviceTarget],
                ["bootstrap", "gui/501", fixture.stagingPlistURL.path],
                ["bootout", fixture.serviceTarget],
            ]
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stagingDirectoryURL.path))
    }

    func testLaunchAtLoginFirstInstallMoveFailureRollsBackBootstrapAndFiles() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        var launchctlCalls: [[String]] = []

        do {
            try await LaunchAtLoginClient.setEnabled(
                true,
                environment: fixture.environment(
                    serviceManagementStatus: { .requiresApproval },
                    runLaunchctl: { launchctlCalls.append($0) },
                    moveItemAt: { _, _ in throw NSError(domain: "move", code: 1) }
                )
            )
            XCTFail("Expected fallback move failure")
        } catch {
            XCTAssertEqual((error as NSError).domain, "move")
        }

        XCTAssertEqual(
            launchctlCalls,
            [
                ["bootout", fixture.serviceTarget],
                ["bootstrap", "gui/501", fixture.stagingPlistURL.path],
                ["bootout", fixture.serviceTarget],
            ]
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.plistURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stagingDirectoryURL.path))
    }

    func testLaunchAtLoginReplacementFailureRestoresPlistAndBootstrap() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        let originalExecutablePath = "/Applications/OriginalV2Bar.app/Contents/MacOS/V2Bar"
        try fixture.writeLaunchAgent(
            executablePath: originalExecutablePath,
            additionalProperties: ["PreservedValue": ["nested", "value"]]
        )
        let originalPlistData = try Data(contentsOf: fixture.plistURL)
        var launchctlCalls: [[String]] = []

        do {
            try await LaunchAtLoginClient.setEnabled(
                true,
                environment: fixture.environment(
                    serviceManagementStatus: { .requiresApproval },
                    runLaunchctl: { launchctlCalls.append($0) },
                    replaceItemAt: { originalItemURL, _ in
                        try FileManager.default.removeItem(at: originalItemURL)
                        throw NSError(domain: "replace", code: 1)
                    }
                )
            )
            XCTFail("Expected fallback replacement failure")
        } catch {
            XCTAssertEqual((error as NSError).domain, "replace")
        }

        XCTAssertEqual(try Data(contentsOf: fixture.plistURL), originalPlistData)
        XCTAssertEqual(
            launchctlCalls,
            [
                ["bootout", fixture.serviceTarget],
                ["bootstrap", "gui/501", fixture.stagingPlistURL.path],
                ["bootout", fixture.serviceTarget],
                ["bootstrap", "gui/501", fixture.plistURL.path],
            ]
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stagingDirectoryURL.path))
    }

    func testLaunchAtLoginRecoveryBootstrapFailureIsReturnedAfterPlistRestore() async throws {
        let fixture = try LaunchAtLoginFixture()
        defer { fixture.cleanUp() }
        try fixture.writeLaunchAgent(
            executablePath: fixture.executableURL.path,
            additionalProperties: ["PreservedValue": "original"]
        )
        let originalPlistData = try Data(contentsOf: fixture.plistURL)
        var launchctlCalls: [[String]] = []

        do {
            try await LaunchAtLoginClient.setEnabled(
                true,
                environment: fixture.environment(
                    serviceManagementStatus: { .requiresApproval },
                    runLaunchctl: { arguments in
                        launchctlCalls.append(arguments)
                        if arguments == ["bootstrap", "gui/501", fixture.plistURL.path] {
                            throw NSError(domain: "recovery-bootstrap", code: 1)
                        }
                    },
                    replaceItemAt: { originalItemURL, _ in
                        try FileManager.default.removeItem(at: originalItemURL)
                        throw NSError(domain: "replace", code: 1)
                    }
                )
            )
            XCTFail("Expected recovery bootstrap failure")
        } catch {
            XCTAssertEqual((error as NSError).domain, "recovery-bootstrap")
        }

        XCTAssertEqual(try Data(contentsOf: fixture.plistURL), originalPlistData)
        XCTAssertEqual(
            launchctlCalls,
            [
                ["bootout", fixture.serviceTarget],
                ["bootstrap", "gui/501", fixture.stagingPlistURL.path],
                ["bootout", fixture.serviceTarget],
                ["bootstrap", "gui/501", fixture.plistURL.path],
            ]
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stagingDirectoryURL.path))
    }

    @MainActor
    func testTokenPromptClientForwardsPromptAndErrorPresentation() {
        let recorder = TokenPromptRecorder()
        let client = TokenPromptClient(
            prompt: { existingToken in
                recorder.existingToken = existingToken
                return "new-token"
            },
            showError: { message in
                recorder.errorMessage = message
            }
        )

        XCTAssertEqual(client.prompt("old-token"), "new-token")
        client.showError("设置失败")

        XCTAssertEqual(recorder.existingToken, "old-token")
        XCTAssertEqual(recorder.errorMessage, "设置失败")
    }

    @MainActor
    func testUpdaterClientInvokesInjectedCheckClosure() {
        var invocationCount = 0
        let client = UpdaterClient {
            invocationCount += 1
        }

        client.checkForUpdates()

        XCTAssertEqual(invocationCount, 1)
    }

    func testSystemClientsCanBeInjectedThroughDependencyValues() {
        var values = DependencyValues()
        values.applicationClient = .noop
        values.launchAtLoginClient = .noop
        values.tokenPromptClient = .noop
        values.updaterClient = .noop

        _ = values.applicationClient
        _ = values.launchAtLoginClient
        _ = values.tokenPromptClient
        _ = values.updaterClient
    }
}

@MainActor
private final class ApplicationRecorder {
    var openedURL: URL?
    var didOpenLoginItemsSettings = false
    var didQuit = false
}

private actor LaunchAtLoginRecorder {
    var value: Bool?

    func record(_ value: Bool) {
        self.value = value
    }
}

private final class NativeLaunchAtLoginStatus {
    var value: SMAppService.Status

    init(_ value: SMAppService.Status) {
        self.value = value
    }
}

private struct LaunchAtLoginFixture {
    let directoryURL: URL
    let plistURL: URL
    let stagingDirectoryURL: URL
    let stagingPlistURL: URL
    let executableURL = URL(fileURLWithPath: "/Applications/V2Bar.app/Contents/MacOS/V2Bar")
    let serviceTarget = "gui/501/top.ygsgdbd.V2Bar"

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("V2BarLaunchAtLoginTests-\(UUID().uuidString)", isDirectory: true)
        plistURL = directoryURL.appendingPathComponent("top.ygsgdbd.V2Bar.plist")
        stagingDirectoryURL = directoryURL
            .appendingPathComponent(".top.ygsgdbd.V2Bar.staging", isDirectory: true)
        stagingPlistURL = stagingDirectoryURL
            .appendingPathComponent("top.ygsgdbd.V2Bar.plist")
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func environment(
        serviceManagementStatus: @escaping () -> SMAppService.Status = { .notRegistered },
        legacyPlistStatus: @escaping (URL) -> SMAppService.Status = { _ in .enabled },
        registerMainApp: @escaping () throws -> Void = {},
        unregisterMainApp: @escaping () async throws -> Void = {},
        runLaunchctl: @escaping ([String]) throws -> Void = { _ in },
        moveItemAt: ((URL, URL) throws -> Void)? = nil,
        removeItemAt: ((URL) throws -> Void)? = nil,
        replaceItemAt: ((URL, URL) throws -> Void)? = nil
    ) -> LaunchAtLoginEnvironment {
        LaunchAtLoginEnvironment(
            serviceManagementStatus: serviceManagementStatus,
            legacyPlistStatus: legacyPlistStatus,
            registerMainApp: registerMainApp,
            unregisterMainApp: unregisterMainApp,
            plistURL: plistURL,
            executableURL: { executableURL },
            runLaunchctl: runLaunchctl,
            userID: { 501 },
            fileManager: .default,
            moveItemAt: moveItemAt ?? { sourceURL, destinationURL in
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            },
            removeItemAt: removeItemAt ?? { try FileManager.default.removeItem(at: $0) },
            replaceItemAt: replaceItemAt ?? { originalItemURL, newItemURL in
                _ = try FileManager.default.replaceItemAt(
                    originalItemURL,
                    withItemAt: newItemURL
                )
            }
        )
    }

    func writeLaunchAgent(
        executablePath: String,
        runAtLoad: Bool = true,
        additionalProperties: [String: Any] = [:]
    ) throws {
        var plist: [String: Any] = [
            "Label": "top.ygsgdbd.V2Bar",
            "ProgramArguments": [executablePath],
            "RunAtLoad": runAtLoad,
        ]
        plist.merge(additionalProperties) { _, newValue in newValue }
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)
    }

    func propertyList() throws -> [String: Any] {
        let data = try Data(contentsOf: plistURL)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
        )
    }
}

@MainActor
private final class TokenPromptRecorder {
    var existingToken: String?
    var errorMessage: String?
}
