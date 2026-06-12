# Test Route Pipeline — Procedura completa

Procedura per verificare `GPXParser`, `ElevationService`, `RouteToSimulationMapper` e `RouteRepository`
usando la tab **Route Debug** dell'app.

A differenza del BLE Debug, **questi test funzionano sul simulatore iOS** — non è necessario hardware fisico.

---

## Setup una-tantum

- Simulatore iPhone (qualsiasi modello) o iPhone fisico
- Un file `.gpx` di test (vedi sezione "File GPX di test" qui sotto)
- Se aggiungi nuovi file Swift, rigenera il progetto: `cd app && xcodegen generate`

### Come aggiungere un file GPX al simulatore

**Metodo 1 — Drag & drop sul simulatore:**
1. Simulatore aperto → finestra del simulatore in foreground
2. Trascina il file `.gpx` dalla cartella Finder **dentro** la finestra del simulatore
3. Si apre automaticamente il pannello di condivisione iOS → seleziona **Ascesa**

**Metodo 2 — Condividi da Safari (simulatore):**
1. Copia il file in `~/Desktop` o in una cartella accessibile
2. Nel simulatore apri Files → clicca "…" → "Connetti a server" non serve; usa invece:
3. Simulatore menu → **File → Add File to Simulator** → scegli il `.gpx` → verrà salvato in Files

**Metodo 3 — `xcrun simctl` (terminale):**
```bash
xcrun simctl openurl booted "file:///Users/tuonome/Desktop/stelvio.gpx"
```
iOS lo apre nel pannello di condivisione → scegli Ascesa.

---

## File GPX di test consigliati

| Percorso | Dove scaricarlo | Caratteristiche |
|---|---|---|
| Passo dello Stelvio (versante Bormio) | Komoot, Strava, OpenCycleMap | 21 km, +1800 m, pendenze fino a 12% — buon test per smoothing |
| Percorso pianeggiante (es. Naviglio Martesana) | Strava / Komoot | Grade ~0% — verifica clamping negativo e smoothing su traccia piatta |
| GPX senza `<ele>` | Crea con un editor testuale: rimuovi tutti i tag `elevation` | Testa il fallback quota 0 del parser |

> **Nota:** Strava esporta `.gpx` con elevation inclusa dalla tab Attività → "Esporta GPX".
> Komoot consente il download diretto dalla pagina percorso (link "Scarica GPX").

---

## 1 — GPXParser

**Prerequisiti:** file `.gpx` aggiunto al simulatore (vedi Setup).

### Flusso

1. `⌘R` → tab **Route Debug** (icona mappa)
2. Sezione **Import GPX** → tocca **"Apri file .gpx…"**
3. Naviga in Files.app e seleziona il file
4. La sezione si aggiorna con i valori estratti

### Cosa verificare

