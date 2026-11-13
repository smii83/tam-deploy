import crypto from "node:crypto";
import admin from "firebase-admin";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const PROJECT_ID = "tam-app-fd30f";
const AUTH_URL = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";
const FUNCTIONS_BASE = `http://127.0.0.1:5001/${PROJECT_ID}/me-central1`;

function sha1(s: string): string {
  return crypto.createHash("sha1").update(s).digest("hex");
}

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

async function createAuthUser(email: string, password: string): Promise<{ uid: string; idToken: string }> {
  const res = await fetch(`${AUTH_URL}/accounts:signUp?key=fake-api-key`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  if (!res.ok) throw new Error(`Failed to create emulator user ${email}: ${await res.text()}`);
  const data = (await res.json()) as { localId: string; idToken: string };
  return { uid: data.localId, idToken: data.idToken };
}

async function signInAuthUser(email: string, password: string): Promise<{ uid: string; idToken: string }> {
  const res = await fetch(`${AUTH_URL}/accounts:signInWithPassword?key=fake-api-key`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const body = (await res.json()) as { localId?: string; idToken?: string; error?: { message: string } };
  if (!res.ok || !body.idToken) {
    throw new Error(body.error?.message || `HTTP ${res.status}`);
  }
  return { uid: body.localId!, idToken: body.idToken };
}

async function callCallable<T = unknown>(
  name: string,
  data: Record<string, unknown>,
  idToken?: string
): Promise<{ status: number; body: { result?: T; error?: { status?: string; message?: string } } }> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (idToken) headers.Authorization = `Bearer ${idToken}`;
  const res = await fetch(`${FUNCTIONS_BASE}/${name}`, {
    method: "POST",
    headers,
    body: JSON.stringify({ data }),
  });
  const body = (await res.json()) as { result?: T; error?: { status?: string; message?: string } };
  return { status: res.status, body };
}

describe("Cloud Functions <-> Auth <-> Firestore Emulator Integration Tests", () => {
  let db: admin.firestore.Firestore;
  const createdUids: string[] = [];

  let student1: { uid: string; idToken: string };
  let student2: { uid: string; idToken: string };
  let blockedStudent: { uid: string; idToken: string };
  let adminUser: { uid: string; idToken: string };

  beforeAll(async () => {
    if (!admin.apps.length) {
      admin.initializeApp({ projectId: PROJECT_ID });
    }
    db = admin.firestore();

    const suffix = Date.now();
    student1 = await createAuthUser(`int_stu1_${suffix}@test.com`, "Pass1234!");
    student2 = await createAuthUser(`int_stu2_${suffix}@test.com`, "Pass1234!");
    blockedStudent = await createAuthUser(`int_blocked_${suffix}@test.com`, "Pass1234!");
    adminUser = await createAuthUser(`tam.app83@gmail.com`, "AdminPass123!").catch(async () =>
      signInAuthUser(`tam.app83@gmail.com`, "AdminPass123!")
    );

    createdUids.push(student1.uid, student2.uid, blockedStudent.uid, adminUser.uid);

    await Promise.all([
      db.collection("users").doc(student1.uid).set({
        firebase_uid: student1.uid,
        name: "طالب تكامل 1",
        email: `int_stu1_${suffix}@test.com`,
        grade: 12,
        is_subscribed: false,
        is_blocked: false,
        password: "legacy-plaintext-password",
      }),
      db.collection("users").doc(student2.uid).set({
        firebase_uid: student2.uid,
        name: "طالب تكامل 2",
        email: `int_stu2_${suffix}@test.com`,
        grade: 12,
        is_subscribed: false,
        is_blocked: false,
      }),
      db.collection("users").doc(blockedStudent.uid).set({
        firebase_uid: blockedStudent.uid,
        name: "طالب محظور",
        email: `int_blocked_${suffix}@test.com`,
        grade: 12,
        is_subscribed: true,
        is_blocked: true,
      }),
    ]);
  });

  afterAll(async () => {
    for (const uid of createdUids) {
      await admin.auth().deleteUser(uid).catch(() => undefined);
      await db.collection("users").doc(uid).delete().catch(() => undefined);
      await db.collection("rate_limits").doc(uid).delete().catch(() => undefined);
    }
    await db.collection("subscriptions").doc("tx_integration_001").delete().catch(() => undefined);
  });

  it("rejects unauthenticated requests to protected Cloud Functions", async () => {
    const res1 = await callCallable("activateSubscription", { productId: "tam_1month", transactionId: "tx0" });
    expect(res1.status).toBe(401);
    expect(res1.body.error?.status).toBe("UNAUTHENTICATED");

    const res2 = await callCallable("adminSetUserPassword", { uid: student1.uid, newPassword: "NewPassword1!" });
    expect(res2.status).toBe(401);

    const res3 = await callCallable("lessonAsk", { pdfId: "p1", heading: "h", content: "c", question: "q" });
    expect(res3.status).toBe(401);
  });

  it("rejects non-subscribed and blocked students from premium AI endpoints", async () => {
    const unsubRes = await callCallable(
      "lessonAsk",
      { pdfId: "pdf_int", heading: "القوة", content: "F=ma", question: "ما هي الوحدة؟" },
      student1.idToken
    );
    expect(unsubRes.status).toBe(403);
    expect(unsubRes.body.error?.status).toBe("PERMISSION_DENIED");

    const blockedRes = await callCallable(
      "lessonAsk",
      { pdfId: "pdf_int", heading: "القوة", content: "F=ma", question: "ما هي الوحدة؟" },
      blockedStudent.idToken
    );
    expect(blockedRes.status).toBe(403);
    expect(blockedRes.body.error?.status).toBe("PERMISSION_DENIED");
  });

  it("activates subscription, persists DB records, blocks cross-account claim, and supports restore", async () => {
    const txId = "tx_integration_001";

    // Invalid plan rejected cleanly
    const badPlan = await callCallable(
      "activateSubscription",
      { productId: "unknown_plan", transactionId: txId, platform: "android" },
      student1.idToken
    );
    expect(badPlan.status).toBe(400);

    // Valid activation updates both /subscriptions and /users
    const act = await callCallable<{ success: boolean; durationDays: number; expiresAt: number }>(
      "activateSubscription",
      { productId: "tam_6months_12kwd", transactionId: txId, platform: "android" },
      student1.idToken
    );
    expect(act.status).toBe(200);
    expect(act.body.result?.success).toBe(true);
    expect(act.body.result?.durationDays).toBe(180);

    const subDoc = await db.collection("subscriptions").doc(txId).get();
    expect(subDoc.exists).toBe(true);
    expect(subDoc.data()?.firebase_uid).toBe(student1.uid);
    expect(subDoc.data()?.status).toBe("active");

    const userDoc = await db.collection("users").doc(student1.uid).get();
    expect(userDoc.data()?.is_subscribed).toBe(true);

    // Second student attempting to hijack the transaction is blocked
    const hijack = await callCallable(
      "activateSubscription",
      { productId: "tam_6months_12kwd", transactionId: txId, platform: "android" },
      student2.idToken
    );
    expect(hijack.status).toBe(409);
    expect(hijack.body.error?.status).toBe("ALREADY_EXISTS");

    // Original student restoring same purchase is idempotent
    const restore = await callCallable<{ success: boolean; message: string }>(
      "activateSubscription",
      { productId: "tam_6months_12kwd", transactionId: txId, platform: "android" },
      student1.idToken
    );
    expect(restore.status).toBe(200);
    expect(restore.body.result?.success).toBe(true);
  });

  it("allows newly subscribed student to hit lessonAsk Firestore Q&A cache and records rate limit", async () => {
    const pdfId = "pdf_cache_int";
    const heading = "قانون [[نيوتن]] الثاني";
    const content = "القوة تساوي الكتلة ضرب التسارع";
    const question = "ما وحدة القوة؟";

    const slideKey = sha1(normalizeAr(`${heading} ${content}`)).slice(0, 12);
    const cacheKey = sha1(`${pdfId}|${slideKey}|${normalizeAr(question)}`);

    await db.collection("lesson_qa_cache").doc(cacheKey).set({
      pdf_id: pdfId,
      slide_key: slideKey,
      question,
      answer: "وحدة قياس القوة هي النيوتن.",
    });

    const res = await callCallable<{ answer: string; cached: boolean }>(
      "lessonAsk",
      { pdfId, heading, content, question, country: "kw" },
      student1.idToken
    );
    expect(res.status).toBe(200);
    expect(res.body.result?.cached).toBe(true);
    expect(res.body.result?.answer).toContain("النيوتن");

    await db.collection("lesson_qa_cache").doc(cacheKey).delete();
  });

  it("restricts adminSetUserPassword to admins and updates Firebase Auth + strips legacy field", async () => {
    // Non-admin blocked
    const nonAdminAttempt = await callCallable(
      "adminSetUserPassword",
      { uid: student2.uid, newPassword: "HackPassword123!" },
      student1.idToken
    );
    expect(nonAdminAttempt.status).toBe(403);
    expect(nonAdminAttempt.body.error?.status).toBe("PERMISSION_DENIED");

    // Weak password rejected
    const weakAttempt = await callCallable(
      "adminSetUserPassword",
      { uid: student1.uid, newPassword: "123" },
      adminUser.idToken
    );
    expect(weakAttempt.status).toBe(400);

    // Valid admin reset updates Auth emulator password and removes legacy Firestore password field
    const adminAttempt = await callCallable<{ success: boolean }>(
      "adminSetUserPassword",
      { uid: student1.uid, newPassword: "NewStrongPass99!" },
      adminUser.idToken
    );
    expect(adminAttempt.status).toBe(200);
    expect(adminAttempt.body.result?.success).toBe(true);

    const updatedUserDoc = await db.collection("users").doc(student1.uid).get();
    expect(updatedUserDoc.data()?.password).toBeUndefined();

    const studentEmail = updatedUserDoc.data()?.email as string;
    const loginRes = await signInAuthUser(studentEmail, "NewStrongPass99!");
    expect(loginRes.uid).toBe(student1.uid);
  });
});

