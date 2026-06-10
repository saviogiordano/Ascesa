import Foundation

struct HeartRateSample: Sendable {
    let timestamp: Date
    let bpm: Int
    let source: HeartRateSourceKind
}

enum HeartRateSourceKind: Sendable {
    case appleWatch
    case bleChestStrap
}

/// Unified heart rate source: Watch (priority) or BLE strap (fallback).
protocol HeartRateSource: Sendable {
    var samples: AsyncStream<HeartRateSample> { get }
}
