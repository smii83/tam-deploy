// Shared helpers for the TAM content pipeline (no secrets in this file).
//
//  • Firestore access goes through the REST API using the access token of the
//    already-logged-in Firebase CLI (`firebase login`) — no service account.
//  • Gemini needs GEMINI_API_KEY in the environment:
//        $env:GEMINI_API_KEY = "<your key>"      (PowerShell)
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const PROJECT = process.env.TAM_PROJECT || 'tam-app-fd30f';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const CFG = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── Firebase CLI token (auto-refreshed by running any CLI command) ────────────
function readToken() {
  const cfg = JSON.parse(fs.readFileSync(CFG, 'utf8'));
  return cfg.tokens || {};
}
function accessToken() {
  let t = readToken();
  if (!t.access_token || (t.expires_at && t.expires_at < Date.now() + 60_000)) {
    try {
      // Any authenticated CLI call makes firebase-tools refresh the token.
      execSync(`${process.platform === 'win32' ? 'firebase.cmd' : 'firebase'} projects:list --json`, { stdio: 'ignore' });
    } catch (_) { /* ignore, re-read below */ }
    t = readToken();
  }
  if (!t.access_token) throw new Error('Not logged in. Run: firebase login');
  return t.access_token;
}

// ── Firestore value conversion ────────────────────────────────────────────────
function fromFs(v) {
  if (!v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(fromFs);
  if ('mapValue' in v) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, fromFs(x)]));
  return null;
}
function toFs(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'string') return { stringValue: val };
  if (typeof val === 'number') return Number.isInteger(val) ? { integerValue: String(val) } : { doubleValue: val };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (Array.isArray(val)) return { arrayValue: { values: val.map(toFs) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(val).map(([k, v]) => [k, toFs(v)])) } };
}
const docToObj = (d) => ({ id: d.name.split('/').pop(), ...Object.fromEntries(Object.entries(d.fields || {}).map(([k, v]) => [k, fromFs(v)])) });

async function fsReq(method, url, body) {
  const r = await fetch(url, {
    method,
    headers: { Authorization: 'Bearer ' + accessToken(), 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!r.ok) throw new Error(`${method} ${url.replace(BASE, '')} → ${r.status} ${(await r.text()).slice(0, 200)}`);
  return r.status === 204 ? null : r.json();
}

async function fsGet(p) {
  try { return docToObj(await fsReq('GET', `${BASE}/${p}`)); } catch (e) { if (String(e).includes('→ 404')) return null; throw e; }
}
async function fsSet(p, obj) {
  const fields = Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, toFs(v)]));
  await fsReq('PATCH', `${BASE}/${p}`, { fields });
}
async function fsDelete(p) { await fsReq('DELETE', `${BASE}/${p}`); }
async function fsList(collection) {
  const out = [];
  let pageToken = '';
  do {
    const j = await fsReq('GET', `${BASE}/${collection}?pageSize=300${pageToken ? '&pageToken=' + encodeURIComponent(pageToken) : ''}`);
    (j.documents || []).forEach((d) => out.push(docToObj(d)));
    pageToken = j.nextPageToken || '';
  } while (pageToken);
  return out;
}

// ── PDF download (handles Google Drive share links) ──────────────────────────
function normalizePdfUrl(url) {
  const m = url.match(/drive\.google\.com\/file\/d\/([^/]+)/) || url.match(/[?&]id=([^&]+)/);
  if (url.includes('drive.google.com') && m) return `https://drive.google.com/uc?export=download&id=${m[1]}`;
  return url;
}
async function fetchPdf(url) {
  const r = await fetch(normalizePdfUrl(url), { redirect: 'follow' });
  if (!r.ok) throw new Error(`PDF download failed ${r.status}`);
  const buf = Buffer.from(await r.arrayBuffer());
  if (buf.slice(0, 4).toString() !== '%PDF') throw new Error('Downloaded file is not a PDF (private/expired link?)');
  if (buf.length > 18 * 1024 * 1024) throw new Error('PDF larger than 18MB (Gemini inline limit)');
  return buf;
}
const pdfUrlOf = (rec) => rec.file_url || rec.file_data || rec.file || '';

// ── Gemini ────────────────────────────────────────────────────────────────────
function apiKey() {
  const k = process.env.GEMINI_API_KEY;
  if (!k) throw new Error('Set GEMINI_API_KEY first, e.g.  $env:GEMINI_API_KEY="..."');
  return k;
}
const TEXT_MODELS = ['gemini-2.5-flash', 'gemini-flash-latest', 'gemini-2.0-flash'];

async function geminiJson({ prompt, pdf, temperature = 0.6, maxOutputTokens = 32768 }) {
  const parts = [{ text: prompt }];
  if (pdf) parts.push({ inline_data: { mime_type: 'application/pdf', data: pdf.toString('base64') } });
  let last = '';
  for (const model of TEXT_MODELS) {
    for (let a = 0; a < 3; a++) {
      try {
        const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey() },
          body: JSON.stringify({
            contents: [{ parts }],
            generationConfig: { responseMimeType: 'application/json', temperature, maxOutputTokens },
          }),
        });
        if (r.status === 429 || r.status >= 500) { last = `${model} HTTP ${r.status}`; await sleep(5000 * (a + 1)); continue; }
        if (!r.ok) { last = `${model} HTTP ${r.status} ${(await r.text()).slice(0, 200)}`; break; }
        const j = await r.json();
        const text = (j.candidates?.[0]?.content?.parts || []).filter((p) => !p.thought).map((p) => p.text || '').join('');
        const m = text.match(/[\[{][\s\S]*[\]}]/);
        if (!m) { last = `${model} returned no JSON`; continue; }
        return JSON.parse(m[0]);
      } catch (e) { last = `${model}: ${e.message}`; await sleep(2000); }
    }
  }
  throw new Error('GEMINI_FAILED: ' + last);
}

module.exports = {
  PROJECT, sleep, fsGet, fsSet, fsDelete, fsList, fetchPdf, pdfUrlOf, geminiJson, normalizePdfUrl,
};
