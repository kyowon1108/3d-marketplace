import RealityKit
import SwiftUI

/// Circular placement indicator shown before the user taps to place a model.
@available(iOS 17.0, *)
struct FootprintIndicator {

    /// Creates a circular plane entity to indicate where the model will be placed.
    /// - Parameters:
    ///   - radius: Radius of the indicator circle.
    ///   - color: Tint color.
    /// - Returns: A ModelEntity representing the footprint.
    @MainActor
    static func create(radius: Float = 0.15, color: UIColor = .systemPurple) -> ModelEntity {
        let mesh = MeshResource.generatePlane(
            width: radius * 2,
            depth: radius * 2,
            cornerRadius: radius
        )
        var material = UnlitMaterial()
        material.color = .init(tint: color.withAlphaComponent(0.4))
        return ModelEntity(mesh: mesh, materials: [material])
    }
}
