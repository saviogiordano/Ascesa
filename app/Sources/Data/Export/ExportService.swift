import Foundation

/// Concrete implementation of `ExportRepository`.
/// Thin actor wrapper: FIT/TCX/GPX encoding is pure and synchronous; HealthKit
/// is delegated to `HealthKitExporter` which confines itself to `@MainActor`.
actor ExportService: ExportRepository {

    // MARK: - Factory

    static func make() -> ExportService { ExportService() }

    // MARK: - ExportRepository

    func exportFIT(
        session: WorkoutSession,
        records: [SessionRecord],
        athlete: AthleteProfile
    ) async throws -> URL {
        let data = try FITExporter().export(session: session, records: records, athlete: athlete)
        return try writeTempFile(data, name: "\(session.id).fit")
    }

    func saveToHealthKit(session: WorkoutSession, records: [SessionRecord]) async throws {
        try await HealthKitExporter.save(session: session, records: records)
    }

    func exportTCX(session: WorkoutSession, records: [SessionRecord]) async throws -> URL {
        let data = try TCXExporter().export(session: session, records: records)
        return try writeTempFile(data, name: "\(session.id).tcx")
    }

    func exportGPX(session: WorkoutSession, records: [SessionRecord]) async throws -> URL {
        let data = try GPXExporter().export(session: session, records: records)
        return try writeTempFile(data, name: "\(session.id).gpx")
    }

    // MARK: - Private

    private func writeTempFile(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}
