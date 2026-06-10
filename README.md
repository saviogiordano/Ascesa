# Ascesa — Indoor Trainer

App iOS + watchOS per allenamenti indoor con rullo smart **TACX FLUX** e **Apple Watch**. Controlla la resistenza del rullo in ERG e SIM mode, legge la frequenza cardiaca dall'orologio, simula percorsi reali e registra le sessioni.

---

## Requisiti

| Requisito | Versione minima |
|---|---|
| Xcode | 16 / 26+ |
| Swift | 6.0 |
| iOS | 17.0 |
| watchOS | 10.0 |
| macOS (host) | 14.0 Sonoma+ |
| [xcodegen](https://github.com/XcodeGen/XcodeGen) | 2.40+ |

Hardware necessario per testare le funzionalità core:
- iPhone fisico (Bluetooth + HealthKit non funzionano su simulatore)
- Apple Watch (Serie 6+ consigliata, per `HKWorkoutSession`)
- TACX FLUX / FLUX S / FLUX 2

---

## Setup iniziale

### 1. Clona il repository

```bash
git clone <repo-url>
cd Ascesa
```

### 2. Installa xcodegen

```bash
brew install xcodegen
```

### 3. Genera il progetto Xcode

```bash
cd app
xcodegen generate --spec project.yml
```

Questo crea `app/Ascesa.xcodeproj`. Il file `.xcodeproj` **non è versionato** — va rigenerato dopo ogni modifica a `project.yml`.

### 4. Apri in Xcode

```bash
open app/Ascesa.xcodeproj
```

Al primo avvio Xcode risolve automaticamente le dipendenze SPM (GRDB, CoreGPX). Richiede connessione internet.

### 5. Imposta il Development Team

In Xcode → seleziona il progetto `Ascesa` nel navigator → target **Ascesa** → tab **Signing & Capabilities** → scegli il tuo team Apple Developer.

Ripeti per il target **AscesaWatch**.

---

## Struttura del repository

```
Ascesa/
├── app/                    ← progetto Xcode (sorgente)
│   ├── project.yml         ← spec xcodegen (source of truth)
│   ├── Sources/
│   │   ├── Presentation/   ← SwiftUI views, ViewModels, DesignTokens
│   │   ├── Domain/         ← logica pura (protocolli, modelli, use case)
│   │   ├── Data/           ← BLE, HealthKit, persistenza, export
│   │   └── Watch/          ← companion app watchOS
│   └── Resources/
│       ├── iOS/            ← Info.plist, entitlements, Assets
│       └── Watch/          ← Info.plist, entitlements, Assets
├── doc/                    ← documentazione tecnica e di progetto
│   ├── IndoorTrainer_App_Analisi_e_Progetto.md
│   ├── Addendum_Autenticazione_Multiutente.md
│   ├── Specifiche_Tecniche.md
│   └── Piano_di_Sviluppo.md
├── prototipo/              ← prototipo HTML/CSS/JS (solo reference UI)
└── res/                    ← asset grafici (icona app, SVG sorgente)
```

---

## Dipendenze

| Package | Versione | Uso |
|---|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | ≥ 6.0 | Persistenza time-series sessioni (1 Hz) |
| [CoreGPX](https://github.com/vincentneo/CoreGPX) | ≥ 0.9 | Parsing file `.gpx` |

---

## Build e run

Il progetto ha due scheme indipendenti: **Ascesa** (iOS) e **AscesaWatch** (watchOS).  
L'embedding della Watch app nell'iOS app va configurato su device fisico (Phase MVP) — non funziona sul simulatore per incompatibilità del formato watchOS standalone.

### Scheme Ascesa — iPhone Simulator (sviluppo UI)

Seleziona scheme **Ascesa** + un simulatore iPhone → `⌘R`.

> Bluetooth e HealthKit non funzionano su simulatore. Usare dati mock per sviluppare la UI.

### Scheme AscesaWatch — Watch Simulator (sviluppo Watch UI)

Seleziona scheme **AscesaWatch** + un simulatore Apple Watch → `⌘R`.

I due simulatori non sono collegati: per testare la comunicazione `WCSession` tra iOS e watchOS serve un device fisico.

### Device fisico (testing completo BLE + Watch HR)

1. Connetti iPhone e Apple Watch appaiato al Mac
2. Seleziona scheme **Ascesa** + il tuo iPhone → `⌘R`
3. La Watch app va installata separatamente con scheme **AscesaWatch** + il tuo Apple Watch

> Bluetooth (TACX FLUX), HealthKit e WatchConnectivity richiedono tutti device fisici.

### Rigenerare il progetto

Ogni volta che modifichi `project.yml` (nuovi target, dipendenze, settings):

```bash
cd app && xcodegen generate --spec project.yml
```

> `Ascesa.xcodeproj` è escluso dal `.gitignore` perché generato. Non committarlo.

---

## Continuous Integration

Il workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) si attiva su ogni PR e push su `main`.

| Job | Cosa fa |
|---|---|
| **Build** | `xcodegen generate` → build iOS (`Ascesa`) → build watchOS (`AscesaWatch`) |
| **Test** | Placeholder — si attiva quando il target `AscesaTests` viene aggiunto in Phase MVP |

I pacchetti SPM sono cachati per chiave `project.yml` tramite `actions/cache`.

### Setup repository (prima volta)

Il progetto non ha ancora un repository git. Per collegarlo a GitHub:

```bash
cd /Users/salvatoregiordano/Documents/Progetti/Ascesa
git init
git add .
git commit -m "feat: Fase 0 — scaffolding progetto Xcode"
git remote add origin https://github.com/<username>/Ascesa.git
git push -u origin main
```

---

## Documentazione

| Documento | Contenuto |
|---|---|
| [Specifiche_Tecniche.md](doc/Specifiche_Tecniche.md) | Stack, architettura, protocolli, modelli, BLE |
| [Piano_di_Sviluppo.md](doc/Piano_di_Sviluppo.md) | Task per fase (MVP → v3), criteri di completamento |
| [IndoorTrainer_App_Analisi_e_Progetto.md](doc/IndoorTrainer_App_Analisi_e_Progetto.md) | Analisi requisiti e architettura (documento originale) |
| [Addendum_Autenticazione_Multiutente.md](doc/Addendum_Autenticazione_Multiutente.md) | Requisiti auth, multi-utente, backend |

---

## Stato del progetto

| Fase | Stato |
|---|---|
| **Fase 0** — Setup progetto | ✅ Completata |
| **MVP** — FLUX + Watch HR + dashboard + export FIT | 🔲 In pianificazione |
| **v1** — Auth, workout strutturati, storico | 🔲 In pianificazione |
| **v2** — Discovery percorsi, Mapbox, integrazioni | 🔲 In pianificazione |
| **v3** — Coach/atleta, multi-utente | 🔲 In pianificazione |
