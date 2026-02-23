import Foundation

enum AppEnvironment {
    case local
    case beta

    var apiBaseURL: String {
        switch self {
        case .local:
            return "http://100.95.177.6:8000/v1"
        case .beta:
            return "https://api.3d-marketplace.example.com/v1"
        }
    }

    var wsBaseURL: String {
        switch self {
        case .local:
            return "ws://100.95.177.6:8000/v1"
        case .beta:
            return "wss://api.3d-marketplace.example.com/v1"
        }
    }

    static var current: AppEnvironment {
        #if DEBUG
        return .local
        #else
        return .beta
        #endif
    }
}
