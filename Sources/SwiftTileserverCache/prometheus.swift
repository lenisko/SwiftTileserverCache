import Vapor

public func metrics(_ app: Application) throws {
    // Metrics endpoint - no authentication required for scraping
    app.get("metrics") { request -> Response in
        let metricsOutput = MetricsManager.shared.emit()
        
        let body = Response.Body(string: metricsOutput)
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/plain; version=0.0.4; charset=utf-8")
        return Response(status: .ok, headers: headers, body: body)
    }
    
    app.logger.notice("Prometheus metrics available at /metrics")
}
