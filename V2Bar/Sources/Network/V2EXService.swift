import Alamofire
import Foundation

actor V2EXService {
    private let decoder: JSONDecoder
    private let session: Session

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        session = Session(configuration: configuration)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func request<Value: Codable & Sendable>(
        _ router: V2EXRouter,
        as type: Value.Type = Value.self
    ) async throws -> Value {
        do {
            let response = try await session.request(router)
                .validate()
                .serializingDecodable(V2EXResponse<Value>.self, decoder: decoder)
                .value
            return try response.getResult()
        } catch let error as V2EXClientError {
            throw error
        } catch let error as AFError {
            if error.responseCode == 401 {
                throw V2EXClientError.unauthorized
            }
            if let statusCode = error.responseCode, statusCode >= 500 {
                throw V2EXClientError.server(statusCode)
            }
            throw V2EXClientError.transport(error.localizedDescription)
        } catch {
            throw V2EXClientError.transport(error.localizedDescription)
        }
    }
}
