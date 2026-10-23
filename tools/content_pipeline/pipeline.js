#!/usr/bin/env node
// TAM content pipeline:  PDF  →  interactive lesson (whiteboard)  +  quiz questions
//
//   node pipeline.js status
//   node pipeline.js lesson <pdfId> [--dry]      summary PDF  → interactive_content + interactive_lessons
//   node pipeline.js quiz   <pdfId> [--dry]      any PDF      → quiz_bank (summary / old exam / worksheet)
//   node pipeline.js all [--force] [--audio]     everything that is missing (use --audio to also make the MP3s)
//
// Needs:  firebase login (once)   and   $env:GEMINI_API_KEY = "..."
'use strict';
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const L = require('./lib');
const P = require('./prompts');

const args = process.argv.slice(2);
const cmd = args[0];
const flags = new Set(args.filter((a) => a.startsWith('--')));
const pos = args.filter((a) => !a.startsWith('--')).slice(1);

const EXAM_TYPES = new Set(['exam_answer', 'worksheet', 'exam']);
const log = (...a) => console.log(...a);

// ── small utils ──────────────────────────────────────────────────────────────
const str = (v, max = 4000) => (typeof v === 'string' ? v.trim().slice(0, max) : '');
const plain = (s) => s.replace(/\[\[|\]\]/g, '');
const normAr = (s) =>
  s.toLowerCase().replace(/[\u064B-\u065F\u0670\u0640]/g, '').replace(/[أإآٱ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه')
    .replace(/[^\p{L}\p{N}\s]/gu, ' ').replace(/\s+/g, ' ').trim();
function hashInt(s) { let h = 2166136261; for (const c of s) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); } return h >>> 0; }
function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

async function contextOf(pdf) {
  const subjectId = pdf.subject_id || '';
  const sub = subjectId ? await L.fsGet(`subjects/${subjectId}`) : null;
  const gradeMatch = String(sub?.grade_id || subjectId).match(/grade_(\d+)/);
  return {
    subjectId,
    subjectName: sub?.name_ar || 'المادة',
    grade: gradeMatch ? Number(gradeMatch[1]) : null,
    country: P.countryFromSubjectId(subjectId),
    title: str(pdf.title_ar || pdf.name || '', 200) || 'درس',
  };
}

async function loadPdf(pdfId) {
  const rec = await L.fsGet(`pdfs/${pdfId}`);
  if (!rec) throw new Error(`pdfs/${pdfId} not found`);
  const url = L.pdfUrlOf(rec);
  if (!url) throw new Error('PDF record has no file_url');
  return { rec, buf: await L.fetchPdf(url) };
}

// ── lesson normalisation (mirrors functions/src/interactive.ts) ─────────────
function normSection(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const heading = str(raw.heading, 300);
  const content = str(raw.content, 1500);
  if (!heading && !content) return null;
  const type = raw.type === 'formula' || raw.type === 'example' ? raw.type : 'section';
  return { type, heading, content, narration: plain(str(raw.narration, 1800) || `${heading}. ${content}`) };
}
function normVersion(raw, forceNoHook) {
  const r = raw && typeof raw === 'object' ? raw : {};
  const h = r.hook && typeof r.hook === 'object' ? r.hook : {};
  const hookText = str(h.text, 1200);
  const hookAvail = !forceNoHook && h.available === true && hookText.length > 0;
  const sections = (Array.isArray(r.sections) ? r.sections : []).map(normSection).filter(Boolean);
  const z = typeof r.zubda === 'string' ? { text: r.zubda, narration: r.zubda } : r.zubda && typeof r.zubda === 'object' ? r.zubda : {};
  const zt = str(z.text, 800);
  return {
    hook: { available: hookAvail, text: hookAvail ? hookText : null, narration: hookAvail ? plain(str(h.narration, 1200) || hookText) : null },
    sections,
    zubda: { text: zt, narration: plain(str(z.narration, 1200) || zt) },
  };
}
function normalizeLesson(raw, ctx, pdfId) {
  const r = raw && typeof raw === 'object' ? raw : {};
  const v = r.versions && typeof r.versions === 'object' ? r.versions : {};
  const title = str(r.title, 200) || ctx.title;
  const kamila = normVersion(v.kamila, false);
  let mukhtasar = normVersion(v.mukhtasar, true);
  if (kamila.sections.length === 0) throw new Error('EMPTY_LESSON');
  if (mukhtasar.sections.length === 0) {
    mukhtasar = { hook: { available: false, text: null, narration: null }, sections: kamila.sections.filter((s) => s.type !== 'example').slice(0, 6), zubda: kamila.zubda };
  }
  const d = P.dialectOf(ctx.country);
  const pick = (arr, salt) => arr[hashInt(pdfId + salt) % arr.length];
  return {
    title,
    subject: str(r.subject, 100) || ctx.subjectName,
    common: {
      welcome: { narration: pick(d.welcome, 'w') },
      intro: { narration: pick(d.intro, 'i').replace('{title}', title) },
    },
    versions: { mukhtasar, kamila },
    polished: false,
    country: ctx.country,
  };
}

