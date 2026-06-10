/* Ascesa — shared screen chrome + Home + Device Connection */

const NavCtx = React.createContext({ go: () => {}, screen: 'home', startRide: () => {} });
window.NavCtx = NavCtx;

// ── shared chrome ──────────────────────────────────────────
function Scaffold({ children, tab, scroll = true, bottom }) {
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'var(--bg)', color: 'var(--text)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ flex: 1, overflowY: scroll ? 'auto' : 'hidden', WebkitOverflowScrolling: 'touch' }}>
        {children}
        <div style={{ height: tab ? 96 : 40 }} />
      </div>
      {bottom}
      {tab && <TabBar active={tab} />}
    </div>
  );
}

function TopBar({ title, large, onBack, action, sub }) {
  const nav = React.useContext(NavCtx);
  return (
    <div style={{ padding: large ? '54px 20px 6px' : '54px 16px 10px', position: 'sticky', top: 0, zIndex: 5, background: 'linear-gradient(var(--bg), var(--bg) 70%, transparent)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, minHeight: 36 }}>
        {onBack && (
          <button onClick={onBack} aria-label="Indietro" style={{ width: 36, height: 36, borderRadius: 18, border: 'none', background: 'var(--surface)', color: 'var(--text)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
            <window.Icon name="back" size={20} sw={2.1} />
          </button>
        )}
        {!large && <div style={{ flex: 1, fontSize: 17, fontWeight: 700, textAlign: onBack ? 'center' : 'left', marginRight: onBack ? 36 : 0 }}>{title}</div>}
        {!large && action}
      </div>
      {large && (
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginTop: 4 }}>
          <div>
            <div style={{ fontSize: 32, fontWeight: 780, letterSpacing: -0.8 }}>{title}</div>
            {sub && <div style={{ fontSize: 13, color: 'var(--text-3)', fontWeight: 500, marginTop: 2 }}>{sub}</div>}
          </div>
          {action}
        </div>
      )}
    </div>
  );
}

function TabBar({ active }) {
  const nav = React.useContext(NavCtx);
  const tabs = [
    { id: 'home', icon: 'home', label: 'Home' },
    { id: 'routes', icon: 'route', label: 'Percorsi' },
    { id: 'builder', icon: 'bolt', label: 'Allena' },
    { id: 'history', icon: 'history', label: 'Storico' },
    { id: 'profile', icon: 'gear', label: 'Profilo' },
  ];
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 86, paddingBottom: 22, display: 'flex', background: 'oklch(0.18 0.006 255 / 0.86)', backdropFilter: 'blur(20px)', borderTop: '1px solid var(--line-soft)' }}>
      {tabs.map(t => {
        const on = t.id === active;
        return (
          <button key={t.id} onClick={() => nav.go(t.id)} style={{ flex: 1, border: 'none', background: 'transparent', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, paddingTop: 10, color: on ? 'var(--accent)' : 'var(--text-3)' }}>
            <window.Icon name={t.icon} size={22} sw={on ? 2 : 1.7} />
            <span style={{ fontSize: 10, fontWeight: on ? 700 : 500 }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
}

function Card({ children, style, onClick, pad = 16 }) {
  return (
    <div onClick={onClick} style={{ background: 'var(--surface)', borderRadius: 'var(--radius-lg)', padding: pad, border: '1px solid var(--line-soft)', cursor: onClick ? 'pointer' : 'default', ...style }}>{children}</div>
  );
}
function SectionLabel({ children, style }) {
  return <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: 0.6, padding: '0 6px 8px', ...style }}>{children}</div>;
}

// generic grade-coloured profile (for cards/details) --------
function HeatProfile({ profile, lengthM, w = 340, h = 64, marker, startEle = 200 }) {
  const { pts, eMin, eMax } = window.AscesaData.elevFromGrades(profile, lengthM, startEle);
  const span = (eMax - eMin) || 1; const pe = span * 0.12 + 3;
  const lo = eMin - pe, hi = eMax + pe;
  const sx = (d) => (d / lengthM) * w;
  const sy = (e) => h - ((e - lo) / (hi - lo)) * (h - 3);
  const segs = [];
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i], b = pts[i + 1], g = (profile[i] + profile[i + 1]) / 2;
    segs.push(<polygon key={i} points={`${sx(a.d)},${h} ${sx(a.d)},${sy(a.ele)} ${sx(b.d)},${sy(b.ele)} ${sx(b.d)},${h}`} fill={window.gradeColor(g)} fillOpacity={0.8} />);
  }
  let line = ''; pts.forEach((p, i) => { line += (i ? 'L' : 'M') + sx(p.d).toFixed(1) + ' ' + sy(p.ele).toFixed(1); });
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block' }}>
      {segs}
      <path d={line} fill="none" stroke="rgba(255,255,255,0.45)" strokeWidth="1.2" strokeLinejoin="round" />
      {marker != null && <line x1={marker * w} y1="0" x2={marker * w} y2={h} stroke="#fff" strokeWidth="1.5" />}
    </svg>
  );
}

