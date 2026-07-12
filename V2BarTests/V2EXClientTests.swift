import XCTest

@testable import V2Bar

final class V2EXClientTests: XCTestCase {
    func testProfileRequestContainsBearerToken() throws {
        let request = try V2EXRouter.profile(token: "secret").asURLRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://www.v2ex.com/api/v2/member")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(request.httpMethod, "GET")
    }

    func testAPIErrorMessageIsPreserved() {
        let response = V2EXResponse<String>(success: false, message: "token expired", result: nil)

        XCTAssertThrowsError(try response.getResult()) { error in
            XCTAssertEqual(error as? V2EXClientError, .api("token expired"))
        }
    }
}
