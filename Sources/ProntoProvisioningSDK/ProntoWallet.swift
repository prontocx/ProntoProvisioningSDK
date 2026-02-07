#if canImport(UIKit) && canImport(PassKit)
import UIKit
import PassKit

/// Main entry point for the Pronto Provisioning SDK.
///
/// Use this class to configure the SDK and provision Apple Account-bound passes
/// to the user's Apple Wallet.
///
/// ```swift
/// // Configure once at app launch
/// ProntoWallet.shared.configure(with: ProntoConfiguration(
///     apiKey: "your_api_user_auth_token",
///     environment: .staging
/// ))
///
/// // Provision a pass
/// ProntoWallet.shared.provisionPass(
///     tagId: "TICKET-001",
///     from: viewController,
///     delegate: self
/// )
/// ```
@MainActor
public final class ProntoWallet: NSObject {
    /// Shared singleton instance.
    public static let shared = ProntoWallet()

    private var configuration: ProntoConfiguration?
    private weak var currentDelegate: ProvisioningDelegate?
    private var currentTask: Task<Void, Never>?

    override private init() {
        super.init()
    }

    /// Configure the SDK with your API credentials.
    ///
    /// Call this once during app initialization before attempting to provision passes.
    /// - Parameter configuration: The SDK configuration containing your API key and environment.
    public func configure(with configuration: ProntoConfiguration) {
        self.configuration = configuration
    }

    /// Whether Apple Wallet is available on this device.
    public var isWalletAvailable: Bool {
        PKAddPassesViewController.canAddPasses()
    }

    /// Provision a pass to the user's Apple Wallet.
    ///
    /// This method fetches issuer data from the Pronto API, then presents the native
    /// Apple Wallet binding UI using `PKAddPassesViewController`.
    ///
    /// - Parameters:
    ///   - tagId: The identifier for the tag/pass to provision.
    ///   - idAttribute: Which attribute to use for tag lookup (defaults to `.referenceId`).
    ///   - presentingViewController: The view controller to present the Apple Wallet UI from.
    ///   - delegate: Delegate to receive provisioning lifecycle callbacks.
    public func provisionPass(
        tagId: String,
        idAttribute: TagIdAttribute = .referenceId,
        from presentingViewController: UIViewController,
        delegate: ProvisioningDelegate
    ) {
        guard let configuration else {
            delegate.provisioning(didFailWith: .notConfigured)
            return
        }

        guard isWalletAvailable else {
            delegate.provisioning(didFailWith: .walletNotAvailable)
            return
        }

        currentDelegate = delegate

        currentTask = Task { [weak self] in
            guard let self else { return }

            let apiClient = APIClient(configuration: configuration)

            let response: IssuerDataResponse
            do {
                response = try await apiClient.fetchIssuerData(
                    tagId: tagId,
                    idAttribute: idAttribute
                )
            } catch let error as ProvisioningError {
                self.currentDelegate?.provisioning(didFailWith: error)
                return
            } catch {
                self.currentDelegate?.provisioning(didFailWith: .networkError(error))
                return
            }

            guard let issuerData = Data(base64Encoded: response.issuerData),
                  let signature = Data(base64Encoded: response.signature) else {
                self.currentDelegate?.provisioning(didFailWith: .invalidResponse)
                return
            }

            self.presentPassViewController(
                issuerData: issuerData,
                signature: signature,
                from: presentingViewController
            )
        }
    }

    private func presentPassViewController(
        issuerData: Data,
        signature: Data,
        from viewController: UIViewController
    ) {
        guard #available(iOS 16.4, *) else {
            currentDelegate?.provisioning(didFailWith: .passKitError(
                NSError(domain: "ProntoProvisioningSDK", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "In-app provisioning requires iOS 16.4 or later."])
            ))
            return
        }

        let addPassVC: PKAddPassesViewController
        do {
            addPassVC = try PKAddPassesViewController(issuerData: issuerData, signature: signature)
        } catch {
            currentDelegate?.provisioning(didFailWith: .passKitError(error))
            return
        }
        addPassVC.delegate = self
        viewController.present(addPassVC, animated: true)
    }
}

// MARK: - PKAddPassesViewControllerDelegate

extension ProntoWallet: PKAddPassesViewControllerDelegate {
    public func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        controller.dismiss(animated: true) { [weak self] in
            // PKAddPassesViewController doesn't distinguish between success and cancel
            // when used with issuer data. We report completion here.
            self?.currentDelegate?.provisioningDidComplete()
            self?.currentDelegate = nil
            self?.currentTask = nil
        }
    }
}

#endif
