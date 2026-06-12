# Piano di sviluppo — Ascesa Indoor Trainer

Piano completo di progettazione, sviluppo e test dell'app iOS/watchOS per allenamenti indoor con TACX FLUX e Apple Watch. Organizzato per fasi rilasciabili in modo incrementale.

---

## Indice

1. [Legenda e convenzioni](#legenda)
2. [Fase 0 — Setup progetto](#fase-0)
3. [Fase MVP — "Pedalo e registro"](#fase-mvp)
4. [Fase v1 — Esperienza completa](#fase-v1)
5. [Fase v2 — Ricchezza e integrazioni](#fase-v2)
6. [Fase v3 — Multi-utente coach/atleta](#fase-v3)
7. [Task trasversali](#trasversali)
8. [Matrice dipendenze critiche](#dipendenze)

---

## Legenda e convenzioni {#legenda}

- `[ ]` — task da completare
- `[x]` — task completato
- Stima indicativa: **S** = 1–2 gg, **M** = 3–5 gg, **L** = 1–2 sett, **XL** = 2–4 sett
- **🔴 Critico** — blocca tutto ciò che viene dopo
- **🟠 Alto** — blocca una funzionalità chiave
- **🟡 Medio** — migliora l'esperienza, non blocca
- **🟢 Basso** — nice-to-have, rimandabile

Prerequisiti di fase indicati con `→ richiede: [task]`.

---

## Fase 0 — Setup progetto {#fase-0}

**Goal:** repository pronto, architettura scaffoldata, toolchain funzionante.
**Stima:** ~1 settimana.

### 0.1 Setup Xcode e piattaforme

- [ ] 🔴 Crea progetto Xcode con target: **iOS App** + **watchOS App** + **watchOS Extension** — S
- [ ] 🔴 Configura Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`) — S
- [ ] 🔴 Configura Bundle ID, Team, code signing e provisioning profiles (Development) — S
- [ ] 🔴 Aggiungi entitlements: HealthKit, CoreBluetooth (sempre-in-uso), WatchConnectivity, HealthKitOnWatchOS — S
- [ ] 🟠 Configura Swift Package Manager: dipendenze iniziali (GRDB, CoreGPX) — S
- [ ] 🟠 Imposta struttura cartelle per layer: `Sources/{Presentation,Domain,Data,Watch}` — S
- [ ] 🟡 Configura Xcode Cloud o GitHub Actions: build + test automatici su ogni PR — M

### 0.2 Design System

- [ ] 🔴 Crea `DesignTokens.swift`: colori (`#1E2A52`, `#2E4288`, `#FFB84D`), tipografia, spaziature — S
- [ ] 🔴 Crea `ZoneColors.swift`: palette 5 zone potenza/HR (blu → verde → giallo → arancio → rosso) — S
- [ ] 🟠 Crea componente base `MetricCard` (numero grande, etichetta, barra zona) — S
- [ ] 🟠 Crea componente `ZoneBadge` (pillola colorata per zona corrente) — S
- [ ] 🟡 Crea componente `DeviceStatusDot` (verde/arancio/grigio per stato connessione) — S

### 0.3 Protocolli e modelli di dominio (contratti, zero implementazione)

Definisce le **interfacce e i tipi di dati** condivisi tra i layer — nessun algoritmo, nessuna dipendenza da framework. Ogni layer (Data, Domain, Presentation) può essere sviluppato e testato in isolamento perché conosce solo questi contratti.

| Cosa | A cosa serve |
|------|--------------|
| `TrainerControl` | Protocollo per il rullo: `setTargetPower(_:)` (ERG) e `setSimulation(grade:totalWeight:)` (SIM). Implementato da `FTMSAdapter` e `TacxAdapter`. |
| `HeartRateSource` | Protocollo per la sorgente HR: espone un `AsyncStream<HeartRateSample>`. Implementato dall'Apple Watch e dalla fascia BLE. |
| `RouteProvider` | Protocollo per i percorsi: `search(query:)` e `fetch(id:)`. Implementato da GPX locale, OpenRouteService, Strava. |
| Modelli dati | Struct pure che circolano tra i layer: `TrainerMetrics`, `HeartRateSample`, `Route`, `RouteProfile`, `WorkoutSession`, `SessionRecord`, `AthleteProfile`. |
| Stati `WorkoutEngine` | Enum della macchina a stati: `idle → connecting → active → paused → finishing → finished`. |

- [ ] 🔴 Definisci protocollo `TrainerControl`: `setTargetPower(_:)`, `setSimulation(grade:totalWeight:)` — S
- [ ] 🔴 Definisci protocollo `HeartRateSource`: `AsyncStream<HeartRateSample>` — S
- [ ] 🔴 Definisci protocollo `RouteProvider`: `search(query:)`, `fetch(id:)` — S
- [ ] 🔴 Definisci modelli: `TrainerMetrics`, `HeartRateSample`, `Route`, `RouteProfile`, `WorkoutSession`, `SessionRecord`, `AthleteProfile` — M
- [ ] 🔴 Definisci stati di `WorkoutEngine`: `idle`, `connecting`, `active`, `paused`, `finishing`, `finished` — S

---

## Fase MVP — "Pedalo e registro" {#fase-mvp}

**Goal:** connessione FLUX reale, ERG + SIM su percorso GPX importato, HR dall'Apple Watch, dashboard live, registrazione a 1 Hz, export FIT.
**Prerequisiti:** Fase 0 completata.
**Stima:** ~8–10 settimane.

**Criteri di completamento (Definition of Done):**
- Sessione completa 30 min su percorso GPX reale senza crash o perdita dati
- Export FIT importabile in Garmin Connect / Strava
- HR dall'Apple Watch visibile nella dashboard con latenza < 3 s
- Rullo risponde a comandi ERG e SIM in < 1 s

---

### MVP-DESIGN — Architettura e UI

#### Architettura
- [ ] 🔴 Specifica contratti Data→Domain: tutti i protocolli repository (TrainerRepository, HeartRateRepository, RouteRepository, PersistenceRepository, ExportRepository) — M
- [ ] 🔴 Disegna diagramma flusso dati: BLE→TrainerService→WorkoutEngine→SessionRecorder→PersistenceRepository — S
- [ ] 🟠 Specifica formato `SessionRecord` SQLite: campi, tipi, indici — S
- [ ] 🟠 Specifica schema SwiftData: `Athlete`, `WorkoutSession`, `Route`, `Lap` — S

#### UI/UX
- [ ] 🔴 Specifica **HomeView**: card percorso selezionato (profilo altimetrico + stats), card workout ERG, attività recenti, badge connessione device — S
- [ ] 🔴 Specifica **DeviceConnectionView**: sezioni Rullo Smart / Frequenza Cardiaca / Sensori Opzionali, stati connesso/disconnesso/scanning, row calibrazione — S
- [ ] 🔴 Specifica **LiveDashboard** variante A (Focus): potenza eroe grande, HR+cadenza+velocità secondari, profilo altimetrico con pendenza corrente e "prossimi 1,5 km", barra colorata zona potenza, toggle SIM/ERG, pulsanti pausa/lap/riavvolgi — M
- [ ] 🔴 Specifica **LiveDashboard** variante B (Griglia bilanciata): 4 card metriche pari (potenza, cardio, cadenza, velocità), profilo altimetrico sotto — S
- [ ] 🔴 Specifica **LiveDashboard** variante C (Terreno protagonista): profilo altimetrico grande come protagonist, metriche compatte sotto — S
- [ ] 🟠 Specifica **ElevationProfileView**: colori per range pendenza (giallo < 4%, verde 4–7%, arancio 7–10%, rosso > 10%), indicatore posizione (linea verticale bianca), etichette km percorsi e prossimi — M
- [ ] 🟠 Specifica **RouteLibraryView**: lista percorsi locali, anteprima profilo, stats (km, dislivello, pendenza media/max), import file — S
- [ ] 🟠 Specifica **SessionSummaryView**: metriche chiave, grafici Swift Charts potenza+HR nel tempo, pulsante export — S
- [ ] 🟠 Specifica **AthleteProfileView**: onboarding (FTP, peso, max HR, zone) e settings — S
- [ ] 🟡 Specifica **Watch companion**: grandi numeri HR + zona, potenza, tempo; pulsanti lap e pausa — S

---

### MVP-DATA — Data / Infrastructure

#### BLE — BluetoothCentralManager
- [ ] 🔴 Implementa `BluetoothCentralManager` actor: scan periferiche, connect, discover services/characteristics, subscribe notifiche — L
- [ ] 🔴 Implementa macchina a stati BLE: `off`, `scanning`, `connecting`, `connected`, `disconnected` — M
- [ ] 🔴 Implementa riconnessione automatica con backoff esponenziale (3 s, 6 s, 12 s, max 60 s) — M
- [ ] 🟠 Implementa timeout di connessione (30 s) con fallback a nuovo scan — S

#### TrainerService — FTMS
- [ ] 🔴 Implementa `FTMSAdapter`: parsing `Indoor Bike Data` (0x2AD2) → `TrainerMetrics` (potenza W, cadenza rpm, velocità km/h) — M
- [ ] 🔴 Implementa `FTMSAdapter`: scrittura `Set Target Power` su Control Point (0x2AD9) → **ERG mode** — M
- [ ] 🔴 Implementa `FTMSAdapter`: scrittura `Set Indoor Bike Simulation Parameters` (grade %, wind speed, Crr, Cw) → **SIM mode** — M
- [ ] 🔴 Implementa handshake Request Control / Response sul Control Point (obbligatorio FTMS spec) — M
- [ ] 🟠 Implementa `TacxAdapter` (protocollo proprietario Tacx, fallback) — L
- [ ] 🟠 Implementa capability discovery: ispezione GATT services → selezione `FTMSAdapter` o `TacxAdapter` — M
- [ ] 🟠 Implementa flusso calibrazione spindown (procedura specifica Tacx/FTMS) — M

#### HeartRateService
- [ ] 🔴 Implementa `HeartRateService` actor con due sorgenti: Watch (priorità) e fascia BLE (fallback) — M
- [ ] 🔴 Implementa ricezione HR da `WCSession` (lato iPhone): `session(_:didReceiveMessage:)` — M
- [ ] 🟠 Implementa `BLEHeartRateAdapter`: standard Heart Rate Service (0x180D), parse caratteristica HR Measurement — M

#### RouteRepository e parser
- [ ] 🔴 Implementa `GPXParser`: parse `.gpx` con `<trkpt lat lon ele>`, output `[RoutePoint]` — M
- [ ] 🟠 Implementa `FITParser` (usando FitDataProtocol SPM): parsing file `.fit` — M
- [ ] 🟠 Implementa `TCXParser`: parse `.tcx` — M
- [ ] 🔴 Implementa `RouteRepository`: salvataggio/caricamento percorsi locali (file system + metadati SwiftData) — M
- [ ] 🔴 Implementa `ElevationService`: chiamata ORS Elevation API per arricchimento quote GPS (batch POST) — M
- [ ] 🔴 Implementa algoritmo smoothing pendenza: ricampionamento a passo 10–25 m, media mobile a finestra 200 m, poi calcolo `Δquota/Δdistanza` — M
- [ ] 🔴 Implementa clamping pendenza al range FLUX (tipicamente −10% … +20%) — S
- [ ] 🔴 Implementa lag resistenza (ritardo applicazione comando ~0.5 s per evitare spike) — S

#### PersistenceRepository
- [ ] 🔴 Implementa schema SwiftData: `Athlete`, `WorkoutSession`, `Route`, `Lap` — M
- [ ] 🔴 Implementa schema GRDB/SQLite: tabella `session_records` (id, session_id, timestamp, power_w, cadence_rpm, speed_kmh, distance_m, hr_bpm, grade_pct, virtual_position_m, altitude_m, lap_index) — M
- [ ] 🔴 Implementa salvataggio incrementale anti-crash: flush ogni 10 record (non aspettare la fine sessione) — M
- [ ] 🟠 Implementa recovery sessione: al riavvio app, rileva sessione non chiusa e offre di riprendere — M

#### ExportService
- [ ] 🔴 Implementa `FITExporter`: converte `[SessionRecord]` in file `.fit` (Activity file, con lap, metrics) — L
- [ ] 🔴 Implementa salvataggio workout in HealthKit (`HKWorkout` + campioni HR e potenza) — M
- [ ] 🟡 Implementa `TCXExporter` — M
- [ ] 🟡 Implementa `GPXExporter` (traccia percorso reale) — S

---

### MVP-DOMAIN — Logica di business

- [ ] 🔴 Implementa `AthleteProfile` (FTP, peso kg, maxHR, zone potenza ×5, zone HR ×5) — S
- [ ] 🔴 Implementa `TrainingZones`: dato valore potenza o HR, restituisce zona (1–5) e colore — S
- [ ] 🔴 Implementa `RouteToSimulationMapper`:
  - [ ] 🔴 Ricampionamento traccia a passo fisso — S
  - [ ] 🔴 Applicazione smoothing/elevazione — S
  - [ ] 🔴 Costruzione `RouteProfile`: array `[distanza_m → grade_pct]` — S
  - [ ] 🔴 Lookup real-time: dato `virtualPosition_m` → `grade_pct` corrente — S
- [ ] 🔴 Implementa `WorkoutEngine` (actor isolato):
  - [ ] 🔴 Tick loop a 1 Hz tramite `AsyncStream` — M
  - [ ] 🔴 ERG mode: emissione `setTargetPower(_:)` a ogni tick — S
  - [ ] 🔴 SIM mode: lookup grade + emissione `setSimulation(grade:totalWeight:)` a ogni tick — M
  - [ ] 🔴 Transizioni di stato (idle → connecting → active → paused → finishing → finished) — M
  - [ ] 🟠 Auto-pause: velocità < 1 km/h per > 3 s → pausa automatica — S
  - [ ] 🟠 Gestione lap manuale (incremento lap index, salva timestamp) — S
- [ ] 🔴 Implementa `SessionRecorder`: aggrega dati dai stream a 1 Hz, costruisce `SessionRecord`, flush async su `PersistenceRepository` — M
- [ ] 🔴 Implementa `MetricsCalculator`:
  - [ ] 🔴 Potenza media, potenza 3s rolling, NP (Normalized Power: media 4° delle medie 30s) — M
  - [ ] 🔴 IF = NP / FTP, TSS = (durata_s × NP × IF) / (FTP × 3600) × 100 — S
  - [ ] 🔴 kJ (lavoro meccanico), calorie (~kJ / 0.25) — S
  - [ ] 🔴 Distanza percorsa (integrazione velocità a 1 Hz) — S
  - [ ] 🔴 Distanza rimanente e ETA (distanza_totale − distanza_percorsa, / velocità_media) — S
  - [ ] 🟠 Zona corrente HR e potenza (tramite TrainingZones) — S
- [ ] 🔴 UseCase `StartSession` (connect → discover → init engine → start recorder) — M
- [ ] 🔴 UseCase `PauseResumeSession` — S
- [ ] 🔴 UseCase `ImportRoute` (file picker → parser → elevation → mapper → save) — M
- [ ] 🔴 UseCase `FinishAndExportSession` (stop engine + recorder → export FIT → save HealthKit) — M
- [ ] 🟠 UseCase `CalibrateTrainer` (spindown flow) — M

---

### MVP-PRESENTATION — SwiftUI iOS

#### ViewModels (Observable, actor-safe)
- [ ] 🔴 `DeviceConnectionViewModel`: stato rullo (tipo, RSSI, connesso), stato Watch/fascia, avvio calibrazione — M
- [ ] 🔴 `LiveDashboardViewModel`: bind a `WorkoutEngine`, espone metriche calcolate, gestisce toggle SIM/ERG, layout selezionato — M
- [ ] 🔴 `RouteLibraryViewModel`: lista percorsi locali, import file, selezione percorso corrente — M
- [ ] 🟠 `SessionSummaryViewModel`: metriche finali, dati per grafici post-sessione — M
- [ ] 🟠 `AthleteProfileViewModel`: salvataggio profilo in SwiftData — S

#### Viste principali
- [ ] 🔴 `HomeView`: saluto utente, badge "N device connessi", card percorso selezionato (profilo altimetrico + CTA "Pedala il percorso"), card workout ERG, sezione "Attività recenti" — L
- [ ] 🔴 `DeviceConnectionView`: sezione Rullo Smart (TACX FLUX S, FTMS badge, stato, row calibrazione), sezione Frequenza Cardiaca (Apple Watch PRIMARIO, fascia BLE ripiego), sezione Sensori Opzionali (aggiungi cadenza/velocità/power meter) — L
- [ ] 🔴 `LiveDashboardView` — **variante Focus**: timer in alto, toggle SIM/ERG, potenza eroe (font ~80pt), barra zona colorata, metrica 3s/NP/media, HR+cadenza+velocità secondari, `ElevationProfileView`, controlli (riavvolgi / pausa / lap) — XL
- [ ] 🟠 `LiveDashboardView` — **variante Griglia**: 4 MetricCard in griglia 2×2, `ElevationProfileView` sotto — M
- [ ] 🟠 `LiveDashboardView` — **variante Terreno**: `ElevationProfileView` occupa 50% schermata, metriche in fondo — M
- [ ] 🟠 Selezione layout dashboard (preferenza persistita in UserDefaults) — S
- [ ] 🔴 `RouteLibraryView`: lista con anteprima `ElevationProfileView`, stats (km/dislivello/pendenza), import da file picker, empty state — L
- [ ] 🟠 `SessionSummaryView`: metriche (TSS, IF, kJ, NP, distanza, dislivello), grafici Swift Charts (potenza/HR/velocità nel tempo), pulsante export/share — L
- [ ] 🟠 `AthleteProfileView`: form FTP / peso / maxHR / zone, validazione input — M
- [ ] 🟡 `SettingsView`: unità (km/mph), permessi Bluetooth/HealthKit/Posizione, about/versione — M
- [ ] 🔴 Tab bar: Home / Percorsi / Allena / Storico / Profilo (Profilo = impostazioni in MVP) — S

#### Componenti riusabili
- [ ] 🔴 `ElevationProfileView` (Swift Charts): area chart colorata per zona pendenza, linea verticale posizione, label km/pendenza corrente, etichetta "prossimi X km" — L
- [ ] 🔴 `MetricCard`: numero grande colorato per zona, label etichetta, barra zona — S
- [ ] 🟠 `SessionResumeCard` (HomeView): card con icona play, nome sessione interrotta, km+modalità — S
- [ ] 🟡 `CountdownOverlay`: conto alla rovescia 3-2-1 pre-sessione — S

---

### MVP-WATCH — watchOS Companion App

- [ ] 🔴 Crea watchOS target e scene principale — S
- [ ] 🔴 Implementa `WatchWorkoutSessionManager`:
  - [ ] 🔴 Avvia `HKWorkoutSession` di tipo `.cycling` + `HKLiveWorkoutBuilder` — M
  - [ ] 🔴 Legge HR live da `HKLiveWorkoutBuilder.statistics(for: .heartRate)` — M
  - [ ] 🔴 Invia HR all'iPhone via `WCSession.sendMessage([:] replyHandler:)` ogni secondo — M
  - [ ] 🔴 Riceve comandi start/pause/stop/lap dall'iPhone e aggiorna stato locale — M
  - [ ] 🔴 Mantiene workout attivo in background (`.workout` background mode) — M
- [ ] 🔴 Implementa `WorkoutControlView` watchOS:
  - [ ] 🔴 HR grande (~ 60pt) con zona, potenza, tempo trascorso — M
  - [ ] 🔴 Pulsante lap (verde) e pausa (arancio), stop (rosso) — M
  - [ ] 🟠 Indicatore zona HR con colore di sfondo — S
- [ ] 🟠 Gestisci stato "iPhone non connesso": messaggio chiaro, blocca streaming — S

---

### MVP-TEST — Test

#### Unit test — Domain (zero dipendenze esterne, tutti fast)
- [ ] 🔴 `WorkoutEngine`: transizioni di stato (idle→connecting, connecting→active, active→paused, paused→active, active→finished) — M
- [ ] 🔴 `WorkoutEngine`: in ERG mode, il comando emesso a ogni tick corrisponde al target power — S
- [ ] 🔴 `WorkoutEngine`: in SIM mode, il grade emesso corrisponde al lookup della posizione virtuale corrente — M
- [ ] 🔴 `WorkoutEngine`: auto-pause scatta dopo 3 tick con velocità < 1 km/h — S
- [ ] 🔴 `MetricsCalculator`: NP su sequenza di potenze nota (golden values calcolati manualmente) — M
- [ ] 🔴 `MetricsCalculator`: TSS e IF corretti con FTP noto — S
- [ ] 🔴 `MetricsCalculator`: distanza percorsa (integrazione velocità costante) — S
- [ ] 🔴 `MetricsCalculator`: ETA con velocità media stabile — S
- [ ] 🔴 `RouteToSimulationMapper`: output ricampionato ha passo fisso ±1 m — S
- [ ] 🔴 `RouteToSimulationMapper`: smoothing non produce pendenza > ±30% su traccia reale (dataset Passo dello Stelvio) — M
- [ ] 🔴 `RouteToSimulationMapper`: clamping rispetta range FLUX — S
- [ ] 🔴 `TrainingZones`: zona corretta per ogni soglia (test tutte e 5 le zone, bordi inclusi) — S
- [ ] 🟠 `SessionRecorder`: dopo 10 tick, flush è avvenuto e record su DB — M

#### Unit test — Data (con mock BLE)
- [ ] 🔴 `FTMSAdapter`: parsing raw bytes `Indoor Bike Data` → potenza/cadenza/velocità corretti — M
- [ ] 🔴 `FTMSAdapter`: costruzione payload `Set Target Power` (byte corretto, little-endian) — S
- [ ] 🔴 `FTMSAdapter`: costruzione payload `Set Indoor Bike Simulation Parameters` — S
- [ ] 🔴 `GPXParser`: file con quote → `[RoutePoint]` corretto — S
- [ ] 🔴 `GPXParser`: file senza quote → gestisce assenza `<ele>` senza crash — S
- [ ] 🟠 `FITParser`: file FIT attività ciclismo → output coerente — M
- [ ] 🔴 `ElevationService`: smoothing applicato su dati sintetici rumorosi (rampa + rumore ±20 m) → pendenza output < ±5% variazione campione-su-campione — M

#### Integration test
- [ ] 🔴 Pipeline end-to-end SIM: `ImportRoute(GPX)` → `RouteToSimulationMapper` → `WorkoutEngine` → sequenza comandi SIM coerente con il profilo del percorso — L
- [ ] 🔴 `WorkoutEngine` + `SessionRecorder`: sessione simulata 60 s → 60 record in DB con timestamp crescenti — M
- [ ] 🔴 `PersistenceRepository`: write + read round-trip SwiftData (sessione, percorso) — M
- [ ] 🔴 `PersistenceRepository`: write + read round-trip SQLite session records — M
- [ ] 🔴 `ExportService`: `[SessionRecord]` → FIT file → parse FIT → record identici — L
- [ ] 🟠 Recovery sessione: simulare crash a metà sessione → riavvio → record precedenti presenti in DB — M

#### Snapshot / UI test
- [ ] 🟠 `ElevationProfileView`: rendering su profilo Stelvio (salita progressiva con variazione zone) — M
- [ ] 🟠 `LiveDashboardView` variante A: snapshot con dati di test (potenza 280 W, zona 4, grade 7.6%) — M
- [ ] 🟠 `LiveDashboardView` variante B: griglia 4 metrica — S
- [ ] 🟠 `DeviceConnectionView`: stato "connesso" vs "disconnesso" — S

#### Test manuali / hardware (richiedono dispositivo reale)
- [ ] 🔴 Ispezionare GATT services TACX FLUX S con **nRF Connect** prima di scrivere l'adapter — S
- [ ] 🔴 Connessione FTMS da app: lettura potenza/cadenza/velocità live, verificare valori coerenti con display FLUX — M
- [ ] 🔴 Comando ERG: impostare 200 W, 250 W, 150 W → rullo risponde < 1 s, potenza si stabilizza — M
- [ ] 🔴 Comando SIM grade 0%, 5%, 10%, −5%: verificare resistenza cambia in modo percepibile e proporzionale — M
- [ ] 🔴 Spindown calibration end-to-end — S
- [ ] 🔴 HR streaming Apple Watch → iPhone: latenza < 3 s, nessun buco > 5 s in 30 min — M
- [ ] 🔴 Sessione SIM completa 30 min su percorso GPX reale: nessuna perdita dati, nessun crash — L
- [ ] 🔴 Import file FIT risultante in Garmin Connect e/o Strava: workout appare con metriche corrette — S
- [ ] 🟠 Riconnessione automatica: disconnettere deliberatamente il FLUX → l'app si riconnette entro 60 s — M
- [ ] 🟠 Auto-pause: fermarsi per 5 s → pausa automatica → riprendere → sessione continua — S

---

## Fase v1 — Esperienza completa {#fase-v1}

**Goal:** autenticazione email/Apple + workout strutturati ERG + storico + mappa sincronizzata + connessione robusta.
**Prerequisiti:** MVP in produzione (o TestFlight).
**Stima:** ~8 settimane.

**Criteri di completamento:**
- L'utente può registrarsi, fare login, fare Sign in with Apple
- I dati sono isolati per account (altro account non vede nulla)
- Workout strutturato 5×4' a 280 W funziona end-to-end (step avanzano automaticamente)
- Storico mostra sessioni con grafici Swift Charts

---

### v1-DESIGN

- [ ] 🔴 Specifica **Auth Flow** completo: Welcome → Sign Up → verifica email → onboarding profilo → Home — M
- [ ] 🔴 Specifica **AccountSettingsView**: dispositivi attivi, sblocco biometrico, export dati, elimina account, consensi GDPR — M
- [ ] 🔴 Specifica **WorkoutBuilderView**: editor step ERG con drag-reorder, form durata/target/tipo, anteprima grafico a barre — M
- [ ] 🔴 Specifica **HistoryView** e **SessionDetailView**: lista sessioni, grafici potenza+HR+velocità nel tempo (Swift Charts), record personali — M
- [ ] 🟠 Specifica **MapView** sincronizzata: MapKit polyline percorso, dot animato posizione virtuale — S
- [ ] 🟠 Specifica adattamento di tutte le viste per dati scoped per account — S

### v1-DATA — Autenticazione e backend

- [ ] 🔴 Integra **Supabase Auth** (o Auth0): SDK iOS, configurazione endpoint — M
- [ ] 🔴 Implementa `AuthService` actor: `register(email:password:)`, `login(email:password:)`, `logout()`, `refreshToken()` — M
- [ ] 🔴 Implementa **Sign in with Apple** (`ASAuthorizationAppleIDProvider`) — M
- [ ] 🔴 Implementa salvataggio token access/refresh in **Keychain** (mai UserDefaults, mai log) — M
- [ ] 🔴 Implementa `SessionManager`: ciclo vita sessione, auto-logout dopo inattività, revoca — M
- [ ] 🔴 Implementa sblocco biometrico Face ID/Touch ID (`LAContext.evaluatePolicy`) — M
- [ ] 🔴 Implementa `AccountRepository`: link identità ↔ `AthleteProfile` in SwiftData — M
- [ ] 🔴 Implementa `BackendAPIClient`: client REST con Bearer token, gestione errori 401 (refresh automatico) — M
- [ ] 🟠 Implementa `SyncEngine` offline-first: coda upload sessioni al rientro della rete (`NWPathMonitor`), retry con backoff, risoluzione conflitti last-write-wins per time-series — L
- [ ] 🟠 Implementa `ConsentManager`: raccolta e versionamento consensi (uso app, dati sanitari, sync cloud) — M
- [ ] 🟠 Adatta `PersistenceRepository` per isolamento per-utente (ogni query filtrata su `userId`) — M
- [ ] 🟠 Implementa robustezza BLE avanzata: macchina a stati con retry espliciti, alert UI "Connessione persa — tentativo N/5" — M

### v1-DOMAIN

- [ ] 🔴 Implementa `WorkoutDefinition`: sequenza di `WorkoutStep` (tipo: riscaldamento/intervallo/recupero/defaticamento, durata_s, target_W o target_%FTP) — M
- [ ] 🔴 Estendi `WorkoutEngine` per **workout strutturati**: avanzamento automatico step, countdown fine step, notifica AudioServicesPlaySystemSound — M
- [ ] 🔴 UseCase `AuthenticateUser`, `RegisterUser`, `SignInWithApple` — M
- [ ] 🔴 UseCase `DeleteAccount` (cancellazione locale SwiftData + SQLite + richiesta DELETE al backend) — M
- [ ] 🔴 Implementa `MigrateGuestData`: sposta sessioni create in modalità ospite sull'account appena creato — M
- [ ] 🔴 Implementa `UserScopedDataPolicy`: wrapper che garantisce userId sulle query — S
- [ ] 🟠 UseCase `BuildWorkout` (crea/modifica WorkoutDefinition, salva) — M
- [ ] 🟠 Record personali: calcola best power per durata (5s, 1', 5', 20', 60') su storico sessioni — M

### v1-PRESENTATION

#### Auth Flow
- [ ] 🔴 `WelcomeView`: logo, "Inizia come ospite" / "Accedi" / "Registrati" — S
- [ ] 🔴 `SignUpView`: email + password (validazione complessità) + CTA — M
- [ ] 🔴 `SignInView`: email/password + "Sign in with Apple" button — M
- [ ] 🔴 `ForgotPasswordView`: input email, invio reset — S
- [ ] 🔴 `EmailVerificationView`: messaggio attesa + "Invia di nuovo" — S
- [ ] 🔴 `AthleteOnboardingView`: form FTP / peso / max HR (si apre solo al primo login) — M
- [ ] 🔴 `AccountSettingsView`: lista dispositivi attivi, toggle Face ID, pulsanti "Esporta i tuoi dati" e "Elimina account" (con conferma), sezione consensi — L

#### Workout e storico
- [ ] 🔴 `WorkoutBuilderView`: lista step con drag-reorder, form inline (durata, potenza target), grafico a barre anteprima, salva/nomina — L
- [ ] 🔴 `WorkoutLibraryView`: lista workout salvati con anteprima, filtro per durata/tipo — M
- [ ] 🔴 `HistoryView`: lista sessioni ordinate per data (per utente loggato), filtri per tipo (SIM/ERG/libero), stats aggregate — L
- [ ] 🔴 `SessionDetailView`: grafici Swift Charts (potenza W, HR bpm, velocità km/h, pendenza % nel tempo), metriche riepilogative, map preview — L
- [ ] 🟠 `MapView` sincronizzata: MapKit polyline del percorso, dot che avanza in real-time durante la sessione — L
- [ ] 🟠 Feedback aptico lap (UIImpactFeedbackGenerator `.heavy`) — S
- [ ] 🟡 Alert banner "Connessione persa" / "Riconnettendo…" in overlay sulla dashboard — S

### v1-WATCH

- [ ] 🟠 Propagazione stato autenticazione iPhone → Watch via `WCSession.transferUserInfo` — M
- [ ] 🟠 Watch: se iPhone non autenticato, mostra messaggio "Apri Ascesa su iPhone per iniziare" — S

### v1-TEST

#### Unit test
- [ ] 🔴 `WorkoutEngine` strutturato: avanzamento automatico step dopo durata prevista — M
- [ ] 🔴 `WorkoutEngine` strutturato: step di tipo recupero → target power corretto (< soglia) — S
- [ ] 🔴 `MigrateGuestData`: dati ospite pre-login appaiono nell'account dopo migrazione — M
- [ ] 🔴 `UserScopedDataPolicy`: query con userId errato restituisce vuoto, non lancia eccezione — S

#### Integration test
- [ ] 🔴 Auth flow: registrazione → verifica email → login (test su Supabase staging) — M
- [ ] 🔴 `SyncEngine`: sessione creata offline → connessione rete → sessione presente su backend — M
- [ ] 🔴 `SyncEngine`: conflitto risolto con last-write-wins (timestamp più recente vince) — M
- [ ] 🔴 `DeleteAccount`: dopo cancellazione, login fallisce + dati locali rimossi — M

#### Security test
- [ ] 🔴 Verifica che token non compaia in nessun log (os_log, print, NSLog) — M
- [ ] 🔴 Verifica che Keychain item abbia `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — S
- [ ] 🔴 Rate limiting login: 5 tentativi falliti → errore specifico dal backend — M
- [ ] 🔴 Isolamento dati: autenticarsi come utente B → impossibile leggere sessioni utente A — M

#### Test manuali
- [ ] 🔴 Flusso registrazione completo su device reale (non simulatore): Sign in with Apple — M
- [ ] 🟠 Workout 5×4' end-to-end: step avanzano al timer, alert audio fine step — M
- [ ] 🟠 History: sessioni visibili solo dopo login, cambio account → vedi solo tue sessioni — M
- [ ] 🟠 Elimina account: dati rimossi, login successivo fallisce — M

---

## Fase v2 — Ricchezza e integrazioni {#fase-v2}

**Goal:** discovery percorsi in-app (OpenRouteService), visualizzazione Mapbox 3D, connettori opzionali (Strava personale, Garmin), trend FTP.
**Prerequisiti:** v1 stabile.
**Stima:** ~6 settimane.

**Criteri di completamento:**
- L'utente può cercare un percorso per nome/zona dentro l'app e iniziare a pedalarlo
- Mapbox mostra terreno 3D sincronizzato con posizione

---

### v2-DESIGN

- [ ] 🟠 Specifica **RouteDiscoveryView**: barra ricerca, mappa ORS interattiva, filtri (lunghezza, dislivello, tipo), CTA "Pedala" — M
- [ ] 🟠 Specifica visualizzazione 3D terrain Mapbox nella dashboard live — M
- [ ] 🟠 Specifica **ConnectorsView**: gestione connessioni Strava/Garmin/RWGPS (OAuth, revoca) — M
- [ ] 🟡 Specifica **FTPTrendView**: grafico PMC (CTL, ATL, TSB nel tempo), trend forma — M

### v2-DATA

- [ ] 🟠 Implementa `OpenRouteServiceProvider` (`RouteProvider`): `search(query:)` → ricerca percorsi ciclistici OSM, `fetch(id:)` → scarica geometria + quote — L
- [ ] 🟠 Integra **Mapbox Maps SDK**: terrain 3D, layer ciclismo — L
- [ ] 🟡 Implementa `StravaProvider` (solo dati personali, scope `activity:read_all`): import attività recenti come percorsi — L
- [ ] 🟡 Implementa `GarminProvider` (Garmin Health API): sync percorsi/attività — L
- [ ] 🟡 Implementa `RideWithGPSProvider`: ricerca e download percorsi — M
- [ ] 🟡 Sync multi-dispositivo su iPad (SyncEngine già sviluppato in v1) — M

### v2-DOMAIN

- [ ] 🟠 Estendi `RouteProvider` per sorgenti ORS / Strava / Garmin / RWGPS — S
- [ ] 🟡 Implementa analisi trend FTP: calcola CTL (fitness), ATL (fatica), TSB (forma) da storico TSS — L

### v2-PRESENTATION

- [ ] 🟠 `RouteDiscoveryView`: ricerca, mappa interattiva ORS, card risultato con profilo altimetrico, filtri — XL
- [ ] 🟠 Dashboard live con Mapbox terrain 3D (variante layout opzionale) — L
- [ ] 🟡 `ConnectorsView`: OAuth flow Strava/Garmin/RWGPS, badge connesso/disconnesso, revoca — L
- [ ] 🟡 `FTPTrendView`: Swift Charts PMC (linee CTL/ATL/TSB), picker intervallo temporale — L

### v2-TEST

- [ ] 🟠 `OpenRouteServiceProvider`: search "Passo dello Stelvio" → risultati geograficamente corretti — M
- [ ] 🟠 Percorso scaricato da ORS: pipeline smoothing → sessione SIM funzionante — M
- [ ] 🟠 Mapbox terrain: rendering 3D corretto senza crash su iPhone + iPad — M
- [ ] 🟡 Strava: import solo attività dell'utente autenticato, nessun dato altrui accessibile — M
- [ ] 🟡 Sync multi-device: sessione iPhone visibile su iPad — M

---

## Fase v3 — Multi-utente coach/atleta {#fase-v3}

**Goal:** ruoli coach–atleta, condivisione selettiva percorsi/workout, account team.
**Prerequisiti:** v2 stabile, backend maturo.
**Stima:** ~6 settimane.

**Criteri di completamento:**
- Coach invita atleta, vede le sue sessioni condivise, non vede quelle private
- Revoca accesso coach → dati immediatamente non più visibili

---

### v3-DESIGN

- [ ] 🟡 Specifica modello ruoli: coach / atleta / team admin — M
- [ ] 🟡 Specifica flusso invito: coach invia invite link → atleta accetta → coach vede workout condivisi — M
- [ ] 🟡 Specifica `CoachDashboardView`: overview atleti, sessioni recenti, note — M
- [ ] 🟡 Specifica permessi di visibilità (atleta sceglie cosa condividere col coach) — M

### v3-SVILUPPO

- [ ] 🟡 Backend: modello ruoli (tabella `user_roles`, RLS per-ruolo) — L
- [ ] 🟡 Backend: sistema inviti (token temporaneo, scadenza 7 gg) — M
- [ ] 🟡 Backend: endpoint condivisione (atleta autorizza coach a leggere specifici dati) — L
- [ ] 🟡 Implementa revoca accesso (immediata, senza cache) — M
- [ ] 🟡 `CoachDashboardView`: lista atleti, sessioni aggregate, drill-down su singolo atleta — L
- [ ] 🟡 `TeamView`: gestione team, condivisione percorsi/workout al gruppo — L
- [ ] 🟡 Permessi granulari in `UserScopedDataPolicy` (ruolo coach) — M

### v3-TEST

- [ ] 🟡 Isolamento dati: atleta B non vede dati di atleta A (nemmeno con token A) — M
- [ ] 🟡 Coach: accede solo ai dati che l'atleta ha esplicitamente condiviso — M
- [ ] 🟡 Revoca accesso coach: dati inaccessibili entro 1 minuto dalla revoca — M
- [ ] 🟡 Invito scaduto non può essere riusato — S

---

## Task trasversali {#trasversali}

Task validi per tutte le fasi, da monitorare continuamente.

### Sicurezza e privacy
- [ ] 🔴 Configura App Transport Security: `NSAllowsArbitraryLoads = false`, solo TLS 1.2+ — S
- [ ] 🔴 Verifica che dati SQLite non contengano HR raw in chiaro su device (valuta `SQLCipher` o iOS Data Protection) — M
- [ ] 🔴 Scrivi **Privacy Policy** conforme GDPR art. 9 (dati sanitari HR/potenza): base giuridica, finalità, conservazione, diritto all'oblio — L (richiede consulenza legale)
- [ ] 🔴 Scrivi **Terms of Service** — M
- [ ] 🔴 Implementa consenso granulare in-app: uso app / dati sanitari / sync cloud — M
- [ ] 🔴 Verifica conformità **App Store Review Guidelines §4.8** (login di terze parti → Sign in with Apple obbligatorio) — S
- [ ] 🔴 Verifica conformità **§5.1.1** (cancellazione account in-app, non solo via sito) — S
- [ ] 🔴 Implementa **export dati** (JSON + FIT + CSV) per portabilità GDPR ante-cancellazione — M
- [ ] 🟠 Implementa **cancellazione account completa** lato server (soft delete → hard delete dopo 30 gg) — M
- [ ] 🟡 Opzione 2FA (v2+): TOTP via Authenticator app — L

### Accessibilità
- [ ] 🟠 Dynamic Type: tutti i testi usano `.font(.body)` o scalabili; nessun testo a dimensione fissa — M
- [ ] 🟠 Verifica leggibilità palette scura sotto sforzo: contrasto minimo 4.5:1 per testi normali — M
- [ ] 🟡 VoiceOver: tutti i controlli interattivi con `accessibilityLabel` significativo — M
- [ ] 🟡 Reduce Motion: nessuna animazione essenziale al funzionamento se `UIAccessibility.isReduceMotionEnabled` — S

### Performance e affidabilità
- [ ] 🟠 Profiling Instruments (Time Profiler): tick loop a 1 Hz < 5% CPU su iPhone XS in sessione 2h — M
- [ ] 🟠 Profiling Allocations: nessun retain cycle nel bindings WorkoutEngine → ViewModel — M
- [ ] 🟠 Misura drain batteria Watch durante workout 1h (Battery Life instrument): < 40% consumo — M
- [ ] 🟡 Gestione termica: `ProcessInfo.thermalState` → ridurre frequenza log se `.critical` — S
- [ ] 🔴 Verifica offline-first a ogni fase: allenamento funziona senza rete (airplane mode) — S

### Distribuzione e rilascio
- [ ] 🟠 Configura schema TestFlight: build automatica su tag `beta/*` — M
- [ ] 🔴 App Store Connect: metadata (titolo, sottotitolo, descrizione, keywords IT+EN), screenshot iPhone/Watch — L
- [ ] 🔴 Privacy Nutrition Label (App Store): dichiara dati raccolti (salute, fitness, email) — M
- [ ] 🔴 Submission App Store: verifica entitlements HealthKit, Bluetooth usage description, associato a Developer Program — M

---

## Matrice dipendenze critiche {#dipendenze}

Le seguenti dipendenze bloccano il task figlio se il task padre non è completato.

```
Fase 0 — Protocolli di dominio
  └─► MVP — Tutti i layer (Data, Domain, Presentation)

MVP — BluetoothCentralManager
  └─► FTMSAdapter, TacxAdapter, HeartRateService (BLE)

MVP — FTMSAdapter (ERG + SIM)
  └─► WorkoutEngine (ERG/SIM loop)
        └─► LiveDashboardViewModel
              └─► LiveDashboardView

MVP — RouteToSimulationMapper
  └─► WorkoutEngine SIM mode

MVP — SessionRecorder + PersistenceRepository
  └─► ExportService (FIT)
        └─► SessionSummaryView

MVP — Watch WatchWorkoutSessionManager
  └─► HeartRateService (Watch source)
        └─► LiveDashboardView (HR)

v1 — AuthService + SessionManager
  └─► Tutte le viste multi-utente (History, Settings, Account)
        └─► UserScopedDataPolicy

v1 — SyncEngine
  └─► v2 multi-device, v3 coach/atleta

v1 — WorkoutDefinition + WorkoutEngine strutturato
  └─► WorkoutBuilderView + WorkoutLibraryView
```

---

*Documento generato il 2026-06-10 sulla base di:*
- *`IndoorTrainer_App_Analisi_e_Progetto.md`*
- *`Addendum_Autenticazione_Multiutente.md`*
- *Prototipo UI `Ascesa — Indoor Trainer.pdf`*
