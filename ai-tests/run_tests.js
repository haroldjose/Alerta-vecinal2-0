#!/usr/bin/env node
'use strict';

/*
 * Pruebas de API y de efectividad de la IA de Alerta Vecinal.
 *
 * Modo "hf": llama directamente a los tres modelos de Hugging Face que usa el
 *   backend (toxicidad, clasificación zero-shot y similitud) y mide estado HTTP,
 *   latencia y efectividad (precisión, exhaustividad, F1) contra dataset.json.
 *   Requiere la variable HF_API_KEY.
 *
 * Modo "functions": llama a las Cloud Functions desplegadas (prueba de extremo a
 *   extremo, incluidas las palabras clave y la lógica del servidor) y comprueba
 *   que exijan autenticación y validen la entrada.
 *   Requiere ID_TOKEN, o bien FIREBASE_API_KEY + TEST_EMAIL + TEST_PASSWORD.
 *
 * Uso:
 *   node run_tests.js hf
 *   node run_tests.js hf --only=offensive,type,duplicates --delay=300
 *   node run_tests.js functions
 *
 * Requiere Node 18 o superior (usa fetch). No necesita instalar paquetes.
 */

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// configuración
const HF_BASE = (process.env.HF_BASE_URL || 'https://router.huggingface.co/hf-inference/models').replace(/\/$/, '');
const FUNCTIONS_BASE = (process.env.FUNCTIONS_BASE_URL || 'https://us-central1-alerta-vecinal-297eb.cloudfunctions.net').replace(/\/$/, '');

const MODELS = {
  toxicity: 's-nlp/roberta_toxicity_classifier',
  type: 'joeddav/xlm-roberta-large-xnli',
  similarity: 'sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2',
};

const CANDIDATE_LABELS = [
  'inseguridad y delincuencia',
  'servicios básicos e infraestructura',
  'contaminación y medio ambiente',
  'convivencia vecinal',
];
const LABEL_TO_TYPE = {
  'inseguridad y delincuencia': 'inseguridad',
  'servicios básicos e infraestructura': 'serviciosBasicos',
  'contaminación y medio ambiente': 'contaminacion',
  'convivencia vecinal': 'convivencia',
};
const TYPES = ['inseguridad', 'serviciosBasicos', 'contaminacion', 'convivencia'];

const TOXIC_THRESHOLD = 0.75; // igual que checkOffensiveContent en index.js

// utilidades
const args = process.argv.slice(2);
const mode = args[0];
const opt = (name, def) => {
  const a = args.find((x) => x.startsWith(`--${name}=`));
  return a ? a.split('=')[1] : def;
};
const ONLY = opt('only', 'offensive,type,duplicates').split(',');
const DELAY = Number(opt('delay', 250));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const pct = (x) => (x === null || x === undefined ? 'n/d' : `${(x * 100).toFixed(1)} %`);
const num = (x, d = 3) => (x === null || x === undefined ? 'n/d' : x.toFixed(d));
const ms = (x) => (x === null || x === undefined ? 'n/d' : `${Math.round(x)}`);

function mdTable(headers, rows) {
  const line = (cells) => `| ${cells.join(' | ')} |`;
  return [line(headers), line(headers.map(() => '---')), ...rows.map(line)].join('\n');
}

function percentile(values, p) {
  if (!values.length) return null;
  const s = [...values].sort((a, b) => a - b);
  const idx = Math.min(s.length - 1, Math.ceil((p / 100) * s.length) - 1);
  return s[Math.max(0, idx)];
}
const mean = (v) => (v.length ? v.reduce((a, b) => a + b, 0) / v.length : null);

function binaryMetrics(rows) {
  let tp = 0, fp = 0, fn = 0, tn = 0;
  for (const r of rows) {
    if (r.expected && r.predicted) tp++;
    else if (!r.expected && r.predicted) fp++;
    else if (r.expected && !r.predicted) fn++;
    else tn++;
  }
  const precision = tp + fp ? tp / (tp + fp) : null;
  const recall = tp + fn ? tp / (tp + fn) : null;
  const f1 = precision !== null && recall !== null ? (precision + recall ? (2 * precision * recall) / (precision + recall) : 0) : null;
  return { tp, fp, fn, tn, precision, recall, f1, accuracy: rows.length ? (tp + tn) / rows.length : null, n: rows.length };
}

