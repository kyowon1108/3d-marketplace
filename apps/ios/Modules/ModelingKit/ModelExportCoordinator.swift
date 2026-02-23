import Foundation
import SceneKit
import UIKit

/// Coordinates USDZ/GLB export from a generated model.
/// GLB export is deferred to a future release.
public struct ModelExportCoordinator {

    public init() {}

    /// Returns the USDZ file URL if it exists at the expected path.
    public func usdzURL(in directory: URL) -> URL? {
        let url = directory.appendingPathComponent("model.usdz")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Generates a thumbnail PNG snapshot from a USDZ file using SceneKit.
    /// Returns the file URL of the saved thumbnail, or nil on failure.
    public func generateThumbnail(from usdzURL: URL, size: CGSize = CGSize(width: 512, height: 512)) -> URL? {
        guard let scene = try? SCNScene(url: usdzURL, options: nil) else {
            return nil
        }

        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene

        // Set up camera if scene doesn't have one
        if scene.rootNode.childNode(withName: "camera", recursively: true) == nil {
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            // Position camera to frame the model
            let (minBound, maxBound) = scene.rootNode.boundingBox
            let center = SCNVector3(
                (minBound.x + maxBound.x) / 2,
                (minBound.y + maxBound.y) / 2,
                (minBound.z + maxBound.z) / 2
            )
            let extent = max(maxBound.x - minBound.x, maxBound.y - minBound.y, maxBound.z - minBound.z)
            let distance = Float(extent) * 2.0
            cameraNode.position = SCNVector3(center.x, center.y + Float(extent) * 0.3, center.z + distance)
            cameraNode.look(at: center)
            scene.rootNode.addChildNode(cameraNode)
        }

        // Add ambient light
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 1000
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)

        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 400
        scene.rootNode.addChildNode(ambientLight)

        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)

        guard let pngData = image.pngData() else {
            return nil
        }

        let thumbnailURL = usdzURL.deletingLastPathComponent().appendingPathComponent("thumbnail.png")
        do {
            try pngData.write(to: thumbnailURL)
            return thumbnailURL
        } catch {
            return nil
        }
    }

    /// GLB export — placeholder for future implementation.
    public func exportGLB(from usdzURL: URL, to outputURL: URL) async throws {
        // Future: SceneKit → GLB conversion
        throw ExportError.glbNotSupported
    }

    public enum ExportError: Error, LocalizedError {
        case glbNotSupported

        public var errorDescription: String? {
            switch self {
            case .glbNotSupported:
                return "GLB export is not yet supported."
            }
        }
    }
}
