import Foundation

/// Manages a WebSocket connection for real-time chat.
final class WebSocketManager: @unchecked Sendable {

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
    }

    private(set) var state: ConnectionState = .disconnected
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    var onMessage: ((ChatWsMessage) -> Void)?
    var onStateChange: ((ConnectionState) -> Void)?

    private let baseURL = AppEnvironment.current.wsBaseURL

    func connect(roomId: String, token: String) {
        guard state == .disconnected || state == .reconnecting else { return }

        let urlString = "\(baseURL)/chats/\(roomId)?token=\(token)"
        guard let url = URL(string: urlString) else { return }

        updateState(.connecting)

        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()

        updateState(.connected)
        reconnectAttempts = 0
        startReceiving(roomId: roomId, token: token)
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        updateState(.disconnected)
        reconnectAttempts = 0
    }

    func send(body: String, imageURL: String? = nil) {
        var payload: [String: String] = ["body": body]
        if let imageURL = imageURL {
            payload["image_url"] = imageURL
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    // MARK: - Private

    private func startReceiving(roomId: String, token: String) {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let ws = self?.webSocketTask else { break }
                do {
                    let message = try await ws.receive()
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8),
                           let wsMessage = try? JSONDecoder().decode(ChatWsMessage.self, from: data) {
                            if let self {
                                await self.deliverMessage(wsMessage)
                            }
                        }
                    case .data(let data):
                        if let wsMessage = try? JSONDecoder().decode(ChatWsMessage.self, from: data) {
                            if let self {
                                await self.deliverMessage(wsMessage)
                            }
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        print("WebSocket receive error: \(error)")
                        self?.handleDisconnect(roomId: roomId, token: token)
                    }
                    break
                }
            }
        }
    }

    @MainActor
    private func deliverMessage(_ message: ChatWsMessage) {
        onMessage?(message)
    }

    private func handleDisconnect(roomId: String, token: String) {
        guard reconnectAttempts < maxReconnectAttempts else {
            updateState(.disconnected)
            return
        }

        updateState(.reconnecting)
        reconnectAttempts += 1

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay = pow(2.0, Double(reconnectAttempts - 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect(roomId: roomId, token: token)
        }
    }

    private func updateState(_ newState: ConnectionState) {
        state = newState
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onStateChange?(newState)
        }
    }
}

// MARK: - WebSocket Message Model

struct ChatWsMessage: Decodable {
    let type: String
    let id: String?
    let room_id: String
    let sender_id: String?
    let body: String
    let message_type: String?
    let image_url: String?
    let created_at: String?
}
