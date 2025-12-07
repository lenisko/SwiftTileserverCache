import Foundation
import Vapor

public final class LeafCacheCleaner: @unchecked Sendable {

    private let logger: Logger
    private let folder: URL
    private weak var app: Application?
    private let templatesLock = NSLock()
    private var templates: [String: Date] = [:]

    public init(app: Application, folder: String, clearDelaySeconds: UInt32=60) {
        self.app = app
        self.folder = URL(fileURLWithPath: folder)
        self.logger = Logger(label: "LeafCacheCleaner-\(folder)")
        let thread = DispatchQueue(label: "LeafCacheCleaner-\(folder)")
        thread.async { [weak self] in
            while let self = self, self.app != nil {
                self.runOnce()
                sleep(clearDelaySeconds)
            }
        }
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
                
                templatesLock.lock()
                let oldModificationDate = templates[fileName]
                templates[fileName] = modificationDate
                templatesLock.unlock()
                
                if let oldDate = oldModificationDate, modificationDate != oldDate {
                    app.leaf.cache.remove("Templates/\(fileName)", on: app.eventLoopGroup.next()).whenComplete { [weak self] _ in
                        self?.logger.info("Removed \(fileName) from cache because it changed")
                    }
                }
            }
            
            // Clean up entries for deleted files
            templatesLock.lock()
            let staleKeys = templates.keys.filter { !currentFileNames.contains($0) }
            for key in staleKeys {
                templates.removeValue(forKey: key)
            }
            templatesLock.unlock()
            
        } catch {
            logger.warning("Failed to update templates")
        }
    }

}
