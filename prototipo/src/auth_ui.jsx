/* Ascesa — auth form primitives (scoped) */

const authField = {
  wrap: { display: 'flex', flexDirection: 'column', gap: 7 },
  label: { fontSize: 12, fontWeight: 650, color: 'var(--text-2)', letterSpacing: 0.2 },
  box: { display: 'flex', alignItems: 'center', gap: 10, background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: 13, padding: '13px 14px', transition: 'border-color .15s, box-shadow .15s' },
  input: { flex: 1, background: 'transparent', border: 'none', outline: 'none', color: 'var(--text)', fontSize: 15.5, fontFamily: 'inherit', fontWeight: 500, minWidth: 0 },
};

function AuthField({ label, value, onChange, placeholder, type = 'text', icon, hint, error, right, autoFocus }) {
  const [focus, setFocus] = React.useState(false);
  return (
    <div style={authField.wrap}>
      {label && <label style={authField.label}>{label}</label>}
      <div style={{ ...authField.box, borderColor: error ? 'var(--z6)' : focus ? 'var(--accent)' : 'var(--line)', boxShadow: focus ? '0 0 0 3px color-mix(in oklch, var(--accent) 18%, transparent)' : 'none' }}>
        {icon && <window.Icon name={icon} size={18} color="var(--text-3)" />}
        <input value={value} onChange={e => onChange && onChange(e.target.value)} placeholder={placeholder} type={type}
          autoFocus={autoFocus} onFocus={() => setFocus(true)} onBlur={() => setFocus(false)} style={authField.input} />
        {right}
      </div>
      {(hint || error) && <div style={{ fontSize: 11.5, color: error ? 'var(--z6)' : 'var(--text-3)', paddingLeft: 2 }}>{error || hint}</div>}
    </div>
  );
}

function PasswordStrength({ value }) {
  const score = React.useMemo(() => {
    let s = 0;
    if (value.length >= 8) s++;
    if (/[A-Z]/.test(value) && /[a-z]/.test(value)) s++;
    if (/\d/.test(value)) s++;
    if (/[^A-Za-z0-9]/.test(value)) s++;
    return Math.min(4, s);
  }, [value]);
  const labels = ['Troppo debole', 'Debole', 'Discreta', 'Buona', 'Forte'];
  const cols = ['var(--z6)', 'var(--z6)', 'var(--z4)', 'var(--z3)', 'var(--z3)'];
  if (!value) return null;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, paddingLeft: 2 }}>
      <div style={{ display: 'flex', gap: 4, flex: 1 }}>
        {[0, 1, 2, 3].map(i => (
          <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: i < score ? cols[score] : 'var(--surface-2)', transition: 'background .2s' }} />
        ))}
      </div>
      <span style={{ fontSize: 11, fontWeight: 650, color: cols[score], minWidth: 78, textAlign: 'right' }}>{labels[score]}</span>
    </div>
  );
}

function SocialButton({ kind, onClick }) {
  if (kind === 'apple') {
    return (
      <button onClick={onClick} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9, width: '100%', background: '#fff', color: '#000', border: 'none', borderRadius: 13, padding: '13px', fontSize: 15.5, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
        {/* generic fruit placeholder glyph — not a brand mark */}
        <svg width="17" height="17" viewBox="0 0 24 24" fill="#000"><path d="M16.5 12.6c0-2.3 1.8-3.4 1.9-3.5-1-1.5-2.6-1.7-3.2-1.7-1.4-.1-2.7.8-3.3.8-.7 0-1.7-.8-2.8-.8-1.4 0-2.8.8-3.5 2.1-1.5 2.6-.4 6.5 1.1 8.6.7 1 1.5 2.2 2.6 2.2 1 0 1.4-.7 2.7-.7s1.6.7 2.7.7c1.1 0 1.8-1 2.5-2 .8-1.2 1.1-2.3 1.1-2.4-.1 0-2.1-.8-2.1-3.2Z" /><path d="M14.4 6.1c.6-.7 1-1.7.9-2.7-.9 0-1.9.6-2.5 1.3-.5.6-1 1.6-.9 2.6 1 .1 2-.5 2.5-1.2Z" /></svg>
        Continua con Apple
      </button>
    );
  }
  return (
    <button onClick={onClick} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9, width: '100%', background: 'var(--surface)', color: 'var(--text)', border: '1px solid var(--line)', borderRadius: 13, padding: '13px', fontSize: 15.5, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
      <span style={{ width: 17, height: 17, borderRadius: 9, background: 'conic-gradient(from -45deg, #ea4335, #fbbc05, #34a853, #4285f4, #ea4335)', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, fontWeight: 800, color: '#fff' }}>G</span>
      Continua con Google
    </button>
  );
}

function OrDivider({ label = 'oppure' }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '2px 0' }}>
      <div style={{ flex: 1, height: 1, background: 'var(--line-soft)' }} />
      <span style={{ fontSize: 12, color: 'var(--text-3)', fontWeight: 500 }}>{label}</span>
      <div style={{ flex: 1, height: 1, background: 'var(--line-soft)' }} />
    </div>
  );
}

function Toggle({ on, onChange }) {
  return (
    <button onClick={() => onChange(!on)} style={{ width: 46, height: 28, borderRadius: 14, border: 'none', cursor: 'pointer', padding: 3, background: on ? 'var(--accent)' : 'var(--surface-2)', transition: 'background .18s', flex: '0 0 auto' }}>
      <span style={{ display: 'block', width: 22, height: 22, borderRadius: 11, background: '#fff', transform: on ? 'translateX(18px)' : 'translateX(0)', transition: 'transform .18s', boxShadow: '0 1px 3px rgba(0,0,0,0.3)' }} />
    </button>
  );
}

function ConsentRow({ title, desc, on, onChange, required, last }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, padding: '14px 14px', borderBottom: last ? 'none' : '1px solid var(--line-soft)' }}>
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <span style={{ fontSize: 14.5, fontWeight: 700 }}>{title}</span>
          {required && <span style={{ fontSize: 9.5, fontWeight: 800, color: 'var(--z6)', border: '1px solid var(--z6)', borderRadius: 5, padding: '1px 5px', letterSpacing: 0.3 }}>OBBLIG.</span>}
        </div>
        <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 3, lineHeight: 1.45 }}>{desc}</div>
      </div>
      <Toggle on={on} onChange={onChange} />
    </div>
  );
}

const authBtnPrimary = { width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, background: 'var(--accent)', color: 'var(--accent-ink)', border: 'none', borderRadius: 14, padding: '15px', fontSize: 15.5, fontWeight: 750, cursor: 'pointer', fontFamily: 'inherit' };
const authBtnGhost = { width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, background: 'transparent', color: 'var(--text)', border: '1px solid var(--line)', borderRadius: 14, padding: '14px', fontSize: 15, fontWeight: 650, cursor: 'pointer', fontFamily: 'inherit' };
const authTextLink = { background: 'none', border: 'none', color: 'var(--accent)', fontWeight: 650, fontSize: 13.5, cursor: 'pointer', fontFamily: 'inherit', padding: 0 };

Object.assign(window, { AuthField, PasswordStrength, SocialButton, OrDivider, Toggle, ConsentRow, authBtnPrimary, authBtnGhost, authTextLink });
