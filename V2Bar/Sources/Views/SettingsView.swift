import SwiftUI
import SwifterSwift
import AppKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    if viewModel.token != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(viewModel.maskedToken)
                                .foregroundColor(.secondary)
                                .font(.caption)
                            if let tokenInfo = viewModel.tokenInfo {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("有效期至 \(viewModel.tokenExpirationText)")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            Button {
                                showTokenAlert(isEditing: true)
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            
                            Button {
                                Task {
                                    await viewModel.clearToken()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                        }
                        
                        Spacer()
                    } else {
                        Button("添加 Token") {
                            showTokenAlert(isEditing: false)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        if let error = viewModel.error {
                            Text(error.localizedDescription)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
    
    private func showTokenAlert(isEditing: Bool) {
        let alert = NSAlert()
        alert.messageText = isEditing ? "编辑 Token" : "添加 Token"
        alert.informativeText = "请输入 V2EX API Token"
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "请输入 Token"
        if isEditing, let currentToken = viewModel.token {
            input.stringValue = currentToken
        }
        alert.accessoryView = input
        
        alert.addButton(withTitle: isEditing ? "更新" : "添加")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let token = input.stringValue
            guard !token.isEmpty else { return }
            
            Task { @MainActor in
                viewModel.newToken = token
                await viewModel.saveToken()
            }
        }
    }
} 
