@preconcurrency import CoreBluetooth
import Foundation

// MARK: - FTMS constants

private enum FTMS {
    static let serviceUUID        = CBUUID(string: "1826")
    static let indoorBikeDataUUID = CBUUID(string: "2AD2")
    static let controlPointUUID   = CBUUID(string: "2AD9")
}

// MARK: - Errors

enum FTMSError: Error, Sendable {
    case serviceNotFound
    case characteristicMissing(String)
    /// FTMS result code other than 0x01 (Success).
    case commandFailed(opCode: UInt8, resultCode: UInt8)
    case disconnected
}

// MARK: - FTMSAdapter

/// Concrete implementation of `TrainerControl` using the Bluetooth FTMS profile (UUID 0x1826).
///
/// Lifecycle:
///   1. Create with a connected peripheral: `FTMSAdapter(ble:peripheralID:)`
///   2. Call `prepare()` — discovers GATT, subscribes to notifications, performs
///      the mandatory FTMS "Request Control" handshake.
///   3. Use via the `TrainerControl` protocol (`setTargetPower`, `setSimulation`).
///   4. Call `disconnect()` when done.
actor FTMSAdapter: TrainerControl {

    // MARK: TrainerControl — metrics stream

    nonisolated let metricsStream: AsyncStream<TrainerMetrics>
    private let metricsContinuation: AsyncStream<TrainerMetrics>.Continuation

    // MARK: Dependencies

    private let ble: BluetoothCentralManager
    private let peripheralID: UUID

    // MARK: FTMS control-point state

    /// Pending FTMS-level response for the last written command.
    private var pendingControl: (opCode: UInt8, continuation: CheckedContinuation<Void, Error>)?
    /// Buffered responses that arrived before a continuation was set up.
    private var controlResponseBuffer: [Data] = []

    // MARK: Init

    init(ble: BluetoothCentralManager, peripheralID: UUID) {
        self.ble = ble
        self.peripheralID = peripheralID
        var cont: AsyncStream<TrainerMetrics>.Continuation!
        metricsStream = AsyncStream { cont = $0 }
        metricsContinuation = cont
    }

    // MARK: - Setup

    /// Discovers GATT characteristics, subscribes to notifications, and performs the
    /// mandatory FTMS "Request Control" handshake. Throws if the peripheral is not
    /// an FTMS-capable device or the handshake fails.
    func prepare() async throws {
        // 1 — Discover FTMS service
        let serviceStrings = try await ble.discoverServices(
            [FTMS.serviceUUID], peripheralID: peripheralID
        )
        guard serviceStrings.contains(where: { CBUUID(string: $0) == FTMS.serviceUUID }) else {
            throw FTMSError.serviceNotFound
        }

        // 2 — Discover Indoor Bike Data + Control Point characteristics
        let charStrings = try await ble.discoverCharacteristics(
            [FTMS.indoorBikeDataUUID, FTMS.controlPointUUID],
            serviceUUID: FTMS.serviceUUID,
            peripheralID: peripheralID
        )
        guard charStrings.contains(where: { CBUUID(string: $0) == FTMS.indoorBikeDataUUID }) else {
            throw FTMSError.characteristicMissing("Indoor Bike Data 0x2AD2")
        }
        guard charStrings.contains(where: { CBUUID(string: $0) == FTMS.controlPointUUID }) else {
            throw FTMSError.characteristicMissing("Control Point 0x2AD9")
        }

        // 3 — Subscribe to Indoor Bike Data notifications (telemetry)
        let ibdStream = await ble.subscribe(
            toCharacteristic: FTMS.indoorBikeDataUUID, peripheralID: peripheralID
        )
        Task { [weak self] in await self?.consumeMetrics(ibdStream) }

        // 4 — Subscribe to Control Point indications (command responses)
        let cpStream = await ble.subscribe(
            toCharacteristic: FTMS.controlPointUUID, peripheralID: peripheralID
        )
        Task { [weak self] in await self?.consumeControlPointResponses(cpStream) }

        // 5 — FTMS mandatory handshake: Request Control (Op Code 0x00)
        try await sendControlCommand(ControlPayload.requestControl(), opCode: 0x00)
    }

    // MARK: - TrainerControl

    func setTargetPower(_ watts: Int) async throws {
        try await sendControlCommand(ControlPayload.setTargetPower(watts), opCode: 0x05)
    }

    /// FTMS `Set Indoor Bike Simulation Parameters` (Op Code 0x11).
    /// - Parameters:
    ///   - grade: Road gradient in %. Negative = downhill.
    ///   - totalWeight: Rider + bike in kg. Not part of the FTMS command itself;
    ///     the trainer computes resistance from grade + fixed physics coefficients.
    func setSimulation(grade: Double, totalWeight: Double) async throws {
        try await sendControlCommand(
            ControlPayload.setSimulation(gradePercent: grade),
            opCode: 0x11
        )
    }

    func disconnect() async {
        metricsContinuation.finish()
        await ble.disconnect(peripheralID: peripheralID)
    }

    // MARK: - Private

    private func sendControlCommand(_ data: Data, opCode: UInt8) async throws {
        // Write the command (awaits GATT-level write ack from the BT stack)
        try await ble.write(
            data: data,
            toCharacteristic: FTMS.controlPointUUID,
            peripheralID: peripheralID,
            type: .withResponse
        )
        // Wait for the FTMS-level indication response (Op Code 0x80)
        try await waitForControlResponse(opCode: opCode)
    }

    /// Checks the response buffer first (handles the rare case where the FTMS
    /// indication arrives during the `ble.write` suspension), then waits.
    private func waitForControlResponse(opCode: UInt8) async throws {
        if let idx = controlResponseBuffer.firstIndex(
            where: { $0.count >= 3 && $0[0] == 0x80 && $0[1] == opCode }
        ) {
            let data = controlResponseBuffer.remove(at: idx)
            return try validateResult(data[2], opCode: opCode)
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            pendingControl = (opCode: opCode, continuation: cont)
        }
    }

    private func consumeMetrics(_ stream: AsyncStream<Data>) async {
        for await data in stream {
            if let metrics = IndoorBikeDataParser.parse(data) {
                metricsContinuation.yield(metrics)
            }
        }
    }

    private func consumeControlPointResponses(_ stream: AsyncStream<Data>) async {
        for await data in stream {
            // FTMS response format: [0x80, requestedOpCode, resultCode, ...]
            guard data.count >= 3, data[0] == 0x80 else { continue }
            let requestedOpCode = data[1]

            if let pending = pendingControl, pending.opCode == requestedOpCode {
                pendingControl = nil
                do {
                    try validateResult(data[2], opCode: requestedOpCode)
                    pending.continuation.resume()
                } catch {
                    pending.continuation.resume(throwing: error)
                }
            } else {
                controlResponseBuffer.append(data)
            }
        }
    }

    private func validateResult(_ resultCode: UInt8, opCode: UInt8) throws {
        guard resultCode == 0x01 else {
            throw FTMSError.commandFailed(opCode: opCode, resultCode: resultCode)
        }
    }
}

