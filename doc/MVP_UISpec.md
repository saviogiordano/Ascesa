# Specifica UI/UX MVP — Ascesa Indoor Trainer

Specifica delle schermate e componenti visivi per la Fase MVP. Ogni sezione definisce struttura, contenuto, stati e comportamenti. Il prototipo HTML in `prototipo/` è la fonte visiva di riferimento.

---

## Convenzioni

- Sfondo app: `Color.indigoBackground` (`#1E2A52`)
- Card / superfici: `.ultraThinMaterial` su sfondo indigo, oppure `Color(hex: 0x1E2533)` (scuro neutro)
- Raggio angoli card: 18–26 pt (`Spacing.lg` → `Spacing.xl + 2`)
- Tipografia numeri metrici: `Typography.metricHero`, tabular digits, `design: .rounded`
- Testo secondario / label: `Typography.metricLabel` + `.textCase(.uppercase)` + `tracking(0.6)`
- Accent: `.amber` (`#FFB84D`) — CTA, tab attivo, badge
- Colori zona: `Zone.color` (Z1 blu → Z5 rosso); vedi `ZoneColors.swift`
- Tutti i numeri live usano `.monospacedDigit()` per evitare saltelli layout
- Padding bordo schermata: `Spacing.lg` (16 pt) laterale

---

## 1. Tab Bar

Barra fissa in fondo, 5 tab, sfondo traslucido (`.ultraThinMaterial`). Tab attivo in `.amber`.

| Tab | Icona SF Symbol | Label |
|---|---|---|
| Home | `house.fill` | Home |
| Percorsi | `map.fill` | Percorsi |
| Allena | `bolt.fill` | Allena |
| Storico | `clock.fill` | Storico |
| Profilo | `person.fill` | Profilo |

---

## 2. HomeView

**Navigazione:** tab bar → "Home"

### Layout (scroll verticale)

```
┌────────────────────────────────────────┐
│ [TopBar large]                         │
│ "Ciao, {nome}"          [● N device] │
│  Lunedì 9 giugno · pronto a salire     │
├────────────────────────────────────────┤
│ [SessionResumeCard] ← solo se sessione │
│  in corso (WorkoutEngineState ≠ idle)  │
├────────────────────────────────────────┤
│ [Card Percorso Selezionato]            │
│  ┌─ immagine/mappa placeholder ──────┐ │
│  │  "PERCORSO SELEZIONATO"           │ │
│  │  Nome percorso  (font 22pt bold)  │ │
│  │  Sottotitolo (dislivello, zona)   │ │
│  └───────────────────────────────────┘ │
│  [ElevationProfileView h=56, snapshot] │
│  km · +m · media% · max%              │
│  [CTA "Pedala il percorso"] [🔍]      │
├────────────────────────────────────────┤
│ [Card Workout ERG]                     │
│  [AnteprimeIntervalBar w=56 h=44]      │
│  "WORKOUT ERG"  Nome workout           │
│  Sottotitolo · 50:00          [›]      │
├────────────────────────────────────────┤
│ ATTIVITÀ RECENTI                       │
│ [HistoryRow] × 2                       │
└────────────────────────────────────────┘
```

### Componenti chiave

**Badge device** (in alto a destra nella TopBar):
- Pillola con pallino colorato (`DeviceStatusDot`) + "N device"
- Verde glow se tutti connessi, arancio se parziale, grigio se nessuno
- Tap → naviga a `DeviceConnectionView`

**Card percorso selezionato:**
- Area mappa/immagine placeholder (`ph-stripe`) h=132, con gradiente in basso
- `ElevationProfileView` a larghezza piena, h=56, snapshot (non animato, `marker` = posizione virtuale corrente se sessione aperta)
- Stat row: distanza km / dislivello +m / pendenza media % / pendenza max %
- CTA primaria `.amber`: "Pedala il percorso" → avvia SIM; bottone ghost "🔍" → `RouteLibraryView`

**Card workout ERG:**
- Anteprima `IntervalBar` compatta 56×44 pt
- Tap su card → `WorkoutBuilderView` (Fase v1)

**SessionResumeCard** (visibile solo se `WorkoutEngineState == .active || .paused`):
- Sfondo scuro con bordo `.amber`, icona play, "Riprendi la sessione", tempo + km + modalità

### Stati

