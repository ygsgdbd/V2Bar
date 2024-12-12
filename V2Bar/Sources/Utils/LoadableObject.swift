import SwiftUI
import Combine

/// 表示一个可加载对象的状态
@MainActor
class LoadableObject<T>: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(T)
        case error(Error)
        
        var value: T? {
            if case .loaded(let value) = self {
                return value
            }
            return nil
        }
        
        var error: Error? {
            if case .error(let error) = self {
                return error
            }
            return nil
        }
        
        var isLoading: Bool {
            if case .loading = self {
                return true
            }
            return false
        }
    }
    
    @Published private(set) var state: State = .idle
    
    var value: T? { state.value }
    var error: Error? { state.error }
    var isLoading: Bool { state.isLoading }
    
    func load(_ operation: @escaping () async throws -> T) {
        Task {
            state = .loading
            do {
                let value = try await operation()
                state = .loaded(value)
            } catch {
                state = .error(error)
            }
        }
    }
    
    func reset() {
        state = .idle
    }
} 