// simple line/area chart -----------------------------------
function MiniChart({ data, w = 340, h = 60, color = 'var(--accent)', fill = false, sw = 1.6, baseline }) {
  if (!data || !data.length) return null;
  let lo = Math.min(...data), hi = Math.max(...data);
  if (baseline != null) lo = Math.min(lo, baseline);
  const pad = (hi - lo) * 0.1 || 1; lo -= pad; hi += pad;
  const sx = (i) => (i / (data.length - 1)) * w;
  const sy = (v) => h - ((v - lo) / (hi - lo)) * h;
  let d = ''; data.forEach((v, i) => { d += (i ? 'L' : 'M') + sx(i).toFixed(1) + ' ' + sy(v).toFixed(1); });
  const area = d + `L${w} ${h} L0 ${h} Z`;
  const gid = 'mc' + Math.random().toString(36).slice(2, 7);
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block' }}>
      {fill && <defs><linearGradient id={gid} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={color} stopOpacity="0.35" /><stop offset="1" stopColor={color} stopOpacity="0" /></linearGradient></defs>}
      {fill && <path d={area} fill={`url(#${gid})`} />}
      <path d={d} fill="none" stroke={color} strokeWidth={sw} strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}

// ── HOME ───────────────────────────────────────────────────
function HomeScreen() {
  const nav = React.useContext(NavCtx);
  const s = window.useEngine();
  const R = window.ROUTE;
  const inProgress = s.elapsed > 0 && !s.finished;
  return (
    <Scaffold tab="home">
      <TopBar large title="Ciao, Marco" sub="Lunedì 9 giugno · pronto a salire" action={
        <button onClick={() => nav.go('connect')} style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'var(--surface)', border: '1px solid var(--line-soft)', borderRadius: 999, padding: '7px 12px', cursor: 'pointer', color: 'var(--text-2)' }}>
          <span style={{ width: 7, height: 7, borderRadius: 4, background: 'var(--z3)', boxShadow: '0 0 8px var(--z3)' }} />
          <span style={{ fontSize: 12, fontWeight: 650 }}>2 device</span>
        </button>
      } />
      <div style={{ padding: '4px 16px 0', display: 'flex', flexDirection: 'column', gap: 16 }}>
        {inProgress && (
          <Card onClick={() => nav.go('ride')} pad={14} style={{ background: 'var(--accent-ink)', border: '1px solid var(--accent-dim)', display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: 20, background: 'var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}><window.Icon name="play" size={18} color="var(--accent-ink)" /></div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 700 }}>Riprendi la sessione</div>
              <div className="tnum" style={{ fontSize: 12, color: 'var(--text-2)' }}>{window.fmtTime(s.elapsed)} · {window.fmtKm(s.distance)} km · {s.mode}</div>
            </div>
            <window.Icon name="chev" size={20} color="var(--text-2)" />
          </Card>
        )}

        {/* hero route */}
        <Card pad={0} style={{ overflow: 'hidden' }}>
          <div className="ph-stripe" style={{ height: 132, position: 'relative', display: 'flex', alignItems: 'flex-end' }}>
            <div style={{ position: 'absolute', top: 12, left: 14, fontSize: 10, fontFamily: 'var(--mono)', color: 'var(--text-3)', letterSpacing: 0.5 }}>[ MAPPA · anteprima percorso ]</div>
            <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(transparent, rgba(14,16,20,0.55))' }} />
            <div style={{ position: 'relative', padding: 14 }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--accent)', letterSpacing: 0.5, textTransform: 'uppercase' }}>Percorso selezionato</div>
              <div style={{ fontSize: 22, fontWeight: 780, letterSpacing: -0.5 }}>{R.name}</div>
              <div style={{ fontSize: 12, color: 'var(--text-2)', fontWeight: 500 }}>{R.sub}</div>
            </div>
          </div>
          <div style={{ padding: '12px 16px 4px' }}>
            <HeatProfile profile={window.AscesaData.ROUTES[0].profile} lengthM={R.lengthM} w={338} h={56} marker={(s.offset) / R.lengthM} startEle={R.startEle} />
            <div className="tnum" style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 2px 4px' }}>
              <Stat3 v={(R.lengthM / 1000).toFixed(1)} u="km" l="distanza" />
              <Stat3 v={'+' + R.gain} u="m" l="dislivello" />
              <Stat3 v={R.avg} u="%" l="media" />
              <Stat3 v={R.max} u="%" l="max" />
            </div>
          </div>
          <div style={{ display: 'flex', gap: 10, padding: 16 }}>
            <button onClick={() => nav.startRide('SIM')} style={btnPrimary}><window.Icon name="mountain" size={18} color="var(--accent-ink)" />Pedala il percorso</button>
            <button onClick={() => nav.go('routes')} style={btnGhostSquare} aria-label="Libreria percorsi"><window.Icon name="search" size={20} /></button>
          </div>
        </Card>

        {/* structured workout shortcut */}
        <Card onClick={() => nav.go('builder')} style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ width: 56, height: 44, flex: '0 0 auto' }}><window.IntervalBar elapsed={0} w={56} h={44} /></div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: 0.5 }}>Workout ERG</div>
            <div style={{ fontSize: 16, fontWeight: 700 }}>{window.WORKOUT.name}</div>
            <div style={{ fontSize: 12, color: 'var(--text-2)' }}>{window.WORKOUT.sub} · 50:00</div>
          </div>
          <window.Icon name="chev" size={20} color="var(--text-3)" />
        </Card>

        <div>
          <SectionLabel>Attività recenti</SectionLabel>
          <Card pad={4}>
            {window.AscesaData.HISTORY.slice(0, 2).map((h, i) => (
              <HistoryRow key={h.id} h={h} last={i === 1} onClick={() => nav.go('detail', h)} />
            ))}
          </Card>
        </div>
      </div>
    </Scaffold>
  );
}

