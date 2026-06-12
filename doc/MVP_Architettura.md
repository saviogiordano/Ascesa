# Architettura MVP — Ascesa Indoor Trainer

Specifica dei contratti Data→Domain, del flusso dati end-to-end, dello schema SQLite per le time-series e dello schema SwiftData per i metadati. Documento di riferimento per la Fase MVP.

---

## 1. Flusso dati end-to-end

```
╔══════════════════════════════════════════════════════════════════╗
║  HARDWARE / SISTEMA OPERATIVO                                    ║
║  TACX FLUX S ─── BLE ───► CoreBluetooth                         ║
║  Apple Watch ────────────► WCSession / HealthKit                 ║
╚══════════════════╤═══════════════════╤══════════════════════════╝
                   │                   │
                   ▼                   ▼
     ┌─────────────────────┐   ┌───────────────────────┐
     │ BluetoothCentral    │   │  HeartRateService      │
     │ Manager (actor)     │   │  (actor)               │
     │                     │   │  ┌─ Watch (priorità)   │
     │  capability check   │   │  └─ BLE strap (fallback│
     │    ↓           ↓    │   └──────────┬────────────┘
     │ FTMSAdapter TacxAd. │              │ AsyncStream
     └────────┬────────────┘              │ <HeartRateSample>
              │ TrainerControl            │
              │ AsyncStream               │
              │ <TrainerMetrics>          │
              └──────────────┐            │
                             ▼            ▼
              ┌──────────────────────────────────────┐
              │         WorkoutEngine (actor)         │
              │         tick loop 1 Hz                │
              │                                       │
              │  ERG → setTargetPower(_:)             │
              │  SIM → lookup RouteProfile            │
              │        → setSimulation(grade:weight:) │
              │                                       │
              │  emette WorkoutEngineState             │
              └──────────────┬───────────────────────┘
                             │ SessionRecord (1 Hz)
                             ▼
              ┌──────────────────────────────────────┐
              │        SessionRecorder (actor)        │
              │        flush ogni 10 record           │
              └────────┬──────────────────────────────┘
                       │                    │
                       ▼                    ▼
          ┌────────────────────┐  ┌──────────────────────┐
          │  GRDB / SQLite     │  │  SwiftData            │
          │  session_records   │  │  WorkoutSession (meta)│
          │  (1 Hz time-series)│  │  Athlete, Route, Lap  │
          └────────────────────┘  └──────────────────────┘
                       │
                       ▼
          ┌────────────────────┐
          │  ExportService     │
          │  FIT / TCX / GPX   │
          └────────────────────┘
                       │
                       ▼
          HealthKit (HKWorkout + campioni HR/potenza)
```

---

## 2. Protocolli repository — contratti Data → Domain

Il Domain layer conosce solo questi protocolli. Le implementazioni concrete vivono nel layer Data e sono iniettate tramite inizializzatori o environment SwiftUI.

### 2.1 `TrainerRepository`

Gestisce il ciclo di vita BLE del rullo: scan, connessione, esposizione del controllo e del flusso di metriche.

```swift
protocol TrainerRepository: Sendable {
    /// Avvia lo scan e produce le periferiche compatibili trovate.
    func scan() -> AsyncStream<DiscoveredDevice>

    /// Connette la periferica e restituisce l'adapter scelto via capability discovery.
    func connect(to device: DiscoveredDevice) async throws -> any TrainerControl

    /// Stream di metriche emesso dall'adapter connesso (1 Hz).
    var metrics: AsyncStream<TrainerMetrics> { get }

    /// Disconnette e resetta lo stato.
    func disconnect() async
}

struct DiscoveredDevice: Sendable, Identifiable {
    let id: UUID           // periferica CBPeripheral.identifier
    let name: String
    let rssi: Int          // segnale dBm, usato in UI per indicatore qualità
    let supportsftms: Bool
}
```

**Implementazione concreta:** `CoreBluetoothTrainerRepository` (usa `BluetoothCentralManager`).

---

### 2.2 `HeartRateRepository`

Espone la sorgente HR attiva (Watch o fascia BLE) e permette di forzare il fallback.

```swift
protocol HeartRateRepository: Sendable {
    /// La sorgente attualmente attiva, nil se nessuna disponibile.
    var activeSource: (any HeartRateSource)? { get async }

    /// Tipo di sorgente attiva (utile per UI badge).
    var activeSourceKind: HeartRateSourceKind? { get async }

    /// Forza il passaggio alla fascia BLE (ignora Watch se disponibile).
    func forceBleFallback(_ enabled: Bool) async
}
```

**Implementazione concreta:** `HeartRateService` (actor, gestisce Watch via `WCSession` + fascia BLE).

---

