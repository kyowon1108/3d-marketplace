import SwiftUI

// View model shared with ProductListView and ProductListRow
struct Product: Identifiable {
    let id: UUID
    let title: String
    let creator: String
    let priceCents: Int
    let status: String
    let likes: Int
    let thumbnailUrl: String?
    let createdAt: String
    let chatCount: Int
    let category: String?
    let condition: String?
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

                // Thumbnail image or fallback icon
                if let urlString = product.thumbnailUrl, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } failure: {
                        Image(systemName: "cube.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .foregroundColor(Theme.Colors.violetAccent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    Image(systemName: "cube.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(Theme.Colors.violetAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // 3D Badge
                Text("3D")
                    .font(.caption2.weight(.bold))
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
                    .font(.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Location & Time
                Text("\(product.creator) · \(relativeTime(from: product.createdAt))")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)

                // Price
                HStack(spacing: Theme.Spacing.xs) {
                    Text(formatPrice(product.priceCents))
                        .font(.headline)
                        .foregroundColor(product.status == "SOLD_OUT" ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                        .strikethrough(product.status == "SOLD_OUT", color: Theme.Colors.textSecondary)
                        .padding(.top, 2)

                    if product.status == "SOLD_OUT" {
                        Text("판매완료")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray)
                            .clipShape(Capsule())
                    } else if product.status == "RESERVED" {
                        Text("예약중")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.9))
                            .clipShape(Capsule())
                    }
                }

                Spacer(minLength: 0)

                // Bottom Icons (Chat & Like) right aligned
                HStack(spacing: 8) {
                    Spacer()

                    HStack(spacing: 2) {
                        Image(systemName: "bubble.right")
                        Text("\(product.chatCount)")
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "heart")
                        Text("\(product.likes)")
                    }
                }
                .font(.caption)
                .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.vertical, 4)
        }
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.lg)
        .background(Theme.Colors.bgPrimary)
        .opacity(product.status == "SOLD_OUT" ? 0.5 : 1.0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(product.title), \(formatPrice(product.priceCents)), 관심 \(product.likes)개, 채팅 \(product.chatCount)개")
        .accessibilityHint("상품 상세 화면으로 이동합니다.")
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
