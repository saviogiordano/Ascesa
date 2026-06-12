import SwiftData
import Foundation

/// All SwiftData operations isolated to a single ModelContext via @ModelActor.
/// Converts between StoredWorkoutSession / StoredAthlete and the Sendable domain structs
/// before crossing actor boundaries, so @Model objects never escape this actor.
@ModelActor
actor SwiftDataSessionStore {

    // MARK: - Session

    func save(_ session: WorkoutSession) throws {
        let athlete = try findOrCreateAthlete(for: session.athleteProfile)
        if let existing = try fetchStoredSession(id: session.id) {
            existing.endDate  = session.endDate
            existing.lapCount = session.lapCount
            existing.athlete  = athlete
        } else {
            let stored = StoredWorkoutSession(
                id:       session.id,
                startDate: session.startDate,
                modeRaw:  session.mode.rawValue,
                lapCount: session.lapCount
            )
            stored.endDate = session.endDate
            stored.athlete = athlete
            modelContext.insert(stored)
        }
        try modelContext.save()
    }

    func close(sessionID: UUID, endDate: Date) throws {
        guard let stored = try fetchStoredSession(id: sessionID) else {
            throw PersistenceError.sessionNotFound(sessionID)
        }
        stored.endDate = endDate
        try modelContext.save()
    }

    func loadAllSessions() throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<StoredWorkoutSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).compactMap { WorkoutSession(from: $0) }
    }

    func loadSession(id: UUID) throws -> WorkoutSession {
        guard let stored = try fetchStoredSession(id: id) else {
            throw PersistenceError.sessionNotFound(id)
        }
        guard let session = WorkoutSession(from: stored) else {
            throw PersistenceError.sessionNotFound(id)
        }
        return session
    }

    func findIncompleteSession() throws -> WorkoutSession? {
        let descriptor = FetchDescriptor<StoredWorkoutSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        // Fetch all and filter in Swift to avoid iOS 17 nil-predicate edge cases.
        let all = try modelContext.fetch(descriptor)
        return all.first { $0.endDate == nil }.flatMap { WorkoutSession(from: $0) }
    }

    // MARK: - Private

    private func fetchStoredSession(id: UUID) throws -> StoredWorkoutSession? {
        let descriptor = FetchDescriptor<StoredWorkoutSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func findOrCreateAthlete(for profile: AthleteProfile) throws -> StoredAthlete {
        let all = try modelContext.fetch(FetchDescriptor<StoredAthlete>())
        let wt = profile.weightKg, ftp = profile.ftpWatts, hr = profile.maxHeartRate
        if let existing = all.first(where: {
            $0.weightKg == wt && $0.ftpWatts == ftp && $0.maxHeartRate == hr
        }) {
            return existing
        }
        let athlete = StoredAthlete(weightKg: wt, ftpWatts: ftp, maxHeartRate: hr)
        modelContext.insert(athlete)
        return athlete
    }
}