| Stato | Comportamento |
|---|---|
| Nessun percorso selezionato | Card percorso mostra empty state con CTA "Importa GPX" |
| Sessione in corso | `SessionResumeCard` appare in cima |
| 0 device connessi | Badge grigio, senza glow |

---

## 3. DeviceConnectionView

**Navigazione:** tap badge device in HomeView, o sheet modale al lancio della sessione se nessun dispositivo connesso.

### Layout (scroll verticale, no tab bar)

```
┌────────────────────────────────────────┐
│ [← Indietro]    Dispositivi            │
├────────────────────────────────────────┤
│ RULLO SMART                            │
│ ┌──────────────────────────────────┐   │
│ │ [BT] TACX FLUX S                 │   │
│ │      FTMS · potenza, cadenza     │   │
│ │      ● Connesso            [›]   │   │
│ ├──────────────────────────────────┤   │
│ │ Calibrazione (spindown)          │   │
│ │ Ultima: 4 giorni fa        [›]   │   │
│ └──────────────────────────────────┘   │
├────────────────────────────────────────┤
│ FREQUENZA CARDIACA                     │
│ ┌──────────────────────────────────┐   │
│ │ [⌚] Apple Watch                 │   │
│ │      HealthKit · sorgente primaria│  │
│ │                         [PRIMARIA]│  │
│ ├──────────────────────────────────┤   │
│ │ [♥] Fascia toracica BLE          │   │
│ │      Ripiego se Watch assente    │   │
│ │      ● Pronta                    │   │
│ └──────────────────────────────────┘   │
│ [nota: Watch trasmette via companion]  │
├────────────────────────────────────────┤
│ SENSORI OPZIONALI                      │
│ ┌──────────────────────────────────┐   │
│ │  + Aggiungi sensore              │   │
│ │    Cadenza, velocità, power meter│   │
│ └──────────────────────────────────┘   │
└────────────────────────────────────────┘
```

### Sezioni e stati device

**Rullo Smart:**
- `DeviceRow`: icona BT colorata `.amber` se connesso; nome + protocollo (FTMS / Tacx)
- `DeviceStatusDot` + label testuale stato: "Connesso" / "Ricerca…" / "Disconnesso"
- Sotto la divider: row calibrazione spindown (tap espande flusso calibrazione)

**Flusso calibrazione spindown:**
1. Idle: "Calibrazione (spindown) · Ultima: N giorni fa" + chevron
2. In corso: label "Pedala fino a 35 km/h e ferma…" + progress bar
3. Completato: check verde + "Calibrato — offset X Nm"

**Frequenza Cardiaca:**
- Watch: badge amber "PRIMARIA" (no dot, viene gestito via companion)
- Fascia BLE: `DeviceStatusDot` + stato "Pronta" / "Connessa" / "Non trovata"
- Nota esplicativa in piccolo sul funzionamento Watch/HealthKit

**Sensori Opzionali:**
- Row con icona "+" → lista opzionale future integrazioni (cadenza BLE, power meter)

### Stati globali

| Stato | UI |
|---|---|
| Scanning | Spinner o pulse animation sul `DeviceStatusDot` del rullo |
| Connessione fallita | Alert inline con "Riprova" |
| Nessun Bluetooth | Alert "Abilita Bluetooth nelle Impostazioni" |

---

## 4. LiveDashboardView — Struttura condivisa

Schermata fullscreen (no tab bar), portrait, sempre accesa durante la sessione.

### Header fisso (tutte le varianti)

```
┌────────────────────────────────────────┐
│ [SIM|ERG]    00:42:17    [🔵🟢]       │
│ Stelvio · Bormio → Cima   12:34 al GPM│
│ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░  (progress) │
└────────────────────────────────────────┘
```

- Toggle SIM/ERG (`Segmented`): cambia modalità al volo
- Timer centrale: `HH:mm:ss`, 22 pt bold tabular
- Status dots: icona BT + Watch (verde se connesso)
- Riga sotto: nome percorso/workout + ETA (km al GPM in SIM, tempo alla fine in ERG)
- Barra progresso sottile: `.amber` su sfondo scuro

### ContextBand (SIM)

```
┌────────────────────────────────────────┐
│  7.4  % pendenza       1.247 m slm     │
│                        +342 m al GPM   │
│ [ElevationProfileView — "prossimi 1.5km"]│
│  ◄ 23,4 km    prossimi 1,5 km →        │
└────────────────────────────────────────┘
```

