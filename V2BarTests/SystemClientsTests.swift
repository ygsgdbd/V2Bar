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
            showAbout: {
                recorder.didShowAbout = true
            },
            openLoginItemsSettings: {
                recorder.didOpenLoginItemsSettings = true
            },
            quit: {
                recorder.didQuit = true
            }
        )

        XCTAssertTrue(client.open(url))
        client.showAbout()
        client.openLoginItemsSettings()
        client.quit()

        XCTAssertEqual(recorder.openedURL, url)
        XCTAssertTrue(recorder.didShowAbout)
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
    var didShowAbout = false
    var didOpenLoginItemsSettings = false
    var didQuit = false
}

private actor LaunchAtLoginRecorder {
    var value: Bool?

    func record(_ value: Bool) {
        self.value = value
    }
}

@MainActor
private final class TokenPromptRecorder {
    var existingToken: String?
    var errorMessage: String?
}
