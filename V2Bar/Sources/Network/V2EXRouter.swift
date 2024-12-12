import Foundation
import Alamofire
import Defaults

enum V2EXRouter {
    case token
    case profile
    case notifications
}

extension V2EXRouter: URLRequestConvertible {
    private var baseURL: URL {
        URL(string: "https://www.v2ex.com/api/v2")!
    }
    
    private var method: HTTPMethod {
        switch self {
        case .token, .profile, .notifications:
            return .get
        }
    }
    
    private var path: String {
        switch self {
        case .token:
            return "/token"
        case .profile:
            return "/member"
        case .notifications:
            return "/notifications"
        }
    }
    
    func asURLRequest() throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.method = method
        
        // 添加通用 headers
        request.headers = HTTPHeaders([
            .accept("application/json"),
            .authorization(bearerToken: Defaults[.token] ?? "")
        ])
        
        return request
    }
} 