function multiclassMetrics(rows, labels) {
  const cols = [...labels, 'ninguna'];
  const cm = {};
  labels.forEach((l) => { cm[l] = Object.fromEntries(cols.map((c) => [c, 0])); });
  rows.forEach((r) => {
    const p = labels.includes(r.predicted) ? r.predicted : 'ninguna';
    cm[r.expected][p]++;
  });
  const perClass = labels.map((l) => {
    const tp = cm[l][l];
    const fp = labels.filter((o) => o !== l).reduce((a, o) => a + cm[o][l], 0);
    const fn = cols.filter((c) => c !== l).reduce((a, c) => a + cm[l][c], 0);
    const precision = tp + fp ? tp / (tp + fp) : 0;
    const recall = tp + fn ? tp / (tp + fn) : 0;
    const f1 = precision + recall ? (2 * precision * recall) / (precision + recall) : 0;
    return { label: l, precision, recall, f1 };
  });
  const correct = labels.reduce((a, l) => a + cm[l][l], 0);
  return {
    cm, cols, perClass,
    accuracy: rows.length ? correct / rows.length : null,
    macroF1: mean(perClass.map((c) => c.f1)),
    n: rows.length,
  };
}

function binaryRow(name, m) {
  return [name, pct(m.precision), pct(m.recall), pct(m.f1), pct(m.accuracy), `${m.tp}/${m.fp}/${m.fn}/${m.tn}`];
}
const BIN_HEAD = ['Método', 'Precisión', 'Exhaustividad', 'F1', 'Exactitud', 'VP/FP/FN/VN'];

function confusionTable(m) {
  const header = ['Real \\ Predicho', ...m.cols];
  const rows = Object.keys(m.cm).map((l) => [l, ...m.cols.map((c) => String(m.cm[l][c]))]);
  return mdTable(header, rows);
}

// lógica pura de index.js
function loadPureLogic() {
  const file = process.env.FUNCTIONS_INDEX || path.join(__dirname, '..', 'functions', 'index.js');
  const src = fs.readFileSync(file, 'utf8');
  const start = src.indexOf('const KEYWORDS = {');
  const end = src.indexOf('// Llama al pipeline SentenceSimilarity de HF.');
  if (start < 0 || end < 0 || end < start) {
    throw new Error(`No pude extraer la lógica de ${file}. Indica la ruta con FUNCTIONS_INDEX=... o revisa que index.js conserve los comentarios originales.`);
  }
  const code = `${src.slice(start, end)}\n({ classifyByKeywords, detectOffensiveWordsLocally, jaccardSimilarity });`;
  const logic = vm.runInNewContext(code, {});
  const jt = src.match(/const JACCARD_THRESHOLD\s*=\s*([0-9.]+)/);
  const ct = src.match(/const COSINE_THRESHOLD\s*=\s*([0-9.]+)/);
  logic.JACCARD_THRESHOLD = jt ? Number(jt[1]) : 0.1;
  logic.COSINE_THRESHOLD = ct ? Number(ct[1]) : 0.7;
  return logic;
}

// llamadas HTTP
const calls = []; // { api, status, ms, cold, error }

