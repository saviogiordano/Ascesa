import Foundation

/// Unified HR source that merges Watch (priority) and BLE strap (fallback).
///
/// Policy: Watch samples are always forwarded. BLE samples are forwarded only if
/// no Watch sample has arrived in the last `watchTimeout` seconds (default 5 s).
/// When Watch resumes, BLE samples are silently dropped again.
actor HeartRateService: HeartRateSource {

    nonisolated let samples: AsyncStream<HeartRateSample>
    private let samplesContinuation: AsyncStream<HeartRateSample>.Continuation

    private var lastWatchSampleDate: Date?
    private static let watchTimeout: TimeInterval = 5.0

    init() {
        var cont: AsyncStream<HeartRateSample>.Continuation!
        samples = AsyncStream { cont = $0 }
        samplesContinuation = cont
    }

    /// Starts consuming the Watch source. Call once on startup.
    func configure(watchSamples: AsyncStream<HeartRateSample>) {
        Task { [weak self] in await self?.consumeWatch(watchSamples) }
    }

    /// Attaches a BLE fallback source. Can be called at any time after `configure`.
    func addBLEFallback(_ bleSamples: AsyncStream<HeartRateSample>) {
        Task { [weak self] in await self?.consumeBLE(bleSamples) }
    }

    // MARK: - Private

    private func consumeWatch(_ stream: AsyncStream<HeartRateSample>) async {
        for await sample in stream {
            lastWatchSampleDate = sample.timestamp
            samplesContinuation.yield(sample)
        }
    }

    private func consumeBLE(_ stream: AsyncStream<HeartRateSample>) async {
        for await sample in stream {
            let watchActive = lastWatchSampleDate.map {
                Date().timeIntervalSince($0) < Self.watchTimeout
            } ?? false
            guard !watchActive else { continue }
            samplesContinuation.yield(sample)
        }
    }
}
