import Foundation

typealias RouteID = UUID

struct RouteQuery: Sendable {
    let text: String
    var maxDistanceKm: Double?
    var maxElevationGainM: Double?
}

struct RouteSummary: Sendable, Identifiable {
    let id: RouteID
    let name: String
    let distanceMeters: Double
    let elevationGainMeters: Double
    let gradeAvgPercent: Double
    let gradeMaxPercent: Double
}

struct RoutePoint: Sendable {
    let distanceMeters: Double
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double
}

struct Route: Sendable, Identifiable {
    let id: RouteID
    let name: String
    let points: [RoutePoint]
}

/// Abstracts route sources: GPX file, OpenRouteService, Strava (personal), etc.
protocol RouteProvider: Sendable {
    func search(query: RouteQuery) async throws -> [RouteSummary]
    func fetch(id: RouteID) async throws -> Route
}
