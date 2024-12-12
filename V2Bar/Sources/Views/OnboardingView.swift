import SwiftUI
import Defaults
import AppKit

struct OnboardingView: View {
    @EnvironmentObject private var viewModel: V2EXViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("欢迎使用 V2Bar")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("请先设置 V2EX 访问令牌")
                .foregroundColor(.secondary)
            
            Link("获取访问令牌", destination: URL(string: "https://www.v2ex.com/settings/tokens")!)
                .foregroundColor(.accentColor)
            
            Button(action: showTokenInputAlert) {
                Text("设置")
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func showTokenInputAlert() {
        let alert = NSAlert()
        alert.messageText = "设置访问令牌"
        alert.informativeText = "请输入您的 V2EX 访问令牌"
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "请输入访问令牌"
        
        alert.accessoryView = input
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let inputToken = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !inputToken.isEmpty {
                Task {
                    do {
                        try await viewModel.saveToken(inputToken)
                    } catch {
                        let errorAlert = NSAlert()
                        errorAlert.messageText = "设置失败"
                        errorAlert.informativeText = error.localizedDescription
                        errorAlert.alertStyle = .critical
                        errorAlert.addButton(withTitle: "确定")
                        errorAlert.runModal()
                    }
                }
            }
        }
    }
} 
