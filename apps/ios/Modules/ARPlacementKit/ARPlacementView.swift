import SwiftUI
import RealityKit
import ARKit
import Combine

/// RealityKit-based AR placement view with plane detection and tap-to-place.
@available(iOS 17.0, *)
struct ARPlacementView: UIViewRepresentable {
    let modelURL: URL
    @Binding var wallSnapEnabled: Bool
    var dims: ModelDimensions?
    var onDismiss: (() -> Void)?
    var onError: ((String) -> Void)?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        arView.session.run(config)

        // Add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)

        // Store arView reference in coordinator
        context.coordinator.arView = arView
        context.coordinator.modelURL = modelURL
        context.coordinator.dims = dims
        context.coordinator.onDismiss = onDismiss
        context.coordinator.onError = onError
        context.coordinator.prepareModel()

        // Add footprint indicator (dynamic size from dims)
        context.coordinator.addFootprintIndicator()

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.wallSnapEnabled = wallSnapEnabled
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        uiView.scene.anchors.removeAll()
        coordinator.tearDown()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator: NSObject {
        weak var arView: ARView?
        var modelURL: URL?
        var dims: ModelDimensions?
        var wallSnapEnabled = false
        var onDismiss: (() -> Void)?
        var onError: ((String) -> Void)?
        private var footprintEntity: ModelEntity?
        private var modelPlaced = false
        private var isLoadingModel = false
        private var isPlacingModel = false
        private var preloadedModel: ModelEntity?
        private var loadCancellable: AnyCancellable?

        func tearDown() {
            loadCancellable?.cancel()
            loadCancellable = nil
            preloadedModel = nil
        }

        func prepareModel() {
            guard !isLoadingModel, preloadedModel == nil, let modelURL else { return }

            isLoadingModel = true
            loadCancellable = Entity.loadModelAsync(contentsOf: modelURL)
                .sink { [weak self] completion in
                    guard let self else { return }
                    self.isLoadingModel = false
                    if case .failure(let error) = completion {
                        #if DEBUG
                        print("Failed to preload AR model: \(error)")
                        #endif
                        self.onError?("AR 모델 로딩에 실패했습니다. Quick Look으로 다시 시도해주세요.")
                    }
                } receiveValue: { [weak self] model in
                    self?.preloadedModel = model
                }
        }

        func addFootprintIndicator() {
            guard let arView = arView else { return }

            // Use real model dimensions for footprint size, fallback to 0.3m
            let footprintWidth: Float = dims.map { Float($0.width) } ?? 0.3
            let footprintDepth: Float = dims.map { Float($0.depth) } ?? 0.3
            let cornerRadius = min(footprintWidth, footprintDepth) * 0.5

            let mesh = MeshResource.generatePlane(width: footprintWidth, depth: footprintDepth, cornerRadius: cornerRadius)
            var material = UnlitMaterial()
            material.color = .init(tint: .systemPurple.withAlphaComponent(0.4))

            let entity = ModelEntity(mesh: mesh, materials: [material])
            let anchor = AnchorEntity(plane: .horizontal)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)

            self.footprintEntity = entity
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView,
                  !modelPlaced,
                  !isPlacingModel else { return }

            let location = recognizer.location(in: arView)

            // Raycast to find plane
            let results = arView.raycast(
                from: location,
                allowing: wallSnapEnabled ? .existingPlaneGeometry : .estimatedPlane,
                alignment: wallSnapEnabled ? .vertical : .horizontal
            )

            guard let result = results.first else { return }

            guard let templateModel = preloadedModel else {
                if !isLoadingModel {
                    prepareModel()
                }
                onError?("모델을 준비 중입니다. 잠시 후 다시 탭해주세요.")
                return
            }

            isPlacingModel = true
            let placedModel = templateModel.clone(recursive: true)

            // Clamp oversized models to keep gesture/collision workload predictable.
            let initialBounds = placedModel.visualBounds(relativeTo: nil)
            let initialExtents = initialBounds.extents
            guard initialExtents.x.isFinite, initialExtents.y.isFinite, initialExtents.z.isFinite else {
                onError?("모델 크기 정보를 읽지 못했습니다. Quick Look으로 다시 시도해주세요.")
                isPlacingModel = false
                return
            }

            let dominantExtent = max(initialExtents.x, max(initialExtents.y, initialExtents.z))
            let maxExtent: Float = 2.0
            if dominantExtent > maxExtent {
                let scale = maxExtent / dominantExtent
                placedModel.scale = SIMD3<Float>(repeating: scale)
            }

            // Use a cheap bounding-box collider to avoid heavy recursive mesh collision generation.
            let bounds = placedModel.visualBounds(relativeTo: nil)
            let extents = bounds.extents
            guard extents.x.isFinite, extents.y.isFinite, extents.z.isFinite else {
                onError?("모델 충돌 정보를 생성할 수 없습니다. Quick Look으로 다시 시도해주세요.")
                isPlacingModel = false
                return
            }
            let colliderSize = SIMD3<Float>(
                min(max(extents.x, 0.01), 4.0),
                min(max(extents.y, 0.01), 4.0),
                min(max(extents.z, 0.01), 4.0)
            )
            let shape = ShapeResource.generateBox(size: colliderSize)
            placedModel.components.set(CollisionComponent(shapes: [shape]))

            let anchor = AnchorEntity(world: result.worldTransform)
            anchor.addChild(placedModel)
            arView.scene.addAnchor(anchor)

            // Install gestures for manipulation
            arView.installGestures([.translation, .rotation, .scale], for: placedModel)

            // Add dimension labels if dims available
            if let dims = dims {
                addDimensionLabels(to: anchor, model: placedModel, dims: dims)
            }

            // Remove footprint
            footprintEntity?.removeFromParent()
            modelPlaced = true
            isPlacingModel = false
        }