async function hfCall(key, body) {
  const url = `${HF_BASE}/${MODELS[key]}`;
  let last = null;
  let cold = 0;
  for (let attempt = 0; attempt < 3; attempt++) {
    const t0 = performance.now();
    let status = 0, data = null, error = null;
    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { Authorization: `Bearer ${process.env.HF_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(60000),
      });
      status = res.status;
      const text = await res.text();
      try { data = JSON.parse(text); } catch { error = text.slice(0, 120); }
    } catch (e) {
      error = e.message;
    }
    last = { status, data, error, ms: performance.now() - t0 };
    if (status === 503 && attempt < 2) {
      cold++;
      const wait = Math.min(((data && data.estimated_time) || 15) * 1000, 20000);
      await sleep(wait);
      continue;
    }
    break;
  }
  calls.push({ api: key, status: last.status, ms: last.ms, cold, error: last.error });
  return last;
}

async function fnCall(name, body, headers) {
  const t0 = performance.now();
  let status = 0, data = null, error = null;
  try {
    const res = await fetch(`${FUNCTIONS_BASE}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: typeof body === 'string' ? body : JSON.stringify(body),
      signal: AbortSignal.timeout(90000),
    });
    status = res.status;
    const text = await res.text();
    try { data = JSON.parse(text); } catch { error = text.slice(0, 120); }
  } catch (e) {
    error = e.message;
  }
  const out = { status, data, error, ms: performance.now() - t0 };
  calls.push({ api: `fn:${name}`, status, ms: out.ms, cold: 0, error });
  return out;
}

function apiStatsTable() {
  const groups = {};
  calls.forEach((c) => { (groups[c.api] = groups[c.api] || []).push(c); });
  const rows = Object.entries(groups).map(([api, list]) => {
    const lat = list.filter((c) => c.status > 0).map((c) => c.ms);
    const ok = list.filter((c) => c.status === 200).length;
    const statuses = {};
    list.forEach((c) => { statuses[c.status] = (statuses[c.status] || 0) + 1; });
    return [
      api, String(list.length), pct(ok / list.length),
      Object.entries(statuses).map(([s, n]) => `${s}×${n}`).join(' '),
      ms(mean(lat)), ms(percentile(lat, 50)), ms(percentile(lat, 95)), ms(lat.length ? Math.max(...lat) : null),
      String(list.reduce((a, c) => a + c.cold, 0)),
    ];
  });
  return mdTable(['API', 'Llamadas', 'HTTP 200', 'Códigos HTTP', 'Media (ms)', 'P50 (ms)', 'P95 (ms)', 'Máx (ms)', 'Arranques en frío (503)'], rows);
}

// decisión de tipo (copia de suggestProblemType)
function decideType(kw, hfType) {
  if (kw && kw.dominance >= 0.6 && kw.score >= 2) return { pred: kw.type, source: 'palabras clave' };
  if (!hfType) return kw ? { pred: kw.type, source: 'palabras clave (IA no disponible)' } : { pred: null, source: 'sin resultado' };
  if (kw && kw.type !== hfType) {
    if (kw.dominance >= 0.7) return { pred: kw.type, source: 'palabras clave' };
    return { pred: hfType, source: 'IA' };
  }
  return { pred: hfType, source: 'IA' };
}

function parseToxic(data) {
  const results = Array.isArray(data && data[0]) ? data[0] : data;
  if (!Array.isArray(results)) return null;
  const t = results.find((r) => r.label === 'toxic');
  return t ? t.score : 0;
}

const short = (t, n = 70) => (t.length > n ? `${t.slice(0, n - 1)}…` : t);

