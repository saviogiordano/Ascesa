import Foundation

// MARK: - StartSessionUseCase

/// Performs BLE handshake on the trainer then wires all dependencies into
/// `WorkoutEngine` and starts the 1 Hz recording loop.
struct StartSessionUseCase: Sendable {
    let engine: WorkoutEngine
    let persistence: any PersistenceRepository

    func execute(
        trainer: any TrainerControl,
        hrSource: (any HeartRateSource)?,
        mode: WorkoutMode,
        routeProfile: RouteProfile?,
        athlete: AthleteProfile
    ) async throws {
        // BLE service discovery + FTMS handshake before the engine starts.
        try await trainer.prepare()

        try await engine.start(
            trainer: trainer,
            hrSource: hrSource,
            persistence: persistence,
            mode: mode,
            routeProfile: routeProfile,
            athlete: athlete
        )
    }
}

// MARK: - PauseResumeSessionUseCase

struct PauseResumeSessionUseCase: Sendable {
    let engine: WorkoutEngine

    func pause()   async { await engine.pause() }
    func resume()  async { await engine.resume() }
    func markLap() async { await engine.markLap() }
}

// MARK: - FinishAndExportSessionUseCase

/// Stops the engine, flushes records, exports a FIT file, and saves to HealthKit.
struct FinishAndExportSessionUseCase: Sendable {
    let engine: WorkoutEngine
    let persistence: any PersistenceRepository
    let export: any ExportRepository

    /// Returns the primary export URL (FIT file), or nil when no records were saved.
    func execute(athlete: AthleteProfile) async throws -> URL? {
        let session = try await engine.finish()

        let records = try await persistence.loadRecords(sessionID: session.id)
        guard !records.isEmpty else { return nil }

        let fitURL = try await export.exportFIT(session: session, records: records, athlete: athlete)

        // HealthKit save is best-effort: failure must not block the FIT export.
        try? await export.saveToHealthKit(session: session, records: records)

        return fitURL
    }
}

// MARK: - ImportRouteUseCase

/// Imports a route from a local file, optionally enriches elevation, builds a
/// `RouteProfile`, and persists the route for future sessions.
///
/// File parsing and elevation enrichment are delegated to a `RouteFileImporter`
/// implementation in the Data layer, keeping this use case framework-free.
struct ImportRouteUseCase: Sendable {
    let importer: any RouteFileImporter
    let mapper: RouteToSimulationMapper
    let repository: any MutableRouteProvider

    /// Parse, enrich, map, and save the route.
    /// - Returns: The saved `Route` and its simulation-ready `RouteProfile`.
    func execute(fileURL: URL) async throws -> (route: Route, profile: RouteProfile) {
        let (name, rawPoints) = try await importer.importPoints(from: fileURL)
        let enrichedPoints    = try await importer.enrichElevation(rawPoints)

        let route   = Route(id: UUID(), name: name, points: enrichedPoints)
        let profile = mapper.buildProfile(from: route)

        try await repository.save(route)
        return (route, profile)
    }
}
