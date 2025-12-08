import Foundation
import Prometheus
import Vapor

#if os(Linux)
import Glibc
#endif

/// Centralized Prometheus metrics for the application
public final class MetricsManager: Sendable {
    public static let shared = MetricsManager()
    
    private let registry = PrometheusCollectorRegistry()
    private let startTime = Date()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Emit Metrics
    
    public func emit() -> String {
        // Update runtime metrics before emitting
        updateRuntimeMetrics()
        
        return registry.emitToString()
    }
    
    // MARK: - Runtime Metrics (updated on each scrape)
    
    private func updateRuntimeMetrics() {
        // Process uptime
        let uptime = Date().timeIntervalSince(startTime)
        registry.makeGauge(name: "tileserver_uptime_seconds", labels: []).record(Int64(uptime))
        
        // Memory metrics - platform specific
        #if os(macOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            registry.makeGauge(name: "tileserver_memory_resident_bytes", labels: []).record(Int64(info.resident_size))
            registry.makeGauge(name: "tileserver_memory_virtual_bytes", labels: []).record(Int64(info.virtual_size))
        }
        #elseif os(Linux)
        // Read from /proc/self/statm for Linux
        if let statm = try? String(contentsOfFile: "/proc/self/statm", encoding: .utf8) {
            let parts = statm.split(separator: " ")
            if parts.count >= 2 {
                let pageSize = Int64(sysconf(Int32(_SC_PAGESIZE)))
                if let vmPages = Int64(parts[0]), let rssPages = Int64(parts[1]) {
                    registry.makeGauge(name: "tileserver_memory_virtual_bytes", labels: []).record(vmPages * pageSize)
                    registry.makeGauge(name: "tileserver_memory_resident_bytes", labels: []).record(rssPages * pageSize)
                }
            }
        }
        #endif
    }
    
    // MARK: - Request Metrics
    
    /// Record a request with type, cache status, and duration
    public func recordRequest(type: String, style: String, cached: Bool, duration: Double) {
        // Total requests by type and style
        registry.makeCounter(
            name: "tileserver_requests_total",
            labels: [("type", type), ("style", style), ("cached", cached ? "true" : "false")]
        ).increment()
        
        // Cache metrics
        if cached {
            registry.makeCounter(name: "tileserver_cache_hits_total", labels: [("type", type)]).increment()
        } else {
            registry.makeCounter(name: "tileserver_cache_misses_total", labels: [("type", type)]).increment()
        }
        
        // Duration histogram
        registry.makeValueHistogram(
            name: "tileserver_request_duration_seconds",
            labels: [("type", type), ("cached", cached ? "true" : "false")],
            buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0]
        ).record(duration)
    }
    
    // MARK: - Convenience Methods (backwards compatible)
    
    public func recordTileRequest(style: String, cached: Bool) {
        registry.makeCounter(
            name: "tileserver_requests_total",
            labels: [("type", "tile"), ("style", style), ("cached", cached ? "true" : "false")]
        ).increment()
        
        if cached {
            registry.makeCounter(name: "tileserver_cache_hits_total", labels: [("type", "tile")]).increment()
        } else {
            registry.makeCounter(name: "tileserver_cache_misses_total", labels: [("type", "tile")]).increment()
        }
    }
    
    public func recordStaticMapRequest(style: String, cached: Bool) {
        registry.makeCounter(
            name: "tileserver_requests_total",
            labels: [("type", "staticmap"), ("style", style), ("cached", cached ? "true" : "false")]
        ).increment()
        
        if cached {
            registry.makeCounter(name: "tileserver_cache_hits_total", labels: [("type", "staticmap")]).increment()
        } else {
            registry.makeCounter(name: "tileserver_cache_misses_total", labels: [("type", "staticmap")]).increment()
        }
    }
    
    public func recordMultiStaticMapRequest(cached: Bool) {
        registry.makeCounter(
            name: "tileserver_requests_total",
            labels: [("type", "multistaticmap"), ("style", "multi"), ("cached", cached ? "true" : "false")]
        ).increment()
        
        if cached {
            registry.makeCounter(name: "tileserver_cache_hits_total", labels: [("type", "multistaticmap")]).increment()
        } else {
            registry.makeCounter(name: "tileserver_cache_misses_total", labels: [("type", "multistaticmap")]).increment()
        }
    }
    
    public func recordMarkerRequest(domain: String, cached: Bool) {
        registry.makeCounter(
            name: "tileserver_requests_total",
            labels: [("type", "marker"), ("style", domain), ("cached", cached ? "true" : "false")]
        ).increment()
        
        if cached {
            registry.makeCounter(name: "tileserver_cache_hits_total", labels: [("type", "marker")]).increment()
        } else {
            registry.makeCounter(name: "tileserver_cache_misses_total", labels: [("type", "marker")]).increment()
        }
    }
    
    public func recordRequestDuration(type: String, duration: Double) {
        registry.makeValueHistogram(
            name: "tileserver_request_duration_seconds",
            labels: [("type", type), ("cached", "unknown")],
            buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0]
        ).record(duration)
    }
    
    // MARK: - Error Metrics
    
    public func recordError(type: String, reason: String) {
        registry.makeCounter(
            name: "tileserver_errors_total",
            labels: [("type", type), ("reason", reason)]
        ).increment()
    }
    
    // MARK: - HTTP Client Metrics
    
    public func recordHttpClientRequest(host: String) {
        registry.makeCounter(
            name: "tileserver_http_client_requests_total",
            labels: [("host", host)]
        ).increment()
    }
    
    public func recordHttpClientError(host: String) {
        registry.makeCounter(
            name: "tileserver_http_client_errors_total",
            labels: [("host", host)]
        ).increment()
    }
    
    public func recordHttpClientDuration(host: String, duration: Double) {
        registry.makeValueHistogram(
            name: "tileserver_http_client_duration_seconds",
            labels: [("host", host)],
            buckets: [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
        ).record(duration)
    }
    
    // MARK: - Queue Metrics
    
    public func setFileToucherQueueSize(_ size: Int) {
        registry.makeGauge(
            name: "tileserver_filetoucher_queue_size",
            labels: []
        ).record(Int64(size))
    }
    
    // MARK: - Async Task Metrics
    
    public func recordActiveTask(type: String, delta: Int) {
        // For tracking concurrent tasks
        registry.makeGauge(
            name: "tileserver_active_tasks",
            labels: [("type", type)]
        ).record(Int64(delta))
    }
    
    public func incrementTasksStarted(type: String) {
        registry.makeCounter(
            name: "tileserver_tasks_started_total",
            labels: [("type", type)]
        ).increment()
    }
    
    public func incrementTasksCompleted(type: String) {
        registry.makeCounter(
            name: "tileserver_tasks_completed_total",
            labels: [("type", type)]
        ).increment()
    }
}
