import GRDB
import SwiftData
import Foundation

/// Coordinates SwiftDataSessionStore (session metadata) and a DatabaseQueue (1 Hz time-series).
/// Buffers SessionRecords and flushes to SQLite every 10 records for crash resilience.
actor DefaultPersistenceRepository: PersistenceRepository {

    private let sessionStore: SwiftDataSessionStore
    private let dbQueue: DatabaseQueue
    private var pending: [SessionRecord] = []

    private static let flushThreshold = 10

    private init(sessionStore: SwiftDataSessionStore, dbQueue: DatabaseQueue) {
        self.sessionStore = sessionStore
        self.dbQueue = dbQueue
    }

    // MARK: - Factory

    /// Production setup: SwiftData in Application Support + SQLite alongside it.
    static func make() throws -> DefaultPersistenceRepository {
        let schema = Schema([StoredAthlete.self, StoredWorkoutSession.self,
                             StoredRoute.self, StoredLap.self])
        let container = try ModelContainer(for: schema,
                                           configurations: [ModelConfiguration(schema: schema)])
        return try make(modelContainer: container)
    }

    /// Inject an existing ModelContainer (useful when the app already owns one).
    static func make(modelContainer: ModelContainer) throws -> DefaultPersistenceRepository {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let dbURL = appSupport.appendingPathComponent("ascesa.sqlite")
        let dbQueue = try DatabaseQueue(path: dbURL.path)
        try runMigrations(on: dbQueue)
        return DefaultPersistenceRepository(
            sessionStore: SwiftDataSessionStore(modelContainer: modelContainer),
            dbQueue: dbQueue
        )
    }

    /// In-memory setup for unit tests — no files written to disk.
    static func makeInMemory() throws -> DefaultPersistenceRepository {
        let schema = Schema([StoredAthlete.self, StoredWorkoutSession.self,
                             StoredRoute.self, StoredLap.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        ])
        let dbQueue = try DatabaseQueue()   // in-memory SQLite
        try runMigrations(on: dbQueue)
        return DefaultPersistenceRepository(
            sessionStore: SwiftDataSessionStore(modelContainer: container),
            dbQueue: dbQueue
        )
    }

    // MARK: - Session metadata (delegates to SwiftDataSessionStore)

    func save(session: WorkoutSession) async throws {
        try await sessionStore.save(session)
    }

    func close(sessionID: UUID, endDate: Date) async throws {
        try await sessionStore.close(sessionID: sessionID, endDate: endDate)
    }

    func loadAllSessions() async throws -> [WorkoutSession] {
        try await sessionStore.loadAllSessions()
    }

    func loadSession(id: UUID) async throws -> WorkoutSession {
        try await sessionStore.loadSession(id: id)
    }

    func findIncompleteSession() async throws -> WorkoutSession? {
        try await sessionStore.findIncompleteSession()
    }

    // MARK: - Time-series records (GRDB)

    func append(record: SessionRecord) async throws {
        pending.append(record)
        if pending.count >= Self.flushThreshold {
            try await flushPending()
        }
    }

    func flushPending() async throws {
        guard !pending.isEmpty else { return }
        let rows = pending.map { SessionRecordRow($0) }
        pending.removeAll()
        try await dbQueue.write { db in
            for row in rows {
                try row.insert(db, onConflict: .ignore)
            }
        }
    }

    func loadRecords(sessionID: UUID) async throws -> [SessionRecord] {
        let idString = sessionID.uuidString
        return try await dbQueue.read { db in
            try SessionRecordRow
                .filter(Column("session_id") == idString)
                .order(Column("timestamp"))
                .fetchAll(db)
                .map { $0.toSessionRecord() }
        }
    }

    // MARK: - Schema migrations

    private static func runMigrations(on dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "session_records", ifNotExists: true) { t in
                t.column("id",                .text)   .notNull().primaryKey()
                t.column("session_id",        .text)   .notNull()
                t.column("timestamp",         .double) .notNull()
                t.column("power_w",           .integer).notNull()
                t.column("cadence_rpm",       .integer).notNull()
                t.column("speed_kmh",         .double) .notNull()
                t.column("distance_m",        .double) .notNull()
                t.column("hr_bpm",            .integer)           // nullable
                t.column("grade_pct",         .double) .notNull().defaults(to: 0.0)
                t.column("virtual_position_m",.double) .notNull().defaults(to: 0.0)
                t.column("altitude_m",        .double) .notNull().defaults(to: 0.0)
                t.column("lap_index",         .integer).notNull().defaults(to: 0)
            }
            // Primary query: all records for a session in chronological order
            try db.create(index: "idx_session_records_session_ts",
                          on:    "session_records",
                          columns: ["session_id", "timestamp"],
                          ifNotExists: true)
            // Secondary: latest record (crash recovery)
            try db.create(index: "idx_session_records_ts",
                          on:    "session_records",
                          columns: ["timestamp"],
                          ifNotExists: true)
        }

        try migrator.migrate(dbQueue)
    }
}
