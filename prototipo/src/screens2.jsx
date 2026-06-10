/* Ascesa — Route Library, Route Detail, Workout Builder */

// ── chips ──────────────────────────────────────────────────
function Chip({ label, on, onClick }) {
  return (
    <button onClick={onClick} style={{ border: '1px solid ' + (on ? 'transparent' : 'var(--line)'), background: on ? 'var(--accent)' : 'transparent', color: on ? 'var(--accent-ink)' : 'var(--text-2)', borderRadius: 999, padding: '7px 14px', fontSize: 13, fontWeight: 650, cursor: 'pointer', whiteSpace: 'nowrap', fontFamily: 'inherit', flex: '0 0 auto' }}>{label}</button>
  );
}

function RouteCard({ r, onClick }) {
  return (
    <window.Card onClick={onClick} pad={0} style={{ overflow: 'hidden' }}>
      <div style={{ display: 'flex', gap: 0 }}>
        <div className="ph-stripe" style={{ width: 96, flex: '0 0 auto', position: 'relative' }}>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <window.Icon name="mountain" size={22} color="var(--text-3)" />
          </div>
        </div>
        <div style={{ flex: 1, padding: '12px 14px', minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ fontSize: 16, fontWeight: 750, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.name}</span>
            {r.tags.includes('Preferiti') && <window.Icon name="heart" size={13} color="var(--z6)" />}
          </div>
          <div style={{ fontSize: 12, color: 'var(--text-3)', marginBottom: 6 }}>{r.sub}</div>
          <window.HeatProfile profile={r.profile} lengthM={r.lengthM} w={210} h={34} />
          <div className="tnum" style={{ display: 'flex', gap: 12, marginTop: 7, fontSize: 12, color: 'var(--text-2)', fontWeight: 600 }}>
            <span>{(r.lengthM / 1000).toFixed(1)} km</span>
            <span>+{r.gain} m</span>
            <span style={{ color: window.gradeColor(r.avg) }}>{r.avg}%</span>
          </div>
        </div>
      </div>
    </window.Card>
  );
}

function RouteLibraryScreen() {
  const nav = React.useContext(window.NavCtx);
  const [filter, setFilter] = React.useState('Tutti');
  const filters = ['Tutti', 'Salita', 'Gravel', 'Pianura', 'Preferiti'];
  const routes = window.AscesaData.ROUTES.filter(r => filter === 'Tutti' || r.tags.includes(filter));
  return (
    <window.Scaffold tab="routes">
      <window.TopBar large title="Percorsi" action={
        <button style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'var(--surface)', border: '1px solid var(--line-soft)', borderRadius: 999, padding: '8px 13px', cursor: 'pointer', color: 'var(--text)' }}>
          <window.Icon name="upload" size={16} /><span style={{ fontSize: 12.5, fontWeight: 650 }}>GPX</span>
        </button>
      } />
      <div style={{ padding: '2px 16px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, background: 'var(--surface)', border: '1px solid var(--line-soft)', borderRadius: 14, padding: '11px 14px', color: 'var(--text-3)' }}>
          <window.Icon name="search" size={18} /><span style={{ fontSize: 14 }}>Cerca salite, città, GPM…</span>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8, padding: '14px 16px 6px', overflowX: 'auto' }}>
        {filters.map(f => <Chip key={f} label={f} on={f === filter} onClick={() => setFilter(f)} />)}
      </div>
      <div style={{ padding: '6px 16px 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {routes.map(r => <RouteCard key={r.id} r={r} onClick={() => nav.go('routeDetail', r)} />)}
        <button style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, background: 'transparent', border: '1.5px dashed var(--line)', color: 'var(--text-2)', borderRadius: 16, padding: '15px', fontSize: 14, fontWeight: 650, cursor: 'pointer', fontFamily: 'inherit' }}>
          <window.Icon name="upload" size={18} />Importa file GPX / FIT / TCX
        </button>
      </div>
    </window.Scaffold>
  );
}

