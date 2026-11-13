import { describe, it, expect, beforeEach } from "vitest";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

// eslint-disable-next-line @typescript-eslint/no-var-requires
const helpers = require("../../admin_dashboard/helpers.js");

describe("Admin Dashboard & Studio Pure Helpers (admin_dashboard/helpers.js)", () => {
  it("isAuthorizedAdmin performs case-insensitive trimmed matching and rejects empty/non-admin", () => {
    expect(helpers.isAuthorizedAdmin("ADMIN@TAM.COM")).toBe(true);
    expect(helpers.isAuthorizedAdmin("  tam.app83@gmail.com  ")).toBe(true);
    expect(helpers.isAuthorizedAdmin("student@gmail.com")).toBe(false);
    expect(helpers.isAuthorizedAdmin("")).toBe(false);
    expect(helpers.isAuthorizedAdmin("   ")).toBe(false);
    expect(helpers.isAuthorizedAdmin(null)).toBe(false);
    expect(helpers.isAuthorizedAdmin(undefined)).toBe(false);
    expect(helpers.isAuthorizedAdmin(12345)).toBe(false);

    // Custom allowlist for Studio
    expect(helpers.isAuthorizedAdmin("admin@eduspark.com", helpers.STUDIO_ADMIN_EMAILS)).toBe(false);
    expect(helpers.isAuthorizedAdmin("tam.app83@gmail.com", helpers.STUDIO_ADMIN_EMAILS)).toBe(true);
  });

  it("escapeHtml neutralizes XSS vectors and preserves zero/numbers safely", () => {
    expect(helpers.escapeHtml(null)).toBe("");
    expect(helpers.escapeHtml(undefined)).toBe("");
    expect(helpers.escapeHtml(0)).toBe("0");
    expect(helpers.escapeHtml('<img src=x onerror="alert(\'xss\')">&')).toBe(
      "&lt;img src=x onerror=&quot;alert(&#39;xss&#39;)&quot;&gt;&amp;"
    );
  });

  it("formatDirectPdfUrl converts Google Drive, Google Docs, and Dropbox share links", () => {
    expect(helpers.formatDirectPdfUrl("")).toBe("");
    expect(helpers.formatDirectPdfUrl(null)).toBe("");
    expect(
      helpers.formatDirectPdfUrl("  https://drive.google.com/file/d/1AbC_dEf-99/view?usp=sharing  ")
    ).toBe("https://drive.google.com/uc?export=download&id=1AbC_dEf-99");
    expect(
      helpers.formatDirectPdfUrl("https://docs.google.com/uc?id=999XYZ_1")
    ).toBe("https://drive.google.com/uc?export=download&id=999XYZ_1");
    expect(
      helpers.formatDirectPdfUrl("https://www.dropbox.com/s/xyz/notes.pdf?dl=0")
    ).toBe("https://www.dropbox.com/s/xyz/notes.pdf?dl=1");
    expect(
      helpers.formatDirectPdfUrl("https://www.dropbox.com/s/xyz/notes.pdf?rlkey=abc&dl=0")
    ).toBe("https://www.dropbox.com/s/xyz/notes.pdf?rlkey=abc&dl=1");
    expect(helpers.formatDirectPdfUrl("https://cdn.example.com/file.pdf")).toBe(
      "https://cdn.example.com/file.pdf"
    );
  });

  it("lessonStatusBadge renders all interactive lesson statuses and escapes HTML errors", () => {
    expect(helpers.lessonStatusBadge({ id: "p1", pdf_type: "worksheet" }, null)).toContain("—");
    expect(
      helpers.lessonStatusBadge({ id: "p1", pdf_type: "summary" }, null, new Set(["p1"]))
    ).toContain("جارٍ التوليد");
    expect(
      helpers.lessonStatusBadge({ id: "p2", pdf_type: "summary" }, { status: "processing" })
    ).toContain("جارٍ التوليد");
    expect(helpers.lessonStatusBadge({ id: "p3", pdf_type: "summary" }, null)).toContain("لم يُولَّد");

    const errBadge = helpers.lessonStatusBadge(
      { id: "p4", pdf_type: "summary" },
      { status: "error", error: 'bad "<tag>"' }
    );
    expect(errBadge).toContain("فشل");
    expect(errBadge).toContain("&quot;&lt;tag&gt;&quot;");

    expect(
      helpers.lessonStatusBadge(
        { id: "p5", pdf_type: "summary" },
        { status: "ready", audio_complete: true }
      )
    ).toContain("🔊");
    expect(
      helpers.lessonStatusBadge(
        { id: "p6", pdf_type: "summary" },
        { status: "ready", audio_complete: false, audio_done: 3, audio_total: 7 }
      )
    ).toContain("🔇 3/7");
  });

  it("lessonSegments handles empty/malformed content and gathers valid narrated segments", () => {
    expect(helpers.lessonSegments(null)).toEqual([]);
    expect(helpers.lessonSegments({})).toEqual([]);
    const segs = helpers.lessonSegments({
      common: { welcome: { narration: "أهلاً" }, intro: { narration: "  " } },
      versions: {
        mukhtasar: {
          hook: { available: false, narration: "skipped" },
          sections: [{ narration: "قسم 1" }],
          zubda: { narration: "زبدة 1" },
        },
        kamila: {
          hook: { available: true, narration: "سؤال" },
          sections: [{ narration: "" }],
          zubda: { narration: "زبدة 2" },
        },
      },
    });
    expect(segs.map((s: { narration: string }) => s.narration)).toEqual([
      "أهلاً",
      "قسم 1",
      "زبدة 1",
      "سؤال",
      "زبدة 2",
    ]);
  });

  it("isEmulatorMode activates ONLY on localhost/127.0.0.1 with ?emulator=1 or sessionStorage", () => {
    const store = new Map<string, string>();
    const sessionShim = {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => void store.set(k, v),
      removeItem: (k: string) => void store.delete(k),
    };

    // Never enabled on production hostname even if ?emulator=1 is passed!
    expect(
      helpers.isEmulatorMode({ hostname: "tam-app-fd30f.web.app", search: "?emulator=1" }, sessionShim)
    ).toBe(false);
    expect(store.size).toBe(0);

    // Disabled on localhost unless ?emulator=1 or session flag
    expect(helpers.isEmulatorMode({ hostname: "127.0.0.1", search: "" }, sessionShim)).toBe(false);

    // Enabled with ?emulator=1 on localhost and persisted in sessionStorage
    expect(helpers.isEmulatorMode({ hostname: "127.0.0.1", search: "?emulator=1" }, sessionShim)).toBe(true);
    expect(helpers.isEmulatorMode({ hostname: "localhost", search: "" }, sessionShim)).toBe(true);

    // ?emulator=0 clears persistence
    expect(helpers.isEmulatorMode({ hostname: "127.0.0.1", search: "?emulator=0" }, sessionShim)).toBe(false);
    expect(helpers.isEmulatorMode({ hostname: "127.0.0.1", search: "" }, sessionShim)).toBe(false);
  });

  it("resolveIdentityToolkitUrl routes signUp to emulator vs live endpoint", () => {
    expect(helpers.resolveIdentityToolkitUrl("accounts:signUp", "KEY123", true)).toBe(
      "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=KEY123"
    );
    expect(helpers.resolveIdentityToolkitUrl("accounts:signUp", "KEY123", false)).toBe(
      "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=KEY123"
    );
  });
});

