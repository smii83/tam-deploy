import * as admin from "firebase-admin";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

/**
 * Shared admin allowlist (kept aligned with Firestore/Storage rules & web admin).
 */
export const ADMIN_EMAILS = [
  "tam.app83@gmail.com",
  "tm.app83@gmail.com",
  "tamteach01@gmail.com",
  "admin@tam.com",
  "admin@eduspark.com",
];

/**
 * Ensures the callable request has an authenticated Firebase Auth user.
 * @param {CallableRequest} request Incoming callable request.
 * @return {string} The authenticated user's UID.
 */
export function requireAuth(request: CallableRequest): string {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً.");
  }
  return request.auth.uid;
}

/**
 * Checks whether the caller is an administrator via allowlisted email
 * or an `admins/{uid}` document.
 * @param {CallableRequest} request Incoming callable request.
 * @return {Promise<boolean>} True if caller is an admin.
 */
export async function isAdminCaller(request: CallableRequest): Promise<boolean> {
  const uid = requireAuth(request);
  const email = String(request.auth?.token?.email ?? "").toLowerCase().trim();
  if (ADMIN_EMAILS.includes(email)) {
    return true;
  }
  const adminDoc = await admin.firestore().collection("admins").doc(uid).get();
  return adminDoc.exists;
}

/**
 * Requires that the caller is an administrator.
 * @param {CallableRequest} request Incoming callable request.
 * @return {Promise<string>} The authenticated admin's UID.
 */
export async function requireAdmin(request: CallableRequest): Promise<string> {
  const uid = requireAuth(request);
  if (!(await isAdminCaller(request))) {
    throw new HttpsError("permission-denied", "هذه العملية مخصصة للمشرفين فقط.");
  }
  return uid;
}

/**
 * Ensures the caller is signed in, not blocked, and either an admin or
 * holds an active (unexpired) subscription.
 * @param {CallableRequest} request Incoming callable request.
 * @return {Promise<string>} The authenticated user's UID.
 */
export async function assertActiveSubscriber(
  request: CallableRequest
): Promise<string> {
  const uid = requireAuth(request);
  const db = admin.firestore();
  const userSnap = await db.collection("users").doc(uid).get();
  const userData = userSnap.data();

  if (userData?.is_blocked === true) {
    throw new HttpsError(
      "permission-denied",
      "تم إيقاف هذا الحساب. يرجى التواصل مع الدعم."
    );
  }

  if (await isAdminCaller(request)) {
    return uid;
  }

  const subsSnap = await db
    .collection("subscriptions")
    .where("firebase_uid", "==", uid)
    .where("status", "==", "active")
    .get();

  const nowMs = Date.now();
  const todayIso = new Date(nowMs).toISOString().substring(0, 10);

  if (!subsSnap.empty) {
    const hasActive = subsSnap.docs.some((doc) => {
      const d = doc.data();
      const exp = d.expires_at as admin.firestore.Timestamp | undefined;
      if (exp && typeof exp.toMillis === "function") {
        return exp.toMillis() > nowMs;
      }
      if (typeof d.end_date === "string" && d.end_date.length >= 10) {
        return d.end_date.substring(0, 10) >= todayIso;
      }
      return true;
    });
    if (hasActive) {
      return uid;
    }
    throw new HttpsError(
      "permission-denied",
      "انتهت صلاحية اشتراكك. يرجى تجديد الاشتراك للمتابعة."
    );
  }

  if (userData?.is_subscribed === true) {
    return uid;
  }

  throw new HttpsError("permission-denied", "هذه الميزة متاحة للمشتركين فقط.");
}
