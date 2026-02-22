import Foundation

/// Coordinates USDZ/GLB export from a generated model.
/// GLB export is deferred to a future release.
public struct ModelExportCoordinator {

    public init() {}

    /// Returns the USDZ file URL if it exists at the expected path.
    public func usdzURL(in directory: URL) -> URL? {
        let url = directory.appendingPathComponent("model.usdz")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
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