- Pendenza corrente: font ~30–44 pt, colorata con `Color.gradeColor(for:)`
- Altitudine e dislivello rimanente al GPM a destra
- `ElevationProfileView` in modalità "ahead": finestra da -150m a +1600m dalla posizione
- Label km percorsi e freccia "prossimi 1,5 km"

### ContextBand (ERG)

```
┌────────────────────────────────────────┐
│  INTERVALLO 2/5          02:14         │
│  280  W target           poi Rec 150W  │
│ [IntervalBar con cursore posizione]    │
└────────────────────────────────────────┘
```

- Blocco corrente: nome + target W colorato per zona
- Countdown fine blocco a destra
- Prossimo blocco in grigio sotto
- `IntervalBar` con indicatore posizione

### Dock (tutte le varianti)

```
┌────────────────────────────────────────┐
│   [Lap ○]    [● Pausa ●●]   [Flag ○]  │
│     54pt          72pt          54pt   │
└────────────────────────────────────────┘
```

- Lap: `RoundBtn` 54 pt, SF Symbol `flag.fill` verde
- Pausa/Riprendi: `RoundBtn` 72 pt, `.amber` background quando attivo
- Termina: `RoundBtn` 54 pt, `zone5` rosso, richiede conferma via `.confirmationDialog`

### Finish overlay

Quando `WorkoutEngineState == .finished`: overlay blur con icona bandiera amber, stats (tempo, km, kJ), due CTA: "Nuova sessione" (ghost) e "Vedi riepilogo" (amber → `SessionSummaryView`).

---

## 5. LiveDashboardView — Variante A (Focus)

**Destinazione:** ciclisti che vogliono monitorare la potenza in modo prioritario.

### Body

```
┌────────────────────────────────────────┐
│           POTENZA                      │
│                                        │
│           287          W               │
│           (font ~118pt, zona Z4)       │
│  ░░░░░░▓▓▓▓▓▓▓░░░  ← ZoneScale 5seg  │
│  media 251W  NP 264W  3s 291W          │
├────────────────────────────────────────┤
│  [♥]  165     [◎]  88     [→]  28.4   │
│  bpm          rpm          km/h        │
│  CARDIO      CADENZA     VELOCITÀ      │
├────────────────────────────────────────┤
│  [ContextBand]                         │
└────────────────────────────────────────┘
```

**Potenza eroe:**
- Font `Typography.metricHero(size: 118)`, colore `Zone.color` della zona potenza corrente
- `ZoneScale`: 5 segmenti colorati, uno attivo (`opacity: 1`, altri `0.22`) + glow
- Riga sub: media / NP / 3s rolling in testo piccolo secondario

**Metriche secondarie (row):**
- HR colorato con `Zone.color` della zona HR corrente
- Cadenza e velocità in colore primario
- Icona + valore grande (~30pt) + unità + label uppercase sotto
- Divider top e bottom

---

## 6. LiveDashboardView — Variante B (Griglia bilanciata)

**Destinazione:** visione equilibrata di tutte le metriche simultaneamente.

### Body

```
┌───────────────────┬────────────────────┐
│ POTENZA           │ CARDIO             │
│                   │                    │
│ 287           W   │ 165           bpm  │
│ (zona 4 amber)    │ (zona 3 giallo)    │
│ [ZoneBar]         │ [ZoneBar HR]       │
├───────────────────┼────────────────────┤
│ CADENZA           │ VELOCITÀ           │
│                   │                    │
│  88          rpm  │  28.4      km/h    │
│                   │                    │
│                   │                    │
└───────────────────┴────────────────────┘
│ media 251W  NP 264W  38 kJ             │
├────────────────────────────────────────┤
│ [ContextBand]                          │
```

**GridTile:**
- Sfondo `.ultraThinMaterial` + bordo sinistra colorato per zona (`inset 4px 0 0 zoneColor`)
- Label 11pt uppercase + icon in alto a sinistra
- Valore ~50pt bold + unità 15pt secondario
- `ZoneBar` in fondo (solo Potenza e Cardio; Cadenza/Velocità: spazio vuoto)

---

## 7. LiveDashboardView — Variante C (Terreno protagonista)

**Destinazione:** SIM — il profilo del percorso è la protagonista visiva.

### Body

