/* Ascesa — History, Session Detail, Profile */

// ── HISTORY ────────────────────────────────────────────────
function HistoryScreen() {
  const nav = React.useContext(window.NavCtx);
  const H = window.AscesaData.HISTORY;
  const groups = {};
  H.forEach(h => { (groups[h.when] = groups[h.when] || []).push(h); });
  const ftpTrend = [243, 247, 246, 251, 255, 258, 261, 265];
  return (
    <window.Scaffold tab="history">
      <window.TopBar large title="Storico" sub="Questa settimana" />
      <div style={{ padding: '2px 16px 0', display: 'flex', flexDirection: 'column', gap: 18 }}>
        <window.Card pad={16}>
          <div className="tnum" style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 14 }}>
            <window.Stat3 v="3" u="" l="uscite" />
            <window.Stat3 v="2:42" u="h" l="tempo" />
            <window.Stat3 v="60" u="km" l="distanza" />
            <window.Stat3 v="160" u="" l="TSS" />
          </div>
          <div style={{ borderTop: '1px solid var(--line-soft)', paddingTop: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: 0.5 }}>Trend FTP</span>
              <span className="tnum" style={{ fontSize: 13, fontWeight: 700, color: 'var(--z3)' }}>265 W ▲ +22</span>
            </div>
            <window.MiniChart data={ftpTrend} w={306} h={48} color="var(--accent)" fill sw={2} />
          </div>
        </window.Card>

        {Object.keys(groups).map(g => (
          <div key={g}>
            <window.SectionLabel>{g}</window.SectionLabel>
            <window.Card pad={4}>
              {groups[g].map((h, i) => <window.HistoryRow key={h.id} h={h} last={i === groups[g].length - 1} onClick={() => nav.go('detail', h)} />)}
            </window.Card>
          </div>
        ))}
      </div>
    </window.Scaffold>
  );
}

// ── SESSION DETAIL ─────────────────────────────────────────
function ChartBlock({ title, color, children, right }) {
  return (
    <div style={{ marginBottom: 4 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 2px 6px' }}>
        <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: 0.5 }}>{title}</span>
        {right && <span className="tnum" style={{ fontSize: 13, fontWeight: 700, color }}>{right}</span>}
      </div>
      {children}
    </div>
  );
}

