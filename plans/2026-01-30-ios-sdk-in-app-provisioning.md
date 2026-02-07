# iOS SDK for Apple Account-Bound Pass In-App Provisioning

## Overview

Create an iOS SDK distributed via Swift Package Manager that enables Pronto's clients to provision Apple Account-bound passes directly from their iOS apps using the native `PKAddPassesViewController` API.

**Key Requirements:**
- Target: Pronto's clients + Pronto's own app
- Distribution: Swift Package Manager only
- Scope: Provisioning only (account binding + pass provisioning)
- Auth: Existing `APIUser` model (already belongs to Client)
- Single-pass per request (same as web flow)

---

## Architecture

### Current (Web Flow)
```
User → Webpage → Universal Link (wallet.apple.com/securePassSession#...) → Apple → Callback → .pkpass
```

### New (In-App Flow)
```
User → iOS App → SDK → Pronto API → (issuerData + signature) → PKAddPassesViewController → Apple → Callback → .pkpass
```

---

## Part 1: Rails Backend Changes (pronto-web)

### 1.1 Reuse Existing `APIUser` Model

The existing `APIUser` model already provides everything needed:
- `auth_token` for authentication
- `belongs_to :client` for scoping
- Soft delete support
- HTTP Basic Auth pattern in `API::V2::BaseController`

**No new API key model needed.**

### 1.2 New API Endpoints (No New Models)

Add to existing API v2 namespace (or create v4 if preferred):

**POST `/api/v2/in_app_provisioning/issuer_data`**
```json
// Request (HTTP Basic Auth with APIUser auth_token)
{
  "tag_id": "PASS-001",
  "id_attribute": "reference_id"  // or "pronto_tag_id", "subscription_id"
}

// Response
{
  "issuer_data": "<base64>",
  "signature": "<base64>",
  "tag_id": "123"
}
```

**POST `/api/v2/in_app_provisioning/callback`** (Apple calls this - no auth)
- Uses tag ID (from `sessionIdentifier` in binding data) to find the pass
- Stores binding data, regenerates pass
- Returns `.pkpass`

**Note:** Uses tag ID as `sessionIdentifier` - same pattern as web flow.

### 1.3 Files to Create

| File | Purpose |
|------|---------|
| `app/controllers/api/v2/in_app_provisioning_controller.rb` | Issuer data endpoint |
| `app/controllers/api/v2/in_app_provisioning_callback_controller.rb` | Apple callback |
| `spec/requests/api/v2/in_app_provisioning_spec.rb` | Request spec |

### 1.4 Files to Modify

| File | Change |
|------|--------|
| `config/routes.rb` | Add in_app_provisioning routes under api/v2 |

### 1.5 Controller Implementation

```ruby
# app/controllers/api/v2/in_app_provisioning_controller.rb
class API::V2::InAppProvisioningController < API::V2::BaseController
  before_action :require_api_user_with_client

  def issuer_data
    tag = find_tag
    return render_not_found unless tag&.apple_pass

    apple_pass = tag.apple_pass
    binding_data = build_binding_data(apple_pass, tag)

    # Store binding data on the pass (same as web flow)
    apple_pass.update!(account_binding_data: binding_data)

    signature = sign_binding_data(binding_data, apple_pass.apple_pass_type)

    render json: {
      issuer_data: Base64.strict_encode64(binding_data.to_json),
      signature: Base64.strict_encode64(signature.to_der),
      tag_id: tag.id
    }
  end

  private

  def find_tag
    id_attr = params[:id_attribute]&.to_sym || :reference_id
    api_user.client.tags
            .includes(:apple_pass, :user)
            .find_by(id_attr => params[:tag_id])
  end

  def build_binding_data(apple_pass, tag)
    # Same structure as web flow - uses tag.id as sessionIdentifier
    {
      "fidoProfile" => {
        "relyingPartyIdentifier" => Rails.application.routes.default_url_options[:host],
        "accountHash" => apple_pass.user.hashid
      },
      "creationTimestamp" => Time.now.iso8601,
      "sessionIdentifier" => tag.id.to_s,  # Tag ID as session identifier
      "callbackURL" => api_v2_in_app_provisioning_callback_url,
      "passTypeIdentifier" => apple_pass.apple_pass_type.bundle_id,
      "teamIdentifier" => apple_pass.apple_pass_type.team_id,
      "displayableName" => apple_pass.apple_pass_type.organization_name
    }
  end

  def sign_binding_data(data, pass_type)
    PassKit::Signer.sign_content(
      content: data.to_json,
      p12_cert: pass_type.p12_cert,
      wwdr_cert: Rails.root.join("lib/pass_kit/wwdr4.cer").read
    )
  end
end
```

