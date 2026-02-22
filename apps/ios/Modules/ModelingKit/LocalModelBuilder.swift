import Foundation
import RealityKit

/// Wraps PhotogrammetrySession with progress tracking.
@MainActor
@Observable
public class LocalModelBuilder {

    public enum State: Equatable {
        case idle
        case building(progress: Double, status: String)
        case completed(URL)
        case failed(String)
    }

    public enum ModelingError: Error, LocalizedError {
        case inputDirectoryNotFound(URL)
        case insufficientImages(found: Int, minimum: Int)
        case sessionFailed(underlying: Error)

        public var errorDescription: String? {
            switch self {
            case .inputDirectoryNotFound(let url):
                return "이미지 폴더를 찾을 수 없습니다: \(url.lastPathComponent)"
            case .insufficientImages(let found, let minimum):
                return "3D 모델을 만들기에는 캡처된 사진이 너무 부족해요 (\(found)/\(minimum))"
            case .sessionFailed(let error):
                let debugText = String(describing: error)
                if debugText.contains("processError") || debugText.contains("error 6") {
                    return "3D 모델링에 실패했어요. 주변을 좀 더 밝게 하고, 물체의 다양한 각도를 더 촘촘히 캡처해주세요."
                }
                return "3D 모델링 중 오류가 발생했습니다: \(error.localizedDescription)"
            }
        }
    }

    public private(set) var state: State = .idle

    private var buildTask: Task<Void, Never>?

    private struct ProgressUpdate {
        let fraction: Double
        let status: String
    }

    nonisolated private static let supportedImageExtensions: Set<String> = ["heic", "heif", "jpg", "jpeg", "png"]
    nonisolated private static let minimumImageCount = 20

    public init() {}

    /// Start building a 3D model from captured images.
    /// - Parameters:
    ///   - inputDirectory: Directory containing captured images.
    ///   - outputURL: Where to write the USDZ file.
    public func build(inputDirectory: URL, outputURL: URL) {
        cancel()
        state = .building(progress: 0.0, status: "3D 모델링 준비 중...")

        buildTask = Task {
            do {
                let outputDir = outputURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

                #if targetEnvironment(simulator)
                try await buildMock(outputURL: outputURL)
                #else
                if PhotogrammetrySession.isSupported {
                    try await buildReal(inputDirectory: inputDirectory, outputURL: outputURL)
                } else {
                    try await buildMock(outputURL: outputURL)
                }
                #endif

                guard !Task.isCancelled else { return }
                self.state = .completed(outputURL)
            } catch is CancellationError {
                // Cancelled — no-op
            } catch {
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    public func cancel() {
        buildTask?.cancel()
        buildTask = nil
        state = .idle
    }

    // MARK: - Input Validation

    nonisolated private static func validateInputDirectory(_ directory: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ModelingError.inputDirectoryNotFound(directory)
        }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        let imageCount = contents.filter {
            supportedImageExtensions.contains($0.pathExtension.lowercased())
        }.count
        if imageCount < minimumImageCount {
            throw ModelingError.insufficientImages(found: imageCount, minimum: minimumImageCount)
        }
    }

    // MARK: - Real PhotogrammetrySession

    @available(iOS 17.0, *)
    nonisolated private static func runPhotogrammetry(
        inputDirectory: URL,
        outputURL: URL
    ) -> AsyncThrowingStream<ProgressUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    var config = PhotogrammetrySession.Configuration()
                    config.featureSensitivity = .high
                    config.sampleOrdering = .sequential
                    let session = try PhotogrammetrySession(input: inputDirectory, configuration: config)

                    try session.process(requests: [
                        .modelFile(url: outputURL, detail: .reduced)
                    ])

                    for try await output in session.outputs {
                        if Task.isCancelled { session.cancel(); continuation.finish(); return }
                        switch output {
                        case .requestProgress(_, fractionComplete: let f):
                            let status = f < 0.4 ? "물체의 특징을 분석하는 중..." :
                                         f < 0.7 ? "3D 형태를 빚어내는 중..." : "표면의 질감을 입히는 중..."
                            continuation.yield(ProgressUpdate(fraction: f, status: status))
                        case .requestComplete(_, let result):
                            if case .modelFile(let url) = result, url != outputURL {
                                try? FileManager.default.moveItem(at: url, to: outputURL)
                            }
                            continuation.finish(); return
                        case .requestError(_, let error):
                            continuation.finish(throwing: ModelingError.sessionFailed(underlying: error)); return
                        default: break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ModelingError.sessionFailed(underlying: error))
                }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    @available(iOS 17.0, *)
    private func buildReal(inputDirectory: URL, outputURL: URL) async throws {
        try Self.validateInputDirectory(inputDirectory)
        state = .building(progress: 0.05, status: "물체의 특징을 분석하는 중...")

        let stream = Self.runPhotogrammetry(inputDirectory: inputDirectory, outputURL: outputURL)
        for try await update in stream {
            guard !Task.isCancelled else { return }
            let progress = 0.05 + update.fraction * 0.9
            state = .building(progress: progress, status: update.status)
        }
    }

    // MARK: - Mock (simulator / unsupported device)

    private func buildMock(outputURL: URL) async throws {
        let steps: [(Double, String)] = [
            (0.15, "물체의 특징을 분석하는 중..."),
            (0.35, "3D 형태를 빚어내는 중..."),
            (0.60, "표면의 질감을 입히는 중..."),
            (0.85, "모델을 최종 다듬는 중..."),
        ]

        for (progress, status) in steps {
            guard !Task.isCancelled else { throw CancellationError() }
            try await Task.sleep(nanoseconds: 400_000_000)
            state = .building(progress: progress, status: status)
        }

        let dummyData = Data(repeating: 0, count: 4096)
        try dummyData.write(to: outputURL)
    }
}
