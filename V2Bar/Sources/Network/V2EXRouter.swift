import Foundation
import Alamofire

enum V2EXRouter {
    // 通知相关
    case notifications(page: Int?)
    case deleteNotification(id: Int)
    
    // 用户相关
    case member
    case token
    case createToken(scope: TokenScope, expiration: TokenExpiration)
    
    // 节点相关
    case node(name: String)
    case nodeTopics(name: String, page: Int?)
    
    // 主题相关
    case topic(id: Int)
    case topicReplies(id: Int, page: Int?)
}

// MARK: - 辅助类型

extension V2EXRouter {
    enum TokenScope: String {
        case everything
        case regular
    }
    
    enum TokenExpiration: Int {
        case days30 = 2592000   // 30天
        case days60 = 5184000   // 60天
        case days90 = 7776000   // 90天
        case days180 = 15552000 // 180天
    }
}

extension V2EXRouter: URLRequestConvertible {
    private var baseURL: String { "https://www.v2ex.com/api/v2" }
    
    private var method: HTTPMethod {
        switch self {
        case .deleteNotification:
            return .delete
        case .createToken:
            return .post
        default:
            return .get
        }
    }
    
    private var path: String {
        switch self {
        case .notifications:
            return "/notifications"
        case .deleteNotification(let id):
            return "/notifications/\(id)"
        case .member:
            return "/member"
        case .token:
            return "/token"
        case .createToken:
            return "/tokens"
        case .node(let name):
            return "/nodes/\(name)"
        case .nodeTopics(let name, _):
            return "/nodes/\(name)/topics"
        case .topic(let id):
            return "/topics/\(id)"
        case .topicReplies(let id, _):
            return "/topics/\(id)/replies"
        }
    }
    
    private var parameters: Parameters? {
        switch self {
        case .notifications(let page):
            return page.map { ["p": $0] }
        case .nodeTopics(_, let page):
            return page.map { ["p": $0] }
        case .topicReplies(_, let page):
            return page.map { ["p": $0] }
        case .createToken(let scope, let expiration):
            return [
                "scope": scope.rawValue,
                "expiration": expiration.rawValue
            ]
        default:
            return nil
        }
    }
    
    private var encoding: ParameterEncoding {
        switch method {
        case .get:
            return URLEncoding.default
        default:
            return JSONEncoding.default
        }
    }
    
    func asURLRequest() throws -> URLRequest {
        let url = try baseURL.asURL()
        var request = URLRequest(url: url.appendingPathComponent(path))
        request.method = method
        
        // 添加通用头部
        request.headers.add(.accept("application/json"))
        request.headers.add(.userAgent("V2Bar/1.0"))
        
        // 添加认证头部（实际的 token 会在 V2EXService 中设置）
        request.headers.add(.init(name: "Authorization", value: "Bearer {token}"))
        
        // 根据不同请求方法处理参数
        if let parameters = parameters {
            request = try encoding.encode(request, with: parameters)
        }
        
        return request
    }
}

// MARK: - 便利方法
extension V2EXRouter {
    static func latestNotifications() -> V2EXRouter {
        .notifications(page: nil)
    }
    
    static func notifications(page: Int) -> V2EXRouter {
        .notifications(page: page)
    }
} 