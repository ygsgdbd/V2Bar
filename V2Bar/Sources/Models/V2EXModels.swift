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