        /// Adds floating dimension labels (width/height/depth) around the placed model.
        private func addDimensionLabels(to anchor: AnchorEntity, model: ModelEntity, dims: ModelDimensions) {
            let bounds = model.visualBounds(relativeTo: anchor)
            let center = bounds.center
            let ext = bounds.extents

            let labelColor: UIColor = .white
            let bgColor: UIColor = UIColor.black.withAlphaComponent(0.7)

            // Width label (X axis) — placed at bottom front edge
            let widthText = String(format: "%.1f cm", dims.widthCm)
            if let widthLabel = makeLabelEntity(text: widthText, color: labelColor, bgColor: bgColor) {
                widthLabel.position = SIMD3<Float>(center.x, center.y - ext.y / 2 - 0.02, center.z + ext.z / 2 + 0.03)
                anchor.addChild(widthLabel)
            }

            // Height label (Y axis) — placed at right edge
            let heightText = String(format: "%.1f cm", dims.heightCm)
            if let heightLabel = makeLabelEntity(text: heightText, color: labelColor, bgColor: bgColor) {
                heightLabel.position = SIMD3<Float>(center.x + ext.x / 2 + 0.03, center.y, center.z)
                anchor.addChild(heightLabel)
            }

            // Depth label (Z axis) — placed at bottom right edge
            let depthText = String(format: "%.1f cm", dims.depthCm)
            if let depthLabel = makeLabelEntity(text: depthText, color: labelColor, bgColor: bgColor) {
                depthLabel.position = SIMD3<Float>(center.x + ext.x / 2 + 0.03, center.y - ext.y / 2 - 0.02, center.z)
                anchor.addChild(depthLabel)
            }
        }

        /// Creates a text label entity with a background panel for AR display.
        private func makeLabelEntity(text: String, color: UIColor, bgColor: UIColor) -> ModelEntity? {
            let mesh = MeshResource.generateText(
                text,
                extrusionDepth: 0.001,
                font: .systemFont(ofSize: 0.025, weight: .bold),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byClipping
            )
            var material = UnlitMaterial()
            material.color = .init(tint: color)

            let textEntity = ModelEntity(mesh: mesh, materials: [material])

            // Center the text on its origin
            let textBounds = textEntity.visualBounds(relativeTo: nil)
            textEntity.position.x = -textBounds.center.x
            textEntity.position.y = -textBounds.center.y

            // Background panel
            let padding: Float = 0.01
            let bgWidth = textBounds.extents.x + padding * 2
            let bgHeight = textBounds.extents.y + padding * 2
            let bgMesh = MeshResource.generatePlane(width: bgWidth, height: bgHeight, cornerRadius: 0.005)
            var bgMaterial = UnlitMaterial()
            bgMaterial.color = .init(tint: bgColor)
            let bgEntity = ModelEntity(mesh: bgMesh, materials: [bgMaterial])
            bgEntity.position.z = -0.001

            let container = ModelEntity()
            container.addChild(bgEntity)
            container.addChild(textEntity)

            // BillboardComponent is iOS 18+, so keep labels static on iOS 17.
            if #available(iOS 18.0, *) {
                container.components.set(BillboardComponent())
            }

            return container
        }
    }
}
