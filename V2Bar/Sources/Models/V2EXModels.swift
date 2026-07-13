import Foundation

enum NotificationKind: Equatable, Sendable {
    case reply
    case favorite
    case thanks
    case other

    var systemImage: String {
        switch self {
        case .reply: "bubble.left"
        case .favorite: "bookmark"
        case .thanks: "heart"
        case .other: "bell"
        }
    }
}

enum NotificationGroupID: Equatable, Hashable, Sendable {
    case topic(Int)
    case notification(Int)
}

struct NotificationGroupSummary: Equatable, Sendable {
    let leadingSystemImage: String
    let texts: [String]
}

struct NotificationGroupMember: Equatable, Identifiable, Sendable {
    let id: Int
    let username: String
}

struct NotificationTopicGroup: Equatable, Identifiable, Sendable {
    let id: NotificationGroupID
    let notifications: [V2EXNotification]
    let newNotificationIDs: Set<Int>

    var title: String {
        switch id {
        case .topic:
            notifications.compactMap(\.topicTitle).first ?? notifications[0].plainText
        case .notification:
            notifications[0].menuTitle
        }
    }

    var topicURL: URL? {
        notifications.compactMap(\.canonicalTopicURL).first
    }

    var hasNew: Bool {
        !newNotificationIDs.isEmpty
    }

    var replyCount: Int {
        notifications.count { $0.kind == .reply }
    }

    var thanksCount: Int {
        notifications.count { $0.kind == .thanks }
    }

    var favoriteCount: Int {
        notifications.count { $0.kind == .favorite }
    }

    var newCount: Int {
        notifications.count { newNotificationIDs.contains($0.id) }
    }

    var newReplyCount: Int {
        notifications.count { $0.kind == .reply && newNotificationIDs.contains($0.id) }
    }

    var newInteractionCount: Int {
        notifications.count {
            $0.kind != .other && newNotificationIDs.contains($0.id)
        }
    }

    var members: [NotificationGroupMember] {
        var memberIDs: Set<Int> = []
        return notifications.compactMap { notification in
            guard memberIDs.insert(notification.memberId).inserted else { return nil }
            return NotificationGroupMember(
                id: notification.memberId,
                username: notification.member.username
            )
        }
    }

    var summary: NotificationGroupSummary {
        var leadingSystemImage: String?
        var texts: [String] = []
        if newReplyCount > 0 {
            leadingSystemImage = "bubble.left.fill"
            texts.append("\(newReplyCount) 条新回复")
        } else if newInteractionCount > 0 {
            leadingSystemImage = "bell.badge.fill"
            texts.append("\(newInteractionCount) 条新互动")
        } else if newCount > 0 {
            leadingSystemImage = "bell.badge.fill"
            texts.append("\(newCount) 条新通知")
        } else if replyCount > 0 {
            leadingSystemImage = "bubble.left"
            texts.append("\(replyCount) 条回复")
        }

        if texts.count < 2, thanksCount > 0 {
            leadingSystemImage = leadingSystemImage ?? "heart.fill"
            texts.append("\(thanksCount) 个感谢")
        }
        if texts.count < 2, favoriteCount > 0 {
            leadingSystemImage = leadingSystemImage ?? "bookmark.fill"
            texts.append("\(favoriteCount) 个收藏")
        }
        if texts.isEmpty {
            leadingSystemImage = "bell"
            texts.append("\(notifications.count) 条通知")
        }
        return NotificationGroupSummary(
            leadingSystemImage: leadingSystemImage ?? "bell",
            texts: texts
        )
    }

    static func makeGroups(
        from notifications: [V2EXNotification],
        newNotificationIDs: Set<Int>,
        limit: Int
    ) -> [Self] {
        let sortedNotifications = notifications.sorted {
            ($0.created, $0.id) > ($1.created, $1.id)
        }
        let grouped = Dictionary(grouping: sortedNotifications, by: \.groupID)
        return grouped
            .map { id, notifications in
                Self(
                    id: id,
                    notifications: notifications,
                    newNotificationIDs: newNotificationIDs.intersection(notifications.map(\.id))
                )
            }
            .sorted {
                let lhs = $0.notifications[0]
                let rhs = $1.notifications[0]
                return (lhs.created, lhs.id) > (rhs.created, rhs.id)
            }
            .prefix(limit)
            .map { $0 }
    }
}

struct V2EXResponse<Value: Codable & Sendable>: Codable, Sendable {
    let success: Bool
    let message: String?
    let result: Value?

    func getResult() throws -> Value {
        guard success else {
            throw V2EXClientError.api(message ?? "未知错误")
        }
        guard let result else {
            throw V2EXClientError.emptyResult
        }
        return result
    }
}