### 2.3 `RouteRepository`

CRUD locale per i percorsi importati, più costruzione del `RouteProfile` per la simulazione.

```swift
protocol RouteRepository: Sendable {
    /// Salva un percorso importato (da GPX/FIT/TCX parser).
    func save(_ route: Route) async throws

    /// Carica il percorso grezzo.
    func load(id: RouteID) async throws -> Route

    /// Lista sommaria di tutti i percorsi salvati.
    func loadAll() async throws -> [RouteSummary]

    /// Rimuove percorso e metadati associati.
    func delete(id: RouteID) async throws

    /// Costruisce (o recupera dalla cache) il RouteProfile pronto per la SIM:
    /// ricampionamento, arricchimento quota (ORS), smoothing, clamping.
    func buildProfile(for routeID: RouteID) async throws -> RouteProfile
}
```

**Implementazione concreta:** `LocalRouteRepository` (file system per GPX/FIT grezzo + SwiftData per metadati + cache `RouteProfile` su disco).

---

### 2.4 `PersistenceRepository`

Doppio backend: SwiftData per metadati della sessione, GRDB/SQLite per le time-series a 1 Hz.

```swift
protocol PersistenceRepository: Sendable {
    // ── Sessione (SwiftData) ────────────────────────────────────────
    /// Crea o aggiorna la sessione. Chiamato a inizio sessione.
    func save(session: WorkoutSession) async throws

    /// Marca la sessione come conclusa (imposta endDate).
    func close(sessionID: UUID, endDate: Date) async throws

    /// Lista di tutte le sessioni (ordinate per data decrescente).
    func loadAllSessions() async throws -> [WorkoutSession]

    func loadSession(id: UUID) async throws -> WorkoutSession

    // ── Record time-series (GRDB/SQLite) ────────────────────────────
    /// Aggiunge un record al buffer interno.
    func append(record: SessionRecord) async throws

    /// Scarica il buffer su disco. Chiamato automaticamente ogni 10 record
    /// e alla fine della sessione. Idempotente se il buffer è vuoto.
    func flushPending() async throws

    /// Carica tutti i record di una sessione (per export o summary).
    func loadRecords(sessionID: UUID) async throws -> [SessionRecord]

    // ── Recovery sessione interrotta ────────────────────────────────
    /// Restituisce la sessione più recente senza endDate, se esiste.
    func findIncompleteSession() async throws -> WorkoutSession?
}
```

**Implementazioni concrete:** `SwiftDataSessionStore` + `GRDBRecordStore`, coordinati da `DefaultPersistenceRepository`.

---

### 2.5 `ExportRepository`

Converte i record di una sessione nei formati standard per condivisione e import su Garmin/Strava.

```swift
protocol ExportRepository: Sendable {
    /// Produce un file `.fit` (Activity file con lap e metriche).
    /// Priorità MVP — importabile da Garmin Connect e Strava.
    func exportFIT(session: WorkoutSession,
                   records: [SessionRecord]) async throws -> URL

    /// Produce un file `.tcx` (opzionale, v1+).
    func exportTCX(session: WorkoutSession,
                   records: [SessionRecord]) async throws -> URL

    /// Produce un file `.gpx` con la traccia virtuale (opzionale, v1+).
    func exportGPX(records: [SessionRecord]) async throws -> URL
}
```

**Implementazione concreta:** `FITExporter` (MVP), `TCXExporter` e `GPXExporter` (v1).

---

## 3. Schema SQLite — `session_records`

Gestito da GRDB. Un record per ogni tick del `WorkoutEngine` (frequenza 1 Hz).

### Definizione tabella

```sql
CREATE TABLE session_records (
    id                   TEXT    NOT NULL PRIMARY KEY,  -- UUID string
    session_id           TEXT    NOT NULL,              -- FK → WorkoutSession.id
    timestamp            REAL    NOT NULL,              -- Unix time (secondi)
    power_w              INTEGER NOT NULL,
    cadence_rpm          INTEGER NOT NULL,
    speed_kmh            REAL    NOT NULL,
    distance_m           REAL    NOT NULL,              -- distanza cumulativa da inizio sessione
    hr_bpm               INTEGER,                       -- NULL se sorgente HR non disponibile
    grade_pct            REAL    NOT NULL DEFAULT 0.0,
    virtual_position_m   REAL    NOT NULL DEFAULT 0.0,  -- posizione lungo RouteProfile
    altitude_m           REAL    NOT NULL DEFAULT 0.0,
    lap_index            INTEGER NOT NULL DEFAULT 0
);
```

### Indici

