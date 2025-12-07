import Foundation
import Vapor
import Leaf

internal final class StatsViewController: ViewController, @unchecked Sendable {

    internal struct Context: ViewControllerContext {
        struct Ratio: Encodable {
            var key: String
            var value: String
        }
        var pageId: String
        var pageName: String
        var tileHitRatios: [Ratio]
        var staticMapHitRatios: [Ratio]
        var markerHitRatios: [Ratio]
    }

    let statsController: StatsController

    init(statsController: StatsController) {
        self.statsController = statsController
    }

    internal func render(request: Request) -> EventLoopFuture<View> {
        let promise = request.eventLoop.makePromise(of: View.self)
        Task {
            let tileHitRatios = await statsController.getTileStats().map { (ratio) -> Context.Ratio in
                return .init(key: ratio.key, value: ratio.value.displayValue)
            }
            let staticMapHitRatios = await statsController.getStaticMapStats().map { (ratio) -> Context.Ratio in
                return .init(key: ratio.key, value: ratio.value.displayValue)
            }
            let markerHitRatios = await statsController.getMarkerStats().map { (ratio) -> Context.Ratio in
                return .init(key: ratio.key, value: ratio.value.displayValue)
            }
            let context = Context(
                pageId: "stats",
                pageName: "Stats",
                tileHitRatios: tileHitRatios,
                staticMapHitRatios: staticMapHitRatios,
                markerHitRatios: markerHitRatios
            )
            do {
                let view = try await self.render(request: request, template: "Stats", context: context).get()
                promise.succeed(view)
            } catch {
                promise.fail(error)
            }
        }
        return promise.futureResult
    }

}
