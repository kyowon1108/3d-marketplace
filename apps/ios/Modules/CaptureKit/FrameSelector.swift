import Foundation

/// Evaluates captured frame quality and yaw coverage.
/// Placeholder — real implementation will score sharpness, exposure, and angular coverage.
public struct FrameSelector {

    public init() {}

    /// Returns a quality score (0.0–1.0) for a captured image at the given URL.
    public func qualityScore(for imageURL: URL) -> Double {
        // Placeholder: all frames pass quality check
        return 1.0
    }

    /// Evaluates whether the set of captured frames covers sufficient yaw range.
    /// - Parameter imageURLs: URLs of captured frame images.
    /// - Returns: `true` if coverage is sufficient for reconstruction.
    public func hasSufficientCoverage(_ imageURLs: [URL]) -> Bool {
        // Placeholder: require at least 20 frames
        return imageURLs.count >= 20
    }
}
