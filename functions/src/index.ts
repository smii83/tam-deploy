import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GoogleGenerativeAI, Part } from "@google/generative-ai";
import { defineSecret, defineString } from "firebase-functions/params";
import { requireAuth, requireAdmin, assertActiveSubscriber } from "./auth";
import {
  AppleValidation,
  VALID_TX_ID_PATTERN,
  checkRateLimitWithDb,
  computeSubscriptionWindow,
  tryModelsWithDelay,
  validateAppleReceiptWithVerify,
} from "./logic";

// ── Initialise Firebase Admin ─────────────────────────────────────────────
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// ── Gemini API key stored as a Firebase Secret (NOT in client code) ───────
// Deploy with: firebase functions:secrets:set GEMINI_API_KEY
const GEMINI_SECRET = defineSecret("GEMINI_API_KEY");

// ── Apple shared secret for server-side receipt validation (OPTIONAL) ─────
// Plain string param (not a secret) so an unset value never breaks deploys.
// Set it in functions/.env:  APPLE_SHARED_SECRET=<App Store Connect shared secret>
const APPLE_SHARED_SECRET = defineString("APPLE_SHARED_SECRET", { default: "" });

// ── Server-side Rate Limiter (Firestore-backed, cannot be bypassed) ───────
async function checkRateLimit(uid: string, type: "chat" | "image"): Promise<void> {
  return checkRateLimitWithDb(db, uid, type);
}

