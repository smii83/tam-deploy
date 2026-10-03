/* ══════════════════════════════════════════════
   TAM Legal Pages — Bilingual Toggle (AR / EN)
   ══════════════════════════════════════════════ */

const htmlRoot = document.getElementById('html-root');
const langBtn  = document.getElementById('lang-btn');
let currentLang = 'ar';

function toggleLang() {
  currentLang = currentLang === 'ar' ? 'en' : 'ar';
  applyLang(currentLang);
}

function applyLang(lang) {
  const isEn = lang === 'en';

  // ── HTML dir & lang ───────────────────────
  htmlRoot.setAttribute('lang', isEn ? 'en' : 'ar');
  htmlRoot.setAttribute('dir',  isEn ? 'ltr' : 'rtl');

  // ── Body font ─────────────────────────────
  document.body.style.fontFamily = isEn
    ? "'Inter', sans-serif"
    : "'Cairo', sans-serif";

  // ── Button label ──────────────────────────
  langBtn.textContent = isEn ? 'ع' : 'EN';
  langBtn.title = isEn ? 'Arabic' : 'English';

  // ── All [data-ar] / [data-en] elements ────
  document.querySelectorAll('[data-ar]').forEach(el => {
    const val = isEn ? el.getAttribute('data-en') : el.getAttribute('data-ar');
    if (val === null) return;
    if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
      el.placeholder = val;
    } else {
      el.innerHTML = val;
    }
  });

  // ── Arabic/English section numbers ────────
  document.querySelectorAll('.en-num').forEach(el => {
    el.classList.toggle('hidden', !isEn);
  });
  document.querySelectorAll('.section-number').forEach(el => {
    // Show first text node (Arabic numeral) only in AR
    el.childNodes.forEach(node => {
      if (node.nodeType === Node.TEXT_NODE) {
        node.textContent = isEn
          ? node.textContent.replace(/[٠-٩]/g, d => '0123456789'['٠١٢٣٤٥٦٧٨٩'.indexOf(d)])
          : node.textContent;
      }
    });
  });

  // ── Page title ────────────────────────────
  const titleEl = document.getElementById('page-title');
  if (titleEl) {
    if (window.location.pathname.includes('privacy')) {
      titleEl.textContent = isEn
        ? 'Privacy Policy — TAM Educational Platform'
        : 'سياسة الخصوصية — منصة تم التعليمية';
    } else {
      titleEl.textContent = isEn
        ? 'Terms of Use — TAM Educational Platform'
        : 'شروط الاستخدام — منصة تم التعليمية';
    }
  }

  // ── Store preference ──────────────────────
  try { localStorage.setItem('tam_lang', lang); } catch(e) {}
}

// ── On page load: restore saved preference or URL param ──
(function init() {
  let saved = 'ar';
  try {
    const urlParams = new URLSearchParams(window.location.search);
    const langParam = urlParams.get('lang');
    if (langParam === 'en' || langParam === 'ar') {
      saved = langParam;
    } else {
      saved = localStorage.getItem('tam_lang') || 'ar';
    }
  } catch(e) {}
  currentLang = saved;
  applyLang(currentLang);
})();

