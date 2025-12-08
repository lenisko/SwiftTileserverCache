import Foundation

public struct MultiStaticMap: Codable, Hashable, PersistentHashable, Sendable {
    public struct DirectionedMultiStaticMap: Codable, Hashable, Sendable {
        public var direction: CombineDirection
        public var maps: [DirectionedStaticMap]
    }
    public struct DirectionedStaticMap: Codable, Hashable, Sendable {
        public var direction: CombineDirection
        public var map: StaticMap
    }

    public var grid: [DirectionedMultiStaticMap]

    internal var path: String {
        return "Cache/StaticMulti/\(persistentHash).png"
    }
}
