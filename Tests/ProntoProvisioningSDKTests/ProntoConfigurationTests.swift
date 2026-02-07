import XCTest
@testable import ProntoProvisioningSDK

final class ProntoConfigurationTests: XCTestCase {

    func testDefaultConfiguration() {
        let config = ProntoConfiguration(apiKey: "test_token")

        XCTAssertEqual(config.apiKey, "test_token")
        XCTAssertEqual(config.timeout, 30.0)
        // Default environment is production
        XCTAssertEqual(config.environment.baseURL.absoluteString, "https://app.prontocx.com")
    }

    func testCustomConfiguration() {
        let config = ProntoConfiguration(
            apiKey: "my_api_key",
            environment: .staging,
            timeout: 60.0
        )

        XCTAssertEqual(config.apiKey, "my_api_key")
        XCTAssertEqual(config.environment.baseURL.absoluteString, "https://app.stage.prontocx.com")
        XCTAssertEqual(config.timeout, 60.0)
    }
}
