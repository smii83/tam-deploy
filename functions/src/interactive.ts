// ─────────────────────────────────────────────────────────────────────────────
// TAM Interactive Lessons (السبورة التفاعلية)
//
//  generateInteractiveLesson  (admin only)
//      PDF summary  ──►  Gemini  ──►  slides JSON (mukhtasar / kamila)
//                   ──►  Gemini TTS ──►  MP3 per segment (Storage)
//      Runs ONCE per PDF. Students then stream static files (cheap).
//
//  lessonAsk  (students)
//      On-demand question about the slide currently on screen.
//      Only the current slide is sent as context, answers are cached
//      per (lesson + slide + normalized question) to avoid repeat API cost.
//
// Firestore layout:
//   interactive_lessons/{pdfId}  small meta doc (status, title, duration …)
//   interactive_content/{pdfId}  heavy payload (slides + audio refs)
//   lesson_qa_cache/{hash}       cached answers
// Storage layout:
//   lesson_audio/{pdfId}/{hash}.mp3
// ─────────────────────────────────────────────────────────────────────────────
import * as admin from "firebase-admin";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { defineSecret } from "firebase-functions/params";
import * as crypto from "crypto";

// @breezystack/lamejs is ESM-only; tsc (CommonJS) would rewrite import() into
// require(), so we keep a native dynamic import.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let _lamejs: any;
async function getLame() {
  if (!_lamejs) {
    const nativeImport = new Function("m", "return import(m)") as (m: string) => Promise<unknown>;
    _lamejs = await nativeImport("@breezystack/lamejs");
  }
  return _lamejs;
}

const GEMINI_SECRET = defineSecret("GEMINI_API_KEY");
const REGION = "me-central1";

const ADMIN_EMAILS = [
  "tam.app83@gmail.com",
  "tm.app83@gmail.com",
  "tamteach01@gmail.com",
  "admin@tam.com",
];

const TEXT_MODELS = ["gemini-2.5-flash", "gemini-flash-latest", "gemini-2.0-flash"];
const DEFAULT_TTS_MODEL = "gemini-2.5-flash-preview-tts";
const DEFAULT_TTS_VOICE = "Kore";
const DEFAULT_TTS_STYLE =
  "Speak as a warm, friendly Gulf Arabic school teacher giving a private tutoring session. " +
  "Use a natural, conversational tone — like you are sitting with the student at home, " +
  "not lecturing formally. Speak at a calm, clear, medium pace with genuine enthusiasm for the subject. " +
  "Sound encouraging and approachable, as if the student is right in front of you: ";
const MAX_PDF_BYTES = 18 * 1024 * 1024; // inline limit for Gemini is ~20MB

const db = () => admin.firestore();

// ═════════════════════════════════════════════════════════════════════════════
// Types
// ═════════════════════════════════════════════════════════════════════════════
interface AudioRef {
  path: string;
  duration: number; // seconds
}
interface Section {
  type: "section" | "formula" | "example";
  heading: string;
  content: string;
  narration: string;
  audio?: AudioRef | null;
}
interface Hook {
  available: boolean;
  text: string | null;
  narration: string | null;
  audio?: AudioRef | null;
}
interface Zubda {
  text: string;
  narration: string;
  audio?: AudioRef | null;
}
interface Version {
  hook: Hook;
  sections: Section[];
  zubda: Zubda;
}
interface LessonContent {
  title: string;
  subject: string;
  common: {
    welcome: { narration: string; audio?: AudioRef | null };
    intro: { narration: string; audio?: AudioRef | null };
  };
  versions: { mukhtasar: Version; kamila: Version };
  voice?: string;
}
type Segment = { narration?: string | null; audio?: AudioRef | null };

// ═════════════════════════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════════════════════════
function requireAuth(request: CallableRequest): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }
  return request.auth.uid;
}

