# Indoor Trainer App — Analisi tecnica e progetto

App iOS/watchOS per allenamenti indoor con rullo smart **TACX FLUX** + **Apple Watch** per la frequenza cardiaca, con registrazione sessioni, download di percorsi reali e dashboard dati in tempo reale.

---

## 1. Analisi dei requisiti

### 1.1 I tuoi 5 requisiti, scomposti

**R1 — Controllo del device TACX FLUX**
Il FLUX è un *controllable smart trainer*: oltre a leggere potenza/cadenza/velocità, accetta comandi che ne cambiano la resistenza. Servono due modalità di controllo:
- **ERG mode**: imposti una potenza target (es. 220 W) e il rullo regola la resistenza per mantenerla a prescindere dalla cadenza. È la modalità per i workout strutturati a intervalli.
- **SIM mode** (simulazione): imposti la pendenza (%) più parametri ambientali (peso totale, resistenza aerodinamica, rolling resistance) e il rullo simula lo sforzo della salita/discesa. È la modalità per "pedalare un percorso reale".

Implicazioni: l'app deve gestire connessione, calibrazione (spindown), invio comandi a ~1 Hz, riconnessione automatica in caso di drop del segnale, e fallback tra protocolli (vedi §2.5).

**R2 — Frequenza cardiaca dall'Apple Watch**
Punto delicato e spesso frainteso: **l'Apple Watch NON trasmette la frequenza cardiaca come una normale fascia cardio Bluetooth** (non espone il profilo standard *Heart Rate Service* ai dispositivi di terze parti). Non puoi quindi "connetterti" all'orologio come faresti con una fascia Polar/Garmin. La via corretta è una **app companion watchOS** che:
1. avvia una sessione di allenamento (`HKWorkoutSession`) — necessaria per ottenere HR ad alta frequenza e con priorità sui sensori;
2. legge il battito live tramite HealthKit (`HKLiveWorkoutBuilder`);
3. lo invia in streaming all'iPhone via **Watch Connectivity** (`WCSession`).

In alternativa/aggiunta puoi supportare anche una **fascia cardio BLE** standard (chest strap o sensore ottico esterno): è più semplice da integrare e utile come ripiego. Consiglio di supportare entrambe.

