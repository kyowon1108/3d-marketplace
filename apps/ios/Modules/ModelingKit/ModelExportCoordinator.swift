import Foundation
import SceneKit
import UIKit

/// Extracted model dimensions in meters.
public struct ModelDimensions {
    /// Width in meters (X axis)
    public let width: Double
    /// Height in meters (Y axis)
    public let height: Double
    /// Depth in meters (Z axis)
    public let depth: Double

    /// Width in centimeters, rounded to 1 decimal place.
    public var widthCm: Double { (width * 100).rounded(toPlaces: 1) }
    /// Height in centimeters, rounded to 1 decimal place.
    public var heightCm: Double { (height * 100).rounded(toPlaces: 1) }
    /// Depth in centimeters, rounded to 1 decimal place.
    public var depthCm: Double { (depth * 100).rounded(toPlaces: 1) }

    /// Formatted string like "45.2 × 30.1 × 80.5 cm"
    public var formattedCm: String {
        "\(widthCm) × \(heightCm) × \(depthCm) cm"
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

/// Coordinates USDZ/GLB export from a generated model.
/// GLB export is deferred to a future release.
public struct ModelExportCoordinator {

    public init() {}

    /// Returns the USDZ file URL if it exists at the expected path.
    public func usdzURL(in directory: URL) -> URL? {
        let url = directory.appendingPathComponent("model.usdz")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Extracts bounding box dimensions from a USDZ file using SceneKit.
    /// Returns nil if the scene cannot be loaded or has degenerate bounds.
    public func extractDimensions(from usdzURL: URL) -> ModelDimensions? {
        guard let scene = try? SCNScene(url: usdzURL, options: nil) else {
            return nil
        }

        let (min, max) = scene.rootNode.boundingBox
        let width  = Double(max.x - min.x)
        let height = Double(max.y - min.y)
        let depth  = Double(max.z - min.z)

        // Reject degenerate bounding boxes
        guard width > 0.001, height > 0.001, depth > 0.001 else {
            return nil
        }

        return ModelDimensions(width: width, height: height, depth: depth)
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

    /// GLB export — deferred (USDZ-only in beta).
    public func exportGLB(from usdzURL: URL, to outputURL: URL) async throws {
        throw ExportError.glbNotSupported
    }

    public enum ExportError: Error, LocalizedError {
        case glbNotSupported

        public var errorDescription: String? {
            switch self {
            case .glbNotSupported:
                return "GLB 내보내기는 아직 지원하지 않습니다."
            }
        }
    }
}
