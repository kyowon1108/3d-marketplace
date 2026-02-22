import RealityKit

/// Configures pan/pinch/rotate gestures for placed AR entities.
@available(iOS 17.0, *)
struct GestureController {

    /// Install standard manipulation gestures on an entity.
    /// - Parameters:
    ///   - entity: The entity to make interactive.
    ///   - arView: The ARView hosting the entity.
    @MainActor
    static func installGestures(on entity: HasCollision, in arView: ARView) {
        arView.installGestures([.translation, .rotation, .scale], for: entity)
    }
}
