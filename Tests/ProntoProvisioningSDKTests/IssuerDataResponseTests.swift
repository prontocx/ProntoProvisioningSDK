import XCTest
@testable import ProntoProvisioningSDK

final class IssuerDataResponseTests: XCTestCase {

    func testDecodingValidResponse() throws {
        let json = """
        {
            "issuer_data": "aXNzdWVyRGF0YQ==",
            "signature": "c2lnbmF0dXJl",
            "tag_id": 42
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(IssuerDataResponse.self, from: json)

        XCTAssertEqual(response.issuerData, "aXNzdWVyRGF0YQ==")
        XCTAssertEqual(response.signature, "c2lnbmF0dXJl")
        XCTAssertEqual(response.tagId, 42)
    }

    func testDecodingMissingFieldFails() {
        let json = """
        {
            "issuer_data": "aXNzdWVyRGF0YQ==",
            "tag_id": 42
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(IssuerDataResponse.self, from: json))
    }

    func testDecodingInvalidJSONFails() {
        let json = "not json".data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(IssuerDataResponse.self, from: json))
    }
}
