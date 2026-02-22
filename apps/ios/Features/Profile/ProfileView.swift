import SwiftUI

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var productCount: Int = 0
    @State private var unreadMessages: Int = 0
    @State private var showLogoutConfirmation = false

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
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.violetAccent)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentUser?.name ?? "크리에이터")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            HStack(spacing: 4) {
                                Text(authManager.currentUser?.location_name ?? "지역 설정")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Theme.Colors.bgSecondary)
                    
                    // Stats quick row (Pay/Points Mock)
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
                    NavigationLink(destination: MyProductsListView(products: myProducts)) {
                        HStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "text.book.closed")
                                .foregroundColor(Theme.Colors.textPrimary)
                                .frame(width: 24)
                            Text("판매내역")
                                .foregroundColor(Theme.Colors.textPrimary)
                        }
                    }
                    .listRowBackground(Theme.Colors.bgSecondary)
                    
                    NavigationLink(destination: Text("구매내역 뷰 (준비 중)").foregroundColor(Theme.Colors.textPrimary)) {
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
                    NavigationLink(destination: MyProductsListView(products: likedProducts)) {
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
                    Button(action: { showLogoutConfirmation = true }) {
                        HStack {
                            Text("로그아웃")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .listRowBackground(Theme.Colors.bgSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.bgPrimary)
            .navigationTitle("나의 당근")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.Colors.bgPrimary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                }
            }
            .confirmationDialog("로그아웃 하시겠습니까?", isPresented: $showLogoutConfirmation) {
                Button("로그아웃", role: .destructive) {
                    authManager.logout()
                }
                Button("취소", role: .cancel) {}
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
                        price: "$\(String(format: "%.2f", Double(p.price_cents) / 100.0))",
                        likes: p.likes_count ?? 0,
                        thumbnailUrl: p.thumbnail_url
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
                        price: "$\(String(format: "%.2f", Double(p.price_cents) / 100.0))",
                        likes: p.likes_count ?? 0,
                        thumbnailUrl: p.thumbnail_url
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

private struct MyProductsListView: View {
    let products: [Product]
    
    var body: some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()
            
            if products.isEmpty {
                EmptyStateView(
                    title: "상품이 없습니다",
                    message: "아직 등록된(관심있는) 상품이 없습니다.",
                    systemImage: "cube.box",
                    actionTitle: "홈으로 가기"
                ) {}
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
        .navigationTitle("목록")
        .navigationBarTitleDisplayMode(.inline)
    }
}
