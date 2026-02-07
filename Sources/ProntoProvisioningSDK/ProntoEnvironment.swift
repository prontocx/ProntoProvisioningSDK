import Foundation

/// Represents the Pronto server environment to connect to.
public enum ProntoEnvironment: Sendable {
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
