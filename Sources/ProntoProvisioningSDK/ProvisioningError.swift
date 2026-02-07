import Foundation

/// Errors that can occur during pass provisioning.
public enum ProvisioningError: Error, Sendable {
    /// The SDK has not been configured. Call `ProntoWallet.shared.configure(with:)` first.
    case notConfigured

    /// Apple Wallet is not available on this device.
    case walletNotAvailable

    /// A network error occurred while communicating with the Pronto API.
    case networkError(any Error)

    /// The server returned an error response.
    case serverError(statusCode: Int, message: String?)

    /// The server response could not be parsed.
    case invalidResponse

    /// An error occurred in PassKit while presenting the provisioning UI.
    case passKitError(any Error)
}

extension ProvisioningError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ProntoWallet SDK is not configured. Call configure(with:) before provisioning."
        case .walletNotAvailable:
            return "Apple Wallet is not available on this device."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let statusCode, let message):
            if let message {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (\(statusCode))"
        case .invalidResponse:
            return "Invalid response from server."
        case .passKitError(let error):
            return "PassKit error: \(error.localizedDescription)"
        }
    }
}