```
┌────────────────────────────────────────┐
│  7.4  % pendenza       1.247 m slm     │
│                        +342 m al GPM   │
│                                        │
│  [ElevationProfileView h=188]          │
│  (profilo occupa ~50% dello schermo)   │
│                                        │
│  ← 23,4 km    prossimi 1,5 km →       │
├────────────────────────────────────────┤
│  [W]287  [♥]165  [◎]88  [→]28.4      │
│  (4 metriche compatte in row unica)    │
└────────────────────────────────────────┘
```

- `ElevationProfileView` h=188, modalità "ahead"
- Metriche in fondo: 4 `MiniMetric` (`icon + valore 22pt + unità`) in HStack
- Potenza e HR colorati per zona
- Non mostra ContextBand separata (è già la body)

---

## 8. ElevationProfileView

Componente riusabile (Swift Charts + Canvas). Usato in HomeView (snapshot), RouteLibraryView (card), LiveDashboard (live).

### Specifiche

```
Colori area per pendenza:
  < 2%   → verde scuro  #8DB48E  (piano)
  2–4%   → giallo       #FFD166
  4–7%   → arancio      #F4994A
  7–10%  → rosso        #E24B4B
  > 10%  → rosso scuro  #9B1C1C

Opacità area: 0.82
Stroke cima: bianco rgba(255,255,255,0.55), 1.5pt

Indicatore posizione:
  Linea verticale bianca 1.5pt
  Cerchio bianco r=4.5 sul punto quota corrente
  (solo in LiveDashboard, non in snapshot)

Zona già percorsa:
  Rettangolo nero trasparente (opacity 0.42) da 0 alla posizione
  (oscura visivamente il tratto già fatto)

Label km:
  In basso a sinistra: "◄ 23,4 km" (posizione corrente)
  In basso a destra: "prossimi 1,5 km →"

Label pendenza corrente:
  Testo 12pt bold bianco centrato sopra la linea posizione

Modalità:
  "full"   → mostra tutto il percorso
  "ahead"  → finestra [-150m … +1600m] dalla posizione (LiveDashboard)
  "card"   → full, no indicatore posizione, no label (HomeView / RouteLibrary)
```

### Parametri View

| Parametro | Tipo | Default | Note |
|---|---|---|---|
| `profile` | `RouteProfile` | — | Obbligatorio |
| `virtualPositionM` | `Double?` | `nil` | Se nil: nessun indicatore |
| `mode` | `ProfileMode` | `.full` | `.full` / `.ahead` / `.card` |
| `height` | `CGFloat` | `90` | Altezza SVG |
| `showGradeLabel` | `Bool` | `true` | Testo % sulla linea |

---

## 9. RouteLibraryView

**Navigazione:** tab "Percorsi", o bottone 🔍 in HomeView.

### Layout

```
┌────────────────────────────────────────┐
│ [TopBar large] Percorsi    [↑ GPX]     │
├────────────────────────────────────────┤
│ [🔍 Cerca salite, città, GPM…]        │
├────────────────────────────────────────┤
│ [Tutti][Salita][Gravel][Pianura][♥]   │
│  ← scroll orizzontale chips →          │
├────────────────────────────────────────┤
│ [RouteCard]                            │
│ ┌──────────────────────────────────┐   │
│ │ [thumbnail] │ Nome percorso      │   │
│ │  (96pt w)   │ Sottotitolo        │   │
│ │             │ [ElevationProfile  │   │
│ │             │  w=210 h=34 card]  │   │
│ │             │ 21.4km +1842m 7.2% │   │
│ └──────────────────────────────────┘   │
│ [RouteCard] × N                        │
│                                        │
│ ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  │
│   + Importa file GPX / FIT / TCX     │
│ └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘  │
└────────────────────────────────────────┘
```

### RouteCard

- Thumbnail a sinistra (96pt): mappa placeholder (`ph-stripe` con icona montagna)
- Destra: nome (16pt 750), sottotitolo zona/tipo
- `ElevationProfileView` in modalità `.card`, w=210 h=34
- Stats: km / dislivello / pendenza media colorata per `Color.gradeColor`

### Bottoni azione

- `[↑ GPX]` in TopBar → `DocumentPicker` per import `.gpx`, `.fit`, `.tcx`
- Import dashed button in fondo alla lista → stessa azione
- Tap su RouteCard → `RouteDetailView` (push)

### Filtri chips (scroll orizzontale)

