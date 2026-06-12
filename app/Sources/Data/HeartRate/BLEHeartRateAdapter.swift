@preconcurrency import CoreBluetooth
import Foundation

// MARK: - HR Service constants

private enum HRService {
    static let serviceUUID     = CBUUID(string: "180D")
    static let measurementUUID = CBUUID(string: "2A37")
}

// MARK: - Errors

enum HRError: Error, Sendable {
    case serviceNotFound
    case characteristicNotFound
}

// MARK: - BLEHeartRateAdapter

/// Reads live heart rate from a standard Bluetooth Heart Rate Service (UUID 0x180D).
/// Works with any BLE chest strap or arm band that implements the spec.
///
/// Used as fallback when the Apple Watch is not reachable.
/// Lifecycle mirrors `FTMSAdapter`: create → `prepare()` → consume `samples` → `disconnect()`.
actor BLEHeartRateAdapter {

    nonisolated let samples: AsyncStream<HeartRateSample>
    private let samplesContinuation: AsyncStream<HeartRateSample>.Continuation

    private let ble: BluetoothCentralManager
    private let peripheralID: UUID

    init(ble: BluetoothCentralManager, peripheralID: UUID) {
        self.ble = ble
        self.peripheralID = peripheralID
        var cont: AsyncStream<HeartRateSample>.Continuation!
        samples = AsyncStream { cont = $0 }
        samplesContinuation = cont
    }

    /// Discovers the HR service, subscribes to HR Measurement notifications.
    func prepare() async throws {
        let services = try await ble.discoverServices(
            [HRService.serviceUUID], peripheralID: peripheralID
        )
        guard services.contains(where: { CBUUID(string: $0) == HRService.serviceUUID }) else {
            throw HRError.serviceNotFound
        }
        let chars = try await ble.discoverCharacteristics(
            [HRService.measurementUUID],
            serviceUUID: HRService.serviceUUID,
            peripheralID: peripheralID
        )
        guard chars.contains(where: { CBUUID(string: $0) == HRService.measurementUUID }) else {
            throw HRError.characteristicNotFound
        }
        let stream = await ble.subscribe(
            toCharacteristic: HRService.measurementUUID, peripheralID: peripheralID
        )
        Task { [weak self] in await self?.consumeMeasurements(stream) }
    }

    func disconnect() async {
        samplesContinuation.finish()
        await ble.unsubscribe(fromCharacteristic: HRService.measurementUUID, peripheralID: peripheralID)
    }

    // MARK: - Private

    private func consumeMeasurements(_ stream: AsyncStream<Data>) async {
        for await data in stream {
            if let bpm = HRMeasurementParser.parse(data) {
                samplesContinuation.yield(HeartRateSample(
                    timestamp: Date(),
                    bpm: bpm,
                    source: .bleChestStrap
                ))
            }
        }
    }
}

// MARK: - HR Measurement parser (Bluetooth spec §3.110)

private enum HRMeasurementParser {
    // Byte 0: flags
    //   bit 0: 0 = HR value is uint8, 1 = HR value is uint16
    //   bit 1: sensor contact feature supported
    //   bit 2: sensor contact status (1 = detected)
    //   bit 3: energy expended field present (+2 bytes after HR)
    //   bit 4: RR-interval field(s) present (+2 bytes each)
    // Byte 1 (or 1–2): HR value

    static func parse(_ data: Data) -> Int? {
        guard data.count >= 2 else { return nil }
        let flags = data[0]
        let isUInt16 = (flags & 0x01) != 0
        if isUInt16 {
            guard data.count >= 3 else { return nil }
            return Int(UInt16(data[1]) | (UInt16(data[2]) << 8))
        } else {
            return Int(data[1])
        }
    }
}
