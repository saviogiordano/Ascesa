/* Ascesa — Live Dashboard (3 layout variants × ERG/SIM) */

// shared screen chrome ------------------------------------------------------
function StatusDots() {
  const dot = (on, label, icon) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: on ? 'var(--text-2)' : 'var(--text-3)' }}>
      <window.Icon name={icon} size={13} sw={1.8} color={on ? 'var(--z3)' : 'var(--text-3)'} />
    </div>
  );
  return (
    <div style={{ display: 'flex', gap: 9, alignItems: 'center' }}>
      {dot(true, 'Rullo', 'bt')}
      {dot(true, 'Watch', 'watch')}
    </div>
  );
}

function DashHeader({ s }) {
  const remM = window.RideEngine.remainingM();
  const remT = window.RideEngine.remainingT();
  const right = s.mode === 'SIM'
    ? `${window.fmtKm(remM)} km al GPM`
    : `${window.fmtTime(remT)} alla fine`;
  const prog = s.mode === 'SIM'
    ? Math.min(1, (s.offset + s.distance) / window.ROUTE.lengthM)
    : Math.min(1, s.elapsed / window.WORKOUT.total);
  return (
    <div style={{ padding: '52px 20px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <window.Segmented dense options={[{ value: 'SIM', label: 'SIM' }, { value: 'ERG', label: 'ERG' }]}
          value={s.mode} onChange={(m) => window.RideEngine.setMode(m)} />
        <div style={{ textAlign: 'center', flex: 1 }}>
          <div className="tnum" style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.5, color: 'var(--text)' }}>{window.fmtTime(s.elapsed)}</div>
        </div>
        <StatusDots />
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 8 }}>
        <div style={{ fontSize: 11.5, fontWeight: 600, color: 'var(--text-3)', letterSpacing: 0.3, textTransform: 'uppercase', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {s.mode === 'SIM' ? `${window.ROUTE.name} · ${window.ROUTE.sub}` : window.WORKOUT.name}
        </div>
        <div className="tnum" style={{ fontSize: 11.5, fontWeight: 600, color: 'var(--text-2)' }}>{right}</div>
      </div>
      <div style={{ height: 3, background: 'var(--line-soft)', borderRadius: 2, marginTop: 7, overflow: 'hidden' }}>
        <div style={{ width: `${prog * 100}%`, height: '100%', background: 'var(--accent)', borderRadius: 2, transition: 'width .3s' }} />
      </div>
    </div>
  );
}

// context band — SIM profile or ERG intervals -----------------------------
function ContextBand({ s, big }) {
  if (s.mode === 'SIM') {
    const posM = s.offset + s.distance;
    const grade = window.RideZones.gradeAt(posM);
    const h = big ? 188 : 120;
    return (
      <div style={{ padding: big ? '4px 0 0' : 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', padding: '0 20px 8px' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
              <span className="tnum" style={{ fontSize: big ? 44 : 30, fontWeight: 720, color: window.gradeColor(grade), letterSpacing: -1.5, lineHeight: 0.9 }}>{grade.toFixed(1)}</span>
              <span style={{ fontSize: 16, fontWeight: 600, color: 'var(--text-3)' }}>% pendenza</span>
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="tnum" style={{ fontSize: 15, fontWeight: 700, color: 'var(--text)' }}>{Math.round(s.ele)} m</div>
            <div className="tnum" style={{ fontSize: 11.5, color: 'var(--text-3)', fontWeight: 600 }}>+{Math.round(window.ROUTE.summit - s.ele)} m al GPM</div>
          </div>
        </div>
        <div style={{ padding: '0 12px' }}>
          <window.ElevationProfile posM={posM} w={big ? 366 : 366} h={h} mode={big ? 'ahead' : 'ahead'} />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 20px 0', fontSize: 11, color: 'var(--text-3)', fontWeight: 600 }}>
          <span className="tnum">{window.fmtKmFine(s.offset + s.distance)} km</span>
          <span>prossimi 1,5 km →</span>
        </div>
      </div>
    );
  }
  // ERG
  const e = window.RideEngine.erg();
  const blk = e.block, into = e.into, left = blk.dur - into;
  const next = window.WORKOUT.blocks[e.idx + 1];
  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', padding: '0 20px 8px' }}>
        <div>
          <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: 0.5 }}>{blk.label}</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
            <span className="tnum" style={{ fontSize: big ? 40 : 30, fontWeight: 720, color: window.pzColor(blk.power), letterSpacing: -1.5, lineHeight: 0.9 }}>{blk.power}</span>
            <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--text-3)' }}>W target</span>
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div className="tnum" style={{ fontSize: big ? 36 : 28, fontWeight: 700, color: 'var(--text)', letterSpacing: -1 }}>{window.fmtTime(left)}</div>
          <div style={{ fontSize: 11.5, color: 'var(--text-3)', fontWeight: 600 }}>{next ? `poi ${next.label} · ${next.power} W` : 'ultimo blocco'}</div>
        </div>
      </div>
      <div style={{ padding: '0 12px' }}>
        <window.IntervalBar elapsed={s.elapsed} w={366} h={big ? 150 : 96} />
      </div>
    </div>
  );
}

