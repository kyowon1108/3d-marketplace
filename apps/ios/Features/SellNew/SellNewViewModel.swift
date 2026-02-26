import SwiftUI
import CryptoKit
import QuickLookThumbnailing

@MainActor
@Observable
public class SellNewViewModel {

    public enum Step {
        case publish     // Starts here! (Text form)
        case intro
        case capture     // ObjectCaptureSession native UI
        case modeling    // LocalModelBuilder background task
        case upload      // Uploading to API
        case success
    }

    public var currentStep: Step = .publish
    public var processingProgress: Double = 0.0
    public var processingStatusText: String = "준비 중..."

    // Form State
    public var publishTitle: String = ""
    public var publishPrice: String = ""
    public var publishDescription: String = ""
    public var isPublishing: Bool = false

    // Captured Data
    public var capturedFolderURL: URL? = nil
    public var generatedModelURL: URL? = nil
    public var generatedThumbnailURL: URL? = nil
    public var uploadedAssetId: String? = nil
    public var extractedDimensions: ModelDimensions? = nil

    // Category & Condition
    public var publishCategory: ProductCategory? = nil
    public var publishCondition: ProductCondition? = nil
    public var dimsComparison: String? = nil

    // AI suggest
    public var isLoadingAISuggestion: Bool = false
    public var aiSuggestionError: String? = nil
    public var suggestedPriceMin: Int? = nil
    public var suggestedPriceMax: Int? = nil
    public var suggestedPriceReason: String? = nil

    // Error state
    public var uploadError: String? = nil
    public var modelingError: String? = nil

    // ModelingKit
    private let modelBuilder = LocalModelBuilder()
    private let exportCoordinator = ModelExportCoordinator()

    public func startCapture() {
        currentStep = .capture
    }

    public func finishCaptureAndStartModeling() {
        currentStep = .modeling
        processingProgress = 0.0
        processingStatusText = "3D 모델링 준비 중..."
        modelingError = nil

        let outputDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GeneratedModel_\(UUID().uuidString)")
        let outputURL = outputDir.appendingPathComponent("model.usdz")

        guard let inputDir = capturedFolderURL else {
            // Simulator/mock mode: buildMock ignores inputDirectory
            modelBuilder.build(inputDirectory: outputDir, outputURL: outputURL)
            observeModelBuilder()
            return
        }
        modelBuilder.build(inputDirectory: inputDir, outputURL: outputURL)
        observeModelBuilder()
    }

    private func observeModelBuilder() {
        withObservationTracking {
            handleModelBuilderState(modelBuilder.state)
        } onChange: {
            Task { @MainActor in
                self.observeModelBuilder()
            }
        }
    }

