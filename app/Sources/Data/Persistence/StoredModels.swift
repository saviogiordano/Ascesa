import SwiftData
import Foundation

// MARK: - SwiftData models
// Prefixed "Stored" to avoid name collisions with domain structs of the same name.

@Model final class StoredAthlete {
    @Attribute(.unique) var id: UUID
    var weightKg: Double
    var ftpWatts: Int
    var maxHeartRate: Int
    @Relationship(deleteRule: .cascade, inverse: \StoredWorkoutSession.athlete)
    var sessions: [StoredWorkoutSession] = []

    init(id: UUID = UUID(), weightKg: Double, ftpWatts: Int, maxHeartRate: Int) {
        self.id = id
        self.weightKg = weightKg
        self.ftpWatts = ftpWatts
        self.maxHeartRate = maxHeartRate
    }

    var profile: AthleteProfile {
        AthleteProfile(weightKg: weightKg, ftpWatts: ftpWatts, maxHeartRate: maxHeartRate)
    }
}

@Model final class StoredWorkoutSession {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    /// Serialised WorkoutMode: "erg:<watts>", "simulation:<uuid>", "free"
    var modeRaw: String
    var lapCount: Int
    var athlete: StoredAthlete?
    @Relationship(deleteRule: .cascade, inverse: \StoredLap.session)
    var laps: [StoredLap] = []

    init(id: UUID, startDate: Date, modeRaw: String, lapCount: Int) {
        self.id = id
        self.startDate = startDate
        self.modeRaw = modeRaw
        self.lapCount = lapCount
    }
}

/// Route metadata stored in SwiftData alongside the raw file path.
/// The RouteRepository (JSON-based in MVP) will migrate here in a future phase.
@Model final class StoredRoute {
    @Attribute(.unique) var id: UUID
    var name: String
    var distanceMeters: Double
    var elevationGainMeters: Double
    var gradeAvgPercent: Double
    var gradeMaxPercent: Double
    /// Relative path of the source GPX/FIT/TCX file inside Application Support.
    var sourceFilePath: String
    /// Path of the serialised RouteProfile cache file, nil until first use.
    var profileCachePath: String?
    var importedAt: Date

    init(id: UUID = UUID(), name: String, distanceMeters: Double, elevationGainMeters: Double,
         gradeAvgPercent: Double, gradeMaxPercent: Double, sourceFilePath: String,
         importedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.gradeAvgPercent = gradeAvgPercent
        self.gradeMaxPercent = gradeMaxPercent
        self.sourceFilePath = sourceFilePath
        self.importedAt = importedAt
    }
}

@Model final class StoredLap {
    var index: Int
    var startTimestamp: Date
    var endTimestamp: Date?
    var distanceMeters: Double
    var session: StoredWorkoutSession?

    init(index: Int, startTimestamp: Date, distanceMeters: Double = 0) {
        self.index = index
        self.startTimestamp = startTimestamp
        self.distanceMeters = distanceMeters
    }
}

// MARK: - WorkoutMode serialisation

extension WorkoutMode {
    var rawValue: String {
        switch self {
        case .erg(let watts):         "erg:\(watts)"
        case .simulation(let id):     "simulation:\(id.uuidString)"
        case .free:                   "free"
        }
    }

    init?(rawValue: String) {
        if rawValue == "free" { self = .free; return }
        if rawValue.hasPrefix("erg:"), let watts = Int(rawValue.dropFirst(4)) {
            self = .erg(targetWatts: watts); return
        }
        if rawValue.hasPrefix("simulation:"),
           let uuid = UUID(uuidString: String(rawValue.dropFirst(11))) {
            self = .simulation(routeID: uuid); return
        }
        return nil
    }
}

// MARK: - WorkoutSession ← StoredWorkoutSession

extension WorkoutSession {
    init?(from stored: StoredWorkoutSession) {
        guard let mode = WorkoutMode(rawValue: stored.modeRaw) else { return nil }
        self.init(
            id: stored.id,
            startDate: stored.startDate,
            endDate: stored.endDate,
            mode: mode,
            athleteProfile: stored.athlete?.profile ?? .placeholder,
            lapCount: stored.lapCount
        )
    }
}
