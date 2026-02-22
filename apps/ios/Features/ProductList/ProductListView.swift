import SwiftUI

struct ProductListView: View {
    @State private var searchText = ""
    @State private var selectedCategory = "최신순"
    let categories = ["최신순", "인기순", "무료", "기기/장비", "의류", "인테리어"]
    
    @State private var products: [Product] = []
    @State private var isLoading = true
    
    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products
        } else {
            return products.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.creator.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.bgPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    CategoryPills(categories: categories, selectedCategory: $selectedCategory)
                        .padding(.top, Theme.Spacing.xs)
                    
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
                            title: searchText.isEmpty ? "아직 등록된 상품이 없네요" : "검색 결과가 없습니다",
                            message: searchText.isEmpty ? "가장 먼저 나만의 3D 에셋을 캡처해서 마켓플레이스에 올려보세요." : "'\(searchText)'에 일치하는 3D 모델을 찾을 수 없습니다.",
                            systemImage: "magnifyingglass",
                            actionTitle: searchText.isEmpty ? "+ 새로운 3D 모델 만들기" : nil
                        ) {
                            if searchText.isEmpty {
                                AppToast(message: "Sell Now 탭으로 이동합니다", style: .info)
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
            .navigationTitle("탐색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Theme.Colors.bgPrimary, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in ProductDetailView(productId: id) }
        }
        .searchable(text: $searchText, prompt: "3D 모델 검색...")
        .onAppear {
            if products.isEmpty {
                Task { await fetchData() }
            }
        }
    }
    
    private func fetchData() async {
        isLoading = true
        do {
            let response: ProductListResponse = try await APIClient.shared.request(endpoint: "/products", needsAuth: false)
            let fetchedProducts = response.products.map { p in
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
                self.products = fetchedProducts
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: (error as? APIError)?.userMessage ?? "탐색 테이터 불러오기 실패", style: .error)
                )
            }
        }
    }
}

