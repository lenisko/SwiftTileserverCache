import Foundation
import Vapor

public final class FileToucher: @unchecked Sendable {

    private let logger: Logger
    private let fileManager = FileManager()
    private let queueLock = NSLock()
    private var queue = [String]()

    public init() {
        let uuidString = UUID().uuidString
        self.logger = Logger(label: "FileToucher-\(uuidString)")
        let thread = DispatchQueue(label: "FileToucher-\(uuidString)")
        thread.async {
            while true {
                self.runOnce()
                sleep(30)
            }
        }
    }

    private func runOnce() {
        queueLock.lock()
        let currentQueue = queue
        queue = []
        queueLock.unlock()

        var count = 0
        if !currentQueue.isEmpty {
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
        }
        if count != 0 {
            logger.info("Touched \(count) Files")
        }
    }

    public func touch(fileName: String) {
        queueLock.lock()
        queue.append(fileName)
        queueLock.unlock()
    }

}
