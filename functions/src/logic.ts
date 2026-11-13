import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { HttpsError } from "firebase-functions/v2/https";

// ── Rate Limiting & Model Constants ──────────────────────────────────────────
export const RATE_LIMITS = {
  chat: { maxPerHour: 30 },
  image: { maxPerHour: 15 },
};

export const MODEL_CANDIDATES = [
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-1.5-flash",
];

// ── Apple Receipt Constants & Product Map ────────────────────────────────────
export const APPLE_PROD_URL = "https://buy.itunes.apple.com/verifyReceipt";
export const APPLE_SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

export const PRODUCT_DURATIONS: Record<string, number> = {
  "tam_1month": 30,
  "tam_3months": 90,
  "tam_6months": 180,
  "tam_6months_12kwd": 180,
  "tam_1year": 365,
};

export const VALID_TX_ID_PATTERN = /^[A-Za-z0-9._-]{1,128}$/;

export interface AppleValidation {
  expiresMs: number;
  originalTransactionId: string;
  transactionIds: string[];
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type AppleReceiptEntry = Record<string, any>;

export type AppleVerifyCaller = (
  url: string,
  receiptData: string,
  sharedSecret: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
) => Promise<Record<string, any>>;

/** Enforce per-user hourly Firestore-backed rate limits. */
export async function checkRateLimitWithDb(
  db: admin.firestore.Firestore,
  uid: string,
  type: "chat" | "image",
  nowMs: number = Date.now()
): Promise<void> {
  const ref = db.collection("rate_limits").doc(uid);
  const chatKey = "chat_count";
  const imageKey = "image_count";
  const resetKey = "reset_at";

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const resetAt = data[resetKey] ?? 0;

    if (nowMs > resetAt) {
      tx.set(ref, {
        [chatKey]: type === "chat" ? 1 : 0,
        [imageKey]: type === "image" ? 1 : 0,
        [resetKey]: nowMs + 3_600_000,
      });
      return;
    }

    const countKey = type === "image" ? imageKey : chatKey;
    const max = type === "image" ? RATE_LIMITS.image.maxPerHour : RATE_LIMITS.chat.maxPerHour;
    const current = (data[countKey] ?? 0) as number;

    if (current >= max) {
      throw new HttpsError(
        "resource-exhausted",
        `لقد تجاوزت الحد المسموح (${max} طلب/ساعة). يرجى المحاولة لاحقاً 🕐`
      );
    }
    tx.update(ref, { [countKey]: current + 1 });
  });
}

/** Try Gemini models sequentially with backoff on HTTP 429 rate-limit responses. */
export async function tryModelsWithDelay(
  buildParts: (modelName: string) => Promise<string>,
  delayFn: (ms: number) => Promise<void> = (ms) => new Promise((r) => setTimeout(r, ms))
): Promise<string> {
  let lastError = "";
  for (const modelName of MODEL_CANDIDATES) {
    try {
      const result = await buildParts(modelName);
      if (result.trim()) return result;
    } catch (e: unknown) {
      lastError = e instanceof Error ? e.message : String(e);
      if (lastError.includes("429")) {
        await delayFn(2000);
        continue;
      }
    }
  }
  throw new HttpsError("unavailable", "تعذّر الاتصال بخدمة الذكاء الاصطناعي. يرجى المحاولة لاحقاً.");
}

/** Call Apple verifyReceipt endpoint directly. */
export async function callAppleVerify(
  url: string,
  receiptData: string,
  sharedSecret: string
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
): Promise<Record<string, any>> {
  let res: Response;
  try {
    res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        "receipt-data": receiptData,
        "password": sharedSecret,
        "exclude-old-transactions": true,
      }),
      signal: AbortSignal.timeout(15_000),
    });
  } catch (e) {
    console.error("Apple verifyReceipt network error", e);
    throw new HttpsError("unavailable", "تعذّر الاتصال بخادم Apple للتحقق من الاشتراك. يرجى المحاولة مجدداً.");
  }
  if (!res.ok) {
    console.error(`Apple verifyReceipt HTTP ${res.status}`);
    throw new HttpsError("unavailable", "خادم Apple غير متاح حالياً. يرجى المحاولة مجدداً.");
  }
  try {
    return await res.json();
  } catch (e) {
    console.error("Apple verifyReceipt invalid JSON", e);
    throw new HttpsError("unavailable", "استجابة غير صالحة من خادم Apple. يرجى المحاولة مجدداً.");
  }
}

