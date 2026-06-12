@preconcurrency import HealthKit
import Foundation

// Saves a completed workout to HealthKit as a retrospective HKWorkout with
// per-second power and HR samples.
//
// All HealthKit objects are confined to @MainActor to satisfy Swift 6 Sendable
// requirements — HKHealthStore and HKWorkoutBuilder are non-Sendable ObjC classes.
@MainActor
enum HealthKitExporter {

    static func save(session: WorkoutSession, records: [SessionRecord]) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw ExportError.healthKitUnavailable
        }
        guard !records.isEmpty else { throw ExportError.noRecords }

        let store = HKHealthStore()
        try await requestAuthorization(store: store)

        let endDate = session.endDate ?? records.last!.timestamp
        let config  = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .indoor

        // HKWorkoutBuilder allows retroactive workout creation with historical dates.
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: nil)
        try await builder.beginCollection(at: session.startDate)

        let samples = buildSamples(records: records)
        if !samples.isEmpty {
            try await addSamples(samples, to: builder)
        }

        try await builder.endCollection(at: endDate)
        _ = try await builder.finishWorkout()
    }

    // MARK: - Private

    private static func requestAuthorization(store: HKHealthStore) async throws {
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        var read: Set<HKObjectType>  = [HKObjectType.workoutType()]

        if let powerType = HKObjectType.quantityType(forIdentifier: .cyclingPower) {
            read.insert(powerType)
        }
        if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            read.insert(hrType)
        }

        do {
            try await store.requestAuthorization(toShare: share, read: read)
        } catch {
            throw ExportError.healthKitNotAuthorized
        }
    }

    private static func buildSamples(records: [SessionRecord]) -> [HKSample] {
        var samples: [HKSample] = []

        let hrType    = HKQuantityType(.heartRate)
        let hrUnit    = HKUnit.count().unitDivided(by: .minute())
        let powerType = HKQuantityType(.cyclingPower)

        for r in records {
            let end = r.timestamp.addingTimeInterval(1)

            // Cycling power (available on iOS 17+).
            let powerSample = HKQuantitySample(
                type: powerType,
                quantity: HKQuantity(unit: .watt(), doubleValue: Double(r.powerWatts)),
                start: r.timestamp,
                end: end
            )
            samples.append(powerSample)

            // Heart rate (only when a sensor was active).
            if let bpm = r.heartRateBPM {
                let hrSample = HKQuantitySample(
                    type: hrType,
                    quantity: HKQuantity(unit: hrUnit, doubleValue: Double(bpm)),
                    start: r.timestamp,
                    end: end
                )
                samples.append(hrSample)
            }
        }
        return samples
    }

    // HKWorkoutBuilder.addSamples only has a callback API — bridge to async.
    private static func addSamples(_ samples: [HKSample], to builder: HKWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            builder.add(samples) { _, error in
                if let error { cont.resume(throwing: error) }
                else          { cont.resume() }
            }
        }
    }
}
