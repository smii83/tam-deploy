#!/usr/bin/env node
/**
 * Seeds isolated Auth + Firestore emulator data, runs Grafana k6 load test
 * against local Hosting + Firestore + Cloud Functions emulators, and prints
 * itemized percentile & load-tier bottleneck metrics.
 */
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import admin from "firebase-admin";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "../..");
const resultsDir = path.join(__dirname, "results");
fs.mkdirSync(resultsDir, { recursive: true });

const PROJECT_ID = "tam-app-fd30f";
const AUTH_URL = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

function sha1(s) {
  return crypto.createHash("sha1").update(s).digest("hex");
}

function normalizeAr(s) {
  return s
    .toLowerCase()
    .replace(/[\u064B-\u065F\u0670\u0640]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function resolveK6Binary() {
  if (process.env.K6_BIN && fs.existsSync(process.env.K6_BIN)) return process.env.K6_BIN;
  const winDefault = "C:\\Program Files\\k6\\k6.exe";
  if (process.platform === "win32" && fs.existsSync(winDefault)) return winDefault;
  return "k6";
}

async function seedPerfFixtures() {
  const tokens = [];
  const uids = [];
  const stamp = Date.now();
  const poolSize = 15;

  for (let i = 0; i < poolSize; i++) {
    const email = `perf_stu_${stamp}_${i}@test.com`;
    const res = await fetch(`${AUTH_URL}/accounts:signUp?key=fake-api-key`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password: "PerfPass!123", returnSecureToken: true }),
    });
    if (!res.ok) throw new Error(`Auth seed failed: ${await res.text()}`);
    const body = await res.json();
    tokens.push(body.idToken);
    uids.push(body.localId);

    await db.collection("users").doc(body.localId).set({
      firebase_uid: body.localId,
      name: `طالب أداء ${i}`,
      email,
      grade: 12,
      section: "scientific",
      country: "kw",
      is_subscribed: true,
      is_blocked: false,
    });
  }

  for (let i = 0; i < 10; i++) {
    await db.collection("subjects").doc(`perf_sub_${i}`).set({
      name_ar: `مادة اختبار ${i}`,
      name_en: `Perf Subject ${i}`,
      grade: 12,
      is_visible: true,
    });
  }

  const pdfId = "perf_pdf_1";
  const heading = "قانون [[نيوتن]] الأول";
  const content = "يظل الجسم ساكناً أو متحركاً بسرعة ثابتة";
  const question = "ما نص القانون؟";
  const slideKey = sha1(normalizeAr(`${heading} ${content}`)).slice(0, 12);
  const cacheKey = sha1(`${pdfId}|${slideKey}|${normalizeAr(question)}`);

  await db.collection("lesson_qa_cache").doc(cacheKey).set({
    pdf_id: pdfId,
    slide_key: slideKey,
    question,
    answer: "الجسم يبقى على حالته الحركية ما لم تؤثر عليه قوة خارجية.",
    hits: 0,
  });

  return { tokens, uids, cacheKey };
}

async function cleanup(uids, cacheKey) {
  for (const uid of uids) {
    await admin.auth().deleteUser(uid).catch(() => undefined);
    await db.collection("users").doc(uid).delete().catch(() => undefined);
  }
  for (let i = 0; i < 10; i++) {
    await db.collection("subjects").doc(`perf_sub_${i}`).delete().catch(() => undefined);
  }
  await db.collection("lesson_qa_cache").doc(cacheKey).delete().catch(() => undefined);
}

const { tokens, uids, cacheKey } = await seedPerfFixtures();
let exitCode = 1;

try {
  const k6Bin = resolveK6Binary();
  const res = spawnSync(k6Bin, ["run", path.join(__dirname, "load_test.js")], {
    cwd: root,
    stdio: "inherit",
    env: {
      ...process.env,
      ID_TOKENS: tokens.join(","),
    },
  });
  exitCode = res.status ?? 1;

  const summaryPath = path.join(resultsDir, "summary.json");
  if (fs.existsSync(summaryPath)) {
    const summary = JSON.parse(fs.readFileSync(summaryPath, "utf8"));
    const m = summary.metrics || {};
    console.log("\n=== TAM k6 Performance Breakdown ===");
    for (const key of [
      "tam_hosting_ms",
      "tam_firestore_ms",
      "tam_functions_ms",
      "tam_tier_010_vus_ms",
      "tam_tier_040_vus_ms",
      "tam_tier_100_vus_ms",
      "tam_tier_180_vus_ms",
      "tam_fn_010_vus_ms",
      "tam_fn_040_vus_ms",
      "tam_fn_100_vus_ms",
      "tam_fn_180_vus_ms",
    ]) {
      const vals = m[key]?.values;
      if (vals) {
        console.log(
          `${key.padEnd(24)} min=${vals.min?.toFixed(1)}ms  avg=${vals.avg?.toFixed(1)}ms  med=${vals.med?.toFixed(1)}ms  p95=${vals["p(95)"]?.toFixed(1)}ms  max=${vals.max?.toFixed(1)}ms`
        );
      }
    }
    if (m.tam_error_rate?.values) {
      console.log(`tam_error_rate           rate=${(m.tam_error_rate.values.rate * 100).toFixed(2)}%`);
    }
    if (m.http_reqs?.values) {
      console.log(`http_reqs                total=${m.http_reqs.values.count} rate=${m.http_reqs.values.rate?.toFixed(1)}/s`);
    }
  }
} finally {
  await cleanup(uids, cacheKey);
}

process.exit(exitCode);
