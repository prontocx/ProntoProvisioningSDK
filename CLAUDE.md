# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ProntoProvisioningSDK is a Swift Package for iOS that enables in-app provisioning of Apple Account-bound passes to Apple Wallet. It wraps Apple's `PKAddPassesViewController(issuerData:signature:)` API, handling the full flow: fetching issuer data from the Pronto API, presenting the native Wallet binding UI, and reporting results via a delegate.

The SDK is consumed by Pronto's clients and Pronto's own iOS app. The corresponding backend lives in the `pronto-web` Rails app (separate repo).

## Build & Test Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run a single test class
swift test --filter ProntoProvisioningSDKTests.APIClientTests

# Run a single test method
swift test --filter ProntoProvisioningSDKTests.APIClientTests/testFetchIssuerDataSuccess
```

Tests run on macOS (not iOS simulator) since `ProntoWallet.swift` is gated behind `#if canImport(UIKit) && canImport(PassKit)`. All testable logic lives in platform-independent files (`APIClient`, `IssuerDataResponse`, `ProntoEnvironment`, `ProntoConfiguration`, `ProvisioningError`, `TagIdAttribute`).

## Architecture

**Public API surface** — a singleton `ProntoWallet.shared` configured once at launch with `ProntoConfiguration` (API key + environment + timeout). Callers invoke `provisionPass(tagId:idAttribute:from:delegate:)` and receive lifecycle callbacks via `ProvisioningDelegate`.

**Internal flow:**
1. `ProntoWallet.provisionPass` validates config and wallet availability
2. Creates an `APIClient` and calls `fetchIssuerData` (async)
3. `APIClient` sends POST to `/api/v2/in_app_provisioning/issuer_data` with HTTP Basic Auth (`apiKey:` base64-encoded)
4. Decodes `IssuerDataResponse` (issuer_data, signature, tag_id — snake_case JSON)
5. Presents `PKAddPassesViewController` with the decoded issuer data and signature
6. Apple handles the binding (Face ID/Touch ID) and calls Pronto's callback endpoint
7. `PKAddPassesViewControllerDelegate` fires `provisioningDidComplete` back to the caller

**Key design decisions:**
- `ProntoWallet` is `@MainActor` and conditionally compiled (`#if canImport(UIKit) && canImport(PassKit)`) — it doesn't exist on macOS builds
- `APIClient` accepts a `URLSessionProtocol` for dependency injection; tests use `MockURLSession`
- All errors flow through `ProvisioningError` (conforms to `LocalizedError`)
- `ProntoEnvironment` maps named environments (production, staging, demo, development) to base URLs
- No external dependencies — only Foundation, UIKit, and PassKit

## Environments

| Case | Base URL |
|------|----------|
| `.production` | `https://app.prontocx.com` |
| `.staging` | `https://app.stage.prontocx.com` |
| `.demo` | `https://app.demo.prontocx.com` |
| `.development(host:)` | `http://<host:port>` |
| `.custom(URL)` | Any URL |

## Testing Patterns

- Tests use `@testable import ProntoProvisioningSDK` to access internal types
- `MockURLSession` implements `URLSessionProtocol` and captures/returns configurable responses
- `APIClient.buildRequest` is internal (not private) specifically to enable request-building tests without network calls
- Typed throws (`throws(ProvisioningError)`) are used on `fetchIssuerData` — test catch blocks match specific error cases
