import * as admin from "firebase-admin";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { GoogleGenerativeAI, Part } from "@google/generative-ai";
import { defineSecret } from "firebase-functions/params";

// ── Initialise Firebase Admin ─────────────────────────────────────────────
admin.initializeApp();
const db = admin.firestore();

// ── Gemini API key stored as a Firebase Secret (NOT in client code) ───────
// Deploy with: firebase functions:secrets:set GEMINI_API_KEY
const GEMINI_SECRET = defineSecret("GEMINI_API_KEY");

// ── Rate Limiting Config ──────────────────────────────────────────────────
const RATE_LIMITS = {
  chat: { maxPerHour: 30 },
  image: { maxPerHour: 15 },
};

// ── Model Candidates (official, verified) ─────────────────────────────────
const MODEL_CANDIDATES = [
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-1.5-flash",
];

// ── Verify Firebase Auth token ────────────────────────────────────────────
function requireAuth(request: CallableRequest): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }
  return request.auth.uid;
}

// ── Server-side Rate Limiter (Firestore-backed, cannot be bypassed) ───────
async function checkRateLimit(uid: string, type: "chat" | "image"): Promise<void> {
  const ref = db.collection("rate_limits").doc(uid);
  const chatKey = "chat_count";
  const imageKey = "image_count";
  const resetKey = "reset_at";
  const nowMs = Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const resetAt = data[resetKey] ?? 0;

    // New window if expired
    if (nowMs > resetAt) {
      tx.set(ref, {
        [chatKey]: 0,
        [imageKey]: 0,
        [resetKey]: nowMs + 3_600_000, // 1 hour
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

// ── Try Gemini models with fallback ──────────────────────────────────────
async function tryModels(
  apiKey: string,
  buildParts: (modelName: string) => Promise<string>
): Promise<string> {
  let lastError = "";
  for (const modelName of MODEL_CANDIDATES) {
    try {
      const result = await buildParts(modelName);
      if (result.trim()) return result;
    } catch (e: unknown) {
      lastError = e instanceof Error ? e.message : String(e);
      if (lastError.includes("429")) {
        await new Promise((r) => setTimeout(r, 2000));
        continue;
      }
    }
  }
  throw new HttpsError("unavailable", `تعذّر الاتصال بخدمة الذكاء الاصطناعي. يرجى المحاولة لاحقاً.`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 1: geminiChat — AI Tutor text chat
// ─────────────────────────────────────────────────────────────────────────────
export const geminiChat = onCall(
  { secrets: [GEMINI_SECRET], region: "me-central1" },
  async (request) => {
    const uid = requireAuth(request);
    await checkRateLimit(uid, "chat");

    const { subject, grade, history, message, userName, country } = request.data as {
      subject: string;
      grade: number;
      history: Array<{ role: string; content: string }>;
      message: string;
      userName?: string;
      country?: string;
    };

    if (!message?.trim()) throw new HttpsError("invalid-argument", "الرسالة فارغة.");

    const isEnglish = subject.toLowerCase().includes("english") || subject.includes("إنجليزي");
    const gender = isEnglish ? "معلمة خبيرة" : "مدرس خبير ومحترف";
    const nameContext = userName ? `ناديه دائماً باسمه الأول (${userName}).` : "";
    const countryText =
      country === "sa" ? "المنهج السعودي" :
      country === "ae" ? "المنهج الإماراتي" :
      "المنهج الكويتي";
    const dialectText =
      country === "sa" ? "تحدث بأسلوب سعودي مشجع وفصيح." :
      country === "ae" ? "تحدث بأسلوب إماراتي مشجع وفصيح." :
      "تحدث بلهجة كويتية بيضاء فصيحة ومشجعة.";

    const systemPrompt =
      `أنت ${gender} في مادة ${subject} لـ ${countryText}، الصف ${grade}. ` +
      `اسمك "مدرس تَم الذكي". ${dialectText} ${nameContext} ` +
      `⚠️ أنت متخصص حصراً في مادة (${subject}). إذا سألك الطالب عن موضوع آخر اعتذر ولا تجب.`;

    const apiKey = GEMINI_SECRET.value();
    const genAI = new GoogleGenerativeAI(apiKey);

    return tryModels(apiKey, async (modelName) => {
      const model = genAI.getGenerativeModel({
        model: modelName,
        systemInstruction: systemPrompt,
      });

      const geminiHistory = history.map((m) => ({
        role: m.role === "user" ? "user" : "model",
        parts: [{ text: m.content }],
      }));

      const chat = model.startChat({ history: geminiHistory });
      const result = await chat.sendMessage(message);
      return result.response.text();
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 2: geminiSolveImage — Camera: Solve from image
// ─────────────────────────────────────────────────────────────────────────────
export const geminiSolveImage = onCall(
  { secrets: [GEMINI_SECRET], region: "me-central1" },
  async (request) => {
    const uid = requireAuth(request);
    await checkRateLimit(uid, "image");

    const { imageBase64, mimeType, subject, grade, mode } = request.data as {
      imageBase64: string;
      mimeType: string;
      subject: string;
      grade?: number;
      mode: "solve" | "grade";
    };

    if (!imageBase64) throw new HttpsError("invalid-argument", "لم يتم إرسال صورة.");

    const gradeText = grade ? `للصف ${grade}` : "";
    const systemPrompt =
      mode === "grade"
        ? `أنت مدرس متخصص في مادة ${subject}. صحح الواجب وحدد الأخطاء وأعط علامة وملاحظات تحسين بالعربية.`
        : `أنت مدرس متخصص في مادة ${subject} ${gradeText}. حل المسألة في الصورة خطوة بخطوة بالعربية.`;

    const apiKey = GEMINI_SECRET.value();
    const genAI = new GoogleGenerativeAI(apiKey);

    const imageBytes = Buffer.from(imageBase64, "base64");

    return tryModels(apiKey, async (modelName) => {
      const model = genAI.getGenerativeModel({ model: modelName });
      const imagePart: Part = { inlineData: { data: imageBytes.toString("base64"), mimeType } };
      const result = await model.generateContent([systemPrompt, imagePart]);
      return result.response.text();
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 3: geminiGenerateQuiz — Quiz generation from PDF content
// ─────────────────────────────────────────────────────────────────────────────
export const geminiGenerateQuiz = onCall(
  { secrets: [GEMINI_SECRET], region: "me-central1" },
  async (request) => {
    const uid = requireAuth(request);
    await checkRateLimit(uid, "chat");

    const { subject, grade, pdfTexts, count = 5 } = request.data as {
      subject: string;
      grade: number;
      pdfTexts: string[];
      count?: number;
    };

    const contextText = pdfTexts?.length
      ? `المحتوى:\n${pdfTexts.join("\n\n")}`
      : `أنشئ ${count} أسئلة شاملة في مادة ${subject} للصف ${grade}.`;

    const systemPrompt =
      `أنت مدرس خبير. أنتج ${count} أسئلة JSON:\n` +
      `{"questions":[{"question":"...","options":["أ","ب","ج","د"],"correctIndex":0,"explanation":"..."}]}`;

    const apiKey = GEMINI_SECRET.value();
    const genAI = new GoogleGenerativeAI(apiKey);

    const rawText = await tryModels(apiKey, async (modelName) => {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(`${systemPrompt}\n${contextText}`);
      return result.response.text();
    });

    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new HttpsError("internal", "فشل توليد الاختبار. يرجى المحاولة مجدداً.");

    const parsed = JSON.parse(jsonMatch[0]);
    return { questions: parsed.questions ?? [] };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 4: geminiSummarize — Smart content summarizer
// ─────────────────────────────────────────────────────────────────────────────
export const geminiSummarize = onCall(
  { secrets: [GEMINI_SECRET], region: "me-central1" },
  async (request) => {
    const uid = requireAuth(request);
    await checkRateLimit(uid, "chat");

    const { content, subject } = request.data as { content: string; subject: string };
    if (!content?.trim()) throw new HttpsError("invalid-argument", "المحتوى فارغ.");

    const prompt = `لخص هذا المحتوى التعليمي في مادة ${subject} بنقاط مهمة وواضحة بالعربية:\n${content}`;

    const apiKey = GEMINI_SECRET.value();
    const genAI = new GoogleGenerativeAI(apiKey);

    return tryModels(apiKey, async (modelName) => {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(prompt);
      return result.response.text();
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 5: activateSubscription — Validate IAP receipt & activate
// ─────────────────────────────────────────────────────────────────────────────
export const activateSubscription = onCall(
  { region: "me-central1" },
  async (request) => {
    const uid = requireAuth(request);

    const { productId, platform, transactionId, userEmail } = request.data as {
      productId: string;
      platform: "ios" | "android";
      transactionId: string;
      userEmail?: string;
    };

    // ── Basic input validation ─────────────────────────────────────────────
    if (!productId || !transactionId) {
      throw new HttpsError("invalid-argument", "بيانات الشراء غير مكتملة.");
    }
    if (!["ios", "android"].includes(platform)) {
      throw new HttpsError("invalid-argument", "منصة غير معروفة.");
    }

    // ── Validate transactionId format ──────────────────────────────────────
    // iOS: numeric string (StoreKit 1) or UUID v4 (StoreKit 2)
    // Android: alphanumeric token from Google Play
    const iosNumericPattern   = /^\d{10,}$/;
    const uuidPattern         = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const androidTokenPattern = /^[A-Za-z0-9._\-]{10,}$/;

    const isValidTxId =
      platform === "ios"
        ? iosNumericPattern.test(transactionId) || uuidPattern.test(transactionId)
        : androidTokenPattern.test(transactionId);

    if (!isValidTxId) {
      throw new HttpsError("invalid-argument", "معرّف المعاملة غير صالح.");
    }

    // ── Prevent duplicate activation (idempotency) ────────────────────────
    const subRef = db.collection("subscriptions").doc(transactionId);
    const existing = await subRef.get();
    if (existing.exists) {
      // Ensure user document has is_subscribed flag set (handles device switch / restore)
      await db.collection("users").doc(uid).update({ is_subscribed: true }).catch(() => {});
      // Already activated — return success (idempotent)
      return { success: true, message: "الاشتراك مفعّل بالفعل." };
    }

    // ── Check that this transactionId hasn't been used by ANOTHER user ─────
    const duplicateSnap = await db
      .collection("subscriptions")
      .where("transaction_id", "==", transactionId)
      .limit(1)
      .get();
    if (!duplicateSnap.empty) {
      throw new HttpsError("already-exists", "هذه المعاملة مُستخدمة بالفعل.");
    }

    // ── TODO: Full server-side receipt validation ──────────────────────────
    // To fully prevent fraudulent activations, integrate:
    //
    // For iOS (App Store Server API v2):
    //   - Set APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY as Firebase Secrets
    //   - POST to https://api.storekit.itunes.apple.com/inApps/v2/transactions/{transactionId}
    //   - Verify the signed JWT response using Apple's public key
    //   - Confirm: bundleId, productId, originalTransactionId, expiresDate
    //
    // For Android (Google Play Billing API):
    //   - Use a service account with Google Play Developer API access
    //   - GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/subscriptions/{subscriptionId}/tokens/{purchaseToken}
    //   - Confirm: paymentState == 1 (Received), expiryTimeMillis > Date.now()
    // ──────────────────────────────────────────────────────────────────────

    // ── Duration map (matching IAP product IDs) ────────────────────────────
    const durationMap: Record<string, number> = {
      "tam_1month": 30,
      "tam_3months": 90,
      "tam_6months": 180,
      "tam_6months_12kwd": 180,  // legacy product id
      "tam_1year": 365,
    };

    const durationDays = durationMap[productId];
    if (!durationDays) {
      throw new HttpsError("invalid-argument", `معرّف المنتج غير معروف: ${productId}`);
    }

    const now = admin.firestore.Timestamp.now();
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + durationDays * 86_400_000
    );

    const subData = {
      firebase_uid: uid,
      user_email: userEmail ?? "",
      product_id: productId,
      platform,
      transaction_id: transactionId,
      status: "active",
      plan: productId,
      duration_days: durationDays,
      created_at: now,
      expires_at: expiresAt,
    };

    // Write subscription document (Admin SDK bypasses security rules)
    await subRef.set(subData);

    // Update user's is_subscribed flag
    await db.collection("users").doc(uid).update({ is_subscribed: true });

    return { success: true, durationDays, expiresAt: expiresAt.toMillis() };
  }
);
