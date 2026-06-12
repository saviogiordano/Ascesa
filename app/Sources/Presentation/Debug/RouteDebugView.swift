// DEBUG — rimuovere prima del rilascio
import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - ViewModel

@MainActor
@Observable
final class RouteDebugViewModel {

    // MARK: Import
    var showFilePicker = false
    var parsedPoints: [RoutePoint] = []
    var parsedName: String = ""

    // MARK: Mapper config
    var mapperStepMeters: Double = 15
    var mapperSmoothingMeters: Double = 200

    // MARK: Profile
    var profile: RouteProfile?

    // MARK: Elevation service
    var orsApiKey: String = ""
    var isEnriching = false

    // MARK: Repository
    var savedRoutes: [RouteSummary] = []
    var isSaving = false

    // MARK: Log
    var log: [String] = []

    // MARK: Private
    private let repository = RouteRepository()
    private let parser = GPXParser()

    // MARK: - Computed

    var totalDistanceKm: Double {
        (parsedPoints.last?.distanceMeters ?? 0) / 1_000
    }

    var rawElevationGain: Double {
        var gain = 0.0
        for i in 1..<parsedPoints.count {
            let d = parsedPoints[i].altitudeMeters - parsedPoints[i - 1].altitudeMeters
            if d > 0 { gain += d }
        }
        return gain
    }

    var chartSegments: [RouteProfile.Segment] {
        guard let segs = profile?.segments, !segs.isEmpty else { return [] }
        guard segs.count > 300 else { return segs }
        let stride = segs.count / 300
        return segs.indices.compactMap { $0 % stride == 0 ? segs[$0] : nil }
    }

    // MARK: - Import

