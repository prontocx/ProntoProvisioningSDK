import XCTest
@testable import ProntoProvisioningSDK

final class ProvisioningErrorTests: XCTestCase {

    func testNotConfiguredDescription() {
        let error = ProvisioningError.notConfigured
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not configured"))
    }

    func testWalletNotAvailableDescription() {
        let error = ProvisioningError.walletNotAvailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not available"))
    }

    func testNetworkErrorDescription() {
        let underlyingError = URLError(.notConnectedToInternet)
        let error = ProvisioningError.networkError(underlyingError)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Network error"))
    }

    func testServerErrorWithMessage() {
        let error = ProvisioningError.serverError(statusCode: 401, message: "Unauthorized")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("401"))
        XCTAssertTrue(error.errorDescription!.contains("Unauthorized"))
    }

    func testServerErrorWithoutMessage() {
        let error = ProvisioningError.serverError(statusCode: 500, message: nil)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("500"))
    }

    func testInvalidResponseDescription() {
        let error = ProvisioningError.invalidResponse
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Invalid response"))
    }

    func testPassKitErrorDescription() {
        let underlyingError = NSError(domain: "PKPassKitError", code: 1, userInfo: nil)
        let error = ProvisioningError.passKitError(underlyingError)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("PassKit error"))
    }
}
