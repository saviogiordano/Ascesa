import Foundation

enum ExportError: Error, LocalizedError {
    case noRecords
    case healthKitUnavailable
    case healthKitNotAuthorized

    var errorDescription: String? {
        switch self {
        case .noRecords:                return "La sessione non contiene record da esportare."
        case .healthKitUnavailable:     return "HealthKit non è disponibile su questo dispositivo."
        case .healthKitNotAuthorized:   return "Autorizzazione HealthKit negata."
        }
    }
}

/// Contract for exporting a completed workout to standard fitness formats.
/// Implementations live in the Data layer and are injected at app startup.
protocol ExportRepository: Sendable {

    /// Encodes the session as a Garmin-compatible .fit Activity file, writes it
    /// to a temporary directory, and returns its URL.
    /// The caller is responsible for consuming or moving the file before the OS
    /// reclaims the temporary directory.
    func exportFIT(
        session: WorkoutSession,
        records: [SessionRecord],
        athlete: AthleteProfile
    ) async throws -> URL

    /// Saves the workout and per-second HR / power samples to HealthKit.
    func saveToHealthKit(session: WorkoutSession, records: [SessionRecord]) async throws

    /// Encodes the session as a Garmin Training Center XML (.tcx) file.
    func exportTCX(session: WorkoutSession, records: [SessionRecord]) async throws -> URL

    /// Encodes the session as a GPX track file with HR / cadence extensions.
    func exportGPX(session: WorkoutSession, records: [SessionRecord]) async throws -> URL
}
