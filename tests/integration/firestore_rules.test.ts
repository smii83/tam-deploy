import fs from "node:fs";
import path from "node:path";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import firebase from "firebase/compat/app";
import "firebase/compat/firestore";

const PROJECT_ID = "tam-rules-isolated";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  const rules = fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

afterAll(async () => {
  if (testEnv) await testEnv.cleanup();
});

describe("Firestore Security Rules Integration Tests (Isolated Emulator)", () => {
  const serverTs = () => firebase.firestore.FieldValue.serverTimestamp();

  it("denies all unauthenticated reads and writes across sensitive collections", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("users").doc("stu1").set({ name: "Ali", is_subscribed: false });
      await ctx.firestore().collection("subjects").doc("sub1").set({ name_ar: "فيزياء" });
      await ctx.firestore().collection("config").doc("ai_settings").set({ api_key: "secret" });
    });

    const anonDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(anonDb.collection("users").doc("stu1").get());
    await assertFails(anonDb.collection("subjects").doc("sub1").get());
    await assertFails(anonDb.collection("config").doc("ai_settings").get());
    await assertFails(anonDb.collection("users").doc("stu2").set({ name: "Intruder" }));
    await assertFails(anonDb.collection("rate_limits").doc("stu1").set({ chat_count: 0 }));
  });

  it("enforces /users ownership and blocks privilege escalation on create and update", async () => {
    const stu1Db = testEnv.authenticatedContext("stu1", { email: "stu1@test.com" }).firestore();
    const stu2Db = testEnv.authenticatedContext("stu2", { email: "stu2@test.com" }).firestore();

    // Legitimate signup document creation succeeds
    await assertSucceeds(
      stu1Db.collection("users").doc("stu1").set({
        firebase_uid: "stu1",
        name: "سالم",
        email: "stu1@test.com",
        grade: 12,
        is_subscribed: false,
        is_blocked: false,
      })
    );

    // Self-escalation blocked: is_admin, role, is_subscribed: true, is_blocked: true
    await assertFails(
      stu2Db.collection("users").doc("stu2").set({ is_admin: true, is_subscribed: false, is_blocked: false })
    );
    await assertFails(
      stu2Db.collection("users").doc("stu2").set({ role: "admin", is_subscribed: false, is_blocked: false })
    );
    await assertFails(
      stu2Db.collection("users").doc("stu2").set({ is_subscribed: true, is_blocked: false })
    );

    // Cross-user read & update denied
    await assertFails(stu2Db.collection("users").doc("stu1").get());
    await assertFails(stu2Db.collection("users").doc("stu1").update({ name: "hacked" }));

    // Student can update own non-sensitive profile fields, NOT sensitive subscription/block fields
    await assertSucceeds(stu1Db.collection("users").doc("stu1").update({ grade: 11, lang: "en" }));
    await assertFails(stu1Db.collection("users").doc("stu1").update({ is_subscribed: true }));
    await assertFails(stu1Db.collection("users").doc("stu1").update({ is_blocked: true }));
    await assertFails(stu1Db.collection("users").doc("stu1").update({ is_admin: true }));

    // Progress & quiz_results subcollections isolated per owner
    await assertSucceeds(stu1Db.collection("users").doc("stu1").collection("quiz_results").doc("q1").set({ score: 8 }));
    await assertFails(stu1Db.collection("users").doc("stu1").collection("quiz_results").doc("q1").update({ score: 10 }));
    await assertFails(stu2Db.collection("users").doc("stu1").collection("quiz_results").doc("q1").get());
  });

  it("enforces /subscriptions schema, server timestamp, duration<=180, and ownership", async () => {
    const stu1Db = testEnv.authenticatedContext("stu1", { email: "stu1@test.com" }).firestore();
    const stu2Db = testEnv.authenticatedContext("stu2", { email: "stu2@test.com" }).firestore();
    const adminDb = testEnv.authenticatedContext("adm1", { email: "admin@tam.com" }).firestore();

    const validSub = {
      user_email: "stu1@test.com",
      firebase_uid: "stu1",
      plan: "tam_6months_12kwd",
      product_id: "tam_6months_12kwd",
      platform: "android",
      transaction_id: "tx_ok_1",
      status: "active",
      duration_days: 180,
      start_date: "2026-11-13",
      end_date: "2027-05-12",
      created: serverTs(),
    };

    // Valid client creation matching doc id == transaction_id succeeds
    await assertSucceeds(stu1Db.collection("subscriptions").doc("tx_ok_1").set(validSub));

    // Doc id mismatch rejected
    await assertFails(
      stu1Db.collection("subscriptions").doc("wrong_id").set({ ...validSub, transaction_id: "tx_mismatch" })
    );
    // Duration > 180 rejected from client
    await assertFails(
      stu1Db
        .collection("subscriptions")
        .doc("tx_over")
        .set({ ...validSub, transaction_id: "tx_over", plan: "tam_1year", duration_days: 365 })
    );
    // Forging validated_by_apple extra field rejected
    await assertFails(
      stu1Db
        .collection("subscriptions")
        .doc("tx_extra")
        .set({ ...validSub, transaction_id: "tx_extra", validated_by_apple: true })
    );
    // Cross-user read & client update rejected; admin update allowed
    await assertFails(stu2Db.collection("subscriptions").doc("tx_ok_1").get());
    await assertFails(stu1Db.collection("subscriptions").doc("tx_ok_1").update({ duration_days: 999 }));
    await assertSucceeds(adminDb.collection("subscriptions").doc("tx_ok_1").update({ status: "cancelled" }));
  });

  it("restricts curriculum catalog writes & server-only collections to admins / Admin SDK", async () => {
    const stuDb = testEnv.authenticatedContext("stu1", { email: "stu1@test.com" }).firestore();
    const adminDb = testEnv.authenticatedContext("adm1", { email: "tam.app83@gmail.com" }).firestore();

    await assertSucceeds(adminDb.collection("subjects").doc("phy12").set({ name_ar: "فيزياء", grade: 12 }));
    await assertSucceeds(stuDb.collection("subjects").doc("phy12").get());
    await assertFails(stuDb.collection("subjects").doc("phy12").update({ name_ar: "تعديل" }));

    // Server-only collections deny even admin client writes
    await assertFails(adminDb.collection("rate_limits").doc("stu1").set({ chat_count: 0 }));
    await assertFails(adminDb.collection("lesson_qa_cache").doc("k1").set({ answer: "x" }));
    await assertFails(adminDb.collection("admins").doc("adm1").set({ email: "admin@tam.com" }));
  });
});

