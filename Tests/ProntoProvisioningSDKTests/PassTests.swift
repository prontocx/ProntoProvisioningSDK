import XCTest
@testable import ProntoProvisioningSDK

final class PassTests: XCTestCase {

    // MARK: - PassesResponse Decoding

    func testDecodesValidResponse() throws {
        let json = """
        {
            "data": [
                {
                    "id": "ref-001",
                    "type": "pass",
                    "attributes": {
                        "active": true,
                        "download_url": "https://example.com/pass.pkpass",
                        "download_url_apple": "https://example.com/apple.pkpass",
                        "download_url_google": "https://example.com/google"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PassesResponse.self, from: json)
        let passes = response.toPasses()

        XCTAssertEqual(passes.count, 1)
        XCTAssertEqual(passes[0].id, "ref-001")
        XCTAssertTrue(passes[0].active)
        XCTAssertEqual(passes[0].downloadURL, "https://example.com/pass.pkpass")
        XCTAssertEqual(passes[0].downloadURLApple, "https://example.com/apple.pkpass")
        XCTAssertEqual(passes[0].downloadURLGoogle, "https://example.com/google")
    }

    func testDecodesNullOptionalFields() throws {
        let json = """
        {
            "data": [
                {
                    "id": "ref-002",
                    "type": "pass",
                    "attributes": {
                        "active": false,
                        "download_url": "https://example.com/pass.pkpass",
                        "download_url_apple": null,
                        "download_url_google": null
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PassesResponse.self, from: json)
        let passes = response.toPasses()

        XCTAssertEqual(passes.count, 1)
        XCTAssertFalse(passes[0].active)
        XCTAssertNil(passes[0].downloadURLApple)
        XCTAssertNil(passes[0].downloadURLGoogle)
    }

    func testDecodesMissingOptionalFields() throws {
        let json = """
        {
            "data": [
                {
                    "id": "ref-003",
                    "type": "pass",
                    "attributes": {
                        "active": true,
                        "download_url": "https://example.com/pass.pkpass"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PassesResponse.self, from: json)
        let passes = response.toPasses()

        XCTAssertEqual(passes.count, 1)
        XCTAssertNil(passes[0].downloadURLApple)
        XCTAssertNil(passes[0].downloadURLGoogle)
    }

    func testDecodesEmptyDataArray() throws {
        let json = """
        { "data": [] }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PassesResponse.self, from: json)
        let passes = response.toPasses()

        XCTAssertTrue(passes.isEmpty)
    }

    func testFailsOnMissingRequiredField() {
        let json = """
        {
            "data": [
                {
                    "id": "ref-001",
                    "type": "pass",
                    "attributes": {
                        "active": true
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(PassesResponse.self, from: json))
    }
}
