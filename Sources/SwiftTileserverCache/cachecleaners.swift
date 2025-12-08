import Vapor

/// Storage key for cache cleaners to prevent deallocation
private struct CacheCleanersKey: StorageKey {
    typealias Value = [CacheCleaner]
}

func cachecleaners(_ app: Application) throws {
    // Store cleaners in app.storage to prevent deallocation
    app.storage[CacheCleanersKey.self] = [
        CacheCleaner(
            folder: "Cache/Tile",
            maxAgeMinutes: UInt32(Environment.get("TILE_CACHE_MAX_AGE_MINUTES") ?? ""),
            clearDelaySeconds: UInt32(Environment.get("TILE_CACHE_DELAY_SECONDS") ?? "") ?? 900
        ),
        CacheCleaner(
            folder: "Cache/Static",
            maxAgeMinutes: UInt32(Environment.get("STATIC_CACHE_MAX_AGE_MINUTES") ?? ""),
            clearDelaySeconds: UInt32(Environment.get("STATIC_CACHE_DELAY_SECONDS") ?? "") ?? 900
        ),
        CacheCleaner(
            folder: "Cache/StaticMulti",
            maxAgeMinutes: UInt32(Environment.get("STATIC_MUTLI_CACHE_MAX_AGE_MINUTES") ?? ""),
            clearDelaySeconds: UInt32(Environment.get("STATIC_MULTI_CACHE_DELAY_SECONDS") ?? "") ?? 900
        ),
        CacheCleaner(
            folder: "Cache/Marker",
            maxAgeMinutes: UInt32(Environment.get("MARKER_CACHE_MAX_AGE_MINUTES") ?? ""),
            clearDelaySeconds: UInt32(Environment.get("MARKER_CACHE_DELAY_SECONDS") ?? "") ?? 900
        ),
        CacheCleaner(
            folder: "Cache/Regeneratable",
            maxAgeMinutes: UInt32(Environment.get("REGENERATABLE_CACHE_MAX_AGE_MINUTES") ?? ""),
            clearDelaySeconds: UInt32(Environment.get("REGENERATABLE_CACHE_DELAY_SECONDS") ?? "") ?? 900
        )
    ]
}