struct V2EXNotification: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let memberId: Int
    let forMemberId: Int
    let text: String
    let payload: String?
    let payloadRendered: String
    let created: Int
    let member: NotificationMember

    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(created))
    }

    var plainText: String {
        Self.normalizedText(text, strippingHTML: true)
    }

    var replyTitle: String {
        let normalizedPayload = payload.map { Self.normalizedText($0, strippingHTML: false) }
        if let normalizedPayload, !normalizedPayload.isEmpty {
            return normalizedPayload
        }
        return plainText
    }

    var kind: NotificationKind {
        let actionText = Self.normalizedText(
            text.replacingOccurrences(
                of: #"<a\b[^>]*>.*?</a>"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            ),
            strippingHTML: true
        )
        let classificationText = actionText.isEmpty ? plainText : actionText
        if classificationText.contains("收藏") { return .favorite }
        if classificationText.contains("感谢") { return .thanks }
        if replyTitle != plainText || classificationText.contains("回复") { return .reply }
        return .other
    }

    var topicTitle: String? {
        links.first { $0.url.path.hasPrefix("/t/") }?.title
    }

    var topicID: Int? {
        guard let topicURL else { return nil }
        let components = topicURL.pathComponents
        guard let topicIndex = components.firstIndex(of: "t"),
              components.indices.contains(topicIndex + 1)
        else {
            return nil
        }
        return Int(components[topicIndex + 1])
    }

    var canonicalTopicURL: URL? {
        guard topicID != nil, let topicURL,
              var components = URLComponents(url: topicURL, resolvingAgainstBaseURL: true)
        else {
            return nil
        }
        components.query = nil
        components.fragment = nil
        return components.url
    }

    var groupID: NotificationGroupID {
        topicID.map(NotificationGroupID.topic) ?? .notification(id)
    }

    var menuTitle: String {
        switch kind {
        case .reply:
            replyTitle
        case .favorite:
            topicTitle == nil ? plainText : "收藏了"
        case .thanks:
            topicTitle == nil ? plainText : "感谢了"
        case .other:
            plainText
        }
    }

    var links: [(title: String, url: URL)] {
        let pattern = #"<a href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges == 3,
                  let hrefRange = Range(match.range(at: 1), in: text),
                  let titleRange = Range(match.range(at: 2), in: text)
            else {
                return nil
            }
            let href = String(text[hrefRange])
            let title = Self.normalizedText(String(text[titleRange]), strippingHTML: true)
            let url = URL(string: href, relativeTo: URL(string: "https://www.v2ex.com"))?.absoluteURL
            return url.map { (title, $0) }
        }
    }

    var topicURL: URL? {
        links.first { $0.url.path.hasPrefix("/t/") }?.url
    }

    private static func normalizedText(_ value: String, strippingHTML: Bool) -> String {
        var value = value
        if strippingHTML {
            value = value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        return value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct NotificationMember: Codable, Equatable, Sendable {
    let username: String
}

struct V2EXUserProfile: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let username: String
    let url: String
    let website: String?
    let twitter: String?
    let psn: String?
    let github: String?
    let btc: String?
    let location: String?
    let tagline: String?
    let bio: String?
    let avatarMini: String?
    let avatarNormal: String?
    let avatarLarge: String?
    let avatarXlarge: String?
    let avatarXxlarge: String?
    let created: Int
    let lastModified: Int

    var profileURL: URL? { URL(string: url) }
    var websiteURL: URL? { normalizedURL(website) }
    var githubURL: URL? { socialURL(github, baseURL: "https://github.com/") }
    var twitterURL: URL? { socialURL(twitter, baseURL: "https://twitter.com/") }
    var avatarURL: URL? { normalizedURL(avatarLarge ?? avatarNormal) }

    private func normalizedURL(_ value: String?) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("//") {
            return URL(string: "https:\(value)")
        }
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(value)")
    }

    private func socialURL(_ value: String?, baseURL: String) -> URL? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return URL(string: baseURL + value)
    }
}

struct V2EXTokenInfo: Codable, Equatable, Sendable {
    let token: String
    let scope: String
    let expiration: Int
    let goodForDays: Int?
    let totalUsed: Int
    let lastUsed: Int
    let created: Int

    var expirationDate: Date? {
        guard expiration > 0 else { return nil }
        return Date().addingTimeInterval(TimeInterval(expiration))
    }
}

enum V2EXClientError: Error, Equatable, LocalizedError, Sendable {
    case invalidResponse
    case unauthorized
    case server(Int)
    case api(String)
    case emptyResult
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "无效的响应"
        case .unauthorized:
            "未授权，请检查访问令牌"
        case let .server(statusCode):
            "服务器错误（\(statusCode)）"
        case let .api(message), let .transport(message):
            message
        case .emptyResult:
            "响应数据为空"
        }
    }
}
