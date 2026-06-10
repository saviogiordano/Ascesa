# Specifiche tecniche — Ascesa Indoor Trainer

Documento di riferimento per lo stack tecnologico, la struttura del progetto Xcode e le scelte architetturali già implementate. Aggiornato al completamento della Fase 0 — Setup progetto.

---

## 1. Progetto Xcode

| Proprietà | Valore |
|---|---|
| Nome progetto | `Ascesa` |
| File progetto | `app/Ascesa.xcodeproj` |
| Spec xcodegen | `app/project.yml` |
| Linguaggio | Swift 6 |
| `SWIFT_STRICT_CONCURRENCY` | `complete` |
| `MARKETING_VERSION` | `0.1.0` |

Per rigenerare il progetto dopo modifiche a `project.yml`:
```bash
cd app && xcodegen generate --spec project.yml
```

### Target

| Target | Piattaforma | Deployment Target | Bundle ID |
|---|---|---|---|
| `Ascesa` | iOS | 17.0 | `com.salvatoregiordano.ascesa` |
| `AscesaWatch` | watchOS | 10.0 | `com.salvatoregiordano.ascesa.watchkitapp` |

`AscesaWatch` è embedded nel target `Ascesa` (Embed Watch Content).

> **Azione richiesta:** impostare `DEVELOPMENT_TEAM` con il proprio Apple Developer Team ID in Build Settings di entrambi i target.

---

## 2. Dipendenze Swift Package Manager

