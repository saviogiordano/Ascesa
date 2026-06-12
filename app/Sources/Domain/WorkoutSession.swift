import Foundation

// MARK: - WorkoutMode

enum WorkoutMode: Sendable {
    /// ERG: hold a fixed power target regardless of cadence.
    case erg(targetWatts: Int)
    /// SIM: simulate a real route — resistance follows the grade profile.
    case simulation(routeID: RouteID)
    /// Free ride: no power or grade target.
    case free
}

// MARK: - WorkoutSession

/// Metadata for a single training session (persisted in SwiftData).
struct WorkoutSession: Sendable, Identifiable {
    let id: UUID
    let startDate: Date
    var endDate: Date?
    let mode: WorkoutMode
    let athleteProfile: AthleteProfile
    /// Number of manual laps triggered during the session.
    var lapCount: Int
}

// MARK: - SessionRecord

/// One 1 Hz telemetry record (persisted in SQLite via GRDB).
/// Matches the `session_records` table schema.
struct SessionRecord: Sendable, Identifiable {
    let id: UUID
    let sessionID: UUID
    let timestamp: Date
    let powerWatts: Int
    let cadenceRPM: Int
    let speedKmh: Double
    /// Cumulative distance from session start.
    let distanceMeters: Double
    /// Nil when no HR source is available.
    let heartRateBPM: Int?
    let gradePercent: Double
    /// Virtual position along the route profile.
    let virtualPositionMeters: Double
    let altitudeMeters: Double
    let lapIndex: Int
}
