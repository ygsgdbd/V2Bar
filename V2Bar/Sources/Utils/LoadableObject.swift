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
        isLoading = true
        error = nil
        
        Task {
            defer { isLoading = false }
            
            do {
                value = try await operation()
                error = nil
            } catch {
                self.error = error
            }
        }
    }
    
    func reset(_ defaultValue: T) {
        value = defaultValue
        error = nil
        isLoading = false
    }
} 