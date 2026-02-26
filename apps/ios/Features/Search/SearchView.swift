import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var results: [Product] = []
    @State private var recentSearches: [String] = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedCategory: ProductCategory? = nil

    var body: some View {
        ZStack {
            Theme.Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.textMuted)

                    TextField("3D 모델 검색...", text: $searchText)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            performSearch()
                        }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchTask?.cancel()
                            searchText = ""
                            results = []
                            isSearching = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.textMuted)
                        }
                        .accessibilityLabel("검색어 지우기")
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 12)
                .background(Theme.Colors.bgSecondary)
                .cornerRadius(12)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.sm)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: { selectedCategory = nil; triggerSearchIfNeeded() }) {
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
                                triggerSearchIfNeeded()
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

                if searchText.isEmpty && results.isEmpty {
                    // Recent searches
                    if !recentSearches.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                Text("최근 검색")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Spacer()
                                Button("지우기") {
                                    recentSearches = []
                                    UserDefaults.standard.removeObject(forKey: "recentSearches")
                                }
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                            }

                            ForEach(recentSearches, id: \.self) { term in
                                Button(action: {
                                    searchText = term
                                    performSearch()
                                }) {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(Theme.Colors.textMuted)
                                        Text(term)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        Spacer()
                                    }
                                    .padding(.vertical, Theme.Spacing.xs)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.lg)
                    }

                    Spacer()
                } else if isSearching {
                    Spacer()
                    ProgressView()
                        .tint(Theme.Colors.violetAccent)
                    Spacer()
                } else if results.isEmpty && !searchText.isEmpty {
                    Spacer()
                    EmptyStateView(
                        title: "검색 결과 없음",
                        message: "'\(searchText)'에 해당하는 3D 모델이 없습니다.",
                        systemImage: "magnifyingglass",
                        actionTitle: nil,
                        action: {}
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(results) { product in
                                NavigationLink(value: product.id) {
                                    ProductListRow(product: product)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.md)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationTitle("검색")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { id in
            ProductDetailView(productId: id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .productPurchased)) { notification in
            guard let event = notification.object as? ProductPurchaseEvent else { return }
            results = results.map { product in
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
        .onChange(of: searchText) {
            scheduleDebouncedSearch(for: searchText)
        }
    }

    private func performSearch(saveToRecents: Bool = true) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchTask?.cancel()
        Task {
            await runSearch(query: query, saveToRecents: saveToRecents)
        }
    }

    private func scheduleDebouncedSearch(for text: String) {
        searchTask?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            isSearching = false
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await runSearch(query: query, saveToRecents: false)
        }
    }

    private func updateRecentSearches(with query: String) {
        var recents = recentSearches
        recents.removeAll { $0 == query }
        recents.insert(query, at: 0)
        if recents.count > 10 { recents = Array(recents.prefix(10)) }
        recentSearches = recents
        UserDefaults.standard.set(recents, forKey: "recentSearches")
    }

    private func triggerSearchIfNeeded() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchTask?.cancel()
        Task {
            await runSearch(query: query, saveToRecents: false)
        }
    }

    private func runSearch(query: String, saveToRecents: Bool) async {
        // Snapshot current category to detect stale responses
        let categorySnapshot = selectedCategory

        if saveToRecents {
            await MainActor.run {
                updateRecentSearches(with: query)
            }
        }

        await MainActor.run {
            isSearching = true
        }

        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            var endpoint = "/products?q=\(encoded)"
            if let cat = categorySnapshot {
                endpoint += "&category=\(cat.rawValue)"
            }
            let response: ProductListResponse = try await APIClient.shared.request(
                endpoint: endpoint,
                needsAuth: false
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
                    chatCount: p.chat_count ?? 0,
                    category: p.category,
                    condition: p.condition
                )
            }
            await MainActor.run {
                let current = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard current == query, selectedCategory == categorySnapshot else { return }
                results = fetched
                isSearching = false
            }
        } catch {
            await MainActor.run {
                let current = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard current == query, selectedCategory == categorySnapshot else { return }
                isSearching = false
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: (error as? APIError)?.userMessage ?? "검색 실패", style: .error)
                )
            }
        }
    }
}
