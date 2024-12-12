import SwiftUI

struct ContentView: View {
    @State private var isAuthorized: Bool = false
    @State private var showingTokenInput = false
    @State private var token: String = ""
    @State private var errorMessage: String?
    @State private var userProfile: V2EXUserProfile.UserInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            // 用户信息区域
            if let profile = userProfile {
                UserProfileView(profile: profile)
            } else if isAuthorized {
                ProgressView()
                    .frame(height: 80)
            } else {
                Text("未登录")
                    .foregroundColor(.secondary)
                    .frame(height: 80)
            }
            
            Divider()
            
            // 通知列表区域
            if isAuthorized {
                NotificationsView()
                    .frame(maxHeight: .infinity)
            } else {
                VStack {
                    Text("请先添加 Token")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            }
            
            Divider()
            
            // Token 设置区域
            HStack {
                if isAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Token: ****")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("注销") {
                        Task {
                            await V2EXService.shared.clearToken()
                            await checkAuthStatus()
                        }
                    }
                    .foregroundColor(.red)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("未设置 Token")
                    Spacer()
                    Button("添加") {
                        showingTokenInput = true
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(height: 36)
        }
        .frame(width: 360, height: 540)
        .sheet(isPresented: $showingTokenInput) {
            TokenInputView(
                token: $token,
                showingTokenInput: $showingTokenInput,
                onSave: {
                    Task {
                        await saveToken()
                    }
                }
            )
        }
        .task {
            await checkAuthStatus()
            if isAuthorized {
                await fetchUserProfile()
            }
        }
    }
    
    @MainActor
    private func checkAuthStatus() async {
        isAuthorized = await V2EXService.shared.isAuthorized
    }
    
    @MainActor
    private func fetchUserProfile() async {
        do {
            let data = try await V2EXService.shared.fetchMemberProfile()
            let response = try JSONDecoder().decode(V2EXUserProfile.Response.self, from: data)
            userProfile = response.result
        } catch {
            print("Error fetching user profile: \(error)")
        }
    }
    
    @MainActor
    private func saveToken() async {
        guard !token.isEmpty else { return }
        
        do {
            await V2EXService.shared.setToken(token)
            // 验证 token 是否有效
            _ = try await V2EXService.shared.fetchCurrentToken()
            await checkAuthStatus()
            if isAuthorized {
                await fetchUserProfile()
            }
            errorMessage = nil
            showingTokenInput = false
        } catch {
            errorMessage = "Token 无效，请检查后重试"
            await V2EXService.shared.clearToken()
            await checkAuthStatus()
        }
    }
}

// MARK: - Token Input View
struct TokenInputView: View {
    @Binding var token: String
    @Binding var showingTokenInput: Bool
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("添加 Token")
                .font(.headline)
            
            TextField("请输入 V2EX API Token", text: $token)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            Text("你可以在 V2EX 的设置页面生成 API Token")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button("取消") {
                    showingTokenInput = false
                }
                
                Button("保存") {
                    onSave()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 400)
    }
}
