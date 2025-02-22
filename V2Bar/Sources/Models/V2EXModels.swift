import Foundation
import SwifterSwift

// MARK: - 通用响应结构
struct V2EXResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let result: T?
    
    // 添加自定义解码逻辑
    func getResult() throws -> T {
        guard success else {
            throw V2EXService.V2EXError.apiError(message ?? "未知错误")
        }
        
        guard let result = result else {
            throw V2EXService.V2EXError.emptyResult
        }
        
        return result
    }
}

// MARK: - 通知模型
struct V2EXNotification: Codable, Identifiable {
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
struct V2EXUserProfile: Codable, Identifiable {
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
    
    // URL 计算属性
    var websiteURL: URL? {
        if website?.isWhitespace == true {
            nil
        } else {
            website?.url
        }
    }
    
    var githubURL: URL? {
        if github?.isWhitespace == true {
            nil
        } else {
            github.map { URL(string: "https://github.com/\($0)") } ?? nil
        }
    }
    
    var twitterURL: URL? {
        if twitter?.isWhitespace == true {
            nil
        } else {
            twitter.map { URL(string: "https://twitter.com/\($0)") } ?? nil
        }
    }
}

// MARK: - Token Info
struct V2EXTokenInfo: Codable {
    let token: String
    let scope: String
    let expiration: Int
    let goodForDays: Int?
    let totalUsed: Int
    let lastUsed: Int
    let created: Int
}

extension V2EXTokenInfo {
    var formattedExpirationText: String {
        if expiration <= 0 {
            return "(已过期)"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        
        let date = Date(timeIntervalSinceNow: TimeInterval(expiration))
        let relativeTime = formatter.localizedString(for: date, relativeTo: Date())
            .replacingOccurrences(of: "后", with: "后过期")
        
        return "(\(relativeTime))"
    }
} 
