/* Ascesa — icons + shared helpers (exported to window) */

// ── line icons (24px grid, stroke = currentColor) ───────────
const _P = {
  bolt:    <path d="M13 2 4 14h6l-1 8 9-12h-6l1-8Z" />,
  heart:   <path d="M12 20S4 14.5 4 9a4 4 0 0 1 8-1 4 4 0 0 1 8 1c0 5.5-8 11-8 11Z" />,
  cadence: <g><circle cx="12" cy="12" r="8.2" /><path d="M12 7v5l3.2 2" /></g>,
  speed:   <g><path d="M4.5 18a8 8 0 1 1 15 0" /><path d="M12 14l4-4" /><circle cx="12" cy="14" r="1.1" fill="currentColor" stroke="none" /></g>,
  route:   <g><circle cx="6" cy="18" r="2.3" /><circle cx="18" cy="6" r="2.3" /><path d="M8 17c5-1 8-4 8-9" /></g>,
  clock:   <g><circle cx="12" cy="12" r="8.2" /><path d="M12 7.5V12l3 2" /></g>,
  mountain:<path d="M3 19h18L14 7l-3.4 5.5L8.2 9 3 19Z" />,
  bt:      <path d="M8 7l8 5-4 3V5l4 3-8 5" />,
  watch:   <g><rect x="7" y="7" width="10" height="10" rx="3" /><path d="M9 7l.6-3h4.8l.6 3M9 17l.6 3h4.8l.6-3" /></g>,
  plus:    <path d="M12 5v14M5 12h14" />,
  minus:   <path d="M5 12h14" />,
  lap:     <g><path d="M20 12a8 8 0 1 1-2.4-5.7" /><path d="M20 4v4h-4" /></g>,
  pause:   <g><rect x="7" y="6" width="3.4" height="12" rx="1" fill="currentColor" stroke="none" /><rect x="13.6" y="6" width="3.4" height="12" rx="1" fill="currentColor" stroke="none" /></g>,
  play:    <path d="M8 5.5v13l11-6.5-11-6.5Z" fill="currentColor" stroke="none" />,
  stop:    <rect x="7" y="7" width="10" height="10" rx="2.5" fill="currentColor" stroke="none" />,
  chev:    <path d="M9 5l7 7-7 7" />,
  chevL:   <path d="M15 5l-7 7 7 7" />,
  chevDown:<path d="M5 9l7 7 7-7" />,
  gear:    <g><circle cx="12" cy="12" r="3" /><path d="M12 3v2.5M12 18.5V21M4.2 7l2.2 1.3M17.6 15.7l2.2 1.3M4.2 17l2.2-1.3M17.6 8.3l2.2-1.3" /></g>,
  search:  <g><circle cx="11" cy="11" r="6" /><path d="M20 20l-4.3-4.3" /></g>,
  upload:  <g><path d="M12 16V5" /><path d="M7.5 9.5 12 5l4.5 4.5" /><path d="M5 19h14" /></g>,
  check:   <path d="M5 12.5 10 17l9-10" />,
  signal:  <g><path d="M5 19v-3M10 19v-7M15 19v-11M20 19V5" /></g>,
  cal:     <g><rect x="4" y="5" width="16" height="15" rx="2.5" /><path d="M4 9h16M9 3v4M15 3v4" /></g>,
  trophy:  <g><path d="M7 4h10v4a5 5 0 0 1-10 0V4Z" /><path d="M7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3M10 14h4M9 20h6M12 14v6" /></g>,
  flag:    <g><path d="M6 21V4" /><path d="M6 5h11l-2 3 2 3H6" /></g>,
  fire:    <path d="M12 3s4 3.5 4 8a4 4 0 0 1-8 0c0-1.4.7-2.4 1.3-3 .2 1 1 1.6 1.7 1.6 0-2.5 1-5 1-6.6Z" />,
  ele:     <g><path d="M12 19V6" /><path d="M7.5 10.5 12 6l4.5 4.5" /></g>,
  back:    <path d="M15 5l-7 7 7 7" />,
  more:    <g><circle cx="5" cy="12" r="1.6" fill="currentColor" stroke="none" /><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none" /><circle cx="19" cy="12" r="1.6" fill="currentColor" stroke="none" /></g>,
  power:   <path d="M13 2 4 14h6l-1 8 9-12h-6l1-8Z" />,
  history: <g><path d="M3.5 12a8.5 8.5 0 1 0 2.6-6.1" /><path d="M5 3v4h4M12 7.5V12l3.2 2" /></g>,
  home:    <path d="M4 11 12 4l8 7M6 9.5V20h12V9.5" />,
  dots:    <g><circle cx="12" cy="5" r="1.6" fill="currentColor" stroke="none" /><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none" /><circle cx="12" cy="19" r="1.6" fill="currentColor" stroke="none" /></g>,
  swap:    <g><path d="M7 7h11l-3-3M17 17H6l3 3" /></g>,
  drop:    <path d="M12 3s5 6 5 10a5 5 0 0 1-10 0c0-4 5-10 5-10Z" />,
};

function Icon({ name, size = 22, sw = 1.7, color = 'currentColor', style }) {
  const c = _P[name] || _P.bolt;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"
      style={{ display: 'block', flex: '0 0 auto', ...style }}>
      {c}
    </svg>
  );
}

// ── colour maps ─────────────────────────────────────────────
const PZONE_COLORS = ['var(--z1)', 'var(--z2)', 'var(--z3)', 'var(--z4)', 'var(--z5)', 'var(--z6)', 'var(--z7)'];
const HZONE_COLORS = ['var(--h1)', 'var(--h2)', 'var(--h3)', 'var(--h4)', 'var(--h5)'];
const PZONE_NAMES = ['Recupero', 'Fondo', 'Tempo', 'Soglia', 'VO₂max', 'Anaerobico', 'Neuromusc.'];
function pzColor(p) { return PZONE_COLORS[window.RideZones.powerZone(p) - 1]; }
function hzColor(h) { return HZONE_COLORS[window.RideZones.hrZone(h) - 1]; }
function gradeColor(g) {
  if (g < 3) return 'var(--g-flat)';
  if (g < 6) return 'var(--g-easy)';
  if (g < 9) return 'var(--g-mod)';
  if (g < 11) return 'var(--g-hard)';
  return 'var(--g-steep)';
}

// ── format helpers ──────────────────────────────────────────
function fmtTime(s) {
  s = Math.max(0, Math.floor(s));
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), ss = s % 60;
  const pad = (n) => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${pad(m)}:${pad(ss)}` : `${m}:${pad(ss)}`;
}
function fmtKm(m) { return (m / 1000).toFixed(1); }
function fmtKmFine(m) { return (m / 1000).toFixed(2); }

// ── engine hook ─────────────────────────────────────────────
function useEngine() {
  const [, force] = React.useState(0);
  React.useEffect(() => window.RideEngine.subscribe(() => force(n => n + 1)), []);
  return window.RideEngine.state;
}

Object.assign(window, {
  Icon, useEngine,
  PZONE_COLORS, HZONE_COLORS, PZONE_NAMES,
  pzColor, hzColor, gradeColor,
  fmtTime, fmtKm, fmtKmFine,
});