/** Validate an Apple receipt against prod then sandbox (on 21007). */
export async function validateAppleReceiptWithVerify(
  receiptData: string,
  sharedSecret: string,
  productId: string,
  verifyFn: AppleVerifyCaller = callAppleVerify,
  nowMs: number = Date.now()
): Promise<AppleValidation> {
  let body = await verifyFn(APPLE_PROD_URL, receiptData, sharedSecret);
  if (body.status === 21007) {
    body = await verifyFn(APPLE_SANDBOX_URL, receiptData, sharedSecret);
  }

  const status = body.status as number;
  if (status !== 0) {
    if (status === 21005 || (status >= 21100 && status <= 21199)) {
      console.error(`Apple verifyReceipt temporary status ${status}`);
      throw new HttpsError("unavailable", "خادم Apple مشغول حالياً. يرجى المحاولة مجدداً.");
    }
    if (status === 21004) {
      console.error("Apple verifyReceipt status 21004: APPLE_SHARED_SECRET is wrong");
      throw new HttpsError("internal", "تعذّر التحقق من الاشتراك حالياً. يرجى التواصل مع الدعم.");
    }
    console.warn(`Apple verifyReceipt rejected receipt, status ${status}`);
    throw new HttpsError("permission-denied", "الاشتراك منتهي أو غير صالح.");
  }

  const rawEntries: AppleReceiptEntry[] =
    Array.isArray(body.latest_receipt_info) && body.latest_receipt_info.length > 0 ?
      body.latest_receipt_info :
      (Array.isArray(body.receipt?.in_app) ? body.receipt.in_app : []);
  const entries = rawEntries.filter((e) => e.product_id === productId);
  if (entries.length === 0) {
    throw new HttpsError("permission-denied", "الاشتراك منتهي أو غير صالح.");
  }

  const expiry = (e: AppleReceiptEntry): number => {
    const n = Number(e.expires_date_ms);
    return Number.isFinite(n) ? n : 0;
  };
  const latest = entries.reduce((a, b) => (expiry(b) > expiry(a) ? b : a));
  if (expiry(latest) <= nowMs) {
    throw new HttpsError("permission-denied", "الاشتراك منتهي أو غير صالح.");
  }

  return {
    expiresMs: expiry(latest),
    originalTransactionId: String(latest.original_transaction_id ?? ""),
    transactionIds: entries.flatMap((e) => [
      String(e.transaction_id ?? ""),
      String(e.original_transaction_id ?? ""),
    ]).filter((s) => s.length > 0),
  };
}

/** Validate transactionId + productId and compute subscription window. */
export function computeSubscriptionWindow(
  productId: string,
  apple: AppleValidation | null,
  transactionDateMs?: unknown,
  nowMs: number = Date.now()
): { durationDays: number; effectiveDays: number; startMs: number; expiresMs: number } {
  const durationDays = PRODUCT_DURATIONS[productId];
  if (!durationDays) {
    throw new HttpsError("invalid-argument", `معرّف المنتج غير معروف: ${productId}`);
  }

  const DAY_MS = 86_400_000;
  let startMs = nowMs;
  let expiresMs = nowMs + durationDays * DAY_MS;
  let effectiveDays = durationDays;

  if (!apple) {
    const tdMs = Number(transactionDateMs);
    if (
      transactionDateMs !== undefined &&
      transactionDateMs !== null &&
      Number.isFinite(tdMs) &&
      tdMs <= nowMs + 5 * 60_000 &&
      tdMs >= nowMs - 400 * DAY_MS
    ) {
      startMs = Math.min(tdMs, nowMs);
      expiresMs = startMs + durationDays * DAY_MS;
      if (expiresMs <= nowMs) {
        throw new HttpsError("failed-precondition", "الاشتراك منتهي.");
      }
      effectiveDays = Math.max(1, Math.ceil((expiresMs - nowMs) / DAY_MS));
    }
  } else {
    expiresMs = Math.min(apple.expiresMs, nowMs + (durationDays + 7) * DAY_MS);
    effectiveDays = Math.max(1, Math.ceil((expiresMs - nowMs) / DAY_MS));
  }

  return { durationDays, effectiveDays, startMs, expiresMs };
}

// ═════════════════════════════════════════════════════════════════════════════
// Interactive Lesson Pure Logic (shared with interactive.ts)
// ═════════════════════════════════════════════════════════════════════════════
export interface AudioRef {
  path: string;
  duration: number;
}
export interface Section {
  type: "section" | "formula" | "example";
  heading: string;
  content: string;
  narration: string;
  audio?: AudioRef | null;
}
export interface Hook {
  available: boolean;
  text: string | null;
  narration: string | null;
  audio?: AudioRef | null;
}
export interface Zubda {
  text: string;
  narration: string;
  audio?: AudioRef | null;
}
export interface Version {
  hook: Hook;
  sections: Section[];
  zubda: Zubda;
}
export interface LessonContent {
  title: string;
  subject: string;
  common: {
    welcome: { narration: string; audio?: AudioRef | null };
    intro: { narration: string; audio?: AudioRef | null };
  };
  versions: { mukhtasar: Version; kamila: Version };
  voice?: string;
}
export type Segment = { narration?: string | null; audio?: AudioRef | null };

