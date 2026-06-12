/* Ascesa — AuthFlow part 2: consent, onboarding, Face ID lock, guest, container */

// ── CONSENT (granular, GDPR art. 9) ────────────────────────
function ConsentView({ go }) {
  const [c, setC] = React.useState({ tos: true, health: true, cloud: true, marketing: false });
  const set = (k) => (v) => setC(s => ({ ...s, [k]: v }));
  return (
    <window.AuthShell onBack={() => go('signup')}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div>
          <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>Privacy e consensi</div>
          <div style={{ fontSize: 14, color: 'var(--text-3)', marginTop: 6, lineHeight: 1.5 }}>I dati cardio e di potenza sono <b style={{ color: 'var(--text-2)' }}>dati sanitari</b>. Decidi tu come trattarli — puoi cambiare in qualsiasi momento.</div>
        </div>
        <window.Card pad={0}>
          <window.ConsentRow title="Termini e Privacy policy" desc="Uso dell'app e trattamento dei dati di base." on={c.tos} onChange={set('tos')} required />
          <window.ConsentRow title="Dati sanitari (HR, potenza)" desc="Necessari per registrare le sessioni e calcolare le zone. Restano locali per impostazione." on={c.health} onChange={set('health')} required />
          <window.ConsentRow title="Sincronizzazione cloud" desc="Salva e ritrova i tuoi dati su iPhone, iPad e Watch. Hosting UE." on={c.cloud} onChange={set('cloud')} />
          <window.ConsentRow title="Email e novità" desc="Consigli di allenamento e aggiornamenti prodotto. Niente pubblicità di terzi." on={c.marketing} onChange={set('marketing')} last />
        </window.Card>
        <button disabled={!c.tos || !c.health} onClick={() => go('onboard')} style={{ ...window.authBtnPrimary, opacity: (c.tos && c.health) ? 1 : 0.4 }}>Accetta e continua</button>
        <div style={{ fontSize: 11.5, color: 'var(--text-3)', textAlign: 'center', lineHeight: 1.5 }}>I dati HealthKit non vengono mai usati per marketing né condivisi senza il tuo consenso.</div>
      </div>
    </window.AuthShell>
  );
}