function SessionDetailScreen({ session }) {
  const nav = React.useContext(window.NavCtx);
  const h = session || window.AscesaData.HISTORY[0];
  const ser = React.useMemo(() => window.AscesaData.sessionSeries(h), [h.id]);
  const grid = [
    ['route', h.dist + ' km', 'distanza'], ['clock', window.fmtTime(h.dur), 'tempo'],
    ['ele', '+' + h.gain + ' m', 'dislivello'], ['bolt', h.avgP + ' W', 'pot. media'],
    ['bolt', h.np + ' W', 'NP'], ['fire', h.kj + ' kJ', 'lavoro'],
    ['heart', h.avgHR + ' bpm', 'HR media'], ['mountain', h.if.toFixed(2), 'IF'],
  ];
  const zTot = ser.zoneDist.reduce((a, b) => a + b, 0);
  return (
    <window.Scaffold>
      <div className="ph-stripe" style={{ height: 168, position: 'relative' }}>
        <div style={{ position: 'absolute', top: 56, left: 16, fontSize: 10, fontFamily: 'var(--mono)', color: 'var(--text-3)' }}>[ MAPPA · traccia GPS ]</div>
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(transparent 30%, var(--bg))' }} />
        <button onClick={() => nav.back()} aria-label="Indietro" style={{ position: 'absolute', top: 54, left: 16, width: 36, height: 36, borderRadius: 18, border: 'none', background: 'rgba(20,22,28,0.7)', backdropFilter: 'blur(8px)', color: 'var(--text)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <window.Icon name="back" size={20} sw={2.1} />
        </button>
        <div style={{ position: 'absolute', bottom: 8, left: 18, right: 18, display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
              <span style={{ fontSize: 23, fontWeight: 800, letterSpacing: -0.5 }}>{h.title}</span>
              {h.pr && <span style={{ fontSize: 10, fontWeight: 800, color: 'var(--accent-ink)', background: 'var(--accent)', borderRadius: 5, padding: '2px 5px' }}>PR</span>}
            </div>
            <div style={{ fontSize: 12.5, color: 'var(--text-2)' }}>{h.date} · {h.type === 'SIM' ? 'Percorso' : 'Workout ERG'}</div>
          </div>
          <button style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(20,22,28,0.7)', backdropFilter: 'blur(8px)', border: '1px solid var(--line-soft)', borderRadius: 999, padding: '8px 12px', color: 'var(--text)', cursor: 'pointer', fontSize: 12.5, fontWeight: 650 }}>
            <window.Icon name="upload" size={15} />Esporta
          </button>
        </div>
      </div>

      <div style={{ padding: '14px 16px 0' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 1, background: 'var(--line-soft)', borderRadius: 16, overflow: 'hidden', border: '1px solid var(--line-soft)' }}>
          {grid.map((g, i) => (
            <div key={i} className="tnum" style={{ background: 'var(--surface)', padding: '12px 8px', textAlign: 'center' }}>
              <div style={{ fontSize: 16, fontWeight: 750, letterSpacing: -0.4 }}>{g[1]}</div>
              <div style={{ fontSize: 9.5, color: 'var(--text-3)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.3, marginTop: 2 }}>{g[2]}</div>
            </div>
          ))}
        </div>

        <div style={{ marginTop: 18, display: 'flex', flexDirection: 'column', gap: 16 }}>
          <ChartBlock title="Potenza" color="var(--z4)" right={`media ${h.avgP} W`}>
            <window.MiniChart data={ser.power} w={338} h={70} color="var(--z4)" fill sw={1.4} baseline={0} />
          </ChartBlock>
          <ChartBlock title="Frequenza cardiaca" color="var(--z6)" right={`media ${h.avgHR} bpm`}>
            <window.MiniChart data={ser.hr} w={338} h={60} color="var(--z6)" sw={1.8} />
          </ChartBlock>
          {ser.ele && (
            <ChartBlock title="Altimetria" color="var(--accent)" right={`+${h.gain} m`}>
              <window.MiniChart data={ser.ele} w={338} h={56} color="var(--accent)" fill sw={1.4} />
            </ChartBlock>
          )}
          <ChartBlock title="Distribuzione zone di potenza">
            <div style={{ display: 'flex', gap: 4, alignItems: 'flex-end', height: 64 }}>
              {ser.zoneDist.map((v, i) => (
                <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                  <div style={{ width: '100%', height: (v / Math.max(...ser.zoneDist)) * 46, background: window.PZONE_COLORS[i], borderRadius: 3, minHeight: 2 }} />
                  <span style={{ fontSize: 9, color: 'var(--text-3)', fontWeight: 700 }}>Z{i + 1}</span>
                </div>
              ))}
            </div>
          </ChartBlock>
        </div>
      </div>
    </window.Scaffold>
  );
}

// ── PROFILE ────────────────────────────────────────────────
function ZoneTable({ title, names, colors, ranges }) {
  return (
    <div>
      <window.SectionLabel>{title}</window.SectionLabel>
      <window.Card pad={4}>
        {names.map((n, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', borderBottom: i === names.length - 1 ? 'none' : '1px solid var(--line-soft)' }}>
            <span style={{ width: 10, height: 10, borderRadius: 3, background: colors[i], flex: '0 0 auto' }} />
            <span style={{ flex: 1, fontSize: 14, fontWeight: 650 }}>Z{i + 1} · {n}</span>
            <span className="tnum" style={{ fontSize: 13, color: 'var(--text-2)', fontWeight: 600 }}>{ranges[i]}</span>
          </div>
        ))}
      </window.Card>
    </div>
  );
}

function ProfileScreen() {
  const A = window.ATHLETE;
  const ftpTrend = [243, 247, 246, 251, 255, 258, 261, 265];
  return (
    <window.Scaffold tab="profile">
      <window.TopBar large title="Profilo" />
      <div style={{ padding: '2px 16px 0', display: 'flex', flexDirection: 'column', gap: 18 }}>
        <window.Card pad={16}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <div style={{ width: 56, height: 56, borderRadius: 28, background: 'var(--accent-ink)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}>
              <span style={{ fontSize: 22, fontWeight: 800, color: 'var(--accent)' }}>MV</span>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 18, fontWeight: 780 }}>{A.name}</div>
              <div style={{ fontSize: 13, color: 'var(--text-3)' }}>Cat. Master · Valtellina</div>
            </div>
          </div>
          <div className="tnum" style={{ display: 'flex', justifyContent: 'space-between', marginTop: 16, borderTop: '1px solid var(--line-soft)', paddingTop: 14 }}>
            <window.Stat3 v={A.ftp} u="W" l="FTP" />
            <window.Stat3 v={A.weight} u="kg" l="peso" />
            <window.Stat3 v={(A.ftp / A.weight).toFixed(1)} u="W/kg" l="rapporto" />
            <window.Stat3 v={A.maxHR} u="bpm" l="FC max" />
          </div>
        </window.Card>

        <window.Card pad={16}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
            <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: 0.5 }}>Trend FTP · 8 settimane</span>
            <span className="tnum" style={{ fontSize: 13, fontWeight: 700, color: 'var(--z3)' }}>+22 W</span>
          </div>
          <window.MiniChart data={ftpTrend} w={306} h={56} color="var(--accent)" fill sw={2} />
        </window.Card>

        <ZoneTable title="Zone di potenza" names={window.PZONE_NAMES} colors={window.PZONE_COLORS}
          ranges={['≤146 W', '147–198', '199–238', '239–278', '279–318', '319–397', '398+ W']} />
        <ZoneTable title="Zone cardiache" names={['Recupero', 'Aerobico', 'Tempo', 'Soglia', 'Massimale']} colors={window.HZONE_COLORS}
          ranges={['≤114', '115–133', '134–152', '153–171', '172+ bpm']} />

        <div>
          <window.SectionLabel>Integrazioni</window.SectionLabel>
          <window.Card pad={4}>
            {[['HealthKit', 'Connesso', 'var(--z3)'], ['Strava', 'Solo dati personali', 'var(--text-3)'], ['Garmin Connect', 'Non connesso', 'var(--text-3)']].map((r, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', padding: '13px 12px', borderBottom: i === 2 ? 'none' : '1px solid var(--line-soft)' }}>
                <span style={{ flex: 1, fontSize: 14.5, fontWeight: 650 }}>{r[0]}</span>
                <span style={{ fontSize: 13, fontWeight: 600, color: r[2] }}>{r[1]}</span>
                <window.Icon name="chev" size={16} color="var(--text-3)" style={{ marginLeft: 8 }} />
              </div>
            ))}
          </window.Card>
        </div>
      </div>
    </window.Scaffold>
  );
}

Object.assign(window, { HistoryScreen, SessionDetailScreen, ProfileScreen });
