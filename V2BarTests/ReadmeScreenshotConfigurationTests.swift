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

    func testDemoStateIncludesReplyFavoriteAndThanks() throws {
        let configuration = try XCTUnwrap(ReadmeScreenshotConfiguration(arguments: ["--readme-demo"]))

        let notifications = configuration.initialState(now: Date(timeIntervalSince1970: 10_000)).recentNotifications

        XCTAssertEqual(Array(notifications.prefix(3).map(\.kind)), [.reply, .favorite, .thanks])
        XCTAssertEqual(notifications.first?.menuTitle, "原生菜单的最近回复现在更清晰了，正文一眼就能看到。")
    }
}
