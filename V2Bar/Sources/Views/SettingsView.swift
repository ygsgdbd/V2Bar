import SwiftUI
import Defaults
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var viewModel: V2EXViewModel
    @State private var editingToken = ""
    
    var body: some View {
        VStack(spacing: 0) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                // 访问令牌
                GridRow {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Token")
                            .font(.system(size: 12))
                        HStack(spacing: 8) {
                            Text(viewModel.maskedToken)
                                .font(.system(size: 12))
                            
                            if viewModel.isTokenLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            } else if let formatted = viewModel.tokenInfo?.formattedExpirationText {
                                Text(formatted)
                                    .font(.system(size: 11))
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    .gridCellColumns(1)
                    
                    HStack(spacing: 8) {
                        Button {
                            showTokenAlert()
                        } label: {
                            Text("编辑")
                        }
                        
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://www.v2ex.com/settings/tokens")!)
                        } label: {
                            Text("管理")
                        }
                        
                        Button(role: .destructive) {
                            Task { await viewModel.clearToken() }
                        } label: {
                            Text("清除")
                        }
                    }
                    .gridCellColumns(1)
                    .controlSize(.small)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(12)
        }
    }
    
    private func showTokenAlert() {
        let alert = NSAlert()
        alert.messageText = "编辑访问令牌"
        alert.informativeText = "请输入新的访问令牌"
        
        // 添加输入框
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.stringValue = Defaults[.token] ?? ""
        input.placeholderString = "访问令牌"
        alert.accessoryView = input
        
        // 添加按钮
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        
        // 获取并隐藏当前窗口
        if let window = NSApplication.shared.windows.first {
            window.orderOut(nil)
            defer { window.makeKeyAndOrderFront(nil) }
            
            // 显示 alert
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let token = input.stringValue
                Task {
                    do {
                        try await viewModel.saveToken(token)
                    } catch {
                        // 错误已经在 ViewModel 中处理
                    }
                }
            }
        }
    }
} 