Chip amber se attivo, ghost se non attivo. Filtri: Tutti / Salita / Gravel / Pianura / Preferiti.

### Empty state

Quando lista vuota: icona mappa, "Nessun percorso", CTA "Importa il tuo primo GPX".

---

## 10. SessionSummaryView

**Navigazione:** push da finish overlay della dashboard, o tap su HistoryRow.

### Layout (scroll verticale)

```
┌────────────────────────────────────────┐
│ [Header hero — mappa/placeholder]      │
│  [← Indietro]                          │
│  Nome sessione / data                  │
│                           [↑ Esporta]  │
├────────────────────────────────────────┤
│ [Grid 4×2 metriche chiave]             │
│  distanza  │ tempo   │ dislivello │ NP │
│  pot.media │ lavoro  │ HR media   │ IF │
├────────────────────────────────────────┤
│ POTENZA ─────────────── media 251 W   │
│ [Swift Charts — area potenza (1Hz)]    │
├────────────────────────────────────────┤
│ FREQUENZA CARDIACA ──────── media 165  │
│ [Swift Charts — linea HR]             │
├────────────────────────────────────────┤
│ ALTIMETRIA ──────────────── +842 m    │
│ [Swift Charts — area altitudine]      │
│   (solo se sessione SIM)              │
├────────────────────────────────────────┤
│ DISTRIBUZIONE ZONE DI POTENZA          │
│ [Barchart verticale Z1–Z5, colorato]  │
├────────────────────────────────────────┤
│ [CTA "Esporta FIT"]   [Condividi]     │
└────────────────────────────────────────┘
```

### Grid metriche

8 celle (4 colonne × 2 righe), sfondo `.surface`, divider 1pt. Ogni cella: valore grande 16pt bold + label 9.5pt uppercase.

| Cella | Valore | Label |
|---|---|---|
| 1 | 42,3 km | distanza |
| 2 | 1:48:22 | tempo |
| 3 | +842 m | dislivello |
| 4 | 264 W | NP |
| 5 | 251 W | pot. media |
| 6 | 127 kJ | lavoro |
| 7 | 165 bpm | HR media |
| 8 | 0.82 | IF |

### Grafici Swift Charts

- **Potenza:** `AreaMark` colore Z4 fill + stroke, baseline 0, risoluzione 1 Hz (max 3600 punti per ora)
- **HR:** `LineMark` colore Z5/rosso, risoluzione 1 Hz
- **Altitudine:** `AreaMark` colore `.amber` fill, solo in SIM
- **Distribuzione zone:** `BarMark` verticale per Z1–Z5, colore zona, altezze relative

### CTA Export

- "Esporta FIT" → `ExportRepository.exportFIT(...)` → `ShareSheet`
- Conferma export con animazione breve checkmark

---

## 11. AthleteProfileView

**Navigazione:** tab "Profilo" (in MVP = Profilo + Impostazioni insieme).

### Layout (scroll)

```
┌────────────────────────────────────────┐
│ [TopBar large] Profilo                 │
├────────────────────────────────────────┤
│ ┌──────────────────────────────────┐   │
│ │  [Avatar initials circle]        │   │
│ │  Nome atleta  · Cat. · Zona       │   │
│ │  FTP: 265W  Peso: 71kg           │   │
│ │  W/kg: 3.73  FC max: 185 bpm    │   │
│ └──────────────────────────────────┘   │
├────────────────────────────────────────┤
│ ONBOARDING / MODIFICA VALORI           │
│ FTP (W)       [_____]  stepper ±5     │
│ Peso (kg)     [_____]  stepper ±0.5   │
│ FC Massima    [_____]  stepper ±1     │
├────────────────────────────────────────┤
│ ZONE DI POTENZA (calcolate da FTP)     │
│ ┌─ Z1 ─ Recupero attivo ── ≤146 W ─┐  │
│ │ Z2 ─ Resistenza ─────── 147–198  │  │
│ │ Z3 ─ Soglia aerobica ── 199–238  │  │
│ │ Z4 ─ Soglia lattica ─── 239–278  │  │
│ └─ Z5 ─ VO2max ──────────── 279+ W ┘  │
├────────────────────────────────────────┤
│ ZONE CARDIACHE (calcolate da FC max)   │
│ [stessa struttura per HR ×5]          │
└────────────────────────────────────────┘
```

### Form input

