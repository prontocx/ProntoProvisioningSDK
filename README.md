# ProntoProvisioningSDK

An iOS SDK for provisioning Apple Account-bound passes directly from your app using Apple's native `PKAddPassesViewController` API.

The SDK handles the full in-app provisioning flow: fetching issuer data from the Pronto API, presenting the Apple Wallet binding UI, and reporting the result back to your app via a delegate.

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15+
- A Pronto API user auth token (obtained from Pronto admin)

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/prontocx/ProntoProvisioningSDK.git", from: "1.0.0")
]
```

Or in Xcode: **File > Add Package Dependencies**, then enter the repository URL.

## Configuration

Configure the SDK once during app launch, before attempting to provision any passes.

```swift
import ProntoProvisioningSDK

// In AppDelegate or app initialization
ProntoWallet.shared.configure(with: ProntoConfiguration(
    apiKey: "your_api_user_auth_token",
    environment: .production
))
```

### ProntoConfiguration

| Parameter     | Type                | Default       | Description                                      |
|---------------|---------------------|---------------|--------------------------------------------------|
| `apiKey`      | `String`            | *required*    | Your API user auth token from the Pronto admin.  |
| `environment` | `ProntoEnvironment` | `.production` | The Pronto environment to connect to.            |
| `timeout`     | `TimeInterval`      | `30.0`        | Network request timeout in seconds.              |

### Environments

| Environment                       | URL                                 |
|-----------------------------------|-------------------------------------|
| `.production`                     | `https://app.prontocx.com`          |
| `.staging`                        | `https://app.stage.prontocx.com`    |
| `.demo`                           | `https://app.demo.prontocx.com`     |
| `.development(host: "host:port")` | `http://<host:port>`                |
| `.custom(URL)`                    | Any custom URL                      |

## Usage

### Provisioning a Pass

Call `provisionPass` when the user taps your "Add to Wallet" button. The SDK will fetch the issuer data from the Pronto API and present the native Apple Wallet binding UI.

```swift
import ProntoProvisioningSDK

class TicketsViewController: UIViewController, ProvisioningDelegate {

    @IBAction func addToWalletTapped() {
        ProntoWallet.shared.provisionPass(
            tagId: "TICKET-001",
            idAttribute: .referenceId,
            from: self,
            delegate: self
        )
    }

    // MARK: - ProvisioningDelegate

    func provisioningDidComplete() {
        showAlert("Pass added to Wallet!")
    }

    func provisioning(didFailWith error: ProvisioningError) {
        showAlert(error.localizedDescription)
    }

    func provisioningDidCancel() {
        // User dismissed the Wallet UI
    }
}
```

### Fetching a User's Passes

Use `fetchPasses` to retrieve the passes associated with a user. This is a pure data fetch with no UI — it returns an array of `Pass` objects via async/await.

```swift
do {
    let passes = try await ProntoWallet.shared.fetchPasses(userId: "user-123")
    for pass in passes {
        print(pass.id, pass.active, pass.downloadURL)
    }
} catch {
    print(error.localizedDescription)
}
```

Each `Pass` contains:

| Property             | Type      | Description                              |
|----------------------|-----------|------------------------------------------|
| `id`                 | `String`  | The pass reference ID.                   |
| `active`             | `Bool`    | Whether the pass is currently active.    |
| `downloadURL`        | `String`  | URL to download the pass.                |
| `downloadURLApple`   | `String?` | Apple-specific download URL, if available. |
| `downloadURLGoogle`  | `String?` | Google-specific download URL, if available. |

### Tag ID Attributes

The `idAttribute` parameter controls which field is used to look up the tag on the Pronto backend:

| Value             | API Parameter     | Description                              |
|-------------------|-------------------|------------------------------------------|
| `.referenceId`    | `reference_id`    | Your external reference ID (default).    |
| `.prontoTagId`    | `pronto_tag_id`   | The Pronto-assigned tag ID.              |
| `.subscriptionId` | `subscription_id` | The subscription ID linked to the tag.   |

### Checking Wallet Availability

You can check whether Apple Wallet is available on the device before showing your "Add to Wallet" button:

```swift
if ProntoWallet.shared.isWalletAvailable {
    addToWalletButton.isHidden = false
}
```

## Error Handling

All errors are reported through the `ProvisioningDelegate` as `ProvisioningError` values:

| Error                | Cause                                                                 |
|----------------------|-----------------------------------------------------------------------|
| `.notConfigured`     | `configure(with:)` was not called before provisioning.                |
| `.walletNotAvailable`| Apple Wallet is not available on this device.                         |
| `.networkError(_)`   | A network error occurred (no connection, timeout, etc).               |
| `.serverError(_, _)` | The Pronto API returned an error (401 unauthorized, 404 not found, etc). |
| `.invalidResponse`   | The API response could not be parsed.                                 |
| `.passKitError(_)`   | PassKit failed to present the provisioning UI.                        |

All cases conform to `LocalizedError`, so you can use `error.localizedDescription` for user-facing messages.

## How It Works

1. Your app calls `provisionPass(tagId:idAttribute:from:delegate:)`.
2. The SDK sends a `POST` request to the Pronto API (`/api/v2/in_app_provisioning/issuer_data`) with HTTP Basic Auth using your API key.
3. The API returns the issuer data and signature needed for Apple's account binding flow.
4. The SDK presents a `PKAddPassesViewController` initialized with the issuer data and signature.
5. The user completes the binding (Face ID / Touch ID) through Apple's native UI.
6. Apple calls the Pronto callback endpoint, which generates and delivers the `.pkpass` to the user's Wallet.
7. The SDK reports the result to your delegate.

## License

Copyright Pronto. All rights reserved.