**R3 — Registrazione percorsi con tutti i dati**
Ogni sessione deve campionare e persistere (idealmente a 1 Hz) un *record* con: timestamp, potenza, cadenza, velocità, distanza, HR, pendenza istantanea, posizione virtuale sul percorso, quota, lap/intervallo corrente, calorie/lavoro (kJ). Più i metadati di sessione (data, durata, percorso usato, TSS/IF/NP se calcolati, meteo virtuale, device usati). Da prevedere: salvataggio incrementale (niente perdita dati se l'app va in crash), e export.

**R4 — Download di percorsi già impostati**
Due famiglie distinte da non confondere:
- **Workout strutturati** (es. "10' riscaldamento, 5×4' a 280 W r:3', defaticamento") → tipicamente file `.zwo`/`.erg`/`.mrc` o cataloghi propri. Servono in ERG mode.
- **Percorsi geografici reali** (la geometria + l'altimetria di una strada/salita vera) → file `.gpx`/`.fit`/`.tcx` o API di terze parti. Servono in SIM mode. Questo è il tema del §3.

**R5 — Dashboard dati in tempo reale**
Durante l'allenamento, schermata ad alta leggibilità (sotto sforzo, sudore, vibrazioni) con: km percorsi / km mancanti, tempo trascorso / stimato rimanente, HR (+ zona), potenza istantanea/media/3s/NP, cadenza, velocità, **pendenza attuale e profilo altimetrico** con indicatore di posizione, e un mini-profilo "cosa arriva nei prossimi metri".

### 1.2 Requisiti aggiuntivi consigliati (non li avevi chiesti, ma servono)

| # | Requisito | Perché serve |
|---|-----------|--------------|
| A1 | Profilo atleta: peso, FTP, zone di potenza e di HR, max HR | Tutti i calcoli (ERG target, zone, TSS) dipendono da questi parametri |
| A2 | Calibrazione / spindown del rullo | La precisione della potenza degrada senza calibrazione periodica |
| A3 | Workout strutturati con editor e libreria | È il caso d'uso indoor più frequente, complementare ai percorsi |
| A4 | Metriche di allenamento: NP, IF, TSS, kJ, VI | Standard del settore per quantificare lo sforzo |
| A5 | Auto-pause, lap manuali/automatici, conto alla rovescia audio | Usabilità durante lo sforzo |
| A6 | Riconnessione automatica e gestione robusta del BLE | Le disconnessioni indoor sono frequentissime |
| A7 | Export FIT / TCX / GPX + sync (Strava, Garmin Connect, file) | Per non chiudere i dati dentro l'app |
| A8 | Storico, analisi post-sessione, record personali, trend FTP | Valore nel tempo, fidelizzazione |
| A9 | Mappa/visuale sincronizzata col percorso (2D minimo, video/3D opzionale) | Esperienza "immersiva" tipo Rouvy/FulGaz |
| A10 | Multi-sensore: cadenza/velocità/power meter separati dal rullo | Alcuni preferiscono i propri sensori |
| A11 | Gestione permessi e privacy (Bluetooth, HealthKit, posizione) | Requisito App Store + GDPR su dati sanitari |
| A12 | Funzionamento offline-first | L'allenamento non deve dipendere dalla rete |
| A13 | Avvisi di sicurezza/affaticamento, gestione termica del device | Sessioni lunghe, surriscaldamento rullo |
| A14 | Accessibilità (testi grandi, alto contrasto, VoiceOver) | Requisito Apple + leggibilità sotto sforzo |

### 1.3 Requisiti non funzionali

- **Real-time**: pipeline dati a 1 Hz (idealmente fino a 4 Hz su potenza), latenza comando→rullo < ~1 s.
- **Affidabilità**: nessuna perdita dati su crash/disconnessione; recovery di sessione.
- **Sicurezza dati sanitari**: HR e dati workout sono dati sensibili → storage cifrato, niente upload non consentito, conformità HealthKit/GDPR.
- **Efficienza energetica**: la Watch app durante un workout consuma molto; ottimizzare il rate di invio.
- **Manutenibilità**: i protocolli BLE dei rulli cambiano tra modelli → astrazione netta del layer device.

---

## 2. Architettura dell'applicazione e stack tecnologico

### 2.1 Scelta della piattaforma

I requisiti **R1 (BLE control)** e soprattutto **R2 (Apple Watch + HealthKit)** spingono fortemente verso lo **sviluppo nativo Apple (Swift)**.

- **CoreBluetooth** e l'integrazione **HealthKit/WorkoutKit/WatchConnectivity** sono API native: una app watchOS che legge HR live durante un workout *deve* essere nativa. Non esiste una scorciatoia cross-platform affidabile per questo.
- Flutter/React Native potrebbero gestire la parte iPhone+BLE con plugin, ma per la Watch app finiresti comunque a scrivere codice nativo, ottenendo il peggio dei due mondi.

**Conclusione: nativo iOS + watchOS.** Se in futuro vorrai Android, il dominio (motore workout, parser percorsi, metriche) va isolato per essere riscritto, ma la parte Apple Watch non sarà portabile.

### 2.2 Stack consigliato

| Ambito | Tecnologia | Note |
|--------|-----------|------|
| Linguaggio | **Swift 6** (concurrency con async/await + actors) | |
| UI | **SwiftUI** (+ UIKit solo dove serve) | Dashboard, editor workout, storico |
| Reattività | **Combine** / `AsyncStream` | Stream dati sensori |
| BLE | **CoreBluetooth** | Connessione e controllo rullo + fasce |
| Salute | **HealthKit** + **WorkoutKit** | HR, salvataggio workout in Salute |
| Watch↔iPhone | **WatchConnectivity** (`WCSession`) | Streaming HR e stato sessione |
| Persistenza | **SwiftData** (o Core Data) per il modello + **GRDB/SQLite** per i record ad alta frequenza | I time-series a 1 Hz stanno meglio in SQLite |
| Mappe | **MapKit** (incluso) o **Mapbox Maps SDK** (più controllo su terrain/3D) | |
| Grafici | **Swift Charts** | Profilo altimetrico, andamenti |
| Networking | **URLSession** + async/await | Chiamate alle API percorsi |
| Parsing percorsi | librerie GPX/FIT (es. **CoreGPX**, **FitDataProtocol**) | Import/Export |
| DI / architettura | MVVM + Clean Architecture (use case) | |
| Test | XCTest + Swift Testing | Unit sul dominio, mock del layer BLE |

### 2.3 Architettura a livelli

```
┌──────────────────────────────────────────────────────────────┐
│  PRESENTATION (SwiftUI)                                        │
│  Live Dashboard · Workout Builder · Route Library · History    │
│  ViewModels (MVVM) — stato osservabile, nessuna logica BLE     │
└───────────────▲───────────────────────────────▲──────────────┘
                │                                │
┌───────────────┴────────────────────────────────┴──────────────┐
│  DOMAIN (puro Swift, testabile, no dipendenze framework)       │
│  WorkoutEngine · SessionRecorder · MetricsCalculator           │
│  RouteToSimulationMapper · TrainingZones · UseCases            │
└───────────────▲───────────────────────────────▲──────────────┘
                │                                │
┌───────────────┴────────────────────────────────┴──────────────┐
│  DATA / INFRASTRUCTURE                                          │
│  TrainerService(CoreBluetooth) · HeartRateService              │
│  RouteRepository(API+import) · ElevationService                │
│  PersistenceRepository(SwiftData+SQLite) · ExportService       │
└────────────────────────────────────────────────────────────────┘
```

Regola d'oro: il **Domain non conosce CoreBluetooth né HealthKit**. Comunica con il Data layer tramite protocolli (interfacce) → così il motore di allenamento è interamente testabile con sensori finti.

### 2.4 Topologia dei dispositivi

```
   ┌─────────────┐   BLE (FTMS / FE-C)   ┌──────────────┐
   │  iPhone App │◀─────────────────────▶│  TACX FLUX   │
   │  (cervello) │   read dati + write    └──────────────┘
   │             │   comandi resistenza
   │             │
   │             │   WatchConnectivity    ┌──────────────┐
   │             │◀─────────────────────▶│ Apple Watch  │
   │             │   stream HR live       │ (HealthKit)  │
   └──────┬──────┘                        └──────────────┘
          │ BLE (opzionale)
          ▼
   ┌──────────────┐
   │ Fascia cardio│  ← ripiego/alternativa all'Apple Watch
   │ / power meter│
   └──────────────┘
```

L'iPhone è l'orchestratore: parla col rullo, riceve HR dall'orologio, calcola, registra, comanda.

### 2.5 Dettaglio protocolli del TACX FLUX (la parte più tecnica)

Il FLUX espone due "lingue" di comunicazione:

- **ANT+ FE-C** (Fitness Equipment Control): standard ANT+. Problema: **iOS non supporta ANT+ nativamente** (servirebbe un dongle, scomodo). Su iOS si usa il Bluetooth.
- **Bluetooth Low Energy**, con questi servizi rilevanti:
  - **FTMS — Fitness Machine Service** (UUID `0x1826`): è lo standard aperto da preferire. Caratteristiche chiave:
    - *Indoor Bike Data* (`0x2AD2`): notifica potenza, cadenza, velocità.
    - *Fitness Machine Control Point* (`0x2AD9`): qui **scrivi i comandi**.
      - `Set Target Power` → **ERG mode**.
      - `Set Indoor Bike Simulation Parameters` (grade, wind, Crr, Cw) → **SIM mode** (è qui che mappi la pendenza del percorso reale).
  - **Cycling Power Service** (`0x1818`): potenza/cadenza in lettura.
  - **Cycling Speed & Cadence** (`0x1816`): velocità/cadenza.
  - **Protocollo proprietario Tacx**: alcuni modelli espongono anche un servizio Tacx custom; utile come fallback se FTMS non è completo sul tuo specifico FLUX.

**Strategia di astrazione:** definisci un protocollo `TrainerControl` nel Domain con metodi tipo `setTargetPower(_:)` e `setSimulation(grade:totalWeight:)`. Poi implementa adattatori concreti (`FTMSAdapter`, `TacxAdapter`) che parlano il BLE. Al primo collegamento, l'app fa *capability discovery* e sceglie l'adapter migliore. Verifica sempre sul tuo esemplare specifico quali servizi sono effettivamente pubblicizzati (usa un'app come nRF Connect per ispezionare i GATT services prima di scrivere codice).

---

## 3. Scaricare percorsi reali: analisi e API disponibili

### 3.1 Il problema, scomposto in 3 sotto-problemi

Per "pedalare un posto vero" indoor servono tre cose distinte:

1. **Geometria** del percorso: la polyline (sequenza di lat/lon) della strada reale.
2. **Profilo altimetrico**: la quota lungo il percorso, da cui si deriva la **pendenza %** punto per punto.
3. **Mapping verso il rullo**: tradurre la pendenza a una certa distanza in un comando *Set Simulation* da inviare al FLUX man mano che avanzi virtualmente.

La (1) e la (2) possono venire dalla stessa fonte (un file GPX già con quote) o da fonti diverse (geometria da una API + quote arricchite da un servizio di elevazione).

### 3.2 Sorgenti dei percorsi — opzioni e stato attuale delle API

Premessa importante sullo scenario API (situazione 2024→2026): a fine 2024 **Strava ha inasprito molto i termini della propria API**. Le restrizioni principali, ribadite nei documenti più recenti, riguardano il divieto di mostrare i dati di un utente a soggetti diversi dall'utente stesso e il divieto di usare i dati per addestrare modelli di IA; inoltre l'accesso al programma sviluppatori è discrezionale e revocabile in qualsiasi momento. Per una app **personale e single-user** (mostri solo i *tuoi* dati a te stesso) Strava resta tecnicamente utilizzabile, ma è una base fragile e poco consigliabile come dipendenza centrale.

| Fonte | Cosa offre | Accesso API | Idoneità per il tuo caso |
|-------|-----------|-------------|--------------------------|
| **Import file GPX/FIT/TCX** | Geometria + quote da qualsiasi app/dispositivo | Nessuna API: l'utente importa il file | ⭐ **Base consigliata.** Zero dipendenze, sempre funzionante, offline. Da implementare comunque |
| **OpenRouteService** | Routing ciclistico + **elevazione**, basato su OpenStreetMap | API REST gratuita (con quota), self-host possibile | ⭐ **Ottima** per generare/cercare percorsi e arricchire le quote. Aperta, niente vincoli stile Strava |
| **OpenStreetMap / Overpass + GraphHopper / Valhalla** | Routing open self-hosted | Open source | Massima libertà e controllo, più lavoro infrastrutturale |
| **Komoot** | Ampio catalogo percorsi (forte su gravel/MTB), highlights community | API esiste ma accesso partner limitato; integrazione spesso via export GPX | Buona come *sorgente di file* per l'utente, meno come API pubblica aperta |
| **Ride with GPS** | Editor avanzato, ottimi profili altimetrici, export GPX/TCX/KML flessibili | API disponibile (programma sviluppatori) | Buona, molto apprezzata per cue sheet ed export precisi |
| **Strava** | Enorme catalogo segmenti/route, discovery sociale | API ristretta dal 2024, accesso discrezionale | Usabile solo per uso personale dei *propri* dati; non farne la dipendenza principale |
| **Garmin Connect** | Percorsi/attività dell'utente Garmin | API via Garmin Developer Program (Health/Activity API) | Sensata se l'utente è nell'ecosistema Garmin |
| **Mapbox** | Mappe, terrain, routing | API a consumo | Ottima per la parte *visuale* (mappa/3D) più che per il catalogo percorsi |

### 3.3 Profilo altimetrico e calcolo della pendenza

Se la fonte non ha quote affidabili (i GPS sportano rumore notevole sull'altimetria), arricchiscile con un servizio di elevazione:

| Servizio | Note |
|----------|------|
| **OpenRouteService Elevation** | Gratuito con quota, OSM/SRTM, ottimo default |
| **Open-Elevation** | Open source, self-host possibile, gratuito |
| **Google Elevation API** | Preciso, a pagamento, con quote |
| **Mapbox Terrain-RGB / Tilequery** | Quote da tile raster, comodo se usi già Mapbox |

**Attenzione al rumore:** la pendenza grezza calcolata punto-punto da quote GPS è inutilizzabile (oscilla tra +30% e −30% in pochi metri). Serve **smoothing**: ricampiona la traccia a passo costante (es. ogni 10–25 m), applica un filtro (media mobile o spline) sulla quota, poi calcola `pendenza = Δquota / Δdistanza`. Limita inoltre la pendenza al range che il FLUX può simulare e applica un piccolo *lag* per evitare scatti di resistenza.

### 3.4 Raccomandazione architetturale per i percorsi

Strategia a 3 livelli, dal più robusto al più "ricco":

1. **MVP — Import GPX/FIT/TCX** (sempre presente). L'utente prende un percorso da dove vuole (Strava, Komoot, RWGPS, registrato da un Garmin) e lo importa. Zero dipendenze da API instabili. Questo da solo soddisfa già il tuo R4.
2. **Discovery integrata — OpenRouteService** (+ OSM). Cerca/genera percorsi dentro l'app senza i vincoli di Strava, con elevazione inclusa.
3. **Integrazioni opzionali** — Ride with GPS / Garmin Connect / Strava (solo dati personali) come connettori "nice to have", isolati dietro l'interfaccia `RouteProvider` così che, se una API cambia o viene chiusa, l'app non si rompe.

Tutto passa per un'unica astrazione di dominio:

```swift
protocol RouteProvider {
    func search(query: RouteQuery) async throws -> [RouteSummary]
    func fetch(id: RouteID) async throws -> Route   // geometria + quote
}
// Implementazioni: GPXFileProvider, OpenRouteServiceProvider,
//                  RideWithGPSProvider, StravaProvider(personalOnly) ...
```

### 3.5 Da percorso a sessione SIM

Pipeline di conversione (Domain layer):

```
GPX/route  →  ricampiona a passo fisso (10–25 m)
           →  arricchisci/pulisci quote (elevation service + smoothing)
           →  calcola pendenza per segmento
           →  costruisci "RouteProfile": [distanza → grade]
durante il ride:
   posizione virtuale = ∫ velocità dt
   grade corrente = lookup(RouteProfile, posizione)
   TrainerControl.setSimulation(grade: ..., totalWeight: ...)
```

---

## 4. Progetto dettagliato dei componenti

Di seguito i moduli da realizzare, raggruppati per livello. Per ciascuno: responsabilità, input/output, tecnologia.

### 4.1 Data / Infrastructure

**`BluetoothCentralManager`**
Gestione bassa di CoreBluetooth: scan, connessione, scoperta servizi/caratteristiche, sottoscrizione notifiche, gestione stato e riconnessione automatica.
*In:* richieste connect/disconnect. *Out:* stream di valori grezzi + eventi di stato. *Tech:* CoreBluetooth.

**`TrainerService` (+ `FTMSAdapter`, `TacxAdapter`)**
Implementa `TrainerControl`. Traduce i comandi di dominio (target power / simulazione) in scritture sul *Fitness Machine Control Point* e parsa l'*Indoor Bike Data*. Esegue capability discovery e sceglie l'adapter.
*In:* `setTargetPower`, `setSimulation`. *Out:* `TrainerMetrics` (power, cadence, speed). *Tech:* CoreBluetooth, FTMS.

**`HeartRateService`**
Due sorgenti dietro un'unica interfaccia: (a) Apple Watch via WatchConnectivity, (b) fascia BLE via Heart Rate Service standard. Selezione e priorità della sorgente.
*Out:* stream HR (bpm) + qualità segnale. *Tech:* CoreBluetooth + WatchConnectivity.

**`RouteRepository` (+ providers)**
Implementa i vari `RouteProvider` (file, ORS, ecc.), caching offline dei percorsi scaricati.
*Tech:* URLSession, parser GPX/FIT, SQLite/file storage.

**`ElevationService`**
Arricchimento quote + smoothing del profilo altimetrico.
*Tech:* ORS/Open-Elevation + algoritmo di filtro.

**`PersistenceRepository`**
Modello (atleta, workout, sessioni, percorsi) in SwiftData; record time-series ad alta frequenza in SQLite (tabella append-only, salvataggio incrementale anti-crash).

**`ExportService`**
Esporta una sessione in FIT/TCX/GPX e salva in HealthKit; opzionale upload (Strava personale, Garmin, file/AirDrop).

**`HealthKitGateway`** (lato iPhone) e **Watch Workout App** (lato watchOS)
La Watch app avvia `HKWorkoutSession`, raccoglie HR con `HKLiveWorkoutBuilder` e lo invia all'iPhone; gestisce stato (start/pause/stop) sincronizzato.

### 4.2 Domain

**`WorkoutEngine`**
Macchina a stati dell'allenamento: gestisce sia workout strutturati (sequenza di step ERG) sia ride libero su percorso (SIM). Decide a ogni tick quale comando mandare al rullo.
*In:* tick temporale + metriche correnti + definizione workout/percorso. *Out:* comando target per il `TrainerService` + stato corrente (step, lap, target).

**`SessionRecorder`**
Aggrega in record a 1 Hz tutti i dati (potenza, HR, cadenza, velocità, distanza, pendenza, posizione, quota) e li passa alla persistenza in modo incrementale.

**`MetricsCalculator`**
Calcola NP, IF, TSS, media/3s power, kJ, calorie, zone HR/potenza, distanza/tempo rimanenti, ETA.

**`RouteToSimulationMapper`**
La pipeline del §3.5: da `Route` a `RouteProfile` e lookup pendenza in tempo reale.

**`TrainingZones` / `AthleteProfile`**
FTP, peso, max HR, soglie zone — input per tutti i calcoli.

**UseCases**: `StartSession`, `PauseResumeSession`, `ImportRoute`, `BuildWorkout`, `FinishAndExportSession`, `CalibrateTrainer`.

### 4.3 Presentation (SwiftUI)

- **DeviceConnectionView**: scan e pairing rullo/HR, stato connessione, calibrazione.
- **LiveDashboardView**: la schermata sotto sforzo. Grandi numeri (potenza, HR+zona, cadenza, velocità), distanza fatta/rimanente, tempo trascorso/ETA, **profilo altimetrico con indicatore di posizione e pendenza attuale**, mappa/visuale, controlli lap/pause. Alto contrasto, testi grandi.
- **RouteLibraryView**: ricerca/import percorsi, anteprima mappa+profilo, dettagli (lunghezza, dislivello, pendenza max).
- **WorkoutBuilderView**: editor di workout strutturati (step ERG, ripetute).
- **HistoryView / SessionDetailView**: storico, grafici post-sessione (Swift Charts), confronti, record personali, trend FTP.
- **SettingsView**: profilo atleta, unità, permessi, account/integrazioni.

### 4.4 Watch app

- **WorkoutControlView**: start/pause/stop, HR live grande, metriche essenziali ricevute dall'iPhone, controllo lap.
- **WorkoutSessionManager**: gestione `HKWorkoutSession` + streaming verso iPhone, mantenimento attività in background durante il workout.

### 4.5 Roadmap suggerita per fasi

| Fase | Obiettivo | Contenuto |
|------|-----------|-----------|
| **MVP** | "Pedalo e registro" | Connessione FLUX (FTMS), lettura potenza/cadenza/velocità, ERG base, HR da Watch, dashboard live, registrazione + export FIT, import GPX, SIM mode su percorso importato con smoothing pendenza |
| **v1** | Esperienza completa | Workout builder strutturati, metriche avanzate (NP/IF/TSS), storico+grafici, mappa sincronizzata, calibrazione, riconnessione robusta, fascia BLE alternativa |
| **v2** | Ricchezza & integrazioni | Discovery percorsi (OpenRouteService), 3D/Mapbox, integrazioni Strava/Garmin/RWGPS, analisi trend FTP, sync cloud |

---

### Note finali e rischi tecnici da tenere d'occhio

- **Verifica i GATT service del tuo specifico FLUX** prima di scrivere l'adapter (ispeziona con nRF Connect): le capability variano tra FLUX, FLUX S e FLUX 2.
- **Apple Watch ≠ fascia cardio BLE**: pianifica fin da subito la Watch app companion; non è un dettaglio rimandabile.
- **Dipendenze da API esterne fragili** (Strava in primis): tienile sempre dietro un'interfaccia e non renderle critiche. L'import GPX deve bastare a far funzionare tutto.
- **Smoothing della pendenza**: è la differenza tra una SIM realistica e un'esperienza con scatti di resistenza fastidiosi.
- **Dati sanitari = obblighi**: permessi HealthKit, privacy policy, e conformità per la pubblicazione su App Store.

Non sono un avvocato: i termini delle API citate (Strava in particolare) vanno verificati nei rispettivi accordi sviluppatore aggiornati prima di costruirci sopra una funzionalità.
