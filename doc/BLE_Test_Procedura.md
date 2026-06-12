# Test BLE — Procedura completa

Procedura per verificare `BluetoothCentralManager`, `FTMSAdapter` e `HeartRateService`
usando la tab **BLE Debug** dell'app.

---

## Setup una-tantum

- iPhone fisico connesso via USB (il simulatore non ha hardware BLE)
- Apple Developer account configurato in Xcode:
  1. Apri `app/Ascesa.xcodeproj`
  2. Project Navigator → target **Ascesa** → tab **Signing & Capabilities** → **Team**
- Se aggiungi nuovi file Swift, rigenera il progetto: `cd app && xcodegen generate`

---

## 1 — BluetoothCentralManager: scan e connessione

**Prerequisiti:** TACX FLUX acceso (LED BLE lampeggiante).

### Flusso

1. `⌘R` sull'iPhone — alla prima esecuzione l'app chiede il permesso Bluetooth
2. Tab **BLE Debug** (icona antenna)
3. Il scan parte automaticamente e mostra solo device rilevanti (FTMS · HR · Power)
4. Entro 15–20 s appare il FLUX nella lista con nome e RSSI
5. Tocca il device → connessione → compare la sezione **GATT Services**

### Interpretare i GATT Services

| UUID | Significato |
|---|---|
| `1826` + badge **FTMS ✓** | FLUX parla FTMS standard → usare `FTMSAdapter` |
| `1818` | Cycling Power Service (bonus) |
| UUID lungo `6E40xxxx-…` | Servizio proprietario Tacx → serve `TacxAdapter` come fallback |

### RSSI

| Range | Indicatore |
|---|---|
| > −65 dBm | Verde — ottimo |
| −65 … −80 dBm | Arancio — accettabile |
| < −80 dBm | Rosso — avvicinarsi |

---

## 2 — FTMSAdapter: handshake, telemetria, comandi

**Prerequisiti:** FLUX connesso, sezione GATT Services mostra `1826`.

### Flusso

1. Appare la sezione **FTMS** → tocca **"Prepara FTMS (handshake)"**
2. Log: `FTMS: Request Control…` → `FTMS pronto ✓`
3. I tre valori (Potenza / Cadenza / Velocità) si aggiornano in tempo reale pedalando
4. **Test ERG**: slider → wattaggio desiderato (es. 150 W) → **Invia**
5. **Test SIM**: slider → pendenza (es. 5%) → **Invia**

### Interpretare il log

| Messaggio | Significato |
|---|---|
| `FTMS pronto ✓` | Handshake OK — rullo risponde 0x01 all'Op Code 0x00 |
| Valori che cambiano pedalando | Parser `Indoor Bike Data` (0x2AD2) corretto |
| `ERG → N W` senza errori | Set Target Power (Op 0x05) accettato |
| `SIM → pendenza N%` senza errori | Set Simulation Parameters (Op 0x11) accettato |
| `commandFailed(resultCode: 0x04)` | Operation Failed — spegnere e riaccendere il FLUX |
| `commandFailed(resultCode: 0x05)` | Control Not Permitted — ritentare "Prepara FTMS" |
| `characteristicMissing(...)` | Device non ha FTMS completo — ispezionare con nRF Connect |

### Verifica fisica

| Comando | Atteso sul rullo |
|---|---|
| ERG 100 W / 200 W / 300 W | Resistenza cambia in modo netto entro ~1 s |
| SIM 0% → 5% → 10% | Resistenza aumenta progressivamente |
| SIM −5% | Resistenza quasi nulla (discesa) |

---

## 3 — HeartRateService: Watch e fascia BLE

La sezione **Frequenza Cardiaca** è sempre visibile, indipendentemente dal device connesso.

### Test Apple Watch

**Prerequisiti:** Apple Watch indossato e abbinato all'iPhone.

Il Watch deve avere un `HKWorkoutSession` attivo per inviare HR ad alta frequenza.
Modi per avviarlo:
- Avvia un allenamento dall'app **Allenamento** sul Watch
- Oppure, una volta che l'app Ascesa avrà la Watch companion app, il workout parte automaticamente

**Flusso:**
1. Apri la tab BLE Debug — la sezione HR mostra subito il badge Watch
2. Se il Watch è raggiungibile: badge verde "Raggiungibile"
3. Avvia un allenamento sul Watch → entro 3 s il numero bpm appare e si aggiorna
4. Label sotto il numero: "da Apple Watch"

### Test fascia BLE (es. Polar H10)

**Prerequisiti:** fascia indossata e accesa, FLUX non necessario (la fascia appare direttamente nel scan).

**Flusso:**
1. La fascia Polar appare nella lista device (advertise service `0x180D`)
2. Toccala per connetterla
3. Compare la sezione GATT Services con i services della fascia
4. Nella sezione **Frequenza Cardiaca** compare il bottone **"Prepara HR BLE"** → toccalo
5. Log: `HR BLE: discovery…` → `HR BLE pronto ✓ (fallback Watch)`

### Verifica priorità Watch vs fascia BLE

| Scenario | Comportamento atteso |
|---|---|
| Watch attivo + fascia connessa | Valori da Watch; fascia silenziosa |
| Watch si ferma (> 5 s senza campioni) | Subentra automaticamente la fascia; label cambia in "da Fascia BLE" |
| Watch riprende | Torna Watch; fascia torna silenziosa |

---

## Rimozione del debug

Quando i test sono completati:

1. In `ContentView.swift` ripristinare il tab Profilo:

```swift
// sostituire:
BLEDebugView()
    .tabItem { Label("BLE Debug", systemImage: "antenna.radiowaves.left.and.right") }

// con:
Text("Profilo")
    .tabItem { Label("Profilo", systemImage: "person.fill") }
```

2. Eliminare `Sources/Presentation/Debug/BLEDebugView.swift`
3. `xcodegen generate`