function Stat3({ v, u, l }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}><span style={{ fontSize: 19, fontWeight: 750, letterSpacing: -0.5 }}>{v}</span><span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 600 }}>{u}</span></div>
      <div style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.4 }}>{l}</div>
    </div>
  );
}

// shared history row (also used in History screen) ----------
function HistoryRow({ h, last, onClick }) {
  return (
    <div onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 12px', cursor: 'pointer', borderBottom: last ? 'none' : '1px solid var(--line-soft)' }}>
      <div style={{ width: 38, height: 38, borderRadius: 12, flex: '0 0 auto', background: h.type === 'SIM' ? 'var(--accent-ink)' : 'var(--surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <window.Icon name={h.type === 'SIM' ? 'mountain' : 'bolt'} size={18} color={h.type === 'SIM' ? 'var(--accent)' : 'var(--z4)'} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 14.5, fontWeight: 700, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{h.title}</span>
          {h.pr && <span style={{ fontSize: 9, fontWeight: 800, color: 'var(--accent-ink)', background: 'var(--accent)', borderRadius: 5, padding: '1px 4px' }}>PR</span>}
        </div>
        <div className="tnum" style={{ fontSize: 12, color: 'var(--text-3)' }}>{h.date} · {window.fmtTime(h.dur)} · {h.dist} km</div>
      </div>
      <div className="tnum" style={{ textAlign: 'right' }}>
        <div style={{ fontSize: 15, fontWeight: 750 }}>{h.tss}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 600 }}> TSS</span></div>
        <div style={{ fontSize: 11, color: 'var(--text-3)' }}>{h.avgP} W</div>
      </div>
    </div>
  );
}

const btnPrimary = { flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, background: 'var(--accent)', color: 'var(--accent-ink)', border: 'none', borderRadius: 14, padding: '13px 16px', fontSize: 15, fontWeight: 750, cursor: 'pointer', fontFamily: 'inherit' };
const btnGhostSquare = { width: 48, flex: '0 0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--surface-2)', color: 'var(--text)', border: 'none', borderRadius: 14, cursor: 'pointer' };

