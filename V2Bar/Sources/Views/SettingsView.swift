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
                            
                            if viewModel.tokenState.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            } else if let formatted = viewModel.tokenState.value?.formattedExpirationText {
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
        alert.messageText = "设置访问令牌"
        alert.informativeText = "请输入您的 V2EX 访问令牌"
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "请输入访问令牌"
        if let existingToken = Defaults[.token] {
            input.stringValue = existingToken
            input.selectText(nil)
        }
        
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
