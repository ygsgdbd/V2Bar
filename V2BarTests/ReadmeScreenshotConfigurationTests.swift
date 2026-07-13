import XCTest

@testable import V2Bar

final class ReadmeScreenshotConfigurationTests: XCTestCase {
    func testHighestResolutionDisplayUsesPhysicalPixelArea() {
        let displays = [
            ReadmeScreenshotConfiguration.Display(id: 1, pixelWidth: 3_840, pixelHeight: 2_160),
            ReadmeScreenshotConfiguration.Display(id: 2, pixelWidth: 5_120, pixelHeight: 2_880),
        ]

        XCTAssertEqual(ReadmeScreenshotConfiguration.highestResolutionDisplayID(in: displays), 2)
    }

    func testDemoStateIncludesGroupedNotificationsAndNewReplySummary() throws {
        let configuration = try XCTUnwrap(ReadmeScreenshotConfiguration(arguments: ["--readme-demo"]))

        let state = configuration.initialState(now: Date(timeIntervalSince1970: 10_000))
        let groups = state.recentNotificationGroups

        XCTAssertEqual(groups.count, 4)
        XCTAssertEqual(groups.first?.title, "TypeSwitch - macOS 自动切换输入法")
        XCTAssertEqual(groups.first?.notifications.map(\.kind), [.reply, .thanks, .thanks])
        XCTAssertEqual(
            groups.first?.summary,
            NotificationGroupSummary(
                leadingSystemImage: "bubble.left.fill",
                texts: ["1 条新回复", "2 个感谢"]
            )
        )
        XCTAssertEqual(groups.first?.notifications.first?.replyTitle, "试了，好用，非常感谢！")
    }
}