// MARK: - Indoor Bike Data parser (FTMS spec §4.9)

private enum IndoorBikeDataParser {

    // Flag bitmask positions (16-bit flags field, little-endian)
    // Bit 0 ("More Data"): 0 = Instantaneous Speed IS present, 1 = absent
    private static let flagMoreData:      UInt16 = 0x0001
    private static let flagAvgSpeed:      UInt16 = 0x0002  // +2 bytes
    private static let flagInstCadence:   UInt16 = 0x0004  // +2 bytes, 0.5 rpm/LSB
    private static let flagAvgCadence:    UInt16 = 0x0008  // +2 bytes
    private static let flagTotalDist:     UInt16 = 0x0010  // +3 bytes
    private static let flagResistance:    UInt16 = 0x0020  // +2 bytes
    private static let flagInstPower:     UInt16 = 0x0040  // +2 bytes, sint16, 1 W/LSB
    private static let flagAvgPower:      UInt16 = 0x0080  // +2 bytes
    private static let flagExpEnergy:     UInt16 = 0x0100  // +5 bytes
    private static let flagHeartRate:     UInt16 = 0x0200  // +1 byte
    private static let flagMetabEquiv:    UInt16 = 0x0400  // +1 byte
    private static let flagElapsedTime:   UInt16 = 0x0800  // +2 bytes
    private static let flagRemainingTime: UInt16 = 0x1000  // +2 bytes

