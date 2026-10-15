"use strict";

/* Settings ----------------------------------------------------------- */
const ACCENTS = [
  ["Blue", "#0A84FF"], ["Purple", "#BF5AF2"], ["Pink", "#FF375F"], ["Red", "#FF453A"],
  ["Orange", "#FF9F0A"], ["Yellow", "#FFD60A"], ["Green", "#30D158"], ["Teal", "#40C8E0"], ["Graphite", "#8E8E93"],
];
const DEFAULTS = { appearance: "system", accent: "#0A84FF", colors: true, unit: "K", view: "table" };
const STORE_KEY = "elements.settings.v1";

const store = {
  load() {
    try { return { ...DEFAULTS, ...JSON.parse(localStorage.getItem(STORE_KEY) || "{}") }; }
    catch { return { ...DEFAULTS }; }
  },
  save(s) { try { localStorage.setItem(STORE_KEY, JSON.stringify(s)); } catch { /* storage unavailable */ } },
};

let settings = store.load();
const state = { query: "", cat: null, current: null, model: "bohr" };
const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;

function applySettings() {
  const root = document.documentElement;
  if (settings.appearance === "system") root.removeAttribute("data-theme");
  else root.dataset.theme = settings.appearance;
  root.dataset.colors = settings.colors ? "on" : "off";
  root.style.setProperty("--accent", settings.accent);
  const dark = settings.appearance === "dark" || (settings.appearance === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
  document.querySelector('meta[name="theme-color"]').content = dark ? "#050507" : "#eef0f6";
}
function update(patch) {
  settings = { ...settings, ...patch };
  store.save(settings);
  applySettings();
}
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", applySettings);

/* Helpers ------------------------------------------------------------ */
const $ = (sel, el = document) => el.querySelector(sel);
const h = (tag, props = {}, ...kids) => {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (k === "class") el.className = v;
    else if (k === "style") el.style.cssText = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (v !== false && v != null) el.setAttribute(k, v === true ? "" : v);
  }
  for (const kid of kids.flat()) if (kid != null) el.append(kid);
  return el;
};
const SVG_NS = "http://www.w3.org/2000/svg";
const s = (tag, attrs = {}, ...kids) => {
  const el = document.createElementNS(SVG_NS, tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  for (const kid of kids.flat()) if (kid != null) el.append(kid);
  return el;
};
const catColor = (e) => CATEGORIES[e.cat].color;
const fmt = (v, d = 0) => v.toLocaleString(undefined, { maximumFractionDigits: d });

function segmented(options, value, onChange, cls = "") {
  const wrap = h("div", { class: `seg glass ${cls}`, role: "group" });
  const render = (val) => {
    wrap.replaceChildren(...options.map(([v, label]) =>
      h("button", { type: "button", "aria-pressed": String(v === val), onclick: () => { onChange(v); render(v); } }, label)));
  };
  render(value);
  return wrap;
}

function temp(k) {
  if (k == null) return "—";
  if (settings.unit === "C") return `${fmt(k - 273.15, 1)} °C`;
  if (settings.unit === "F") return `${fmt((k - 273.15) * 9 / 5 + 32, 1)} °F`;
  return `${fmt(k, 1)} K`;
}
function density(e) {
  if (e.density == null) return "—";
  return e.phase === "g" ? `${fmt(e.density * 1000, 3)} g/L` : `${fmt(e.density, 3)} g/cm³`;
}
const PHASES = { s: "Solid", l: "Liquid", g: "Gas", u: "Unknown" };
const BLOCKS = { s: "s-block", p: "p-block", d: "d-block", f: "f-block" };

/* Search / filter ---------------------------------------------------- */
function matches(e) {
  if (state.cat && e.cat !== state.cat) return false;
  const q = state.query.trim().toLowerCase();
  if (!q) return true;
  return e.name.toLowerCase().includes(q)
    || (q.length <= 2 && e.sym.toLowerCase().startsWith(q))
    || String(e.n) === q
    || CATEGORIES[e.cat].label.toLowerCase().includes(q);
}

/* Table & list ------------------------------------------------------- */
const tableEl = $("#table");
const listEl = $("#list");
const cells = new Map();

function buildTable() {
  for (const e of ELEMENTS) {
    const btn = h("button", {
      class: "el", type: "button", style: `grid-row:${e.pos.row};grid-column:${e.pos.col};--c-cat:${catColor(e)}`,
      "aria-label": `${e.name}, atomic number ${e.n}`, onclick: () => openDetail(e.n),
    },
      h("span", { class: "no" }, e.n),
      h("span", { class: "sym" }, e.sym),
      h("span", { class: "nm" }, e.name),
      h("span", { class: "ms" }, fmt(e.mass, 3)));
    cells.set(e.n, btn);
    tableEl.append(btn);
  }
  const ph = (row, label, range, cat) => h("div", { class: "ph", style: `grid-row:${row};grid-column:3;--c:${CATEGORIES[cat].color}`, "aria-hidden": "true" }, h("div", {}, h("span", {}, label), range));
  tableEl.append(ph(6, "La–Lu", "57–71", "lanthanide"), ph(7, "Ac–Lr", "89–103", "actinide"));
}

function buildList() {
  listEl.replaceChildren(...ELEMENTS.map((e) => {
    const li = h("li", { "data-n": e.n },
      h("button", { class: "row", type: "button", onclick: () => openDetail(e.n) },
        h("span", { class: "badge", style: `--c:${catColor(e)}` }, e.sym),
        h("span", { class: "name" }, h("b", {}, e.name), h("small", {}, CATEGORIES[e.cat].label)),
        h("span", { class: "num" }, e.n)));
    return li;
  }));
}

function refresh() {
  const isTable = settings.view === "table";
  $("#table-wrap").hidden = !isTable;
  listEl.hidden = isTable;
  let count = 0;
  for (const e of ELEMENTS) {
    const ok = matches(e);
    if (ok) count++;
    cells.get(e.n).classList.toggle("dim", !ok);
  }
  for (const li of listEl.children) li.hidden = !matches(ELEMENTS[li.dataset.n - 1]);
  $("#empty").hidden = count > 0;
}

function buildLegend() {
  const legend = $("#legend");
  legend.replaceChildren(...Object.entries(CATEGORIES).map(([key, c]) =>
    h("button", {
      class: "chip glass", type: "button", style: `--c:${c.color}`, "aria-pressed": "false", "data-cat": key,
      onclick: () => {
        state.cat = state.cat === key ? null : key;
        for (const b of legend.children) b.setAttribute("aria-pressed", String(b.dataset.cat === state.cat));
        refresh();
      },
    }, h("b"), h("span", {}, c.label))));
}

function buildViewSeg() {
  const host = $("#view-seg");
  const render = () => host.replaceChildren(...[["table", "Table"], ["list", "List"]].map(([v, label]) =>
    h("button", { type: "button", "aria-pressed": String(settings.view === v), onclick: () => { update({ view: v }); render(); refresh(); } }, label)));
  render();
}

$("#q").addEventListener("input", (ev) => { state.query = ev.target.value; refresh(); });
$("#q").addEventListener("keydown", (ev) => {
  if (ev.key !== "Enter") return;
  const first = ELEMENTS.find(matches);
  if (first && (state.query || state.cat)) { ev.target.blur(); openDetail(first.n); }
});

/* Sheets ------------------------------------------------------------- */
function closeSheet(dlg) {
  if (!dlg.open) return;
  if (reduceMotion) { dlg.close(); return; }
  dlg.classList.add("closing");
  dlg.addEventListener("animationend", () => { dlg.classList.remove("closing"); dlg.close(); }, { once: true });
}
for (const dlg of document.querySelectorAll("dialog")) {
  dlg.addEventListener("click", (ev) => { if (ev.target === dlg) closeSheet(dlg); });
  dlg.addEventListener("cancel", (ev) => { ev.preventDefault(); closeSheet(dlg); });
}
$("#detail").addEventListener("close", () => { state.current = null; history.replaceState(null, "", location.pathname + location.search); });

const icon = {
  prev: '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m15 5-7 7 7 7"/></svg>',
  next: '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m9 5 7 7-7 7"/></svg>',
};
const iconBtn = (svg, label, onclick, disabled) => {
  const b = h("button", { class: "pill-btn sq glass", type: "button", "aria-label": label, onclick, disabled });
  b.insertAdjacentHTML("beforeend", svg);
  return b;
};

/* Element detail ----------------------------------------------------- */
const MODELS = [["bohr", "Bohr"], ["cloud", "Cloud"], ["lewis", "Lewis"]];
const MODEL_NOTES = {
  bohr: "Electrons orbiting in energy shells.",
  cloud: "Probability cloud — denser areas are where electrons are likelier to be found.",
  lewis: "Valence electrons shown as dots.",
};

function openDetail(n) {
  const dlg = $("#detail");
  const e = ELEMENTS[n - 1];
  state.current = n;
  history.replaceState(null, "", `#${e.sym}`);

  const stage = h("div", { class: "stage glass" });
  const note = h("p", { class: "stage-note" });
  const showModel = (m) => {
    state.model = m;
    stage.replaceChildren(renderModel(e, m));
    note.textContent = m === "lewis" && valenceOf(e) > 8 ? "" : MODEL_NOTES[m];
  };

  const stat = (label, value, cls = "") => h("div", { class: `stat glass ${cls}` }, h("small", {}, label), h("b", { class: cls.includes("mono") ? "mono" : "" }, value));
  const neutrons = Math.round(e.mass) - e.n;

  const sheet = h("div", { class: "sheet" },
    h("div", { class: "grab" }),
    h("div", { class: "bar" },
      h("div", { class: "grp" },
        iconBtn(icon.prev, "Previous element", () => openDetail(n - 1), n === 1),
        iconBtn(icon.next, "Next element", () => openDetail(n + 1), n === 118)),
      h("button", { class: "pill-btn glass", type: "button", onclick: () => closeSheet(dlg) }, h("span", {}, "Done"))),
    h("div", { class: "hero" },
      h("div", { class: "tile", style: `--c-cat:${catColor(e)}` }, h("span", { class: "no" }, e.n), h("span", { class: "sym" }, e.sym)),
      h("div", {}, h("h2", {}, e.name), h("p", {}, `${CATEGORIES[e.cat].label} · ${fmt(e.mass, 3)} u`))),
    h("p", { class: "fact" }, e.fact),
    segmented(MODELS, state.model, showModel, "model-seg"),
    stage, note,
    h("div", { class: "sect" }, "Properties"),
    h("div", { class: "grid" },
      stat("State at 20 °C", PHASES[e.phase]),
      stat("Melting point", temp(e.melt)),
      stat("Boiling point", temp(e.boil)),
      stat("Density", density(e)),
      stat("Electronegativity", e.en == null ? "—" : e.en.toFixed(2)),
      stat("Discovered", e.year === 0 ? "Antiquity" : e.year)),
    h("div", { class: "sect" }, "Structure"),
    h("div", { class: "grid" },
      stat("Group", e.group ?? "—"),
      stat("Period", e.period),
      stat("Block", BLOCKS[e.block]),
      stat("Protons", e.n),
      stat("Electrons", e.n),
      stat("Neutrons (typical)", neutrons),
      stat("Electron configuration", e.config, "wide mono"),
      stat("Electrons per shell", e.shells.join(" · "), "wide mono")));

  dlg.replaceChildren(sheet);
  showModel(state.model);
  if (!dlg.open) dlg.showModal();
  sheet.scrollTop = 0;
  $(".pill-btn:not(:disabled)", sheet)?.blur();
}

$("#detail").addEventListener("keydown", (ev) => {
  if (state.current == null) return;
  if (ev.key === "ArrowLeft" && state.current > 1) openDetail(state.current - 1);
  if (ev.key === "ArrowRight" && state.current < 118) openDetail(state.current + 1);
});

/* Atomic models ------------------------------------------------------ */
function valenceOf(e) { return e.shells[e.shells.length - 1]; }
const radius = (i, k) => (k === 1 ? 50 : 24 + (i * 66) / (k - 1));

function renderModel(e, kind) {
  if (kind === "cloud") return cloudModel(e);
  if (kind === "lewis") return lewisModel(e);
  return bohrModel(e);
}

function defs(id) {
  return s("defs", {},
    s("radialGradient", { id: `nuc-${id}`, cx: "35%", cy: "30%", r: "75%" },
      s("stop", { offset: "0", "stop-color": "#fff", "stop-opacity": "0.95" }),
      s("stop", { offset: "0.35", "stop-color": "var(--accent)" }),
      s("stop", { offset: "1", "stop-color": "var(--accent)", "stop-opacity": "0.55" })),
    s("radialGradient", { id: `glow-${id}`, cx: "50%", cy: "50%", r: "50%" },
      s("stop", { offset: "0", "stop-color": "var(--accent)", "stop-opacity": "0.55" }),
      s("stop", { offset: "1", "stop-color": "var(--accent)", "stop-opacity": "0" })));
}

function bohrModel(e) {
  const k = e.shells.length;
  const svg = s("svg", { viewBox: "-100 -100 200 200", role: "img", "aria-label": `Bohr model of ${e.name}: ${e.shells.join(", ")} electrons per shell` });
  svg.append(defs("b"));
  svg.append(s("circle", { r: 34, fill: "url(#glow-b)" }));
  const nr = Math.min(6 + Math.sqrt(e.n) * 0.7, 15);
  e.shells.forEach((count, i) => {
    const r = radius(i, k);
    svg.append(s("circle", { r, fill: "none", stroke: "currentColor", "stroke-opacity": "0.18", "stroke-width": "0.8" }));
    const ring = s("g", {});
    const dot = Math.max(1.6, Math.min(3.2, (2 * Math.PI * r) / count / 3.2));
    for (let j = 0; j < count; j++) {
      const a = (j / count) * Math.PI * 2 + i * 0.7;
      ring.append(s("circle", { cx: (Math.cos(a) * r).toFixed(2), cy: (Math.sin(a) * r).toFixed(2), r: dot.toFixed(2), fill: "var(--accent)", stroke: "#fff", "stroke-opacity": "0.6", "stroke-width": "0.4" }));
    }
    if (!reduceMotion) {
      const dur = 6 + i * 4;
      ring.append(s("animateTransform", { attributeName: "transform", type: "rotate", from: "0", to: i % 2 ? "-360" : "360", dur: `${dur}s`, repeatCount: "indefinite" }));
    }
    svg.append(ring);
  });
  svg.append(s("circle", { r: nr, fill: "url(#nuc-b)", stroke: "#fff", "stroke-opacity": "0.5", "stroke-width": "0.5" }));
  return svg;
}

function mulberry32(a) {
  return () => { a |= 0; a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
function gauss(rand) { return Math.sqrt(-2 * Math.log(1 - rand())) * Math.cos(2 * Math.PI * rand()); }

function cloudModel(e) {
  const k = e.shells.length;
  const rand = mulberry32(e.n * 7919);
  const svg = s("svg", { viewBox: "-100 -100 200 200", class: "cloud", role: "img", "aria-label": `Electron cloud model of ${e.name}` });
  svg.append(defs("c"));
  svg.append(s("circle", { r: 30, fill: "url(#glow-c)" }));
  e.shells.forEach((count, i) => {
    const r = radius(i, k) * (k === 1 ? 0.75 : 1);
    const dots = count * 9;
    for (let j = 0; j < dots; j++) {
      // Sample points on a sphere, then project to 2D, for a soft volumetric look.
      const rr = Math.max(2, r * (1 + 0.16 * gauss(rand)));
      const a = rand() * Math.PI * 2;
      const z = rand() * 2 - 1;
      const proj = Math.sqrt(1 - z * z) * 0.35 + 0.65;
      svg.append(s("circle", {
        cx: (Math.cos(a) * rr * proj).toFixed(1), cy: (Math.sin(a) * rr * proj).toFixed(1),
        r: (0.7 + rand() * 0.9).toFixed(2), fill: "var(--accent)", "fill-opacity": (0.25 + rand() * 0.55).toFixed(2),
      }));
    }
  });
  svg.append(s("circle", { r: 3.5, fill: "var(--accent)" }));
  return svg;
}

function lewisModel(e) {
  const v = valenceOf(e);
  const svg = s("svg", { viewBox: "0 0 200 200", role: "img", "aria-label": `Lewis dot structure of ${e.name}, ${v} valence electrons` });
  svg.append(s("rect", { x: 56, y: 56, width: 88, height: 88, rx: 24, fill: "var(--accent)", "fill-opacity": "0.14", stroke: "var(--accent)", "stroke-opacity": "0.4", "stroke-width": "1" }));
  const t = s("text", { x: 100, y: 118, "text-anchor": "middle", "font-size": 52, "font-weight": 700, fill: "currentColor" });
  t.textContent = e.sym;
  svg.append(t);
  if (v > 8) {
    const m = s("text", { x: 100, y: 176, "text-anchor": "middle", "font-size": 9, fill: "currentColor", "fill-opacity": "0.6" });
    m.textContent = "Outer shell is too full for a simple dot diagram";
    svg.append(m);
    return svg;
  }
  // Dot slots: top, right, bottom, left — each side holds a pair.
  const slots = [[85, 36], [164, 85], [115, 164], [36, 115], [115, 36], [164, 115], [85, 164], [36, 85]];
  const order = e.n === 2 ? [0, 4] : [0, 1, 2, 3, 4, 5, 6, 7];
  for (let i = 0; i < v; i++) {
    const [x, y] = slots[order[i]];
    svg.append(s("circle", { cx: x, cy: y, r: 6, fill: "var(--accent)", stroke: "#fff", "stroke-opacity": "0.55", "stroke-width": "0.8" }));
  }
  return svg;
}

/* Settings sheet ----------------------------------------------------- */
function openSettings() {
  const dlg = $("#settings");
  const accentSw = h("div", { class: "swatches", role: "group", "aria-label": "Accent colour" });
  const hex = h("span", { class: "hex" });
  const renderAccent = () => {
    const cur = settings.accent.toLowerCase();
    const preset = ACCENTS.some(([, c]) => c.toLowerCase() === cur);
    hex.textContent = settings.accent;
    const picker = h("input", { type: "color", value: settings.accent, "aria-label": "Custom accent colour",
      oninput: (ev) => { update({ accent: ev.target.value.toUpperCase() }); hex.textContent = settings.accent; markPresets(); } });
    const custom = h("label", { class: `sw custom${preset ? "" : " on"}`, style: `--sw:${preset ? "transparent" : settings.accent}`, title: "Custom colour" }, picker);
    accentSw.replaceChildren(
      ...ACCENTS.map(([name, c]) => h("button", { class: "sw", type: "button", style: `--sw:${c}`, "aria-label": name, "aria-pressed": String(c.toLowerCase() === cur),
        onclick: () => { update({ accent: c }); renderAccent(); } })),
      custom);
    if (!preset) custom.style.background = settings.accent;
    function markPresets() {
      for (const b of accentSw.querySelectorAll("button.sw")) b.setAttribute("aria-pressed", "false");
      custom.classList.add("on"); custom.style.background = settings.accent; custom.style.setProperty("--sw", settings.accent);
    }
  };
  renderAccent();

  const colorSwitch = h("label", { class: "switch" },
    h("input", { type: "checkbox", role: "switch", checked: settings.colors, onchange: (ev) => update({ colors: ev.target.checked }) }), h("i"));

  const sheet = h("div", { class: "sheet" },
    h("div", { class: "grab" }),
    h("div", { class: "bar" }, h("span"), h("button", { class: "pill-btn glass", type: "button", onclick: () => closeSheet(dlg) }, h("span", {}, "Done"))),
    h("h2", { class: "settings-title" }, "Settings"),
    h("div", { class: "sect" }, "Appearance"),
    h("div", { class: "group glass" },
      h("div", { class: "line stack" }, segmented([["system", "System"], ["light", "Light"], ["dark", "Dark"]], settings.appearance, (v) => update({ appearance: v }), "full"))),
    h("div", { class: "sect" }, "Accent colour"),
    h("div", { class: "group glass" },
      h("div", { class: "line stack" }, accentSw),
      h("div", { class: "line" }, h("span", {}, "Current"), hex)),
    h("div", { class: "sect" }, "Display"),
    h("div", { class: "group glass" },
      h("div", { class: "line" }, h("span", {}, "Colour by category"), colorSwitch),
      h("div", { class: "line stack" }, h("span", {}, "Temperature"), segmented([["K", "Kelvin"], ["C", "Celsius"], ["F", "Fahrenheit"]], settings.unit, (v) => update({ unit: v }), "full"))),
    h("button", { class: "reset glass", type: "button", onclick: () => { update({ ...DEFAULTS, view: settings.view }); refresh(); openSettings(); } }, "Reset to defaults"));

  dlg.replaceChildren(sheet);
  if (!dlg.open) dlg.showModal();
}
$("#open-settings").addEventListener("click", openSettings);

/* Boot --------------------------------------------------------------- */
applySettings();
buildTable();
buildList();
buildLegend();
buildViewSeg();
refresh();

function openFromHash() {
  const key = decodeURIComponent(location.hash.slice(1)).toLowerCase();
  if (!key) return;
  const e = ELEMENTS.find((x) => x.sym.toLowerCase() === key || x.name.toLowerCase() === key || String(x.n) === key);
  if (e) openDetail(e.n);
}
openFromHash();