// finish overlay ----------------------------------------------------------
function FinishOverlay({ s, onSummary }) {
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 80, background: 'rgba(14,16,20,0.78)', backdropFilter: 'blur(8px)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 18, padding: 30, textAlign: 'center' }}>
      <window.Icon name="flag" size={40} color="var(--accent)" />
      <div style={{ fontSize: 24, fontWeight: 750, color: 'var(--text)' }}>Sessione conclusa</div>
      <div className="tnum" style={{ display: 'flex', gap: 22, color: 'var(--text-2)', fontSize: 13 }}>
        <span><b style={{ color: 'var(--text)', fontSize: 17 }}>{window.fmtTime(s.elapsed)}</b><br />tempo</span>
        <span><b style={{ color: 'var(--text)', fontSize: 17 }}>{window.fmtKm(s.distance)}</b><br />km</span>
        <span><b style={{ color: 'var(--text)', fontSize: 17 }}>{Math.round(s.work)}</b><br />kJ</span>
      </div>
      <div style={{ display: 'flex', gap: 10, marginTop: 4 }}>
        <button onClick={() => window.RideEngine.reset()} style={ghostBtn}>Nuova sessione</button>
        {onSummary && <button onClick={onSummary} style={accentBtn}>Vedi riepilogo</button>}
      </div>
    </div>
  );
}
const ghostBtn = { border: '1px solid var(--line)', background: 'transparent', color: 'var(--text)', padding: '11px 18px', borderRadius: 12, fontWeight: 650, fontSize: 14, cursor: 'pointer', fontFamily: 'inherit' };
const accentBtn = { border: 'none', background: 'var(--accent)', color: 'var(--accent-ink)', padding: '11px 18px', borderRadius: 12, fontWeight: 700, fontSize: 14, cursor: 'pointer', fontFamily: 'inherit' };

// dock --------------------------------------------------------------------
function DashDock({ s }) {
  return (
    <div style={{ padding: '14px 28px 30px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <window.RoundBtn icon="lap" label="Lap" onClick={() => window.RideEngine.lap()} size={54} iconSize={22} />
      <window.RoundBtn icon={s.running ? 'pause' : 'play'} label="Play/Pausa"
        onClick={() => window.RideEngine.toggle()} size={72} iconSize={30}
        active color="var(--accent)" ink="var(--accent-ink)" />
      <window.RoundBtn icon="flag" label="Termina" onClick={() => window.RideEngine.finish()} size={54} iconSize={22} color="var(--z6)" />
    </div>
  );
}

// small secondary metric (for variant A row) -----------------------------
function MiniMetric({ icon, value, unit, label, color = 'var(--text)' }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3 }}>
      <window.Icon name={icon} size={15} color="var(--text-3)" sw={1.8} />
      <div className="tnum" style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}>
        <span style={{ fontSize: 30, fontWeight: 700, color, letterSpacing: -1 }}>{value}</span>
        <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-3)' }}>{unit}</span>
      </div>
      <div style={{ fontSize: 10, fontWeight: 600, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
    </div>
  );
}

// ── VARIANT A — single hero (power) ───────────────────────────
function BodyFocus({ s }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '0 20px', gap: 18 }}>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, color: 'var(--text-3)' }}>
          <window.Icon name="bolt" size={15} color="var(--text-3)" />
          <span style={{ fontSize: 12, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase' }}>Potenza</span>
        </div>
        <div className="tnum" style={{ display: 'flex', alignItems: 'baseline', gap: 8, color: window.pzColor(s.power), lineHeight: 0.85 }}>
          <span style={{ fontSize: 118, fontWeight: 700, letterSpacing: -5 }}>{Math.round(s.power)}</span>
          <span style={{ fontSize: 26, fontWeight: 600, color: 'var(--text-3)' }}>W</span>
        </div>
        <div style={{ width: 220 }}><window.ZoneScale value={s.power} zones="power" h={7} /></div>
        <div className="tnum" style={{ display: 'flex', gap: 16, fontSize: 12.5, color: 'var(--text-3)', fontWeight: 600, marginTop: 2 }}>
          <span>media {s.powerAvg} W</span><span>NP {s.np} W</span><span>3s {s.power3} W</span>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 6, padding: '12px 0', borderTop: '1px solid var(--line-soft)', borderBottom: '1px solid var(--line-soft)' }}>
        <MiniMetric icon="heart" value={s.hr} unit="bpm" label="Cardio" color={window.hzColor(s.hr)} />
        <MiniMetric icon="cadence" value={s.cadence} unit="rpm" label="Cadenza" />
        <MiniMetric icon="speed" value={s.speed.toFixed(1)} unit="km/h" label="Velocità" />
      </div>
    </div>
  );
}

