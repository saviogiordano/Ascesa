import Foundation

/// Local route storage: JSON route files in Application Support + a JSON index for fast search.
/// Implements RouteProvider so it can be injected anywhere a RouteProvider is expected.
///
/// Full SwiftData integration (Athlete, WorkoutSession, Route, Lap schema) comes in
/// PersistenceRepository. This actor is intentionally scoped to route import/retrieval.
actor RouteRepository: MutableRouteProvider {

    private let routesDirectory: URL
    private var indexCache: [RouteID: RouteSummary]?

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        routesDirectory = appSupport.appendingPathComponent("routes", isDirectory: true)
    }

    // MARK: - RouteProvider

    func search(query: RouteQuery) async throws -> [RouteSummary] {
        let idx = try loadIndex()
        var results = Array(idx.values)
        if !query.text.isEmpty {
            let q = query.text.lowercased()
            results = results.filter { $0.name.lowercased().contains(q) }
        }
        if let maxDist = query.maxDistanceKm {
            results = results.filter { $0.distanceMeters <= maxDist * 1_000 }
        }
        if let maxElev = query.maxElevationGainM {
            results = results.filter { $0.elevationGainMeters <= maxElev }
        }
        return results.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func fetch(id: RouteID) async throws -> Route {
        let data = try Data(contentsOf: routeFileURL(for: id))
        return try JSONDecoder().decode(Route.self, from: data)
    }

    // MARK: - Write

    func save(_ route: Route) async throws {
        try ensureDirectory()
        let data = try JSONEncoder().encode(route)
        try data.write(to: routeFileURL(for: route.id), options: .atomic)
        var idx = try loadIndex()
        idx[route.id] = RouteSummary(from: route)
        try persistIndex(idx)
        indexCache = idx
    }

    func delete(id: RouteID) async throws {
        let url = routeFileURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var idx = try loadIndex()
        idx.removeValue(forKey: id)
        try persistIndex(idx)
        indexCache = idx
    }

    // MARK: - Private

    private func routeFileURL(for id: RouteID) -> URL {
        routesDirectory.appendingPathComponent(id.uuidString + ".json")
    }

    private var indexFileURL: URL {
        routesDirectory.appendingPathComponent("index.json")
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: routesDirectory, withIntermediateDirectories: true)
    }

    private func loadIndex() throws -> [RouteID: RouteSummary] {
        if let cached = indexCache { return cached }
        try ensureDirectory()
        var result: [RouteID: RouteSummary] = [:]
        if FileManager.default.fileExists(atPath: indexFileURL.path) {
            let data = try Data(contentsOf: indexFileURL)
            let summaries = try JSONDecoder().decode([RouteSummary].self, from: data)
            result = Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
        }
        indexCache = result
        return result
    }

    private func persistIndex(_ index: [RouteID: RouteSummary]) throws {
        let sorted = index.values.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        let data = try JSONEncoder().encode(sorted)
        try data.write(to: indexFileURL, options: .atomic)
    }
}

// MARK: - RouteSummary from Route

private extension RouteSummary {
    init(from route: Route) {
        let totalDist = route.points.last?.distanceMeters ?? 0
        var elevGain = 0.0, gradeSum = 0.0, maxGrade = 0.0, count = 0
        for i in 1..<route.points.count {
            let p0 = route.points[i - 1], p1 = route.points[i]
            let rise = p1.altitudeMeters - p0.altitudeMeters
            let run = p1.distanceMeters - p0.distanceMeters
            if rise > 0 { elevGain += rise }
            if run > 0 {
                let g = abs(rise / run) * 100
                gradeSum += g
                maxGrade = max(maxGrade, g)
                count += 1
            }
        }
        self.init(
            id: route.id,
            name: route.name,
            distanceMeters: totalDist,
            elevationGainMeters: elevGain,
            gradeAvgPercent: count > 0 ? gradeSum / Double(count) : 0,
            gradeMaxPercent: maxGrade
        )
    }
}
