/* Ascesa — shared visual components */

// ── Elevation profile (grade-coloured area + position marker) ──
function ElevationProfile({ posM, w = 360, h = 90, mode = 'full', pad = 0, showGrade = true, thin = false }) {
  const R = window.ROUTE;
  let x0, x1;
  if (mode === 'ahead') { x0 = Math.max(0, posM - 150); x1 = Math.min(R.lengthM, posM + 1600); }
  else { x0 = 0; x1 = R.lengthM; }
  if (x1 - x0 < 400) x1 = x0 + 400;

  const pts = R.pts.filter(p => p.d >= x0 - R.stepM && p.d <= x1 + R.stepM);
  let eMin = Infinity, eMax = -Infinity;
  pts.forEach(p => { if (p.ele < eMin) eMin = p.ele; if (p.ele > eMax) eMax = p.ele; });
  const padE = (eMax - eMin) * 0.12 + 6; eMin -= padE; eMax += padE;
  const topPad = showGrade ? 4 : 2;
  const sx = (m) => ((m - x0) / (x1 - x0)) * w;
  const sy = (e) => h - ((e - eMin) / (eMax - eMin)) * (h - topPad);

  const segs = [];
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i], b = pts[i + 1];
    const xa = sx(a.d), xb = sx(b.d);
    if (xb < 0 || xa > w) continue;
    const g = (a.grade + b.grade) / 2;
    segs.push(<polygon key={i}
      points={`${xa},${h} ${xa},${sy(a.ele)} ${xb},${sy(b.ele)} ${xb},${h}`}
      fill={window.gradeColor(g)} fillOpacity={thin ? 0.5 : 0.82} />);
  }
  // top stroke
  let line = '';
  pts.forEach((p, i) => { line += (i ? 'L' : 'M') + sx(p.d).toFixed(1) + ' ' + sy(p.ele).toFixed(1); });

  const mx = sx(posM);
  const curGrade = window.RideZones.gradeAt(posM);

  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block', overflow: 'visible' }}>
      <defs>
        <clipPath id={'epc' + Math.round(w) + mode}><rect x="0" y="0" width={mx} height={h} /></clipPath>
      </defs>
      {segs}
      <path d={line} fill="none" stroke="rgba(255,255,255,0.55)" strokeWidth={thin ? 1 : 1.5} strokeLinejoin="round" />
      {/* dim the part already ridden */}
      <rect x="0" y="0" width={mx} height={h} fill="rgba(10,12,16,0.42)" />
      {/* position marker */}
      <line x1={mx} y1="0" x2={mx} y2={h} stroke="#fff" strokeWidth="1.5" strokeOpacity="0.9" />
      <circle cx={mx} cy={sy(window.RideZones.eleAt(posM))} r={thin ? 3 : 4.5} fill="#fff" stroke="rgba(0,0,0,0.4)" strokeWidth="1" />
      {showGrade && (
        <g transform={`translate(${Math.min(Math.max(mx, 30), w - 30)}, 14)`}>
          <text textAnchor="middle" fontSize="12" fontWeight="700" fill="#fff"
            style={{ fontVariantNumeric: 'tabular-nums' }}>{curGrade.toFixed(1)}%</text>
        </g>
      )}
    </svg>
  );
}

// ── ERG interval bar ───────────────────────────────────────
function IntervalBar({ elapsed, w = 360, h = 72, compact = false }) {
  const W = window.WORKOUT, total = W.total;
  const maxP = 320;
  let acc = 0;
  const segs = W.blocks.map((b, i) => {
    const x = (acc / total) * w, bw = (b.dur / total) * w;
    const bh = (b.power / maxP) * (h - 6);
    acc += b.dur;
    const col = b.kind === 'work' ? window.pzColor(b.power)
      : b.kind === 'warmup' || b.kind === 'cooldown' ? 'var(--z1)' : 'var(--z2)';
    return <rect key={i} x={x + 0.6} y={h - bh} width={Math.max(1, bw - 1.2)} height={bh}
      rx="2" fill={col} fillOpacity={0.9} />;
  });
  const mx = (Math.min(elapsed, total) / total) * w;
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block', overflow: 'visible' }}>
      <line x1="0" y1={h - 0.5} x2={w} y2={h - 0.5} stroke="var(--line)" strokeWidth="1" />
      {segs}
      <rect x="0" y="0" width={mx} height={h} fill="rgba(10,12,16,0.5)" />
      <line x1={mx} y1="0" x2={mx} y2={h} stroke="#fff" strokeWidth="1.5" />
    </svg>
  );
}

