import Foundation
import Vapor

public final class CacheCleaner: Sendable {

    private let logger: Logger
    private let folder: URL
    private let maxAgeMinutes: UInt32
    private let runTask: Task<Void, Never>?

    public init(folder: String, maxAgeMinutes: UInt32?, clearDelaySeconds: UInt32?) {
        self.folder = URL(fileURLWithPath: folder)
        self.maxAgeMinutes = maxAgeMinutes ?? 0
        self.logger = Logger(label: "CacheCleaner-\(folder)")
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        
        if let maxAge = maxAgeMinutes, let delay = clearDelaySeconds {
            self.logger.notice("Starting CacheCleaner for \(folder) with maxAgeMinutes: \(maxAge) and clearDelaySeconds: \(delay)")
            let folderPath = self.folder.path
            let logger = self.logger
            self.runTask = Task.detached {
                while !Task.isCancelled {
                    Self.runOnce(folder: folderPath, maxAgeMinutes: maxAge, logger: logger)
                    try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                }
            }
        } else {
            self.runTask = nil
        }
    }
    
    deinit {
        runTask?.cancel()
    }
    
    private static func runOnce(folder: String, maxAgeMinutes: UInt32, logger: Logger) {
        do {
            let count = Int(try escapedShellOut(to: "./Resources/Scripts/clear.bash", arguments: [folder, "\(maxAgeMinutes)"])) ?? 0
            if count != 0 {
                logger.info("Removed \(count) files")
            }
        } catch {
            logger.warning("Failed to run remove script")
        }
    }
    
}
