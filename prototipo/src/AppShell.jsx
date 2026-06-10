/* Ascesa — navigable app shell */

function ScreenFade({ dir, k, children }) {
  return (
    <div style={{ position: 'absolute', inset: 0 }}>
      {children}
    </div>
  );
}

function AppShell({ initial = 'home', rideVariant = 'B' }) {
  const [stack, setStack] = React.useState([{ s: initial }]);
  const [dir, setDir] = React.useState('fwd');
  const top = stack[stack.length - 1];
  const tabs = ['home', 'routes', 'builder', 'history', 'profile'];

  const nav = React.useMemo(() => ({
    go(s, params) {
      if (tabs.includes(s)) { setDir('fwd'); setStack([{ s, params }]); }
      else { setDir('fwd'); setStack(st => [...st, { s, params }]); }
    },
    back() { setDir('back'); setStack(st => st.length > 1 ? st.slice(0, -1) : st); },
    startRide(mode) {
      window.RideEngine.reset();
      window.RideEngine.setMode(mode);
      window.RideEngine.start();
      setDir('fwd'); setStack(st => [...st, { s: 'ride' }]);
    },
    summary() {
      const S = window.RideEngine.state;
      const sess = {
        id: 'live', title: S.mode === 'SIM' ? window.ROUTE.name : window.WORKOUT.name,
        date: 'Oggi', when: 'Oggi', type: S.mode,
        dur: Math.round(S.elapsed), dist: +window.fmtKm(S.distance), gain: S.mode === 'SIM' ? Math.round(S.ele - window.RideZones.eleAt(S.offset)) : 0,
        avgP: S.powerAvg, np: S.np, if: +(S.np / window.ATHLETE.ftp).toFixed(2),
        tss: Math.round((S.elapsed * S.np * (S.np / window.ATHLETE.ftp)) / (window.ATHLETE.ftp * 3600) * 100),
        avgHR: Math.round(S.hr), kj: Math.round(S.work),
      };
      setDir('fwd'); setStack(st => [{ s: 'history' }, { s: 'detail', params: sess }]);
    },
  }), []);

  const screen = (e) => {
    switch (e.s) {
      case 'home': return <window.HomeScreen />;
      case 'routes': return <window.RouteLibraryScreen />;
      case 'routeDetail': return <window.RouteDetailScreen route={e.params} />;
      case 'builder': return <window.WorkoutBuilderScreen />;
      case 'history': return <window.HistoryScreen />;
      case 'detail': return <window.SessionDetailScreen session={e.params} />;
      case 'profile': return <window.ProfileScreen />;
      case 'connect': return <window.ConnectionScreen />;
      case 'ride': return <window.LiveDashboard variant={rideVariant} onSummary={() => nav.summary()} />;
      default: return <window.HomeScreen />;
    }
  };

  return (
    <window.NavCtx.Provider value={nav}>
      <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', background: 'var(--bg)' }}>
        <ScreenFade key={stack.length + ':' + top.s} dir={dir} k={top.s}>
          {screen(top)}
        </ScreenFade>
      </div>
    </window.NavCtx.Provider>
  );
}

window.AppShell = AppShell;