const wordCount = (s) => String(s).trim().split(/\s+/).filter(Boolean).length;
function lessonReport(c) {
  const rep = (name, v) => {
    const words = v.sections.reduce((a, s) => a + wordCount(s.narration), 0) + wordCount(v.zubda.narration) + (v.hook.available ? wordCount(v.hook.narration) : 0);
    return `${name}: ${v.sections.length} slides, ~${words} spoken words (~${Math.round(words / 2.2)}s)`;
  };
  return [rep('mukhtasar', c.versions.mukhtasar), rep('kamila', c.versions.kamila)].join(' | ');
}

// ── lesson ───────────────────────────────────────────────────────────────────
async function runLesson(pdfId) {
  const { rec, buf } = await loadPdf(pdfId);
  const ctx = await contextOf(rec);
  log(`▶ lesson ${pdfId} — "${ctx.title}" (${ctx.subjectName}, grade ${ctx.grade ?? '?'}, ${ctx.country})`);
  const raw = await L.geminiJson({
    prompt: P.lessonPrompt(ctx), pdf: buf, temperature: 0.7, maxOutputTokens: 60000,
  });
  const content = normalizeLesson(raw, ctx, pdfId);
  log('  ' + lessonReport(content));

  if (flags.has('--dry')) {
    const out = path.join(__dirname, `dry_lesson_${pdfId}.json`);
    fs.writeFileSync(out, JSON.stringify(content, null, 2), 'utf8');
    log(`  (dry run) saved → ${out}`);
    return content;
  }

  // Remove audio docs of the previous version of this lesson (they no longer match the text).
  const old = await L.fsGet(`interactive_content/${pdfId}`);
  if (old) {
    const refs = [];
    const walk = (o) => { if (o && typeof o === 'object') { if (typeof o.path === 'string' && o.path.startsWith('fs:interactive_audio/')) refs.push(o.path.slice(3)); Object.values(o).forEach(walk); } };
    walk(old);
    for (const r of new Set(refs)) { try { await L.fsDelete(r); } catch (_) {} }
    if (refs.length) log(`  removed ${new Set(refs).size} outdated audio clips`);
  }

  await L.fsSet(`interactive_content/${pdfId}`, content);
  const oldMeta = (await L.fsGet(`interactive_lessons/${pdfId}`)) || {};
  const est = (v) => Math.round((v.sections.reduce((a, s) => a + wordCount(s.narration), 0) + wordCount(v.zubda.narration)) / 2.2);
  await L.fsSet(`interactive_lessons/${pdfId}`, {
    pdf_id: pdfId, subject_id: ctx.subjectId, title_ar: ctx.title, country: ctx.country,
    status: oldMeta.status === 'ready' ? 'ready' : 'processing', error: null,
    slides_mukhtasar: content.versions.mukhtasar.sections.length,
    slides_kamila: content.versions.kamila.sections.length,
    duration_mukhtasar: est(content.versions.mukhtasar), duration_kamila: est(content.versions.kamila),
    audio_done: 0, audio_total: 0, audio_complete: false, updated: new Date().toISOString(),
  });
  log('  ✓ saved to Firestore  → now run:  node audio.js ' + pdfId);
  return content;
}

// ── quiz ─────────────────────────────────────────────────────────────────────
function cleanQuestions(list, source, seed) {
  const rand = rng(seed);
  const seen = new Set();
  const out = [];
  for (const q of Array.isArray(list) ? list : []) {
    const question = str(q?.question, 700);
    const options = (Array.isArray(q?.options) ? q.options : []).map((o) => str(String(o), 300));
    let ci = Number.isInteger(q?.correctIndex) ? q.correctIndex : parseInt(q?.correctIndex, 10);
    if (!question || options.length !== 4 || options.some((o) => !o) || new Set(options.map(normAr)).size !== 4) continue;
    if (!(ci >= 0 && ci <= 3)) continue;
    const key = normAr(question);
    if (seen.has(key)) continue;
    seen.add(key);
    // shuffle options (seeded) so the right answer is not biased to one slot
    const idx = [0, 1, 2, 3].sort(() => rand() - 0.5);
    const shuffled = idx.map((i) => options[i]);
    out.push({
      question,
      options: shuffled,
      correctIndex: idx.indexOf(ci),
      explanation: str(q?.explanation, 600),
      difficulty: ['easy', 'medium', 'hard'].includes(q?.difficulty) ? q.difficulty : 'medium',
      topic: str(q?.topic, 120),
      year: q?.year ? str(String(q.year), 10) : '',
      source,
    });
  }
  return out;
}

