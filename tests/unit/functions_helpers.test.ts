import { describe, it, expect, vi } from "vitest";
import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import {
  APPLE_PROD_URL,
  APPLE_SANDBOX_URL,
  MODEL_CANDIDATES,
  PRODUCT_DURATIONS,
  RATE_LIMITS,
  VALID_TX_ID_PATTERN,
  checkRateLimitWithDb,
  cleanPcm,
  collectSegments,
  computeSubscriptionWindow,
  dialectFor,
  normSection,
  normVersion,
  normalizeAr,
  normalizeContent,
  plain,
  sha1,
  str,
  teacherPersonality,
  totalDuration,
  tryModelsWithDelay,
  validateAppleReceiptWithVerify,
  type LessonContent,
} from "../../functions/src/logic";
import { ADMIN_EMAILS, requireAuth } from "../../functions/src/auth";

// Helper to build a synthetic 16-bit mono PCM buffer
function makeSinePcm(rate: number, seconds: number, freq = 440, amp = 0.5): Buffer {
  const n = Math.round(rate * seconds);
  const buf = Buffer.alloc(n * 2);
  for (let i = 0; i < n; i++) {
    const sample = Math.round(Math.sin((2 * Math.PI * freq * i) / rate) * amp * 32767);
    buf.writeInt16LE(Math.max(-32768, Math.min(32767, sample)), i * 2);
  }
  return buf;
}

describe("Pure String & Normalization Helpers (functions/src/logic.ts)", () => {
  it("sha1 produces deterministic 40-char lowercase hex hashes", () => {
    const h1 = sha1("hello|درس");
    const h2 = sha1("hello|درس");
    expect(h1).toBe(h2);
    expect(h1).toMatch(/^[a-f0-9]{40}$/);
    expect(sha1("")).toBe("da39a3ee5e6b4b0d3255bfef95601890afd80709");
  });

  it("str trims strings, truncates to max length, and coerces non-strings to empty", () => {
    expect(str("  مرحبا  ")).toBe("مرحبا");
    expect(str("abcdef", 3)).toBe("abc");
    expect(str(null)).toBe("");
    expect(str(undefined)).toBe("");
    expect(str(12345)).toBe("");
    expect(str({ a: 1 })).toBe("");
  });

  it("plain strips [[...]] concept markers without removing inner text", () => {
    expect(plain("قانون [[نيوتن]] الأول")).toBe("قانون نيوتن الأول");
    expect(plain("لا علامات")).toBe("لا علامات");
    expect(plain("")).toBe("");
  });

  it("normalizeAr strips diacritics, normalizes alef/ya/taa, collapses spaces", () => {
    expect(normalizeAr("  أَحْمَدُ إلى مَدْرَسَةٍ  ")).toBe("احمد الي مدرسه");
    expect(normalizeAr("الآيَةُ ١٢!")).toBe("الايه ١٢");
    expect(normalizeAr("   ")).toBe("");
  });

  it("dialectFor and teacherPersonality map Gulf dialects with safe Kuwait default", () => {
    expect(dialectFor("kw")).toContain("كويتية");
    expect(dialectFor("sa")).toContain("سعودية");
    expect(dialectFor("ae")).toContain("إماراتية");
    expect(dialectFor("unknown")).toContain("كويتية");
    expect(dialectFor("")).toContain("كويتية");
    expect(teacherPersonality("sa")).toContain("سعودية");
  });
});

