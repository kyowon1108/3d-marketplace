import Foundation
import SwiftUI

/// Downloads USDZ model files with real-time progress tracking.
/// Uses URLSessionDownloadDelegate for byte-level progress updates.
final class ModelDownloader: NSObject, ObservableObject {
    @Published var progress: Double = 0.0       // 0.0 ~ 1.0
    @Published var isDownloading: Bool = false
    @Published var downloadedURL: URL? = nil
    @Published var error: Error? = nil

    private var downloadTask: URLSessionDownloadTask?
    private var destinationURL: URL?
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    /// Start downloading a model file.
    /// - Parameters:
    ///   - remoteURL: The remote URL of the USDZ file.
    ///   - destination: The local file URL to save the downloaded file.
    func download(from remoteURL: URL, destination: URL) {
        // If already cached, return immediately
        if FileManager.default.fileExists(atPath: destination.path) {
            self.downloadedURL = destination
            return
        }

        self.destinationURL = destination
        self.progress = 0.0
        self.error = nil
        self.isDownloading = true
        self.downloadedURL = nil

        downloadTask = session.downloadTask(with: remoteURL)
        downloadTask?.resume()
    }

    /// Cancel an in-progress download.
    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        progress = 0.0
    }
}

// MARK: - URLSessionDownloadDelegate
extension ModelDownloader: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let dest = destinationURL else {
            self.isDownloading = false
            return
        }

        do {
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: location, to: dest)
            self.downloadedURL = dest
            self.isDownloading = false
            self.progress = 1.0
        } catch {
            self.error = error
            self.isDownloading = false
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            self.error = error
            self.isDownloading = false
        }
    }
}
