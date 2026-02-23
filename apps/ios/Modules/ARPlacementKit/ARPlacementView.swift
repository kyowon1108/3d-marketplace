import SwiftUI
import RealityKit
import ARKit
import Combine

/// RealityKit-based AR placement view with plane detection and tap-to-place.
@available(iOS 17.0, *)
struct ARPlacementView: UIViewRepresentable {
    let modelURL: URL
    @Binding var wallSnapEnabled: Bool
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
        context.coordinator.onDismiss = onDismiss
        context.coordinator.onError = onError
        context.coordinator.prepareModel()

        // Add footprint indicator
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

            let mesh = MeshResource.generatePlane(width: 0.3, depth: 0.3, cornerRadius: 0.15)
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

            // Remove footprint
            footprintEntity?.removeFromParent()
            modelPlaced = true
            isPlacingModel = false
        }
    }
}
