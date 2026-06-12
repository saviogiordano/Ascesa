import Foundation

enum PersistenceError: Error, LocalizedError {
    case sessionNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id): "Sessione \(id) non trovata nel database."
        }
    }
}

/// Dual-backend persistence contract.
/// Session metadata lives in SwiftData; 1 Hz time-series in GRDB/SQLite.
/// WorkoutEngine and SessionRecorder depend only on this protocol — never on SwiftData or GRDB directly.
protocol PersistenceRepository: Sendable {

    // ── Session metadata (SwiftData) ─────────────────────────────────

    /// Insert or update session metadata. Called at session start (endDate is nil).
    func save(session: WorkoutSession) async throws

    /// Set endDate. Called at session end or during recovery.
    func close(sessionID: UUID, endDate: Date) async throws

    func loadAllSessions() async throws -> [WorkoutSession]
    func loadSession(id: UUID) async throws -> WorkoutSession

    // ── Time-series records (GRDB/SQLite) ────────────────────────────

    /// Buffer a 1 Hz record. Automatically flushes every 10 records for crash resilience.
    func append(record: SessionRecord) async throws

    /// Force-write all buffered records to SQLite. Idempotent when buffer is empty.
    func flushPending() async throws

    func loadRecords(sessionID: UUID) async throws -> [SessionRecord]

    // ── Crash recovery ───────────────────────────────────────────────

    /// Returns the most recent session with no endDate, or nil if none exists.
    func findIncompleteSession() async throws -> WorkoutSession?
}
