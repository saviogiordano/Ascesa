# Addendum — Autenticazione, registrazione e supporto multi-utente

Questo addendum estende il documento *Indoor Trainer App — Analisi tecnica e progetto*. Aggiunge i requisiti di account e multi-utente (integra il §1), aggiorna l'architettura introducendo un backend (integra il §2) ed elenca i nuovi componenti (integra il §4).

---

## 0. Cambio di paradigma

Il documento originale assumeva un'app **single-user, offline-first, con dati solo locali**. Supportare più utenti introduce tre conseguenze strutturali:

1. **Serve un backend** (identità + sincronizzazione): i dati non possono più vivere solo sul dispositivo.
2. **I dati diventano per-utente e isolati**: un utente non deve mai vedere i dati di un altro (multi-tenancy).
3. **Aumentano gli obblighi legali e di piattaforma**: i dati di allenamento e di frequenza cardiaca sono **dati sanitari** (categoria particolare GDPR), e l'App Store impone regole precise su login e cancellazione account.

Principio da preservare: **resta offline-first**. L'allenamento non deve mai dipendere dalla rete. L'autenticazione deve degradare con grazia — sessione valida in cache, l'app funziona offline e sincronizza al ritorno della connessione.

---

## 1. Requisiti funzionali di autenticazione (serie AUTH)

Da aggiungere al §1.2 del documento.

| # | Requisito | Note |
|---|-----------|------|
| AUTH1 | **Registrazione** con email + password, con verifica dell'indirizzo email | Validazione robustezza password, anti-bot |
| AUTH2 | **Login** email/password | |
| AUTH3 | **Sign in with Apple** | Consigliato su iOS a prescindere; **obbligatorio** se si offre anche un login social (vedi §3) |
| AUTH4 | **Login social opzionale** (es. Google) | Se incluso, fa scattare l'obbligo di AUTH3 |
| AUTH5 | **Recupero/reset password** via email | Token a scadenza |
| AUTH6 | **Gestione sessioni**: logout, "esci da tutti i dispositivi", elenco dispositivi attivi | |
| AUTH7 | **Sblocco biometrico** (Face ID / Touch ID) | Per riaprire l'app senza reinserire la password |
| AUTH8 | **Persistenza sicura della sessione**: token in Keychain, refresh token con rotazione | Mai credenziali in chiaro |
| AUTH9 | **Gestione account**: modifica email, cambio password | |
| AUTH10 | **Cancellazione account in-app** + **export dei dati** prima della cancellazione | Obbligo App Store; collegato al diritto all'oblio GDPR |
| AUTH11 | **Onboarding al primo accesso**: il profilo atleta (FTP, peso, zone — A1 del doc) viene legato all'account | |
| AUTH12 | **Modalità ospite / offline**: uso dell'app senza account, con **migrazione dei dati locali** all'eventuale registrazione | Evita di perdere gli allenamenti fatti prima di registrarsi |
| AUTH13 | **Multi-dispositivo**: stesso account su iPhone, iPad e Apple Watch, con dati sincronizzati | |
| AUTH14 | *(futuro)* **Ruoli e condivisione**: relazione coach–atleta, condivisione percorsi/workout, account "team" | Apre a inviti, permessi, visibilità selettiva |

---

## 2. Requisiti non funzionali: sicurezza e privacy

Da aggiungere al §1.3 del documento.

- **Dati sanitari = categoria particolare (GDPR art. 9)**: servono base giuridica e **consenso esplicito** separato, minimizzazione dei dati, finalità dichiarate. HR, potenza e sessioni rientrano qui.
- **Isolamento per utente (multi-tenancy)**: ogni query è vincolata all'utente autenticato. Con un database relazionale si applica *row-level security*; nessun endpoint deve poter restituire dati di altri utenti.
- **Gestione segreti**: TLS ovunque, token di accesso a vita breve + refresh token con rotazione e revoca, archiviazione esclusivamente in **Keychain**.
- **Protezione account**: rate limiting sui tentativi di login, blocco temporaneo dopo N fallimenti, protezione anti brute-force, opzione **2FA** (futuro).
- **Vincoli HealthKit**: i dati letti da HealthKit hanno restrizioni d'uso imposte da Apple (in particolare **non** possono essere usati per pubblicità/marketing e non vanno condivisi senza consenso). Scelta architetturale consigliata: **tenere i dati HR/HealthKit locali** e sincronizzare in cloud solo ciò che serve al multi-dispositivo, con consenso esplicito; in alternativa caricare solo metriche derivate, non il flusso grezzo.
- **Conformità**: privacy policy e termini di servizio obbligatori (richiesti anche dall'App Store quando c'è creazione account); **diritto all'oblio** (cancellazione completa lato server, legato ad AUTH10); **portabilità** (export in formato leggibile, es. JSON/FIT/CSV); attenzione alla **data residency** (hosting UE consigliato).
- **Consenso granulare**: separare consenso all'uso dell'app, al trattamento dei dati sanitari e all'eventuale sincronizzazione cloud / condivisione.

---

## 3. Regola App Store da rispettare (login)

Apple richiede che, **se usi un login di terze parti o social** (Google, Facebook, ecc.) per creare o autenticare l'account principale, tu offra anche un'opzione di login **equivalente e attenta alla privacy**, che: limiti la raccolta dati a nome ed email, consenta all'utente di mantenere privata la propria email, e non raccolga le interazioni per scopi pubblicitari senza consenso. **Sign in with Apple** soddisfa questi requisiti. Per contro, se l'app usa **solo il proprio sistema email/password**, Sign in with Apple non è obbligatorio.

