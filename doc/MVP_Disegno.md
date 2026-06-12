# MVP — Dettagli Implementativi

Descrive le decisioni di design interno, i pattern usati e il funzionamento di ciascun modulo implementato nel MVP. È un documento di riferimento per capire il *perché* dietro le scelte, non una lista di API (per quelle basta leggere il codice).

---

## Indice

1. [BLE — BluetoothCentralManager](#1-ble--bluetoothcentralmanager)
2. [TrainerService — FTMSAdapter](#2-trainerservice--ftmsadapter)
3. [HeartRateService](#3-heartRateService)
4. [RouteRepository e parser](#4-routerepository-e-parser)
5. [PersistenceRepository](#5-persistencerepository)
6. [ExportService](#6-exportservice)
7. [Domain — Logica di business](#7-domain--logica-di-business)

---

## 1. BLE — BluetoothCentralManager

**File:** `app/Sources/Data/BLE/BluetoothCentralManager.swift`

### Ruolo

Incapsula tutta la complessità di CoreBluetooth (scan, connect, discovery GATT, notifiche, scritture) e la espone al resto del layer Data con un'API Swift moderna basata su `async/await` e `AsyncStream`. FTMSAdapter e BLEHeartRateAdapter dipendono solo da questa classe; non vedono mai `CBCentralManager` né `CBPeripheral`.

### Problema: CB objects e Swift 6

CoreBluetooth è costruito intorno a NSObject non-Sendable (`CBPeripheral`, `CBService`, `CBCharacteristic`). Con `SWIFT_STRICT_CONCURRENCY = complete` non possono attraversare confini di actor.

**Soluzione — pattern DelegateProxy:**

```
CBCentralManager / CBPeripheral  (thread CB interno)
        │  callback NSObject
        ▼
DelegateProxy  (NSObject, @unchecked Sendable)
        │  estrae dati primitivi (Data, CBUUID, UUID, Int)
        │  prima che il closure lasci il thread CB
        ▼  Task { await actor.handle...() }
BluetoothCentralManager  (actor Swift)
```

`DelegateProxy` è una classe `NSObject, @unchecked Sendable` privata. Ogni closure che assegna (`onStateUpdate`, `onDiscoverPeripheral`, ecc.) è marcata `@Sendable`. La proxy estrae i valori scalari prima di fare il `Task { await self?.handle...() }`, così nessun oggetto CB entra nel Task.

Esempio chiave — `didDiscoverPeripheral`:
```swift
// Nel DelegateProxy (thread CoreBluetooth)
let uuidStrings = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
    .map(\.uuidString)                     // [String] è Sendable
let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String  // String?
onDiscoverPeripheral?(peripheral, uuidStrings, localName, RSSI.intValue)
// CBPeripheral passa solo perché viene immediatamente salvato nell'actor
// (e non attraversa un confine async/await)
```

### Regola fondamentale

I `CBService` e `CBCharacteristic` vivono in cache interne all'actor (`serviceCache`, `characteristicCache`). Tutto ciò che esce verso i caller sono UUID `String` o `CBUUID`. Questo è il motivo per cui `discoverServices` e `discoverCharacteristics` restituiscono `[String]`, non `[CBService]`.

### Operazioni async — CheckedContinuation

Ogni operazione GATT che richiede una risposta asincrona usa `withCheckedThrowingContinuation`:

| Operazione | Dictionary di continuazioni |
|---|---|
| `connect` | `connectionContinuations: [UUID: CC<Void,Error>]` |
| `discoverServices` | `serviceDiscovContinuations: [UUID: CC<[String],Error>]` |
| `discoverCharacteristics` | `charDiscovContinuations: [ServiceKey: CC<[String],Error>]` |
| `write` (withResponse) | `writeContinuations: [CharacteristicKey: CC<Void,Error>]` |

I callback del delegate (già sul thread dell'actor via `Task`) fanno `resume` sulla continuazione corrispondente.

**Timeout connessione:** 30 s. Un `Task` separato (`connectionTimeoutTasks`) fa `cancel` e `resume(throwing: .connectionTimeout)` dopo 30 s. Se la connessione va a buon fine prima, `handleConnected` fa `cancel` sul task di timeout.

### Notifiche — AsyncStream<Data>

`subscribe(toCharacteristic:peripheralID:)` crea un `AsyncStream<Data>` e salva la sua continuation in `notificationContinuations[key]`. `handleValueUpdated` fa `yield` con i dati raw. `unsubscribe` fa `finish` sulla continuation e disabilita le notifiche sul peripheral.

### Auto-reconnect con exponential backoff

`enableAutoReconnect(for:)` aggiunge l'UUID a `autoReconnectIDs`. Alla disconnessione, `scheduleReconnect` avvia un `Task` che aspetta l'intervallo corrente e poi chiama `central.connect`. La sequenza è 3 → 6 → 12 → 24 → 60 → 60 → … secondi.

```swift
private static let backoffIntervals: [UInt64] = [3, 6, 12, 24, 60]
let interval = Self.backoffIntervals[min(attempt, Self.backoffIntervals.count - 1)]
```

`reconnectAttempts[id]` viene azzerato a ogni connessione riuscita.

### Key types interni

`CharacteristicKey` e `ServiceKey` sono struct `Hashable, Sendable` usate come chiavi nei dictionary cache. Permettono di identificare univocamente una caratteristica con `(peripheralID, characteristicUUID)`.

---

## 2. TrainerService — FTMSAdapter

**File:** `app/Sources/Data/Trainer/FTMSAdapter.swift`

### Ruolo

Implementazione concreta di `TrainerControl` per trainer che parlano FTMS (Fitness Machine Service, UUID `0x1826`). Gestisce la sequenza GATT obbligatoria, riceve telemetria da Indoor Bike Data e invia comandi al Control Point.

### UUID FTMS rilevanti

| UUID | Nome | Direzione |
|---|---|---|
| `0x1826` | Fitness Machine Service | — |
| `0x2AD2` | Indoor Bike Data | notify → iPhone |
| `0x2AD9` | Fitness Machine Control Point | write + indicate |

### Sequenza `prepare()`

```
1. discoverServices([0x1826])
2. discoverCharacteristics([0x2AD2, 0x2AD9], serviceUUID: 0x1826)
3. subscribe(to: 0x2AD2)  → Task { consumeMetrics(stream) }
4. subscribe(to: 0x2AD9)  → Task { consumeControlPointResponses(stream) }
5. sendControlCommand(ControlPayload.requestControl(), opCode: 0x00)
   — FTMS mandatory handshake: dichiara che vogliamo prendere controllo
```

### Due livelli di ack per ogni comando

Un comando al Control Point attraversa due livelli di conferma:

```
iPhone                    TACX FLUX
  │─── GATT Write ──────────►│
  │◄── GATT Write Ack ────────│  (livello transport, gestito da BluetoothCentralManager)
  │                           │
  │◄── FTMS Indication ───────│  [0x80, opCode, resultCode]
  │                           │   0x01 = Success, altrimenti errore
```

`sendControlCommand` prima `await ble.write(...)` (aspetta il GATT ack), poi `waitForControlResponse(opCode:)` (aspetta l'FTMS indication).

### Race condition: indication prima della continuation

C'è un edge case: l'FTMS indication può arrivare e venire processata da `consumeControlPointResponses` *prima* che `waitForControlResponse` abbia impostato `pendingControl`. Soluzione: buffer.

```swift
// consumeControlPointResponses:
if let pending = pendingControl, pending.opCode == requestedOpCode {
    pendingControl = nil
    pending.continuation.resume(...)     // caso normale
} else {
    controlResponseBuffer.append(data)   // arrivata troppo presto
}

// waitForControlResponse:
if let idx = controlResponseBuffer.firstIndex(...) {
    let data = controlResponseBuffer.remove(at: idx)
    return try validateResult(data[2], opCode: opCode)  // già in buffer
}
// altrimenti aspetta con CheckedContinuation
```

### IndoorBikeDataParser

Parsifica il payload binario di Indoor Bike Data (`0x2AD2`) seguendo la specifica FTMS §4.9. Il campo flags a 16 bit indica quali campi facoltativi sono presenti. Il parser scorre il payload con un indice `i` che avanza in base ai flag attivi.

Punti chiave:
- **Bit 0 ("More Data") è invertito**: `flags & 0x0001 == 0` significa che la velocità istantanea *è* presente
- **Cadenza**: unità 0.5 rpm/LSB — `cadenceRPM = rawValue / 2`
- **Potenza**: sint16 (con segno), unità 1 W/LSB

### ControlPayload builder

Enum privato con factory methods statici che costruiscono i payload binari in little-endian:

| Metodo | Op Code | Payload |
|---|---|---|
| `requestControl()` | `0x00` | `[0x00]` |
| `setTargetPower(watts)` | `0x05` | `[0x05, sint16 LE]` |
| `setSimulation(grade:)` | `0x11` | `[0x11, wind sint16, grade sint16, crr uint8, cw uint8]` |

Valori di default fisici: Crr = 0.004 (bici da strada), Cw = 0.51 kg/m. `totalWeight` non fa parte del payload FTMS — il trainer calcola la resistenza internamente.

---

## 3. HeartRateService

**File:** `app/Sources/Data/HeartRate/WatchHRSource.swift`  
**File:** `app/Sources/Data/HeartRate/BLEHeartRateAdapter.swift`  
**File:** `app/Sources/Data/HeartRate/HeartRateService.swift`

### Architettura a tre livelli

```
WatchHRSource  ─────────────┐
(WCSession, alta priorità)  │  AsyncStream<HeartRateSample>
                             ▼
                    HeartRateService  (actor, merger)
                             ▲  AsyncStream<HeartRateSample>
BLEHeartRateAdapter ─────────┘
(HR Service 0x180D, fallback)
```

`HeartRateService` implementa il protocollo `HeartRateSource` — è l'unica dipendenza del `WorkoutEngine`.

---

### WatchHRSource

**Pattern:** identico al `DelegateProxy` di `BluetoothCentralManager`, ma per `WCSessionDelegate`.

Il Watch invia un messaggio `["bpm": Int]` via `WCSession.sendMessage` una volta al secondo durante un `HKWorkoutSession` attivo.

**Problema Swift 6 con `[String: Any]`:** `[String: Any]` non è `Sendable`. Non può essere passato in un `Task` direttamente.

**Soluzione in `WCDelegate`:**
```swift
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard let bpm = message["bpm"] as? Int else { return }  // estrae Int (Sendable)
    Task { await self?.handleMessage(bpm: bpm) }            // Task riceve solo Int
}
```

**`sessionDidDeactivate`**: su iOS è obbligatorio riattivare `WCSession.default.activate()` quando il Watch va in handoff. Gestito in `WCDelegate.sessionDidDeactivate`.

Il `WatchHRSource` espone anche `reachabilityStream: AsyncStream<Bool>` che emette quando cambia `session.isReachable` — utile per la UI (mostrare se il Watch è connesso).

---

### BLEHeartRateAdapter

Legge HR da qualsiasi cinghia/fascia BLE che implementa il **Heart Rate Service** (UUID `0x180D`), caratteristica **HR Measurement** (`0x2A37`).

**Lifecycle identico a FTMSAdapter:**
1. `prepare()` — discovery del servizio 0x180D, discovery di 0x2A37, subscribe a notifiche
2. `consumeMeasurements()` — loop su `AsyncStream<Data>`, parsifica ogni notifica

**HRMeasurementParser** — specifica BT §3.110:

Il byte 0 è un campo di flag. Bit 0 indica il formato del valore HR:
- `0` → HR è `uint8` (byte 1)
- `1` → HR è `uint16` little-endian (byte 1–2)

La maggior parte delle cinghie consumer usa uint8, ma la specifica permette entrambi.

---

### HeartRateService

Actor che implementa la **policy di priorità**: il Watch ha sempre la precedenza; la cinghia BLE è usata solo se il Watch non ha inviato campioni negli ultimi 5 secondi.

```swift
private func consumeBLE(_ stream: AsyncStream<HeartRateSample>) async {
    for await sample in stream {
        let watchActive = lastWatchSampleDate.map {
            Date().timeIntervalSince($0) < Self.watchTimeout  // 5 s
        } ?? false
        guard !watchActive else { continue }
        samplesContinuation.yield(sample)
    }
}
```

`configure(watchSamples:)` e `addBLEFallback(_:)` avviano `Task` separati per consumare i rispettivi stream. Entrambi scrivono sulla stessa `samplesContinuation`, ma `lastWatchSampleDate` (protetto dall'actor) garantisce che non ci siano duplicati nei 5 s successivi a un campione Watch.

**Transition trasparente:** se il Watch perde la connessione, dopo 5 s i campioni BLE iniziano a fluire senza che il `WorkoutEngine` debba fare nulla.

---

## 4. RouteRepository e parser

**File:** `app/Sources/Data/Route/GPXParser.swift`  
**File:** `app/Sources/Data/Route/ElevationService.swift`  
**File:** `app/Sources/Data/Route/RouteRepository.swift`  
**File:** `app/Sources/Domain/RouteToSimulationMapper.swift`

### Pipeline completa

```
File GPX/FIT/TCX
      │
      ▼ GPXParser
[RoutePoint] (lat, lon, ele, distAccum)
      │
      ▼ ElevationService (opzionale)
[RoutePoint] con elevazione corretta da SRTM
      │
      ▼ RouteRepository.save(_:)
routes/<uuid>.json + routes/index.json
      │
      ▼ RouteToSimulationMapper.buildProfile(from:)
RouteProfile [SimulationSegment] (distanceMeters, gradePercent)
      │
      ▼ WorkoutEngine.grade(at: virtualPosition)
setSimulation(grade:totalWeight:) → TACX FLUX
```

---

### GPXParser

Usa il pacchetto SPM `CoreGPX`. Il costruttore è **failable**: `CoreGPX.GPXParser(withURL: url)?` può restituire `nil` per file malformati.

```swift
guard let root = CoreGPX.GPXParser(withURL: url)?.parsedData() else {
    throw ParserError.invalidFile
}
```

**Strategia di estrazione punti:** cerca prima i track points (`<trkseg>/<trkpt>`), poi cade back sui waypoints (`<wpt>`). La distanza accumulata è calcolata con haversine incrementale.

Errori: `invalidFile` (parser nil o file non leggibile), `emptyTrack` (nessun punto trovato).

---

### ElevationService

**Motivazione:** l'elevazione GPS raw è rumorosa (±10–20 m). OpenRouteService usa dati SRTM (Shuttle Radar Topography Mission) molto più precisi. Il servizio è no-op se `apiKey.isEmpty`, così l'app funziona in sviluppo senza credenziali.

**Chiamata API:** POST `https://api.openrouteservice.org/elevation/line` con GeoJSON LineString.

**Batching:** massimo 500 coordinate per richiesta (limite ORS). Route lunghe vengono spezzate e i batch vengono assemblati.

**Validazione:** il response body contiene un array di coordinate. Il parser verifica che `response.geometry.coordinates.count == request.count` — se non corrispondono, `throw .countMismatch` per evitare di applicare elevazioni sfasate.

**Codable interno:** usato per de/serializzare il payload, senza `JSONSerialization`/`Any`.

---

### RouteRepository

Actor che implementa `RouteProvider`. Storage: file JSON su disco.

**Layout su disco:**
```
Application Support/
  routes/
    index.json              ← [RouteID: RouteSummary]
    <uuid>.json             ← Route completa (incluso RouteProfile cache)
```

**Index cache:** `indexCache: [RouteID: RouteSummary]?` è un optional lazy. Viene caricato la prima volta che `search` viene chiamato. Viene invalidato su `save` e `delete`. Questo evita di leggere il file indice a ogni query.

**`search(query:)`** è case-insensitive: confronta `query.lowercased()` con il nome della route.

**`RouteSummary`** viene calcolata dalla `Route` dentro il layer Data — il Domain non conosce come farlo.

---

### RouteToSimulationMapper

`struct` Sendable (nessuno stato mutabile). Parametri di configurazione in `Configuration`:

| Parametro | Default | Significato |
|---|---|---|
| `stepMeters` | 15 m | Passo del ricampionamento |
| `smoothingWindowMeters` | 200 m | Finestra media mobile |
| `minGradePercent` | −10% | Clamping FLUX |
| `maxGradePercent` | +20% | Clamping FLUX |

**1. Ricampionamento (`resample`):** interpola linearmente tra i punti della route ogni `stepMeters`. Usa binary search (`partition`) per trovare il segmento corrente in O(log n).

**2. Pendenza (`calculateGrades`):** differenza centrale per i punti intermedi, forward/backward agli estremi:
```
grade[i] = (elevation[i+1] − elevation[i−1]) / (2 × stepMeters) × 100
```

**3. Smoothing (`smoothGrades`):** media mobile su finestra di ampiezza `smoothingWindowMeters / stepMeters`. Implementazione con indice finestra che scorre, complessità O(n·w) ma w è costante.

**4. Clamping:** `max(min, min(max, grade))` — rispetta i limiti fisici del FLUX.

**Lookup durante il ride:**
```swift
func grade(at virtualPositionMeters: Double) -> Double  // su RouteProfile
```
Binary search sull'array di segmenti. Il commento nel codice suggerisce il pattern di compensazione del lag del trainer: `grade(at: pos + speed * 0.5)` per anticipare di mezzo secondo la resistenza.

---

## 5. PersistenceRepository

**File:** `app/Sources/Domain/PersistenceRepository.swift` (protocollo)  
**File:** `app/Sources/Data/Persistence/StoredModels.swift`  
**File:** `app/Sources/Data/Persistence/SessionRecordRow.swift`  
**File:** `app/Sources/Data/Persistence/SwiftDataSessionStore.swift`  
**File:** `app/Sources/Data/Persistence/DefaultPersistenceRepository.swift`

### Motivazione dual-backend

I metadati di sessione (`WorkoutSession`, `Athlete`, `Lap`) sono pochi record con relazioni — SwiftData è ideale. Le time-series a 1 Hz possono arrivare a milioni di righe per molte sessioni — SQLite via GRDB è più efficiente di SwiftData per bulk insert e query di range.

```
WorkoutEngine / SessionRecorder
        │  dipende solo dal protocollo PersistenceRepository
        ▼
DefaultPersistenceRepository (actor)
        ├── SwiftDataSessionStore (@ModelActor) ← metadati
        └── DatabaseQueue (GRDB)               ← time-series
```

---

### StoredModels

Quattro `@Model` SwiftData, tutti con `@Attribute(.unique)` sull'id:

- `StoredAthlete` → relazione 1:N con `StoredWorkoutSession` (cascade delete)
- `StoredWorkoutSession` → relazione 1:N con `StoredLap` (cascade delete); `endDate?` nullable
- `StoredRoute` → metadata route + path file GPX + path cache profilo
- `StoredLap` → index, startTimestamp, endTimestamp?, distanceMeters

**Serializzazione `WorkoutMode`** via `rawValue: String`:
- `.erg(targetWatts: 200)` → `"erg:200"`
- `.simulation(routeID: uuid)` → `"simulation:550e8400-..."`
- `.free` → `"free"`

L'`init?(rawValue:)` è failable — se il formato è corrotto, `WorkoutSession(from:)` restituisce `nil` e la sessione viene scartata silenziosamente da `compactMap`.

`AthleteProfile.placeholder` è usato quando `StoredWorkoutSession.athlete == nil` (edge case recovery).

---

### SessionRecordRow

Struct `Codable, FetchableRecord, PersistableRecord`. GRDB sintetizza automaticamente le query SQL da `Codable` + `CodingKeys`.

**Problema:** `init(from decoder: Decoder)` viene già sintetizzato da `Decodable`. Un secondo `init(from stored: SessionRecord)` causerebbe conflitto di firma.

**Soluzione:** il custom initializer non ha label esterno:
```swift
init(_ record: SessionRecord)  // non "init(from record:)"
```

`CodingKeys` mappano camelCase Swift → snake_case SQL:
```swift
case sessionID = "session_id"
case powerW    = "power_w"
// ecc.
```

---

### SwiftDataSessionStore

`@ModelActor actor` — macro che crea un serial executor dedicato e un `modelContext` isolato. Tutti i `@Model` restano confinati in questo actor; i metodi pubblici accettano e restituiscono solo tipi Sendable (UUID, Date, struct Domain).

**`findIncompleteSession`:** intenzionalmente non usa `#Predicate { $0.endDate == nil }`. Il predicato nil di SwiftData su iOS 17 ha edge case non documentati. Si fetcha tutto e si filtra in Swift:
```swift
let all = try modelContext.fetch(descriptor)
return all.first { $0.endDate == nil }.flatMap { WorkoutSession(from: $0) }
```

**`findOrCreateAthlete`:** fetcha tutti gli atleti e fa match su `(weightKg, ftpWatts, maxHeartRate)`. Se non trovato, ne crea uno nuovo. Previene duplicati negli aggiornamenti frequenti del profilo atleta.

---

### DefaultPersistenceRepository

Actor coordinatore. Tre factory:

| Factory | Uso |
|---|---|
| `make()` | Produzione — SwiftData in Application Support + `ascesa.sqlite` |
| `make(modelContainer:)` | Iniezione — app possiede già un `ModelContainer` |
| `makeInMemory()` | Test — SwiftData in-memory + `DatabaseQueue()` senza path |

**Buffer e flush automatico:**
```swift
func append(record: SessionRecord) async throws {
    pending.append(record)
    if pending.count >= Self.flushThreshold {  // 10
        try await flushPending()
    }
}
```

**Idempotenza del flush** — garanzia crash-safety:
```swift
func flushPending() async throws {
    guard !pending.isEmpty else { return }
    let rows = pending.map { SessionRecordRow($0) }
    pending.removeAll()                          // svuota prima dell'await
    try await dbQueue.write { db in
        for row in rows {
            try row.insert(db, onConflict: .ignore)   // INSERT OR IGNORE
        }
    }
}
```

Il buffer viene svuotato *prima* dell'`await`. Se l'app crasha durante l'`await`, i record sono persi (max 9, ≤9 secondi di dati), ma le righe già su disco non vengono duplicate al riavvio grazie a `INSERT OR IGNORE` sulla primary key.

### Schema SQLite (migrazione v1)

```sql
CREATE TABLE session_records (
    id                TEXT NOT NULL PRIMARY KEY,
    session_id        TEXT NOT NULL,
    timestamp         REAL NOT NULL,
    power_w           INTEGER NOT NULL,
    cadence_rpm       INTEGER NOT NULL,
    speed_kmh         REAL NOT NULL,
    distance_m        REAL NOT NULL,
    hr_bpm            INTEGER,          -- nullable
    grade_pct         REAL NOT NULL DEFAULT 0.0,
    virtual_position_m REAL NOT NULL DEFAULT 0.0,
    altitude_m        REAL NOT NULL DEFAULT 0.0,
    lap_index         INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_session_records_session_ts ON session_records (session_id, timestamp);
CREATE INDEX idx_session_records_ts ON session_records (timestamp);
```

L'indice composto `(session_id, timestamp)` copre la query più frequente: tutti i record di una sessione in ordine cronologico. L'indice su `timestamp` solo serve per il crash recovery (trovare l'ultimo record scritto).

Le migrazioni sono gestite da `DatabaseMigrator` di GRDB, che esegue ogni migration block esattamente una volta e tiene traccia in una tabella interna `grdb_migrations`.

---

## 6. ExportService

**File protocollo:** `app/Sources/Domain/ExportRepository.swift`  
**File implementazione:** `app/Sources/Data/Export/ExportService.swift`  
**Encoders:** `FITExporter.swift` · `HealthKitExporter.swift` · `TCXExporter.swift` · `GPXExporter.swift`

### Ruolo

Converte una sessione completata (metadati `WorkoutSession` + time-series `[SessionRecord]`) in formati di file standard:

| Formato | Uso principale | Priorità |
|---------|----------------|----------|
| `.fit`  | Import Garmin Connect, Strava, Training Peaks | 🔴 Critico |
| HealthKit | App Salute, Fitness, terze parti su iOS | 🔴 Critico |
| `.tcx`  | Garmin Training Center, Wahoo | 🟡 Nice-to-have |
| `.gpx`  | Visualizzazione mappe, import generico | 🟡 Nice-to-have |

### Architettura

```
ExportService (actor)
        ├── FITExporter (struct puro) → Data → file .fit
        ├── HealthKitExporter (@MainActor enum) → HKWorkout + samples
        ├── TCXExporter (struct puro) → Data → file .tcx
        └── GPXExporter (struct puro) → Data → file .gpx
```

`ExportService` è un `actor` sottile che:
1. Esegue l'encoding (puro, sincrono) sul proprio executor
2. Delega il salvataggio HealthKit a `@MainActor` tramite `await HealthKitExporter.save(...)`
3. Scrive i file nella directory temporanea con `.atomic` write

I file temporanei vengono restituiti come `URL` al chiamante, che è responsabile di consumarli o spostarli (es. via `UIActivityViewController`).

---

### FITExporter

**Protocollo di riferimento:** Garmin FIT SDK 21.141

#### Struttura del file FIT

```
File Header (14 byte)
  [0]    = 14  (dimensione header)
  [1]    = 0x10  (protocol version 1.0)
  [2-3]  = 0x54 0x08  (profile version 2132, LE)
  [4-7]  = data_size (uint32 LE, esclusi header e CRC finale)
  [8-11] = ".FIT"  (0x2E 0x46 0x49 0x54)
  [12-13] = CRC-16 dei primi 12 byte

Data Records
  Alternanza: Definition Message → Data Message(s)

File CRC (2 byte)
  CRC-16 di header + data records
```

#### Record header byte

```
Normal Header:
  Bit 7 = 0  (Normal, non compressed)
  Bit 6 = 0
  Bit 5 = 1  (Definition Message) | 0 (Data Message)
  Bit 4 = 0  (no Developer Data)
  Bit 3-0 = Local Message Type (0–15)
```

Esempi: Definition per local 0 → `0x40`, Data per local 0 → `0x00`.

#### Sequenza messaggi nell'Activity file

| Ordine | Messaggio | Global mesg_num | Local |
|--------|-----------|-----------------|-------|
| 1 | file_id | 0 | 0 |
| 2 | event (start) | 21 | 1 |
| 3…N+2 | record (1 per SessionRecord) | 20 | 2 |
| N+3 | event (stop_all) | 21 | 1 |
| N+4…N+3+M | lap (1 per lapIndex group) | 19 | 3 |
| N+4+M | session | 18 | 4 |
| N+5+M | activity | 34 | 5 |

#### Epoch e scaling dei campi

- **FIT epoch offset:** Unix timestamp 631 065 600 = Dec 31 1989 00:00:00 UTC.  
  `fitTimestamp = unixTimestamp - 631_065_600`
- **speed** (campo 6 del record): `raw = speedKmh / 3.6 * 1000` (mm/s, uint16)
- **distance** (campo 5): `raw = distanceMeters * 100` (cm, uint32)
- **altitude** (campo 2): `raw = (altitudeMeters + 500) * 5` (uint16; range −500…+12707 m)
- **total_elapsed_time** (session/lap campo 7): `raw = seconds * 1000` (ms, uint32)

#### CRC-16 (nibble lookup, da FIT SDK)

```swift
let crcTable: [UInt16] = [
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
]
// Per ogni byte: applica due passaggi nibble (basso, poi alto).
```

Lo stesso algoritmo copre sia il CRC dell'header (primi 12 byte) sia il CRC finale (header + data).

#### Gestione lap

`lapGroups(_:)` raggruppa i record per sequenze consecutive di `lapIndex` uguale. Ogni gruppo diventa un `<lap>` FIT. L'ultimo lap ha `lap_trigger = 7` (session_end); i precedenti `lap_trigger = 0` (manual).

#### Valori "invalid"

| Campo | Tipo | Invalid value |
|-------|------|---------------|
| heart_rate | uint8 | `0xFF` |
| avg_heart_rate | uint8 | `0xFF` |
| max_heart_rate | uint8 | `0xFF` |

Se nessun record nella sessione ha `heartRateBPM`, `avgHR` e `maxHR` vengono scritti come `0xFF` (parser FIT lo interpreta come "assente").

---

### HealthKitExporter

Confinato a `@MainActor` (stesso pattern di `WatchWorkoutManager`) per evitare problemi Swift 6 con `HKHealthStore` e `HKWorkoutBuilder` non-Sendable.

#### Flusso

```
HKWorkoutBuilder.beginCollection(at: startDate)
        │
        ▼  HKQuantitySample×N per cyclingPower (iOS 17+)
        │  HKQuantitySample×N per heartRate (se disponibile)
        ▼
builder.endCollection(at: endDate)
builder.finishWorkout()  → salva workout + campioni in un'unica transazione
```

`addSamples(_:)` su `HKWorkoutBuilder` ha solo API con callback; viene ponticellato ad `async throws` con `withCheckedThrowingContinuation`.

#### Autorizzazione

`requestAuthorization(toShare:read:)` viene chiamato prima di ogni export. Su iOS, HealthKit mostra il pannello di consenso solo la prima volta; le chiamate successive sono istantanee. Se l'utente nega, il metodo rilancia `ExportError.healthKitNotAuthorized`.

---

### TCXExporter

Genera XML conforme a **Training Center Database v2** con estensione **ActivityExtension v2** per potenza.

**Struttura:**
```
TrainingCenterDatabase
  Activities
    Activity Sport="Biking"
      Id (timestamp inizio sessione, ISO 8601)
      Lap×M (uno per lapIndex)
        TotalTimeSeconds / DistanceMeters / Calories
        AverageHeartRateBpm / MaximumHeartRateBpm (se disponibili)
        Track
          Trackpoint×N
            Time / AltitudeMeters / DistanceMeters
            HeartRateBpm (se disponibile)
            Cadence
            Extensions > AX2:TPX > Speed + Watts
        Extensions > AX2:LX > MaxBikeCadence + AvgWatts + MaxWatts
```

Le calorie per lap sono calcolate dalla potenza meccanica: `kJ = Σ(powerWatts) × ΔT / 1000`, poi `kcal = kJ / 4.184`.

---

### GPXExporter

Genera GPX 1.1 con estensioni **Garmin TrackPointExtension v1** (HR + cadenza).

**Nota indoor:** lat/lon sono fissi a `0.0` — la sessione indoor non ha coordinate GPS reali. Il dato rilevante è l'elevazione (dal profilo virtuale del percorso), HR e cadenza. Il nome della traccia riflette la modalità (ERG / SIM / Free Ride).

**Escaping XML:** i 5 caratteri speciali XML (`& < > " '`) nel nome della traccia vengono escapati.

---

## 7. Domain — Logica di business

**File principali:**
- `app/Sources/Domain/MetricsCalculator.swift`
- `app/Sources/Domain/SessionRecorder.swift`
- `app/Sources/Domain/WorkoutEngine.swift`
- `app/Sources/Domain/WorkoutUseCases.swift`
- `app/Sources/Domain/TrainerControl.swift` (aggiunto `prepare()`)
- `app/Sources/Domain/RouteProvider.swift` (aggiunti `MutableRouteProvider`, `RouteFileImporter`)
- `app/Sources/Domain/RouteToSimulationMapper.swift` (aggiunta `altitude(at:)`)

---

### 7.1 MetricsCalculator

`MetricsCalculator` è un `struct Sendable` aggiornato a 1 Hz da `WorkoutEngine`. Tutta la matematica è O(1) per tick grazie a finestre scorrevoli.

#### Metriche calcolate

| Metrica | Formula | Finestra |
|---|---|---|
| `averagePower` | Σ power / n tick | globale |
| `rollingPower3s` | media mobile potenza | 3 s |
| `normalizedPower` | ⁴√(media(30 s avg⁴)) | 30 s scorrevole |
| `totalKilojoules` | Σ power × 1 s / 1000 | globale |
| `calories` | kJ / 4.0 | FIT convention |
| `distanceMeters` | Σ(speed km/h) / 3.6 | globale (integr. velocità) |
| `intensityFactor` | NP / FTP | — |
| `tss` | (sec × NP × IF) / (FTP × 3600) × 100 | — |
| `eta` | distanza rimanente / velocità media | — |

#### Normalized Power — dettagli implementativi

NP richiede di mantenere in accumulo la somma dei termini `(media_30s)^4`. Ogni tick:
1. Si aggiunge il nuovo valore alla finestra da 30 elementi
2. Quando la finestra è piena (30 tick = 30 s), si calcola `avg = sum30 / 30` e si accumula `npSum4 += avg^4`
3. `normalizedPower = ⁴√(npSum4 / npCount)`

Questo evita di ricalcolare ogni volta l'intera storia, mantenendo complessità O(1).

---

### 7.2 SessionRecorder

`SessionRecorder` è un `struct Sendable` (non actor): tutte le chiamate arrivano già serializzate dall'isolamento di `WorkoutEngine`.

```
WorkoutEngine (actor)
    └── recorder.append(record:)  → persistence.append(record:)
    └── recorder.flush()          → persistence.flushPending()
```

La delega è intenzionalmente sottile: il buffering e la soglia di flush automatico (ogni 10 record) vivono nel `DefaultPersistenceRepository`.

---

### 7.3 WorkoutEngine

`WorkoutEngine` è l'actor centrale della sessione.

#### State machine

```
idle ──start()──► connecting ──session saved──► active
                                                  │  ▲
                                             pause()  resume()
                                                  ▼  │
                                                paused
                                                  │
                                             finish()
                                                  ▼
                                             finishing ──► finished
```

Auto-pause: 3 tick consecutivi con `speedKmh < 1.0` → `pause()` automatico.

#### Tick loop (1 Hz)

```swift
tickTask = Task {
    var next = ContinuousClock.now + .seconds(1)
    while !Task.isCancelled {
        try? await Task.sleep(until: next, clock: .continuous)
        await tick()
        next += .seconds(1)
    }
}
```

`ContinuousClock` garantisce un intervallo reale di 1 s indipendente dal clock di sistema. La sospensione al `try? await Task.sleep` libera l'executor dell'actor per altre chiamate.

#### Sequenza per tick

```
1. Leggi latestTrainerMetrics (aggiornato dal metricsTask in background)
2. Calcola grade at (currentDist + speed × 0.5 s)  ← lag compensation
3. Invia comando al trainer (ERG: setTargetPower / SIM: setSimulation / free: nop)
4. Controlla auto-pause
5. metricsCalc.addTick(power:speedKmh:)  ← avanza distanza
6. Costruisci SessionRecord con i valori post-tick
7. recorder.append(record:)  ← persiste su SQLite
8. snapshotsCont.yield(...)  ← aggiorna ViewModel
```

#### Lag compensation (modalità SIM)

Il trainer TACX FLUX impiega ~0.5–1 s per modificare la resistenza meccanica. Per evitare che il corridore senta la resistenza troppo tardi, il grade viene letto in anticipo:

```swift
let laggedDist = currentDist + (tm.speedKmh / 3.6) * 0.5
gradeNow = profile.grade(at: laggedDist)
```

#### Monitoring tasks

Vengono creati due `Task` persistenti per la durata della sessione:
- `metricsTask`: `for await tm in trainer.metricsStream` → aggiorna `latestTrainerMetrics`
- `hrTask`: `for await sample in hrSource.samples` → aggiorna `latestHR`

Entrambi vengono cancellati in `finish()`. L'isolamento actor è preservato perché i Task creati dentro un actor method ereditano l'executor dell'actor.

#### WorkoutSnapshot

Emesso ogni tick via `nonisolated let snapshots: AsyncStream<WorkoutSnapshot>`. Contiene una copia value-type di `MetricsCalculator` così il ViewModel legge i dati senza mai aspettare l'actor.

---

### 7.4 Protocolli estesi

#### `TrainerControl.prepare()`

Aggiunto per consentire all'`StartSessionUseCase` di fare il BLE handshake prima di avviare il loop:

```swift
protocol TrainerControl: Actor {
    func prepare() async throws  // ← nuovo
    func setTargetPower(_ watts: Int) async throws
    func setSimulation(grade: Double, totalWeight: Double) async throws
    func disconnect() async
    nonisolated var metricsStream: AsyncStream<TrainerMetrics> { get }
}
```

#### `MutableRouteProvider`

Estende `RouteProvider` con le operazioni di scrittura. `RouteRepository` ora conforma a questo protocollo (non più solo a `RouteProvider`):

```swift
protocol MutableRouteProvider: RouteProvider {
    func save(_ route: Route) async throws
    func delete(id: RouteID) async throws
}
```

#### `RouteFileImporter`

Astrazioni per il parsing di file nel Domain, implementate nel layer Data da `GPXParser` + `ElevationService`:

```swift
protocol RouteFileImporter: Sendable {
    func importPoints(from url: URL) async throws -> (name: String, points: [RoutePoint])
    func enrichElevation(_ points: [RoutePoint]) async throws -> [RoutePoint]
}
```

#### `RouteProfile.altitude(at:)`

Interpolazione lineare dell'altitudine speculare a `grade(at:)`, usata da `WorkoutEngine.tick()` per il campo `altitudeMeters` di ogni `SessionRecord`.

---

### 7.5 UseCases

#### StartSessionUseCase

```
trainer.prepare()                 ← FTMS handshake BLE
engine.start(trainer:hrSource:...)← wiring + salva header sessione + avvia tick
```

#### PauseResumeSessionUseCase

Delega sottile: `pause()`, `resume()`, `markLap()` → `WorkoutEngine`.

#### FinishAndExportSessionUseCase

```
engine.finish()                   → WorkoutSession completata
persistence.loadRecords(sessionID:)→ [SessionRecord]
export.exportFIT(...)             → URL file .fit
export.saveToHealthKit(...)        → best-effort (errore ignorato)
return fitURL
```

#### ImportRouteUseCase

```
importer.importPoints(from:)      → [RoutePoint] grezzi
importer.enrichElevation(_:)      → [RoutePoint] arricchiti (OpenElevation)
mapper.buildProfile(from:)        → RouteProfile (resample → smooth → clamp)
repository.save(route)            → persiste JSON + aggiorna indice
return (route, profile)
```

La separazione `RouteFileImporter` ↔ `ImportRouteUseCase` consente di testare la business logic del mapper con punti di test sintetici senza dover parsare file reali.
