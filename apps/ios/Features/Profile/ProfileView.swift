import SwiftUI

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var productCount: Int = 0
    @State private var unreadMessages: Int = 0

    // My products and liked products
    @State private var myProducts: [Product] = []
    @State private var likedProducts: [Product] = []
    @State private var isLoadingProducts = false
    @State private var isLoadingLiked = false
    @State private var didLoadMyProducts = false
    @State private var didLoadLiked = false

    var body: some View {
        NavigationStack {
            List {
                // Profile Header Card
                Section {
                    NavigationLink(destination: ProfileEditView()) {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.violetAccent)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.currentUser?.name ?? "크리에이터")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                if let location = authManager.currentUser?.location_name, !location.isEmpty {
                                    Text(location)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }

                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Theme.Colors.bgSecondary)

                    // Stats quick row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("판매상품")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("\(productCount)개")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("안읽은 채팅")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("\(unreadMessages)개")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Theme.Colors.bgSecondary)
                }

                // My Trades Section
                Section(header: Text("나의 거래").foregroundColor(Theme.Colors.textSecondary)) {
                    NavigationLink(
                        destination: MyProductsListView(
                            products: myProducts,
                            title: "판매내역",
                            emptyTitle: "판매내역이 없습니다",
                            emptyMessage: "아직 등록한 판매 상품이 없습니다."
                        )
                    ) {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "text.book.closed")
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 24)
                            Text("판매내역")
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }
                    .listRowBackground(Theme.Colors.bgSecondary)

                    NavigationLink(destination: PurchaseHistoryView()) {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "bag")
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 24)
                            Text("구매내역")
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }
                    .listRowBackground(Theme.Colors.bgSecondary)
                }

                // My Interests
                Section(header: Text("나의 관심").foregroundColor(Theme.Colors.textSecondary)) {
                    NavigationLink(
                        destination: MyProductsListView(
                            products: likedProducts,
                            title: "관심목록",
                            emptyTitle: "관심목록이 없습니다",
                            emptyMessage: "아직 관심 등록한 상품이 없습니다."
                        )
                    ) {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "heart")
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 24)
                            Text("관심목록")
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }
                    .listRowBackground(Theme.Colors.bgSecondary)
                }

                // Settings Section
                Section(header: Text("기타").foregroundColor(Theme.Colors.textSecondary)) {
                    NavigationLink(destination: SettingsView()) {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "gearshape")
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 24)
                            Text("설정")
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }
                    .listRowBackground(Theme.Colors.bgSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.bgPrimary)
            .navigationTitle("마이페이지")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.Colors.bgPrimary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }
            .refreshable {
                fetchSummary()
                didLoadMyProducts = false
                didLoadLiked = false
                fetchMyProducts()
                fetchLikedProducts()
            }
            .onAppear {
                fetchSummary()
                if !didLoadMyProducts { fetchMyProducts() }
                if !didLoadLiked { fetchLikedProducts() }
            }
        }
    }

    // MARK: - Networking

    private func fetchSummary() {
        Task {
            do {
                let response: UserSummaryResponse = try await APIClient.shared.request(
                    endpoint: "/me/summary"
                )
                await MainActor.run {
                    self.productCount = response.product_count
                    self.unreadMessages = response.unread_messages
                }
            } catch {
                // Silently fail — stats stay at 0
            }
        }
    }

    private func fetchMyProducts() {
        guard let userId = authManager.currentUser?.id else { return }
        isLoadingProducts = true
        Task {
            do {
                let response: ProductListResponse = try await APIClient.shared.request(
                    endpoint: "/products?seller_id=\(userId)"
                )
                let fetched = response.products.map { p in
                    Product(
                        id: UUID(uuidString: p.id) ?? UUID(),
                        title: p.title,
                        creator: p.seller_name ?? "알 수 없는 판매자",
                        priceCents: p.price_cents,
                        status: p.status,
                        likes: p.likes_count ?? 0,
                        thumbnailUrl: p.thumbnail_url,
                        createdAt: p.created_at,
                        chatCount: p.chat_count ?? 0
                    )
                }
                await MainActor.run {
                    self.myProducts = fetched
                    self.isLoadingProducts = false
                    self.didLoadMyProducts = true
                }
            } catch {
                await MainActor.run {
                    self.isLoadingProducts = false
                }
            }
        }
    }

    private func fetchLikedProducts() {
        isLoadingLiked = true
        Task {
            do {
                let response: ProductListResponse = try await APIClient.shared.request(
                    endpoint: "/products?liked=true"
                )
                let fetched = response.products.map { p in
                    Product(
                        id: UUID(uuidString: p.id) ?? UUID(),
                        title: p.title,
                        creator: p.seller_name ?? "알 수 없는 판매자",
                        priceCents: p.price_cents,
                        status: p.status,
                        likes: p.likes_count ?? 0,
                        thumbnailUrl: p.thumbnail_url,
                        createdAt: p.created_at,
                        chatCount: p.chat_count ?? 0
                    )
                }
                await MainActor.run {
                    self.likedProducts = fetched
                    self.isLoadingLiked = false
                    self.didLoadLiked = true
                }
            } catch {
                await MainActor.run {
                    self.isLoadingLiked = false
                }
            }
        }
    }
}

