import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var tokenInfo: V2EXTokenInfo?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var showingTokenInput = false
    @Published var newToken = ""
    @Published var isEditing = false
    
    var maskedToken: String {
        guard let token = token else { return "未设置" }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)****\(suffix)"
    }
    
    var tokenExpirationText: String {
        guard let tokenInfo = tokenInfo else { return "未知" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(tokenInfo.expiration)))
    }
    
    init() {
        Task {
            self.token = await V2EXService.shared.currentToken
            if token != nil {
                await fetchTokenInfo()
            }
        }
    }
    
    func fetchTokenInfo() async {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try await V2EXService.shared.fetchCurrentToken()
            let response = try JSONDecoder().decode(V2EXResponse<V2EXTokenInfo>.self, from: data)
            self.tokenInfo = response.result
            self.error = nil
        } catch {
            print("Failed to fetch token info: \(error)")
            self.error = error
            self.tokenInfo = nil
        }
    }
    
    func saveToken() async {
        guard !newToken.isEmpty else { return }
        
        do {
            await V2EXService.shared.setToken(newToken)
            // 验证 token 是否有效
            _ = try await V2EXService.shared.fetchCurrentToken()
            self.token = newToken
            await fetchTokenInfo()
            showingTokenInput = false
            newToken = ""
            isEditing = false
            error = nil
        } catch {
            self.error = error
            await V2EXService.shared.clearToken()
            self.token = nil
            self.tokenInfo = nil
        }
    }
    
    func clearToken() async {
        await V2EXService.shared.clearToken()
        self.token = nil
        self.tokenInfo = nil
        self.error = nil
    }
    
    func startEditing() {
        if let currentToken = token {
            newToken = currentToken
            isEditing = true
            showingTokenInput = true
        }
    }
    
    func cancelEditing() {
        newToken = ""
        isEditing = false
        showingTokenInput = false
    }
} 