// pruebas modo hf
async function offensiveHF(ds, pure) {
  const rows = [];
  for (const s of ds.offensive) {
    const localWords = pure.detectOffensiveWordsLocally(s.text);
    const r = await hfCall('toxicity', { inputs: s.text });
    const score = r.status === 200 ? parseToxic(r.data) : null;
    rows.push({ id: s.id, text: s.text, expected: s.expected, local: localWords.length > 0, localWords, hfScore: score, hfStatus: r.status });
    await sleep(DELAY);
  }
  const hfAt = (th) => rows.map((r) => ({ expected: r.expected, predicted: r.hfScore !== null && r.hfScore >= th }));
  const local = binaryMetrics(rows.map((r) => ({ expected: r.expected, predicted: r.local })));
  const hf = binaryMetrics(hfAt(TOXIC_THRESHOLD));
  const combined = binaryMetrics(rows.map((r) => ({ expected: r.expected, predicted: r.local || (r.hfScore !== null && r.hfScore >= TOXIC_THRESHOLD) })));
  const sweep = [0.3, 0.5, 0.6, 0.7, 0.75, 0.8, 0.9, 0.95].map((th) => binaryRow(`HF solo, umbral ${th}`, binaryMetrics(hfAt(th))));

  const yes = rows.filter((r) => r.expected);
  const no = rows.filter((r) => !r.expected);
  const hfOnlyAdds = yes.filter((r) => !r.local && r.hfScore !== null && r.hfScore >= TOXIC_THRESHOLD).length;
  const localFP = no.filter((r) => r.local);
  const fn = rows.filter((r) => r.expected && !(r.local || (r.hfScore !== null && r.hfScore >= TOXIC_THRESHOLD)));
  const fp = rows.filter((r) => !r.expected && (r.local || (r.hfScore !== null && r.hfScore >= TOXIC_THRESHOLD)));
  const hfFailed = rows.filter((r) => r.hfScore === null).length;

  const md = [
    '## Lenguaje ofensivo',
    `Muestras: ${yes.length} ofensivas y ${no.length} no ofensivas. Umbral de la función: ${TOXIC_THRESHOLD}.`,
    '',
    mdTable(BIN_HEAD, [
      binaryRow('Solo lista local de palabras', local),
      binaryRow(`Solo modelo de Hugging Face (umbral ${TOXIC_THRESHOLD})`, hf),
      binaryRow('Combinado (como en checkOffensiveContent)', combined),
    ]),
    '',
    `Puntaje tóxico medio del modelo: ofensivos ${num(mean(yes.filter((r) => r.hfScore !== null).map((r) => r.hfScore)))} / no ofensivos ${num(mean(no.filter((r) => r.hfScore !== null).map((r) => r.hfScore)))}.`,
    `Ofensivos que solo detectó el modelo (la lista local no): ${hfOnlyAdds} de ${yes.length}. Falsos positivos de la lista local: ${localFP.length} de ${no.length}.`,
    hfFailed ? `Llamadas al modelo sin puntaje válido: ${hfFailed}.` : '',
    '',
    '**Variación del umbral del modelo (solo Hugging Face)**',
    '',
    mdTable(BIN_HEAD, sweep),
    '',
    '**Errores del método combinado**',
    '',
    fn.length || fp.length
      ? mdTable(['Tipo', 'ID', 'Texto', 'Lista local', 'Puntaje HF'], [
          ...fn.map((r) => ['Falso negativo', r.id, short(r.text), r.local ? 'sí' : 'no', num(r.hfScore)]),
          ...fp.map((r) => ['Falso positivo', r.id, short(r.text), r.local ? `sí (${r.localWords.join(', ')})` : 'no', num(r.hfScore)]),
        ])
      : 'Sin errores.',
  ].join('\n');
  return { md, data: { rows, local, hf, combined } };
}

