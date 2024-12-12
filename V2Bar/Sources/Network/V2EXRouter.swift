import Foundation

enum V2EXRouter {
    case token
    case notifications(page: Int)
    case member
    
    var path: String {
        switch self {
        case .token:
            return "/token"
        case .notifications:
            return "/notifications"
        case .member:
            return "/member"
        }
    }
    
    var method: String {
        switch self {
        case .token, .notifications, .member:
            return "GET"
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .notifications(let page):
            return [URLQueryItem(name: "p", value: String(page))]
        default:
            return nil
        }
    }
    
    func url(baseURL: String) -> URL {
        var components = URLComponents(string: baseURL)!
        components.path += path
        components.queryItems = queryItems
        return components.url!
    }
} 
