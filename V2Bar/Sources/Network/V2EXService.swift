import Foundation
import Defaults

class V2EXService {
    static let shared = V2EXService()
    private let session: URLSession
    private let baseURL = "https://www.v2ex.com/api/v2"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }
    
    // MARK: - API Methods
    func fetchCurrentToken() async throws -> Data {
        try await request(.token)
    }
    
    func fetchNotifications(page: Int = 1) async throws -> Data {
        try await request(.notifications(page: page))
    }
    
    func fetchMemberProfile() async throws -> Data {
        try await request(.member)
    }
    
    // MARK: - Private Methods
    private func request(_ router: V2EXRouter) async throws -> Data {
        guard let token = Defaults[.token], !token.isEmpty else {
            throw V2EXError.unauthorized
        }
        
        var request = URLRequest(url: router.url(baseURL: baseURL))
        request.httpMethod = router.method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("V2Bar/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw V2EXError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            return data
        case 401:
            throw V2EXError.unauthorized
        default:
            throw V2EXError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Error Types
extension V2EXService {
    enum V2EXError: LocalizedError {
        case unauthorized
        case invalidResponse
        case serverError(statusCode: Int)
        
        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "未授权，请检查访问令牌"
            case .invalidResponse:
                return "无效的响应"
            case .serverError(let statusCode):
                return "服务器错误（\(statusCode)）"
            }
        }
    }
} 
