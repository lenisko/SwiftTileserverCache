import Foundation
import Vapor
import Leaf

internal final class StylesAddExternalViewController: ViewController, @unchecked Sendable {

    internal struct Context: ViewControllerContext {
        var pageId: String
        var pageName: String
    }

    init() {}

    internal func render(request: Request) -> EventLoopFuture<View> {
        let context = Context(
            pageId: "styles",
            pageName: "Add External Style"
        )
        return self.render(request: request, template: "StylesAddExternal", context: context)
    }

}