async function typeHF(ds, pure) {
  const rows = [];
  for (const s of ds.problemType) {
    const kw = pure.classifyByKeywords(s.text);
    const r = await hfCall('type', { inputs: s.text, parameters: { candidate_labels: CANDIDATE_LABELS, multi_label: false } });
    let hfType = null, hfScore = null;
    if (r.status === 200 && r.data && Array.isArray(r.data.labels) && r.data.labels.length) {
      hfType = LABEL_TO_TYPE[r.data.labels[0]] || 'inseguridad';
      hfScore = r.data.scores ? r.data.scores[0] : null;
    }
    const d = decideType(kw, hfType);
    rows.push({ id: s.id, text: s.text, expected: s.expected, kw: kw ? kw.type : null, kwDominance: kw ? kw.dominance : null, hfType, hfScore, pred: d.pred, source: d.source });
    await sleep(DELAY);
  }
  const mKw = multiclassMetrics(rows.map((r) => ({ expected: r.expected, predicted: r.kw })), TYPES);
  const mHf = multiclassMetrics(rows.map((r) => ({ expected: r.expected, predicted: r.hfType })), TYPES);
  const mAll = multiclassMetrics(rows.map((r) => ({ expected: r.expected, predicted: r.pred })), TYPES);
  const bySource = {};
  rows.forEach((r) => { (bySource[r.source] = bySource[r.source] || []).push(r); });
  const wrong = rows.filter((r) => r.pred !== r.expected);

  const md = [
    '## Sugerencia de tipo de problema',
    `Muestras: ${rows.length} (${rows.length / TYPES.length} por categoría).`,
    '',
    mdTable(['Método', 'Exactitud', 'F1 macro'], [
      ['Solo palabras clave (sin resultado cuenta como error)', pct(mKw.accuracy), pct(mKw.macroF1)],
      ['Solo modelo zero-shot de Hugging Face', pct(mHf.accuracy), pct(mHf.macroF1)],
      ['Combinado (como en suggestProblemType)', pct(mAll.accuracy), pct(mAll.macroF1)],
    ]),
    '',
    '**Combinado: resultado por fuente de la decisión**',
    '',
    mdTable(['Fuente', 'Casos', 'Aciertos', 'Exactitud'], Object.entries(bySource).map(([k, v]) => {
      const ok = v.filter((r) => r.pred === r.expected).length;
      return [k, String(v.length), String(ok), pct(ok / v.length)];
    })),
    '',
    `El filtro de palabras clave resolvió ${(bySource['palabras clave'] || []).length} de ${rows.length} casos sin necesitar el modelo en la decisión final.`,
    '',
    '**Combinado: métricas por categoría**',
    '',
    mdTable(['Categoría', 'Precisión', 'Exhaustividad', 'F1'], mAll.perClass.map((c) => [c.label, pct(c.precision), pct(c.recall), pct(c.f1)])),
    '',
    '**Combinado: matriz de confusión**',
    '',
    confusionTable(mAll),
    '',
    '**Solo Hugging Face: matriz de confusión**',
    '',
    confusionTable(mHf),
    '',
    '**Errores del método combinado**',
    '',
    wrong.length
      ? mdTable(['ID', 'Texto', 'Real', 'Predicho', 'Fuente', 'Puntaje HF'], wrong.map((r) => [r.id, short(r.text), r.expected, String(r.pred), r.source, num(r.hfScore)]))
      : 'Sin errores.',
  ].join('\n');
  return { md, data: { rows, keywords: mKw, hf: mHf, combined: mAll } };
}