    func importGPX(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                let points = try parser.parse(contentsOf: url)
                parsedPoints = points
                parsedName = url.deletingPathExtension().lastPathComponent
                profile = nil
                appendLog("Importato '\(parsedName)': \(points.count) punti, \(String(format: "%.1f", totalDistanceKm)) km, +\(Int(rawElevationGain)) m")
            } catch {
                appendLog("Errore import: \(error.localizedDescription)")
            }
        case .failure(let error):
            appendLog("File picker: \(error.localizedDescription)")
        }
    }

    // MARK: - Mapper

    func buildProfile() {
        guard !parsedPoints.isEmpty else { return }
        let config = RouteToSimulationMapper.Configuration(
            resampleStepMeters: mapperStepMeters,
            smoothingWindowMeters: mapperSmoothingMeters
        )
        let route = Route(id: UUID(), name: parsedName, points: parsedPoints)
        let p = RouteToSimulationMapper(config: config).buildProfile(from: route)
        profile = p
        let grades = p.segments.map(\.gradePercent)
        let minG = grades.min() ?? 0, maxG = grades.max() ?? 0
        let avgG = grades.isEmpty ? 0.0 : grades.reduce(0, +) / Double(grades.count)
        appendLog("Profilo: \(p.segments.count) segmenti @ \(Int(mapperStepMeters)) m, grade min \(String(format: "%.1f", minG))% max \(String(format: "%.1f", maxG))% avg \(String(format: "%.1f", avgG))%")
    }

    // MARK: - Elevation Service

    func enrichElevation() {
        guard !parsedPoints.isEmpty else { return }
        isEnriching = true
        let key = orsApiKey
        let pts = parsedPoints
        Task {
            do {
                let enriched = try await ElevationService(apiKey: key).enrich(points: pts)
                parsedPoints = enriched
                profile = nil
                appendLog("ORS: quote aggiornate su \(enriched.count) punti")
            } catch {
                appendLog("ElevationService errore: \(error.localizedDescription)")
            }
            isEnriching = false
        }
    }

    // MARK: - Repository

    func loadSavedRoutes() {
        Task {
            do {
                savedRoutes = try await repository.search(query: RouteQuery(text: ""))
            } catch {
                appendLog("Repository: \(error.localizedDescription)")
            }
        }
    }

    func saveCurrentRoute() {
        guard !parsedPoints.isEmpty else { return }
        isSaving = true
        let route = Route(
            id: UUID(),
            name: parsedName.isEmpty ? "Percorso senza nome" : parsedName,
            points: parsedPoints
        )
        Task {
            do {
                try await repository.save(route)
                appendLog("Salvato '\(route.name)'")
                loadSavedRoutes()
            } catch {
                appendLog("Salvataggio errore: \(error.localizedDescription)")
            }
            isSaving = false
        }
    }

    func deleteRoute(_ summary: RouteSummary) {
        Task {
            do {
                try await repository.delete(id: summary.id)
                appendLog("Eliminato '\(summary.name)'")
                loadSavedRoutes()
            } catch {
                appendLog("Eliminazione errore: \(error.localizedDescription)")
            }
        }
    }

    func fetchAndLog(_ summary: RouteSummary) {
        Task {
            do {
                let route = try await repository.fetch(id: summary.id)
                appendLog("Fetch '\(route.name)': \(route.points.count) punti, \(String(format: "%.1f", (route.points.last?.distanceMeters ?? 0) / 1000)) km")
            } catch {
                appendLog("Fetch errore: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func appendLog(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.insert("[\(time)] \(message)", at: 0)
        if log.count > 200 { log.removeLast() }
    }
}

// MARK: - View

struct RouteDebugView: View {
    @State private var vm = RouteDebugViewModel()

    var body: some View {
        NavigationStack {
            List {
                importSection
                if !vm.parsedPoints.isEmpty { elevationSection }
                if !vm.parsedPoints.isEmpty { mapperSection }
                if let profile = vm.profile { profileSection(profile) }
                repositorySection
                logSection
            }
            .navigationTitle("Route Debug")
        }
        .fileImporter(
            isPresented: $vm.showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml]
        ) { vm.importGPX(result: $0) }
        .onAppear { vm.loadSavedRoutes() }
    }

    // MARK: - Import

    private var importSection: some View {
        Section("Import GPX") {
            Button {
                vm.showFilePicker = true
            } label: {
                Label("Apri file .gpx…", systemImage: "doc.badge.plus")
            }
            .foregroundStyle(.blue)

            if !vm.parsedPoints.isEmpty {
                statRow("Punti grezzi", "\(vm.parsedPoints.count)")
                statRow("Distanza", String(format: "%.2f km", vm.totalDistanceKm))
                statRow("Dislivello grezzo", String(format: "+%.0f m", vm.rawElevationGain))
                if let first = vm.parsedPoints.first, let last = vm.parsedPoints.last {
                    statRow("Quota inizio / fine",
                            String(format: "%.0f m / %.0f m", first.altitudeMeters, last.altitudeMeters))
                }
            }
        }
    }

    // MARK: - Elevation ORS

    private var elevationSection: some View {
        Section("Elevation ORS") {
            VStack(alignment: .leading, spacing: 6) {
                Text("ORS API Key")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Lascia vuoto per saltare", text: $vm.orsApiKey)
                    .font(.caption).fontDesign(.monospaced)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Button {
                vm.enrichElevation()
            } label: {
                if vm.isEnriching {
                    HStack { ProgressView().scaleEffect(0.8); Text("Arricchimento in corso…") }
                } else {
                    Label("Arricchisci quote (ORS SRTM)", systemImage: "mountain.2")
                }
            }
            .disabled(vm.isEnriching || vm.orsApiKey.isEmpty)
            .foregroundStyle(vm.orsApiKey.isEmpty ? Color.gray : Color.blue)
        }
    }

    // MARK: - Mapper

    private var mapperSection: some View {
        Section("RouteToSimulationMapper") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Passo ricampionamento").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(vm.mapperStepMeters)) m").font(.caption).monospacedDigit()
                }
                Slider(value: $vm.mapperStepMeters, in: 5...50, step: 5)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Finestra smoothing").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(vm.mapperSmoothingMeters)) m").font(.caption).monospacedDigit()
                }
                Slider(value: $vm.mapperSmoothingMeters, in: 50...500, step: 50)
            }
            Button {
                vm.buildProfile()
            } label: {
                Label("Calcola RouteProfile", systemImage: "waveform.path.ecg")
                    .bold()
            }
            .foregroundStyle(Color.amber)
        }
    }

    // MARK: - Profile

    private func profileSection(_ profile: RouteProfile) -> some View {
        let grades = profile.segments.map(\.gradePercent)
        let minG = grades.min() ?? 0
        let maxG = grades.max() ?? 0
        let avgG = grades.isEmpty ? 0.0 : grades.reduce(0, +) / Double(grades.count)

        return Section("RouteProfile") {
            statRow("Segmenti", "\(profile.segments.count)")
            statRow("Distanza totale", String(format: "%.2f km", profile.totalDistanceMeters / 1_000))
            statRow("Dislivello positivo", String(format: "+%.0f m", profile.totalElevationGainMeters))
            statRow("Grade min / max / avg",
                    String(format: "%.1f%% / %.1f%% / %.1f%%", minG, maxG, avgG))

            if !vm.chartSegments.isEmpty {
                gradeChart
            }

            // Test grade(at:) lookup
            gradeLookupRow(profile: profile)
        }
    }

    private var gradeChart: some View {
        Chart {
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.secondary.opacity(0.5))
            ForEach(vm.chartSegments, id: \.distanceMeters) { seg in
                AreaMark(
                    x: .value("km", seg.distanceMeters / 1_000),
                    y: .value("%", seg.gradePercent)
                )
                .foregroundStyle(gradeColor(seg.gradePercent).opacity(0.4))
                LineMark(
                    x: .value("km", seg.distanceMeters / 1_000),
                    y: .value("%", seg.gradePercent)
                )
                .foregroundStyle(gradeColor(seg.gradePercent))
            }
        }
        .chartXAxisLabel("km")
        .chartYAxisLabel("%")
        .chartYScale(domain: -12...22)
        .frame(height: 130)
        .padding(.vertical, 4)
    }

    private func gradeLookupRow(profile: RouteProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Test grade(at:) — lookup a 1/4, 1/2, 3/4 del percorso")
                .font(.caption).foregroundStyle(.secondary)
            let d = profile.totalDistanceMeters
            HStack(spacing: 16) {
                lookupCell(label: "25%", grade: profile.grade(at: d * 0.25))
                lookupCell(label: "50%", grade: profile.grade(at: d * 0.50))
                lookupCell(label: "75%", grade: profile.grade(at: d * 0.75))
            }
        }
        .padding(.vertical, 2)
    }

    private func lookupCell(label: String, grade: Double) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f%%", grade))
                .font(.headline).monospacedDigit()
                .foregroundStyle(gradeColor(grade))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Repository

    private var repositorySection: some View {
        Section("RouteRepository") {
            if !vm.parsedPoints.isEmpty {
                Button {
                    vm.saveCurrentRoute()
                } label: {
                    if vm.isSaving {
                        HStack { ProgressView().scaleEffect(0.8); Text("Salvataggio…") }
                    } else {
                        Label("Salva percorso corrente", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(vm.isSaving)
                .foregroundStyle(.green)
            }

            if vm.savedRoutes.isEmpty {
                Text("Nessun percorso salvato.")
                    .foregroundStyle(.secondary).font(.callout)
            } else {
                ForEach(vm.savedRoutes) { summary in
                    Button { vm.fetchAndLog(summary) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(summary.name).font(.subheadline)
                            HStack(spacing: 12) {
                                Text(String(format: "%.1f km", summary.distanceMeters / 1_000))
                                Text(String(format: "+%.0f m", summary.elevationGainMeters))
                                Text(String(format: "max %.1f%%", summary.gradeMaxPercent))
                            }
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { vm.deleteRoute(summary) } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Log

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

    // MARK: - Helpers

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.callout).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.callout).monospacedDigit()
        }
    }

    private func gradeColor(_ grade: Double) -> Color {
        switch grade {
        case ..<0:    return Color.blue
        case 0..<4:   return Color.green
        case 4..<7:   return Color.yellow
        case 7..<10:  return Color.orange
        default:      return Color.red
        }
    }
}
