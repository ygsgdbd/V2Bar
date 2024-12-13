import Foundation
import Alamofire
import Defaults

actor V2EXService {
    static let shared = V2EXService()
    private let session: Session
    private let decoder: JSONDecoder
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        session = Session(configuration: configuration)
    }
    
    func request<T: Codable>(_ router: V2EXRouter) async throws -> T {
        do {
            let response = try await session.request(router)
                .validate()
                .serializingDecodable(V2EXResponse<T>.self, decoder: decoder)
                .value
            return response.result
        } catch let error as DecodingError {
            // 打印详细的解码错误信息
            switch error {
            case .keyNotFound(let key, let context):
                print("⚠️ 解码错误 - 找不到键: \(key)")
                print("编码路径: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("⚠️ 解码错误 - 找不到值，类型: \(type)")
                print("编码路径: \(context.codingPath)")
            case .typeMismatch(let type, let context):
                print("⚠️ 解码错误 - 类型不匹配: \(type)")
                print("编码路径: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("⚠️ 解码错误 - 数据损坏")
                print("编码路径: \(context.codingPath)")
                if let underlyingError = context.underlyingError {
                    print("底层错误: \(underlyingError)")
                }
            @unknown default:
                print("⚠️ 未知解码错误: \(error)")
            }
            
            // 果需要，可以打印原始数据
            if let data = try? await session.request(router).serializingData().value {
                print("原始响应数据:")
                print(String(data: data, encoding: .utf8) ?? "无法解码为字符串")
            }
            
            throw error
        } catch {
            print("⚠️ 网络请求错误: \(error)")
            throw error
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
