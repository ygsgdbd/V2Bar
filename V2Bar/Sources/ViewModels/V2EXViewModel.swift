import SwiftUI
import Defaults
import Combine

@MainActor
class V2EXViewModel: ObservableObject {
    // MARK: - States
    private let tokenState = LoadableObject<V2EXTokenInfo>()
    private let profileState = LoadableObject<V2EXUserProfile>()
    private let notificationsState = LoadableObject<[Notification]>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Token Info
    var tokenInfo: V2EXTokenInfo? { tokenState.value }
    var isTokenLoading: Bool { tokenState.isLoading }
    var tokenError: Error? { tokenState.error }
    
    var maskedToken: String {
        guard let token = Defaults[.token] else { return "未设置" }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)****\(suffix)"
    }
    
    var tokenExpirationText: String {
        guard let tokenInfo = tokenInfo else { return "未知" }
        return tokenInfo.formattedExpirationText
    }
    
    // MARK: - Profile
    var profile: V2EXUserProfile? { profileState.value }
    var isProfileLoading: Bool { profileState.isLoading }
    var profileError: Error? { profileState.error }
    
    // MARK: - Notifications
    var notifications: [Notification] { notificationsState.value ?? [] }
    var isNotificationsLoading: Bool { notificationsState.isLoading }
    var notificationsError: Error? { notificationsState.error }
    
    // MARK: - Initialization
    init() {
        // 转发所有状态变化
        tokenState.objectWillChange.sink(receiveValue: objectWillChange.send).store(in: &cancellables)
        profileState.objectWillChange.sink(receiveValue: objectWillChange.send).store(in: &cancellables)
        notificationsState.objectWillChange.sink(receiveValue: objectWillChange.send).store(in: &cancellables)
        
        // 监听 token 变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    /// 刷新令牌信息
    func refreshTokenInfo() async {
        tokenState.load {
            let data = try await V2EXService.shared.fetchCurrentToken()
            let response = try JSONDecoder().decode(V2EXResponse<V2EXTokenInfo>.self, from: data)
            return response.result
        }
    }
    
    /// 刷新用户资料
    func fetchProfile() async {
        profileState.load {
            let data = try await V2EXService.shared.fetchMemberProfile()
            let response = try JSONDecoder().decode(V2EXResponse<V2EXUserProfile>.self, from: data)
            return response.result
        }
    }
    
    /// 刷新通知
    func fetchNotifications() async {
        notificationsState.load {
            let data = try await V2EXService.shared.fetchNotifications()
            let response = try JSONDecoder().decode(V2EXResponse<[Notification]>.self, from: data)
            return response.result
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
            _ = try await V2EXService.shared.fetchCurrentToken()
            
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
        tokenState.reset()
        profileState.reset()
        notificationsState.reset()
    }
    
    /// 刷新所有数据
    func refreshAll() async {
        await refreshTokenInfo()
        await fetchProfile()
        await fetchNotifications()
    }
    
    // MARK: - Private Methods
    @objc private func defaultsChanged() {
        Task {
            if Defaults[.token] != nil {
                await refreshTokenInfo()
            } else {
                await clearToken()
            }
        }
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