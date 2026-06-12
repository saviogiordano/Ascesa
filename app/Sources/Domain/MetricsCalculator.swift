import Foundation

/// Incrementally updated workout metrics, maintained by WorkoutEngine at 1 Hz.
/// All rolling-window computations are O(1) per tick.
struct MetricsCalculator: Sendable {

    // MARK: - Accumulators

    private var tickCount: Int = 0
    private var totalPower: Int = 0
    private var totalSpeedKmh: Double = 0

    // 3-second rolling window
    private var win3: [Int] = []
    private var sum3: Int = 0

    // 30-second rolling window for Normalized Power
    private var win30: [Int] = []
    private var sum30: Int = 0
    // Accumulated only when the window is full: Σ(30 s avg ^ 4)
    private var npSum4: Double = 0
    private var npCount: Int = 0

    // MARK: - Mutation

    mutating func addTick(power: Int, speedKmh: Double) {
        tickCount += 1
        totalPower += power
        totalSpeedKmh += speedKmh

        // 3 s window
        win3.append(power)
        sum3 += power
        if win3.count > 3 { sum3 -= win3.removeFirst() }

        // 30 s window (NP fourth-power term accumulated once window is full)
        win30.append(power)
        sum30 += power
        if win30.count > 30 { sum30 -= win30.removeFirst() }
        if win30.count == 30 {
            let avg = Double(sum30) / 30.0
            npSum4 += pow(avg, 4)
            npCount += 1
        }
    }

    // MARK: - Read-only metrics

    var averagePower: Int {
        tickCount > 0 ? totalPower / tickCount : 0
    }

    var rollingPower3s: Int {
        win3.isEmpty ? 0 : sum3 / win3.count
    }

    /// Normalized Power per TrainingPeaks methodology (4th root of mean of 30 s averages^4).
    /// Falls back to averagePower until the first 30 s window is complete.
    var normalizedPower: Int {
        guard npCount > 0 else { return averagePower }
        return Int(pow(npSum4 / Double(npCount), 0.25).rounded())
    }

    /// Total mechanical work: Σ power (W) × 1 s ticks / 1000 = kJ.
    var totalKilojoules: Double {
        Double(totalPower) / 1000.0
    }

    /// Gross kilocalories using the FIT-file convention of 4 kJ/kcal.
    var calories: Int {
        Int((totalKilojoules / 4.0).rounded())
    }

    /// Cumulative distance in metres: Σ(speed km/h × 1 s) / 3.6.
    var distanceMeters: Double {
        totalSpeedKmh / 3.6
    }

    /// Intensity Factor = NP / FTP.
    func intensityFactor(ftp: Int) -> Double {
        guard ftp > 0 else { return 0 }
        return Double(normalizedPower) / Double(ftp)
    }

    /// Training Stress Score: (elapsed_s × NP × IF) / (FTP × 3600) × 100.
    func tss(ftp: Int) -> Double {
        guard ftp > 0, tickCount > 0 else { return 0 }
        let np = Double(normalizedPower)
        let iF = np / Double(ftp)
        return Double(tickCount) * np * iF / (Double(ftp) * 3600.0) * 100.0
    }

    func distanceRemaining(routeTotalMeters total: Double) -> Double {
        max(0, total - distanceMeters)
    }

    /// Estimated time to finish in seconds, or nil if not moving / route not set.
    func eta(routeTotalMeters total: Double) -> TimeInterval? {
        let remaining = distanceRemaining(routeTotalMeters: total)
        guard remaining > 0, tickCount > 0, totalSpeedKmh > 0 else { return nil }
        let avgSpeedMs = (totalSpeedKmh / Double(tickCount)) / 3.6
        return remaining / avgSpeedMs
    }
}
