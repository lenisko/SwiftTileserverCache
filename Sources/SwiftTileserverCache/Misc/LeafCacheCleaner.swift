import Foundation
import Vapor

public actor LeafCacheCleaner {

    private let logger: Logger
    private let folder: URL
    private weak var app: Application?
    private var templates: [String: Date] = [:]
    private nonisolated(unsafe) var runTask: Task<Void, Never>?
    private let clearDelaySeconds: UInt32

    public init(app: Application, folder: String, clearDelaySeconds: UInt32 = 60) {
        self.app = app
        self.folder = URL(fileURLWithPath: folder)
        self.logger = Logger(label: "LeafCacheCleaner-\(folder)")
        self.clearDelaySeconds = clearDelaySeconds
    }
    
    public func start() {
        guard runTask == nil else { return }
        let delay = clearDelaySeconds
        runTask = Task { [weak self] in
            while !Task.isCancelled {
                guard await self?.app != nil else { break }
                await self?.runOnce()
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            }
        }
    }

    deinit {
        runTask?.cancel()
    }

    private func runOnce() {
        guard let app = app else { return }
        
        do {
            let currentFiles = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
                .filter { $0.pathExtension == "json" }
            
            let currentFileNames = Set(currentFiles.compactMap { $0.pathComponents.last })
            
            // Process current files
            for url in currentFiles {
                guard let fileName = url.pathComponents.last,
                      let modificationDate = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                    continue
                }
                
                let oldModificationDate = templates[fileName]
                templates[fileName] = modificationDate
                
                if let oldDate = oldModificationDate, modificationDate != oldDate {
                    let logger = self.logger
                    app.leaf.cache.remove("Templates/\(fileName)", on: app.eventLoopGroup.next()).whenComplete { _ in
                        logger.info("Removed \(fileName) from cache because it changed")
                    }
                }
            }
            
            // Clean up entries for deleted files
            for key in templates.keys where !currentFileNames.contains(key) {
                templates.removeValue(forKey: key)
            }
            
        } catch {
            logger.warning("Failed to update templates")
        }
    }

}
