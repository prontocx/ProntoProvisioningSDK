import Foundation

/// Protocol abstracting URLSession for testability.
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

@available(iOS 15.0, macOS 12.0, *)
extension URLSession: URLSessionProtocol {}

/// Internal HTTP client for communicating with the Pronto API.
final class APIClient: Sendable {
    private let configuration: ProntoConfiguration
    private let session: URLSessionProtocol

    init(configuration: ProntoConfiguration, session: URLSessionProtocol = URLSession.shared) {
        self.configuration = configuration
        self.session = session
    }

    /// Fetches issuer data and signature for the given tag.
    func fetchIssuerData(
        tagId: String,
        idAttribute: TagIdAttribute
    ) async throws(ProvisioningError) -> IssuerDataResponse {
        let request: URLRequest
        do {
            request = try buildRequest(tagId: tagId, idAttribute: idAttribute)
        } catch {
            throw .invalidResponse
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data)
            throw .serverError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(IssuerDataResponse.self, from: data)
        } catch {
            throw .invalidResponse
        }
    }

    /// Fetches passes for the given user.
    func fetchPasses(userId: String) async throws(ProvisioningError) -> [Pass] {
        let request: URLRequest
        do {
            request = try buildPassesRequest(userId: userId)
        } catch {
            throw .invalidResponse
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = parseErrorMessage(from: data)
            throw .serverError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            let passesResponse = try JSONDecoder().decode(PassesResponse.self, from: data)
            return passesResponse.toPasses()
        } catch {
            throw .invalidResponse
        }
    }

    // MARK: - Internal (visible for testing)

    func buildRequest(tagId: String, idAttribute: TagIdAttribute) throws -> URLRequest {
        let url = configuration.environment.baseURL
            .appendingPathComponent("api/v2/in_app_provisioning/issuer_data")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = configuration.timeout

        // HTTP Basic Auth: base64(apiKey:)
        let credentials = "\(configuration.apiKey):"
        let credentialData = credentials.data(using: .utf8)!
        let base64Credentials = credentialData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "tag_id": tagId,
            "id_attribute": idAttribute.rawValue
        ]

        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    func buildPassesRequest(userId: String) throws -> URLRequest {
        let url = configuration.environment.baseURL
            .appendingPathComponent("api/v2/users/\(userId)/passes")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = configuration.timeout

        // HTTP Basic Auth: base64(apiKey:)
        let credentials = "\(configuration.apiKey):"
        let credentialData = credentials.data(using: .utf8)!
        let base64Credentials = credentialData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")

        return request
    }

    private func parseErrorMessage(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let error: String?
            let message: String?
        }
        guard let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.error ?? errorResponse.message
    }
}
