import Foundation

// MARK: - 通用响应结构
struct V2EXResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let result: T
}

// MARK: - 通知模型
struct Notification: Codable, Identifiable {
    let id: Int
    let memberId: Int
    let forMemberId: Int
    let text: String
    let payload: String?
    let payloadRendered: String
    let created: Int
    let member: NotificationMember
    
    enum CodingKeys: String, CodingKey {
        case id
        case memberId = "member_id"
        case forMemberId = "for_member_id"
        case text
        case payload
        case payloadRendered = "payload_rendered"
        case created
        case member
    }
    
    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(created))
    }
    
    // 移除 HTML 标签的纯文本
    var plainText: String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
    
    // 提取链接
    var links: [(title: String, url: URL)] {
        var result: [(String, URL)] = []
        
        // 匹配 HTML 的正则表达式
        let pattern = #"<a href="([^"]+)"[^>]*>([^<]+)</a>"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        
        if let matches = regex?.matches(in: text, range: nsRange) {
            for match in matches {
                if match.numberOfRanges == 3,
                   let pathRange = Range(match.range(at: 1), in: text),
                   let titleRange = Range(match.range(at: 2), in: text) {
                    let path = String(text[pathRange])
                    let title = String(text[titleRange])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    
                    // 构建完整的 URL
                    if let url = URL(string: "https://v2ex.com\(path)") {
                        result.append((title, url))
                    }
                }
            }
        }
        
        return result
    }
}

struct NotificationMember: Codable {
    let username: String
}

// MARK: - User Profile
struct V2EXUserProfile: Codable {
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
    
    enum CodingKeys: String, CodingKey {
        case id, username, url, website, twitter, psn, github, btc, location, tagline, bio, created
        case avatarMini = "avatar_mini"
        case avatarNormal = "avatar_normal"
        case avatarLarge = "avatar_large"
        case avatarXlarge = "avatar_xlarge"
        case avatarXxlarge = "avatar_xxlarge"
        case lastModified = "last_modified"
    }
}

// MARK: - Token Info
struct V2EXTokenInfo: Codable {
    let token: String
    let scope: String
    let expiration: Int
    let good_for: Int
    let total_used: Int
    let last_used: Int
    let created: Int
} 