import Foundation

/// Configuration for the Pronto Provisioning SDK.
public struct ProntoConfiguration: Sendable {
    /// The API user auth token from Pronto admin.
    public let apiKey: String

    /// The Pronto environment to connect to.
    public let environment: ProntoEnvironment

    /// Network request timeout interval in seconds.
    public let timeout: TimeInterval

    public init(
        apiKey: String,
        environment: ProntoEnvironment = .production,
        timeout: TimeInterval = 30.0
    ) {
        self.apiKey = apiKey
        self.environment = environment
        self.timeout = timeout
    }
}
