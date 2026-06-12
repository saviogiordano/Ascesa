/* Ascesa — AuthFlow: welcome → sign up / sign in → verify → consent → onboarding */

function AuthShell({ children, onBack, title, scroll = true }) {
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'var(--bg)', color: 'var(--text)', display: 'flex', flexDirection: 'column' }}>
      {onBack && (
        <div style={{ padding: '52px 16px 4px', flex: '0 0 auto' }}>
          <button onClick={onBack} aria-label="Indietro" style={{ width: 36, height: 36, borderRadius: 18, border: 'none', background: 'var(--surface)', color: 'var(--text)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <window.Icon name="back" size={20} sw={2.1} />
          </button>
        </div>
      )}
      <div style={{ flex: 1, overflowY: scroll ? 'auto' : 'hidden', padding: onBack ? '8px 22px 28px' : '60px 22px 28px' }}>
        {children}
      </div>
    </div>
  );
}

function BrandMark({ size = 64 }) {
  return (
    <div style={{ width: size, height: size, borderRadius: size * 0.32, background: 'var(--accent-ink)', border: '1px solid var(--accent-dim)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <svg width={size * 0.6} height={size * 0.6} viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="2.1" strokeLinejoin="round" strokeLinecap="round">
        <polyline points="3,19 9,9 13,13 17,6 21,19" />
        <circle cx="13" cy="13" r="1.1" fill="var(--accent)" stroke="none" />
      </svg>
    </div>
  );
}

// ── WELCOME ────────────────────────────────────────────────
function WelcomeView({ go }) {
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'var(--bg)', color: 'var(--text)', display: 'flex', flexDirection: 'column' }}>
      <div className="ph-stripe" style={{ position: 'absolute', inset: 0, opacity: 0.5 }} />
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, transparent, var(--bg) 62%)' }} />
      <div style={{ position: 'absolute', top: 70, left: 24, fontSize: 10, fontFamily: 'var(--mono)', color: 'var(--text-3)' }}>[ IMG · ciclista su salita all'alba ]</div>
      <div style={{ position: 'relative', marginTop: 'auto', padding: '0 24px 34px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        <BrandMark size={60} />
        <div>
          <div style={{ fontSize: 38, fontWeight: 820, letterSpacing: -1.2, lineHeight: 1.0 }}>Ascesa</div>
          <div style={{ fontSize: 16, color: 'var(--text-2)', marginTop: 8, lineHeight: 1.45, maxWidth: 300 }}>Allenati indoor su salite vere. Potenza, cuore e pendenza, in un colpo d'occhio.</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 6 }}>
          <button onClick={() => go('signup')} style={window.authBtnPrimary}>Crea un account</button>
          <button onClick={() => go('signin')} style={window.authBtnGhost}>Ho già un account</button>
          <button onClick={() => go('guest')} style={{ ...window.authTextLink, alignSelf: 'center', marginTop: 6, fontSize: 14, color: 'var(--text-2)' }}>Continua come ospite →</button>
        </div>
      </div>
    </div>
  );
}

// ── SIGN UP ────────────────────────────────────────────────
function SignUpView({ go }) {
  const [email, setEmail] = React.useState('');
  const [pw, setPw] = React.useState('');
  const [show, setShow] = React.useState(false);
  const valid = /.+@.+\..+/.test(email) && pw.length >= 8;
  return (
    <AuthShell onBack={() => go('welcome')}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div>
          <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>Crea il tuo account</div>
          <div style={{ fontSize: 14, color: 'var(--text-3)', marginTop: 4 }}>Bastano un'email e una password.</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <window.SocialButton kind="apple" onClick={() => go('onboard')} />
          <window.SocialButton kind="google" onClick={() => go('consent')} />
        </div>
        <window.OrDivider />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <window.AuthField label="Email" value={email} onChange={setEmail} placeholder="tu@esempio.it" type="email" icon="route" />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <window.AuthField label="Password" value={pw} onChange={setPw} placeholder="Almeno 8 caratteri" type={show ? 'text' : 'password'} icon="gear"
              right={<button onClick={() => setShow(!show)} style={{ ...window.authTextLink, fontSize: 12 }}>{show ? 'Nascondi' : 'Mostra'}</button>} />
            <window.PasswordStrength value={pw} />
          </div>
        </div>
        <button disabled={!valid} onClick={() => go('verify')} style={{ ...window.authBtnPrimary, opacity: valid ? 1 : 0.4, cursor: valid ? 'pointer' : 'default' }}>Continua</button>
        <div style={{ fontSize: 11.5, color: 'var(--text-3)', textAlign: 'center', lineHeight: 1.5 }}>
          Proseguendo accetti i <b style={{ color: 'var(--text-2)' }}>Termini</b> e la <b style={{ color: 'var(--text-2)' }}>Privacy policy</b>. I dati sanitari sono trattati con consenso esplicito.
        </div>
        <div style={{ textAlign: 'center', fontSize: 13.5, color: 'var(--text-3)' }}>
          Hai già un account? <button onClick={() => go('signin')} style={window.authTextLink}>Accedi</button>
        </div>
      </div>
    </AuthShell>
  );
}

// ── SIGN IN ────────────────────────────────────────────────
function SignInView({ go, onDone }) {
  const [email, setEmail] = React.useState('marco.vinci@esempio.it');
  const [pw, setPw] = React.useState('');
  const [show, setShow] = React.useState(false);
  return (
    <AuthShell onBack={() => go('welcome')}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div>
          <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>Bentornato</div>
          <div style={{ fontSize: 14, color: 'var(--text-3)', marginTop: 4 }}>Accedi per ritrovare i tuoi allenamenti.</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <window.AuthField label="Email" value={email} onChange={setEmail} placeholder="tu@esempio.it" type="email" icon="route" />
          <window.AuthField label="Password" value={pw} onChange={setPw} placeholder="La tua password" type={show ? 'text' : 'password'} icon="gear"
            right={<button onClick={() => setShow(!show)} style={{ ...window.authTextLink, fontSize: 12 }}>{show ? 'Nascondi' : 'Mostra'}</button>} />
          <div style={{ textAlign: 'right', marginTop: -4 }}>
            <button onClick={() => go('forgot')} style={window.authTextLink}>Password dimenticata?</button>
          </div>
        </div>
        <button onClick={onDone} style={window.authBtnPrimary}>Accedi</button>
        <button onClick={() => go('lock')} style={{ ...window.authBtnGhost, gap: 9 }}>
          <window.Icon name="check" size={18} color="var(--accent)" />Sblocca con Face ID
        </button>
        <window.OrDivider />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <window.SocialButton kind="apple" onClick={onDone} />
        </div>
        <div style={{ textAlign: 'center', fontSize: 13.5, color: 'var(--text-3)' }}>
          Non hai un account? <button onClick={() => go('signup')} style={window.authTextLink}>Registrati</button>
        </div>
      </div>
    </AuthShell>
  );
}

// ── FORGOT PASSWORD ────────────────────────────────────────
function ForgotView({ go }) {
  const [sent, setSent] = React.useState(false);
  const [email, setEmail] = React.useState('');
  return (
    <AuthShell onBack={() => go('signin')}>
      {!sent ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          <div>
            <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>Reimposta password</div>
            <div style={{ fontSize: 14, color: 'var(--text-3)', marginTop: 4, lineHeight: 1.5 }}>Ti inviamo un link di ripristino a scadenza. Controlla anche lo spam.</div>
          </div>
          <window.AuthField label="Email" value={email} onChange={setEmail} placeholder="tu@esempio.it" type="email" icon="route" autoFocus />
          <button onClick={() => setSent(true)} style={window.authBtnPrimary}>Invia link di ripristino</button>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, textAlign: 'center', paddingTop: 40 }}>
          <div style={{ width: 64, height: 64, borderRadius: 32, background: 'var(--accent-ink)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <window.Icon name="check" size={30} color="var(--accent)" />
          </div>
          <div style={{ fontSize: 22, fontWeight: 780 }}>Controlla la posta</div>
          <div style={{ fontSize: 14, color: 'var(--text-3)', lineHeight: 1.5, maxWidth: 280 }}>Abbiamo inviato un link a <b style={{ color: 'var(--text-2)' }}>{email || 'la tua email'}</b>. Il link scade tra 30 minuti.</div>
          <button onClick={() => go('signin')} style={{ ...window.authBtnGhost, marginTop: 8 }}>Torna all'accesso</button>
        </div>
      )}
    </AuthShell>
  );
}

