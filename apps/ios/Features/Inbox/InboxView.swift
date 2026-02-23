import SwiftUI

struct InboxView: View {
    @State private var chatRooms: [ChatRoomResponse] = []
    @State private var isLoading = true
    @State private var selectedTab = "전체"
    let tabs = ["전체", "판매", "구매", "안읽음"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    CustomSegmentedPicker(options: tabs, selection: $selectedTab)
                        .padding(.top, Theme.Spacing.sm)
                        .padding(.bottom, Theme.Spacing.md)

                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Theme.Colors.violetAccent)
                        Spacer()
                    } else if filteredRooms(chatRooms).isEmpty {
                        Spacer()
                        EmptyStateView(
                            title: "진행 중인 대화가 없습니다",
                            message: "선택한 조건에 맞는 채팅방이 없습니다.",
                            systemImage: "bubble.left.and.bubble.right",
                            actionTitle: "탐색 탭으로 가기"
                        ) {
                            AppToast(message: "탐색 탭에서 상품을 찾아보세요", style: .info)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredRooms(chatRooms)) { room in
                                NavigationLink(destination: ChatRoomView(room: room)) {
                                    HStack(spacing: Theme.Spacing.md) {
                                        // Left: Product Thumbnail + User avatar overlay
                                        ZStack(alignment: .bottomTrailing) {
                                            if let thumbURL = room.product_thumbnail_url, let url = URL(string: thumbURL) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image.resizable().scaledToFill()
                                                    default:
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Theme.Colors.bgSecondary)
                                                            .overlay(
                                                                Image(systemName: "cube.fill")
                                                                    .foregroundColor(Theme.Colors.textMuted)
                                                            )
                                                    }
                                                }
                                                .frame(width: 48, height: 48)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Theme.Colors.bgSecondary)
                                                    .frame(width: 48, height: 48)
                                                    .overlay(
                                                        Image(systemName: "cube.fill")
                                                            .foregroundColor(Theme.Colors.textMuted)
                                                    )
                                            }
                                        }

                                        // Center: Message info
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 4) {
                                                Text(partnerName(for: room))
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Theme.Colors.textPrimary)

                                                Text(relativeTime(from: room.last_message_at ?? room.created_at))
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Theme.Colors.textSecondary)
                                            }

                                            Text(room.last_message_body ?? "메시지가 없습니다.")
                                                .font(.system(size: 14))
                                                .foregroundColor(Theme.Colors.textSecondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()
                                        
                                        // Right: Unread Badge
                                        if room.unread_count > 0 {
                                            Text("\(room.unread_count)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(minWidth: 20, minHeight: 20)
                                                .padding(.horizontal, 6)
                                                .background(Theme.Colors.violetAccent)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.vertical, Theme.Spacing.xs)
                                }
                                .padding(.vertical, Theme.Spacing.xs)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Theme.Colors.glassBorder)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("메시지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.Colors.bgPrimary, for: .navigationBar)
            .onAppear {
                fetchChatRooms()
            }
        }
    }

    private func fetchChatRooms() {
        isLoading = true
        Task {
            do {
                let response: ChatRoomListResponse = try await APIClient.shared.request(
                    endpoint: "/chat-rooms"
                )
                await MainActor.run {
                    self.chatRooms = response.rooms
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    NotificationCenter.default.post(
                        name: .showToast,
                        object: Toast(message: (error as? APIError)?.userMessage ?? "채팅 목록을 불러오지 못했습니다.", style: .error)
                    )
                }
            }
        }
    }

    private func partnerName(for room: ChatRoomResponse) -> String {
        let currentUserId = AuthManager.shared.currentUser?.id
        if room.buyer_id == currentUserId {
            return room.seller_name.isEmpty ? "판매자" : room.seller_name
        } else {
            return room.buyer_name.isEmpty ? "구매자" : room.buyer_name
        }
    }

    private func filteredRooms(_ rooms: [ChatRoomResponse]) -> [ChatRoomResponse] {
        switch selectedTab {
        case "판매":
            return rooms.filter { $0.seller_id == AuthManager.shared.currentUser?.id }
        case "구매":
            return rooms.filter { $0.buyer_id == AuthManager.shared.currentUser?.id }
        case "안읽음":
            return rooms.filter { $0.unread_count > 0 }
        default:
            return rooms
        }
    }
}
