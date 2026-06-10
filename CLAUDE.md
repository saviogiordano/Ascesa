# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Ascesa** is an iOS/watchOS app for indoor cycling training. It controls a TACX FLUX smart trainer via Bluetooth, reads heart rate from Apple Watch, simulates riding real-world routes, and records sessions. The Xcode project has not been created yet — this repo is currently in design/pre-development phase.

Key reference documents:
- [doc/IndoorTrainer_App_Analisi_e_Progetto.md](doc/IndoorTrainer_App_Analisi_e_Progetto.md) — full technical analysis, architecture decisions, API survey (Italian)
- [res/README.md](res/README.md) — app icon setup for Xcode

## Tech Stack (decided)

- **Swift 6** with async/await + actors throughout
- **SwiftUI** for all UI; UIKit only where unavoidable
- **Combine / AsyncStream** for sensor data pipelines
- **CoreBluetooth** for TACX FLUX and BLE heart rate bands
- **HealthKit + WorkoutKit** for Apple Watch HR and session saving
- **WatchConnectivity** (`WCSession`) for Watch↔iPhone HR streaming
- **SwiftData** for the object model (athlete, workouts, routes); **SQLite/GRDB** for 1 Hz time-series records
- **Swift Charts** for elevation profiles and session analytics
- **XCTest + Swift Testing** for unit tests

## Architecture

Three layers. The Domain layer has zero knowledge of CoreBluetooth, HealthKit, or any framework:

```
Presentation (SwiftUI + ViewModels)
        ↕  protocols only
Domain (pure Swift — WorkoutEngine, SessionRecorder, MetricsCalculator,
        RouteToSimulationMapper, TrainingZones, UseCases)
        ↕  protocols only
Data / Infrastructure (TrainerService, HeartRateService, RouteRepository,
        PersistenceRepository, ExportService, HealthKitGateway)
```

**Key protocol boundaries:**
- `TrainerControl` — `setTargetPower(_:)` / `setSimulation(grade:totalWeight:)` — implemented by `FTMSAdapter` and `TacxAdapter`; chosen at runtime via capability discovery
- `RouteProvider` — `search(query:)` / `fetch(id:)` — implemented by `GPXFileProvider`, `OpenRouteServiceProvider`, optional Strava/Garmin connectors
- `HeartRateSource` — wraps both Apple Watch (WatchConnectivity) and BLE chest strap; Watch is preferred

## TACX FLUX — BLE Protocol

The FLUX speaks FTMS over BLE (UUID `0x1826`). Primary characteristics:
- **Indoor Bike Data** `0x2AD2` — subscribe for power, cadence, speed notifications
- **Fitness Machine Control Point** `0x2AD9` — write commands:
  - `Set Target Power` → ERG mode
  - `Set Indoor Bike Simulation Parameters` (grade, wind, Crr, Cw) → SIM mode

Some FLUX variants also expose a Tacx proprietary service; implement a `TacxAdapter` as fallback. Always inspect the actual device with nRF Connect before writing adapters, since GATT capabilities vary between FLUX, FLUX S, and FLUX 2.

## Route-to-Simulation Pipeline

1. Import GPX/FIT/TCX (zero-dependency baseline)
2. Resample track to fixed step (10–25 m)
3. Enrich/smooth elevation (OpenRouteService or Open-Elevation) — raw GPS altitude is too noisy
4. Calculate per-segment grade; apply moving-average or spline smoothing
5. Clamp grade to trainer's supported range; add small lag to avoid resistance spikes
6. During ride: `virtual_position = ∫ speed dt` → lookup grade → `TrainerControl.setSimulation(...)`

## Apple Watch Integration

Apple Watch does **not** expose HR as a standard BLE Heart Rate Service. The Watch companion app must:
1. Start an `HKWorkoutSession` (required for high-frequency, prioritized HR access)
2. Read live HR via `HKLiveWorkoutBuilder`
3. Stream it to iPhone via `WCSession`

The Watch app also mirrors workout state (start/pause/stop) and shows essential metrics received from the iPhone.

## Planned Development Phases

| Phase | Scope |
|-------|-------|
| MVP | FLUX connection (FTMS), power/cadence/speed read, ERG, HR from Watch, live dashboard, 1 Hz recording, FIT export, GPX import, SIM mode with elevation smoothing |
| v1 | Structured workout builder, NP/IF/TSS metrics, session history + charts, map sync, spindown calibration, BLE chest strap fallback |
| v2 | In-app route discovery (OpenRouteService), Mapbox 3D, Strava/Garmin/RWGPS connectors, FTP trend analysis |

## App Icon

Assets are in [res/Ascesa-AppIcon/](res/Ascesa-AppIcon/). To add to Xcode: drag `AppIcon.appiconset/` into `Assets.xcassets` and set **App Icon Source** to `AppIcon` in the target's General tab.

To regenerate PNGs from the SVG source:
```bash
pip install Pillow
python3 res/Ascesa-AppIcon/make_icons.py
```

Brand colors: `#1E2A52` (deep indigo background), `#2E4288` (mid indigo), `#FFB84D` (amber). Reuse `#1E2A52` as the dominant color in the live dashboard.
