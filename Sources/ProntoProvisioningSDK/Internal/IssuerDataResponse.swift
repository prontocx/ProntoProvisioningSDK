import Foundation

/// Response from the Pronto API issuer_data endpoint.
struct IssuerDataResponse: Decodable {
    let issuerData: String
    let signature: String
    let tagId: Int

    enum CodingKeys: String, CodingKey {
        case issuerData = "issuer_data"
        case signature
        case tagId = "tag_id"
    }
}
