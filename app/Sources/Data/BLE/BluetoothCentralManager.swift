@preconcurrency import CoreBluetooth
import Foundation

// MARK: - Public types

struct DiscoveredPeripheral: Sendable {
    let id: UUID
    let name: String?
    let advertisedServiceUUIDs: [CBUUID]
    let rssi: Int
}

enum BLESystemState: Sendable, Equatable {
    case unknown
    case off
    case unauthorized
    case resetting
    case ready
    case scanning
}

enum BLEError: Error, Sendable {
    case bluetoothUnavailable(BLESystemState)
    case connectionTimeout
    case peripheralNotFound
    case serviceNotFound
    case characteristicNotFound
    case disconnectedDuringOperation
    case serviceDiscoveryFailed(Error?)
    case characteristicDiscoveryFailed(Error?)
    case writeFailed(Error?)
}

// MARK: - BluetoothCentralManager

/// Manages all CoreBluetooth operations: scanning, connecting, GATT discovery,
/// characteristic notifications, and automatic reconnection with exponential backoff.
///
/// Design rule: CB objects (CBService, CBCharacteristic) never cross actor boundaries.
/// All public methods accept and return CBUUID; objects are cached internally.
///
/// Usage:
///   1. Create an instance and call `setup()` once (triggers Bluetooth permission prompt).
///   2. Observe `systemStateStream` and call `startScan(for:)` when state becomes `.ready`.
///   3. Call `connect(peripheralID:)` — returns when connected or throws on timeout/error.
///   4. Call `discoverServices` / `discoverCharacteristics` for GATT discovery.
///   5. Call `subscribe(toCharacteristic:peripheralID:)` for notification streams.
///   6. Call `enableAutoReconnect(for:)` to survive drops with exponential backoff.
actor BluetoothCentralManager {

    // Reconnect backoff intervals in seconds: 3, 6, 12, 24, 60, 60, …
    private static let backoffIntervals: [UInt64] = [3, 6, 12, 24, 60]
    private static let connectionTimeoutNs: UInt64 = 30 * 1_000_000_000

    // MARK: Streams

    let systemStateStream: AsyncStream<BLESystemState>
    let discoveredPeripherals: AsyncStream<DiscoveredPeripheral>
    private let systemStateContinuation: AsyncStream<BLESystemState>.Continuation
    private let discoveryStreamContinuation: AsyncStream<DiscoveredPeripheral>.Continuation

    // MARK: State

    private(set) var systemState: BLESystemState = .unknown

    // MARK: CoreBluetooth

    private var central: CBCentralManager!
    private let delegateProxy = DelegateProxy()
    private var currentScanServices: [CBUUID] = []

    // MARK: Peripheral & GATT cache (CB objects never leave the actor)

    private var knownPeripherals: [UUID: CBPeripheral] = [:]
    private var serviceCache: [UUID: [CBService]] = [:]
    private var characteristicCache: [CharacteristicKey: CBCharacteristic] = [:]

    // MARK: Pending async operations

    private var connectionContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var connectionTimeoutTasks: [UUID: Task<Void, Never>] = [:]
    private var serviceDiscovContinuations: [UUID: CheckedContinuation<[String], Error>] = [:]
    private var charDiscovContinuations: [ServiceKey: CheckedContinuation<[String], Error>] = [:]
    private var writeContinuations: [CharacteristicKey: CheckedContinuation<Void, Error>] = [:]
    private var notificationContinuations: [CharacteristicKey: AsyncStream<Data>.Continuation] = [:]

    // MARK: Auto-reconnect

    private var autoReconnectIDs: Set<UUID> = []
    private var reconnectTasks: [UUID: Task<Void, Never>] = [:]
    private var reconnectAttempts: [UUID: Int] = [:]

    // MARK: Init

    init() {
        var stateC: AsyncStream<BLESystemState>.Continuation!
        systemStateStream = AsyncStream { stateC = $0 }
        systemStateContinuation = stateC

        var discC: AsyncStream<DiscoveredPeripheral>.Continuation!
        discoveredPeripherals = AsyncStream { discC = $0 }
        discoveryStreamContinuation = discC
    }

    /// Must be called once after creating the instance (triggers Bluetooth permission prompt).
    func setup() {
        wireDelegateProxy()
        central = CBCentralManager(delegate: delegateProxy, queue: nil)
    }

    // MARK: - Public API

    /// Convenience overload — accepts UUID strings so callers outside the Data layer
    /// don't need to import CoreBluetooth.
    func startScan(for serviceStrings: [String]) {
        startScan(for: serviceStrings.map { CBUUID(string: $0) })
    }

    func startScan(for services: [CBUUID] = []) {
        guard central != nil, central.state == .poweredOn else { return }
        currentScanServices = services
        central.scanForPeripherals(
            withServices: services.isEmpty ? nil : services,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        updateSystemState(.scanning)
    }

    func stopScan() {
        central?.stopScan()
        if systemState == .scanning { updateSystemState(.ready) }
    }

    /// Connects to a previously discovered peripheral. Throws `BLEError.connectionTimeout`
    /// after 30 s and triggers a fresh scan so the peripheral can be re-discovered.
    func connect(peripheralID: UUID) async throws {
        guard central.state == .poweredOn else {
            throw BLEError.bluetoothUnavailable(systemState)
        }
        guard let peripheral = knownPeripherals[peripheralID] else {
            throw BLEError.peripheralNotFound
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connectionContinuations[peripheralID] = cont
            connectionTimeoutTasks[peripheralID] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: Self.connectionTimeoutNs)
                guard !Task.isCancelled else { return }
                await self?.handleConnectionTimeout(peripheralID: peripheralID)
            }
            central.connect(peripheral, options: nil)
        }
    }

    /// Cancels connection / disconnects and disables auto-reconnect for this peripheral.
    func disconnect(peripheralID: UUID) {
        reconnectTasks[peripheralID]?.cancel()
        reconnectTasks[peripheralID] = nil
        autoReconnectIDs.remove(peripheralID)
        reconnectAttempts.removeValue(forKey: peripheralID)
        guard let peripheral = knownPeripherals[peripheralID] else { return }
        central.cancelPeripheralConnection(peripheral)
    }

    /// Returns the UUID strings of discovered services. CBService objects are cached internally.
    /// Callers can create `CBUUID(string:)` from the returned strings inside their own context.
    func discoverServices(_ serviceUUIDs: [CBUUID] = [], peripheralID: UUID) async throws -> [String] {
        guard let peripheral = knownPeripherals[peripheralID] else {
            throw BLEError.peripheralNotFound
        }
        return try await withCheckedThrowingContinuation { cont in
            serviceDiscovContinuations[peripheralID] = cont
            peripheral.discoverServices(serviceUUIDs.isEmpty ? nil : serviceUUIDs)
        }
    }

    /// Returns the UUID strings of discovered characteristics. CBCharacteristic objects are cached internally.
    /// Callers can create `CBUUID(string:)` from the returned strings inside their own context.
    func discoverCharacteristics(
        _ uuids: [CBUUID] = [],
        serviceUUID: CBUUID,
        peripheralID: UUID
    ) async throws -> [String] {
        guard let peripheral = knownPeripherals[peripheralID] else {
            throw BLEError.peripheralNotFound
        }
        guard let service = serviceCache[peripheralID]?.first(where: { $0.uuid == serviceUUID }) else {
            throw BLEError.serviceNotFound
        }
        let key = ServiceKey(peripheralID: peripheralID, serviceUUID: serviceUUID)
        return try await withCheckedThrowingContinuation { cont in
            charDiscovContinuations[key] = cont
            peripheral.discoverCharacteristics(uuids.isEmpty ? nil : uuids, for: service)
        }
    }

    /// Subscribes to a characteristic's notifications; returns an `AsyncStream<Data>`
    /// that yields raw bytes until the peripheral disconnects or `unsubscribe` is called.
    func subscribe(toCharacteristic characteristicUUID: CBUUID, peripheralID: UUID) -> AsyncStream<Data> {
        let key = CharacteristicKey(peripheralID: peripheralID, characteristicUUID: characteristicUUID)
        guard let peripheral = knownPeripherals[peripheralID],
              let characteristic = characteristicCache[key] else {
            return AsyncStream { $0.finish() }
        }
        var continuation: AsyncStream<Data>.Continuation!
        let stream = AsyncStream(Data.self) { continuation = $0 }
        notificationContinuations[key] = continuation
        peripheral.setNotifyValue(true, for: characteristic)
        return stream
    }

    func unsubscribe(fromCharacteristic characteristicUUID: CBUUID, peripheralID: UUID) {
        let key = CharacteristicKey(peripheralID: peripheralID, characteristicUUID: characteristicUUID)
        notificationContinuations.removeValue(forKey: key)?.finish()
        if let peripheral = knownPeripherals[peripheralID],
           let characteristic = characteristicCache[key] {
            peripheral.setNotifyValue(false, for: characteristic)
        }
    }

    /// Writes data to a characteristic. For `.withResponse`, awaits the ACK.
    func write(
        data: Data,
        toCharacteristic characteristicUUID: CBUUID,
        peripheralID: UUID,
        type writeType: CBCharacteristicWriteType = .withResponse
    ) async throws {
        let key = CharacteristicKey(peripheralID: peripheralID, characteristicUUID: characteristicUUID)
        guard let peripheral = knownPeripherals[peripheralID] else {
            throw BLEError.peripheralNotFound
        }
        guard peripheral.state == .connected else {
            throw BLEError.disconnectedDuringOperation
        }
        guard let characteristic = characteristicCache[key] else {
            throw BLEError.characteristicNotFound
        }
        if writeType == .withoutResponse {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            return
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writeContinuations[key] = cont
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    /// Marks this peripheral for automatic reconnection on unexpected disconnects.
    /// Backoff sequence: 3 s → 6 s → 12 s → 24 s → 60 s (capped).
    func enableAutoReconnect(for peripheralID: UUID) {
        autoReconnectIDs.insert(peripheralID)
        reconnectAttempts[peripheralID] = 0
    }

    func disableAutoReconnect(for peripheralID: UUID) {
        autoReconnectIDs.remove(peripheralID)
        reconnectTasks[peripheralID]?.cancel()
        reconnectTasks[peripheralID] = nil
    }

    // MARK: - Delegate handlers (called by DelegateProxy via unstructured Tasks)

    func handleSystemStateChange(_ cbState: CBManagerState) {
        switch cbState {
        case .poweredOn:
            updateSystemState(.ready)
        case .poweredOff:
            updateSystemState(.off)
            failAllPendingOperations(with: BLEError.bluetoothUnavailable(.off))
        case .unauthorized:
            updateSystemState(.unauthorized)
            failAllPendingOperations(with: BLEError.bluetoothUnavailable(.unauthorized))
        case .resetting:
            updateSystemState(.resetting)
        case .unsupported:
            updateSystemState(.off)
        case .unknown:
            updateSystemState(.unknown)
        @unknown default:
            updateSystemState(.unknown)
        }
    }

    // serviceUUIDs arrives as [String] (Sendable) to avoid Task-capture data-race warnings
    func handleDiscoveredPeripheral(
        _ peripheral: CBPeripheral,
        serviceUUIDStrings: [String],
        localName: String?,
        rssi: Int
    ) {
        knownPeripherals[peripheral.identifier] = peripheral
        discoveryStreamContinuation.yield(DiscoveredPeripheral(
            id: peripheral.identifier,
            name: localName ?? peripheral.name,
            advertisedServiceUUIDs: serviceUUIDStrings.map { CBUUID(string: $0) },
            rssi: rssi
        ))
    }

    func handleConnected(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier
        connectionTimeoutTasks.removeValue(forKey: id)?.cancel()
        reconnectAttempts[id] = 0
        reconnectTasks.removeValue(forKey: id)?.cancel()
        connectionContinuations.removeValue(forKey: id)?.resume()
    }

    func handleDisconnected(_ peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier
        connectionTimeoutTasks.removeValue(forKey: id)?.cancel()
        connectionContinuations.removeValue(forKey: id)?
            .resume(throwing: error ?? BLEError.disconnectedDuringOperation)
        serviceDiscovContinuations.removeValue(forKey: id)?
            .resume(throwing: BLEError.disconnectedDuringOperation)
        for key in charDiscovContinuations.keys where key.peripheralID == id {
            charDiscovContinuations.removeValue(forKey: key)?
                .resume(throwing: BLEError.disconnectedDuringOperation)
        }
        for key in notificationContinuations.keys where key.peripheralID == id {
            notificationContinuations.removeValue(forKey: key)?.finish()
        }
        serviceCache.removeValue(forKey: id)
        for key in characteristicCache.keys where key.peripheralID == id {
            characteristicCache.removeValue(forKey: key)
        }
        if autoReconnectIDs.contains(id) {
            scheduleReconnect(peripheralID: id)
        }
    }

    func handleServicesDiscovered(_ peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier
        if let error {
            serviceDiscovContinuations.removeValue(forKey: id)?
                .resume(throwing: BLEError.serviceDiscoveryFailed(error))
        } else {
            let services = peripheral.services ?? []
            serviceCache[id] = services
            serviceDiscovContinuations.removeValue(forKey: id)?
                .resume(returning: services.map(\.uuid.uuidString))
        }
    }

    func handleCharacteristicsDiscovered(
        _ peripheral: CBPeripheral,
        service: CBService,
        error: Error?
    ) {
        let key = ServiceKey(peripheralID: peripheral.identifier, serviceUUID: service.uuid)
        if let error {
            charDiscovContinuations.removeValue(forKey: key)?
                .resume(throwing: BLEError.characteristicDiscoveryFailed(error))
        } else {
            let characteristics = service.characteristics ?? []
            for char in characteristics {
                let cKey = CharacteristicKey(
                    peripheralID: peripheral.identifier,
                    characteristicUUID: char.uuid
                )
                characteristicCache[cKey] = char
            }
            charDiscovContinuations.removeValue(forKey: key)?
                .resume(returning: characteristics.map(\.uuid.uuidString))
        }
    }

    func handleValueUpdated(
        _ peripheral: CBPeripheral,
        characteristicUUID: CBUUID,
        data: Data
    ) {
        let key = CharacteristicKey(peripheralID: peripheral.identifier, characteristicUUID: characteristicUUID)
        notificationContinuations[key]?.yield(data)
    }

    func handleWriteResponse(
        _ peripheral: CBPeripheral,
        characteristicUUID: CBUUID,
        error: Error?
    ) {
        let key = CharacteristicKey(peripheralID: peripheral.identifier, characteristicUUID: characteristicUUID)
        guard let cont = writeContinuations.removeValue(forKey: key) else { return }
        if let error {
            cont.resume(throwing: BLEError.writeFailed(error))
        } else {
            cont.resume()
        }
    }

    // MARK: - Private helpers

    private func updateSystemState(_ newState: BLESystemState) {
        guard newState != systemState else { return }
        systemState = newState
        systemStateContinuation.yield(newState)
    }

    private func failAllPendingOperations(with error: Error) {
        for (id, cont) in connectionContinuations {
            connectionTimeoutTasks.removeValue(forKey: id)?.cancel()
            cont.resume(throwing: error)
        }
        connectionContinuations.removeAll()
        for (_, cont) in serviceDiscovContinuations { cont.resume(throwing: error) }
        serviceDiscovContinuations.removeAll()
        for (_, cont) in charDiscovContinuations { cont.resume(throwing: error) }
        charDiscovContinuations.removeAll()
        for (_, cont) in writeContinuations { cont.resume(throwing: error) }
        writeContinuations.removeAll()
        for (_, cont) in notificationContinuations { cont.finish() }
        notificationContinuations.removeAll()
    }

    private func handleConnectionTimeout(peripheralID: UUID) {
        guard connectionContinuations[peripheralID] != nil else { return }
        connectionTimeoutTasks.removeValue(forKey: peripheralID)
        if let peripheral = knownPeripherals[peripheralID] {
            central.cancelPeripheralConnection(peripheral)
        }
        connectionContinuations.removeValue(forKey: peripheralID)?
            .resume(throwing: BLEError.connectionTimeout)
        startScan(for: currentScanServices)
    }

    private func scheduleReconnect(peripheralID: UUID) {
        let attempt = reconnectAttempts[peripheralID, default: 0]
        reconnectAttempts[peripheralID] = attempt + 1
        let interval = Self.backoffIntervals[min(attempt, Self.backoffIntervals.count - 1)]
        reconnectTasks[peripheralID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.attemptReconnect(peripheralID: peripheralID)
        }
    }

    private func attemptReconnect(peripheralID: UUID) {
        guard autoReconnectIDs.contains(peripheralID) else { return }
        if let peripheral = knownPeripherals[peripheralID] {
            central.connect(peripheral, options: nil)
        } else {
            startScan(for: currentScanServices)
        }
    }

    private func wireDelegateProxy() {
        delegateProxy.onStateUpdate = { [weak self] state in
            Task { await self?.handleSystemStateChange(state) }
        }
        // serviceUUIDs converted to [String] in DelegateProxy to satisfy Swift 6 sending semantics
        delegateProxy.onDiscoverPeripheral = { [weak self] peripheral, serviceUUIDStrings, localName, rssi in
            Task {
                await self?.handleDiscoveredPeripheral(
                    peripheral,
                    serviceUUIDStrings: serviceUUIDStrings,
                    localName: localName,
                    rssi: rssi
                )
            }
        }
        delegateProxy.onConnect = { [weak self] peripheral in
            Task { await self?.handleConnected(peripheral) }
        }
        delegateProxy.onDisconnect = { [weak self] peripheral, error in
            Task { await self?.handleDisconnected(peripheral, error: error) }
        }
        delegateProxy.onDiscoverServices = { [weak self] peripheral, error in
            Task { await self?.handleServicesDiscovered(peripheral, error: error) }
        }
        delegateProxy.onDiscoverCharacteristics = { [weak self] peripheral, service, error in
            Task {
                await self?.handleCharacteristicsDiscovered(peripheral, service: service, error: error)
            }
        }
        // Data extracted in DelegateProxy so CBCharacteristic doesn't cross the boundary
        delegateProxy.onValueUpdate = { [weak self] peripheral, characteristicUUID, data in
            Task { await self?.handleValueUpdated(peripheral, characteristicUUID: characteristicUUID, data: data) }
        }
        delegateProxy.onWriteResponse = { [weak self] peripheral, characteristicUUID, error in
            Task {
                await self?.handleWriteResponse(peripheral, characteristicUUID: characteristicUUID, error: error)
            }
        }
    }
}

// MARK: - DelegateProxy

/// Non-isolated NSObject bridge. All callbacks dispatch into the actor via `Task`.
/// CB objects that aren't Sendable are unwrapped here before crossing the boundary.
private final class DelegateProxy: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate,
    @unchecked Sendable
{
    var onStateUpdate: (@Sendable (CBManagerState) -> Void)?
    // serviceUUIDs as [String] — CBUUID is not unconditionally Sendable in all Swift 6 contexts
    var onDiscoverPeripheral: (@Sendable (CBPeripheral, [String], String?, Int) -> Void)?
    var onConnect: (@Sendable (CBPeripheral) -> Void)?
    var onDisconnect: (@Sendable (CBPeripheral, Error?) -> Void)?
    var onDiscoverServices: (@Sendable (CBPeripheral, Error?) -> Void)?
    var onDiscoverCharacteristics: (@Sendable (CBPeripheral, CBService, Error?) -> Void)?
    // Data extracted here so CBCharacteristic doesn't need to cross actor boundaries
    var onValueUpdate: (@Sendable (CBPeripheral, CBUUID, Data) -> Void)?
    var onWriteResponse: (@Sendable (CBPeripheral, CBUUID, Error?) -> Void)?

    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onStateUpdate?(central.state)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let uuidStrings = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
            .map(\.uuidString)
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        onDiscoverPeripheral?(peripheral, uuidStrings, localName, RSSI.intValue)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        onConnect?(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        onDisconnect?(peripheral, error)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        onDisconnect?(peripheral, error)
    }

    // MARK: CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        onDiscoverServices?(peripheral, error)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        onDiscoverCharacteristics?(peripheral, service, error)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        onValueUpdate?(peripheral, characteristic.uuid, data)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        onWriteResponse?(peripheral, characteristic.uuid, error)
    }
}

// MARK: - Key types

private struct CharacteristicKey: Hashable, Sendable {
    let peripheralID: UUID
    let characteristicUUID: CBUUID
}

private struct ServiceKey: Hashable, Sendable {
    let peripheralID: UUID
    let serviceUUID: CBUUID
}
