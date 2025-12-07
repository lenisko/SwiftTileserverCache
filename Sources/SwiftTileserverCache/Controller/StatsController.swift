import Vapor
import Leaf

internal final class StatsController: @unchecked Sendable {

    private let fileToucher: FileToucher
    
    // Serial queue for stats updates - avoids blocking request threads
    private let statsQueue = DispatchQueue(label: "StatsController")
    private var tileHitRatios = [String: HitRatio]()
    private var staticMapHitRatios = [String: HitRatio]()
    private var markerHitRatios = [String: HitRatio]()

    internal init(fileToucher: FileToucher) {
        self.fileToucher = fileToucher
    }

    // MARK: - Stats

    internal func tileServed(new: Bool, path: String, style: String) {
        if !new { fileToucher.touch(fileName: path) }
        statsQueue.async {
            if self.tileHitRatios[style] == nil { self.tileHitRatios[style] = HitRatio() }
            self.tileHitRatios[style]!.served(new: new)
        }
    }

    internal func staticMapServed(new: Bool, path: String, style: String) {
        if !new { fileToucher.touch(fileName: path) }
        statsQueue.async {
            if self.staticMapHitRatios[style] == nil { self.staticMapHitRatios[style] = HitRatio() }
            self.staticMapHitRatios[style]!.served(new: new)
        }
    }

    internal func markerServed(new: Bool, path: String, domain: String) {
        if !new { fileToucher.touch(fileName: path) }
        statsQueue.async {
            if self.markerHitRatios[domain] == nil { self.markerHitRatios[domain] = HitRatio() }
            self.markerHitRatios[domain]!.served(new: new)
        }
    }

    internal func getTileStats() -> [String: HitRatio] {
        return statsQueue.sync { tileHitRatios }
    }

    internal func getStaticMapStats() -> [String: HitRatio] {
        return statsQueue.sync { staticMapHitRatios }
    }

    internal func getMarkerStats() -> [String: HitRatio] {
        return statsQueue.sync { markerHitRatios }
    }

}