function RouteDetailScreen({ route }) {
  const nav = React.useContext(window.NavCtx);
  const r = route || window.AscesaData.ROUTES[0];
  return (
    <window.Scaffold>
      <div style={{ position: 'relative' }}>
        <div className="ph-stripe" style={{ height: 200, position: 'relative' }}>
          <div style={{ position: 'absolute', top: 56, left: 16, fontSize: 10, fontFamily: 'var(--mono)', color: 'var(--text-3)' }}>[ MAPPA · {r.name} ]</div>
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(transparent 40%, var(--bg))' }} />
          <button onClick={() => nav.back()} aria-label="Indietro" style={{ position: 'absolute', top: 54, left: 16, width: 36, height: 36, borderRadius: 18, border: 'none', background: 'rgba(20,22,28,0.7)', backdropFilter: 'blur(8px)', color: 'var(--text)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <window.Icon name="back" size={20} sw={2.1} />
          </button>
        </div>
        <div style={{ padding: '0 18px', marginTop: -8 }}>
          <div style={{ fontSize: 26, fontWeight: 800, letterSpacing: -0.6 }}>{r.name}</div>
          <div style={{ fontSize: 13, color: 'var(--text-2)' }}>{r.sub}</div>
        </div>
      </div>
      <div style={{ padding: '16px 18px 0' }}>
        <window.Card pad={14}>
          <window.HeatProfile profile={r.profile} lengthM={r.lengthM} w={306} h={92} />
          <div className="tnum" style={{ display: 'flex', justifyContent: 'space-between', marginTop: 14 }}>
            <window.Stat3 v={(r.lengthM / 1000).toFixed(1)} u="km" l="lunghezza" />
            <window.Stat3 v={'+' + r.gain} u="m" l="dislivello" />
            <window.Stat3 v={r.avg} u="%" l="pend. media" />
            <window.Stat3 v={r.max} u="%" l="pend. max" />
          </div>
        </window.Card>
        <div style={{ display: 'flex', gap: 8, marginTop: 12, flexWrap: 'wrap' }}>
          {r.tags.map(t => <span key={t} style={{ fontSize: 12, fontWeight: 650, color: 'var(--text-2)', background: 'var(--surface)', border: '1px solid var(--line-soft)', borderRadius: 999, padding: '6px 12px' }}>{t}</span>)}
        </div>
        <button onClick={() => nav.startRide('SIM')} style={{ ...window.btnPrimary, width: '100%', marginTop: 16, padding: '15px' }}>
          <window.Icon name="mountain" size={19} color="var(--accent-ink)" />Pedala in SIM
        </button>
        <div style={{ fontSize: 11.5, color: 'var(--text-3)', textAlign: 'center', marginTop: 10, lineHeight: 1.4 }}>
          La pendenza viene ricampionata a passo fisso e levigata prima di comandare il rullo.
        </div>
      </div>
    </window.Scaffold>
  );
}

// ── WORKOUT BUILDER ────────────────────────────────────────
function BuilderBar({ blocks, w = 330, h = 110 }) {
  const total = blocks.reduce((s, b) => s + b.dur, 0), maxP = 320;
  let acc = 0;
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block' }}>
      <line x1="0" y1={h - 0.5} x2={w} y2={h - 0.5} stroke="var(--line)" />
      {[0.5, 0.75, 1.0].map((f, i) => { const y = h - (f * 265 / maxP) * (h - 6); return <line key={i} x1="0" y1={y} x2={w} y2={y} stroke="var(--line-soft)" strokeDasharray="3 4" />; })}
      {blocks.map((b, i) => {
        const x = (acc / total) * w, bw = (b.dur / total) * w, bh = (b.power / maxP) * (h - 6);
        acc += b.dur;
        const col = b.kind === 'work' ? window.pzColor(b.power) : (b.kind === 'rest' ? 'var(--z2)' : 'var(--z1)');
        return <rect key={i} x={x + 0.5} y={h - bh} width={Math.max(1, bw - 1)} height={bh} rx="2" fill={col} fillOpacity="0.92" />;
      })}
    </svg>
  );
}

function WorkoutBuilderScreen() {
  const nav = React.useContext(window.NavCtx);
  const [blocks, setBlocks] = React.useState(() => window.WORKOUT.blocks.map(b => ({ ...b })));
  const total = blocks.reduce((s, b) => s + b.dur, 0);
  const avgP = blocks.reduce((s, b) => s + b.power * b.dur, 0) / total;
  const np = Math.round(Math.pow(blocks.reduce((s, b) => s + Math.pow(b.power, 4) * b.dur, 0) / total, 0.25));
  const iff = np / window.ATHLETE.ftp;
  const tss = Math.round((total * np * iff) / (window.ATHLETE.ftp * 3600) * 100);
  const kj = Math.round(avgP * total / 1000);

  const adj = (i, field, d) => setBlocks(bs => bs.map((b, j) => j === i ? { ...b, [field]: Math.max(field === 'power' ? 60 : 30, b[field] + d) } : b));

  return (
    <window.Scaffold tab="builder">
      <window.TopBar large title="Allenamento" sub={window.WORKOUT.sub} action={
        <button style={{ background: 'var(--surface)', border: '1px solid var(--line-soft)', borderRadius: 999, padding: '8px 13px', cursor: 'pointer', color: 'var(--text)', fontSize: 12.5, fontWeight: 650 }}>Libreria</button>
      } />
      <div style={{ padding: '2px 16px 0', display: 'flex', flexDirection: 'column', gap: 16 }}>
        <window.Card pad={16}>
          <BuilderBar blocks={blocks} w={306} h={108} />
          <div className="tnum" style={{ display: 'flex', justifyContent: 'space-between', marginTop: 14, borderTop: '1px solid var(--line-soft)', paddingTop: 12 }}>
            <window.Stat3 v={window.fmtTime(total)} u="" l="durata" />
            <window.Stat3 v={tss} u="" l="TSS stim." />
            <window.Stat3 v={iff.toFixed(2)} u="" l="IF" />
            <window.Stat3 v={kj} u="kJ" l="lavoro" />
          </div>
        </window.Card>

        <div>
          <window.SectionLabel>Blocchi · {blocks.length}</window.SectionLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {blocks.map((b, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, background: 'var(--surface)', borderRadius: 14, padding: '10px 12px', border: '1px solid var(--line-soft)', boxShadow: `inset 4px 0 0 ${b.kind === 'work' ? window.pzColor(b.power) : (b.kind === 'rest' ? 'var(--z2)' : 'var(--z1)')}` }}>
                <window.Icon name="dots" size={16} color="var(--text-3)" />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 700 }}>{b.label}</div>
                  <div className="tnum" style={{ fontSize: 12, color: 'var(--text-3)' }}>{window.fmtTime(b.dur)}</div>
                </div>
                <Stepper value={b.power + ' W'} onMinus={() => adj(i, 'power', -5)} onPlus={() => adj(i, 'power', 5)} />
              </div>
            ))}
          </div>
          <button onClick={() => setBlocks(bs => [...bs.slice(0, -1), { kind: 'work', label: `Intervallo ${bs.filter(x => x.kind === 'work').length + 1}`, dur: 240, power: 280 }, { kind: 'rest', label: 'Recupero', dur: 180, power: 150 }, bs[bs.length - 1]])}
            style={{ width: '100%', marginTop: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, background: 'transparent', border: '1.5px dashed var(--line)', color: 'var(--text-2)', borderRadius: 14, padding: '13px', fontSize: 14, fontWeight: 650, cursor: 'pointer', fontFamily: 'inherit' }}>
            <window.Icon name="plus" size={18} />Aggiungi intervallo
          </button>
        </div>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '14px 16px 30px', background: 'linear-gradient(transparent, var(--bg) 30%)' }}>
        <button onClick={() => nav.startRide('ERG')} style={{ ...window.btnPrimary, width: '100%', padding: '15px' }}>
          <window.Icon name="play" size={18} color="var(--accent-ink)" />Avvia in ERG
        </button>
      </div>
    </window.Scaffold>
  );
}

function Stepper({ value, onMinus, onPlus }) {
  const b = { width: 30, height: 30, borderRadius: 8, border: 'none', background: 'var(--surface-2)', color: 'var(--text)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' };
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
      <button onClick={onMinus} style={b}><window.Icon name="minus" size={16} sw={2.2} /></button>
      <span className="tnum" style={{ minWidth: 48, textAlign: 'center', fontSize: 14, fontWeight: 700 }}>{value}</span>
      <button onClick={onPlus} style={b}><window.Icon name="plus" size={16} sw={2.2} /></button>
    </div>
  );
}

Object.assign(window, { RouteLibraryScreen, RouteDetailScreen, WorkoutBuilderScreen });
