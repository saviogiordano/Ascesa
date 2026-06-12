// DEBUG — rimuovere prima del rilascio
import SwiftUI

// MARK: - ViewModel

@MainActor
@Observable
final class BLEDebugViewModel {

    // MARK: BLE scan/connect state

    var systemState: BLESystemState = .unknown
    var discovered: [DiscoveredPeripheral] = []
    var connectedID: UUID?
    var gattServices: [String] = []
    var isConnecting = false

    // MARK: FTMS state

    enum FTMSState { case idle, preparing, ready, error(String) }
    var ftmsState: FTMSState = .idle
    var currentMetrics: TrainerMetrics?
    var ergWatts: Int = 100
    var simGrade: Double = 0.0

    // MARK: HR state

    enum HRBLEState { case idle, preparing, ready, error(String) }
    var currentHR: HeartRateSample?
    var watchReachable = false
    var hrBLEState: HRBLEState = .idle

    // MARK: Log

    var log: [String] = []

    // MARK: Private

    private let ble = BluetoothCentralManager()
    private let watchHRSource = WatchHRSource()
    private let hrService = HeartRateService()
    private var bleHRAdapter: BLEHeartRateAdapter?
    private var ftmsAdapter: FTMSAdapter?
    private var observationTasks: [Task<Void, Never>] = []

    // MARK: - Lifecycle

    func onAppear() {
        Task {
            await ble.setup()
            let t1 = Task { await self.observeState() }
            let t2 = Task { await self.observeDiscovery() }
            observationTasks = [t1, t2]
        }
        Task {
            await watchHRSource.activate()
            watchReachable = await watchHRSource.isWatchReachable
            await hrService.configure(watchSamples: watchHRSource.samples)
            let t3 = Task { await self.observeHR() }
            let t4 = Task { await self.observeWatchReachability() }
            observationTasks += [t3, t4]
        }
    }

    func onDisappear() {
        observationTasks.forEach { $0.cancel() }
        observationTasks = []
    }

    // MARK: - BLE actions

    func connect(to peripheral: DiscoveredPeripheral) {
        guard !isConnecting else { return }
        isConnecting = true
        Task {
            do {
                appendLog("Connessione a \(peripheral.name ?? peripheral.id.uuidString)…")
                try await ble.connect(peripheralID: peripheral.id)
                connectedID = peripheral.id
                appendLog("Connesso ✓")

                let services = try await ble.discoverServices(peripheralID: peripheral.id)
                gattServices = services
                appendLog("Services (\(services.count)): \(services.joined(separator: ", "))")
            } catch {
                appendLog("Errore connessione: \(error)")
            }
            isConnecting = false
        }
    }

    func disconnect() {
        guard let id = connectedID else { return }
        Task {
            ftmsAdapter = nil
            ftmsState = .idle
            currentMetrics = nil
            if let hr = bleHRAdapter { await hr.disconnect() }
            bleHRAdapter = nil
            hrBLEState = .idle
            await ble.disconnect(peripheralID: id)
            connectedID = nil
            gattServices = []
            appendLog("Disconnesso")
        }
    }

    func restartScan() {
        discovered = []
        gattServices = []
        Task {
            await ble.startScan(for: Self.scanServices)
            appendLog("Scan riavviato")
        }
    }

    // MARK: - FTMS actions

    var hasFTMS: Bool {
        gattServices.contains(where: { $0.uppercased() == "1826" })
    }

    func prepareFTMS() {
        guard let id = connectedID else { return }
        ftmsState = .preparing
        let adapter = FTMSAdapter(ble: ble, peripheralID: id)
        ftmsAdapter = adapter
        Task {
            do {
                appendLog("FTMS: Request Control…")
                try await adapter.prepare()
                ftmsState = .ready
                appendLog("FTMS pronto ✓")
                Task { await self.observeMetrics(adapter.metricsStream) }
            } catch {
                ftmsState = .error(error.localizedDescription)
                appendLog("FTMS errore: \(error)")
            }
        }
    }

    func sendERG() {
        guard let adapter = ftmsAdapter else { return }
        Task {
            do {
                try await adapter.setTargetPower(ergWatts)
                appendLog("ERG → \(ergWatts) W")
            } catch {
                appendLog("ERG errore: \(error)")
            }
        }
    }