| Package | URL | Versione minima | Usato da |
|---|---|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | `https://github.com/groue/GRDB.swift` | `6.0.0` | `Ascesa` (iOS) |
| [CoreGPX](https://github.com/vincentneo/CoreGPX) | `https://github.com/vincentneo/CoreGPX` | `0.9.0` | `Ascesa` (iOS) |

Le dipendenze vengono risolte automaticamente alla prima apertura del progetto in Xcode.

---

## 3. Entitlements e permessi

### iOS (`Resources/iOS/Ascesa.entitlements`)

| Entitlement | Valore |
|---|---|
| `com.apple.developer.healthkit` | `true` |
| `com.apple.developer.healthkit.background-delivery` | `true` |

### watchOS (`Resources/Watch/AscesaWatch.entitlements`)

| Entitlement | Valore |
|---|---|
| `com.apple.developer.healthkit` | `true` |
| `com.apple.developer.healthkit.background-delivery` | `true` |

### Info.plist — iOS

| Chiave | Valore |
|---|---|
| `NSBluetoothAlwaysUsageDescription` | Stringa per permesso BLE (TACX FLUX + fasce cardio) |
| `NSHealthShareUsageDescription` | Lettura HR dall'Apple Watch |
| `NSHealthUpdateUsageDescription` | Salvataggio sessioni in Salute |
| `UIBackgroundModes` | `bluetooth-central` |
| `UISupportedInterfaceOrientations` | `UIInterfaceOrientationPortrait` |

### Info.plist — watchOS

| Chiave | Valore |
|---|---|
| `NSHealthShareUsageDescription` | Lettura HR durante allenamento |
| `NSHealthUpdateUsageDescription` | Salvataggio sessione in Salute |
| `WKBackgroundModes` | `workout-processing` |
| `WKWatchKitApp` | `true` |

---

## 4. Struttura cartelle

```
app/
├── project.yml                        ← spec xcodegen
├── Ascesa.xcodeproj
├── Sources/
│   ├── Presentation/                  ← compilato nel target Ascesa (iOS)
│   │   ├── AscesaApp.swift            ← @main entry point SwiftUI
│   │   ├── ContentView.swift          ← tab bar (Home/Percorsi/Allena/Storico/Profilo)
│   │   └── DesignTokens.swift         ← colori brand, zone, gradeColor()
│   ├── Domain/                        ← compilato nel target Ascesa (iOS)
│   │   ├── TrainerControl.swift       ← protocollo ERG + SIM
│   │   ├── HeartRateSource.swift      ← protocollo stream HR
│   │   ├── RouteProvider.swift        ← protocollo search/fetch percorsi
│   │   ├── TrainingZones.swift        ← enum Zone, PowerZones, HeartRateZones
│   │   └── AthleteProfile.swift       ← FTP, peso, maxHR
│   ├── Data/
│   │   └── BLE/
│   │       └── BluetoothCentralManager.swift  ← stub (MVP)
│   └── Watch/                         ← compilato nel target AscesaWatch
│       ├── AscesaWatchApp.swift        ← @main entry point watchOS
│       └── WatchContentView.swift      ← schermata HR live (placeholder)
└── Resources/
    ├── iOS/
    │   ├── Info.plist                  ← generato da xcodegen
    │   ├── Ascesa.entitlements         ← generato da xcodegen
    │   └── Assets.xcassets/
    │       ├── AccentColor.colorset    ← amber #FFB84D
    │       └── AppIcon.appiconset      ← placeholder 1024×1024
    └── Watch/
        ├── Info.plist
        ├── AscesaWatch.entitlements
        └── Assets.xcassets/
            ├── AccentColor.colorset    ← amber #FFB84D
            └── AppIcon.appiconset
```

---

## 5. Architettura a livelli

```
┌──────────────────────────────────────────────────────────┐
│  PRESENTATION  (Sources/Presentation/)                    │
│  SwiftUI Views · ViewModels (@Observable)                 │
│  DesignTokens · Componenti riusabili                      │
└───────────────────────▲──────────────────────────────────┘
                        │  protocolli only
┌───────────────────────┴──────────────────────────────────┐
│  DOMAIN  (Sources/Domain/)                                │
│  WorkoutEngine · SessionRecorder · MetricsCalculator      │
│  RouteToSimulationMapper · TrainingZones · UseCases       │
│  — zero dipendenze da CoreBluetooth / HealthKit —         │
└───────────────────────▲──────────────────────────────────┘
                        │  protocolli only
┌───────────────────────┴──────────────────────────────────┐
│  DATA / INFRASTRUCTURE  (Sources/Data/)                   │
│  TrainerService (FTMSAdapter, TacxAdapter)                │
│  HeartRateService · RouteRepository · ElevationService    │
│  PersistenceRepository (SwiftData + GRDB/SQLite)          │
│  ExportService · HealthKitGateway                         │
└──────────────────────────────────────────────────────────┘
```

Regola: il layer **Domain non importa mai** CoreBluetooth, HealthKit, SwiftData o qualsiasi framework esterno. Ogni dipendenza è iniettata tramite protocollo.

---

## 6. Protocolli di dominio (fase 0)

### `TrainerControl`
```swift
protocol TrainerControl: Actor {
    func setTargetPower(_ watts: Int) async throws        // ERG mode
    func setSimulation(grade: Double,
                       totalWeight: Double) async throws  // SIM mode
    func disconnect() async
}
```
Implementazioni previste: `FTMSAdapter` (standard FTMS UUID `0x1826`), `TacxAdapter` (protocollo proprietario, fallback). Scelta a runtime via capability discovery.

### `HeartRateSource`
```swift
protocol HeartRateSource: Sendable {
    var samples: AsyncStream<HeartRateSample> { get }
}
```
Sorgenti: Apple Watch via `WCSession` (priorità), fascia BLE Heart Rate Service `0x180D` (fallback).

### `RouteProvider`
```swift
protocol RouteProvider: Sendable {
    func search(query: RouteQuery) async throws -> [RouteSummary]
    func fetch(id: RouteID) async throws -> Route
}
```
Implementazioni previste: `GPXFileProvider`, `OpenRouteServiceProvider`, `StravaProvider` (solo dati personali), `GarminProvider`, `RideWithGPSProvider`.

---

## 7. Modelli di dominio (fase 0)

| Tipo | Descrizione |
|---|---|
| `AthleteProfile` | Peso, FTP, maxHR; calcola `PowerZones` e `HeartRateZones` |
| `Zone` | Enum Z1…Z5 (potenza e HR), con `Comparable` e `Sendable` |
| `PowerZones` | Calcola zona da watt in base a FTP (soglie % standard) |
| `HeartRateZones` | Calcola zona da bpm in base a maxHR |
| `HeartRateSample` | Timestamp + bpm + sorgente (Watch / BLE) |
| `Route` | ID + nome + `[RoutePoint]` (distanza, lat, lon, altitudine) |
| `RouteSummary` | Metadati percorso (km, dislivello, pendenza media/max) |
| `RouteQuery` | Filtri ricerca (testo, distanza max, dislivello max) |

---

## 8. Design tokens

Definiti in `Sources/Presentation/DesignTokens.swift`.

### Colori brand

| Nome | Hex | Uso |
|---|---|---|
| `.indigoBackground` | `#1E2A52` | Sfondo dominante app e dashboard |
| `.indigoMid` | `#2E4288` | Sfondo card secondarie |
| `.amber` | `#FFB84D` | Accento, CTA, tab attivo |

### Zone (potenza e HR)

| Nome | Hex | Zona |
|---|---|---|
| `.zone1` | `#5B8BF5` | Z1 — Recupero attivo |
| `.zone2` | `#4CAF76` | Z2 — Resistenza |
| `.zone3` | `#FFD166` | Z3 — Soglia aerobica |
| `.zone4` | `#F4994A` | Z4 — Soglia lattica |
| `.zone5` | `#E24B4B` | Z5 — VO2max |

### Profilo altimetrico (`Color.gradeColor(for:)`)

| Range pendenza | Colore |
|---|---|
| < 2% | Verde scuro `#8DB48E` — piano |
| 2–4% | Giallo `#FFD166` |
| 4–7% | Arancio `#F4994A` |
| 7–10% | Rosso `#E24B4B` |
| > 10% | Rosso scuro `#9B1C1C` |

L'estensione `Zone.color` mappa i valori di zona al colore corrispondente.

---

## 9. Watch companion app

L'Apple Watch **non espone la HR come servizio BLE standard** (Heart Rate Service). Richiede una companion app watchOS che:

1. Avvia `HKWorkoutSession` (necessario per HR ad alta priorità)
2. Legge HR live via `HKLiveWorkoutBuilder`
3. Invia stream HR all'iPhone via `WCSession.sendMessage(_:replyHandler:)`
4. Riceve comandi start/pause/stop/lap dall'iPhone e aggiorna stato locale
5. Rimane attiva in background con `WKBackgroundModes: workout-processing`

Il bundle ID della Watch app segue la convenzione `{iOS_bundle_id}.watchkitapp`.

---

## 10. Protocollo BLE TACX FLUX

Il FLUX parla **FTMS** (Fitness Machine Service, UUID `0x1826`) su BLE.

| Caratteristica | UUID | Direzione | Uso |
|---|---|---|---|
| Indoor Bike Data | `0x2AD2` | Notify (read) | Potenza W, cadenza rpm, velocità km/h |
| Fitness Machine Control Point | `0x2AD9` | Write | Comandi ERG e SIM |

Comandi FMCP rilevanti:
- `Set Target Power` → **ERG mode**
- `Set Indoor Bike Simulation Parameters` (grade %, wind, Crr, Cw) → **SIM mode**

Alcuni modelli FLUX espongono anche un servizio Tacx proprietario → `TacxAdapter` come fallback. Verificare i GATT services del dispositivo reale con nRF Connect prima di implementare gli adapter.

---

## 11. Persistenza

| Layer | Tecnologia | Cosa contiene |
|---|---|---|
| Modello oggetti | SwiftData | `Athlete`, `WorkoutSession`, `Route`, `Lap` |
| Time-series | GRDB / SQLite | `session_records` — 1 record/sec per sessione (power, HR, cadence, speed, distance, grade, position, altitude) |

I record SQLite sono scritti in modo incrementale (flush ogni ~10 record) per sopravvivere a crash durante la sessione.

---

*Documento aggiornato: 2026-06-10. Fase coperta: 0 — Setup progetto.*
*Prossimo aggiornamento previsto al completamento della Fase MVP.*