---

## Part 2: iOS SDK (ProntoWalletSDK)

### 2.1 Package Structure

```
ProntoWalletSDK/
├── Package.swift
├── Sources/ProntoWalletSDK/
│   ├── ProntoWallet.swift              # Main entry point + public API
│   ├── ProntoConfiguration.swift       # API key + environment config
│   ├── ProntoEnvironment.swift         # Pronto environments (prod/staging/demo/dev)
│   ├── ProvisioningError.swift         # Error types
│   ├── ProvisioningDelegate.swift      # Delegate protocol
│   └── Internal/
│       ├── APIClient.swift             # HTTP client with Basic Auth
│       └── IssuerDataResponse.swift    # API response model
├── Tests/ProntoWalletSDKTests/
└── README.md
```

### 2.2 Pronto Environments

```swift
// ProntoEnvironment.swift
public enum ProntoEnvironment {
    case production
    case staging
    case demo
    case development(host: String)
    case custom(URL)

    var baseURL: URL {
        switch self {
        case .production:
            return URL(string: "https://app.prontocx.com")!
        case .staging:
            return URL(string: "https://app.stage.prontocx.com")!
        case .demo:
            return URL(string: "https://app.demo.prontocx.com")!
        case .development(let host):
            return URL(string: "http://\(host)")!
        case .custom(let url):
            return url
        }
    }
}
```

### 2.3 Configuration

```swift
// ProntoConfiguration.swift
public struct ProntoConfiguration {
    public let apiKey: String        // APIUser auth_token
    public let environment: ProntoEnvironment
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
```

### 2.4 Public API

```swift
// ProntoWallet.swift
public final class ProntoWallet {
    public static let shared = ProntoWallet()

    private var configuration: ProntoConfiguration?

    /// Configure the SDK with your API key (from Pronto admin)
    public func configure(with configuration: ProntoConfiguration) {
        self.configuration = configuration
    }

    /// Check if Apple Wallet is available
    public var isWalletAvailable: Bool {
        PKAddPassesViewController.canAddPasses()
    }

    /// Provision a pass to Apple Wallet
    public func provisionPass(
        tagId: String,
        idAttribute: TagIdAttribute = .referenceId,
        from presentingViewController: UIViewController,
        delegate: ProvisioningDelegate
    )
}

public enum TagIdAttribute: String {
    case referenceId = "reference_id"
    case prontoTagId = "pronto_tag_id"
    case subscriptionId = "subscription_id"
}
```

### 2.5 Delegate Protocol

```swift
public protocol ProvisioningDelegate: AnyObject {
    func provisioningDidComplete()
    func provisioning(didFailWith error: ProvisioningError)
    func provisioningDidCancel()
}

public enum ProvisioningError: Error {
    case notConfigured
    case walletNotAvailable
    case networkError(Error)
    case serverError(statusCode: Int, message: String?)
    case invalidResponse
    case passKitError(Error)
}
```

### 2.6 Usage Example

```swift
import ProntoWalletSDK

// In AppDelegate or app initialization
ProntoWallet.shared.configure(with: ProntoConfiguration(
    apiKey: "your_api_user_auth_token",
    environment: .staging  // or .production, .demo, .development(host: "localhost:3000")
))

// When user taps "Add to Wallet"
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
        showSuccess("Pass added to Wallet!")
    }

    func provisioning(didFailWith error: ProvisioningError) {
        showError(error.localizedDescription)
    }

    func provisioningDidCancel() {
        // User cancelled
    }
}
```

