import XCTest
@testable import ProntoProvisioningSDK

final class TagIdAttributeTests: XCTestCase {

    func testReferenceIdRawValue() {
        XCTAssertEqual(TagIdAttribute.referenceId.rawValue, "reference_id")
    }

    func testProntoTagIdRawValue() {
        XCTAssertEqual(TagIdAttribute.prontoTagId.rawValue, "pronto_tag_id")
    }

    func testSubscriptionIdRawValue() {
        XCTAssertEqual(TagIdAttribute.subscriptionId.rawValue, "subscription_id")
    }
}