// ── Zone scale (7 power segments with marker) ──────────────
function ZoneScale({ value, zones = 'power', h = 8 }) {
  const cols = zones === 'power' ? window.PZONE_COLORS : window.HZONE_COLORS;
  const fn = zones === 'power' ? window.RideZones.powerZone : window.RideZones.hrZone;
  const active = fn(value);
  return (
    <div style={{ display: 'flex', gap: 3 }}>
      {cols.map((c, i) => (
        <div key={i} style={{
          flex: 1, height: h, borderRadius: 3, background: c,
          opacity: i + 1 === active ? 1 : 0.22,
          transition: 'opacity .2s, box-shadow .2s',
          boxShadow: i + 1 === active ? `0 0 10px ${c}` : 'none',
        }} />
      ))}
    </div>
  );
}

// ── Big metric ─────────────────────────────────────────────
function Metric({ value, unit, label, color = 'var(--text)', size = 56, icon, sub, align = 'left', live }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2, alignItems: align === 'center' ? 'center' : 'flex-start' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--text-3)' }}>
        {icon && <window.Icon name={icon} size={13} sw={1.8} />}
        <span style={{ fontSize: 11, fontWeight: 600, letterSpacing: 0.6, textTransform: 'uppercase' }}>{label}</span>
      </div>
      <div className="tnum" style={{ display: 'flex', alignItems: 'baseline', gap: 4, color, lineHeight: 0.95 }}>
        <span style={{ fontSize: size, fontWeight: 680, letterSpacing: -1.5 }}>{value}</span>
        {unit && <span style={{ fontSize: Math.max(13, size * 0.26), fontWeight: 600, color: 'var(--text-3)', letterSpacing: -0.2 }}>{unit}</span>}
      </div>
      {sub && <div className="tnum" style={{ fontSize: 12, color: 'var(--text-3)', fontWeight: 500 }}>{sub}</div>}
    </div>
  );
}

// ── Tile (boxed metric) ────────────────────────────────────
function Tile({ children, style, pad = 14, accent }) {
  return (
    <div style={{
      background: 'var(--surface)', borderRadius: 'var(--radius)',
      padding: pad, position: 'relative', overflow: 'hidden',
      border: '1px solid var(--line-soft)',
      ...(accent ? { boxShadow: `inset 3px 0 0 ${accent}` } : {}),
      ...style,
    }}>{children}</div>
  );
}

// ── Round control button ───────────────────────────────────
function RoundBtn({ icon, onClick, color, bg = 'var(--surface-2)', size = 56, iconSize, active, label, ink = 'var(--text)' }) {
  return (
    <button onClick={onClick} aria-label={label} style={{
      width: size, height: size, borderRadius: size / 2, border: 'none', cursor: 'pointer',
      background: active ? color : bg, color: active ? (ink) : (color || 'var(--text)'),
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      transition: 'transform .12s, background .15s', flex: '0 0 auto',
    }}
      onMouseDown={e => e.currentTarget.style.transform = 'scale(0.92)'}
      onMouseUp={e => e.currentTarget.style.transform = 'scale(1)'}
      onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}>
      <window.Icon name={icon} size={iconSize || size * 0.42} sw={2} />
    </button>
  );
}

// ── Segmented control (mode toggle etc.) ───────────────────
function Segmented({ options, value, onChange, accent = 'var(--accent)', dense }) {
  return (
    <div style={{ display: 'flex', background: 'var(--bg-elev)', borderRadius: 999, padding: 3, border: '1px solid var(--line-soft)' }}>
      {options.map(o => {
        const on = o.value === value;
        return (
          <button key={o.value} onClick={() => onChange(o.value)} style={{
            border: 'none', cursor: 'pointer', borderRadius: 999,
            padding: dense ? '5px 12px' : '7px 16px', fontSize: dense ? 12 : 13, fontWeight: 650,
            letterSpacing: 0.2, fontFamily: 'inherit',
            background: on ? accent : 'transparent',
            color: on ? 'var(--accent-ink)' : 'var(--text-2)',
            transition: 'background .15s, color .15s',
          }}>{o.label}</button>
        );
      })}
    </div>
  );
}

Object.assign(window, { ElevationProfile, IntervalBar, ZoneScale, Metric, Tile, RoundBtn, Segmented });
