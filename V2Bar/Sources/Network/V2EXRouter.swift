import Alamofire
import Foundation

enum V2EXRouter: URLRequestConvertible, Sendable {
    case token(token: String)
    case profile(token: String)
    case notifications(token: String)

    private var path: String {
        switch self {
        case .token:
            "/token"
        case .profile:
            "/member"
        case .notifications:
            "/notifications"
        }
    }

    private var accessToken: String {
        switch self {
        case let .token(token), let .profile(token), let .notifications(token):
            token
        }
    }

    func asURLRequest() throws -> URLRequest {
        var request = URLRequest(
            url: URL(string: "https://www.v2ex.com/api/v2")!.appendingPathComponent(path)
        )
        request.method = .get
        request.headers = [
            .accept("application/json"),
            .authorization(bearerToken: accessToken),
        ]
        return request
    }
}