async function duplicatesHF(ds, pure) {
  const rows = [];
  for (const s of ds.duplicates) {
    const jac = pure.jaccardSimilarity(s.a, s.b);
    const r = await hfCall('similarity', { inputs: { source_sentence: s.a, sentences: [s.b] } });
    const cos = r.status === 200 && Array.isArray(r.data) && typeof r.data[0] === 'number' ? r.data[0] : null;
    rows.push({ id: s.id, a: s.a, b: s.b, expected: s.expected, jaccard: jac, cosine: cos });
    await sleep(DELAY);
  }
  const JT = pure.JACCARD_THRESHOLD;
  const CT = pure.COSINE_THRESHOLD;
  const hfAt = (th) => rows.map((r) => ({ expected: r.expected, predicted: r.cosine !== null && r.cosine >= th }));
  const hf = binaryMetrics(hfAt(CT));
  const pipeline = binaryMetrics(rows.map((r) => ({ expected: r.expected, predicted: r.jaccard >= JT && r.cosine !== null && r.cosine >= CT })));
  const jOnly = binaryMetrics(rows.map((r) => ({ expected: r.expected, predicted: r.jaccard >= JT })));
  const jFallback = binaryMetrics(rows.map((r) => ({ expected: r.expected, predicted: r.jaccard >= 0.45 })));
  const sweep = [0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9].map((th) => binaryRow(`HF solo, umbral ${th}`, binaryMetrics(hfAt(th))));

  const yes = rows.filter((r) => r.expected);
  const no = rows.filter((r) => !r.expected);
  const passPrefilter = yes.filter((r) => r.jaccard >= JT).length;
  const errs = rows.filter((r) => (r.jaccard >= JT && r.cosine !== null && r.cosine >= CT) !== r.expected);
  const valid = (v) => v.filter((x) => x !== null);

  const md = [
    '## Detección de reportes duplicados',
    `Pares: ${yes.length} duplicados y ${no.length} no duplicados. Umbral de Jaccard: ${JT}. Umbral de similitud semántica: ${CT}.`,
    '',
    mdTable(BIN_HEAD, [
      binaryRow(`Solo filtro Jaccard (≥ ${JT})`, jOnly),
      binaryRow('Solo Jaccard (≥ 0,45, respaldo sin IA)', jFallback),
      binaryRow(`Solo modelo de Hugging Face (≥ ${CT})`, hf),
      binaryRow('Combinado (como en checkDuplicateReport)', pipeline),
    ]),
    '',
    `Similitud semántica media: duplicados ${num(mean(valid(yes.map((r) => r.cosine))))} / no duplicados ${num(mean(valid(no.map((r) => r.cosine))))}.`,
    `Jaccard medio: duplicados ${num(mean(yes.map((r) => r.jaccard)))} / no duplicados ${num(mean(no.map((r) => r.jaccard)))}.`,
    `Duplicados reales que pasan el filtro Jaccard: ${passPrefilter} de ${yes.length}. Los demás no llegan nunca al modelo.`,
    '',
    '**Variación del umbral de similitud (solo Hugging Face)**',
    '',
    mdTable(BIN_HEAD, sweep),
    '',
    '**Errores del método combinado**',
    '',
    errs.length
      ? mdTable(['ID', 'Real', 'Texto A', 'Texto B', 'Jaccard', 'Similitud'], errs.map((r) => [r.id, r.expected ? 'duplicado' : 'distinto', short(r.a, 45), short(r.b, 45), num(r.jaccard), num(r.cosine)]))
      : 'Sin errores.',
  ].join('\n');
  return { md, data: { rows, jaccardOnly: jOnly, hf, pipeline } };
}

// modo functions
async function getIdToken() {
  if (process.env.ID_TOKEN) return process.env.ID_TOKEN;
  const { FIREBASE_API_KEY, TEST_EMAIL, TEST_PASSWORD } = process.env;
  if (!FIREBASE_API_KEY || !TEST_EMAIL || !TEST_PASSWORD) {
    throw new Error('Define ID_TOKEN, o bien FIREBASE_API_KEY, TEST_EMAIL y TEST_PASSWORD.');
  }
  const res = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: TEST_EMAIL, password: TEST_PASSWORD, returnSecureToken: true }),
  });
  const data = await res.json();
  if (!res.ok || !data.idToken) throw new Error(`No se pudo iniciar sesión (HTTP ${res.status}).`);
  return data.idToken;
}

async function authAndContractTests(token) {
  const good = { Authorization: `Bearer ${token}` };
  const cases = [
    ['Sin encabezado Authorization', {}, { title: '', description: 'texto de prueba' }, 401],
    ['Token inválido', { Authorization: 'Bearer token-falso' }, { title: '', description: 'texto de prueba' }, 401],
    ['Esquema distinto de Bearer', { Authorization: 'Basic abc' }, { title: '', description: 'texto de prueba' }, 401],
    ['Token válido y texto correcto', good, { title: '', description: 'Hay un bache en la calle principal' }, 200],
    ['Título que no es texto', good, { title: 123, description: 'texto de prueba' }, 400],
    ['Descripción de más de 3000 caracteres', good, { title: '', description: 'a'.repeat(3001) }, 400],
    ['Cuerpo que no es un objeto', good, '[1,2,3]', 400],
  ];
  const rows = [];
  for (const [name, headers, body, expected] of cases) {
    const r = await fnCall('checkOffensiveContent', body, headers);
    rows.push([name, String(expected), String(r.status), r.status === expected ? 'Aprobado' : 'No aprobado']);
    await sleep(DELAY);
  }
  const passed = rows.filter((r) => r[3] === 'Aprobado').length;
  const md = [
    '## Pruebas de autenticación y de validación en checkOffensiveContent',
    '',
    mdTable(['Comprobación', 'HTTP esperado', 'HTTP obtenido', 'Resultado'], rows),
    '',
    `Resultado: ${passed} de ${rows.length} comprobaciones según lo esperado.`,
  ].join('\n');
  return { md, data: { rows } };
}

