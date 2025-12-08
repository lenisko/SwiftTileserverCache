import Vapor

internal class ResponseUtils<T> where T: Codable & Sendable {

    internal static func generateResponse(request: Request, staticMap: T?, path: String) -> EventLoopFuture<Response> {
        if (try? request.query.get(Bool.self, at: "pregenerate")) ?? false {
            var regeneratableFuture: EventLoopFuture<Void>? = nil
            if let staticMap = staticMap, (try? request.query.get(Bool.self, at: "regeneratable")) ?? false {
                let regeneratablePath = "Cache/Regeneratable/\(path.components(separatedBy: "/").last!).json"
                if !FileManager.default.fileExists(atPath: regeneratablePath) {
                    regeneratableFuture = storeRegeneratable(request: request, staticMap: staticMap, path: regeneratablePath)
                }
            }
            let response = Response(body: .init(string: path.components(separatedBy: "/").last!))
            response.headers.add(name: .contentType, value: "text/plain")
            if let regeneratableFuture = regeneratableFuture {
                return regeneratableFuture.map { response }
            }
            return request.eventLoop.future(response)
        }
        
        // Use async file streaming to properly manage file handles
        let promise = request.eventLoop.makePromise(of: Response.self)
        Task {
            do {
                let response = try await request.fileio.asyncStreamFile(at: path)
                response.headers.add(name: .cacheControl, value: "max-age=604800, must-revalidate")
                promise.succeed(response)
            } catch {
                promise.fail(error)
            }
        }
        return promise.futureResult
    }

    internal static func storeRegeneratable(request: Request, staticMap: T, path: String) -> EventLoopFuture<Void> {
        return request.application.fileio.openFile(
                path: path,
                mode: .write,
                flags: .allowFileCreation(),
                eventLoop: request.eventLoop
        ).flatMap { fileHandle in
            guard let buffer = try? JSONEncoder().encodeAsByteBuffer(staticMap, allocator: .init()) else {
                return request.eventLoop.future(error: Abort(.internalServerError, reason: "Failed to store regeneratable StaticMap"))
            }
            return request.application.fileio.write(
                fileHandle: fileHandle,
                buffer: buffer,
                eventLoop: request.eventLoop
            ).always { _ in
                try? fileHandle.close()
            }
        }
    }

    internal static func readRegeneratable(request: Request, path: String, as: T.Type) -> EventLoopFuture<T> {
        return request.application.fileio.openFile(
                path: path,
                mode: .read,
                eventLoop: request.eventLoop
        ).flatMap { fileHandle in
            return request.application.fileio.read(fileHandle: fileHandle, byteCount: 131_072, allocator: .init(), eventLoop: request.eventLoop).flatMapThrowing { buffer in
                return try JSONDecoder().decode(T.self, from: buffer)
            }.always { _ in
                try? fileHandle.close()
            }
        }
    }

}
