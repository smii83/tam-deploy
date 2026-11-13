import http from "k6/http";
import exec from "k6/execution";
import { check, group, sleep } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

// Endpoint latency trends
const hostingTrend = new Trend("tam_hosting_ms", true);
const firestoreTrend = new Trend("tam_firestore_ms", true);
const functionsTrend = new Trend("tam_functions_ms", true);

// Non-overlapping load-tier trends (exact active VUs per scenario)
const tier10All = new Trend("tam_tier_010_vus_ms", true);
const tier40All = new Trend("tam_tier_040_vus_ms", true);
const tier100All = new Trend("tam_tier_100_vus_ms", true);
const tier180All = new Trend("tam_tier_180_vus_ms", true);

const tier10Fn = new Trend("tam_fn_010_vus_ms", true);
const tier40Fn = new Trend("tam_fn_040_vus_ms", true);
const tier100Fn = new Trend("tam_fn_100_vus_ms", true);
const tier180Fn = new Trend("tam_fn_180_vus_ms", true);

const errRate = new Rate("tam_error_rate");
const reqCount = new Counter("tam_total_requests");

const HOSTING_BASE = __ENV.HOSTING_BASE || "http://127.0.0.1:5000";
const FIRESTORE_BASE = __ENV.FIRESTORE_BASE || "http://127.0.0.1:8080/v1/projects/tam-app-fd30f/databases/(default)/documents";
const FUNCTIONS_BASE = __ENV.FUNCTIONS_BASE || "http://127.0.0.1:5001/tam-app-fd30f/me-central1";
const ID_TOKENS = (__ENV.ID_TOKENS || "").split(",").filter(Boolean);
const IS_CI = __ENV.K6_CI_MODE === "1";

export const options = IS_CI
  ? {
      scenarios: {
        tier_10_vus: { executor: "constant-vus", vus: 10, duration: "10s", gracefulStop: "2s" },
      },
      thresholds: {
        tam_error_rate: ["rate<0.05"],
        tam_hosting_ms: ["p(95)<1000"],
        tam_firestore_ms: ["p(95)<1500"],
        tam_functions_ms: ["p(95)<2500"],
      },
    }
  : {
      scenarios: {
        tier_10_vus: { executor: "constant-vus", vus: 10, duration: "6s", startTime: "0s", gracefulStop: "2s" },
        tier_40_vus: { executor: "constant-vus", vus: 40, duration: "7s", startTime: "9s", gracefulStop: "2s" },
        tier_100_vus: { executor: "constant-vus", vus: 100, duration: "8s", startTime: "19s", gracefulStop: "3s" },
        tier_180_vus: { executor: "constant-vus", vus: 180, duration: "8s", startTime: "30s", gracefulStop: "3s" },
      },
      thresholds: {
        // Strict SLA at healthy/moderate concurrency + <5% error rate across saturation tiers
        tam_error_rate: ["rate<0.05"],
        tam_firestore_ms: ["p(95)<2500"],
        tam_tier_010_vus_ms: ["med<300", "p(90)<1000"],
        tam_tier_040_vus_ms: ["p(95)<2000"],
      },
    };

export function setup() {
  // Warm up Firebase Hosting & parallel Cloud Functions worker pool so cold-start doesn't skew 10-VU metrics
  http.get(`${HOSTING_BASE}/`);
  if (ID_TOKENS.length) {
    http.get(`${FIRESTORE_BASE}/subjects?pageSize=5`, {
      headers: { Authorization: `Bearer ${ID_TOKENS[0]}` },
    });
    const warmupStart = Date.now();
    const fnBody = JSON.stringify({
      data: {
        pdfId: "perf_pdf_1",
        heading: "قانون [[نيوتن]] الأول",
        content: "يظل الجسم ساكناً أو متحركاً بسرعة ثابتة",
        question: "ما نص القانون؟",
        country: "kw",
      },
    });
    const batchReqs = Array.from({ length: 4 }, (_, i) => ({
      method: "POST",
      url: `${FUNCTIONS_BASE}/lessonAsk`,
      body: fnBody,
      params: {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${ID_TOKENS[i % ID_TOKENS.length]}`,
        },
      },
    }));
    http.batch(batchReqs);
    return { coldStartMs: Date.now() - warmupStart };
  }
  return { coldStartMs: 0 };
}

function recordTier(ms, isFn = false) {
  const name = exec.scenario.name;
  if (name === "tier_10_vus") {
    tier10All.add(ms);
    if (isFn) tier10Fn.add(ms);
  } else if (name === "tier_40_vus") {
    tier40All.add(ms);
    if (isFn) tier40Fn.add(ms);
  } else if (name === "tier_100_vus") {
    tier100All.add(ms);
    if (isFn) tier100Fn.add(ms);
  } else if (name === "tier_180_vus") {
    tier180All.add(ms);
    if (isFn) tier180Fn.add(ms);
  }
}

export default function () {
  const token = ID_TOKENS.length ? ID_TOKENS[(__VU - 1) % ID_TOKENS.length] : "";

  group("Hosting Pages", () => {
    const resHome = http.get(`${HOSTING_BASE}/`, { tags: { endpoint: "hosting_home" } });
    hostingTrend.add(resHome.timings.duration);
    recordTier(resHome.timings.duration);
    reqCount.add(1);
    const okHome = check(resHome, { "hosting / status 200": (r) => r.status === 200 });
    errRate.add(!okHome);

    const resPrivacy = http.get(`${HOSTING_BASE}/privacy.html`, { tags: { endpoint: "hosting_privacy" } });
    hostingTrend.add(resPrivacy.timings.duration);
    recordTier(resPrivacy.timings.duration);
    reqCount.add(1);
    const okPriv = check(resPrivacy, { "privacy.html status 200": (r) => r.status === 200 });
    errRate.add(!okPriv);
  });

  if (token) {
    group("Firestore Read API", () => {
      const resFs = http.get(`${FIRESTORE_BASE}/subjects?pageSize=20`, {
        headers: { Authorization: `Bearer ${token}` },
        tags: { endpoint: "firestore_subjects" },
      });
      firestoreTrend.add(resFs.timings.duration);
      recordTier(resFs.timings.duration);
      reqCount.add(1);
      const okFs = check(resFs, { "firestore subjects 200": (r) => r.status === 200 });
      errRate.add(!okFs);
    });

    group("Cloud Function lessonAsk (cached)", () => {
      const payload = JSON.stringify({
        data: {
          pdfId: "perf_pdf_1",
          heading: "قانون [[نيوتن]] الأول",
          content: "يظل الجسم ساكناً أو متحركاً بسرعة ثابتة",
          question: "ما نص القانون؟",
          country: "kw",
        },
      });
      const resFn = http.post(`${FUNCTIONS_BASE}/lessonAsk`, payload, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        tags: { endpoint: "fn_lessonAsk" },
      });
      functionsTrend.add(resFn.timings.duration);
      recordTier(resFn.timings.duration, true);
      reqCount.add(1);
      const okFn = check(resFn, {
        "lessonAsk 200 & cached": (r) => {
          if (r.status !== 200) return false;
          try {
            return r.json("result.cached") === true;
          } catch (_) {
            return false;
          }
        },
      });
      errRate.add(!okFn);
    });
  }

  sleep(0.05);
}

export function handleSummary(data) {
  return {
    "tests/perf/results/summary.json": JSON.stringify(data, null, 2),
  };
}