describe("Legal Pages Bilingual Helper (admin_dashboard/legal.js)", () => {
  let legalScript: string;

  beforeEach(() => {
    legalScript = fs.readFileSync(path.resolve(__dirname, "../../admin_dashboard/legal.js"), "utf8");
  });

  it("applies RTL Arabic by default, toggles EN/LTR cleanly, and updates title", () => {
    const attrMap = new Map<string, string>();
    const storageMap = new Map<string, string>();
    const htmlRoot = {
      setAttribute: (k: string, v: string) => attrMap.set(k, v),
      getAttribute: (k: string) => attrMap.get(k) ?? null,
    };
    const langBtn = { textContent: "", title: "" };
    const pageTitle = { textContent: "" };
    const sampleHeading = {
      tagName: "SPAN",
      innerHTML: "",
      getAttribute: (k: string) => (k === "data-en" ? "Privacy" : "الخصوصية"),
    };

    const context: Record<string, unknown> = {
      document: {
        body: { style: { fontFamily: "" } },
        getElementById: (id: string) => {
          if (id === "html-root") return htmlRoot;
          if (id === "lang-btn") return langBtn;
          if (id === "page-title") return pageTitle;
          return null;
        },
        querySelectorAll: (sel: string) => (sel === "[data-ar]" ? [sampleHeading] : []),
      },
      window: { location: { search: "", pathname: "/privacy.html" } },
      localStorage: {
        getItem: (k: string) => storageMap.get(k) ?? null,
        setItem: (k: string, v: string) => void storageMap.set(k, v),
      },
      URLSearchParams,
    };

    vm.runInNewContext(legalScript, context);

    expect(attrMap.get("lang")).toBe("ar");
    expect(attrMap.get("dir")).toBe("rtl");
    expect(langBtn.textContent).toBe("EN");
    expect(sampleHeading.innerHTML).toBe("الخصوصية");
    expect(pageTitle.textContent).toContain("سياسة الخصوصية");

    (context.toggleLang as () => void)();
    expect(attrMap.get("lang")).toBe("en");
    expect(attrMap.get("dir")).toBe("ltr");
    expect(langBtn.textContent).toBe("ع");
    expect(sampleHeading.innerHTML).toBe("Privacy");
    expect(pageTitle.textContent).toContain("Privacy Policy");
    expect(storageMap.get("tam_lang")).toBe("en");

    // Non-'en' language defaults cleanly to 'ar'
    (context.applyLang as (l: string) => void)("fr");
    expect(attrMap.get("lang")).toBe("ar");
    expect(attrMap.get("dir")).toBe("rtl");
  });
});
