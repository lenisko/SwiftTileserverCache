import Foundation
import Vapor

public actor FileToucher {

    private let logger: Logger
    private var queue: [String] = []
    private static let maxQueueSize = 50000
    private nonisolated(unsafe) var runTask: Task<Void, Never>?

    public init() {
        let uuidString = UUID().uuidString
        self.logger = Logger(label: "FileToucher-\(uuidString)")
    }
    
    public func start() {
        guard runTask == nil else { return }
        runTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runOnce()
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    deinit {
        runTask?.cancel()
    }

    private func runOnce() {
        let currentQueue = queue
        queue.removeAll(keepingCapacity: false)

        guard !currentQueue.isEmpty else { return }
        
        var count = 0
        // use smaller batch size to avoid command line length limits
        for slice in currentQueue.chunked(into: 75) {
            guard !slice.isEmpty else { continue }
            do {
                try escapedShellOut(to: "/usr/bin/touch", arguments: ["-c"] + slice)
                count += slice.count
            } catch {
                logger.warning("Failed to touch files: \(error)")
            }
        }
        if count != 0 {
            logger.info("Touched \(count) files")
        }
    }

    nonisolated public func touch(fileName: String) {
        Task { await enqueue(fileName: fileName) }
    }

    private func enqueue(fileName: String) {
        guard queue.count < Self.maxQueueSize else {
            logger.warning("FileToucher queue full, dropping touch request")
            return
        }
        queue.append(fileName)
    }

}
