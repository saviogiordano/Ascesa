import Foundation

/// Live telemetry snapshot emitted by the smart trainer at ~1 Hz.
struct TrainerMetrics: Sendable {
    let timestamp: Date
    /// Instantaneous power output.
    let powerWatts: Int
    /// Pedalling cadence.
    let cadenceRPM: Int
    /// Wheel speed derived from flywheel velocity.
    let speedKmh: Double
}
