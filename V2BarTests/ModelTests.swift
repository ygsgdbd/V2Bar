import XCTest

@testable import V2Bar

final class ModelTests: XCTestCase {
    func testNotificationPlainTextAndTopicURL() {
        let notification = V2EXNotification(
            id: 1,
            memberId: 1,
            forMemberId: 2,
            text: #"<a href="/member/alice">alice</a> 回复了 <a href="/t/123#reply1">主题</a>"#,
            payload: nil,
            payloadRendered: "",
            created: 1,
            member: .init(username: "alice")
        )

        XCTAssertEqual(notification.plainText, "alice 回复了 主题")
        XCTAssertEqual(notification.topicURL, URL(string: "https://www.v2ex.com/t/123#reply1"))
    }

    func testNotificationReplyTitleUsesPayload() {
        let notification = makeNotification(payload: "实际回复内容")

        XCTAssertEqual(notification.replyTitle, "实际回复内容")
    }

    func testNotificationReplyTitleCollapsesWhitespace() {
        let notification = makeNotification(payload: "  第一行\n\n  第二行   内容  ")

        XCTAssertEqual(notification.replyTitle, "第一行 第二行 内容")
    }

    func testNotificationReplyTitleFallsBackToPlainText() {
        let notification = makeNotification(payload: "  \n  ")

        XCTAssertEqual(notification.replyTitle, "alice 回复了 主题")
    }

    func testNotificationKindsAndSystemImages() {
        XCTAssertEqual(
            makeNotification(text: "alice 收藏了你的主题", payload: nil).kind,
            .favorite
        )
        XCTAssertEqual(NotificationKind.favorite.systemImage, "bookmark")
        XCTAssertEqual(
            makeNotification(text: "alice 感谢了你的主题", payload: nil).kind,
            .thanks
        )
        XCTAssertEqual(NotificationKind.thanks.systemImage, "heart")
        XCTAssertEqual(makeNotification(payload: "回复内容").kind, .reply)
        XCTAssertEqual(NotificationKind.reply.systemImage, "bubble.left")
        XCTAssertEqual(makeNotification(text: "系统通知", payload: nil).kind, .other)
        XCTAssertEqual(NotificationKind.other.systemImage, "bell")
    }

    func testThanksTakesPriorityOverReplyText() {
        let notification = makeNotification(text: "alice 感谢了你在主题里的回复", payload: nil)

        XCTAssertEqual(notification.kind, .thanks)
    }

    func testTopicTitleDoesNotAffectNotificationKind() {
        let notification = makeNotification(
            text: #"<a href="/member/alice">alice</a> 回复了 <a href="/t/123">感谢大家的收藏</a>"#,
            payload: "实际回复"
        )

        XCTAssertEqual(notification.kind, .reply)
    }

    func testNotificationMenuTitlesUseKindAndKeepTopicAsContext() {
        let favorite = makeNotification(
            text: #"<a href="/member/alice">alice</a> 收藏了 <a href="/t/123">TypeSwitch &amp; V2Bar</a>"#,
            payload: nil
        )
        let thanks = makeNotification(
            text: #"<a href="/member/alice">alice</a> 感谢了 <a href="/t/123">原生菜单</a>"#,
            payload: nil
        )

        XCTAssertEqual(favorite.topicTitle, "TypeSwitch & V2Bar")
        XCTAssertEqual(favorite.menuTitle, "收藏了")
        XCTAssertEqual(thanks.topicTitle, "原生菜单")
        XCTAssertEqual(thanks.menuTitle, "感谢了")
        XCTAssertEqual(makeNotification(payload: "实际回复").menuTitle, "实际回复")
    }

    func testNotificationMenuTitleFallsBackWithoutTopicLink() {
        let notification = makeNotification(text: "alice 收藏了你的主题", payload: nil)

        XCTAssertEqual(notification.menuTitle, "alice 收藏了你的主题")
    }

    func testNotificationMenuTitleFallsBackForUnknownKind() {
        let notification = makeNotification(text: "系统通知", payload: nil)

        XCTAssertEqual(notification.menuTitle, "系统通知")
        XCTAssertNil(notification.topicTitle)
    }

    func testAutoRefreshIntervals() {
        XCTAssertNil(AutoRefreshMode.onMenuOpen.interval)
        XCTAssertEqual(AutoRefreshMode.fiveMinutes.interval, 300)
        XCTAssertEqual(AutoRefreshMode.fifteenMinutes.interval, 900)
        XCTAssertEqual(AutoRefreshMode.thirtyMinutes.interval, 1_800)
        XCTAssertNil(AutoRefreshMode.off.interval)
    }

    private func makeNotification(
        text: String = #"<a href="/member/alice">alice</a> 回复了 <a href="/t/123#reply1">主题</a>"#,
        payload: String?
    ) -> V2EXNotification {
        V2EXNotification(
            id: 1,
            memberId: 1,
            forMemberId: 2,
            text: text,
            payload: payload,
            payloadRendered: "",
            created: 1,
            member: .init(username: "alice")
        )
    }
}
