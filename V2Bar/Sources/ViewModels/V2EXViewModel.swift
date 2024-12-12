import SwiftUI
import Defaults
import Combine

@MainActor
class V2EXViewModel: ObservableObject {
    // MARK: - States
    let tokenState = LoadableObject<V2EXTokenInfo?>(defaultValue: nil)
    let profileState = LoadableObject<V2EXUserProfile?>(defaultValue: nil)
    let notificationsState = LoadableObject<[V2EXNotification]>(defaultValue: [])
    private var cancellables = Set<AnyCancellable>()
    
    var maskedToken: String {
        guard let token = Defaults[.token] else { return "未设置" }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)****\(suffix)"
    }
    
    // MARK: - Initialization
    init() {
        // 转发所有状态变化
        tokenState.objectWillChange.sink(receiveValue: objectWillChange.send).store(in: &cancellables)
        profileState.objectWillChange.sink(receiveValue: objectWillChange.send).store(in: &cancellables)
        notificationsState.objectWillChange.sink(receiveValue: objectWillChange.send).store(in: &cancellables)
        
        // 监听 token 变化
        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    if Defaults[.token] != nil {
                        await self.refreshTokenInfo()
                    } else {
                        await self.clearToken()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    /// 刷新令牌信息
    func refreshTokenInfo() async {
        tokenState.load {
            try await V2EXService.shared.request(.token)
        }
    }
    
    /// 刷新用户资料
    func fetchProfile() async {
        profileState.load {
            try await V2EXService.shared.request(.profile)
        }
    }
    
    /// 刷新通知
    func fetchNotifications() async {
        notificationsState.load {
            try await V2EXService.shared.request(.notifications)
        }
    }
    
    /// 保存并验证新的访问令牌
    func saveToken(_ token: String) async throws {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { throw TokenError.emptyToken }
        
        do {
            // 先保存 token
            Defaults[.token] = trimmedToken
            
            // 验证 token 是否有效
            _ = try await V2EXService.shared.request(.token) as V2EXTokenInfo
            
            // token 有效，更新信息
            await refreshTokenInfo()
        } catch {
            // token 无效，清理状态
            await clearToken()
            throw TokenError.invalidToken(error)
        }
    }
    
    /// 清除当前的访问令牌
    func clearToken() async {
        Defaults[.token] = nil
        tokenState.reset(nil)
        profileState.reset(nil)
        notificationsState.reset([])
    }
    
    /// 刷新所有数据
    func refreshAll() async {
        await refreshTokenInfo()
        await fetchProfile()
        await fetchNotifications()
    }
}

// MARK: - Error Types
extension V2EXViewModel {
    enum TokenError: LocalizedError {
        case emptyToken
        case invalidToken(Error)
        
        var errorDescription: String? {
            switch self {
            case .emptyToken:
                return "访问令牌不能为空"
            case .invalidToken(let error):
                return "无效的访问令牌：\(error.localizedDescription)"
            }
        }
    }
} 