// ── ONBOARDING (athlete profile, multi-step) ───────────────
function OnboardView({ go, onDone }) {
  const [step, setStep] = React.useState(0);
  const [d, setD] = React.useState({ name: '', weight: 72, ftp: 250, maxHR: 186, knowFtp: true });
  const steps = ['Chi sei', 'Peso', 'FTP', 'Cuore'];
  const next = () => step < 3 ? setStep(step + 1) : onDone();
  const back = () => step > 0 ? setStep(step - 1) : go('consent');

  const Stepper = ({ value, unit, onMinus, onPlus, big }) => (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 22, padding: '10px 0' }}>
      <button onClick={onMinus} style={onbStep}><window.Icon name="minus" size={22} sw={2.2} /></button>
      <div className="tnum" style={{ display: 'flex', alignItems: 'baseline', gap: 6, minWidth: 150, justifyContent: 'center' }}>
        <span style={{ fontSize: 64, fontWeight: 760, letterSpacing: -2 }}>{value}</span>
        <span style={{ fontSize: 18, fontWeight: 600, color: 'var(--text-3)' }}>{unit}</span>
      </div>
      <button onClick={onPlus} style={onbStep}><window.Icon name="plus" size={22} sw={2.2} /></button>
    </div>
  );

  return (
    <div style={{ position: 'absolute', inset: 0, background: 'var(--bg)', color: 'var(--text)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '52px 22px 8px', flex: '0 0 auto' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button onClick={back} aria-label="Indietro" style={{ width: 36, height: 36, borderRadius: 18, border: 'none', background: 'var(--surface)', color: 'var(--text)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
            <window.Icon name="back" size={20} sw={2.1} />
          </button>
          <div style={{ flex: 1, display: 'flex', gap: 5 }}>
            {steps.map((_, i) => <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: i <= step ? 'var(--accent)' : 'var(--surface-2)', transition: 'background .2s' }} />)}
          </div>
        </div>
        <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: 0.6, marginTop: 16 }}>Passo {step + 1} di 4 · Profilo atleta</div>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 22px 20px', display: 'flex', flexDirection: 'column' }}>
        {step === 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
            <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>Come ti chiami?</div>
            <window.AuthField label="Nome" value={d.name} onChange={v => setD({ ...d, name: v })} placeholder="Es. Marco" autoFocus />
            <div style={{ fontSize: 13.5, color: 'var(--text-3)', lineHeight: 1.5 }}>Il profilo (FTP, peso, zone) viene legato al tuo account, così lo ritrovi su ogni dispositivo.</div>
          </div>
        )}
        {step === 1 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>Quanto pesi?</div>
            <div style={{ fontSize: 14, color: 'var(--text-3)' }}>Serve per simulare lo sforzo in salita.</div>
            <div style={{ marginTop: 'auto', marginBottom: 'auto' }}><Stepper value={d.weight} unit="kg" onMinus={() => setD({ ...d, weight: Math.max(40, d.weight - 1) })} onPlus={() => setD({ ...d, weight: d.weight + 1 })} /></div>
          </div>
        )}
        {step === 2 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>La tua FTP</div>
            <div style={{ fontSize: 14, color: 'var(--text-3)', lineHeight: 1.5 }}>Potenza di soglia. Da qui calcoliamo zone, ERG e TSS. Non la sai? Stimiamo con un test.</div>
            <div style={{ marginTop: 24 }}><Stepper value={d.ftp} unit="W" onMinus={() => setD({ ...d, ftp: Math.max(80, d.ftp - 5) })} onPlus={() => setD({ ...d, ftp: d.ftp + 5 })} /></div>
            <div className="tnum" style={{ textAlign: 'center', fontSize: 13.5, color: 'var(--text-2)', fontWeight: 600 }}>{(d.ftp / d.weight).toFixed(1)} W/kg</div>
            <button style={{ ...window.authTextLink, alignSelf: 'center', marginTop: 14 }}>Non conosco la mia FTP →</button>
          </div>
        )}
        {step === 3 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>Frequenza cardiaca max</div>
            <div style={{ fontSize: 14, color: 'var(--text-3)', lineHeight: 1.5 }}>Definisce le zone cardio. Stima di partenza: 220 − età.</div>
            <div style={{ marginTop: 24 }}><Stepper value={d.maxHR} unit="bpm" onMinus={() => setD({ ...d, maxHR: Math.max(140, d.maxHR - 1) })} onPlus={() => setD({ ...d, maxHR: d.maxHR + 1 })} /></div>
          </div>
        )}
      </div>

      <div style={{ padding: '8px 22px 30px', flex: '0 0 auto' }}>
        <button onClick={next} style={window.authBtnPrimary}>{step < 3 ? 'Continua' : 'Inizia ad allenarti'}</button>
      </div>
    </div>
  );
}
const onbStep = { width: 56, height: 56, borderRadius: 28, border: '1px solid var(--line)', background: 'var(--surface)', color: 'var(--text)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' };

// ── FACE ID LOCK ───────────────────────────────────────────
function LockView({ onDone, go }) {
  const [scan, setScan] = React.useState(false);
  React.useEffect(() => { if (scan) { const t = setTimeout(onDone, 1100); return () => clearTimeout(t); } }, [scan]);
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'var(--bg)', color: 'var(--text)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 22, padding: 30 }}>
      <window.BrandMark size={56} />
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 22, fontWeight: 780 }}>Ascesa è bloccata</div>
        <div style={{ fontSize: 14, color: 'var(--text-3)', marginTop: 6 }}>Sblocca per accedere ai tuoi dati.</div>
      </div>
      <button onClick={() => setScan(true)} aria-label="Face ID" style={{ width: 96, height: 96, borderRadius: 48, border: '2px solid ' + (scan ? 'var(--accent)' : 'var(--line)'), background: 'var(--surface)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'border-color .3s, box-shadow .3s', boxShadow: scan ? '0 0 26px color-mix(in oklch, var(--accent) 40%, transparent)' : 'none' }}>
        <svg width="46" height="46" viewBox="0 0 24 24" fill="none" stroke={scan ? 'var(--accent)' : 'var(--text-2)'} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" style={{ transition: 'stroke .3s' }}>
          <path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2" />
          <path d="M9 10v1M15 10v1M12 9v4l-1 1M9.5 15.5c1.5 1 3.5 1 5 0" />
        </svg>
      </button>
      <div style={{ fontSize: 13.5, fontWeight: 600, color: scan ? 'var(--accent)' : 'var(--text-3)', minHeight: 18 }}>{scan ? 'Riconoscimento…' : 'Tocca per Face ID'}</div>
      <button onClick={() => go && go('signin')} style={{ ...window.authTextLink, color: 'var(--text-2)', marginTop: 4 }}>Usa la password</button>
    </div>
  );
}

