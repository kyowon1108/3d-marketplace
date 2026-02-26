import SwiftUI

struct ProductListView: View {
    @State private var searchText = ""
    @State private var selectedSort = "최신순"
    @State private var hideCompleted = false
    @State private var selectedCategory: ProductCategory? = nil
    let sortOptions = ["최신순", "인기순", "무료"]

    @State private var products: [Product] = []
    @State private var isLoading = true
    
    var filteredProducts: [Product] {
        let searched: [Product]
        if searchText.isEmpty {
            searched = products
        } else {
            searched = products.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) || $0.creator.localizedCaseInsensitiveContains(searchText)
            }
        }
        let filteredByStatus = hideCompleted ? searched.filter { $0.status == "FOR_SALE" } : searched
        return applySortFilter(to: filteredByStatus)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    CategoryPills(categories: sortOptions, selectedCategory: $selectedSort)
                        .padding(.top, Theme.Spacing.xs)

                    // Category filter chips (server-side)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: {
                                selectedCategory = nil
                                Task { await fetchData() }
                            }) {
                                Text("전체")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(selectedCategory == nil ? .white : Theme.Colors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == nil ? Theme.Colors.violetAccent : Theme.Colors.bgSecondary)
                                    .clipShape(Capsule())
                            }
                            ForEach(ProductCategory.allCases, id: \.self) { cat in
                                Button(action: {
                                    selectedCategory = selectedCategory == cat ? nil : cat
                                    Task { await fetchData() }
                                }) {
                                    Text(cat.label)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(selectedCategory == cat ? .white : Theme.Colors.textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == cat ? Theme.Colors.violetAccent : Theme.Colors.bgSecondary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    .padding(.top, Theme.Spacing.xs)

                    HStack(spacing: 6) {
                        Toggle(isOn: $hideCompleted) {
                            Text("판매중만")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.violetAccent))
                        .fixedSize()
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    
                    if isLoading {
                        ScrollView {
                            LazyVStack(spacing: Theme.Spacing.md) {
                                ForEach(0..<6, id: \.self) { _ in ProductListRowSkeleton() }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.top, Theme.Spacing.md)
                        }
                    } else if filteredProducts.isEmpty {
                        Spacer()
                        EmptyStateView(
                            title: searchText.isEmpty ? "근처에 3D 모델이 텅 비어있네요." : "검색 결과가 없습니다",
                            message: searchText.isEmpty ? "가장 먼저 나만의 3D 에셋을 캡처해서 마켓플레이스에 올려보세요!" : "'\(searchText)'에 안타깝게도 일치하는 모델이 없어요.",
                            systemImage: "magnifyingglass",
                            actionTitle: searchText.isEmpty ? "+ 새로운 3D 모델 캡처하기" : nil
                        ) {
                            if searchText.isEmpty {
                                NotificationCenter.default.post(name: .switchToSellTab, object: nil)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: Theme.Spacing.md) {
                                ForEach(filteredProducts) { product in
                                    NavigationLink(value: product.id) { ProductListRow(product: product) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.top, Theme.Spacing.md)
                            .padding(.bottom, 100) // Space for TabBar
                        }
                        .refreshable {
                            await fetchData()
                        }
                    }
                }
            }
            .navigationTitle("홈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.Colors.bgPrimary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SearchView()) {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.textPrimary)
                    }
                    .accessibilityLabel("검색 화면 열기")
                    .accessibilityHint("상품 검색 화면으로 이동합니다.")
                }
            }
            .navigationDestination(for: UUID.self) { id in ProductDetailView(productId: id) }
        }
        .searchable(text: $searchText, prompt: "3D 모델 검색...")
        .onAppear {
            if products.isEmpty {
                Task { await fetchData() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .productPurchased)) { notification in
            guard let event = notification.object as? ProductPurchaseEvent else { return }
            products = products.map { product in
                guard product.id == event.productId else { return product }
                return Product(
                    id: product.id,
                    title: product.title,
                    creator: product.creator,
                    priceCents: product.priceCents,
                    status: "SOLD_OUT",
                    likes: product.likes,
                    thumbnailUrl: product.thumbnailUrl,
                    createdAt: product.createdAt,
                    chatCount: product.chatCount,
                    category: product.category,
                    condition: product.condition
                )
            }
        }
    }
    
    private func fetchData() async {
        isLoading = true
        do {
            var endpoint = "/products"
            if let cat = selectedCategory {
                endpoint += "?category=\(cat.rawValue)"
            }
            let response: ProductListResponse = try await APIClient.shared.request(endpoint: endpoint, needsAuth: false)
            let fetchedProducts = response.products.map { p in
                Product(
                    id: UUID(uuidString: p.id) ?? UUID(),
                    title: p.title,
                    creator: p.seller_name ?? "알 수 없는 판매자",
                    priceCents: p.price_cents,
                    status: p.status,
                    likes: p.likes_count ?? 0,
                    thumbnailUrl: p.thumbnail_url,
                    createdAt: p.created_at,
                    chatCount: p.chat_count ?? 0,
                    category: p.category,
                    condition: p.condition
                )
            }
            await MainActor.run {
                self.products = fetchedProducts
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: (error as? APIError)?.userMessage ?? "탐색 데이터 불러오기 실패", style: .error)
                )
            }
        }
    }

    private func applySortFilter(to source: [Product]) -> [Product] {
        switch selectedSort {
        case "인기순":
            return source.sorted { lhs, rhs in
                if lhs.likes == rhs.likes {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.likes > rhs.likes
            }
        case "무료":
            return source
                .filter { $0.priceCents == 0 }
                .sorted { $0.createdAt > $1.createdAt }
        default:
            return source.sorted { $0.createdAt > $1.createdAt }
        }
    }
}