async function runQuiz(pdfId, slideHint) {
  const { rec, buf } = await loadPdf(pdfId);
  const ctx = await contextOf(rec);
  const type = rec.pdf_type || 'summary';
  const isExam = EXAM_TYPES.has(type);
  const source = isExam ? (type === 'worksheet' ? 'worksheet' : 'exam') : 'summary';
  log(`▶ quiz ${pdfId} — "${ctx.title}" [${source}]`);
  const count = Math.max(10, Math.min(25, Math.round((slideHint || 10) * 1.3)));
  const prompt = isExam
    ? P.quizFromExamPrompt({ ...ctx, kind: type })
    : P.quizFromSummaryPrompt({ ...ctx, count });
  const raw = await L.geminiJson({ prompt, pdf: buf, temperature: 0.4, maxOutputTokens: 40000 });
  const questions = cleanQuestions(raw.questions ?? raw, source, hashInt(pdfId));
  if (!questions.length) throw new Error('No valid questions produced');
  const by = questions.reduce((m, q) => ((m[q.difficulty] = (m[q.difficulty] || 0) + 1), m), {});
  log(`  ${questions.length} questions`, by);

  if (flags.has('--dry')) {
    const out = path.join(__dirname, `dry_quiz_${pdfId}.json`);
    fs.writeFileSync(out, JSON.stringify(questions, null, 2), 'utf8');
    log(`  (dry run) saved → ${out}`);
    return questions;
  }
  await L.fsSet(`quiz_bank/${pdfId}`, {
    pdf_id: pdfId, subject_id: ctx.subjectId, grade: ctx.grade ?? 0, source, title_ar: ctx.title,
    count: questions.length, questions, updated: new Date().toISOString(),
  });
  log('  ✓ saved to quiz_bank');
  return questions;
}

// ── status / all ─────────────────────────────────────────────────────────────
async function status() {
  const [pdfs, lessons, banks] = await Promise.all([L.fsList('pdfs'), L.fsList('interactive_lessons'), L.fsList('quiz_bank')]);
  const lm = Object.fromEntries(lessons.map((m) => [m.id, m]));
  const bm = Object.fromEntries(banks.map((b) => [b.id, b]));
  log(`PDFs: ${pdfs.length}`);
  for (const p of pdfs) {
    const isExam = EXAM_TYPES.has(p.pdf_type);
    const m = lm[p.id];
    const lesson = isExam ? '—' : m ? `${m.status}${m.audio_complete ? ' +audio' : ' (no/partial audio)'}` : 'MISSING';
    const quiz = bm[p.id] ? `${bm[p.id].count} q` : 'MISSING';
    log(` ${p.id}  ${String(p.pdf_type || '?').padEnd(11)} ${String(p.title_ar || '').slice(0, 24).padEnd(24)} lesson: ${lesson.padEnd(26)} quiz: ${quiz}`);
  }
}

async function all() {
  const pdfs = (await L.fsList('pdfs')).filter((p) => p.is_active !== false && L.pdfUrlOf(p));
  const lessons = Object.fromEntries((await L.fsList('interactive_lessons')).map((m) => [m.id, m]));
  const banks = new Set((await L.fsList('quiz_bank')).map((b) => b.id));
  const force = flags.has('--force');
  for (const p of pdfs) {
    try {
      const isExam = EXAM_TYPES.has(p.pdf_type);
      let slides = 10;
      if (!isExam && (force || !lessons[p.id])) {
        const c = await runLesson(p.id);
        slides = c.versions.kamila.sections.length;
        if (flags.has('--audio')) spawnSync(process.execPath, [path.join(__dirname, 'audio.js'), p.id], { stdio: 'inherit' });
      } else if (lessons[p.id]) slides = lessons[p.id].slides_kamila || 10;
      if (force || !banks.has(p.id)) await runQuiz(p.id, slides);
    } catch (e) {
      console.error(`✗ ${p.id}: ${e.message}`);
    }
  }
  log('done.');
}

(async () => {
  if (cmd === 'status') return status();
  if (cmd === 'lesson' && pos[0]) return runLesson(pos[0]);
  if (cmd === 'quiz' && pos[0]) return runQuiz(pos[0]);
  if (cmd === 'all') return all();
  log('Usage: node pipeline.js status | lesson <pdfId> [--dry] | quiz <pdfId> [--dry] | all [--force] [--audio]');
})().catch((e) => { console.error('ERROR', e.message); process.exit(1); });
