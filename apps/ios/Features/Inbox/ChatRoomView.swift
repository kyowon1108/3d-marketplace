import SwiftUI

struct ChatRoomView: View {
    let room: ChatRoomResponse
    @State private var messageText = ""
    @State private var messages: [ChatMessageResponse] = []
    @State private var isLoading = true
    @State private var isSending = false
    @State private var wsConnected = false
    @State private var productDetail: ProductResponse?
    @Environment(\.dismiss) var dismiss

    private let wsManager = WebSocketManager()

    var body: some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                if let product = productDetail {
                    // Product Summary Header
                    HStack(spacing: Theme.Spacing.md) {
                        AsyncImage(url: URL(string: product.thumbnail_url ?? "")) { phase in
                            switch phase {
                            case .empty:
                                Rectangle().fill(Theme.Colors.bgSecondary)
                            case .success(let img):
                                img.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "cube.transparent")
                                    .foregroundColor(Theme.Colors.violetAccent)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.title)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)
                            Text(formatPrice(product.price_cents))
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.bgSecondary.opacity(0.8))
                    .overlay(
                        VStack {
                            Spacer()
                            Divider().background(Theme.Colors.glassBorder)
                        }
                    )
                }

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Theme.Colors.violetAccent)
                    Spacer()
                } else {
                    ScrollView {
                        ScrollViewReader { proxy in
                            LazyVStack(spacing: Theme.Spacing.md) {
                                // System Safety Warning
                                Text("직거래를 권장하며, 외부 채널 유도나 선입금 요구에 주의하세요.")
                                    .font(.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Theme.Colors.bgSecondary)
                                    .clipShape(Capsule())
                                    .padding(.top, Theme.Spacing.md)
                                    
                                ForEach(messages) { msg in
                                    MessageBubble(message: msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.md)
                            .onAppear {
                                if let last = messages.last {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                            .onChange(of: messages.count) {
                                if let last = messages.last {
                                    withAnimation {
                                        proxy.scrollTo(last.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }

                // Input Area
                VStack {
                    Divider()
                        .background(Theme.Colors.glassBorder)

                    HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
                        ZStack(alignment: .topLeading) {
                            if messageText.isEmpty {
                                Text("메시지를 입력하세요...")
                                    .foregroundColor(Theme.Colors.textMuted)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                            TextEditor(text: $messageText)
                                .frame(minHeight: 36, maxHeight: 100)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .scrollContentBackground(.hidden)
                        }
                        .background(Theme.Colors.bgSecondary)
                        .cornerRadius(20)

                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20))
                                .foregroundColor(messageText.isEmpty || isSending ? Theme.Colors.textMuted : Theme.Colors.violetAccent)
                                .shadow(color: messageText.isEmpty ? .clear : Theme.Colors.neonGlow, radius: 5)
                        }
                        .disabled(messageText.isEmpty || isSending)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .background(Theme.Colors.bgPrimary)
            }
        }
        .navigationTitle(room.subject)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                // Connection status indicator
                Circle()
                    .fill(wsConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .onAppear {
            fetchProductDetail()
            fetchMessages()
            markAsRead()
            connectWebSocket()
        }
        .onDisappear {
            wsManager.disconnect()
        }
    }

    // MARK: - WebSocket

    private func connectWebSocket() {
        guard let token = AuthManager.shared.currentToken else { return }

        wsManager.onMessage = { wsMessage in
            // Deduplicate by message ID
            if let msgId = wsMessage.id, messages.contains(where: { $0.id == msgId }) {
                return
            }

            let chatMsg = ChatMessageResponse(
                id: wsMessage.id ?? UUID().uuidString,
                room_id: wsMessage.room_id,
                sender_id: wsMessage.sender_id ?? "",
                body: wsMessage.body,
                created_at: wsMessage.created_at ?? ""
            )
            messages.append(chatMsg)
        }

        wsManager.onStateChange = { state in
            wsConnected = (state == .connected)
        }

        wsManager.connect(roomId: room.id, token: token)
    }

    // MARK: - REST

    private func fetchProductDetail() {
        Task {
            do {
                let response: ProductResponse = try await APIClient.shared.request(
                    endpoint: "/products/\(room.product_id)",
                    needsAuth: false
                )
                await MainActor.run {
                    self.productDetail = response
                }
            } catch {
                // Silently fail if product no longer exists
            }
        }
    }

    private func fetchMessages() {
        isLoading = true
        Task {
            do {
                let response: ChatMessageListResponse = try await APIClient.shared.request(
                    endpoint: "/chat-rooms/\(room.id)/messages"
                )
                await MainActor.run {
                    self.messages = response.messages
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    NotificationCenter.default.post(
                        name: .showToast,
                        object: Toast(message: (error as? APIError)?.userMessage ?? "메시지를 불러오지 못했습니다.", style: .error)
                    )
                }
            }
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let body = messageText
        messageText = ""

        if wsConnected {
            // Send via WebSocket — will be broadcast back and added via onMessage
            wsManager.send(body: body)
        } else {
            // Fallback to REST
            isSending = true
            Task {
                do {
                    let request = SendMessageRequest(body: body)
                    let encodedBody = try JSONEncoder().encode(request)
                    let sent: ChatMessageResponse = try await APIClient.shared.request(
                        endpoint: "/chat-rooms/\(room.id)/messages",
                        method: "POST",
                        body: encodedBody
                    )
                    await MainActor.run {
                        self.messages.append(sent)
                        self.isSending = false
                    }
                } catch {
                    await MainActor.run {
                        self.isSending = false
                        NotificationCenter.default.post(
                            name: .showToast,
                            object: Toast(message: (error as? APIError)?.userMessage ?? "메시지 전송 실패", style: .error)
                        )
                    }
                }
            }
        }
    }

    private func markAsRead() {
        Task {
            do {
                let _: EmptyResponse = try await APIClient.shared.request(
                    endpoint: "/chat-rooms/\(room.id)/read",
                    method: "POST"
                )
            } catch {
                #if DEBUG
                print("[Chat] Failed to mark messages as read: \(error)")
                #endif
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessageResponse

    private var isMe: Bool {
        guard let userId = AuthManager.shared.currentUser?.id else { return false }
        return message.sender_id == userId
    }

    var body: some View {
        HStack {
            if isMe {
                Spacer()
            }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .font(.body)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 10)
                    .background(isMe ? Theme.Colors.violetAccent : Theme.Colors.bgSecondary)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .clipShape(ChatBubbleShape(isMe: isMe))

                Text(formatTime(from: message.created_at))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.textMuted)
            }

            if !isMe {
                Spacer()
            }
        }
    }
}

private struct ChatBubbleShape: Shape {
    let isMe: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        var path = Path()

        path.addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: radius, height: radius),
            style: .continuous
        )
        return path
    }
}
