import SwiftUI
import RealityKit

/// Wraps ObjectCaptureSession lifecycle for sweep capture.
@available(iOS 17.0, *)
@MainActor
@Observable
public class SweepCaptureEngine {

    public enum State {
        case idle
        case initializing
        case ready(ObjectCaptureSession)
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var imagesDirectory: URL?

    private var session: ObjectCaptureSession?

    private enum FinalizationError: LocalizedError {
        case noActiveSession
        case timeout

        var errorDescription: String? {
            switch self {
            case .noActiveSession:
                return "No active capture session."
            case .timeout:
                return "Capture finalization timed out."
            }
        }
    }

    public init() {}

    /// Creates and starts an ObjectCaptureSession, writing frames to a temp directory.
    public func start() {
        guard ObjectCaptureSession.isSupported else {
            state = .failed("ObjectCaptureSession not supported on this device")
            return
        }

        state = .initializing

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDir = documentsDir.appendingPathComponent("CapturedImages_\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

            let newSession = ObjectCaptureSession()
            let config = ObjectCaptureSession.Configuration()
            newSession.start(imagesDirectory: imagesDir, configuration: config)

            self.session = newSession
            self.imagesDirectory = imagesDir
            self.state = .ready(newSession)
        } catch {
            state = .failed("Failed to initialize capture: \(error.localizedDescription)")
        }
    }

    /// Cancel the current session and reset state.
    public func cancel() {
        session?.cancel()
        session = nil
        state = .idle
    }

    /// Finish capturing — caller should then use `imagesDirectory` for modeling.
    public func finish() {
        session?.finish()
    }

    /// Finish capture and wait until the session reaches `.completed`.
    /// This avoids starting photogrammetry before the capture pipeline has finalized files.
    public func finishAndAwaitCompletion(timeoutNanoseconds: UInt64 = 45_000_000_000) async throws {
        guard let session else {
            throw FinalizationError.noActiveSession
        }

        session.finish()

        let start = DispatchTime.now().uptimeNanoseconds
        while true {
            switch session.state {
            case .completed:
                // Give the framework a short moment to flush data to disk.
                try await Task.sleep(nanoseconds: 300_000_000)
                self.session = nil
                return
            case .failed(let error):
                self.state = .failed("Capture failed: \(error.localizedDescription)")
                throw error
            default:
                if DispatchTime.now().uptimeNanoseconds - start > timeoutNanoseconds {
                    throw FinalizationError.timeout
                }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }
}
