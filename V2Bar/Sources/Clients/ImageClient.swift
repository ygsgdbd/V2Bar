import ComposableArchitecture
import Foundation

struct ImageClient: Sendable {
    var load: @Sendable (URL) async throws -> Data
}

extension ImageClient: DependencyKey {
    static let liveValue = Self { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
            throw V2EXClientError.invalidResponse
        }
        return data
    }

    static let testValue = Self { _ in throw V2EXClientError.invalidResponse }
}

extension DependencyValues {
    var imageClient: ImageClient {
        get { self[ImageClient.self] }
        set { self[ImageClient.self] = newValue }
    }
}