Implicazione pratica per il progetto:
- Se ti limiti a **email/password** → SiwA facoltativo (ma consigliato sull'ecosistema Apple).
- Se aggiungi **Google login** → devi includere **Sign in with Apple** (o equivalente conforme).
- Inoltre: con Sign in with Apple **non** richiedere di nuovo nome/email dopo il login (Apple li fornisce già) e gestisci il caso dell'**email nascosta** tramite relay di Apple.

Va inoltre garantita la **cancellazione dell'account dall'interno dell'app** (non solo via sito o email). Verifica sempre il testo aggiornato delle App Store Review Guidelines prima della submission, perché queste regole vengono riviste periodicamente.

---

## 4. Impatto sull'architettura (aggiornamento del §2)

Il diagramma a livelli del §2.3 guadagna un **tier cloud**:

```
┌───────────────────────────────────────────────┐
│  DEVICE (iPhone/iPad/Watch) — offline-first     │
│  Presentation · Domain · Data (locale: SwiftData│
│  + SQLite) · AuthService · SyncEngine           │
└───────────────▲─────────────────────────────────┘
                │  HTTPS / token (TLS)
┌───────────────┴─────────────────────────────────┐
│  CLOUD                                           │
│  Identity Provider (Sign in with Apple +         │
│     email/password)                              │
│  API backend (profili, percorsi, sessioni, sync) │
│  Database multi-tenant (row-level security)      │
│  Object storage (file FIT/GPX, export)           │
└──────────────────────────────────────────────────┘
```

Opzioni tecnologiche per identità + backend:

| Soluzione | Pro | Contro / attenzioni |
|-----------|-----|---------------------|
| **Supabase** (Postgres + Auth + Row-Level Security) | Open source, hosting UE possibile, RLS nativa ideale per il multi-tenant, ottimo rapporto sforzo/risultato | Backend da modellare bene; self-host se vuoi pieno controllo |
| **Firebase Auth + Firestore** | Velocissimo da avviare, SDK iOS maturo | Dati (sanitari) su infrastruttura Google; data residency UE meno immediata |
| **AWS Amplify / Cognito** | Scalabile, controllo fine, ecosistema ampio | Più complesso da configurare |
| **Auth0 / Okta** (solo identità) + backend proprio | Auth gestita e robusta, MFA pronto | Devi comunque costruire e ospitare il backend dati |
| **Sign in with Apple + CloudKit** | Zero backend da gestire, privacy nativa | CloudKit è legato all'Apple ID: **non** adatto a email/password o login multipli arbitrari; utile solo se l'identità è esclusivamente l'Apple ID |

**Raccomandazione**: identità con **Sign in with Apple + email/password** gestiti da un provider come **Supabase Auth** (o Auth0), backend dati su **Postgres con Row-Level Security** e hosting UE per il GDPR. Mantieni il livello locale come fonte di verità durante l'allenamento e usa un **SyncEngine offline-first** con risoluzione dei conflitti (last-write-wins per i record time-series, merge per il profilo).

---

## 5. Nuovi componenti da realizzare (aggiornamento del §4)

### Data / Infrastructure
- **`AuthService`** — registrazione, login/logout, refresh token, integrazione Sign in with Apple ed eventuale Google; salvataggio token in Keychain.
- **`SessionManager`** — ciclo di vita della sessione, gate biometrico (Face ID/Touch ID), auto-logout, revoca.
- **`AccountRepository`** — collega l'identità (account) al profilo atleta del dominio; gestione email/password.
- **`BackendAPIClient`** — client REST/realtime verso il backend, gestione errori di autenticazione (401/refresh).
- **`SyncEngine`** — sincronizzazione offline-first di sessioni, percorsi e profilo; coda di upload, risoluzione conflitti.
- **`ConsentManager`** — raccolta e versionamento dei consensi (app, dati sanitari, sync/condivisione).

### Domain
- **`AuthenticateUser` / `RegisterUser` / `SignInWithApple`** (use case).
- **`MigrateGuestData`** — migra i dati della modalità ospite all'account appena creato (AUTH12).
- **`DeleteAccount`** — cancellazione completa lato client e server + export preventivo (AUTH10).
- **`UserScopedDataPolicy`** — garantisce che ogni accesso ai dati sia vincolato all'utente corrente.

### Presentation (SwiftUI)
- **`AuthFlow`**: schermate Welcome → Sign Up / Sign In → Forgot Password → verifica email → Onboarding profilo atleta.
- **`AccountSettingsView`**: gestione account, dispositivi/sessioni attive, toggle biometria, **export dati**, **elimina account**, gestione consensi.
- Adattamento delle viste esistenti (History, Routes, Workouts) per essere **scoperate per utente**.

### Watch app
- Propagazione dello stato di autenticazione dall'iPhone (l'orologio non gestisce login proprio): se l'utente non è autenticato sull'iPhone, la Watch app resta in sola modalità allenamento locale finché non c'è una sessione valida.

---

## 6. Roadmap (aggiornamento del §4.5)

| Fase | Aggiunta su autenticazione |
|------|----------------------------|
| **MVP** | Modalità ospite/offline funzionante senza account (così non blocchi l'uso base); persistenza locale per-utente già predisposta |
| **v1** | Registrazione + login email/password, Sign in with Apple, Keychain, sblocco biometrico, cancellazione account in-app, privacy policy/ToS, onboarding profilo |
| **v2** | Sync multi-dispositivo (SyncEngine + backend), gestione sessioni, export dati, eventuale Google login (con i relativi obblighi), 2FA |
| **v3** | Ruoli coach–atleta, condivisione percorsi/workout, account team (AUTH14) |

---

*Nota: non sono un avvocato. Gli obblighi GDPR e le App Store Review Guidelines (4.8 sui login e 5.1.1 sulla cancellazione account) vanno verificati nella versione aggiornata prima dello sviluppo e della pubblicazione.*