```sql
-- Query primaria: recupero tutti i record di una sessione in ordine cronologico
CREATE INDEX idx_session_records_session_ts
    ON session_records (session_id, timestamp);

-- Query secondaria: recupero ultimo record (per recovery dopo crash)
CREATE INDEX idx_session_records_ts
    ON session_records (timestamp DESC);
```

### Note

| Campo | Dettaglio |
|---|---|
| `id` | UUID generato lato Swift al momento della scrittura |
| `session_id` | Corrisponde a `WorkoutSession.id` in SwiftData — no FK constraint in SQLite per semplicità |
| `timestamp` | `Date.timeIntervalSince1970` — double, precisione al millisecondo |
| `distance_m` | Integrazione velocità a 1 Hz: `distance += speed_kmh / 3.6 * Δt` |
| `virtual_position_m` | Stessa integrazione, usata per lookup su `RouteProfile.segments` |
| `hr_bpm` | `NULL` (non zero) quando HR non disponibile — permette query `WHERE hr_bpm IS NOT NULL` |

---

## 4. Schema SwiftData

Modelli persistenti per metadati e oggetti di dominio a lunga vita. Le classi SwiftData hanno il prefisso `Stored` per evitare conflitti di nome con le struct del Domain layer (es. `WorkoutSession` domain struct vs `StoredWorkoutSession` SwiftData model).

### `StoredAthlete`

```swift
@Model class StoredAthlete {
    @Attribute(.unique) var id: UUID
    var weightKg: Double
    var ftpWatts: Int
    var maxHeartRate: Int
    @Relationship(deleteRule: .cascade) var sessions: [StoredWorkoutSession]
}
```

### `StoredWorkoutSession`

```swift
@Model class StoredWorkoutSession {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    /// Serializzato come stringa: "erg:<watts>", "simulation:<routeID>", "free"
    var modeRaw: String
    var lapCount: Int
    var athlete: StoredAthlete?
    @Relationship(deleteRule: .cascade) var laps: [StoredLap]
}
```

### `StoredRoute`

```swift
@Model class StoredRoute {
    @Attribute(.unique) var id: UUID
    var name: String
    var distanceMeters: Double
    var elevationGainMeters: Double
    var gradeAvgPercent: Double
    var gradeMaxPercent: Double
    /// Percorso relativo del file GPX/FIT/TCX nel documents directory
    var sourceFilePath: String
    /// Percorso del RouteProfile serializzato su disco (cache)
    var profileCachePath: String?
    var importedAt: Date
}
```

### `StoredLap`

```swift
@Model class StoredLap {
    var index: Int
    var startTimestamp: Date
    var endTimestamp: Date?
    /// Distanza percorsa nel lap (m)
    var distanceMeters: Double
    var session: StoredWorkoutSession?
}
```

### Relazioni

```
StoredAthlete  ──(1:N)──► StoredWorkoutSession  ──(1:N)──► StoredLap
StoredRoute     — nessuna relazione diretta con sessioni in MVP —
                  (il routeID è salvato come campo in StoredWorkoutSession.modeRaw)
```

---

## 5. Iniezione delle dipendenze

Le implementazioni concrete vengono costruite all'avvio dell'app e iniettate tramite SwiftUI `Environment` o passate esplicitamente agli attori Domain.

```
AscesaApp (@main)
  └─ AppContainer (struct, costruisce e possiede tutte le dipendenze)
       ├─ TrainerRepository     → CoreBluetoothTrainerRepository
       ├─ HeartRateRepository   → HeartRateService
       ├─ RouteRepository       → LocalRouteRepository
       ├─ PersistenceRepository → DefaultPersistenceRepository
       └─ ExportRepository      → FITExporter
            │
            └─► WorkoutEngine(trainer:heartRate:persistence:)
                    └─► SessionRecorder(persistence:)
```

In fase di test, ogni protocollo può essere sostituito con un mock senza toccare il Domain layer.

---

## 6. Convenzioni critiche

| Regola | Motivazione |
|---|---|
| Il Domain layer **non importa** CoreBluetooth, HealthKit, SwiftData, GRDB | Testabilità senza simulatore; sostituibilità degli adapter |
| Tutti i tipi che attraversano i boundary actor sono `Sendable` | Swift 6 strict concurrency: zero data race |
| `PersistenceRepository.flushPending()` chiamato ogni 10 record e al termine | Sopravvivenza a crash: massimo 10 secondi di dati persi |
| `session_records` scritti con `INSERT OR IGNORE` | Idempotenza in caso di retry dopo crash |
| Nomi SwiftData prefissati `Stored*` | Evita ambiguità con le struct domain dello stesso nome |

---

*Documento creato: 2026-06-10. Fase: MVP — Design / Architettura.*
*Prossimo aggiornamento: al termine della Fase MVP (implementazione completa).*
