import XCTest
@testable import ProntoProvisioningSDK

// MARK: - Mock URLSession

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var requestHandler: ((URLRequest) async throws -> (Data, URLResponse))?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let handler = requestHandler else {
            fatalError("MockURLSession requestHandler not set")
        }
        return try await handler(request)
    }
}

// MARK: - Tests

final class APIClientTests: XCTestCase {

    private let testConfig = ProntoConfiguration(
        apiKey: "test_api_key_123",
        environment: .staging,
        timeout: 15.0
    )

    // MARK: - Request Building

    func testBuildRequestURL() throws {
        let client = APIClient(configuration: testConfig)
        let request = try client.buildRequest(tagId: "PASS-001", idAttribute: .referenceId)

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://app.stage.prontocx.com/api/v2/in_app_provisioning/issuer_data"
        )
    }

    func testBuildRequestMethod() throws {
        let client = APIClient(configuration: testConfig)
        let request = try client.buildRequest(tagId: "PASS-001", idAttribute: .referenceId)

        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testBuildRequestHeaders() throws {
        let client = APIClient(configuration: testConfig)
        let request = try client.buildRequest(tagId: "PASS-001", idAttribute: .referenceId)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testBuildRequestTimeout() throws {
        let client = APIClient(configuration: testConfig)
        let request = try client.buildRequest(tagId: "PASS-001", idAttribute: .referenceId)

        XCTAssertEqual(request.timeoutInterval, 15.0)
    }

    func testBuildRequestBasicAuth() throws {
        let client = APIClient(configuration: testConfig)
        let request = try client.buildRequest(tagId: "PASS-001", idAttribute: .referenceId)

        let expectedCredentials = "test_api_key_123:"
        let expectedBase64 = Data(expectedCredentials.utf8).base64EncodedString()
        let expectedHeader = "Basic \(expectedBase64)"

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), expectedHeader)
    }

    func testBuildRequestBody() throws {
        let client = APIClient(configuration: testConfig)
        let request = try client.buildRequest(tagId: "PASS-001", idAttribute: .referenceId)

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode([String: String].self, from: body)

        XCTAssertEqual(decoded["tag_id"], "PASS-001")
        XCTAssertEqual(decoded["id_attribute"], "reference_id")
    }

    func testBuildRequestBodyWithProntoTagId() throws {
        let client = APIClient(configuration: testConfig)
        let request = try client.buildRequest(tagId: "42", idAttribute: .prontoTagId)

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode([String: String].self, from: body)

        XCTAssertEqual(decoded["tag_id"], "42")
        XCTAssertEqual(decoded["id_attribute"], "pronto_tag_id")
    }

    func testBuildRequestBodyWithSubscriptionId() throws {
        let client = APIClient(configuration: testConfig)
        let request = try client.buildRequest(tagId: "SUB-99", idAttribute: .subscriptionId)

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode([String: String].self, from: body)

        XCTAssertEqual(decoded["tag_id"], "SUB-99")
        XCTAssertEqual(decoded["id_attribute"], "subscription_id")
    }

    func testBuildRequestWithProductionEnvironment() throws {
        let config = ProntoConfiguration(apiKey: "key", environment: .production)
        let client = APIClient(configuration: config)
        let request = try client.buildRequest(tagId: "1", idAttribute: .referenceId)

        XCTAssertTrue(request.url!.absoluteString.hasPrefix("https://app.prontocx.com"))
    }

    func testBuildRequestWithDevelopmentEnvironment() throws {
        let config = ProntoConfiguration(apiKey: "key", environment: .development(host: "localhost:3000"))
        let client = APIClient(configuration: config)
        let request = try client.buildRequest(tagId: "1", idAttribute: .referenceId)

        XCTAssertTrue(request.url!.absoluteString.hasPrefix("http://localhost:3000"))
    }

    // MARK: - fetchIssuerData Success

    func testFetchIssuerDataSuccess() async throws {
        let mockSession = MockURLSession()
        let client = APIClient(configuration: testConfig, session: mockSession)

        let responseJSON = """
        {
            "issuer_data": "aXNzdWVyRGF0YQ==",
            "signature": "c2lnbmF0dXJl",
            "tag_id": 42
        }
        """.data(using: .utf8)!

        mockSession.requestHandler = { request in
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (responseJSON, httpResponse)
        }

        let response = try await client.fetchIssuerData(tagId: "PASS-001", idAttribute: .referenceId)

        XCTAssertEqual(response.issuerData, "aXNzdWVyRGF0YQ==")
        XCTAssertEqual(response.signature, "c2lnbmF0dXJl")
        XCTAssertEqual(response.tagId, 42)
    }

    // MARK: - fetchIssuerData Errors

    func testFetchIssuerDataNetworkError() async {
        let mockSession = MockURLSession()
        let client = APIClient(configuration: testConfig, session: mockSession)

        mockSession.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await client.fetchIssuerData(tagId: "PASS-001", idAttribute: .referenceId)
            XCTFail("Expected networkError")
        } catch {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        }
    }

    func testFetchIssuerDataServerError401() async {
        let mockSession = MockURLSession()
        let client = APIClient(configuration: testConfig, session: mockSession)

        let errorJSON = """
        {"error": "Unauthorized"}
        """.data(using: .utf8)!

        mockSession.requestHandler = { request in
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (errorJSON, httpResponse)
        }

        do {
            _ = try await client.fetchIssuerData(tagId: "PASS-001", idAttribute: .referenceId)
            XCTFail("Expected serverError")
        } catch {
            if case .serverError(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 401)
                XCTAssertEqual(message, "Unauthorized")
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        }
    }

    func testFetchIssuerDataServerError404() async {
        let mockSession = MockURLSession()
        let client = APIClient(configuration: testConfig, session: mockSession)

        let errorJSON = """
        {"error": "Not Found"}
        """.data(using: .utf8)!

        mockSession.requestHandler = { request in
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (errorJSON, httpResponse)
        }

        do {
            _ = try await client.fetchIssuerData(tagId: "NONEXISTENT", idAttribute: .referenceId)
            XCTFail("Expected serverError")
        } catch {
            if case .serverError(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 404)
                XCTAssertEqual(message, "Not Found")
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        }
    }

    func testFetchIssuerDataServerError500WithNoMessage() async {
        let mockSession = MockURLSession()
        let client = APIClient(configuration: testConfig, session: mockSession)

        mockSession.requestHandler = { request in
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), httpResponse)
        }

        do {
            _ = try await client.fetchIssuerData(tagId: "PASS-001", idAttribute: .referenceId)
            XCTFail("Expected serverError")
        } catch {
            if case .serverError(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 500)
                XCTAssertNil(message)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        }
    }

    func testFetchIssuerDataInvalidResponseBody() async {
        let mockSession = MockURLSession()
        let client = APIClient(configuration: testConfig, session: mockSession)

        mockSession.requestHandler = { request in
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return ("not json".data(using: .utf8)!, httpResponse)
        }

        do {
            _ = try await client.fetchIssuerData(tagId: "PASS-001", idAttribute: .referenceId)
            XCTFail("Expected invalidResponse")
        } catch {
            if case .invalidResponse = error {
                // Expected
            } else {
                XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }

    // MARK: - Verify request is sent correctly

    func testFetchIssuerDataSendsCorrectRequest() async throws {
        let mockSession = MockURLSession()
        let client = APIClient(configuration: testConfig, session: mockSession)

        var capturedRequest: URLRequest?

        let responseJSON = """
        {
            "issuer_data": "aXNzdWVyRGF0YQ==",
            "signature": "c2lnbmF0dXJl",
            "tag_id": 1
        }
        """.data(using: .utf8)!

        mockSession.requestHandler = { request in
            capturedRequest = request
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (responseJSON, httpResponse)
        }

        _ = try await client.fetchIssuerData(tagId: "MY-TAG", idAttribute: .subscriptionId)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://app.stage.prontocx.com/api/v2/in_app_provisioning/issuer_data"
        )

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode([String: String].self, from: body)
        XCTAssertEqual(decoded["tag_id"], "MY-TAG")
        XCTAssertEqual(decoded["id_attribute"], "subscription_id")
    }

    func testFetchIssuerDataServerErrorWithMessageField() async {
        let mockSession = MockURLSession()
        let client = APIClient(configuration: testConfig, session: mockSession)

        let errorJSON = """
        {"message": "Rate limit exceeded"}
        """.data(using: .utf8)!

        mockSession.requestHandler = { request in
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (errorJSON, httpResponse)
        }

        do {
            _ = try await client.fetchIssuerData(tagId: "PASS-001", idAttribute: .referenceId)
            XCTFail("Expected serverError")
        } catch {
            if case .serverError(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 429)
                XCTAssertEqual(message, "Rate limit exceeded")
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        }
    }
}