    func sendSIM() {
        guard let adapter = ftmsAdapter else { return }
        Task {
            do {
                try await adapter.setSimulation(grade: simGrade, totalWeight: 80)
                appendLog("SIM → pendenza \(String(format: "%.1f", simGrade))%")
            } catch {
                appendLog("SIM errore: \(error)")
            }
        }
    }

    // MARK: - HR actions

    var hasHRService: Bool {
        gattServices.contains(where: { $0.uppercased() == "180D" })
    }

    func prepareBLEHR() {
        guard let id = connectedID else { return }
        hrBLEState = .preparing
        let adapter = BLEHeartRateAdapter(ble: ble, peripheralID: id)
        bleHRAdapter = adapter
        Task {
            do {
                appendLog("HR BLE: discovery…")
                try await adapter.prepare()
                await hrService.addBLEFallback(adapter.samples)
                hrBLEState = .ready
                appendLog("HR BLE pronto ✓ (fallback Watch)")
            } catch {
                hrBLEState = .error(error.localizedDescription)
                appendLog("HR BLE errore: \(error)")
            }
        }
    }

    func stopBLEHR() {
        guard let adapter = bleHRAdapter else { return }
        Task {
            await adapter.disconnect()
            bleHRAdapter = nil
            hrBLEState = .idle
            appendLog("HR BLE fermato")
        }
    }

    func stopFTMS() {
        guard let adapter = ftmsAdapter else { return }
        Task {
            await adapter.disconnect()
            ftmsAdapter = nil
            ftmsState = .idle
            currentMetrics = nil
            appendLog("FTMS fermato")
        }
    }

    // MARK: - Private observation

    // Service UUIDs to scan for — only devices advertising these will appear.
    // 1826 = FTMS (smart trainers), 180D = Heart Rate, 1818 = Cycling Power
    private static let scanServices = ["1826", "180D", "1818"]

    private func observeState() async {
        let stream = await ble.systemStateStream
        for await state in stream {
            systemState = state
            appendLog("BLE: \(state.label)")
            if state == .ready {
                await ble.startScan(for: Self.scanServices)
                appendLog("Scan avviato (FTMS · HR · Power)")
            }
        }
    }

    private func observeDiscovery() async {
        let stream = await ble.discoveredPeripherals
        for await p in stream {
            if !discovered.contains(where: { $0.id == p.id }) {
                discovered.append(p)
                appendLog("Trovato: \(p.name ?? "N/A") — \(p.rssi) dBm")
            } else if let idx = discovered.firstIndex(where: { $0.id == p.id }) {
                discovered[idx] = p
            }
        }
    }

    private func observeMetrics(_ stream: AsyncStream<TrainerMetrics>) async {
        for await metrics in stream {
            currentMetrics = metrics
        }
    }

    private func observeHR() async {
        for await sample in hrService.samples {
            currentHR = sample
        }
    }

    private func observeWatchReachability() async {
        let stream = await watchHRSource.reachabilityStream
        for await reachable in stream {
            watchReachable = reachable
        }
    }

    private func appendLog(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.insert("[\(time)] \(message)", at: 0)
        if log.count > 200 { log.removeLast() }
    }
}

// MARK: - View

struct BLEDebugView: View {
    @State private var vm = BLEDebugViewModel()