---

## Part 3: Implementation Phases

### Phase 1: Backend - Routes & Controllers
- [X] Add routes to `config/routes.rb`
- [X] Implement `in_app_provisioning_controller.rb` (issuer_data action)
- [X] Implement `in_app_provisioning_callback_controller.rb`
- [X] Write request specs
- [X] Test with curl

### Phase 2: iOS SDK - Core
- [ ] Create Swift Package structure with `Package.swift`
- [ ] Implement `ProntoEnvironment`, `ProntoConfiguration`
- [ ] Implement `APIClient` with HTTP Basic Auth
- [ ] Implement error types
- [ ] Write unit tests

### Phase 3: iOS SDK - Provisioning
- [ ] Implement `PassProvisioner` using `PKAddPassesViewController(issuerData:signature:)`
- [ ] Implement delegate callbacks
- [ ] Integration test on physical device

### Phase 4: Polish & Documentation
- [ ] README with setup instructions
- [ ] API documentation (DocC)
- [ ] Sample app demonstrating usage
- [ ] Publish to GitHub (SPM-compatible repo)

---

## Part 4: Key Implementation Details

### Reuse Existing Code

**Signing logic** (`lib/pass_kit/signer.rb:24-33`):
```ruby
PassKit::Signer.sign_content(
  content: binding_data.to_json,
  p12_cert: apple_pass_type.p12_cert,
  wwdr_cert: wwdr_cert
)
```

**Binding data structure** (`app/models/apple_pass.rb:68-81`):
```ruby
{
  "fidoProfile" => { "relyingPartyIdentifier" => ..., "accountHash" => ... },
  "creationTimestamp" => Time.now.iso8601,
  "sessionIdentifier" => tag.id.to_s,  # Tag ID as session identifier (same as web)
  "callbackURL" => "https://app.prontocx.com/api/v2/in_app_provisioning/callback",
  "passTypeIdentifier" => ...,
  "teamIdentifier" => ...,
  "displayableName" => ...
}
```

### Authentication Flow

1. Client app configures SDK with `APIUser.auth_token` (from Pronto admin)
2. SDK sends HTTP Basic Auth: `Authorization: Basic base64(auth_token:)`
3. Backend validates via existing `api_user` method in `API::V2::BaseController`
4. Requests scoped to `api_user.client` (can only access own passes)

---

## Part 5: Verification

### Backend Testing
```bash
# Run specs
bundle exec rspec spec/requests/api/v2/in_app_provisioning_spec.rb

# Manual test
curl -X POST https://app.stage.prontocx.com/api/v2/in_app_provisioning/issuer_data \
  -u "your_api_user_auth_token:" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{"tag_id": "PASS-001"}'
```

### iOS SDK Testing
1. Get `APIUser` auth_token from Pronto admin for a client
2. Configure SDK with staging environment
3. Call `provisionPass` with a valid tag reference ID
4. Verify Apple Wallet binding UI appears
5. Complete binding with Face ID
6. Verify pass appears in Wallet

### Test Cases
1. Single pass provisioning (happy path)
2. Invalid auth token → 401/403
3. Non-existent pass → 404
4. Pass from wrong client → 404 (scoped)
5. Pass without apple_pass → 404
6. User cancellation in SDK

---

## Dependencies

### Backend (pronto-web)
- No new gems required
- Uses existing `PassKit::Signer` and `APIUser`

### iOS SDK
- iOS 15.0+ (for `PKAddPassesViewController.init(issuerData:signature:)`)
- PassKit framework (system)
- No external dependencies

---

## Future: React Native Support

The Swift Package can be wrapped for React Native:
```
@pronto/wallet-sdk-react-native (npm)
  └── depends on ProntoWalletSDK (SPM)
```

This would be a separate project that bridges the native Swift SDK to JavaScript/TypeScript.