// ── VARIANT B — balanced 2×2 grid ─────────────────────────────
function GridTile({ icon, label, value, unit, color = 'var(--text)', zone, accent }) {
  return (
    <window.Tile pad={16} accent={accent} style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between', minHeight: 124 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--text-3)' }}>
        <window.Icon name={icon} size={14} color="var(--text-3)" />
        <span style={{ fontSize: 11, fontWeight: 650, letterSpacing: 0.6, textTransform: 'uppercase' }}>{label}</span>
      </div>
      <div className="tnum" style={{ display: 'flex', alignItems: 'baseline', gap: 4, color, lineHeight: 0.9 }}>
        <span style={{ fontSize: 50, fontWeight: 700, letterSpacing: -2 }}>{value}</span>
        <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--text-3)' }}>{unit}</span>
      </div>
      {zone ? <window.ZoneScale value={zone.value} zones={zone.type} h={6} /> : <div style={{ height: 6 }} />}
    </window.Tile>
  );
}
function BodyGrid({ s }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '0 16px', gap: 12 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <GridTile icon="bolt" label="Potenza" value={Math.round(s.power)} unit="W" color={window.pzColor(s.power)} accent={window.pzColor(s.power)} zone={{ value: s.power, type: 'power' }} />
        <GridTile icon="heart" label="Cardio" value={s.hr} unit="bpm" color={window.hzColor(s.hr)} accent={window.hzColor(s.hr)} zone={{ value: s.hr, type: 'hr' }} />
        <GridTile icon="cadence" label="Cadenza" value={s.cadence} unit="rpm" />
        <GridTile icon="speed" label="Velocità" value={s.speed.toFixed(1)} unit="km/h" />
      </div>
      <div className="tnum" style={{ display: 'flex', justifycontent: 'space-between', gap: 8, padding: '0 4px', fontSize: 12, color: 'var(--text-3)', fontWeight: 600 }}>
        <span style={{ flex: 1 }}>media {s.powerAvg} W</span>
        <span style={{ flex: 1, textAlign: 'center' }}>NP {s.np} W</span>
        <span style={{ flex: 1, textAlign: 'right' }}>{Math.round(s.work)} kJ</span>
      </div>
    </div>
  );
}

// ── VARIANT C — profile / terrain hero ────────────────────────
function BodyProfile({ s }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 14 }}>
      <ContextBand s={s} big />
      <div style={{ display: 'flex', gap: 6, padding: '14px 18px 0', margin: '0 14px', borderTop: '1px solid var(--line-soft)' }}>
        <MiniMetric icon="bolt" value={Math.round(s.power)} unit="W" label="Potenza" color={window.pzColor(s.power)} />
        <MiniMetric icon="heart" value={s.hr} unit="bpm" label="Cardio" color={window.hzColor(s.hr)} />
        <MiniMetric icon="cadence" value={s.cadence} unit="" label="Cadenza" />
        <MiniMetric icon="speed" value={s.speed.toFixed(1)} unit="" label="km/h" />
      </div>
    </div>
  );
}

// ── main ──────────────────────────────────────────────────────
function LiveDashboard({ variant = 'B', onSummary }) {
  const s = window.useEngine();
  const showBandBottom = variant !== 'C'; // C puts the band in the body
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'var(--bg)', color: 'var(--text)', display: 'flex', flexDirection: 'column' }}>
      <DashHeader s={s} />
      {variant === 'A' && <BodyFocus s={s} />}
      {variant === 'B' && <BodyGrid s={s} />}
      {variant === 'C' && <BodyProfile s={s} />}
      {showBandBottom && (
        <div style={{ paddingTop: 6 }}>
          <ContextBand s={s} />
        </div>
      )}
      <DashDock s={s} />
      {s.finished && <FinishOverlay s={s} onSummary={onSummary} />}
    </div>
  );
}

Object.assign(window, { LiveDashboard });