// ── Try Gemini models with fallback ──────────────────────────────────────
async function tryModels(
  _apiKey: string,
  buildParts: (modelName: string) => Promise<string>
): Promise<string> {
  return tryModelsWithDelay(buildParts);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 1: geminiChat — AI Tutor text chat
// ─────────────────────────────────────────────────────────────────────────────
export const geminiChat = onCall(
  { secrets: [GEMINI_SECRET], region: "me-central1" },
  async (request) => {
    const uid = await assertActiveSubscriber(request);
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
    const uid = await assertActiveSubscriber(request);
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
      mode === "grade" ?
        `أنت مدرس متخصص في مادة ${subject}. صحح الواجب وحدد الأخطاء وأعط علامة وملاحظات تحسين بالعربية.` :
        `أنت مدرس متخصص في مادة ${subject} ${gradeText}. حل المسألة في الصورة خطوة بخطوة بالعربية.`;

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
    const uid = await assertActiveSubscriber(request);
    await checkRateLimit(uid, "chat");

    const { subject, grade, pdfTexts, count = 5 } = request.data as {
      subject: string;
      grade: number;
      pdfTexts: string[];
      count?: number;
    };

    const contextText = pdfTexts?.length ?
      `المحتوى:\n${pdfTexts.join("\n\n")}` :
      `أنشئ ${count} أسئلة شاملة في مادة ${subject} للصف ${grade}.`;

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
    const uid = await assertActiveSubscriber(request);
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

// ── Apple App Store receipt validation (optional) ─────────────────────────
// Configure with: APPLE_SHARED_SECRET in functions/.env (see defineString above).
async function validateAppleReceipt(
  receiptData: string,
  sharedSecret: string,
  productId: string
): Promise<AppleValidation> {
  return validateAppleReceiptWithVerify(receiptData, sharedSecret, productId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 5: activateSubscription — Validate IAP receipt & activate
// ─────────────────────────────────────────────────────────────────────────────
export const activateSubscription = onCall(
  { region: "me-central1" },
  async (request) => {
    const uid = requireAuth(request);

    const { productId, platform, transactionId, userEmail, receiptData, transactionDateMs } = request.data as {
      productId: string;
      platform: "ios" | "android";
      transactionId: string;
      userEmail?: string;
      receiptData?: string;
      transactionDateMs?: number;
    };

    // ── Basic input validation ─────────────────────────────────────────────
    if (!productId || !transactionId) {
      throw new HttpsError("invalid-argument", "بيانات الشراء غير مكتملة.");
    }
    if (!["ios", "android"].includes(platform)) {
      throw new HttpsError("invalid-argument", "منصة غير معروفة.");
    }

    // ── Validate transactionId format ──────────────────────────────────────
    // iOS: numeric string (StoreKit 1), UUID v4 (StoreKit 2), or alphanumeric token (Sandbox/Local)
    // Android: alphanumeric token from Google Play
    if (!transactionId || typeof transactionId !== "string" || !VALID_TX_ID_PATTERN.test(transactionId.trim())) {
      throw new HttpsError("invalid-argument", "معرّف المعاملة غير صالح.");
    }

    const cleanTxId = transactionId.trim();
    const subRef = db.collection("subscriptions").doc(cleanTxId);

    // Ensure productId is known before hitting Firestore or Apple
    computeSubscriptionWindow(productId, null);

    // ── Fast path: this transaction was already activated ─────────────────
    // The subscription document id IS the transaction id, so a single doc read
    // is enough to detect re-use (no separate duplicate query is needed).
    const existing = await subRef.get();
    if (existing.exists && existing.data()?.firebase_uid === uid) {
      // Same user (device switch / restore) — idempotent success.
      // Ensure the user document has the is_subscribed flag set.
      await db.collection("users").doc(uid).update({ is_subscribed: true }).catch(() => undefined);
      const prevExp = existing.data()?.expires_at as admin.firestore.Timestamp | undefined;
      return {
        success: true,
        message: "الاشتراك مفعّل بالفعل.",
        expiresAt: prevExp?.toMillis?.() ?? null,
      };
    }

    // ── Server-side Apple receipt validation (optional) ────────────────────
    // Enabled only when APPLE_SHARED_SECRET is configured and the purchase
    // comes from iOS with a receipt. Android validation is not implemented yet.
    // TODO(android): validate the Google Play purchase token with the Google
    // Play Developer API (purchases.subscriptionsv2.get) before activating.
    const appleSecret = APPLE_SHARED_SECRET.value();
    let apple: AppleValidation | null = null;
    if (appleSecret && platform === "ios" && typeof receiptData === "string" && receiptData.length > 0) {
      apple = await validateAppleReceipt(receiptData, appleSecret, productId);
    } else if (platform === "ios" && !appleSecret) {
      console.warn("APPLE_SHARED_SECRET not set — receipt not validated");
    } else if (platform === "ios" && appleSecret) {
      // Secret configured but the client sent no receipt: keep legacy behaviour.
      console.warn("iOS purchase without receiptData — receipt not validated");
    }
    const validated = apple !== null;
    // The validated receipt must actually contain the transaction being claimed
    // before we allow taking it over from another account.
    const receiptOwnsTx =
      apple !== null &&
      (apple.transactionIds.includes(cleanTxId) ||
        apple.originalTransactionId === cleanTxId);

    // ── Compute expiry ─────────────────────────────────────────────────────
    const nowMs = Date.now();
    const { effectiveDays, startMs, expiresMs } = computeSubscriptionWindow(
      productId,
      apple,
      transactionDateMs,
      nowMs
    );

    const now = Timestamp.now();
    const expiresAt = Timestamp.fromMillis(expiresMs);

    const subData: Record<string, unknown> = {
      firebase_uid: uid,
      user_email: userEmail ?? "",
      product_id: productId,
      platform,
      transaction_id: cleanTxId,
      original_transaction_id: apple?.originalTransactionId ?? "",
      validated_by_apple: validated,
      status: "active",
      plan: productId,
      duration_days: effectiveDays,
      start_date: new Date(startMs).toISOString().substring(0, 10),
      end_date: expiresAt.toDate().toISOString().substring(0, 10),
      created_at: now,
      expires_at: expiresAt,
    };

    // ── Write subscription document (Admin SDK bypasses security rules) ────
    const transfer: { from: string | null } = { from: null };
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(subRef);
      if (snap.exists) {
        const old = snap.data() ?? {};
        if (old.firebase_uid === uid) {
          return; // activated concurrently by the same user — idempotent
        }
        // The transaction belongs to ANOTHER user. Only a receipt validated by
        // Apple that really contains this transaction may take it over.
        if (!receiptOwnsTx) {
          throw new HttpsError("already-exists", "هذه المعاملة مُستخدمة بالفعل من حساب آخر.");
        }
        // The doc id is the transaction id, so archive the previous record
        // under a new id (status: transferred) before overwriting it.
        transfer.from = (old.firebase_uid as string | undefined) ?? null;
        const archiveRef = db.collection("subscriptions").doc(`${cleanTxId}_transferred_${nowMs}`);
        tx.set(archiveRef, {
          ...old,
          status: "transferred",
          transferred_to_uid: uid,
          transferred_at: now,
        });
        subData.transferred_from_uid = transfer.from ?? "";
      }
      tx.set(subRef, subData);
    });

    // Revoke the old owner's flag if the transfer left them with no active plan
    if (transfer.from) {
      try {
        const oldUid: string = transfer.from;
        const stillActive = await db
          .collection("subscriptions")
          .where("firebase_uid", "==", oldUid)
          .where("status", "==", "active")
          .get();
        const hasValid = stillActive.docs.some((d) => {
          const exp = d.data().expires_at as admin.firestore.Timestamp | undefined;
          return !exp || exp.toMillis() > Date.now();
        });
        if (!hasValid) {
          await db.collection("users").doc(oldUid).update({ is_subscribed: false });
        }
      } catch (e) {
        console.warn("Failed to refresh previous owner's subscription flag", e);
      }
    }

    // Update user's is_subscribed flag
    await db.collection("users").doc(uid).update({ is_subscribed: true });

    return { success: true, durationDays: effectiveDays, expiresAt: expiresAt.toMillis() };
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Cloud Function 6: adminSetUserPassword — Admin updates user password
// ─────────────────────────────────────────────────────────────────────────────
export const adminSetUserPassword = onCall(
  { region: "me-central1" },
  async (request) => {
    await requireAdmin(request);
    const { uid, email, newPassword } = request.data as {
      uid?: string;
      email?: string;
      newPassword: string;
    };
    if (!newPassword || typeof newPassword !== "string" || newPassword.length < 6) {
      throw new HttpsError("invalid-argument", "كلمة المرور يجب ألا تقل عن 6 أحرف.");
    }

    let targetUid = uid;
    if (!targetUid && email) {
      const userRecord = await admin.auth().getUserByEmail(email);
      targetUid = userRecord.uid;
    }
    if (!targetUid) {
      throw new HttpsError("not-found", "لم يتم العثور على حساب الطالب.");
    }

    await admin.auth().updateUser(targetUid, { password: newPassword });

    try {
      await db.collection("users").doc(targetUid).update({ password: FieldValue.delete() });
    } catch {
      // legacy plaintext field already removed
    }

    return { success: true };
  }
);

// ── Interactive lessons (slides + TTS + on-demand Q&A) ─────────────────────
export * from "./interactive";
