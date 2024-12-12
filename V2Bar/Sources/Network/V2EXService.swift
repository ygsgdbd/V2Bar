import Foundation
import Alamofire

actor V2EXService {
    static let shared = V2EXService()
    private let session: Session
    private var token: String?
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        
        let monitor = APIEventMonitor()
        session = Session(
            configuration: configuration,
            eventMonitors: [monitor]
        )
        
        // 从 UserDefaults 加载保存的 token
        if let savedToken = UserDefaults.standard.string(forKey: "v2ex_token") {
            self.token = savedToken
        }
    }
    
    // MARK: - Token Management
    
    func setToken(_ token: String) {
        self.token = token
        // 保存 token 到 UserDefaults
        Task { @MainActor in
            UserDefaults.standard.set(token, forKey: "v2ex_token")
        }
    }
    
    func clearToken() {
        self.token = nil
        Task { @MainActor in
            UserDefaults.standard.removeObject(forKey: "v2ex_token")
        }
    }
    
    var isAuthorized: Bool {
        token != nil
    }
    
    // MARK: - 通知相关
    
    /// 获取最新提醒
    func fetchNotifications(page: Int? = nil) async throws -> Data {
        try await authorizedRequest(V2EXRouter.notifications(page: page))
    }
    
    /// 删除指定提醒
    func deleteNotification(id: Int) async throws {
        _ = try await authorizedRequest(V2EXRouter.deleteNotification(id: id))
    }
    
    // MARK: - 用户相关
    
    /// 获取个人信息
    func fetchMemberProfile() async throws -> Data {
        try await authorizedRequest(V2EXRouter.member)
    }
    
    /// 获取当前令牌信息
    func fetchCurrentToken() async throws -> Data {
        try await authorizedRequest(V2EXRouter.token)
    }
    
    /// 创建新令牌
    func createToken(scope: V2EXRouter.TokenScope, expiration: V2EXRouter.TokenExpiration) async throws -> Data {
        try await authorizedRequest(V2EXRouter.createToken(scope: scope, expiration: expiration))
    }
    
    // MARK: - 节点相关
    
    /// 获取节点信息
    func fetchNode(name: String) async throws -> Data {
        try await authorizedRequest(V2EXRouter.node(name: name))
    }
    
    /// 获取节点主题列表
    func fetchNodeTopics(name: String, page: Int? = nil) async throws -> Data {
        try await authorizedRequest(V2EXRouter.nodeTopics(name: name, page: page))
    }
    
    // MARK: - 主题相关
    
    /// 获取主题详情
    func fetchTopic(id: Int) async throws -> Data {
        try await authorizedRequest(V2EXRouter.topic(id: id))
    }
    
    /// 获取主���回复
    func fetchTopicReplies(id: Int, page: Int? = nil) async throws -> Data {
        try await authorizedRequest(V2EXRouter.topicReplies(id: id, page: page))
    }
    
    // MARK: - Private Methods
    
    private func authorizedRequest(_ convertible: URLRequestConvertible) async throws -> Data {
        guard let token = token else {
            throw V2EXError.unauthorized
        }
        
        var urlRequest = try convertible.asURLRequest()
        urlRequest.headers.update(.authorization(bearerToken: token))
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(urlRequest)
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        // 如果是 401 错误，清除无效的 token
                        if let statusCode = response.response?.statusCode, statusCode == 401 {
                            Task {
                                await self.clearToken()
                            }
                        }
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
}

// MARK: - Error Types
enum V2EXError: Error {
    case unauthorized
    case rateLimitExceeded
    case invalidResponse
}

// MARK: - API Monitor
class APIEventMonitor: EventMonitor, @unchecked Sendable {
    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        print("📡 \(urlRequest.httpMethod ?? "GET") \(urlRequest.url?.absoluteString ?? "")")
    }
    
    func request(_ request: Request, didParseResponse response: DataResponse<Data, AFError>) {
        if let statusCode = response.response?.statusCode {
            print("📥 Status Code: \(statusCode)")
        }
        
        // 检查 Rate Limit 信息
        if let headers = response.response?.headers {
            let limit = headers["X-Rate-Limit-Limit"]
            let remaining = headers["X-Rate-Limit-Remaining"]
            let reset = headers["X-Rate-Limit-Reset"]
            
            if let limit = limit, let remaining = remaining {
                print("📊 Rate Limit - Limit: \(limit), Remaining: \(remaining), Reset: \(reset ?? "N/A")")
            }
        }
    }
} 
