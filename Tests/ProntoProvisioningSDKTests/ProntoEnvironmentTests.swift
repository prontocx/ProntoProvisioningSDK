import XCTest
@testable import ProntoProvisioningSDK

final class ProntoEnvironmentTests: XCTestCase {

    func testProductionBaseURL() {
        let env = ProntoEnvironment.production
        XCTAssertEqual(env.baseURL.absoluteString, "https://app.prontocx.com")
    }

    func testStagingBaseURL() {
        let env = ProntoEnvironment.staging
        XCTAssertEqual(env.baseURL.absoluteString, "https://app.stage.prontocx.com")
    }

    func testDemoBaseURL() {
        let env = ProntoEnvironment.demo
        XCTAssertEqual(env.baseURL.absoluteString, "https://app.demo.prontocx.com")
    }

    func testDevelopmentBaseURL() {
        let env = ProntoEnvironment.development(host: "localhost:3000")
        XCTAssertEqual(env.baseURL.absoluteString, "http://localhost:3000")
    }

    func testDevelopmentWithCustomHost() {
        let env = ProntoEnvironment.development(host: "192.168.1.10:3000")
        XCTAssertEqual(env.baseURL.absoluteString, "http://192.168.1.10:3000")
    }

    func testCustomBaseURL() {
        let url = URL(string: "https://custom.example.com")!
        let env = ProntoEnvironment.custom(url)
        XCTAssertEqual(env.baseURL, url)
    }
}