// MARK: - My Products List View

private struct MyProductsListView: View {
    let products: [Product]
    var title: String = "목록"
    var emptyTitle: String = "상품이 없습니다"
    var emptyMessage: String = "아직 등록된 상품이 없습니다."
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()

            if products.isEmpty {
                EmptyStateView(
                    title: emptyTitle,
                    message: emptyMessage,
                    systemImage: "cube.box",
                    actionTitle: "홈으로 가기"
                ) {
                    dismiss()
                    NotificationCenter.default.post(name: .switchToHomeTab, object: nil)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(products) { product in
                            NavigationLink(destination: ProductDetailView(productId: product.id)) {
                                ProductListRow(product: product)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, Theme.Spacing.md)
                        }
                    }
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Purchase History View

struct PurchaseHistoryView: View {
    @State private var purchases: [PurchaseItem] = []
    @State private var isLoading = true
    @State private var totalCount = 0
    @Environment(\.dismiss) private var dismiss

    struct PurchaseItem: Identifiable {
        let id: UUID
        let product: Product?
        let priceCents: Int
        let purchasedAt: String
    }

    var body: some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()

            if isLoading {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(0..<4, id: \.self) { _ in ProductListRowSkeleton() }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
                }
            } else if purchases.isEmpty {
                EmptyStateView(
                    title: "구매내역이 없습니다",
                    message: "아직 구매한 상품이 없습니다.",
                    systemImage: "bag",
                    actionTitle: "홈으로 가기"
                ) {
                    dismiss()
                    NotificationCenter.default.post(name: .switchToHomeTab, object: nil)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(purchases) { item in
                            if let product = item.product {
                                NavigationLink(destination: ProductDetailView(productId: product.id)) {
                                    ProductListRow(product: product)
                                }
                                .buttonStyle(.plain)
                            }

                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, Theme.Spacing.md)
                        }
                    }
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await fetchPurchases()
                }
            }
        }
        .navigationTitle("구매내역")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if purchases.isEmpty {
                Task { await fetchPurchases() }
            }
        }
    }

    private func fetchPurchases() async {
        isLoading = true
        do {
            let response: PurchaseListAPIResponse = try await APIClient.shared.request(
                endpoint: "/me/purchases"
            )
            let items = response.purchases.map { p in
                let product: Product? = {
                    guard let pr = p.product else { return nil }
                    return Product(
                        id: UUID(uuidString: pr.id) ?? UUID(),
                        title: pr.title,
                        creator: pr.seller_name ?? "판매자",
                        priceCents: pr.price_cents,
                        status: pr.status,
                        likes: pr.likes_count ?? 0,
                        thumbnailUrl: pr.thumbnail_url,
                        createdAt: pr.created_at,
                        chatCount: pr.chat_count ?? 0
                    )
                }()
                return PurchaseItem(
                    id: UUID(uuidString: p.id) ?? UUID(),
                    product: product,
                    priceCents: p.price_cents,
                    purchasedAt: p.purchased_at
                )
            }
            await MainActor.run {
                self.purchases = items
                self.totalCount = response.total
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: (error as? APIError)?.userMessage ?? "구매내역 불러오기 실패", style: .error)
                )
            }
        }
    }
}
