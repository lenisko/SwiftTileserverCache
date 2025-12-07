import Foundation
import Vapor
import Leaf

internal final class StylesViewController: ViewController, @unchecked Sendable {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
        var styles: [Style]
        var previewLatitude: Double
        var previewLongitude: Double
        var time: Double
    }

    let stylesController: StylesController
    let previewLatitude: Double
    let previewLongitude: Double

    init(stylesController: StylesController) {
        self.stylesController = stylesController
        self.previewLatitude = Double(Environment.get("PREVIEW_LATIDUDE") ?? "") ?? 47.377105
        self.previewLongitude = Double(Environment.get("PREVIEW_LONGITUDE") ?? "") ?? 8.541655
    }

    internal func render(request: Request) throws -> EventLoopFuture<View> {
        let previewLat = self.previewLatitude
        let previewLon = self.previewLongitude
        return stylesController.getWithAnalysis(request: request).flatMap { [weak self] (styles) in
            let context = Context(
                pageId: "styles",
                pageName: "Styles",
                styles: styles,
                previewLatitude: previewLat,
                previewLongitude: previewLon,
                time: Date().timeIntervalSince1970
            )
            guard let self = self else {
                return request.eventLoop.makeFailedFuture(Abort(.internalServerError))
            }
            return self.render(request: request, template: "Styles", context: context)
        }
    }

}
