/* Ascesa — static data: routes, history, synthetic session series */
(function () {
  'use strict';
  const rnd = (seed) => { let x = seed; return () => (x = (x * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff; };

  function makeProfile(seed, n, lo, hi, shape) {
    const r = rnd(seed); const out = [];
    for (let i = 0; i < n; i++) {
      const x = i / (n - 1);
      let g = (lo + hi) / 2
        + (hi - lo) * 0.4 * Math.sin(i * 0.5 + seed)
        + (hi - lo) * 0.25 * Math.sin(i * 0.17)
        + (r() - 0.5) * (hi - lo) * 0.3;
      if (shape === 'climb') g += (hi - lo) * 0.3 * (x - 0.5) * 2;
      if (shape === 'rollers') g = (hi - lo) * 0.7 * Math.sin(i * 0.6) + (lo + hi) / 2;
      out.push(Math.max(lo, Math.min(hi, +g.toFixed(1))));
    }
    return out;
  }

  // alternate routes for the library (the live ROUTE is Stelvio)
  const ROUTES = [
    { id: 'stelvio-bormio', name: 'Passo dello Stelvio', sub: 'Bormio · Alpi', lengthM: 21500, gain: 1530, avg: 7.1, max: 11.4, tags: ['Salita', 'Preferiti'], live: true, profile: makeProfile(3, 44, 3, 11, 'climb') },
    { id: 'mortirolo', name: 'Passo del Mortirolo', sub: 'Mazzo di Valtellina', lengthM: 12400, gain: 1300, avg: 10.5, max: 18, tags: ['Salita'], profile: makeProfile(7, 40, 7, 16, 'climb') },
    { id: 'ghisallo', name: 'Madonna del Ghisallo', sub: 'Bellagio · Lario', lengthM: 10600, gain: 552, avg: 5.2, max: 14, tags: ['Salita', 'Preferiti'], profile: makeProfile(11, 40, 2, 12, 'rollers') },
    { id: 'gavia', name: 'Passo Gavia', sub: 'Ponte di Legno', lengthM: 17300, gain: 1363, avg: 7.9, max: 16, tags: ['Salita'], profile: makeProfile(5, 42, 4, 13, 'climb') },
    { id: 'maratona', name: 'Tour del Lago', sub: 'Lago di Garda', lengthM: 38000, gain: 420, avg: 1.1, max: 6, tags: ['Pianura', 'Gravel'], profile: makeProfile(9, 44, -3, 6, 'rollers') },
  ];

  // build elevation array from grades for drawing (returns {pts, eMin, eMax})
  function elevFromGrades(profile, lengthM, startEle = 200) {
    const step = lengthM / (profile.length - 1);
    let ele = startEle; const pts = [];
    for (let i = 0; i < profile.length; i++) { pts.push({ d: i * step, ele }); ele += (profile[i] / 100) * step; }
    let eMin = Infinity, eMax = -Infinity; pts.forEach(p => { eMin = Math.min(eMin, p.ele); eMax = Math.max(eMax, p.ele); });
    return { pts, eMin, eMax, step };
  }

  // history sessions
  const HISTORY = [
    { id: 1, when: 'Oggi', date: '9 giu', title: 'Passo dello Stelvio', type: 'SIM', dur: 4123, dist: 21.5, gain: 1530, avgP: 241, np: 257, if: 0.97, tss: 108, avgHR: 164, kj: 994, pr: true },
    { id: 2, when: 'Ieri', date: '8 giu', title: 'Soglia 5×4′', type: 'ERG', dur: 3000, dist: 28.4, gain: 0, avgP: 218, np: 246, if: 0.93, tss: 72, avgHR: 158, kj: 654 },
    { id: 3, when: 'Questa settimana', date: '6 giu', title: 'Madonna del Ghisallo', type: 'SIM', dur: 2210, dist: 10.6, gain: 552, avgP: 228, np: 239, if: 0.90, tss: 50, avgHR: 152, kj: 504 },
    { id: 4, when: 'Questa settimana', date: '4 giu', title: 'Recupero Z2', type: 'ERG', dur: 3600, dist: 33.1, gain: 0, avgP: 168, np: 172, if: 0.65, tss: 38, avgHR: 131, kj: 605 },
    { id: 5, when: 'Settimana scorsa', date: '1 giu', title: 'Passo Gavia', type: 'SIM', dur: 3890, dist: 17.3, gain: 1363, avgP: 235, np: 251, if: 0.95, tss: 98, avgHR: 161, kj: 914 },
  ];

  // synthetic per-second-ish series for the detail charts
  function series(seed, n, base, amp, drift) {
    const r = rnd(seed); const out = [];
    for (let i = 0; i < n; i++) {
      const x = i / n;
      out.push(base + Math.sin(i * 0.35 + seed) * amp + (r() - 0.5) * amp * 0.8 + (drift || 0) * x);
    }
    return out;
  }
  function sessionSeries(h) {
    const n = 90;
    return {
      power: series(h.id * 3 + 1, n, h.avgP, h.type === 'ERG' ? 70 : 38, 0).map(v => Math.max(40, v)),
      hr: series(h.id * 5 + 2, n, h.avgHR, 12, 10).map(v => Math.max(90, Math.min(190, v))),
      ele: h.gain > 100 ? elevFromGrades(makeProfile(h.id, n, 2, 11, 'climb'), h.dist * 1000).pts.map(p => p.ele) : null,
      zoneDist: h.type === 'ERG' ? [8, 22, 14, 38, 14, 4, 0] : [6, 18, 30, 32, 10, 3, 1],
    };
  }

  window.AscesaData = { ROUTES, HISTORY, elevFromGrades, sessionSeries };
})();
