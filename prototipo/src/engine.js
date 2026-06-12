/* Ascesa — ride simulation engine (plain JS, framework-agnostic) */
(function () {
  'use strict';

  // ── Athlete ───────────────────────────────────────────────
  const ATHLETE = { name: 'Marco Vinci', ftp: 265, weight: 72, bikeWeight: 8, maxHR: 188, restHR: 52 };
  const MASS = ATHLETE.weight + ATHLETE.bikeWeight;

  // ── Route: Passo dello Stelvio (vers. Bormio) ─────────────
  // Built deterministically: ~100 m steps, grade wandering 4–11 %.
  function buildRoute() {
    const stepM = 100, n = 215, startEle = 1225;
    const pts = []; let ele = startEle, dist = 0;
    for (let i = 0; i <= n; i++) {
      // smooth pseudo-random grade from layered sines
      const x = i / n;
      let g = 7.1
        + 2.6 * Math.sin(i * 0.21 + 0.6)
        + 1.7 * Math.sin(i * 0.071 + 2.1)
        + 1.1 * Math.sin(i * 0.0125)
        - 2.0 * Math.cos(x * Math.PI);          // easier foot & a touch near top
      // a couple of brief false-flats (tornanti)
      if ((i > 60 && i < 64) || (i > 138 && i < 142)) g *= 0.45;
      g = Math.max(2.4, Math.min(11.4, g));
      pts.push({ d: dist, ele: Math.round(ele), grade: +g.toFixed(2) });
      ele += (g / 100) * stepM;
      dist += stepM;
    }
    return {
      id: 'stelvio-bormio',
      name: 'Passo dello Stelvio',
      sub: 'Versante Bormio',
      lengthM: n * stepM,
      gain: Math.round(ele - startEle),
      avg: 7.1, max: 11.4, summit: Math.round(ele),
      startEle, pts, stepM,
    };
  }
  const ROUTE = buildRoute();

  function gradeAt(m) {
    if (m <= 0) return ROUTE.pts[0].grade;
    if (m >= ROUTE.lengthM) return ROUTE.pts[ROUTE.pts.length - 1].grade;
    const i = m / ROUTE.stepM, lo = Math.floor(i), f = i - lo;
    return ROUTE.pts[lo].grade * (1 - f) + ROUTE.pts[lo + 1].grade * f;
  }
  function eleAt(m) {
    if (m <= 0) return ROUTE.pts[0].ele;
    if (m >= ROUTE.lengthM) return ROUTE.pts[ROUTE.pts.length - 1].ele;
    const i = m / ROUTE.stepM, lo = Math.floor(i), f = i - lo;
    return ROUTE.pts[lo].ele * (1 - f) + ROUTE.pts[lo + 1].ele * f;
  }

  // ── Workout: ERG — 5×4' @ 280 W ───────────────────────────
  const WORKOUT = {
    name: 'Soglia 5×4′',
    sub: '5 × 4′ @ 280 W · r 3′',
    blocks: (() => {
      const b = [];
      b.push({ kind: 'warmup', label: 'Riscaldamento', dur: 600, power: 165 });
      for (let i = 0; i < 5; i++) {
        b.push({ kind: 'work', label: `Intervallo ${i + 1}`, dur: 240, power: 280 });
        if (i < 4) b.push({ kind: 'rest', label: 'Recupero', dur: 180, power: 150 });
      }
      b.push({ kind: 'rest', label: 'Recupero', dur: 180, power: 150 });
      b.push({ kind: 'cooldown', label: 'Defaticamento', dur: 300, power: 130 });
      return b;
    })(),
    get total() { return this.blocks.reduce((s, x) => s + x.dur, 0); },
  };
  function ergBlockAt(t) {
    let acc = 0;
    for (let i = 0; i < WORKOUT.blocks.length; i++) {
      const b = WORKOUT.blocks[i];
      if (t < acc + b.dur) return { block: b, idx: i, into: t - acc, acc };
      acc += b.dur;
    }
    const last = WORKOUT.blocks.length - 1;
    return { block: WORKOUT.blocks[last], idx: last, into: WORKOUT.blocks[last].dur, acc: acc - WORKOUT.blocks[last].dur };
  }

  // ── Physics: solve speed for given power & grade ──────────
  const G = 9.81, CRR = 0.005, RHO = 1.2, CDA = 0.42;
  function speedFor(power, gradePct) {
    const grav = MASS * G * (gradePct / 100);
    const roll = CRR * MASS * G;
    let v = 6;
    for (let k = 0; k < 12; k++) {
      const denom = grav + roll + 0.5 * RHO * CDA * v * v;
      const nv = denom > 0.2 ? power / denom : 18;
      v = v + (nv - v) * 0.6;
    }
    return Math.max(0.6, Math.min(22, v)); // m/s
  }

  // ── Zones ─────────────────────────────────────────────────
  const PZ = [146, 198, 238, 278, 318, 397]; // upper bounds z1..z6 (z7 above)
  const HZ = [114, 133, 152, 171];           // upper bounds h1..h4 (h5 above)
  function powerZone(p) { let z = 1; for (const u of PZ) { if (p > u) z++; else break; } return z; }
  function hrZone(h) { let z = 1; for (const u of HZ) { if (h > u) z++; else break; } return z; }

  // ── Engine ────────────────────────────────────────────────
  const SAVE_KEY = 'ascesa-ride-v1';
  function defState() {
    return {
      mode: 'SIM', running: false, finished: false,
      elapsed: 0, distance: 0, offset: 8400, // start 8.4 km up the climb
      power: 0, power3: 0, powerAvg: 0, np: 150, work: 0,
      cadence: 0, speed: 0, hr: 96, grade: gradeAt(8400), ele: eleAt(8400),
      lap: 1, lapStart: 0,
      _emaHR: 96, _emaP3: 0, _np4: Math.pow(150, 4), _npN: 1, _pSum: 0, _pN: 0,
      _emaNP: 150,
    };
  }
  let S = load() || defState();
  function load() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (!raw) return null;
      const o = JSON.parse(raw); o.running = false; return o;
    } catch (e) { return null; }
  }
  function persist() {
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(S)); } catch (e) {}
  }

  const subs = new Set();
  function emit() { subs.forEach(fn => { try { fn(S); } catch (e) {} }); }

  // target power for the rider's effort
  function targetPower(dt) {
    if (S.mode === 'ERG') {
      const { block } = ergBlockAt(S.elapsed);
      return block.power;
    }
    // SIM: tempo-ish effort that drifts with the road
    const base = 232 + 30 * Math.sin(S.elapsed * 0.013) + (S.grade - 7.1) * 6;
    return Math.max(120, Math.min(330, base));
  }

  let lastWall = 0;
  function tick() {
    const now = performance.now();
    let dt = (now - lastWall) / 1000;
    lastWall = now;
    if (!S.running || S.finished) { emit(); return; }
    dt = Math.max(0.05, Math.min(0.6, dt));

    S.elapsed += dt;

    // power: follow target with response + breathing noise
    const tgt = targetPower(dt);
    const resp = S.mode === 'ERG' ? 0.16 : 0.08;
    const noise = (Math.sin(S.elapsed * 2.3) + Math.sin(S.elapsed * 5.1)) * (S.mode === 'ERG' ? 3 : 5);
    S.power = Math.max(0, S.power + (tgt - S.power) * resp + noise * dt * 6);
    if (S.power < 0) S.power = 0;

    // 3s power (ema tau 3)
    S._emaP3 += (S.power - S._emaP3) * (1 - Math.exp(-dt / 3));
    S.power3 = Math.round(S._emaP3);

    // grade + speed
    if (S.mode === 'SIM') {
      S.grade = gradeAt(S.offset + S.distance);
    } else {
      S.grade = 0;
    }
    const v = speedFor(S.power, S.grade);
    S.speed = +(v * 3.6).toFixed(1);
    S.distance += v * dt;
    if (S.mode === 'SIM') {
      const pos = S.offset + S.distance;
      S.ele = eleAt(pos);
      if (pos >= ROUTE.lengthM) { S.running = false; S.finished = true; }
    }

    // cadence
    const cadTgt = S.mode === 'ERG'
      ? (ergBlockAt(S.elapsed).block.kind === 'work' ? 92 : 86)
      : Math.max(70, 94 - S.grade * 1.4);
    S.cadence = Math.round(cadTgt + Math.sin(S.elapsed * 3.7) * 2);

    // hr — lag toward effort target
    const hrTgt = Math.max(95, Math.min(186, 95 + (S.power / ATHLETE.ftp) * 80));
    S._emaHR += (hrTgt - S._emaHR) * (1 - Math.exp(-dt / 18));
    S.hr = Math.round(S._emaHR + Math.sin(S.elapsed * 0.9) * 0.8);

    // aggregates
    S._pSum += S.power * dt; S._pN += dt; S.powerAvg = Math.round(S._pSum / S._pN);
    S.work += S.power * dt / 1000; // kJ
    S._emaNP += (S.power - S._emaNP) * (1 - Math.exp(-dt / 25));
    S._np4 += Math.pow(Math.max(0, S._emaNP), 4) * dt; S._npN += dt;
    S.np = Math.round(Math.pow(S._np4 / S._npN, 0.25));

    persistThrottle();
    emit();
  }

  let _pt = 0;
  function persistThrottle() { const n = performance.now(); if (n - _pt > 1500) { _pt = n; persist(); } }

  let timer = null;
  function ensureTimer() { if (!timer) { lastWall = performance.now(); timer = setInterval(tick, 250); } }
  ensureTimer();

  const Engine = {
    get state() { return S; },
    subscribe(fn) { subs.add(fn); fn(S); return () => subs.delete(fn); },
    start() { if (S.finished) this.reset(); S.running = true; lastWall = performance.now(); emit(); },
    pause() { S.running = false; persist(); emit(); },
    toggle() { S.running ? this.pause() : this.start(); },
    setMode(m) {
      if (m === S.mode) return;
      S.mode = m; emit();
    },
    lap() { S.lap += 1; S.lapStart = S.elapsed; emit(); },
    reset() { const m = S.mode; S = defState(); S.mode = m; persist(); emit(); },
    finish() { S.running = false; S.finished = true; persist(); emit(); },
    // derived helpers
    remainingM() {
      if (S.mode === 'SIM') return Math.max(0, ROUTE.lengthM - (S.offset + S.distance));
      return null;
    },
    remainingT() {
      if (S.mode === 'ERG') return Math.max(0, WORKOUT.total - S.elapsed);
      return null;
    },
    erg() { return ergBlockAt(S.elapsed); },
  };

  window.ATHLETE = ATHLETE;
  window.ROUTE = ROUTE;
  window.WORKOUT = WORKOUT;
  window.RideEngine = Engine;
  window.RideZones = { powerZone, hrZone, gradeAt, eleAt, speedFor, PZ, HZ, ergBlockAt };
})();