- Campo FTP: `TextField` numerico + stepper ±5 W
- Campo Peso: `TextField` + stepper ±0.5 kg
- Campo FC Max: `TextField` + stepper ±1 bpm
- Validazione: FTP 50–600, Peso 30–200, FC max 100–230
- Al salvataggio: aggiorna `AthleteProfile` in SwiftData + ricalcola zone in tempo reale

### ZoneTable (riusabile)

Ogni riga: quadratino 10×10 pt del colore zona + "Z{N} · Nome" + range numerico (calcolato live da FTP/maxHR).

---

## 12. Watch Companion App — WorkoutControlView

Schermata unica fullscreen su sfondo nero.

### Layout

```
┌──────────────────────────┐
│ ● Ascesa          9:41   │  ← status row (dot rosso=attivo, amber nome)
├──────────────────────────┤
│                          │
│ CARDIO · Z3              │  ← icon cuore + zona, colore zona
│                          │
│ 165          bpm         │  ← font ~72pt, colore zona HR
│                          │
│  287 W    00:42:17       │  ← potenza (colore zona potenza) + timer
│                          │
├──────────────────────────┤
│  [Lap ○]    [▶ Pausa]   │  ← bottoni circolari h=44
└──────────────────────────┘
```

### Specifiche

- HR: font 72pt 750, colorato `Zone.color` della zona HR corrente
- Potenza: font 22pt 750, colorato `Zone.color` zona potenza
- Timer: font 22pt 750 tabular
- Bottone Lap: sfondo `zone2.opacity(0.16)`, icona verde
- Bottone Pausa/Riprendi: sfondo `amber.opacity(0.16)`, icona amber
- Status dot: rosso pulsante se sessione attiva, grigio se in pausa/idle

### Stato "iPhone disconnesso"

Overlay che copre tutta la schermata: messaggio "Apri Ascesa su iPhone per iniziare", icona iPhone.

---

## 13. Selezione variante dashboard

Preferenza persistita in `UserDefaults`. Accessibile da:
- Bottone "Layout" nella TopBar della dashboard (3 icone layout)
- `AthleteProfileView` → sezione Impostazioni Dashboard

Varianti:
- **A** (Focus) — default per ciclisti experienced, SIM e ERG
- **B** (Griglia) — default per utenti nuovi
- **C** (Terreno) — solo SIM, visualizzazione paesaggistica

---

---

## Fase v1 — Autenticazione e gestione account

> **Nota fase:** le schermate seguenti appartengono alla **Fase v1**, non all'MVP.
> In MVP l'app funziona interamente in **modalità ospite** (offline, dati locali) senza alcuna schermata di login.
> Fonte di riferimento: `doc/Addendum_Autenticazione_Multiutente.md`.

### Roadmap auth per fase

| Fase | Cosa è disponibile |
|---|---|
| **MVP** | Modalità ospite/offline; nessuna schermata auth; dati locali già strutturati per-utente (campo `userId` predisposto) |
| **v1** | WelcomeView · SignUpView · SignInView · ForgotPasswordView · EmailVerificationView · AthleteOnboardingView · AccountSettingsView · Sign in with Apple · sblocco biometrico · cancellazione account |
| **v2** | Sync multi-dispositivo · Google login (se incluso → SiwA obbligatorio) · 2FA |
| **v3** | Ruoli coach–atleta · condivisione · account team |

---

### 14. WelcomeView

**Prima schermata** che appare a chi non ha un account o ha fatto logout.

```
┌────────────────────────────────────────┐
│                                        │
│         [Logo Ascesa]                  │
│         Ascesa                         │
│         Indoor Training                │
│                                        │
│                                        │
│  [CTA primaria — "Registrati"]         │
│  [CTA secondaria — "Accedi"]           │
│  [Ghost — "Inizia come ospite"]        │
│                                        │
│  Continuando accetti i Termini di      │
│  Servizio e la Privacy Policy          │
└────────────────────────────────────────┘
```

- Logo centrato, animazione fade-in al lancio
- CTA primaria `.amber` full-width → `SignUpView`
- CTA secondaria bordo `.amber`, sfondo trasparente → `SignInView`
- Link "ospite" in testo piccolo secondario → accesso diretto alla HomeView senza account
- Footer: link "Termini di Servizio" e "Privacy Policy" (obbligatori App Store)

---

### 15. SignUpView