export function sha1(s: string): string {
  return crypto.createHash("sha1").update(s).digest("hex");
}

export function str(v: unknown, max = 4000): string {
  return typeof v === "string" ? v.trim().slice(0, max) : "";
}

/** Strip [[concept]] markers so they are not spoken/hashed. */
export function plain(s: string): string {
  return s.replace(/\[\[|\]\]/g, "");
}

/** Normalise Arabic text for cache keys. */
export function normalizeAr(s: string): string {
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

export function dialectFor(country: string): string {
  switch (country) {
    case "sa": return "لهجة سعودية خليجية أصيلة";
    case "ae": return "لهجة إماراتية خليجية أصيلة";
    default: return "لهجة كويتية خليجية أصيلة";
  }
}

export function teacherPersonality(country: string): string {
  return `أنت مدرس خليجي محترف بشوش يعطي درساً خصوصياً لطالب كأنك جالس في البيت.
- تحكي بـ${dialectFor(country)} مريح وطبيعي، مو بأسلوب رسمي.
- تبدأ كل فكرة جديدة بعبارة تشويقية مثل: "اسمع كيف"، "الحين خل أوضح"، "هذي هي الحلوة"، "والله سؤال وايد مهم".
- تضرب أمثلة من الحياة اليومية الخليجية.
- ترحب بالطالب ويحس إنك مهتم فيه شخصياً.
- ما تحشو الكلام ولا تكرر نفس الجملة.
- كلامك يُقرأ بصوت عالٍ، فاكتب كلاماً عادياً بدون نقاط مرقّمة ولا ماركداون ولا رموز أو إيموجي.
- اكتب المعادلات والأرقام والرموز العلمية بالكلمات (مثل: إكس تربيع، جذر اثنين، باي).`;
}

export function normSection(raw: unknown): Section | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const heading = str(r.heading, 300);
  const content = str(r.content, 1500);
  if (!heading && !content) return null;
  const type = r.type === "formula" || r.type === "example" ? r.type : "section";
  const narration = str(r.narration, 1200) || plain(`${heading}. ${content}`);
  return { type, heading, content, narration: plain(narration) };
}

export function normVersion(raw: unknown, forceNoHook: boolean): Version {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const hookRaw = (r.hook && typeof r.hook === "object" ? r.hook : {}) as Record<string, unknown>;
  const hookText = str(hookRaw.text, 1200);
  const hookAvail = !forceNoHook && hookRaw.available === true && hookText.length > 0;
  const sections = (Array.isArray(r.sections) ? r.sections : [])
    .map(normSection)
    .filter((s): s is Section => s !== null);
  const zRaw = r.zubda;
  let zubda: Zubda;
  if (typeof zRaw === "string") {
    zubda = { text: str(zRaw, 800), narration: plain(str(zRaw, 800)) };
  } else {
    const z = (zRaw && typeof zRaw === "object" ? zRaw : {}) as Record<string, unknown>;
    const text = str(z.text, 800);
    zubda = { text, narration: plain(str(z.narration, 800) || text) };
  }
  return {
    hook: {
      available: hookAvail,
      text: hookAvail ? hookText : null,
      narration: hookAvail ? plain(str(hookRaw.narration, 1200) || hookText) : null,
    },
    sections,
    zubda,
  };
}

export function normalizeContent(raw: unknown, fallbackTitle: string, subjectName: string): LessonContent {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const versions = (r.versions && typeof r.versions === "object" ? r.versions : {}) as Record<string, unknown>;
  const title = str(r.title, 200) || fallbackTitle;
  const kamila = normVersion(versions.kamila, false);
  let mukhtasar = normVersion(versions.mukhtasar, true);
  if (mukhtasar.sections.length === 0) {
    mukhtasar = {
      hook: { available: false, text: null, narration: null },
      sections: kamila.sections.filter((s) => s.type !== "example").slice(0, 5),
      zubda: kamila.zubda,
    };
  }
  if (kamila.sections.length === 0) {
    throw new Error("EMPTY_LESSON");
  }
  return {
    title,
    subject: str(r.subject, 100) || subjectName,
    common: {
      welcome: { narration: "هلا والله، أهلاً وسهلاً فيك في منصة تَم التعليمية. يا هلا بك معنا." },
      intro: { narration: `خلنا نبدأ. درسنا اليوم عن ${title}. استعد الحين وخل نشتغل سوا.` },
    },
    versions: { mukhtasar, kamila },
  };
}

