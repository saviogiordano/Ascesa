import Foundation

// MARK: - State

/// Workout state machine.
/// Transitions: idle → connecting → active ⇄ paused → finishing → finished.
enum WorkoutEngineState: Sendable, Equatable {
    case idle
    case connecting
    case active
    case paused
    case finishing
    case finished
}

enum WorkoutEngineError: Error, LocalizedError {
    case invalidStateTransition
    case noActiveSession

    var errorDescription: String? {
        switch self {
        case .invalidStateTransition: "Transizione di stato non valida."
        case .noActiveSession:        "Nessuna sessione attiva."
        }
    }
}

// MARK: - Snapshot

/// Read-only snapshot emitted every tick via `WorkoutEngine.snapshots`.
/// Consumed by ViewModels without `await`-ing into the engine.
struct WorkoutSnapshot: Sendable {
    let state: WorkoutEngineState
    let trainerMetrics: TrainerMetrics?
    let heartRate: HeartRateSample?
    let virtualPositionMeters: Double
    let gradePercent: Double
    let lapIndex: Int
    let elapsedSeconds: Int
    let calculator: MetricsCalculator
    let routeProfile: RouteProfile?
}

// MARK: - WorkoutEngine

/// Central coordinator for a training session.
///
/// Ownership model:
/// - Owns one `SessionRecorder` (value type, always called from this actor).
/// - Monitors `TrainerControl.metricsStream` and `HeartRateSource.samples` via
///   per-session Tasks whose lifecycle is bound to the session.
/// - Exposes `snapshots` as a `nonisolated` `AsyncStream` so ViewModels can
///   subscribe without awaiting into the actor.
actor WorkoutEngine {

    // MARK: - Public stream

    nonisolated let snapshots: AsyncStream<WorkoutSnapshot>
    private let snapshotsCont: AsyncStream<WorkoutSnapshot>.Continuation

    // MARK: - State

    private(set) var state: WorkoutEngineState = .idle

    private var mode: WorkoutMode = .free
    private var athleteProfile: AthleteProfile = .placeholder
    private var routeProfile: RouteProfile?

    // MARK: - Dependencies

    private var trainer: (any TrainerControl)?
    private var persistence: (any PersistenceRepository)?

    // MARK: - Live sensor values (updated by monitoring tasks)

    private var latestTrainerMetrics: TrainerMetrics?
    private var latestHR: HeartRateSample?

    // MARK: - Session

    private var session: WorkoutSession?
    private var recorder: SessionRecorder?
    private var metricsCalc: MetricsCalculator = .init()
    private var sessionStartDate: Date = .now
    private var lapIndex: Int = 0

    // MARK: - Auto-pause

    private var slowTickCount: Int = 0
    private static let autoPauseSpeedKmh: Double = 1.0
    private static let autoPauseAfterTicks: Int = 3

    // MARK: - Tasks

    private var tickTask: Task<Void, Never>?
    private var metricsTask: Task<Void, Never>?
    private var hrTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        (snapshots, snapshotsCont) = AsyncStream.makeStream(of: WorkoutSnapshot.self)
    }

    // MARK: - Public API

    /// Wire dependencies, create the session record, and start the 1 Hz tick loop.
    /// Callers must call `trainer.prepare()` before this.
    func start(
        trainer: any TrainerControl,
        hrSource: (any HeartRateSource)?,
        persistence: any PersistenceRepository,
        mode: WorkoutMode,
        routeProfile: RouteProfile?,
        athlete: AthleteProfile
    ) async throws {
        guard state == .idle else { throw WorkoutEngineError.invalidStateTransition }

        self.trainer      = trainer
        self.persistence  = persistence
        self.mode         = mode
        self.routeProfile = routeProfile
        self.athleteProfile = athlete
        metricsCalc = MetricsCalculator()
        lapIndex    = 0
        slowTickCount = 0

        transition(to: .connecting)

        // Subscribe to sensor streams before starting the tick so data is ready.
        startMetricsMonitoring(trainer: trainer)
        if let hrSource { startHRMonitoring(hrSource: hrSource) }

        let ws = WorkoutSession(
            id: UUID(),
            startDate: .now,
            endDate: nil,
            mode: mode,
            athleteProfile: athlete,
            lapCount: 0
        )
        session = ws
        sessionStartDate = ws.startDate
        recorder = SessionRecorder(persistence: persistence)
        try await persistence.save(session: ws)

        transition(to: .active)
        startTickLoop()
    }

    func pause() async {
        guard state == .active else { return }
        transition(to: .paused)
        tickTask?.cancel()
        tickTask = nil
        slowTickCount = 0
    }

    func resume() async {
        guard state == .paused else { return }
        transition(to: .active)
        startTickLoop()
    }

    /// Increment the lap counter. Safe to call from active or paused state.
    func markLap() async {
        guard state == .active || state == .paused else { return }
        lapIndex += 1
        session?.lapCount = lapIndex
    }

    /// Stop the session, flush buffered records, close the DB row, and return the
    /// completed `WorkoutSession` for use by `FinishAndExportSessionUseCase`.
    @discardableResult
    func finish() async throws -> WorkoutSession {
        guard state == .active || state == .paused else {
            throw WorkoutEngineError.invalidStateTransition
        }
        guard var finishedSession = session else {
            throw WorkoutEngineError.noActiveSession
        }

        transition(to: .finishing)

        tickTask?.cancel()
        hrTask?.cancel()
        metricsTask?.cancel()
        tickTask = nil
        hrTask = nil
        metricsTask = nil

        let endDate = Date.now
        finishedSession.endDate = endDate
        session = finishedSession

        try await recorder?.flush()
        try await persistence?.close(sessionID: finishedSession.id, endDate: endDate)

        await trainer?.disconnect()

        transition(to: .finished)
        snapshotsCont.finish()

        return finishedSession
    }

    // MARK: - Sensor monitoring

    private func startMetricsMonitoring(trainer: any TrainerControl) {
        metricsTask = Task {
            for await tm in trainer.metricsStream {
                if Task.isCancelled { break }
                latestTrainerMetrics = tm
            }
        }
    }

    private func startHRMonitoring(hrSource: any HeartRateSource) {
        hrTask = Task {
            for await sample in hrSource.samples {
                if Task.isCancelled { break }
                latestHR = sample
            }
        }
    }

    // MARK: - Tick loop

    private func startTickLoop() {
        tickTask = Task {
            var next = ContinuousClock.now + .seconds(1)
            while !Task.isCancelled {
                try? await Task.sleep(until: next, clock: .continuous)
                if Task.isCancelled { break }
                await tick()
                next += .seconds(1)
            }
        }
    }

    private func tick() async {
        guard state == .active, let tm = latestTrainerMetrics, let ws = session else { return }

        // Grade and altitude at the current virtual position (before advancing).
        let currentDist = metricsCalc.distanceMeters
        let gradeNow: Double
        let altNow: Double
        if let profile = routeProfile {
            // Look 0.5 s ahead to compensate for trainer mechanical lag.
            let laggedDist = currentDist + (tm.speedKmh / 3.6) * 0.5
            gradeNow = profile.grade(at: laggedDist)
            altNow   = profile.altitude(at: currentDist)
        } else {
            gradeNow = 0
            altNow   = 0
        }

        // Send resistance command. Errors are non-fatal — trainer keeps last setting.
        try? await applyModeCommand(trainerMetrics: tm, grade: gradeNow)

        // Auto-pause: 3 consecutive ticks below 1 km/h → pause.
        if tm.speedKmh < Self.autoPauseSpeedKmh {
            slowTickCount += 1
            if slowTickCount >= Self.autoPauseAfterTicks {
                await pause()
                return
            }
        } else {
            slowTickCount = 0
        }

        // Advance metrics (increments distanceMeters by speed × 1 s).
        metricsCalc.addTick(power: tm.powerWatts, speedKmh: tm.speedKmh)
        let distNow = metricsCalc.distanceMeters
        let elapsed = Int(Date.now.timeIntervalSince(sessionStartDate))

        let record = SessionRecord(
            id: UUID(),
            sessionID: ws.id,
            timestamp: tm.timestamp,
            powerWatts: tm.powerWatts,
            cadenceRPM: tm.cadenceRPM,
            speedKmh: tm.speedKmh,
            distanceMeters: distNow,
            heartRateBPM: latestHR?.bpm,
            gradePercent: gradeNow,
            virtualPositionMeters: distNow,
            altitudeMeters: altNow,
            lapIndex: lapIndex
        )
        try? await recorder?.append(record: record)

        snapshotsCont.yield(WorkoutSnapshot(
            state: state,
            trainerMetrics: tm,
            heartRate: latestHR,
            virtualPositionMeters: distNow,
            gradePercent: gradeNow,
            lapIndex: lapIndex,
            elapsedSeconds: elapsed,
            calculator: metricsCalc,
            routeProfile: routeProfile
        ))
    }

    private func applyModeCommand(trainerMetrics tm: TrainerMetrics, grade: Double) async throws {
        guard let trainer else { return }
        switch mode {
        case .erg(let targetW):
            try await trainer.setTargetPower(targetW)
        case .simulation:
            let totalWeightKg = athleteProfile.weightKg + 8.0  // 8 kg bike estimate
            try await trainer.setSimulation(grade: grade, totalWeight: totalWeightKg)
        case .free:
            break
        }
    }

    private func transition(to newState: WorkoutEngineState) {
        state = newState
    }
}
