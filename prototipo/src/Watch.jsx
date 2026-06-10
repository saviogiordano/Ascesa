/* Ascesa — Apple Watch companion */

function WatchApp() {
  const s = window.useEngine();
  return (
    <div style={{ position: 'absolute', inset: 0, background: '#000', color: 'var(--text)', display: 'flex', flexDirection: 'column', padding: '12px 16px 14px', fontFamily: 'var(--font)' }}>
      {/* status row */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 2 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
          <span style={{ width: 7, height: 7, borderRadius: 4, background: s.running ? 'var(--z6)' : 'var(--text-3)', boxShadow: s.running ? '0 0 7px var(--z6)' : 'none' }} />
          <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--accent)' }}>Ascesa</span>
        </div>
        <span className="tnum" style={{ fontSize: 13, fontWeight: 600, color: 'var(--accent)' }}>9:41</span>
      </div>

      {/* HR hero */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, color: window.hzColor(s.hr) }}>
          <window.Icon name="heart" size={16} color={window.hzColor(s.hr)} />
          <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.4 }}>CARDIO · Z{window.RideZones.hrZone(s.hr)}</span>
        </div>
        <div className="tnum" style={{ display: 'flex', alignItems: 'baseline', gap: 4, color: window.hzColor(s.hr), lineHeight: 0.9, marginTop: 7 }}>
          <span style={{ fontSize: 72, fontWeight: 750, letterSpacing: -3 }}>{s.hr}</span>
          <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--text-3)' }}>bpm</span>
        </div>
        <div className="tnum" style={{ display: 'flex', gap: 16, marginTop: 12 }}>
          <div>
            <div style={{ fontSize: 22, fontWeight: 750, color: window.pzColor(s.power), letterSpacing: -1 }}>{Math.round(s.power)}<span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 600 }}> W</span></div>
          </div>
          <div>
            <div style={{ fontSize: 22, fontWeight: 750, letterSpacing: -1 }}>{window.fmtTime(s.elapsed)}</div>
          </div>
        </div>
      </div>

      {/* controls */}
      <div style={{ display: 'flex', gap: 10 }}>
        <button onClick={() => window.RideEngine.lap()} style={watchBtn('var(--z3)')}><window.Icon name="lap" size={20} color="var(--z3)" /></button>
        <button onClick={() => window.RideEngine.toggle()} style={watchBtn('var(--accent)')}><window.Icon name={s.running ? 'pause' : 'play'} size={20} color="var(--accent)" /></button>
      </div>
    </div>
  );
}
const watchBtn = (c) => ({ flex: 1, height: 44, borderRadius: 22, border: 'none', background: 'color-mix(in oklch, ' + c + ' 16%, #000)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' });

function WatchFrame({ children }) {
  return (
    <div style={{ position: 'relative', width: 208, height: 252 }}>
      {/* crown + button */}
      <div style={{ position: 'absolute', right: -5, top: 78, width: 8, height: 30, borderRadius: 4, background: 'linear-gradient(#3a3a3e,#1c1c1e)' }} />
      <div style={{ position: 'absolute', right: -4, top: 120, width: 6, height: 44, borderRadius: 4, background: 'linear-gradient(#2a2a2e,#161618)' }} />
      {/* case */}
      <div style={{ position: 'absolute', inset: 0, borderRadius: 52, background: 'linear-gradient(150deg,#48484c,#222226)', padding: 9, boxShadow: '0 30px 60px rgba(0,0,0,0.45)' }}>
        <div style={{ position: 'relative', width: '100%', height: '100%', borderRadius: 44, overflow: 'hidden', background: '#000' }}>
          {children}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { WatchApp, WatchFrame });
