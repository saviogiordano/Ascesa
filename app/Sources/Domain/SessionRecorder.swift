import Foundation

/// Thin adapter between WorkoutEngine ticks and PersistenceRepository.
/// Designed as a value type — WorkoutEngine owns it and all calls are
/// serialised through the engine's actor isolation.
struct SessionRecorder: Sendable {

    private let persistence: any PersistenceRepository

    init(persistence: any PersistenceRepository) {
        self.persistence = persistence
    }

    func append(record: SessionRecord) async throws {
        try await persistence.append(record: record)
    }

    /// Force-flush any buffered records to SQLite. Call at session end.
    func flush() async throws {
        try await persistence.flushPending()
    }
}
