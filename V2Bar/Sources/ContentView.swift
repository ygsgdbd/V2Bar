import SwiftUI
import SwiftUIX
import Defaults

struct ContentView: View {
    @StateObject private var viewModel = V2EXViewModel()
    @Default(.token) private var token: String?
    
    var body: some View {
        VStack(spacing: 0) {
            if let _ = token {
                // 已登录状态显示主界面
                VStack(spacing: 0) {
                    UserProfileView()
                        .height(80)
                    
                    Divider()
                    
                    NotificationsView()
                        .maxHeight(.infinity)
                        .minHeight(300)
                    
                    Divider()
                    
                    SettingsView()
                }
                .environmentObject(viewModel)
                .task {
                    await viewModel.refreshAll()
                }
            } else {
                // 未登录状态显示引导页面
                OnboardingView()
                    .environmentObject(viewModel)
            }
        }
        .width(420)
        .minHeight(600)
    }
}