async function offensiveFn(ds, token) {
  const rows = [];
  for (const s of ds.offensive) {
    const r = await fnCall('checkOffensiveContent', { title: '', description: s.text }, { Authorization: `Bearer ${token}` });
    const ok = r.status === 200 && r.data && typeof r.data.isOffensive === 'boolean';
    rows.push({ id: s.id, text: s.text, expected: s.expected, predicted: ok ? r.data.isOffensive : false, source: ok && r.data.source ? r.data.source : 'ninguna', status: r.status });
    await sleep(DELAY);
  }
  const m = binaryMetrics(rows);
  const src = {};
  rows.filter((r) => r.predicted).forEach((r) => { src[r.source] = (src[r.source] || 0) + 1; });
  const errs = rows.filter((r) => r.expected !== r.predicted);
  const md = [
    '## Lenguaje ofensivo (extremo a extremo, función desplegada)',
    '',
    mdTable(BIN_HEAD, [binaryRow('checkOffensiveContent', m)]),
    '',
    `Detecciones por fuente: ${Object.entries(src).map(([k, v]) => `${k}: ${v}`).join(', ') || 'ninguna'}.`,
    `Llamadas con error HTTP: ${rows.filter((r) => r.status !== 200).length}.`,
    '',
    errs.length ? mdTable(['Tipo', 'ID', 'Texto'], errs.map((r) => [r.expected ? 'Falso negativo' : 'Falso positivo', r.id, short(r.text)])) : 'Sin errores.',
  ].join('\n');
  return { md, data: { rows, metrics: m } };
}

async function typeFn(ds, token) {
  const rows = [];
  for (const s of ds.problemType) {
    const r = await fnCall('suggestProblemType', { title: '', description: s.text }, { Authorization: `Bearer ${token}` });
    const ok = r.status === 200 && r.data && r.data.suggestion;
    rows.push({ id: s.id, text: s.text, expected: s.expected, predicted: ok ? r.data.suggestion : null, confidence: ok ? r.data.confidence : 'sin respuesta', status: r.status });
    await sleep(DELAY);
  }
  const m = multiclassMetrics(rows, TYPES);
  const byConf = {};
  rows.forEach((r) => { (byConf[r.confidence] = byConf[r.confidence] || []).push(r); });
  const errs = rows.filter((r) => r.predicted !== r.expected);
  const md = [
    '## Sugerencia de tipo de problema (extremo a extremo, función desplegada)',
    '',
    mdTable(['Método', 'Exactitud', 'F1 macro'], [['suggestProblemType', pct(m.accuracy), pct(m.macroF1)]]),
    '',
    '**Exactitud según la confianza que informa la función**',
    '',
    mdTable(['Confianza', 'Casos', 'Aciertos', 'Exactitud'], Object.entries(byConf).map(([k, v]) => {
      const ok = v.filter((r) => r.predicted === r.expected).length;
      return [k, String(v.length), String(ok), pct(ok / v.length)];
    })),
    '',
    '**Matriz de confusión**',
    '',
    confusionTable(m),
    '',
    errs.length ? mdTable(['ID', 'Texto', 'Real', 'Predicho', 'Confianza'], errs.map((r) => [r.id, short(r.text), r.expected, String(r.predicted), r.confidence])) : 'Sin errores.',
  ].join('\n');
  return { md, data: { rows, metrics: m } };
}