```
┌────────────────────────────────────────┐
│ [← Indietro]   Crea account           │
├────────────────────────────────────────┤
│                                        │
│  Email        [___________________]   │
│  Password     [___________________]   │
│               [show/hide •••••••••]   │
│                                        │
│  ✓ Min. 8 caratteri                   │
│  ✓ Almeno una maiuscola e un numero   │
│                                        │
│  [CTA "Crea account" — .amber]        │
│                                        │
│  ─────────── oppure ───────────        │
│                                        │
│  [Sign in with Apple — nero std]       │
│                                        │
│  Hai già un account? Accedi           │
└────────────────────────────────────────┘
```

- Validazione password in tempo reale: checklist visiva sotto il campo
- Email validata al blur (formato + dominio minimo)
- CTA disabilitata (grigia) finché i campi non sono validi
- `Sign in with Apple` tramite `ASAuthorizationAppleIDProvider` (bottone standard Apple, non personalizzabile)
- Link "Accedi" in fondo → `SignInView` (pop o replace)
- Al submit → `EmailVerificationView`

---

### 16. SignInView

```
┌────────────────────────────────────────┐
│ [← Indietro]   Accedi                 │
├────────────────────────────────────────┤
│                                        │
│  Email        [___________________]   │
│  Password     [___________________]   │
│                                        │
│  [CTA "Accedi" — .amber]              │
│                                        │
│  Password dimenticata?                 │
│                                        │
│  ─────────── oppure ───────────        │
│                                        │
│  [Sign in with Apple — nero std]       │
│                                        │
│  Non hai un account? Registrati       │
└────────────────────────────────────────┘
```

- Errore credenziali: banner rosso sotto i campi "Email o password non corretti"
- Rate limiting: dopo 5 tentativi falliti → messaggio "Troppi tentativi, riprova tra X minuti"
- "Password dimenticata?" → `ForgotPasswordView`
- Sblocco biometrico: se sessione precedente valida in Keychain → Face ID / Touch ID al lancio, senza mostrare SignInView

---

### 17. ForgotPasswordView

```
┌────────────────────────────────────────┐
│ [← Indietro]   Reimposta password     │
├────────────────────────────────────────┤
│                                        │
│  Inserisci la tua email e ti invieremo │
│  un link per reimpostare la password.  │
│                                        │
│  Email        [___________________]   │
│                                        │
│  [CTA "Invia link" — .amber]          │
│                                        │
│  ─ ─ ─ ─ (dopo invio) ─ ─ ─ ─ ─ ─   │
│                                        │
│  ✓ Email inviata a nome@email.com     │
│    Controlla la tua casella (e spam).  │
│                                        │
│  [Invia di nuovo — ghost, con timer]  │
└────────────────────────────────────────┘
```

- Dopo l'invio: feedback inline (non navigate away), bottone "Invia di nuovo" con cooldown 60s
- Nessuna conferma se l'email esiste o meno (security best practice: risposta sempre uguale)

---

### 18. EmailVerificationView

Appare dopo `SignUpView` quando l'account è creato ma l'email non è ancora verificata.

```
┌────────────────────────────────────────┐
│              Verifica email            │
│                                        │
│  [Icona busta con checkmark]          │
│                                        │
│  Abbiamo inviato un link a:           │
│  nome@email.com                        │
│                                        │
│  Clicca il link nell'email per         │
│  completare la registrazione.          │
│                                        │
│  [CTA "Invia di nuovo" — con timer]   │
│                                        │
│  Email sbagliata? Torna indietro      │
└────────────────────────────────────────┘
```

- App polling o deep link: quando l'utente clicca il link sull'email → app si riapre e avanza automaticamente ad `AthleteOnboardingView`
- "Invia di nuovo" con cooldown 60s, poi 120s, poi 300s (backoff)

---

### 19. AthleteOnboardingView

Appare **una sola volta**, al primo login verificato. Raccoglie i dati minimi per calcolare le zone.

```
┌────────────────────────────────────────┐
│         Configuriamo il tuo profilo   │
│         (1 di 1)                       │
├────────────────────────────────────────┤
│                                        │
│  FTP (Functional Threshold Power)      │
│  [     265      W]  [−5] [+5]         │
│  Non sai il tuo FTP? Usa 200 W        │
│                                        │
│  Peso corporeo                         │
│  [      71      kg] [−0.5] [+0.5]    │
│                                        │
│  Frequenza cardiaca massima            │
│  [     185      bpm] [−1]  [+1]       │
│  Stima approssimativa: 220 − età       │
│                                        │
│  [CTA "Inizia ad allenarti" — .amber] │
│                                        │
│  Puoi modificare questi valori in      │
│  qualsiasi momento nel Profilo.        │
└────────────────────────────────────────┘
```