    private func handleModelBuilderState(_ state: LocalModelBuilder.State) {
        switch state {
        case .idle:
            break
        case .building(let progress, let status):
            self.processingProgress = progress * 0.7
            self.processingStatusText = status
        case .completed(let url):
            self.generatedModelURL = url
            self.processingProgress = 0.7
            self.processingStatusText = "3D 모델 완성!"
            // Extract dimensions from the generated USDZ
            self.extractedDimensions = exportCoordinator.extractDimensions(from: url)
            #if DEBUG
            if let dims = self.extractedDimensions {
                print("[Modeling] Extracted dims: \(dims.formattedCm)")
            } else {
                print("[Modeling] Could not extract dimensions from USDZ")
            }
            #endif
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.currentStep = .upload
                self.startUpload()
            }
        case .failed(let error):
            self.modelingError = error
            self.processingStatusText = "3D 모델링 실패"
        }
    }

    public func retryModeling() {
        modelBuilder.cancel()
        modelingError = nil
        finishCaptureAndStartModeling()
    }

    public func startUpload() {
        self.processingProgress = 0.7
        self.processingStatusText = "업로드 서버에 자리 만드는 중..."
        self.uploadError = nil

        Task {
            do {
                guard let modelURL = generatedModelURL else {
                    throw UploadError.noModelFile
                }

                let fileData = try Data(contentsOf: modelURL)
                let fileSize = fileData.count

                self.processingStatusText = "업로드 공간 확보 중..."
                self.processingProgress = 0.72

                // 썸네일 생성 시도: QLThumbnailGenerator → SceneKit fallback
                var thumbnailData: Data? = nil
                let thumbnailURL = modelURL.deletingPathExtension().appendingPathExtension("jpg")

                let size = CGSize(width: 512, height: 512)
                let scale = UIScreen.main.scale
                let request = QLThumbnailGenerator.Request(fileAt: modelURL, size: size, scale: scale, representationTypes: .thumbnail)

                do {
                    let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                    if let jpgData = thumbnail.uiImage.jpegData(compressionQuality: 0.8) {
                        try jpgData.write(to: thumbnailURL)
                        thumbnailData = jpgData
                        self.generatedThumbnailURL = thumbnailURL
                    }
                } catch {
                    #if DEBUG
                    print("[Upload] QLThumbnail failed, trying SceneKit: \(error)")
                    #endif
                    // Fallback: SceneKit snapshot
                    if let sceneThumbURL = exportCoordinator.generateThumbnail(from: modelURL, size: size),
                       let pngData = try? Data(contentsOf: sceneThumbURL) {
                        // Convert PNG to JPG for smaller size
                        if let uiImg = UIImage(data: pngData), let jpgData = uiImg.jpegData(compressionQuality: 0.8) {
                            try? jpgData.write(to: thumbnailURL)
                            thumbnailData = jpgData
                            self.generatedThumbnailURL = thumbnailURL
                        }
                    }
                }

                #if DEBUG
                print("[Upload] Step 1: Sending init request... (fileSize=\(fileSize), hasThumbnail=\(thumbnailData != nil))")
                #endif

                var imagesArray: [UploadInitRequest.ImageMeta] = []
                if let tData = thumbnailData {
                    imagesArray.append(UploadInitRequest.ImageMeta(image_type: "THUMBNAIL", sort_order: 0, size_bytes: tData.count))
                }

                let initRequest = UploadInitRequest(
                    dims_source: extractedDimensions != nil ? "ios_lidar" : "unknown",
                    dims_width: extractedDimensions?.widthCm,
                    dims_height: extractedDimensions?.heightCm,
                    dims_depth: extractedDimensions?.depthCm,
                    capture_session_id: nil,
                    files: [UploadInitRequest.FileInfo(role: "MODEL_USDZ", size_bytes: fileSize)],
                    images: imagesArray
                )
                let initBody = try JSONEncoder().encode(initRequest)
                let initResponse: UploadInitResponse = try await APIClient.shared.request(
                    endpoint: "/model-assets/uploads/init",
                    method: "POST",
                    body: initBody
                )

                #if DEBUG
                print("[Upload] Step 1: Init OK — asset_id=\(initResponse.asset_id), \(initResponse.presigned_uploads.count) presigned URLs")
                #endif

                self.uploadedAssetId = initResponse.asset_id
                self.processingProgress = 0.75

                guard let presigned = initResponse.presigned_uploads.first else {
                    throw UploadError.noPresignedURL
                }

                self.processingStatusText = "3D 모델 파일을 서버로 전송하는 중... 거의 다 왔어요!"
                #if DEBUG
                print("[Upload] Step 2: Uploading to presigned URL...")
                #endif
                try await uploadFileToPresignedURL(
                    fileData: fileData,
                    presignedURLString: presigned.url
                )
                
                // Upload Thumbnail if present
                if let tData = thumbnailData, let imgPresigned = initResponse.presigned_image_uploads.first(where: { $0.image_type == "THUMBNAIL" }) {
                    #if DEBUG
                    print("[Upload] Step 2b: Uploading Thumbnail to presigned URL...")
                    #endif
                    try await uploadFileToPresignedURL(
                        fileData: tData,
                        presignedURLString: imgPresigned.url
                    )
                }

                self.processingProgress = 0.9
                #if DEBUG
                print("[Upload] Step 2: Upload OK")
                #endif

                self.processingStatusText = "파일 안전성 검증 중..."
                let sha256 = SHA256.hash(data: fileData)
                let checksumHex = sha256.compactMap { String(format: "%02x", $0) }.joined()
                
                var verifyImages: [UploadCompleteRequest.ImageVerify] = []
                if let tData = thumbnailData {
                    let imgSha = SHA256.hash(data: tData)
                    let imgChecksumHex = imgSha.compactMap { String(format: "%02x", $0) }.joined()
                    verifyImages.append(UploadCompleteRequest.ImageVerify(
                        image_type: "THUMBNAIL",
                        sort_order: 0,
                        size_bytes: tData.count,
                        checksum_sha256: imgChecksumHex
                    ))
                }

                #if DEBUG
                print("[Upload] Step 3: Sending complete request... (checksum=\(checksumHex.prefix(12))...)")
                #endif

                let completeRequest = UploadCompleteRequest(
                    asset_id: initResponse.asset_id,
                    files: [UploadCompleteRequest.FileVerify(
                        role: "MODEL_USDZ",
                        size_bytes: fileSize,
                        checksum_sha256: checksumHex
                    )],
                    images: verifyImages
                )
                let completeBody = try JSONEncoder().encode(completeRequest)
                let _: UploadCompleteResponse = try await APIClient.shared.request(
                    endpoint: "/model-assets/uploads/complete",
                    method: "POST",
                    body: completeBody,
                    useIdempotency: true
                )
                #if DEBUG
                print("[Upload] Step 3: Complete OK")
                #endif

                self.processingProgress = 1.0
                self.processingStatusText = "업로드 완료!"

                try? await Task.sleep(nanoseconds: 500_000_000)
                self.currentStep = .publish

            } catch {
                let message: String
                if let apiError = error as? APIError {
                    message = apiError.userMessage
                } else {
                    message = error.localizedDescription
                }
                #if DEBUG
                print("[Upload Error] Step failed: \(error)")
                #endif
                self.uploadError = message
                self.processingStatusText = "업로드 실패"
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: message, style: .error)
                )
            }
        }
    }

    public func requestAISuggestion() {
        guard let thumbnailURL = generatedThumbnailURL else {
            NotificationCenter.default.post(
                name: .showToast,
                object: Toast(message: "썸네일이 없어 AI 추천을 사용할 수 없습니다.", style: .info)
            )
            return
        }

        isLoadingAISuggestion = true
        aiSuggestionError = nil

        Task {
            do {
                // Build a URL for the thumbnail accessible from the server
                let thumbURLString: String
                if let assetId = uploadedAssetId {
                    // Server base without /v1 suffix for storage endpoint
                    let apiBase = AppEnvironment.current.apiBaseURL
                    let serverBase = apiBase.replacingOccurrences(of: "/v1", with: "")
                    thumbURLString = "\(serverBase)/storage/assets/\(assetId)/thumbnail.jpg"
                } else {
                    thumbURLString = thumbnailURL.absoluteString
                }

                let request = AISuggestListingRequest(
                    thumbnail_url: thumbURLString,
                    dims_width: extractedDimensions?.widthCm,
                    dims_height: extractedDimensions?.heightCm,
                    dims_depth: extractedDimensions?.depthCm,
                    dims_source: extractedDimensions != nil ? "ios_lidar" : nil
                )
                let body = try JSONEncoder().encode(request)
                let response: AISuggestListingResponse = try await APIClient.shared.request(
                    endpoint: "/ai/suggest-listing",
                    method: "POST",
                    body: body
                )

                self.publishTitle = response.suggested_title
                self.publishDescription = response.suggested_description
                if let cat = response.suggested_category {
                    self.publishCategory = ProductCategory(rawValue: cat)
                }
                if let cond = response.suggested_condition {
                    self.publishCondition = ProductCondition(rawValue: cond)
                }
                self.suggestedPriceMin = response.suggested_price_min
                self.suggestedPriceMax = response.suggested_price_max
                self.dimsComparison = response.dims_comparison
                self.suggestedPriceReason = response.suggested_price_reason
                self.isLoadingAISuggestion = false
            } catch {
                self.isLoadingAISuggestion = false
                self.aiSuggestionError = (error as? APIError)?.userMessage ?? "AI 추천 실패"
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: self.aiSuggestionError ?? "AI 추천 실패", style: .error)
                )
            }
        }
    }

    public func publishProduct() {
        guard !publishTitle.isEmpty, !publishPrice.isEmpty else {
            NotificationCenter.default.post(
                name: .showToast,
                object: Toast(message: "상품명과 가격을 입력해주세요.", style: .error)
            )
            return
        }

        guard let assetId = uploadedAssetId else {
            NotificationCenter.default.post(
                name: .showToast,
                object: Toast(message: "에셋 업로드가 완료되지 않았습니다.", style: .error)
            )
            return
        }

        let priceCents = Int(publishPrice) ?? 0
        let requestBody = ProductPublishRequest(
            asset_id: assetId,
            title: publishTitle,
            description: publishDescription.isEmpty ? nil : publishDescription,
            price_cents: priceCents,
            category: publishCategory?.rawValue,
            condition: publishCondition?.rawValue,
            dims_comparison: dimsComparison
        )

        isPublishing = true

        Task {
            do {
                let encodedBody = try JSONEncoder().encode(requestBody)
                let _: ProductResponse = try await APIClient.shared.request(
                    endpoint: "/products/publish",
                    method: "POST",
                    body: encodedBody,
                    useIdempotency: true
                )

                self.isPublishing = false
                self.currentStep = .success
            } catch {
                self.isPublishing = false
                NotificationCenter.default.post(
                    name: .showToast,
                    object: Toast(message: (error as? APIError)?.userMessage ?? "게시 실패", style: .error)
                )
            }
        }
    }

    public func reset() {
        modelBuilder.cancel()
        self.currentStep = .publish
        self.processingProgress = 0.0
        self.processingStatusText = ""
        self.publishTitle = ""
        self.publishPrice = ""
        self.publishDescription = ""
        self.publishCategory = nil
        self.publishCondition = nil
        self.dimsComparison = nil
        self.suggestedPriceMin = nil
        self.suggestedPriceMax = nil
        self.suggestedPriceReason = nil
        self.capturedFolderURL = nil
        self.generatedModelURL = nil
        self.extractedDimensions = nil
        self.uploadedAssetId = nil
        self.uploadError = nil
        self.modelingError = nil
        self.isLoadingAISuggestion = false
        self.aiSuggestionError = nil
    }

    // MARK: - Private

    private func uploadFileToPresignedURL(fileData: Data, presignedURLString: String) async throws {
        guard let url = URL(string: presignedURLString) else {
            throw UploadError.invalidPresignedURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = fileData

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw UploadError.presignedUploadFailed
        }
    }
}

// MARK: - Upload Errors

enum UploadError: Error, LocalizedError {
    case noModelFile
    case noPresignedURL
    case invalidPresignedURL
    case presignedUploadFailed

    var errorDescription: String? {
        switch self {
        case .noModelFile: return "모델 파일을 찾을 수 없습니다."
        case .noPresignedURL: return "업로드 URL을 받지 못했습니다."
        case .invalidPresignedURL: return "잘못된 업로드 URL입니다."
        case .presignedUploadFailed: return "파일 업로드에 실패했습니다."
        }
    }
}
