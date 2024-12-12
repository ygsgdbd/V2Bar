import SwiftUI

struct TokenInputView: View {
    @Binding var token: String
    let title: String
    let submitButtonTitle: String
    let onSubmit: () async -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            
            TextField("请输入 Token", text: $token)
                .textFieldStyle(.roundedBorder)
            
            HStack(spacing: 12) {
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(.plain)
                
                Button(submitButtonTitle) {
                    Task {
                        await onSubmit()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
    }
} 