import SwiftUI

struct LoadableView<T, Content: View>: View {
    let state: LoadableObject<T>
    let content: (T) -> Content
    let emptyText: String
    let isEmpty: (T) -> Bool
    
    init(
        state: LoadableObject<T>,
        emptyText: String = "暂无数据",
        isEmpty: @escaping (T) -> Bool = { _ in false },
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.state = state
        self.content = content
        self.emptyText = emptyText
        self.isEmpty = isEmpty
    }
    
    var body: some View {
        Group {
            if let error = state.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text(error.localizedDescription)
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if !isEmpty(state.value) {
                content(state.value)
            } else if state.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                Text(emptyText)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
} 