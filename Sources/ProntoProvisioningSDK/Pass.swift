import Foundation

/// A user's pass fetched from the Pronto API.
public struct Pass: Decodable, Sendable {
    public let id: String
    public let active: Bool
    public let downloadURL: String
    public let downloadURLApple: String?
    public let downloadURLGoogle: String?
}

// MARK: - JSON API Envelope

/// Internal response wrapper matching the JSON API `data` array format.
struct PassesResponse: Decodable {
    let data: [PassResource]

    struct PassResource: Decodable {
        let id: String
        let type: String
        let attributes: Attributes

        struct Attributes: Decodable {
            let active: Bool
            let downloadURL: String
            let downloadURLApple: String?
            let downloadURLGoogle: String?

            enum CodingKeys: String, CodingKey {
                case active
                case downloadURL = "download_url"
                case downloadURLApple = "download_url_apple"
                case downloadURLGoogle = "download_url_google"
            }
        }
    }

    func toPasses() -> [Pass] {
        data.map { resource in
            Pass(
                id: resource.id,
                active: resource.attributes.active,
                downloadURL: resource.attributes.downloadURL,
                downloadURLApple: resource.attributes.downloadURLApple,
                downloadURLGoogle: resource.attributes.downloadURLGoogle
            )
        }
    }
}
