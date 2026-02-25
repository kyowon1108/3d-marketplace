import SwiftUI
import UIKit

final class ImageCacheManager: @unchecked Sendable {
    static let shared = ImageCacheManager()

    private let cache: NSCache<NSString, UIImage>

    private init() {
        cache = NSCache<NSString, UIImage>()
        // Memory cache limit: 50 items, around 50MB
        cache.countLimit = 50
        cache.totalCostLimit = 1024 * 1024 * 50
    }

    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        // We estimate the cost as 1 byte per pixel, times 4 (RGBA). This is a rough estimation.
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

public struct CachedAsyncImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let failureView: (() -> Failure)?

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadFailed = false

    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.failureView = failure
    }

    public var body: some View {
        ZStack {
            if let uiImage = loadedImage {
                content(Image(uiImage: uiImage))
            } else if loadFailed {
                if let failureView {
                    failureView()
                } else {
                    placeholder()
                }
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) {
            loadImage()
        }
    }

    private func loadImage() {
        guard let url = url else {
            loadFailed = true
            return
        }
        let key = url.absoluteString

        // Check cache first
        if let cached = ImageCacheManager.shared.get(forKey: key) {
            self.loadedImage = cached
            return
        }

        guard !isLoading else { return }
        isLoading = true
        loadFailed = false

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    ImageCacheManager.shared.set(uiImage, forKey: key)
                    await MainActor.run {
                        self.loadedImage = uiImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.loadFailed = true
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }
}

extension CachedAsyncImage where Failure == EmptyView {
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.failureView = nil
    }
}