// ── GUEST MODE / MIGRATION ─────────────────────────────────
function GuestView({ go, onDone }) {
  return (
    <window.AuthShell onBack={() => go('welcome')}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div style={{ width: 56, height: 56, borderRadius: 28, background: 'var(--surface)', border: '1px solid var(--line)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <window.Icon name="watch" size={26} color="var(--text-2)" />
        </div>
        <div>
          <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>Modalità ospite</div>
          <div style={{ fontSize: 14, color: 'var(--text-3)', marginTop: 6, lineHeight: 1.5 }}>Allenati subito, senza account. I dati restano <b style={{ color: 'var(--text-2)' }}>solo su questo iPhone</b>.</div>
        </div>
        <window.Card pad={0}>
          {[['check', 'Tutto l\'allenamento funziona offline', 'var(--z3)'], ['route', 'Sessioni salvate localmente', 'var(--text-2)'], ['minus', 'Niente sync multi-dispositivo né backup', 'var(--text-3)']].map((r, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px', borderBottom: i === 2 ? 'none' : '1px solid var(--line-soft)' }}>
              <window.Icon name={r[0]} size={18} color={r[2]} />
              <span style={{ fontSize: 14, fontWeight: 600, color: r[2] === 'var(--text-3)' ? 'var(--text-3)' : 'var(--text)' }}>{r[1]}</span>
            </div>
          ))}
        </window.Card>
        <div style={{ background: 'var(--accent-ink)', border: '1px solid var(--accent-dim)', borderRadius: 14, padding: 14, fontSize: 12.5, color: 'var(--text-2)', lineHeight: 1.5 }}>
          <b style={{ color: 'var(--accent)' }}>Buono a sapersi:</b> quando ti registrerai, i tuoi allenamenti da ospite verranno <b style={{ color: 'var(--text)' }}>migrati automaticamente</b> sul nuovo account.
        </div>
        <button onClick={onDone} style={window.authBtnPrimary}>Continua come ospite</button>
        <button onClick={() => go('signup')} style={window.authBtnGhost}>Meglio creare un account</button>
      </div>
    </window.AuthShell>
  );
}

// ── CONTAINER ──────────────────────────────────────────────
function AuthFlow({ initial = 'welcome', onAuthed }) {
  const [view, setView] = React.useState(initial);
  const go = (v) => setView(v);
  const done = () => onAuthed ? onAuthed() : setView('welcome');
  switch (view) {
    case 'welcome': return <WelcomeView go={go} />;
    case 'signup': return <SignUpView go={go} />;
    case 'signin': return <SignInView go={go} onDone={done} />;
    case 'forgot': return <ForgotView go={go} />;
    case 'verify': return <VerifyView go={go} />;
    case 'consent': return <ConsentView go={go} />;
    case 'onboard': return <OnboardView go={go} onDone={done} />;
    case 'lock': return <LockView go={go} onDone={done} />;
    case 'guest': return <GuestView go={go} onDone={done} />;
    default: return <WelcomeView go={go} />;
  }
}

Object.assign(window, { ConsentView, OnboardView, LockView, GuestView, AuthFlow });