// ── EMAIL VERIFY (code) ────────────────────────────────────
function VerifyView({ go }) {
  const [code, setCode] = React.useState(['', '', '', '', '', '']);
  const refs = React.useRef([]);
  const set = (i, v) => {
    if (!/^\d?$/.test(v)) return;
    setCode(c => { const n = [...c]; n[i] = v; return n; });
    if (v && refs.current[i + 1]) refs.current[i + 1].focus();
  };
  const full = code.every(c => c !== '');
  return (
    <AuthShell onBack={() => go('signup')}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div>
          <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.6 }}>Verifica l'email</div>
          <div style={{ fontSize: 14, color: 'var(--text-3)', marginTop: 6, lineHeight: 1.5 }}>Inserisci il codice a 6 cifre che ti abbiamo inviato. Serve a confermare che l'indirizzo è tuo.</div>
        </div>
        <div style={{ display: 'flex', gap: 9, justifyContent: 'space-between' }}>
          {code.map((c, i) => (
            <input key={i} ref={el => refs.current[i] = el} value={c} onChange={e => set(i, e.target.value)}
              inputMode="numeric" maxLength={1} className="tnum"
              style={{ width: 46, height: 58, textAlign: 'center', fontSize: 24, fontWeight: 750, color: 'var(--text)', background: 'var(--surface)', border: '1px solid ' + (c ? 'var(--accent)' : 'var(--line)'), borderRadius: 13, outline: 'none', fontFamily: 'inherit' }} />
          ))}
        </div>
        <button disabled={!full} onClick={() => go('consent')} style={{ ...window.authBtnPrimary, opacity: full ? 1 : 0.4 }}>Verifica</button>
        <div style={{ textAlign: 'center', fontSize: 13.5, color: 'var(--text-3)' }}>
          Non l'hai ricevuto? <button style={window.authTextLink}>Invia di nuovo</button> <span style={{ opacity: 0.6 }}>(0:42)</span>
        </div>
      </div>
    </AuthShell>
  );
}

Object.assign(window, { AuthShell, BrandMark, WelcomeView, SignUpView, SignInView, ForgotView, VerifyView });
