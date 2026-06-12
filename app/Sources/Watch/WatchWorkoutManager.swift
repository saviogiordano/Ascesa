import Foundation
import HealthKit
import WatchConnectivity

/// Manages an HKWorkoutSession on the Watch to get live heart rate,
/// displays it locally, and streams it to the iPhone via WCSession.
@MainActor
@Observable
final class WatchWorkoutManager {

    var bpm: Int = 0
    var isActive = false
    var errorMessage: String?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var liveBuilder: HKLiveWorkoutBuilder?
    private var proxy: WorkoutProxy?
    private let sender = WCSender()

    func start() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit non disponibile"
            return
        }

        let hrType = HKQuantityType(.heartRate)
        do {
            try await store.requestAuthorization(
                toShare: [HKObjectType.workoutType()],
                read: [hrType]
            )
        } catch {
            errorMessage = "Autorizzazione negata"
            return
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .indoor

        guard let ws = try? HKWorkoutSession(healthStore: store, configuration: config) else {
            errorMessage = "Impossibile creare sessione"
            return
        }

        let builder = ws.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

        let p = WorkoutProxy { [weak self] newBPM in
            Task { @MainActor in
                self?.bpm = newBPM
                self?.sender.send(bpm: newBPM)
            }
        }
        ws.delegate = p
        builder.delegate = p

        session = ws
        liveBuilder = builder
        proxy = p

        ws.startActivity(with: .now)
        try? await builder.beginCollection(at: .now)
        isActive = true
    }

    func stop() async {
        session?.end()
        try? await liveBuilder?.endCollection(at: .now)
        try? await liveBuilder?.finishWorkout()
        isActive = false
        bpm = 0
        session = nil
        liveBuilder = nil
    }
}

// MARK: - Delegate proxy

private final class WorkoutProxy: NSObject,
    HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, @unchecked Sendable {

    private let onBPM: @Sendable (Int) -> Void

    init(onBPM: @escaping @Sendable (Int) -> Void) {
        self.onBPM = onBPM
    }

    func workoutSession(_ session: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {}

    func workoutSession(_ session: HKWorkoutSession, didFailWithError error: Error) {}

    func workoutBuilder(_ builder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(HKQuantityType(.heartRate)),
              let qty = builder.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity()
        else { return }
        let bpm = Int(qty.doubleValue(for: .count().unitDivided(by: .minute())).rounded())
        onBPM(bpm)
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

// MARK: - WCSession sender

private final class WCSender: NSObject, WCSessionDelegate, @unchecked Sendable {

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(bpm: Int) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["bpm": bpm], replyHandler: nil, errorHandler: nil)
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {}
}
