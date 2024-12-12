import Foundation
import Alamofire
import Defaults

actor V2EXService {
    static let shared = V2EXService()
    private let session: Session
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        
        session = Session(configuration: configuration)
    }
    
    func request<T: Codable>(_ router: V2EXRouter) async throws -> T {
        let response = try await session.request(router)
            .validate()
            .serializingDecodable(V2EXResponse<T>.self)
            .value
        return response.result
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
