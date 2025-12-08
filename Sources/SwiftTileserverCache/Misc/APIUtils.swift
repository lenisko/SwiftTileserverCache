import Foundation
import Vapor

public class APIUtils {
    
    private init() {}
    
    public static func downloadFile(request: Request, from: String, to: String, type: String?) -> EventLoopFuture<Void> {
        let headers = HTTPHeaders([("User-Agent", "TileserverCache")])
        let host = URL(string: from)?.host ?? "unknown"
        let startTime = DispatchTime.now()
        MetricsManager.shared.recordHttpClientRequest(host: host)
        
        return request.client.get(URI(string: from), headers: headers).flatMap { response in
            let duration = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
            MetricsManager.shared.recordHttpClientDuration(host: host, duration: duration)
            guard response.status.code >= 200 && response.status.code < 300 else {
                let errorReason = "Failed to load file. Got \(response.status.code)"
                request.application.logger.error(.init(stringLiteral: errorReason))
                MetricsManager.shared.recordHttpClientError(host: host)
                MetricsManager.shared.recordError(type: "http_client", reason: "status_\(response.status.code)")
                return request.eventLoop.future(error: Abort(.internalServerError, reason: errorReason))
            }
            
            if let type = type, response.content.contentType?.type != type {
                let errorReason = "Failed to load file. Got invalid type: \(response.content.contentType?.description ?? "none")"
                request.application.logger.error(.init(stringLiteral: errorReason))
                return request.eventLoop.future(error: Abort(.internalServerError, reason: errorReason))
            }
            
            guard let body = response.body, body.readableBytes != 0 else {
                let errorReason = "Failed to load file. Got empty data"
                request.application.logger.error(.init(stringLiteral: errorReason))
                return request.eventLoop.future(error: Abort(.internalServerError, reason: errorReason))
            }
            
            return request.application.fileio.openFile(
                path: to,
                mode: .write,
                flags: .allowFileCreation(),
                eventLoop: request.eventLoop
            ).flatMap { fileHandle in
                request.application.fileio.write(
                    fileHandle: fileHandle,
                    buffer: body,
                    eventLoop: request.eventLoop
                ).always { _ in
                    try? fileHandle.close()
                }
            }
        }
    }
    
    public static func loadJSON<T: Decodable & Sendable>(request: Request, from: String) -> EventLoopFuture<T> {
        let headers = HTTPHeaders([("User-Agent", "TileserverCache")])
        return request.client.get(URI(string: from), headers: headers).flatMap { response in
            guard response.status.code >= 200 && response.status.code < 300 else {
                let errorReason = "Failed to load file. Got \(response.status.code)"
                request.application.logger.error(.init(stringLiteral: errorReason))
                return request.eventLoop.future(error: Abort(.internalServerError, reason: errorReason))
            }
            
            do {
                let json = try response.content.decode(T.self)
                return request.eventLoop.future(json)
            } catch {
                let errorReason = "Failed to parse JSON: \(error.localizedDescription)"
                request.application.logger.error(.init(stringLiteral: errorReason))
                return request.eventLoop.future(error: Abort(.internalServerError, reason: errorReason))
            }
        }
    }
}
