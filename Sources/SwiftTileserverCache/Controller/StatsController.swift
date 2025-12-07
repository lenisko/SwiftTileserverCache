import Vapor
import Leaf

internal actor StatsController {

    private let fileToucher: FileToucher
    
    private var tileHitRatios: [String: HitRatio] = [:]
    private var staticMapHitRatios: [String: HitRatio] = [:]
    private var markerHitRatios: [String: HitRatio] = [:]

    internal init(fileToucher: FileToucher) {
        self.fileToucher = fileToucher
    }

    // MARK: - Stats (nonisolated for fire-and-forget from sync contexts)

    nonisolated internal func tileServed(new: Bool, path: String, style: String) {
        if !new { fileToucher.touch(fileName: path) }
        Task { await recordTile(new: new, style: style) }
    }

    nonisolated internal func staticMapServed(new: Bool, path: String, style: String) {
        if !new { fileToucher.touch(fileName: path) }
        Task { await recordStaticMap(new: new, style: style) }
    }

    nonisolated internal func markerServed(new: Bool, path: String, domain: String) {
        if !new { fileToucher.touch(fileName: path) }
        Task { await recordMarker(new: new, domain: domain) }
    }

    // MARK: - Isolated recording

    private func recordTile(new: Bool, style: String) {
        if tileHitRatios[style] == nil { tileHitRatios[style] = HitRatio() }
        tileHitRatios[style]!.served(new: new)
    }

    private func recordStaticMap(new: Bool, style: String) {
        if staticMapHitRatios[style] == nil { staticMapHitRatios[style] = HitRatio() }
        staticMapHitRatios[style]!.served(new: new)
    }

    private func recordMarker(new: Bool, domain: String) {
        if markerHitRatios[domain] == nil { markerHitRatios[domain] = HitRatio() }
        markerHitRatios[domain]!.served(new: new)
    }

    // MARK: - Getters

    internal func getTileStats() -> [String: HitRatio] {
        tileHitRatios
    }

    internal func getStaticMapStats() -> [String: HitRatio] {
        staticMapHitRatios
    }

    internal func getMarkerStats() -> [String: HitRatio] {
        markerHitRatios
    }

}