    var body: some View {
        NavigationStack {
            List {
                stateSection
                devicesSection
                if !vm.gattServices.isEmpty { servicesSection }
                if vm.connectedID != nil && vm.hasFTMS { ftmsSection }
                hrSection
                logSection
            }
            .navigationTitle("BLE Debug")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Rescan", systemImage: "arrow.clockwise") { vm.restartScan() }
                        .disabled(vm.systemState != .scanning && vm.systemState != .ready)
                }
            }
        }
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
    }

    // MARK: - BLE sections

    private var stateSection: some View {
        Section("Stato Bluetooth") {
            HStack {
                Image(systemName: vm.systemState.icon)
                    .foregroundStyle(vm.systemState.color)
                    .frame(width: 24)
                Text(vm.systemState.label)
                Spacer()
                if vm.systemState == .scanning { ProgressView().scaleEffect(0.8) }
            }
        }
    }

    private var devicesSection: some View {
        Section("Device trovati (\(vm.discovered.count))") {
            if vm.discovered.isEmpty {
                Text("Nessun device trovato. Accendi il FLUX e avvicina il telefono.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(vm.discovered, id: \.id) { p in peripheralRow(p) }
            }
        }
    }

    private func peripheralRow(_ p: DiscoveredPeripheral) -> some View {
        let isConnected = vm.connectedID == p.id
        return Button {
            if isConnected { vm.disconnect() } else { vm.connect(to: p) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isConnected
                      ? "antenna.radiowaves.left.and.right"
                      : "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(isConnected ? .green : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name ?? "Sconosciuto").font(.headline)
                    Text(p.id.uuidString.lowercased()).font(.caption2).foregroundStyle(.secondary)
                    if !p.advertisedServiceUUIDs.isEmpty {
                        Text(p.advertisedServiceUUIDs.map { "0x\($0.uuidString)" }.joined(separator: " "))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(p.rssi) dBm").font(.caption).foregroundStyle(rssiColor(p.rssi))
                    if vm.isConnecting && !isConnected { ProgressView().scaleEffect(0.7) }
                    if isConnected { Text("Connesso").font(.caption2).foregroundStyle(.green) }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var servicesSection: some View {
        Section("GATT Services") {
            ForEach(vm.gattServices, id: \.self) { uuid in
                HStack {
                    Text(uuid.lowercased()).font(.caption).fontDesign(.monospaced)
                    Spacer()
                    if uuid.uppercased() == "1826" {
                        Text("FTMS ✓").font(.caption2).foregroundStyle(.green).bold()
                    }
                }
            }
        }
    }

    // MARK: - FTMS section

    private var ftmsSection: some View {
        Section("FTMS") {
            switch vm.ftmsState {
            case .idle:
                Button("Prepara FTMS (handshake)") { vm.prepareFTMS() }
                    .foregroundStyle(.blue)

            case .preparing:
                HStack {
                    ProgressView()
                    Text("Handshake in corso…").foregroundStyle(.secondary)
                }

            case .error(let msg):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Errore FTMS", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(msg).font(.caption2).foregroundStyle(.secondary)
                    Button("Riprova") { vm.prepareFTMS() }.font(.caption)
                }

            case .ready:
                metricsRow
                ergRow
                simRow
                Button("Stop FTMS", role: .destructive) { vm.stopFTMS() }
                    .font(.callout)
            }
        }
    }

    private var metricsRow: some View {
        VStack(spacing: 8) {
            if let m = vm.currentMetrics {
                HStack(spacing: 0) {
                    metricCell(value: "\(m.powerWatts)", unit: "W", label: "Potenza")
                    Divider().frame(height: 40)
                    metricCell(value: "\(m.cadenceRPM)", unit: "rpm", label: "Cadenza")
                    Divider().frame(height: 40)
                    metricCell(value: String(format: "%.1f", m.speedKmh), unit: "km/h", label: "Velocità")
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("In attesa di telemetria…").foregroundStyle(.secondary).font(.callout)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func metricCell(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.title2).bold().monospacedDigit()
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var ergRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ERG").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(vm.ergWatts) W").font(.caption).monospacedDigit()
            }
            HStack(spacing: 12) {
                Slider(value: Binding(
                    get: { Double(vm.ergWatts) },
                    set: { vm.ergWatts = Int($0) }
                ), in: 50...400, step: 5)
                Button("Invia") { vm.sendERG() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    private var simRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SIM — Pendenza").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f%%", vm.simGrade)).font(.caption).monospacedDigit()
            }
            HStack(spacing: 12) {
                Slider(value: $vm.simGrade, in: -10...20, step: 0.5)
                Button("Invia") { vm.sendSIM() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - HR section

    private var hrSection: some View {
        Section("Frequenza Cardiaca") {
            // Watch status
            HStack(spacing: 10) {
                Image(systemName: "applewatch")
                    .foregroundStyle(vm.watchReachable ? .green : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Watch")
                        .font(.subheadline)
                    Text(vm.watchReachable ? "Raggiungibile" : "Non raggiungibile")
                        .font(.caption2)
                        .foregroundStyle(vm.watchReachable ? .green : .secondary)
                }
                Spacer()
                if let hr = vm.currentHR, hr.source == .appleWatch {
                    hrBadge(bpm: hr.bpm, fresh: Date().timeIntervalSince(hr.timestamp) < 5)
                }
            }

            // Current HR value (any source)
            if let hr = vm.currentHR {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(hr.bpm)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(hrColor(hr.bpm))
                            Text("bpm")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Text("da \(hr.source == .appleWatch ? "Apple Watch" : "Fascia BLE")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "heart.fill")
                        .font(.largeTitle)
                        .foregroundStyle(hrColor(hr.bpm))
                        .symbolEffect(.pulse)
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("In attesa di campioni HR…")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            // BLE HR strap (only when a device with 0x180D is connected)
            if vm.connectedID != nil && vm.hasHRService {
                hrBLESubsection
            }
        }
    }

    @ViewBuilder
    private var hrBLESubsection: some View {
        switch vm.hrBLEState {
        case .idle:
            Button("Prepara HR BLE (Polar/Garmin)") { vm.prepareBLEHR() }
                .foregroundStyle(.blue)
        case .preparing:
            HStack {
                ProgressView()
                Text("Discovery in corso…").foregroundStyle(.secondary)
            }
        case .error(let msg):
            VStack(alignment: .leading, spacing: 4) {
                Label("Errore HR BLE", systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                Text(msg).font(.caption2).foregroundStyle(.secondary)
                Button("Riprova") { vm.prepareBLEHR() }.font(.caption)
            }
        case .ready:
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fascia BLE attiva").font(.subheadline)
                    Text("Usata se Watch silente > 5 s").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if let hr = vm.currentHR, hr.source == .bleChestStrap {
                    hrBadge(bpm: hr.bpm, fresh: Date().timeIntervalSince(hr.timestamp) < 5)
                }
            }
            Button("Stop HR BLE", role: .destructive) { vm.stopBLEHR() }.font(.callout)
        }
    }

    private func hrBadge(bpm: Int, fresh: Bool) -> some View {
        Text("\(bpm)")
            .font(.headline).monospacedDigit()
            .foregroundStyle(fresh ? hrColor(bpm) : .secondary)
    }

    private func hrColor(_ bpm: Int) -> Color {
        switch bpm {
        case ..<100: return .green
        case 100..<140: return .yellow
        case 140..<170: return .orange
        default: return .red
        }
    }

    // MARK: - Log section

    private var logSection: some View {
        Section("Log") {
            if vm.log.isEmpty {
                Text("—").foregroundStyle(.secondary)
            } else {
                ForEach(vm.log.prefix(50), id: \.self) { entry in
                    Text(entry)
                        .font(.caption2).fontDesign(.monospaced).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Helpers

    private func rssiColor(_ rssi: Int) -> Color {
        switch rssi {
        case ..<(-80): return .red
        case (-80)..<(-65): return .orange
        default: return .green
        }
    }
}

// MARK: - BLESystemState display helpers

private extension BLESystemState {
    var label: String {
        switch self {
        case .unknown:      return "Inizializzazione…"
        case .off:          return "Bluetooth spento"
        case .unauthorized: return "Permesso negato"
        case .resetting:    return "Reset in corso"
        case .ready:        return "Pronto"
        case .scanning:     return "Scansione in corso"
        }
    }
    var icon: String {
        switch self {
        case .scanning:              return "antenna.radiowaves.left.and.right"
        case .ready:                 return "checkmark.circle"
        case .off:                   return "bluetooth"
        case .unauthorized:          return "lock.slash"
        case .unknown, .resetting:   return "arrow.clockwise"
        }
    }
    var color: Color {
        switch self {
        case .scanning:              return .blue
        case .ready:                 return .green
        case .unauthorized:          return .red
        case .off:                   return .secondary
        case .unknown, .resetting:   return .orange
        }
    }
}
