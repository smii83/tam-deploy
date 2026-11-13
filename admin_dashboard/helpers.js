// ─────────────────────────────────────────────────────────────────────────────
// TAM Shared Pure Helpers & Emulator Mode Detection (Browser + Node/Vitest)
// ─────────────────────────────────────────────────────────────────────────────
(function (root) {
  const ADMIN_EMAILS = [
    'admin@tam.com',
    'tamteach01@gmail.com',
    'tam.app83@gmail.com',
    'tm.app83@gmail.com',
    'admin@eduspark.com',
  ];

  const STUDIO_ADMIN_EMAILS = [
    'tam.app83@gmail.com',
    'tm.app83@gmail.com',
    'tamteach01@gmail.com',
    'admin@tam.com',
  ];

  function isAuthorizedAdmin(email, allowList = ADMIN_EMAILS) {
    if (!email || typeof email !== 'string') return false;
    const e = email.toLowerCase().trim();
    if (!e) return false;
    return allowList.some((a) => a.toLowerCase().trim() === e);
  }

  function escapeHtml(val) {
    if (val === null || val === undefined) return '';
    return String(val)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function formatDirectPdfUrl(rawUrl) {
    if (!rawUrl || typeof rawUrl !== 'string') return '';
    const url = rawUrl.trim();
    if (!url) return '';
    const driveMatch =
      url.match(/\/file\/d\/([a-zA-Z0-9_-]+)/) ||
      url.match(/[?&]id=([a-zA-Z0-9_-]+)/);
    if (driveMatch && (url.includes('drive.google.com') || url.includes('docs.google.com'))) {
      return `https://drive.google.com/uc?export=download&id=${driveMatch[1]}`;
    }
    if (url.includes('dropbox.com')) {
      return url.replace('?dl=0', '?dl=1').replace('&dl=0', '&dl=1');
    }
    return url;
  }

  function lessonStatusBadge(pdf, il, generatingSet) {
    if (!pdf || pdf.pdf_type !== 'summary') return '<span style="opacity:.4">—</span>';
    if ((generatingSet && generatingSet.has(pdf.id)) || (il && il.status === 'processing')) {
      return '<span class="badge badge-blue">⏳ جارٍ التوليد</span>';
    }
    if (!il) return '<span style="opacity:.5">لم يُولَّد</span>';
    if (il.status === 'error') {
      return `<span class="badge badge-red" title="${escapeHtml(il.error || '')}">❌ فشل</span>`;
    }
    if (il.status === 'ready') {
      const audio = il.audio_complete
        ? '🔊'
        : `🔇 ${escapeHtml(il.audio_done || 0)}/${escapeHtml(il.audio_total || 0)}`;
      return `<span class="badge badge-green">✅ جاهز</span> <small>${audio}</small>`;
    }
    return '—';
  }

  function lessonSegments(c) {
    if (!c || !c.common || !c.versions) return [];
    const segs = [c.common.welcome, c.common.intro];
    for (const v of [c.versions.mukhtasar, c.versions.kamila]) {
      if (!v) continue;
      if (v.hook && v.hook.available && v.hook.narration) segs.push(v.hook);
      if (Array.isArray(v.sections)) segs.push(...v.sections);
      if (v.zubda) segs.push(v.zubda);
    }
    return segs.filter((s) => s && (s.narration || '').trim());
  }

  function isEmulatorMode(loc, store) {
    try {
      const l = loc || (typeof window !== 'undefined' ? window.location : null);
      if (!l) return false;
      const host = l.hostname;
      if (host !== '127.0.0.1' && host !== 'localhost') return false;
      const params = new URLSearchParams(l.search || '');
      const s = store || (typeof window !== 'undefined' ? window.sessionStorage : null);
      if (params.get('emulator') === '1') {
        try { if (s) s.setItem('tam_use_emulator', '1'); } catch (_) {}
        return true;
      }
      if (params.get('emulator') === '0') {
        try { if (s) s.removeItem('tam_use_emulator'); } catch (_) {}
        return false;
      }
      return Boolean(s && s.getItem('tam_use_emulator') === '1');
    } catch (_) {
      return false;
    }
  }

  function resolveIdentityToolkitUrl(path, apiKey, useEmulator) {
    if (useEmulator) {
      return `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/${path}?key=${apiKey}`;
    }
    return `https://identitytoolkit.googleapis.com/v1/${path}?key=${apiKey}`;
  }

  const exported = {
    ADMIN_EMAILS,
    STUDIO_ADMIN_EMAILS,
    isAuthorizedAdmin,
    escapeHtml,
    formatDirectPdfUrl,
    lessonStatusBadge,
    lessonSegments,
    isEmulatorMode,
    resolveIdentityToolkitUrl,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = exported;
  } else {
    Object.assign(root, exported);
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);

