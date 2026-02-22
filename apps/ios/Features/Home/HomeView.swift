import SwiftUI

// View model shared with ProductListView and ProductListRow
struct Product: Identifiable {
    let id: UUID
    let title: String
    let creator: String
    let price: String
    let likes: Int
    let thumbnailUrl: String?
}

struct HomeView: View {
    @State private var isLoading = true
    @State private var products: [Product] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {

                        // Header
                        HStack {
                            Text("3D Marketplace")
                                .font(.system(size: 28, weight: .bold))
                            Spacer()
                            NavigationLink(destination: SearchView()) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.md)

                        // Feed
                        LazyVStack(spacing: Theme.Spacing.md) {
                            if isLoading {
                                ForEach(0..<6, id: \.self) { _ in
                                    ProductListRowSkeleton()
                                }
                            } else {
                                ForEach(products) { product in
                                    NavigationLink(value: product.id) {
                                        ProductListRow(product: product)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                }
                .refreshable {
                    await fetchFeedData()
                }
            }
            .navigationDestination(for: UUID.self) { id in
                ProductDetailView(productId: id)
            }
            .onAppear {
                if products.isEmpty {
                    Task { await fetchFeedData() }
                }
            }
        }
    }

    private func fetchFeedData() async {
        isLoading = true
        do {
            let response: ProductListResponse = try await APIClient.shared.request(
                endpoint: "/products",
                needsAuth: false
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
                self.products = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: (error as? APIError)?.userMessage ?? "데이터 불러오기 실패", style: .error)
                )
            }
        }
    }
}

// MARK: - Components

struct ProductListRow: View {
    let product: Product
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Left: Square Thumbnail Container
            ZStack(alignment: .bottomTrailing) {
                // Background fallback
                Color.black.opacity(0.3)
                LinearGradient(colors: [Theme.Colors.violetAccent.opacity(0.3), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                
                Image(systemName: "cube.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundColor(Theme.Colors.violetAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 3D Badge (Always show for now)
                Text("3D")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(6)
            }
            .frame(width: 110, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))

            // Right: Meta Area
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(product.title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Location & Time (Mocking "동" and "시간" for presentation)
                // Assuming `creator` holds the location or fallback
                Text("\(product.creator) · 17분 전")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)
                
                // Price
                Text(product.price)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.top, 2)
                
                Spacer(minLength: 0)
                
                // Bottom Icons (Chat & Like) right aligned
                HStack(spacing: 8) {
                    Spacer()
                    
                    // Mock chat count
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.right")
                        Text("2") // Example mock chat count
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "heart")
                        Text("\(product.likes)")
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.vertical, 4)
        }
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.lg)
        // Karrot feed removes the glass card background completely
        // and just relies on standard row separators
        .background(Theme.Colors.bgPrimary) 
    }
}

struct ProductListRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color.white.opacity(0.05))
                .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 140, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 80, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 60, height: 16)
                    .padding(.top, 4)
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .padding(Theme.Spacing.sm)
        .glassCardStyle(cornerRadius: Theme.Radius.lg, borderOpacity: 0.1, shadowRadius: 5)
        .shimmer()
    }
}