- Stepper + campo numerico editabile direttamente
- Hint per chi non conosce l'FTP (valore di default 200 W)
- Formula suggerita per FC max (220 − età): mostrata se si sa l'età
- Al salvataggio: crea `StoredAthlete` in SwiftData + lega all'account → naviga a `HomeView`
- Se l'utente era in modalità ospite con dati locali: chiede se migrare i dati (`MigrateGuestData` use case)

---

### 20. AccountSettingsView

**Navigazione:** tab "Profilo" → sezione Account (v1 sostituisce la sezione Impostazioni dell'MVP).

```
┌────────────────────────────────────────┐
│ [TopBar large] Account                 │
├────────────────────────────────────────┤
│ PROFILO ACCOUNT                        │
│ ┌──────────────────────────────────┐   │
│ │ Email: nome@email.com      [›]   │   │
│ │ Password: •••••••••••      [›]   │   │
│ └──────────────────────────────────┘   │
├────────────────────────────────────────┤
│ SICUREZZA                              │
│ ┌──────────────────────────────────┐   │
│ │ Sblocco Face ID / Touch ID  [⬜]  │   │
│ │ Dispositivi attivi (2)      [›]   │   │
│ │ Esci da tutti i dispositivi [›]   │   │
│ └──────────────────────────────────┘   │
├────────────────────────────────────────┤
│ DATI E PRIVACY                         │
│ ┌──────────────────────────────────┐   │
│ │ Esporta i tuoi dati         [›]  │   │
│ │ Consensi e trattamento dati [›]  │   │
│ └──────────────────────────────────┘   │
├────────────────────────────────────────┤
│ [Logout — testo rosso]                 │
├────────────────────────────────────────┤
│ [Elimina account — testo rosso dim]   │
└────────────────────────────────────────┘
```

**Dispositivi attivi:**
- Lista sessioni attive con device, data ultimo accesso, posizione approssimativa
- Bottone "Termina sessione" per ogni dispositivo terzo

**Sblocco biometrico:**
- Toggle: attiva `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`
- Richiede conferma password prima di attivare

**Esporta i tuoi dati:**
- Genera archivio ZIP con: tutte le sessioni in `.fit`, profilo atleta in `.json`, percorsi in `.gpx`
- Obbligatorio per conformità GDPR (diritto alla portabilità)
- Progress indicator durante la generazione

**Consensi e trattamento dati:**
- Lista consensi versioned (uso app / dati sanitari / sync cloud)
- Toggle per revocare il consenso al sync cloud (i dati rimangono locali)

**Elimina account:**
1. Tap → `confirmationDialog` "Sei sicuro? Questa azione è irreversibile."
2. Secondo step → richiesta password per conferma
3. Proposta export dati prima di procedere
4. Cancellazione: `DeleteAccount` use case → rimozione locale (SwiftData + SQLite) + richiesta DELETE al backend
5. Ritorno a `WelcomeView`
- Backend: soft delete (30 gg) → hard delete. Obbligatorio per App Store §5.1.1.

---

### 21. Gestione sessione — comportamenti trasversali

| Evento | Comportamento UI |
|---|---|
| Token scaduto in background | Refresh silenzioso; se fallisce → banner "Sessione scaduta, accedi di nuovo" |
| App aperta dopo inattività (>15 min) | Face ID / Touch ID se abilitato; altrimenti diretto alla HomeView |
| Offline con sessione valida in cache | HomeView funziona normalmente; banner "Nessuna connessione — dati sincronizzati al rientro" |
| Logout con sessione allenamento aperta | Alert "Sessione in corso — vuoi davvero uscire? I dati salvati non andranno persi" |
| Account ospite → registrazione | `MigrateGuestData`: dialog "Vuoi importare i tuoi allenamenti precedenti?" + conferma |

---

*Documento creato: 2026-06-10. Fase: MVP — UI/UX Design.*
*Sezione autenticazione aggiunta da: `doc/Addendum_Autenticazione_Multiutente.md`.*
*Prototipo di riferimento: `prototipo/Ascesa.html` (apri in browser).*