function requireAdmin(request: CallableRequest): void {
  requireAuth(request);
  const email = String(request.auth?.token?.email ?? "").toLowerCase().trim();
  if (!ADMIN_EMAILS.includes(email)) {
    throw new HttpsError("permission-denied", "هذه العملية مخصصة للمشرفين فقط.");
  }
}

function sha1(s: string): string {
  return crypto.createHash("sha1").update(s).digest("hex");
}

function str(v: unknown, max = 4000): string {
  return typeof v === "string" ? v.trim().slice(0, max) : "";
}

/** Strip [[concept]] markers so they are not spoken/hashed. */
function plain(s: string): string {
  return s.replace(/\[\[|\]\]/g, "");
}

/** Normalise Arabic text for cache keys. */
function normalizeAr(s: string): string {
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

function dialectFor(country: string): string {
  switch (country) {
    case "sa": return "لهجة سعودية خليجية أصيلة";
    case "ae": return "لهجة إماراتية خليجية أصيلة";
    default: return "لهجة كويتية خليجية أصيلة";
  }
}

function teacherPersonality(country: string): string {
  const base = `أنت مدرس خليجي محترف بشوش يعطي درساً خصوصياً لطالب كأنك جاسه في البيت.
- تحكي بـ${dialectFor(country)} مريح وطبيعي، مو بأسلوب رسمي.
- تبدأ كل فكرة جديدة بعبارة تشويقية مثل: "اسمع كيف"، "الحين خل أوضح"، "هذي هي الحلوة"، "والله سؤال وايد مهم".
- تضرب أمثلة من الحياة اليومية الخليجية.
- ترحب بالطالب ويحس إنك مهتم فيه شخصياً.
- ما تحشو الكلام ولا تكرر نفس الجملة.
- كلامك يُقرأ بصوت عالٍ، فاكتب كلاماً عادياً بدون نقاط مرقّمة ولا ماركداون ولا رموز أو إيموجي.
- اكتب المعادلات والأرقام والرموز العلمية بالكلمات (مثل: إكس تربيع، جذر اثنين، باي).`;
  return base;
}

async function pool<T>(items: T[], size: number, fn: (item: T) => Promise<void>): Promise<void> {
  let i = 0;
  const workers = Array.from({ length: Math.min(size, items.length) }, async () => {
    while (i < items.length) {
      const item = items[i++];
      await fn(item);
    }
  });
  await Promise.all(workers);
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// ═════════════════════════════════════════════════════════════════════════════
// 1) Content generation (PDF → slides JSON)
// ═════════════════════════════════════════════════════════════════════════════
function buildLessonPrompt(titleHint: string, subjectName: string, country: string): string {
  const dialect = dialectFor(country);
  return `${teacherPersonality(country)}

أمامك ملخص دراسي (PDF) لمادة "${subjectName}" بعنوان "${titleHint}".
حوّله إلى درس تفاعلي على شكل شرائح متحركة يقودها صوتك كمدرس خليجي.
أعد JSON صالحاً فقط بدون أي نص خارجه وبهذا الشكل:

{
  "title": "اسم الدرس",
  "subject": "${subjectName}",
  "versions": {
    "mukhtasar": {
      "hook": { "available": false, "text": null, "narration": null },
      "sections": [ { "type": "section", "heading": "...", "content": "...", "narration": "..." } ],
      "zubda": { "text": "...", "narration": "..." }
    },
    "kamila": {
      "hook": { "available": true, "text": "...", "narration": "..." },
      "sections": [ { "type": "section|formula|example", "heading": "...", "content": "...", "narration": "..." } ],
      "zubda": { "text": "...", "narration": "..." }
    }
  }
}

القواعد الصارمة:
1) الأمانة: استخدم معلومات الملخص فقط. لا تضف حقائق أو أرقاماً من عندك. إذا كان جزء غير واضح فتجاوزه.
2) heading: عنوان قصير جذاب. ضع الكلمات المفتاحية بين [[ ]] مثل: شنو هي [[المعادلة التربيعية]]؟
3) content: النص المعروض على الشاشة. مختصر (حتى 220 حرفاً). اكتب الرياضيات والفيزياء والكيمياء بصيغ يونيكود (x² ، √ ، ± ، ÷ ، × ، ≤ ، ≥ ، π ، →) بدون LaTeX أو علامات $ أو \\\\. استخدم \\n لفصل الأسطر.
4) narration: كلام المعلم المنطوق بصوت عالٍ بـ${dialect}. ثلاث إلى خمس جمل طبيعية كأنك تشرح لطالب جالس قدامك. ابدأ بعبارة تشويقية خليجية أو سؤال بسيط. اكتب المعادلات والرموز بالكلمات كما تُنطق. بدون رموز أو ماركداون أو أقواس [[ ]].
5) type: "section" للشرح العادي، "formula" للقوانين والمعادلات (ضع القانون في content)، "example" للأمثلة المحلولة (خطوات الحل في content مفصولة بـ \\n).
6) النسخة mukhtasar (الزبدة): من 3 إلى 6 شرائح للمفاهيم الجوهرية فقط، بدون أمثلة طويلة، و hook.available=false دائماً.
7) النسخة kamila (الكاملة): من 6 إلى 14 شريحة تغطي كل مفاهيم الملخص وكل قانون وكل مثال محلول فيه.
8) hook في kamila: إذا كان الملخص يحتوي سؤال امتحان سابق حقيقي ضعه في text (مع السنة إن وُجدت) و available=true. narration: اجعل المدرس يطرح السؤال بأسلوب تشويقي كأنه اختبار مفاجئ. وإلا اجعل available=false وبقية الحقول null.
9) zubda: خلاصة الدرس في جملة أو جملتين (text). narration: ختمة المدرس — يلخّص بحرارة ويشجع الطالب بكلام خليجي مألوف.
10) لا تكرر نفس الشريحة. ولا تنهي بسؤال للطالب.`;
}

function normSection(raw: unknown): Section | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const heading = str(r.heading, 300);
  const content = str(r.content, 1500);
  if (!heading && !content) return null;
  const type = r.type === "formula" || r.type === "example" ? r.type : "section";
  const narration = str(r.narration, 1200) || plain(`${heading}. ${content}`);
  return { type, heading, content, narration: plain(narration) };
}

function normVersion(raw: unknown, forceNoHook: boolean): Version {
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

function normalizeContent(raw: unknown, fallbackTitle: string, subjectName: string): LessonContent {
  const r = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const versions = (r.versions && typeof r.versions === "object" ? r.versions : {}) as Record<string, unknown>;
  const title = str(r.title, 200) || fallbackTitle;
  const kamila = normVersion(versions.kamila, false);
  let mukhtasar = normVersion(versions.mukhtasar, true);
  // Safety net: if the model failed to produce the short version, derive it.
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

async function generateContentJson(
  apiKey: string,
  prompt: string,
  pdf: Buffer
): Promise<unknown> {
  const genAI = new GoogleGenerativeAI(apiKey);
  let lastError = "";
  for (const modelName of TEXT_MODELS) {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const model = genAI.getGenerativeModel(
          {
            model: modelName,
            generationConfig: {
              responseMimeType: "application/json",
              temperature: 0.4,
              maxOutputTokens: 32768,
            },
          },
          { timeout: 240_000 }
        );
        const result = await model.generateContent([
          { text: prompt },
          { inlineData: { data: pdf.toString("base64"), mimeType: "application/pdf" } },
        ]);
        const text = result.response.text();
        const match = text.match(/\{[\s\S]*\}/);
        if (!match) throw new Error("NO_JSON");
        return JSON.parse(match[0]);
      } catch (e: unknown) {
        lastError = e instanceof Error ? e.message : String(e);
        console.warn(`generateContentJson ${modelName} attempt ${attempt}: ${lastError}`);
        await sleep(1500);
      }
    }
  }
  throw new Error(`GEMINI_FAILED: ${lastError}`);
}

// ═════════════════════════════════════════════════════════════════════════════
// 2) Audio generation (Gemini TTS → MP3 → Storage)
// ═════════════════════════════════════════════════════════════════════════════
interface TtsConfig {
  model: string;
  voice: string;
  style: string;
}

async function loadTtsConfig(): Promise<TtsConfig> {
  try {
    const doc = await db().collection("config").doc("ai").get();
    const d = doc.data() ?? {};
    return {
      model: str(d.tts_model, 100) || DEFAULT_TTS_MODEL,
      voice: str(d.tts_voice, 40) || DEFAULT_TTS_VOICE,
      style: str(d.tts_style, 400) || DEFAULT_TTS_STYLE,
    };
  } catch {
    return { model: DEFAULT_TTS_MODEL, voice: DEFAULT_TTS_VOICE, style: DEFAULT_TTS_STYLE };
  }
}

async function ttsPcm(apiKey: string, cfg: TtsConfig, text: string): Promise<Buffer> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${cfg.model}:generateContent`;
  const body = {
    contents: [{ parts: [{ text: cfg.style + text }] }],
    generationConfig: {
      responseModalities: ["AUDIO"],
      speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: cfg.voice } } },
    },
  };
  let lastErr = "";
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        lastErr = `HTTP ${res.status}`;
        if (res.status === 429 || res.status >= 500) {
          await sleep(2500 * (attempt + 1));
          continue;
        }
        throw new Error(`${lastErr}: ${(await res.text()).slice(0, 200)}`);
      }
      const json = (await res.json()) as {
        candidates?: Array<{ content?: { parts?: Array<{ inlineData?: { data?: string } }> } }>;
      };
      const part = json.candidates?.[0]?.content?.parts?.find((p) => p.inlineData?.data);
      if (!part?.inlineData?.data) {
        lastErr = "NO_AUDIO";
        await sleep(1200);
        continue;
      }
      return Buffer.from(part.inlineData.data, "base64"); // 24kHz s16le mono
    } catch (e: unknown) {
      lastErr = e instanceof Error ? e.message : String(e);
      await sleep(1500);
    }
  }
  throw new Error(`TTS_FAILED: ${lastErr}`);
}

/**
 * Gemini TTS clips have a "pop" at the start and a loud, noisy burst after the last word.
 * Every slide is its own clip, so that is audible as static between segments.
 * Steps: high-pass (DC/rumble) → drop edge artifacts → trim → fade in/out → short silent tail.
 * Mirrors scratch/audio_tools/audio_clean.js.
 */
function cleanPcm(pcm: Buffer, rate: number): Int16Array {
  const n0 = Math.floor(pcm.length / 2);
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

async function pcmToMp3(pcm: Buffer, sampleRate = 24000): Promise<{ mp3: Buffer; duration: number }> {
  const lamejs = await getLame();
  const samples = cleanPcm(pcm, sampleRate);
  const encoder = new lamejs.Mp3Encoder(1, sampleRate, 56);
  const chunks: Buffer[] = [];
  const block = 1152;
  for (let i = 0; i < samples.length; i += block) {
    const out = encoder.encodeBuffer(samples.subarray(i, i + block));
    if (out.length) chunks.push(Buffer.from(out));
  }
  const tail = encoder.flush();
  if (tail.length) chunks.push(Buffer.from(tail));
  return { mp3: Buffer.concat(chunks), duration: samples.length / sampleRate };
}

/** Synthesize (or reuse) the audio for one narration. */
async function ensureAudio(
  apiKey: string,
  cfg: TtsConfig,
  pdfId: string,
  narration: string
): Promise<AudioRef> {
  const bucket = admin.storage().bucket();
  const path = `lesson_audio/${pdfId}/${sha1(cfg.voice + "|" + narration).slice(0, 20)}.mp3`;
  const file = bucket.file(path);
  const [exists] = await file.exists();
  if (exists) {
    const [meta] = await file.getMetadata();
    const d = parseFloat(String(meta.metadata?.duration ?? "0"));
    if (d > 0) return { path, duration: d };
  }
  const pcm = await ttsPcm(apiKey, cfg, narration);
  const { mp3, duration } = await pcmToMp3(pcm);
  await file.save(mp3, {
    contentType: "audio/mpeg",
    resumable: false,
    metadata: {
      cacheControl: "public, max-age=31536000",
      metadata: { duration: duration.toFixed(2), voice: cfg.voice },
    },
  });
  return { path, duration };
}

/** Collect every narrated segment inside the lesson (same object refs). */
function collectSegments(c: LessonContent): Segment[] {
  const segs: Segment[] = [c.common.welcome, c.common.intro];
  for (const v of [c.versions.mukhtasar, c.versions.kamila]) {
    if (v.hook.available) segs.push(v.hook);
    segs.push(...v.sections, v.zubda);
  }
  return segs.filter((s) => (s.narration ?? "").trim().length > 0);
}

async function attachAudio(
  apiKey: string,
  pdfId: string,
  content: LessonContent,
  deadlineMs: number
): Promise<{ done: number; total: number }> {
  const cfg = await loadTtsConfig();
  content.voice = cfg.voice;
  const segs = collectSegments(content);
  const cache = new Map<string, AudioRef | null>();
  let done = 0;
  await pool(segs, 3, async (seg) => {
    const text = (seg.narration ?? "").trim();
    if (seg.audio?.path) {
      done++;
      return;
    }
    if (cache.has(text)) {
      seg.audio = cache.get(text);
      if (seg.audio) done++;
      return;
    }
    if (Date.now() > deadlineMs) return; // out of time → client falls back to device TTS
    try {
      const audio = await ensureAudio(apiKey, cfg, pdfId, text);
      cache.set(text, audio);
      seg.audio = audio;
      done++;
    } catch (e: unknown) {
      console.warn(`TTS failed for segment: ${e instanceof Error ? e.message : e}`);
      cache.set(text, null);
    }
  });
  return { done, total: segs.length };
}

function totalDuration(c: LessonContent, version: "mukhtasar" | "kamila"): number {
  const v = c.versions[version];
  const segs: Segment[] = [c.common.welcome, c.common.intro, ...v.sections, v.zubda];
  if (v.hook.available) segs.push(v.hook);
  return Math.round(segs.reduce((a, s) => a + (s.audio?.duration ?? 0), 0));
}

// ═════════════════════════════════════════════════════════════════════════════
// Callable: generateInteractiveLesson  (admin)
// ═════════════════════════════════════════════════════════════════════════════
export const generateInteractiveLesson = onCall(
  { secrets: [GEMINI_SECRET], region: REGION, timeoutSeconds: 540, memory: "1GiB" },
  async (request) => {
    requireAdmin(request);
    const startedAt = Date.now();
    const { pdfId, mode } = request.data as { pdfId?: string; mode?: "full" | "audio" };
    if (!pdfId || typeof pdfId !== "string") {
      throw new HttpsError("invalid-argument", "pdfId مطلوب.");
    }

    const pdfSnap = await db().collection("pdfs").doc(pdfId).get();
    if (!pdfSnap.exists) throw new HttpsError("not-found", "ملف PDF غير موجود.");
    const pdf = pdfSnap.data() ?? {};
    const titleAr = str(pdf.title_ar, 200) || str(pdf.name, 200) || "درس";
    const subjectId = str(pdf.subject_id, 100);

    const metaRef = db().collection("interactive_lessons").doc(pdfId);
    const contentRef = db().collection("interactive_content").doc(pdfId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    await metaRef.set(
      {
        pdf_id: pdfId,
        subject_id: subjectId,
        title_ar: titleAr,
        status: "processing",
        error: null,
        updated: now,
      },
      { merge: true }
    );

    try {
      // Subject + country (for dialect)
      let subjectName = "المادة";
      let country = "kw";
      if (subjectId) {
        const sub = await db().collection("subjects").doc(subjectId).get();
        const sd = sub.data();
        if (sd) {
          subjectName = str(sd.name_ar, 100) || subjectName;
          if (sd.grade_id) {
            const g = await db().collection("grades").doc(String(sd.grade_id)).get();
            country = str(g.data()?.country, 5) || "kw";
          }
        }
      }

      const apiKey = GEMINI_SECRET.value();
      let content: LessonContent;

      if (mode === "audio") {
        const existing = await contentRef.get();
        if (!existing.exists) throw new Error("NO_CONTENT_YET");
        content = existing.data() as LessonContent;
      } else {
        const fileUrl = str(pdf.file_url, 2000);
        if (!fileUrl) throw new Error("NO_FILE_URL");
        const res = await fetch(fileUrl);
        if (!res.ok) throw new Error(`PDF_DOWNLOAD_${res.status}`);
        const buf = Buffer.from(await res.arrayBuffer());
        if (buf.length > MAX_PDF_BYTES) throw new Error("PDF_TOO_LARGE");
        const raw = await generateContentJson(
          apiKey,
          buildLessonPrompt(titleAr, subjectName, country),
          buf
        );
        // The admin-chosen name is the single source of truth for the title.
        content = normalizeContent(raw, titleAr, subjectName);
        content.title = titleAr;
        content.common.intro.narration = `خلنا نبدأ. درسنا اليوم عن ${titleAr}. استعد الحين وخل نشتغل سوا.`;
        // Save text right away so a TTS timeout never loses the lesson.
        await contentRef.set(content);
      }

      const deadline = startedAt + 470_000;
      const audio = await attachAudio(apiKey, pdfId, content, deadline);
      await contentRef.set(content);

      await metaRef.set(
        {
          status: "ready",
          error: null,
          country,
          slides_mukhtasar: content.versions.mukhtasar.sections.length,
          slides_kamila: content.versions.kamila.sections.length,
          duration_mukhtasar: totalDuration(content, "mukhtasar"),
          duration_kamila: totalDuration(content, "kamila"),
          audio_done: audio.done,
          audio_total: audio.total,
          audio_complete: audio.done >= audio.total,
          voice: content.voice ?? DEFAULT_TTS_VOICE,
          updated: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return { success: true, audioDone: audio.done, audioTotal: audio.total };
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error("generateInteractiveLesson failed:", msg);
      await metaRef.set(
        { status: "error", error: msg.slice(0, 300), updated: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
      throw new HttpsError("internal", `فشل توليد الدرس: ${msg.slice(0, 160)}`);
    }
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// Callable: lessonAsk  (students — on demand only)
// ═════════════════════════════════════════════════════════════════════════════
const ASK_LIMIT_PER_HOUR = 40;

async function checkAskLimit(uid: string): Promise<void> {
  const ref = db().collection("rate_limits").doc(`ask_${uid}`);
  const nowMs = Date.now();
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data() ?? {};
    if (nowMs > (d.reset_at ?? 0)) {
      tx.set(ref, { count: 1, reset_at: nowMs + 3_600_000 });
      return;
    }
    if ((d.count ?? 0) >= ASK_LIMIT_PER_HOUR) {
      throw new HttpsError(
        "resource-exhausted",
        "وصلت للحد الأقصى من الأسئلة هذه الساعة. جرّب بعد قليل 🕐"
      );
    }
    tx.update(ref, { count: (d.count ?? 0) + 1 });
  });
}

export const lessonAsk = onCall(
  { secrets: [GEMINI_SECRET], region: REGION, timeoutSeconds: 60, memory: "256MiB" },
  async (request) => {
    const uid = requireAuth(request);
    const d = request.data as {
      pdfId?: string;
      heading?: string;
      content?: string;
      question?: string;
      country?: string;
    };
    const pdfId = str(d.pdfId, 100);
    const question = str(d.question, 400);
    const heading = str(d.heading, 300);
    const content = str(d.content, 1500);
    if (!pdfId || !question) {
      throw new HttpsError("invalid-argument", "السؤال فارغ.");
    }

    // 1) Semantic-ish cache: same lesson + same slide + same normalized question
    const slideKey = sha1(normalizeAr(heading + " " + content)).slice(0, 12);
    const cacheKey = sha1(`${pdfId}|${slideKey}|${normalizeAr(question)}`);
    const cacheRef = db().collection("lesson_qa_cache").doc(cacheKey);
    const cached = await cacheRef.get();
    if (cached.exists && typeof cached.data()?.answer === "string") {
      cacheRef.update({ hits: admin.firestore.FieldValue.increment(1) }).catch(() => undefined);
      return { answer: cached.data()!.answer as string, cached: true };
    }

    // 2) Not cached → costs money → rate limit
    await checkAskLimit(uid);

    const metaSnap = await db().collection("interactive_lessons").doc(pdfId).get();
    const meta = metaSnap.data() ?? {};
    const lessonTitle = str(meta.title_ar, 200);
    let subjectName = "";
    if (meta.subject_id) {
      const sub = await db().collection("subjects").doc(String(meta.subject_id)).get();
      subjectName = str(sub.data()?.name_ar, 100);
    }
    const country = ["kw", "sa", "ae"].includes(String(d.country)) ? String(d.country) : str(meta.country, 5) || "kw";

    const system =
      `${teacherPersonality(country)}\n\n` +
      `أنت تعطي درساً خصوصياً في مادة "${subjectName || "الدراسية"}" وكنت تشرح "${lessonTitle}". ` +
      `الطالب قاطعك بسؤال الحين وانت في أثناء الشرح — تصرف كمدرس حقيقي: توقف بشكل طبيعي وأجب بدفء. ` +
      `أجب بثلاث إلى ست جمل طبيعية فقط، معتمداً على محتوى الشريحة المعروضة. ` +
      `ابدأ بعبارة تُظهر إنك استقبلت سؤاله بارتياح، مثل: "آه والله سؤال حلو"، "هذا بالضبط اللي كان يلزمنا نوضحه"، "يا هلا بالسؤال". ` +
      `الإجابة ستُقرأ بصوت عالٍ — فاكتب كلاماً عادياً مفهوماً بالأذن بدون ماركداون أو نقاط أو رموز أو إيموجي، واكتب المعادلات بالكلمات. ` +
      `إذا كان السؤال خارج نطاق المادة اعتذر بلطف بأسلوب خليجي وأعده للدرس. لا تطرح سؤالاً في نهاية إجابتك.`;

    const userPrompt =
      `الشريحة المعروضة الآن:\nالعنوان: ${plain(heading)}\nالمحتوى: ${plain(content)}\n\n` +
      `سؤال الطالب: ${question}`;

    const genAI = new GoogleGenerativeAI(GEMINI_SECRET.value());
    let answer = "";
    for (const modelName of TEXT_MODELS) {
      try {
        const model = genAI.getGenerativeModel({
          model: modelName,
          systemInstruction: system,
          generationConfig: { temperature: 0.5, maxOutputTokens: 1500 },
        });
        const r = await model.generateContent(userPrompt);
        answer = r.response.text().replace(/[*_#`]/g, "").trim();
        if (answer) break;
      } catch (e: unknown) {
        console.warn(`lessonAsk ${modelName}: ${e instanceof Error ? e.message : e}`);
        await sleep(800);
      }
    }
    if (!answer) {
      throw new HttpsError("unavailable", "تعذّر الاتصال بالأستاذ الذكي حالياً. حاول مجدداً.");
    }

    cacheRef
      .set({
        pdf_id: pdfId,
        slide_key: slideKey,
        question,
        answer,
        hits: 0,
        created: admin.firestore.FieldValue.serverTimestamp(),
      })
      .catch(() => undefined);

    return { answer, cached: false };
  }
);
