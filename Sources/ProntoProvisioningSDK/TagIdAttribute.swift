import Foundation

/// The attribute used to identify a tag when requesting provisioning.
public enum TagIdAttribute: String, Sendable {
    case referenceId = "reference_id"
    case prontoTagId = "pronto_tag_id"
    case subscriptionId = "subscription_id"
}