// ── DEVICE CONNECTION ──────────────────────────────────────
function DeviceRow({ icon, name, detail, status, color, right, onClick }) {
  return (
    <div onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 14px', cursor: onClick ? 'pointer' : 'default' }}>
      <div style={{ width: 42, height: 42, borderRadius: 12, flex: '0 0 auto', background: 'var(--surface-2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <window.Icon name={icon} size={20} color={color || 'var(--text-2)'} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 700 }}>{name}</div>
        <div style={{ fontSize: 12, color: 'var(--text-3)' }}>{detail}</div>
      </div>
      {right || (status && <span style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 12.5, fontWeight: 650, color: 'var(--z3)' }}><span style={{ width: 7, height: 7, borderRadius: 4, background: 'var(--z3)', boxShadow: '0 0 8px var(--z3)' }} />{status}</span>)}
    </div>
  );
}

function ConnectionScreen() {
  const nav = React.useContext(NavCtx);
  const [cal, setCal] = React.useState(0); // 0 idle, 1..100 progress, 101 done
  React.useEffect(() => {
    if (cal > 0 && cal <= 100) { const t = setTimeout(() => setCal(c => c + 8), 90); return () => clearTimeout(t); }
  }, [cal]);
  const calibrating = cal > 0 && cal <= 100;
  return (
    <Scaffold>
      <TopBar title="Dispositivi" onBack={() => nav.back()} />
      <div style={{ padding: '4px 16px', display: 'flex', flexDirection: 'column', gap: 18 }}>
        <div>
          <SectionLabel>Rullo smart</SectionLabel>
          <Card pad={0}>
            <DeviceRow icon="bt" name="TACX FLUX S" detail="FTMS · potenza, cadenza, controllo resistenza" color="var(--accent)" status="Connesso" />
            <div style={{ height: 1, background: 'var(--line-soft)', margin: '0 14px' }} />
            <div style={{ padding: 14 }}>
              {!calibrating && cal !== 101 && (
                <button onClick={() => setCal(8)} style={{ ...rowBtn }}>
                  <div><div style={{ fontSize: 14, fontWeight: 700 }}>Calibrazione (spindown)</div><div style={{ fontSize: 12, color: 'var(--text-3)' }}>Ultima: 4 giorni fa</div></div>
                  <window.Icon name="chev" size={18} color="var(--text-3)" />
                </button>
              )}
              {calibrating && (
                <div>
                  <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 4 }}>Pedala fino a 35 km/h e ferma…</div>
                  <div style={{ height: 8, background: 'var(--surface-2)', borderRadius: 5, overflow: 'hidden' }}><div style={{ width: cal + '%', height: '100%', background: 'var(--accent)', transition: 'width .1s' }} /></div>
                </div>
              )}
              {cal === 101 && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--z3)' }}><window.Icon name="check" size={18} color="var(--z3)" /><span style={{ fontSize: 14, fontWeight: 700 }}>Calibrato — offset 8,2 Nm</span></div>
              )}
            </div>
          </Card>
        </div>

        <div>
          <SectionLabel>Frequenza cardiaca</SectionLabel>
          <Card pad={0}>
            <DeviceRow icon="watch" name="Apple Watch" detail="HealthKit · sorgente primaria HR" color="var(--z5)" right={<span style={{ fontSize: 11, fontWeight: 750, color: 'var(--accent-ink)', background: 'var(--accent)', borderRadius: 6, padding: '3px 8px' }}>PRIMARIA</span>} />
            <div style={{ height: 1, background: 'var(--line-soft)', margin: '0 14px' }} />
            <DeviceRow icon="heart" name="Fascia toracica BLE" detail="Ripiego se l'orologio non è in sessione" status="Pronta" />
          </Card>
          <div style={{ fontSize: 11.5, color: 'var(--text-3)', padding: '8px 8px 0', lineHeight: 1.45 }}>
            L'Apple Watch trasmette l'HR via app companion durante un <i>workout</i> HealthKit — non come fascia BLE standard.
          </div>
        </div>

        <div>
          <SectionLabel>Sensori opzionali</SectionLabel>
          <Card pad={0}>
            <DeviceRow icon="cadence" name="Aggiungi sensore" detail="Cadenza, velocità o power meter separato" right={<window.Icon name="plus" size={20} color="var(--text-3)" />} onClick={() => {}} />
          </Card>
        </div>
      </div>
    </Scaffold>
  );
}
const rowBtn = { width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'transparent', border: 'none', color: 'var(--text)', cursor: 'pointer', fontFamily: 'inherit', padding: 0, textAlign: 'left' };

Object.assign(window, { Scaffold, TopBar, TabBar, Card, SectionLabel, HeatProfile, MiniChart, HomeScreen, HistoryRow, Stat3, ConnectionScreen, btnPrimary, btnGhostSquare });