// principal
async function main() {
  if (!['hf', 'functions'].includes(mode)) {
    console.error('Uso: node run_tests.js hf|functions [--only=offensive,type,duplicates] [--delay=250]');
    process.exit(1);
  }
  const ds = JSON.parse(fs.readFileSync(path.join(__dirname, 'dataset.json'), 'utf8'));
  const started = new Date();
  const sections = [];
  const results = {};

  if (mode === 'hf') {
    if (!process.env.HF_API_KEY) throw new Error('Define la variable HF_API_KEY con tu token de Hugging Face.');
    const pure = loadPureLogic();

    // Comprobación previa: si el token o los créditos no sirven, no tiene sentido seguir
    const probe = await hfCall('similarity', { inputs: { source_sentence: 'prueba', sentences: ['prueba'] } });
    calls.length = 0;
    if (probe.status !== 200) {
      const hint = {
        401: 'Token inválido o sin permisos.',
        402: 'Créditos agotados o sin créditos (revisa https://huggingface.co/settings/billing).',
        403: 'Token sin permiso para Inference Providers.',
        404: 'El modelo no está disponible en este proveedor.',
        0: 'No hubo conexión con el servicio.',
      }[probe.status] || 'Respuesta inesperada.';
      throw new Error(`Hugging Face respondió HTTP ${probe.status}. ${hint} ${probe.error || JSON.stringify(probe.data || '').slice(0, 160)}`);
    }

    if (ONLY.includes('offensive')) { const r = await offensiveHF(ds, pure); sections.push(r.md); results.offensive = r.data; }
    if (ONLY.includes('type')) { const r = await typeHF(ds, pure); sections.push(r.md); results.type = r.data; }
    if (ONLY.includes('duplicates')) { const r = await duplicatesHF(ds, pure); sections.push(r.md); results.duplicates = r.data; }
  } else {
    const token = await getIdToken();
    const a = await authAndContractTests(token);
    if (a.data.rows.every((r) => r[2] === '0')) {
      throw new Error(`No hubo conexión con las funciones en ${FUNCTIONS_BASE}. Revisa la dirección (FUNCTIONS_BASE_URL) y que estén desplegadas.`);
    }
    sections.push(a.md); results.contract = a.data;
    if (ONLY.includes('offensive')) { const r = await offensiveFn(ds, token); sections.push(r.md); results.offensive = r.data; }
    if (ONLY.includes('type')) { const r = await typeFn(ds, token); sections.push(r.md); results.type = r.data; }
    sections.push('_La detección de duplicados de extremo a extremo depende de los reportes guardados en Firestore; se comprueba con los casos TC-022 y TC-023 y, para el modelo solo, con el modo hf._');
  }

  const header = [
    `# Resultados de las pruebas de IA (modo ${mode})`,
    '',
    `Fecha: ${started.toISOString()} · Node ${process.version}`,
    mode === 'hf'
      ? `Modelos: ${Object.entries(MODELS).map(([k, v]) => `${k}: ${v}`).join('; ')}`
      : `Funciones: ${FUNCTIONS_BASE}`,
    `Muestras: ${ds.problemType.length} de tipo, ${ds.offensive.length} de lenguaje y ${ds.duplicates.length} pares de duplicados.`,
    '',
    '## Pruebas de API: estado y latencia',
    '',
    '__API_STATS__',
  ].join('\n');

  const summary = `${header.replace('__API_STATS__', apiStatsTable())}\n\n${sections.join('\n\n')}\n`;
  const stamp = started.toISOString().replace(/[:.]/g, '-');
  const dir = path.join(__dirname, 'results', `${mode}-${stamp}`);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'resumen.md'), summary, 'utf8');
  fs.writeFileSync(path.join(dir, 'resultados.json'), JSON.stringify({ mode, started, calls, results }, null, 2), 'utf8');
  console.log(summary);
  console.log(`\nArchivos guardados en: ${dir}`);
}

main().catch((e) => {
  console.error(`\nError: ${e.message}`);
  process.exit(1);
});