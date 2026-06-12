import Foundation

typealias RouteID = UUID

struct RouteQuery: Sendable {
    let text: String
    var maxDistanceKm: Double?
    var maxElevationGainM: Double?
}

struct RouteSummary: Sendable, Identifiable, Codable {
    let id: RouteID
    let name: String
    let distanceMeters: Double
    let elevationGainMeters: Double
    let gradeAvgPercent: Double
    let gradeMaxPercent: Double
}

struct RoutePoint: Sendable, Codable {
    let distanceMeters: Double
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double
}

struct Route: Sendable, Identifiable, Codable {
    let id: RouteID
    let name: String
    let points: [RoutePoint]
}

/// Abstracts route sources: GPX file, OpenRouteService, Strava (personal), etc.
protocol RouteProvider: Sendable {
    func search(query: RouteQuery) async throws -> [RouteSummary]
    func fetch(id: RouteID) async throws -> Route
}

/// Extends `RouteProvider` with write operations. Implemented by `RouteRepository`.
/// Domain use cases depend on this protocol, never on the concrete actor.
protocol MutableRouteProvider: RouteProvider {
    func save(_ route: Route) async throws
    func delete(id: RouteID) async throws
}

/// Abstracts file-based route import: parsing + optional elevation enrichment.
/// Implemented by the Data layer (GPXParser + ElevationService).
protocol RouteFileImporter: Sendable {
    /// Parse a local file (GPX/FIT/TCX) and return a named list of route points.
    func importPoints(from url: URL) async throws -> (name: String, points: [RoutePoint])

    /// Enrich elevation data via an external service. No-op if unavailable.
    func enrichElevation(_ points: [RoutePoint]) async throws -> [RoutePoint]
}

// MARK: - RouteProfile

/// A route processed for simulation: resampled at a fixed step, elevation
/// smoothed, grade clamped to the trainer's supported range.
/// Built by RouteToSimulationMapper from a raw Route.
struct RouteProfile: Sendable {
    struct Segment: Sendable {
        /// Cumulative distance from the start of the route.
        let distanceMeters: Double
        let gradePercent: Double
        let altitudeMeters: Double
    }

    let routeID: RouteID
    let name: String
    let totalDistanceMeters: Double
    let totalElevationGainMeters: Double
    /// Fixed-step segments ready for grade lookup during a SIM session.
    let segments: [Segment]
}