| Campo | Stelvio (~21 km, ~1800 m) | Traccia senza `<ele>` |
|---|---|---|
| Punti grezzi | Dipende dal file, tipicamente 1000–3000 | Stessi punti, altitudineMeters = 0 |
| Distanza | ~21 km | Invariata (Haversine non usa l'altitudine) |
| Dislivello grezzo | ~+1800 m | 0 m |
| Quota inizio / fine | ~1300 m / ~2758 m | 0 m / 0 m |

### Interpretare il log

| Messaggio | Significato |
|---|---|
| `Importato 'stelvio': N punti, X.X km, +Y m` | Parse OK — tutti i `<trkpt>` letti |
| `Il file GPX non è valido o non può essere letto.` | File corrotto o non è XML valido |
| `Il file GPX non contiene punti traccia.` | Nessun `<trkpt>` né `<wpt>` nel file |

> **Nota sul fallback waypoints:** se il GPX ha solo `<wpt>` (nessun `<trkseg>`), il parser usa quelli. Testa con un GPX di waypoint per verificare il comportamento.

---

## 2 — ElevationService (ORS)

L'arricchimento ORS sostituisce le quote GPS (rumorose, ±20 m tipici) con valori da DEM SRTM/Copernicus.

**Prerequisiti:** file GPX già importato; API key OpenRouteService.

### Ottenere l'API key ORS

1. Registrati su [openrouteservice.org](https://openrouteservice.org)
2. Dashboard → **API Keys** → copia la chiave (tier gratuito: 2000 req/giorno, 500 coord/richiesta)

### Flusso

1. Sezione **Elevation ORS** → incolla la chiave nel campo testo
2. Tocca **"Arricchisci quote (ORS SRTM)"**
3. Il bottone mostra uno spinner; attendi la risposta di rete

### Cosa verificare

| Scenario | Risultato atteso |
|---|---|
| API key valida, file ~1500 punti | 3 batch da 500 coord, log `ORS: quote aggiornate su 1500 punti` |
| API key vuota | Bottone grigio disabilitato — il servizio è un no-op |
| Rete assente | Log `ORS Elevation API ha restituito un errore.` — la pipeline funziona anche senza (usa quote GPX) |
| Risposta con count diverso | Log `Attesi N punti quota, ricevuti M.` — non dovrebbe accadere con ORS corretto |

> **Consiglio:** dopo l'arricchimento, premi "Calcola RouteProfile" di nuovo. Se le pendenze sono più morbide rispetto a prima dell'arricchimento, il servizio sta correggendo il rumore GPS.

---

## 3 — RouteToSimulationMapper

Il mapper trasforma il percorso grezzo nel `RouteProfile` usato in SIM mode. Testa l'effetto dei parametri sui dati.

**Prerequisiti:** file GPX importato (con o senza arricchimento ORS).

### Flusso

1. Sezione **RouteToSimulationMapper** → regola i parametri
2. Tocca **"Calcola RouteProfile"** → appare la sezione **RouteProfile**

### Parametri e effetti attesi

| Parametro | Valore basso | Valore alto |
|---|---|---|
| Passo ricampionamento (5–50 m) | Più segmenti, più fedele al tracciato, calcolo più lento | Meno segmenti, più scattoso sulle curve |
| Finestra smoothing (50–500 m) | Pendenze più rumorose ma reattive | Pendenze più morbide, spike da GPS soppressi |

### Valori attesi — Passo dello Stelvio

Con passo 15 m, smoothing 200 m, quote ORS:

| Metrica | Atteso |
|---|---|
| Segmenti | ~1400 (21 km / 15 m) |
| Grade max | ~11–12% (tornanti finali) |
| Grade min | ~−2% (breve discesa nel tratto basso) |
| Grade avg | ~4–5% (pendenza media salita sostenuta) |

Con percorso pianeggiante (Naviglio):

| Metrica | Atteso |
|---|---|
| Grade max | < 1% |
| Grade min | > −1% |
| Grade avg | ~0% |

### Clamping FLUX

Il mapper clamp il grade a −10%…+20% (range supportato da TACX FLUX). Verifica:
- Nessun segmento nel grafico supera +20% (nemmeno i tornanti più ripidi)
- Nessun segmento va sotto −10%

### Grafico pendenza

| Colore | Zona |
|---|---|
| Blu | Pendenza negativa (discesa) |
| Verde | 0–4% (pianura / lieve salita) |
| Giallo | 4–7% (salita media) |
| Arancio | 7–10% (salita impegnativa) |
| Rosso | > 10% (salita dura) |

---

## 4 — RouteProfile.grade(at:)

La sezione **RouteProfile** mostra tre lookup a 25%, 50%, 75% del percorso.
Questo testa la funzione di interpolazione lineare usata da `WorkoutEngine` ogni secondo.

### Come verificare

1. Confronta i valori dei tre lookup con il grafico visivamente
2. Il valore a 25% deve cadere nel tratto iniziale del grafico; 50% a metà; 75% verso la fine
3. Cambia il passo di ricampionamento → ricalcola → i lookup devono cambiare di pochissimo (< 0.5% di variazione tipica)

### Casi limite

| Caso | Come testarlo | Atteso |
|---|---|---|
| Posizione = 0 | Hardcoded: primo segmento | Grade del primo segmento |
| Posizione = distanza totale | Hardcoded: ultimo segmento | Grade dell'ultimo segmento |
| Posizione oltre la fine | Non esposto in UI — verificabile a codice | Grade dell'ultimo segmento (no crash) |

---

## 5 — RouteRepository

Testa il ciclo completo: salvataggio su disco, ricerca, fetch, eliminazione.

**Prerequisiti:** file GPX importato.

### Flusso — salvataggio

1. Sezione **RouteRepository** → tocca **"Salva percorso corrente"**
2. Log: `Salvato 'nome_percorso'`
3. Il percorso appare immediatamente nella lista con distanza, dislivello e grade max

### Flusso — fetch round-trip

1. Tocca una riga del percorso salvato
2. Log: `Fetch 'nome': N punti, X.X km`
3. Verifica che `N punti` e `X.X km` coincidano con quelli dell'import originale

### Flusso — eliminazione

1. Swipe left sulla riga → tocca **Elimina** (rosso)
2. Il percorso sparisce dalla lista; log `Eliminato 'nome'`
3. Forza chiusura dell'app (doppio tap home → swipe up su Ascesa) e riapri
4. Il percorso non deve più comparire — verifica che l'indice JSON sia stato riscritto correttamente

### Flusso — ricampionamento file

1. Salva lo stesso file due volte (importa, salva, importa di nuovo, salva di nuovo)
2. Compaiono due entry con lo stesso nome ma ID diversi — comportamento corretto (UUID generato a ogni salvataggio)

### Interpretare il log

| Messaggio | Significato |
|---|---|
| `Salvato 'nome'` | File JSON + indice JSON scritti in Application Support/routes/ |
| `Fetch 'nome': N punti, X.X km` | Round-trip JSON ok — punto count e distanza coerenti |
| `Eliminato 'nome'` | File rimosso + indice aggiornato |
| Qualsiasi errore con `errore:` | Problema filesystem — controlla permessi in Application Support |

### Posizione file su simulatore

I file sono in Application Support dell'app sandbox, ispezionabili da Xcode:
**Window → Devices and Simulators → seleziona il simulatore → Download Container** (tasto destro sull'app).
Dopo il download, apri `.xcappdata` in Finder → Mostra contenuto pacchetto → `AppData/Library/Application Support/routes/`.

---

## 6 — Test combinato: pipeline end-to-end

Dopo aver verificato ogni servizio singolarmente, esegui la pipeline completa:

1. Importa un GPX con elevation
2. (Opzionale) Arricchisci con ORS
3. Calcola il profilo (passo 15 m, smoothing 200 m)
4. Salva nel repository
5. Forza chiusura e riapri l'app
6. Il percorso è ancora nella lista
7. Tocca la riga → il fetch restituisce gli stessi punti originali (non il profilo smoothed — quello è calcolato in RAM)

Questo simula il flusso reale di `UseCase ImportRoute`.

---

## Rimozione del debug

Quando i test sono completati:

1. In `ContentView.swift` rimuovi il tab Route Debug:

```swift
// Rimuovere queste righe:
// DEBUG — rimuovere prima del rilascio
RouteDebugView()
    .tabItem { Label("Route Debug", systemImage: "map") }
```

2. Elimina `Sources/Presentation/Debug/RouteDebugView.swift`
3. `xcodegen generate`

---

*Documento creato: 2026-06-12. Fase: MVP — Data / RouteRepository e parser.*
