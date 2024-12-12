import SwiftUI
import Combine

@MainActor
class LoadableObject<T>: ObservableObject {
    @Published private(set) var value: T
    @Published private(set) var error: Error?
    @Published private(set) var isLoading = false
    
    init(defaultValue: T) {
        self.value = defaultValue
    }
    
    func load(_ operation: @escaping () async throws -> T) {
        // 如果已经有非默认数据，不设置 isLoading 状态
        let shouldShowLoading = isLoading == false
        
        if shouldShowLoading {
            isLoading = true
            error = nil
        }
        
        Task {
            do {
                value = try await operation()
                error = nil
            } catch {
                self.error = error
            }
            
            if shouldShowLoading {
                isLoading = false
            }
        }
    }
    
    func reset(_ defaultValue: T) {
        value = defaultValue
        error = nil
        isLoading = false
    }
} 