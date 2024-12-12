import SwiftUI
import SwiftUIX
import Defaults

struct ContentView: View {
    @StateObject private var viewModel = V2EXViewModel()
    @Default(.token) private var token: String?
    
    var body: some View {
        Group {
            if let _ = token {
                // 已登录状态显示主界面
                VStack(spacing: 0) {
                    UserProfileView()
                    
                    Divider()
                    
                    NotificationsView()
                        .minHeight(320)
                    
                    Divider()
                    
                    SettingsView()
                    
                    Divider()
                    
                    QuickLinksView()
                    
                    Divider()
                    
                    BottomButtonsView()
                }
                .environmentObject(viewModel)
                .task {
                    // 初始化时加载所有数据
                    await viewModel.refreshAll()
                }
            } else {
                // 未登录状态显示引导页面
                OnboardingView()
                    .environmentObject(viewModel)
            }
        }
        .width(360)
        .focusable(false)
    }
}
