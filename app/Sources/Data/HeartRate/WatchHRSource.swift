import Foundation
import WatchConnectivity

/// Receives live heart rate samples sent by the Apple Watch companion app
/// via `WCSession.sendMessage(["bpm": Int], replyHandler: nil)`.
///
/// The Watch sends one message per second during an active `HKWorkoutSession`.
/// This actor exposes the samples as an `AsyncStream<HeartRateSample>`.
actor WatchHRSource {

    nonisolated let samples: AsyncStream<HeartRateSample>
    private let samplesContinuation: AsyncStream<HeartRateSample>.Continuation

    nonisolated let reachabilityStream: AsyncStream<Bool>
    private let reachabilityContinuation: AsyncStream<Bool>.Continuation

    private(set) var isWatchReachable = false

    private let delegate = WCDelegate()

    init() {
        var cont: AsyncStream<HeartRateSample>.Continuation!
        samples = AsyncStream { cont = $0 }
        samplesContinuation = cont

        var reachCont: AsyncStream<Bool>.Continuation!
        reachabilityStream = AsyncStream { reachCont = $0 }
        reachabilityContinuation = reachCont
    }

    /// Activates WCSession. Safe to call multiple times (guards against unsupported hardware).
    func activate() {
        guard WCSession.isSupported() else { return }
        delegate.onMessage = { [weak self] message in
            // Extract Int (Sendable) before Task — [String: Any] is not Sendable in Swift 6
            guard let bpm = message["bpm"] as? Int else { return }
            Task { await self?.handleMessage(bpm: bpm) }
        }
        delegate.onReachabilityChange = { [weak self] reachable in
            Task { await self?.handleReachabilityChange(reachable) }
        }
        WCSession.default.delegate = delegate
        WCSession.default.activate()
    }

    // MARK: - Private

    private func handleMessage(bpm: Int) {
        guard bpm > 0 else { return }
        samplesContinuation.yield(HeartRateSample(
            timestamp: Date(),
            bpm: bpm,
            source: .appleWatch
        ))
    }

    private func handleReachabilityChange(_ reachable: Bool) {
        isWatchReachable = reachable
        reachabilityContinuation.yield(reachable)
    }
}

// MARK: - WCSessionDelegate proxy

/// Non-isolated NSObject bridge. Dispatches all WCSession callbacks into the actor.
private final class WCDelegate: NSObject, WCSessionDelegate, @unchecked Sendable {

    var onMessage: (@Sendable ([String: Any]) -> Void)?
    var onReachabilityChange: (@Sendable (Bool) -> Void)?

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    // Required on iOS — deactivated during Watch handoff
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate to be ready for the next Watch session
        WCSession.default.activate()
    }

    // Watch sends `sendMessage(_:replyHandler:)` without a reply handler
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        onMessage?(message)
    }

    // Watch sends `sendMessage(_:replyHandler:)` with a reply handler
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        onMessage?(message)
        replyHandler([:])
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        onReachabilityChange?(session.isReachable)
    }
}
