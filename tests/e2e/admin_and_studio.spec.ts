import { test, expect } from "@playwright/test";
import admin from "firebase-admin";

const PROJECT_ID = "tam-app-fd30f";
const AUTH_URL = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";

// Ensure admin SDK talks exclusively to local emulators inside Playwright runner
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:9199";

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

async function ensureAuthUser(email: string, password: string): Promise<string> {
  try {
    const existing = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(existing.uid, { password });
    return existing.uid;
  } catch {
    const res = await fetch(`${AUTH_URL}/accounts:signUp?key=fake-api-key`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: false }),
    });
    const body = (await res.json()) as { localId: string };
    return body.localId;
  }
}

test.describe("TAM Web E2E Tests (Playwright + Isolated Firebase Emulator)", () => {
  const adminEmail = "admin@tam.com";
  const adminPass = "AdminE2E!123";
  const nonAdminEmail = "student_e2e_blocked@test.com";
  const nonAdminPass = "StudentE2E!123";
  const createdStudentEmail = `e2e_student_${Date.now()}@test.com`;
  let nonAdminUid = "";
  let gradeDocId = "e2e_grade_12";

  test.beforeAll(async () => {
    await ensureAuthUser(adminEmail, adminPass);
    nonAdminUid = await ensureAuthUser(nonAdminEmail, nonAdminPass);
    await db.collection("grades").doc(gradeDocId).set({
      name_ar: "الصف الثاني عشر (تجريبي)",
      name_en: "Grade 12 Test",
      grade_number: 12,
      section: "scientific",
      is_visible: true,
    });
  });

  test.afterAll(async () => {
    // Clean seeded records
    const subs = await db.collection("subjects").where("name_ar", "==", "الفيزياء المتقدمة E2E").get();
    for (const d of subs.docs) await d.ref.delete();
    const les = await db.collection("lessons").where("title_ar", "==", "قانون نيوتن E2E").get();
    for (const d of les.docs) await d.ref.delete();
    const stuDocs = await db.collection("users").where("email", "==", createdStudentEmail).get();
    for (const d of stuDocs.docs) {
      await admin.auth().deleteUser(d.id).catch(() => undefined);
      await d.ref.delete();
    }
    const subRecords = await db.collection("subscriptions").where("user_email", "==", createdStudentEmail).get();
    for (const d of subRecords.docs) await d.ref.delete();
    await db.collection("grades").doc(gradeDocId).delete().catch(() => undefined);
    if (nonAdminUid) await admin.auth().deleteUser(nonAdminUid).catch(() => undefined);
  });

  let blockedLiveUrls: string[] = [];

  test.beforeEach(async ({ page }) => {
    blockedLiveUrls = [];
    // Isolate from live Firebase Cloud & allow local Emulator ports under Hosting CSP in Chromium
    await page.route("**/*", async (route) => {
      const req = route.request();
      const url = req.url();
      const isLocalEmulator =
        url.startsWith("http://127.0.0.1:") || url.startsWith("http://localhost:");
      if (
        !isLocalEmulator &&
        (url.includes("firestore.googleapis.com") ||
          url.includes("identitytoolkit.googleapis.com") ||
          url.includes("securetoken.googleapis.com"))
      ) {
        blockedLiveUrls.push(url);
        return route.abort("blockedbyclient");
      }
      if (req.resourceType() === "document" && url.startsWith("http://127.0.0.1:5000")) {
        const response = await route.fetch();
        const headers = { ...response.headers() };
        if (headers["content-security-policy"]) {
          headers["content-security-policy"] = headers["content-security-policy"].replace(
            "connect-src 'self' https:",
            "connect-src 'self' https: http://127.0.0.1:* http://localhost:* ws://127.0.0.1:* ws://localhost:*"
          );
        }
        return route.fulfill({ response, headers });
      }
      return route.continue();
    });
  });

  test.afterEach(() => {
    expect(blockedLiveUrls, "No live Google Firebase cloud requests permitted in E2E").toEqual([]);
  });

  test("rejects invalid login and non-admin student account on Admin Dashboard", async ({ page }) => {
    await page.goto("/?emulator=1");
    await expect(page.locator("#loginScreen")).toBeVisible();
    await expect(page.locator("#dashboard")).toHaveClass(/hidden/);

    // Empty submit / bad password shows login error
    await page.fill("#loginEmail", adminEmail);
    await page.fill("#loginPassword", "WrongPass999!");
    await page.click('#loginScreen button[onclick="doLogin()"]');
    await expect(page.locator("#loginError")).not.toHaveClass(/hidden/);

    // Non-admin valid Auth user is rejected from Admin Dashboard
    await page.fill("#loginEmail", nonAdminEmail);
    await page.fill("#loginPassword", nonAdminPass);
    await page.click('#loginScreen button[onclick="doLogin()"]');
    await expect(page.locator("#loginError")).not.toHaveClass(/hidden/);
    await expect(page.locator("#dashboard")).toHaveClass(/hidden/);
  });

  test("full Admin E2E workflow: Login -> Create Subject/Lesson -> Register Student -> Activate Subscription -> Logout", async ({
    page,
  }) => {
    await page.goto("/?emulator=1");

    // 1. Admin Login
    await page.fill("#loginEmail", adminEmail);
    await page.fill("#loginPassword", adminPass);
    await page.click('#loginScreen button[onclick="doLogin()"]');

    await expect(page.locator("#dashboard")).not.toHaveClass(/hidden/);
    await expect(page.locator("#loginScreen")).toHaveClass(/hidden/);
    // Overview stats load real Firestore data
    await expect(page.locator("#stat-grades")).not.toHaveText("—");

    // 2. Create Subject in Curriculum
    await page.click('.nav-item[data-section="subjects"]');
    await page.click('#section-subjects button[onclick="openAddSubjectModal()"]');
    await expect(page.locator("#subjectModal")).not.toHaveClass(/hidden/);
    await page.selectOption("#subjectGradeId", gradeDocId);
    await page.fill("#subjectNameAr", "الفيزياء المتقدمة E2E");
    await page.fill("#subjectNameEn", "Advanced Physics E2E");
    await page.fill("#subjectIcon", "⚛️");
    await page.click('#subjectModal button[onclick="saveSubject()"]');
    await expect(page.locator("#subjectModal")).toHaveClass(/hidden/);
    await page.selectOption("#subjectGradeFilter", gradeDocId);
    await expect(page.locator("#subjectsList")).toContainText("الفيزياء المتقدمة E2E");

    // 3. Create Lesson for the Subject
    await page.click('.nav-item[data-section="lessons"]');
    await page.click('#section-lessons button[onclick="openAddLessonModal()"]');
    await expect(page.locator("#lessonModal")).not.toHaveClass(/hidden/);
    await page.selectOption("#lessonModalGrade", gradeDocId);
    const lessonSubOption = page.locator('#lessonModalSubject option:has-text("الفيزياء المتقدمة E2E")');
    await expect(lessonSubOption).toBeAttached();
    const subOptionValue = await lessonSubOption.getAttribute("value");
    expect(subOptionValue).toBeTruthy();
    await page.selectOption("#lessonModalSubject", subOptionValue!);
    await page.fill("#lessonTitleAr", "قانون نيوتن E2E");
    await page.fill("#lessonVideoUrl", "https://cdn.example.com/newton.mp4");
    await page.click("#btnSaveLesson");
    await expect(page.locator("#lessonModal")).toHaveClass(/hidden/);

    // Verify lesson loads in Lessons table under subject filter
    await page.selectOption("#lessonGradeFilter", gradeDocId);
    await page.selectOption("#lessonSubjectFilter", subOptionValue!);
    await expect(page.locator("#lessonsList")).toContainText("قانون نيوتن E2E");

    // 4. Register / Add Student via Auth Emulator + Firestore
    await page.click('.nav-item[data-section="students"]');
    await page.click('#section-students button[onclick="openStudentModal()"]');
    await expect(page.locator("#studentModal")).not.toHaveClass(/hidden/);
    await page.fill("#studentName", "سارة اختبار E2E");
    await page.fill("#studentEmail", createdStudentEmail);
    await page.fill("#studentPassword", "StudentPass!2026");
    await page.selectOption("#studentGrade", "12");
    await page.selectOption("#studentSection", "scientific");
    await page.click("#studentModalBtn");
    await expect(page.locator("#studentModal")).toHaveClass(/hidden/);
    await expect(page.locator("#studentsList")).toContainText(createdStudentEmail);

    // 5. Activate Subscription via Student Subscription Duration modal (core entitlement/checkout flow)
    const userQuery = await db.collection("users").where("email", "==", createdStudentEmail).get();
    expect(userQuery.size).toBe(1);
    const createdStudentUid = userQuery.docs[0].id;

    const studentRow = page.locator("#studentsList tr", { hasText: createdStudentEmail });
    await studentRow.locator('button[title="تعديل مدة الاشتراك"]').click();
    await expect(page.locator("#editSubDurationModal")).not.toHaveClass(/hidden/);
    const futureDate = new Date(Date.now() + 30 * 86_400_000).toISOString().slice(0, 10);
    await page.fill("#editSubEndDate", futureDate);
    await page.click('#editSubDurationModal button[onclick="saveSubscriptionDuration()"]');
    await expect(page.locator("#editSubDurationModal")).toHaveClass(/hidden/);

    // Verify subscription visible in Subscriptions section and persisted in Firestore
    await page.click('.nav-item[data-section="subscriptions"]');
    await expect(page.locator("#subscriptionsList")).toContainText(createdStudentEmail);

    const refreshedUser = await db.collection("users").doc(createdStudentUid).get();
    expect(refreshedUser.data()?.is_subscribed).toBe(true);

    // 6. Logout
    await page.click('button[onclick="doLogout()"]');
    await expect(page.locator("#loginScreen")).not.toHaveClass(/hidden/);
    await expect(page.locator("#dashboard")).toHaveClass(/hidden/);
  });

  test("Summary Studio (/studio) authenticates admin, loads grades from Emulator, and logs out", async ({
    page,
  }) => {
    await page.goto("/studio/?emulator=1");
    await expect(page.locator("#loginOverlay")).not.toHaveClass(/hidden/);

    await page.fill("#authEmail", adminEmail);
    await page.fill("#authPassword", adminPass);
    await page.click("#btnLogin");

    await expect(page.locator("#loginOverlay")).toHaveClass(/hidden/);
    await expect(page.locator("#userSessionBadge")).not.toHaveClass(/hidden/);
    await expect(page.locator('#gradeSelect option[value="e2e_grade_12"]')).toBeAttached();

    await page.click('button[onclick="handleStudioLogout()"]');
    await expect(page.locator("#loginOverlay")).not.toHaveClass(/hidden/);
  });

  test("Legal pages (/privacy.html and /terms.html) toggle AR/EN cleanly with RTL/LTR and zero stale copy", async ({
    page,
  }) => {
    for (const route of ["/privacy.html", "/terms.html"]) {
      await page.goto(`${route}?lang=ar`);
      await expect(page.locator("#html-root")).toHaveAttribute("lang", "ar");
      await expect(page.locator("#html-root")).toHaveAttribute("dir", "rtl");

      const bodyTextAr = await page.locator("body").innerText();
      expect(bodyTextAr).not.toContain("FCM");
      expect(bodyTextAr).not.toContain("Firebase Secrets");

      await page.click("#lang-btn");
      await expect(page.locator("#html-root")).toHaveAttribute("lang", "en");
      await expect(page.locator("#html-root")).toHaveAttribute("dir", "ltr");

      const bodyTextEn = await page.locator("body").innerText();
      expect(bodyTextEn).not.toContain("FCM");
      expect(bodyTextEn).not.toContain("Firebase Secrets");

      // Toggle back to Arabic and verify bidirectional switch works cleanly
      await page.click("#lang-btn");
      await expect(page.locator("#html-root")).toHaveAttribute("lang", "ar");
      await expect(page.locator("#html-root")).toHaveAttribute("dir", "rtl");
    }
  });
});