/** High-pass (DC/rumble), trim leading/trailing dead air, fade in/out, and add silent tail. */
export function cleanPcm(pcm: Buffer, rate: number): Int16Array {
  const n0 = Math.floor(pcm.length / 2);
  if (n0 === 0 || rate <= 0) {
    return new Int16Array(Math.max(0, Math.round(Math.max(0, rate) * 0.25)));
  }
  const x = new Float32Array(n0);
  const rc = 1 / (2 * Math.PI * 70);
  const a = rc / (rc + 1 / rate);
  let px = 0;
  let py = 0;
  for (let i = 0; i < n0; i++) {
    const v = pcm.readInt16LE(i * 2) / 32768;
    const y = a * (py + v - px);
    px = v;
    py = y;
    x[i] = y;
  }

  const fl = Math.max(1, Math.round(rate * 0.02));
  const nf = Math.floor(n0 / fl);
  const rms = new Float32Array(nf);
  for (let f = 0; f < nf; f++) {
    let e = 0;
    for (let i = f * fl; i < (f + 1) * fl; i++) e += x[i] * x[i];
    rms[f] = Math.sqrt(e / fl);
  }
  const sorted = Array.from(rms).sort((p, q) => p - q);
  const ref = sorted[Math.floor(sorted.length * 0.9)] || 0;
  const thresh = Math.max(0.004, ref * 0.07);

  const MERGE = 5;
  const chunks: Array<[number, number]> = [];
  for (let f = 0; f < nf; f++) {
    if (rms[f] <= thresh) continue;
    const last = chunks[chunks.length - 1];
    if (last && f - last[1] <= MERGE) last[1] = f;
    else chunks.push([f, f]);
  }
  const stats = ([s, e]: [number, number]) => {
    const a0 = s * fl;
    const a1 = (e + 1) * fl;
    let en = 0;
    let pk = 0;
    let z = 0;
    for (let i = a0; i < a1; i++) {
      en += x[i] * x[i];
      const v = Math.abs(x[i]);
      if (v > pk) pk = v;
      if (i > a0 && (x[i] >= 0) !== (x[i - 1] >= 0)) z++;
    }
    const len = a1 - a0;
    return { sec: len / rate, rms: Math.sqrt(en / len), peak: pk, zcr: z / len };
  };
  while (chunks.length > 1) {
    const st = stats(chunks[chunks.length - 1]);
    const gapBefore = (chunks[chunks.length - 1][0] - chunks[chunks.length - 2][1] - 1) * 0.02;
    const noisy = st.zcr >= 0.22 || st.peak >= 0.95 || st.rms >= ref * 1.6;
    if (gapBefore >= 0.1 && st.sec <= 0.8 && noisy) chunks.pop();
    else break;
  }
  while (chunks.length > 1) {
    const st = stats(chunks[0]);
    const gapAfter = (chunks[1][0] - chunks[0][1] - 1) * 0.02;
    if (st.sec <= 0.15 && gapAfter >= 0.1) chunks.shift();
    else break;
  }
  let start = 0;
  let end = n0;
  if (chunks.length) {
    start = Math.max(0, chunks[0][0] * fl - Math.round(rate * 0.06));
    end = Math.min(n0, (chunks[chunks.length - 1][1] + 1) * fl + Math.round(rate * 0.12));
  }

  const bodyLen = end - start;
  const tail = Math.round(rate * 0.25);
  const out = new Int16Array(bodyLen + tail);
  const fin = Math.min(bodyLen, Math.round(rate * 0.012));
  const fout = Math.min(bodyLen, Math.round(rate * 0.06));
  for (let i = 0; i < bodyLen; i++) {
    let v = x[start + i];
    if (i < fin) v *= i / fin;
    if (i >= bodyLen - fout) v *= (bodyLen - 1 - i) / fout;
    out[i] = Math.max(-32000, Math.min(32000, Math.round(v * 32767)));
  }
  return out;
}

/** Collect every narrated segment inside the lesson (same object refs). */
export function collectSegments(c: LessonContent): Segment[] {
  const segs: Segment[] = [c.common.welcome, c.common.intro];
  for (const v of [c.versions.mukhtasar, c.versions.kamila]) {
    if (v.hook.available) segs.push(v.hook);
    segs.push(...v.sections, v.zubda);
  }
  return segs.filter((s) => (s.narration ?? "").trim().length > 0);
}

export function totalDuration(c: LessonContent, version: "mukhtasar" | "kamila"): number {
  const v = c.versions[version];
  const segs: Segment[] = [c.common.welcome, c.common.intro, ...v.sections, v.zubda];
  if (v.hook.available) segs.push(v.hook);
  return Math.round(segs.reduce((a, s) => a + (s.audio?.duration ?? 0), 0));
}

