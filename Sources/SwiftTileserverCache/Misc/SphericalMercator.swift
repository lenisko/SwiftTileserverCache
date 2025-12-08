import Foundation

// Source: https://github.com/qin9smile/sphericalmercator.swift/blob/master/sphericalmercator.swift
public struct Coordinate: Sendable {
    public var latitude: Double
    public var longitude: Double


    // Source: https://github.com/mapbox/turf-swift
    public func coordinate(at distance: Double, facing direction: Double) -> Coordinate {
        let distance = distance / 6_373_000.0
        let direction = direction
        let latitude = self.latitude * .pi / 180.0
        let longitude = self.longitude * .pi / 180.0
        let otherLatitude = asin(
            sin(latitude) * cos(distance) + cos(latitude) * sin(distance) * cos(direction)
        )
        let otherLongitude = longitude + atan2(
            sin(direction) * sin(distance) * cos(latitude),
            cos(distance) - sin(latitude) * sin(otherLatitude)
        )
        return Coordinate(latitude: otherLatitude * 180.0 / .pi, longitude: otherLongitude * 180.0 / .pi)
    }

}

public struct SphericalMercator: Sendable {
    private static let EPSLN = 1.0e-10
    private static let D2R = Double.pi / 180
    private static let R2D = 180 / Double.pi
    private static let A = 6378137.0
    private static let MAXEXTENT = 20037508.342789244
    private static let size: Double = 256

    // Pre-computed zoom level constants (30 levels)
    private let Bc: [Double]
    private let Cc: [Double]
    private let zc: [Double]
    private let Ac: [Double]

    struct Bounds: Sendable {
        var ws: Coordinate
        var en: Coordinate
    }

    struct XYZBounds: Sendable {
        var minPoint: Point
        var maxPoint: Point
    }

    struct Point: Sendable {
        var x: Double
        var y: Double
    }

    public init() {
        var bc = [Double]()
        var cc = [Double]()
        var zc = [Double]()
        var ac = [Double]()
        bc.reserveCapacity(30)
        cc.reserveCapacity(30)
        zc.reserveCapacity(30)
        ac.reserveCapacity(30)
        
        var size = Self.size
        for _ in 0..<30 {
            bc.append(size / 360)
            cc.append(size / (2 * Double.pi))
            zc.append(size / 2)
            ac.append(size)
            size *= 2
        }
        
        self.Bc = bc
        self.Cc = cc
        self.zc = zc
        self.Ac = ac
    }

    /// Convert lon lat to screen pixel value
    func px(coordinate: Coordinate, zoom: Int) -> Point {
        let d = zc[zoom]
        let f = min(max(sin(Self.D2R * coordinate.latitude), -0.9999), 0.9999)
        var x = round(d + coordinate.longitude * Bc[zoom])
        var y = round(d + 0.5 * log((1 + f) / (1 - f)) * (-Cc[zoom]))
        if x > Ac[zoom] {
            x = Ac[zoom]
        }
        if y > Ac[zoom] {
            y = Ac[zoom]
        }
        return Point(x: x, y: y)
    }

    /// Convert screen pixel value to Coordinate
    func ll(px: Point, zoom: Int) -> Coordinate {
        let g = (px.y - zc[zoom]) / (-Cc[zoom])
        let longitude = (px.x - zc[zoom]) / Bc[zoom]
        let latitude = Self.R2D * (2 * atan(exp(g)) - 0.5 * Double.pi)
        return Coordinate(latitude: latitude, longitude: longitude)
    }

    /// Convert tile xyz value to Bounds
    func bbox(x: Double, y: Double, zoom: Int, tmsStyle: Bool, srs: String) -> Bounds {
        var _y = y
        if tmsStyle {
            _y = (Double(truncating: NSDecimalNumber(decimal: pow(2, zoom))) - 1) - y
        }

        let ws = ll(px: Point(x: x * Self.size, y: (_y + 1) * Self.size), zoom: zoom)
        let en = ll(px: Point(x: (x + 1) * Self.size, y: _y * Self.size), zoom: zoom)
        let bounds = Bounds(ws: ws, en: en)
        if srs == "900913" {
            return convert(bounds, to: "900913")
        }
        return bounds
    }

    /// Convert bounds to xyz bounds
    func xyz(bbox: Bounds, zoom: Int, tmsStyle: Bool, srs: String) -> XYZBounds {
        var _bbox = bbox
        if srs == "900913" {
            _bbox = convert(bbox, to: "WGS84")
        }

        let px_ll = px(coordinate: _bbox.ws, zoom: zoom)
        let px_ur = px(coordinate: _bbox.en, zoom: zoom)

        // Y = 0 for XYZ is the top hence minY uses px_ur.y
        let xVals = [floor(px_ll.x / Self.size), floor((px_ur.x - 1) / Self.size)]
        let yVals = [floor(px_ur.y / Self.size), floor((px_ll.y - 1) / Self.size)]

        var xyzBounds = XYZBounds(
            minPoint: Point(x: max(0, xVals.min()!), y: max(0, yVals.min()!)),
            maxPoint: Point(x: xVals.max()!, y: yVals.max()!)
        )

        if tmsStyle {
            let zoomMax = Double(truncating: NSDecimalNumber(decimal: pow(2, zoom))) - 1
            let minY = zoomMax - xyzBounds.maxPoint.y
            let maxY = zoomMax - xyzBounds.minPoint.y
            xyzBounds.minPoint.y = minY
            xyzBounds.maxPoint.y = maxY
        }

        return xyzBounds
    }

    /// Convert coordinate to tile xyz
    func xy(coord: Coordinate, zoom: Int) -> (x: Int, y: Int, xDelta: Int16, yDelta: Int16) {
        let pxC = px(coordinate: coord, zoom: zoom)
        let x = Int(pxC.x / Self.size)
        let xDelta = Int16(pxC.x.truncatingRemainder(dividingBy: Self.size))
        let y = Int(pxC.y / Self.size)
        let yDelta = Int16(pxC.y.truncatingRemainder(dividingBy: Self.size))
        return (x, y, xDelta, yDelta)
    }

    /// Convert projection of given bbox
    func convert(_ bounds: Bounds, to srs: String) -> Bounds {
        if srs == "900913" {
            let point1 = forward(bounds.ws)
            let point2 = forward(bounds.en)
            return Bounds(ws: Coordinate(latitude: point1.x, longitude: point1.y), en: Coordinate(latitude: point2.x, longitude: point2.y))
        } else {
            let point1 = inverse(Point(x: bounds.ws.latitude, y: bounds.ws.longitude))
            let point2 = inverse(Point(x: bounds.en.latitude, y: bounds.en.longitude))
            return Bounds(ws: point1, en: point2)
        }
    }

    /// Convert Coordinate to 900913 Point
    func forward(_ coordinate: Coordinate) -> Point {
        var x = Self.A * coordinate.longitude * Self.D2R
        var y = Self.A * log(tan(Double.pi * 0.25 + 0.5 * coordinate.latitude * Self.D2R))

        // Clamp to maxextent (e.g. poles)
        x = min(max(x, -Self.MAXEXTENT), Self.MAXEXTENT)
        y = min(max(y, -Self.MAXEXTENT), Self.MAXEXTENT)

        return Point(x: x, y: y)
    }

    /// Convert 900913 Point to Coordinate
    func inverse(_ point: Point) -> Coordinate {
        Coordinate(
            latitude: (Double.pi * 0.5 - 2.0 * atan(exp(-point.y / Self.A))) * Self.R2D,
            longitude: point.x * Self.R2D / Self.A
        )
    }
}