describe("Interactive Lesson Normalization & Duration", () => {
  it("normSection rejects invalid inputs and coerces invalid types to 'section'", () => {
    expect(normSection(null)).toBeNull();
    expect(normSection("str")).toBeNull();
    expect(normSection({ heading: "  ", content: "" })).toBeNull();

    const s1 = normSection({ type: "bogus", heading: "عنوان [[مهم]]", content: "شرح" });
    expect(s1).toEqual({
      type: "section",
      heading: "عنوان [[مهم]]",
      content: "شرح",
      narration: "عنوان مهم. شرح",
    });

    const f1 = normSection({ type: "formula", heading: "F=ma", content: "القوة", narration: "[[القوة]] تساوي" });
    expect(f1?.type).toBe("formula");
    expect(f1?.narration).toBe("القوة تساوي");
  });

  it("normVersion enforces forceNoHook, handles legacy string zubda, and keeps valid hook", () => {
    const raw = {
      hook: { available: true, text: "سؤال 2024", narration: "انتبه" },
      sections: [{ type: "example", heading: "مثال", content: "حل" }, null],
      zubda: "خلاصة سريعة",
    };

    const forcedNoHook = normVersion(raw, true);
    expect(forcedNoHook.hook).toEqual({ available: false, text: null, narration: null });
    expect(forcedNoHook.sections).toHaveLength(1);
    expect(forcedNoHook.zubda).toEqual({ text: "خلاصة سريعة", narration: "خلاصة سريعة" });

    const withHook = normVersion(raw, false);
    expect(withHook.hook.available).toBe(true);
    expect(withHook.hook.text).toBe("سؤال 2024");

    const emptyHookText = normVersion({ hook: { available: true, text: "   " } }, false);
    expect(emptyHookText.hook.available).toBe(false);
  });

  it("normalizeContent throws EMPTY_LESSON when kamila has no sections and derives mukhtasar fallback", () => {
    expect(() => normalizeContent({}, "درس تجريبي", "الفيزياء")).toThrow("EMPTY_LESSON");

    const raw = {
      versions: {
        kamila: {
          hook: { available: true, text: "سؤال سابق" },
          sections: [
            { type: "section", heading: "1", content: "مفهوم" },
            { type: "example", heading: "مثال محذوف", content: "تطبيق" },
            { type: "formula", heading: "2", content: "قانون" },
          ],
          zubda: { text: "ملخص", narration: "" },
        },
        mukhtasar: { sections: [] },
      },
    };

    const normalized = normalizeContent(raw, "عنوان احتياطي", "فيزياء");
    expect(normalized.title).toBe("عنوان احتياطي");
    expect(normalized.subject).toBe("فيزياء");
    expect(normalized.common.welcome.narration).toContain("منصة تَم");
    // Derived mukhtasar drops examples & strips hook
    expect(normalized.versions.mukhtasar.hook.available).toBe(false);
    expect(normalized.versions.mukhtasar.sections.map((s) => s.type)).toEqual(["section", "formula"]);
    expect(normalized.versions.mukhtasar.zubda.narration).toBe("ملخص");
  });

  it("collectSegments and totalDuration aggregate only non-empty narrations and round duration", () => {
    const lesson: LessonContent = {
      title: "الحركة",
      subject: "فيزياء",
      common: {
        welcome: { narration: "أهلا", audio: { path: "a.mp3", duration: 2.3 } },
        intro: { narration: "مقدمة", audio: { path: "b.mp3", duration: 3.4 } },
      },
      versions: {
        mukhtasar: {
          hook: { available: false, text: "hidden", narration: "should not count", audio: { path: "h.mp3", duration: 10 } },
          sections: [{ type: "section", heading: "1", content: "c", narration: "ن1", audio: { path: "s1.mp3", duration: 4.1 } }],
          zubda: { text: "z", narration: "   " },
        },
        kamila: {
          hook: { available: true, text: "h", narration: "هوك", audio: { path: "hk.mp3", duration: 5.2 } },
          sections: [{ type: "formula", heading: "2", content: "c2", narration: "ن2" }],
          zubda: { text: "z2", narration: "زبدة", audio: { path: "z.mp3", duration: 1.9 } },
        },
      },
    };

    const segs = collectSegments(lesson);
    // welcome + intro + mukhtasar.s1 + kamila.hook + kamila.s2 + kamila.zubda = 6 (skipped mukhtasar hook + blank zubda)
    expect(segs).toHaveLength(6);
    expect(totalDuration(lesson, "mukhtasar")).toBe(Math.round(2.3 + 3.4 + 4.1));
    expect(totalDuration(lesson, "kamila")).toBe(Math.round(2.3 + 3.4 + 5.2 + 0 + 1.9));
  });
});

describe("cleanPcm Audio DSP Helper", () => {
  it("handles empty buffers and invalid/negative sample rates safely", () => {
    const emptyOut = cleanPcm(Buffer.alloc(0), 24000);
    expect(emptyOut).toBeInstanceOf(Int16Array);
    expect(emptyOut.length).toBe(6000); // 0.25s tail

    const badRate = cleanPcm(makeSinePcm(24000, 0.2), -100);
    expect(badRate.length).toBe(0);
  });

  it("clamps amplitude strictly within [-32000, 32000] and adds silent fade tail", () => {
    const raw = makeSinePcm(24000, 0.5, 300, 1.0);
    const cleaned = cleanPcm(raw, 24000);
    expect(cleaned.length).toBeGreaterThan(24000 * 0.25);

    let maxAbs = 0;
    for (let i = 0; i < cleaned.length; i++) {
      maxAbs = Math.max(maxAbs, Math.abs(cleaned[i]));
    }
    expect(maxAbs).toBeLessThanOrEqual(32000);
    expect(maxAbs).toBeGreaterThan(1000);

    // Silent tail at end (last 0.2s) must be exact zero
    const tailSlice = cleaned.subarray(cleaned.length - 4000);
    expect(tailSlice.every((s) => s === 0)).toBe(true);
  });
});