    static func parse(_ data: Data) -> TrainerMetrics? {
        guard data.count >= 2 else { return nil }

        let flags = UInt16(data[0]) | (UInt16(data[1]) << 8)
        var i = 2

        var speedKmh    = 0.0
        var cadenceRPM  = 0
        var powerWatts  = 0

        // Instantaneous Speed — present when bit 0 is 0 (inverted flag)
        if flags & flagMoreData == 0 {
            guard i + 2 <= data.count else { return nil }
            speedKmh = Double(readU16(data, i)) / 100.0   // 0.01 km/h per LSB
            i += 2
        }

        if flags & flagAvgSpeed != 0     { guard i + 2 <= data.count else { return nil }; i += 2 }

        if flags & flagInstCadence != 0 {
            guard i + 2 <= data.count else { return nil }
            cadenceRPM = Int(Double(readU16(data, i)) / 2.0)   // 0.5 rpm per LSB
            i += 2
        }

        if flags & flagAvgCadence != 0   { guard i + 2 <= data.count else { return nil }; i += 2 }
        if flags & flagTotalDist != 0    { guard i + 3 <= data.count else { return nil }; i += 3 }
        if flags & flagResistance != 0   { guard i + 2 <= data.count else { return nil }; i += 2 }

        if flags & flagInstPower != 0 {
            guard i + 2 <= data.count else { return nil }
            powerWatts = Int(Int16(bitPattern: readU16(data, i)))   // sint16, 1 W per LSB
            i += 2
        }

        return TrainerMetrics(
            timestamp: Date(),
            powerWatts: max(0, powerWatts),
            cadenceRPM: max(0, cadenceRPM),
            speedKmh:   max(0, speedKmh)
        )
    }

    private static func readU16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
}

// MARK: - Control Point payload builder (FTMS spec §4.16)

private enum ControlPayload {

    /// Op Code 0x00 — Request Control (mandatory before any other command).
    static func requestControl() -> Data {
        Data([0x00])
    }

    /// Op Code 0x05 — Set Target Power.
    /// Parameter: sint16, 1 W/LSB, little-endian.
    static func setTargetPower(_ watts: Int) -> Data {
        var d = Data([0x05])
        appendLE(Int16(clamping: watts), to: &d)
        return d
    }

    /// Op Code 0x11 — Set Indoor Bike Simulation Parameters.
    /// Parameters (all little-endian):
    ///   windSpeedMps: sint16, 0.001 m/s per LSB
    ///   gradePercent: sint16, 0.01 % per LSB
    ///   crr:          uint8,  0.0001 per LSB (rolling resistance coefficient)
    ///   cw:           uint8,  0.01 kg/m per LSB (wind resistance coefficient)
    ///
    /// Default Crr (0.004) and Cw (0.51) represent a typical road bike + rider.
    /// totalWeight is not part of the FTMS command — the trainer handles physics internally.
    static func setSimulation(
        windSpeedMps: Double = 0.0,
        gradePercent: Double,
        crr: Double = 0.004,
        cw:  Double = 0.51
    ) -> Data {
        var d = Data([0x11])
        appendLE(Int16(clamping: Int(windSpeedMps * 1000)), to: &d)
        appendLE(Int16(clamping: Int(gradePercent * 100)),  to: &d)
        d.append(UInt8(clamping: Int(crr * 10_000)))
        d.append(UInt8(clamping: Int(cw  * 100)))
        return d
    }

    private static func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
