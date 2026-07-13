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

    func testNotificationTopicIdentityIgnoresReplyFragment() {
        let notification = makeNotification(
            text: #"<a href="/member/alice">alice</a> 回复了 <a href="/t/123?p=2#reply9">主题</a>"#,
            payload: "回复内容"
        )

        XCTAssertEqual(notification.topicID, 123)
        XCTAssertEqual(notification.canonicalTopicURL, URL(string: "https://www.v2ex.com/t/123"))
    }

    func testNotificationTopicGroupsMergeEventsAndBuildSummary() throws {
        let reply = makeNotification(
            id: 3,
            memberId: 1,
            text: #"<a href="/member/alice">alice</a> 回复了 <a href="/t/123#reply3">TypeSwitch</a>"#,
            payload: "完整回复内容",
            created: 3,
            username: "alice"
        )
        let thanks = makeNotification(
            id: 2,
            memberId: 2,
            text: #"<a href="/member/bob">bob</a> 感谢了 <a href="/t/123">TypeSwitch</a>"#,
            payload: nil,
            created: 2,
            username: "bob"
        )
        let otherTopic = makeNotification(
            id: 1,
            memberId: 3,
            text: #"<a href="/member/carol">carol</a> 收藏了 <a href="/t/456">V2Bar</a>"#,
            payload: nil,
            created: 1,
            username: "carol"
        )

        let groups = NotificationTopicGroup.makeGroups(
            from: [otherTopic, thanks, reply],
            newNotificationIDs: [reply.id],
            limit: 5
        )
        let group = try XCTUnwrap(groups.first)

        XCTAssertEqual(groups.map(\.id), [.topic(123), .topic(456)])
        XCTAssertEqual(group.notifications.map(\.id), [3, 2])
        XCTAssertEqual(group.title, "TypeSwitch")
        XCTAssertEqual(group.replyCount, 1)
        XCTAssertEqual(group.thanksCount, 1)
        XCTAssertEqual(group.newReplyCount, 1)
        XCTAssertEqual(
            group.summary,
            NotificationGroupSummary(
                leadingSystemImage: "bubble.left.fill",
                texts: ["1 条新回复", "1 个感谢"]
            )
        )
        XCTAssertEqual(group.members.map(\.username), ["alice", "bob"])
    }

    func testNotificationWithoutTopicRemainsIndependent() {
        let notification = makeNotification(
            id: 7,
            text: "系统通知",
            payload: nil
        )

        let groups = NotificationTopicGroup.makeGroups(
            from: [notification],
            newNotificationIDs: [],
            limit: 5
        )

        XCTAssertEqual(groups.map(\.id), [.notification(7)])
        XCTAssertEqual(groups.first?.title, "系统通知")
    }

    func testNewSystemNotificationUsesNotificationSummary() throws {
        let notification = makeNotification(
            id: 7,
            text: "系统通知",
            payload: nil
        )

        let group = try XCTUnwrap(
            NotificationTopicGroup.makeGroups(
                from: [notification],
                newNotificationIDs: [notification.id],
                limit: 5
            ).first
        )

        XCTAssertEqual(
            group.summary,
            NotificationGroupSummary(
                leadingSystemImage: "bell.badge.fill",
                texts: ["1 条新通知"]
            )
        )
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
        id: Int = 1,
        memberId: Int = 1,
        text: String = #"<a href="/member/alice">alice</a> 回复了 <a href="/t/123#reply1">主题</a>"#,
        payload: String?,
        created: Int = 1,
        username: String = "alice"
    ) -> V2EXNotification {
        V2EXNotification(
            id: id,
            memberId: memberId,
            forMemberId: 2,
            text: text,
            payload: payload,
            payloadRendered: "",
            created: created,
            member: .init(username: username)
        )
    }
}