describe("Subscription Pricing, Validation & Receipt Helpers", () => {
  it("VALID_TX_ID_PATTERN accepts valid store tx IDs and blocks traversal/empty/oversized", () => {
    expect(VALID_TX_ID_PATTERN.test("GPA.3312-9988-0011")).toBe(true);
    expect(VALID_TX_ID_PATTERN.test("1000000912345678")).toBe(true);
    expect(VALID_TX_ID_PATTERN.test("")).toBe(false);
    expect(VALID_TX_ID_PATTERN.test("tx with spaces")).toBe(false);
    expect(VALID_TX_ID_PATTERN.test("../admin/hack")).toBe(false);
    expect(VALID_TX_ID_PATTERN.test("a".repeat(129))).toBe(false);
  });

  it("computeSubscriptionWindow maps all plan durations and handles edge cases", () => {
    const now = 1_700_000_000_000;
    const DAY = 86_400_000;

    expect(PRODUCT_DURATIONS).toEqual({
      tam_1month: 30,
      tam_3months: 90,
      tam_6months: 180,
      tam_6months_12kwd: 180,
      tam_1year: 365,
    });

    expect(() => computeSubscriptionWindow("tam_invalid", null, undefined, now)).toThrow(HttpsError);

    const fresh = computeSubscriptionWindow("tam_1month", null, undefined, now);
    expect(fresh.durationDays).toBe(30);
    expect(fresh.effectiveDays).toBe(30);
    expect(fresh.expiresMs).toBe(now + 30 * DAY);

    // Restored purchase started 10 days ago => 20 effective days left
    const restored = computeSubscriptionWindow("tam_1month", null, now - 10 * DAY, now);
    expect(restored.effectiveDays).toBe(20);
    expect(restored.expiresMs).toBe(now + 20 * DAY);

    // Restored purchase from 40 days ago for 30-day plan => expired!
    expect(() => computeSubscriptionWindow("tam_1month", null, now - 40 * DAY, now)).toThrow(
      /الاشتراك منتهي/
    );

    // Implausible timestamp (>400 days old) falls back to fresh window
    const ancient = computeSubscriptionWindow("tam_1month", null, now - 500 * DAY, now);
    expect(ancient.effectiveDays).toBe(30);

    // Apple-validated expiry is capped at plan + 7 days
    const apple = { expiresMs: now + 500 * DAY, originalTransactionId: "orig", transactionIds: ["orig"] };
    const capped = computeSubscriptionWindow("tam_1month", apple, undefined, now);
    expect(capped.effectiveDays).toBe(37);
  });

  it("validateAppleReceiptWithVerify falls back to sandbox on 21007 and handles error codes", async () => {
    const now = 1_700_000_000_000;
    const futureExp = String(now + 10 * 86_400_000);
    const pastExp = String(now - 10_000);

    // 1. Prod returns 21007 -> retry Sandbox -> status 0
    const urlsCalled: string[] = [];
    const sandboxResult = await validateAppleReceiptWithVerify(
      "rcpt",
      "secret",
      "tam_1month",
      async (url) => {
        urlsCalled.push(url);
        if (url === APPLE_PROD_URL) return { status: 21007 };
        return {
          status: 0,
          latest_receipt_info: [
            { product_id: "tam_1month", expires_date_ms: futureExp, transaction_id: "tx1", original_transaction_id: "orig1" },
          ],
        };
      },
      now
    );
    expect(urlsCalled).toEqual([APPLE_PROD_URL, APPLE_SANDBOX_URL]);
    expect(sandboxResult.originalTransactionId).toBe("orig1");
    expect(sandboxResult.transactionIds).toContain("tx1");

    // 2. Temporary 21005 / 21150 -> unavailable
    await expect(
      validateAppleReceiptWithVerify("rcpt", "sec", "tam_1month", async () => ({ status: 21005 }), now)
    ).rejects.toMatchObject({ code: "unavailable" });
    await expect(
      validateAppleReceiptWithVerify("rcpt", "sec", "tam_1month", async () => ({ status: 21150 }), now)
    ).rejects.toMatchObject({ code: "unavailable" });

    // 3. Wrong secret 21004 -> internal
    await expect(
      validateAppleReceiptWithVerify("rcpt", "bad", "tam_1month", async () => ({ status: 21004 }), now)
    ).rejects.toMatchObject({ code: "internal" });

    // 4. Other rejection status / mismatched product / expired -> permission-denied
    await expect(
      validateAppleReceiptWithVerify("rcpt", "sec", "tam_1month", async () => ({ status: 21002 }), now)
    ).rejects.toMatchObject({ code: "permission-denied" });
    await expect(
      validateAppleReceiptWithVerify(
        "rcpt",
        "sec",
        "tam_1month",
        async () => ({ status: 0, latest_receipt_info: [{ product_id: "other", expires_date_ms: futureExp }] }),
        now
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
    await expect(
      validateAppleReceiptWithVerify(
        "rcpt",
        "sec",
        "tam_1month",
        async () => ({ status: 0, latest_receipt_info: [{ product_id: "tam_1month", expires_date_ms: pastExp }] }),
        now
      )
    ).rejects.toMatchObject({ code: "permission-denied" });
  });
});

describe("Gemini Fallback & Rate Limiter", () => {
  it("tryModelsWithDelay falls back across candidates and backs off on 429", async () => {
    const tried: string[] = [];
    const delays: number[] = [];
    const answer = await tryModelsWithDelay(
      async (model) => {
        tried.push(model);
        if (model === MODEL_CANDIDATES[0]) throw new Error("HTTP 429 Too Many Requests");
        if (model === MODEL_CANDIDATES[1]) return "   "; // empty ignored
        return "إجابة صحيحة";
      },
      async (ms) => {
        delays.push(ms);
      }
    );

    expect(tried).toEqual(MODEL_CANDIDATES);
    expect(delays).toEqual([2000]);
    expect(answer).toBe("إجابة صحيحة");

    await expect(
      tryModelsWithDelay(async () => {
        throw new Error("500");
      }, async () => undefined)
    ).rejects.toMatchObject({ code: "unavailable" });
  });

  it("checkRateLimitWithDb enforces hourly quota and resets expired windows", async () => {
    const store = new Map<string, Record<string, unknown>>();
    const mockDb = {
      collection: () => ({
        doc: (id: string) => ({ id }),
      }),
      runTransaction: async (fn: (tx: unknown) => Promise<void>) => {
        const tx = {
          get: async (ref: { id: string }) => ({
            data: () => store.get(ref.id),
          }),
          set: (ref: { id: string }, data: Record<string, unknown>) => {
            store.set(ref.id, { ...data });
          },
          update: (ref: { id: string }, data: Record<string, unknown>) => {
            store.set(ref.id, { ...(store.get(ref.id) ?? {}), ...data });
          },
        };
        await fn(tx);
      },
    } as unknown as admin.firestore.Firestore;

    const t0 = 1_000_000;
    for (let i = 0; i < RATE_LIMITS.image.maxPerHour; i++) {
      await checkRateLimitWithDb(mockDb, "u1", "image", t0 + i * 100);
    }
    expect(store.get("u1")?.image_count).toBe(15);

    // 16th within same hour is rejected
    await expect(
      checkRateLimitWithDb(mockDb, "u1", "image", t0 + 5000)
    ).rejects.toMatchObject({ code: "resource-exhausted" });

    // After 1 hour (+3_600_001ms), window resets cleanly
    await checkRateLimitWithDb(mockDb, "u1", "image", t0 + 3_600_001);
    expect(store.get("u1")?.image_count).toBe(1);
    expect(store.get("u1")?.chat_count).toBe(0);
  });

  it("requireAuth validates caller UID and ADMIN_EMAILS includes core admin accounts", () => {
    expect(ADMIN_EMAILS).toContain("admin@tam.com");
    expect(() => requireAuth({ auth: undefined } as never)).toThrow(/يجب تسجيل الدخول/);
    expect(requireAuth({ auth: { uid: "stu_123" } } as never)).toBe("stu_123");
    const spy = vi.fn();
    spy();
    expect(spy).toHaveBeenCalledTimes(1);
  });
});
