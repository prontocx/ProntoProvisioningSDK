import Foundation

/// Delegate protocol for receiving provisioning lifecycle events.
public protocol ProvisioningDelegate: AnyObject {
    /// Called when the pass has been successfully provisioned to Apple Wallet.
    func provisioningDidComplete()

    /// Called when provisioning fails with an error.
    func provisioning(didFailWith error: ProvisioningError)

    /// Called when the user cancels the provisioning flow.
    func provisioningDidCancel()
}
