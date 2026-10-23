// ─────────────────────────────────────────────────────────────────────────────
// TAM Admin Dashboard — Firebase Firestore Edition
// ─────────────────────────────────────────────────────────────────────────────
const firebaseConfig = {
  apiKey: 'AIzaSyD6Rt1pNgLMOC6ajMWSpqiBf3Z-jFZNecw',
  authDomain: 'tam-app-fd30f.firebaseapp.com',
  projectId: 'tam-app-fd30f',
  storageBucket: 'tam-app-fd30f.firebasestorage.app',
  messagingSenderId: '82581349835',
  appId: '1:82581349835:web:018e0cd45d48a9c942824e'
};
firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();
const auth = firebase.auth();
const storage = firebase.storage();
// Cloud Functions (same region as the deployed callables)
const functions = firebase.app().functions('me-central1');

// Admin email whitelist — only these emails can log in
const ADMIN_EMAILS = ['admin@tam.com', 'tamteach01@gmail.com', 'tam.app83@gmail.com', 'tm.app83@gmail.com', 'admin@eduspark.com'];

function isAuthorizedAdmin(email) {
  if (!email) return false;
  const e = email.toLowerCase().trim();
  return ADMIN_EMAILS.some(a => a.toLowerCase().trim() === e);
}

// ── Firestore helpers ────────────────────────────────────────────────────────
async function fsCollection(col) {
  const snap = await db.collection(col).get();
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}
async function fsList(col, opts = {}) {
  let q = db.collection(col);
  if (opts.where) opts.where.forEach(w => q = q.where(...w));
  if (opts.orderBy) q = q.orderBy(opts.orderBy, opts.orderDir || 'asc');
  if (opts.limit) q = q.limit(opts.limit);
  const snap = await q.get();
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}
async function fsGet(col, id) {
  const doc = await db.collection(col).doc(id).get();
  if (!doc.exists) throw new Error('لم يتم العثور على السجل');
  return { id: doc.id, ...doc.data() };
}
async function fsCreate(col, data) {
  const ref = await db.collection(col).add({ ...data, created: firebase.firestore.FieldValue.serverTimestamp() });
  return { id: ref.id, ...data };
}
async function fsCreateWithId(col, id, data) {
  await db.collection(col).doc(id).set({ ...data, created: firebase.firestore.FieldValue.serverTimestamp() });
  return { id, ...data };
}
async function fsUpdate(col, id, data) {
  await db.collection(col).doc(id).update(data);
  return true;
}
async function fsDelete(col, id) {
  await db.collection(col).doc(id).delete();
  return true;
}

// ── Auth ──────────────────────────────────────────────────────────────────────
async function doLogin() {
  const email = document.getElementById('loginEmail').value.trim();
  const pass = document.getElementById('loginPassword').value;
  const errEl = document.getElementById('loginError');
  const btn = document.getElementById('loginBtnText');
  errEl.classList.add('hidden'); btn.textContent = 'جارٍ التحقق...';
  try {
    const cred = await auth.signInWithEmailAndPassword(email, pass);
    // Check if admin
    if (!isAuthorizedAdmin(email)) {
      await auth.signOut();
      throw new Error('هذا الحساب ليس مشرفاً');
    }
    document.getElementById('loginScreen').classList.add('hidden');
    document.getElementById('dashboard').classList.remove('hidden');
    document.getElementById('currentPbUrl').value = 'tam-app-fd30f';
    document.getElementById('adminName').textContent = email.split('@')[0];
    await initDashboard();
  } catch (e) {
    let msg = e.message || 'بيانات غير صحيحة';
    if (e.code === 'auth/user-not-found') msg = 'البريد الإلكتروني غير مسجل';
    if (e.code === 'auth/wrong-password' || e.code === 'auth/invalid-credential') msg = 'كلمة المرور غير صحيحة';
    errEl.textContent = 'خطأ: ' + msg; errEl.classList.remove('hidden'); btn.textContent = 'تسجيل الدخول';
  }
}

async function doForgotPassword() {
  const email = document.getElementById('loginEmail').value.trim();
  const errEl = document.getElementById('loginError');
  if (!email) {
    errEl.textContent = 'يرجى كتابة البريد الإلكتروني أولاً في حقل البريد أعلاه';
    errEl.classList.remove('hidden');
    return;
  }
  if (!ADMIN_EMAILS.includes(email.toLowerCase())) {
    errEl.textContent = 'هذا البريد غير موجود في قائمة المشرفين المصرح لهم';
    errEl.classList.remove('hidden');
    return;
  }
  errEl.classList.add('hidden');
  try {
    await auth.sendPasswordResetEmail(email);
    alert('✅ تم إرسال رابط إعادة تعيين كلمة المرور إلى البريد: ' + email + '\nيرجى مراجعة صندوق الوارد (أو الرسائل غير المرغوبة Spam) لتعيين كلمة مرورك الجديدة.');
  } catch (e) {
    errEl.textContent = 'خطأ في إرسال الرابط: ' + (e.message || 'تعذر الإرسال');
    errEl.classList.remove('hidden');
  }
}

function doLogout() { auth.signOut(); location.reload(); }

// Auto-login check
auth.onAuthStateChanged(user => {
  if (user && isAuthorizedAdmin(user.email)) {
    document.getElementById('loginScreen').classList.add('hidden');
    document.getElementById('dashboard').classList.remove('hidden');
    document.getElementById('adminName').textContent = user.email.split('@')[0];
    initDashboard();
  }
});

document.addEventListener('DOMContentLoaded', () => {
  ['loginEmail', 'loginPassword'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('keydown', e => { if (e.key === 'Enter') doLogin(); });
  });
});

// ── UI helpers ────────────────────────────────────────────────────────────────
function showSection(id) {
  document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  document.getElementById('section-' + id).classList.add('active');
  document.querySelector(`[data-section="${id}"]`).classList.add('active');
  const titles = { overview: 'نظرة عامة', grades: 'الصفوف', subjects: 'المواد', lessons: 'الدروس', pdfs: 'ملفات PDF', students: 'الطلاب', subscriptions: 'الاشتراكات', settings: 'الإعدادات' };
  document.getElementById('pageTitle').textContent = titles[id] || id;
  if (id === 'grades') loadGrades();
  if (id === 'subjects') {
    const sg = document.getElementById('subjectGradeFilter');
    if (sg && !sg.value && sg.options.length > 1) { sg.selectedIndex = 1; loadSubjects(); }
    else if (sg && sg.value) { loadSubjects(); }
  }
  if (id === 'lessons') {
    const lg = document.getElementById('lessonGradeFilter');
    if (lg && !lg.value && lg.options.length > 1) {
      lg.selectedIndex = 1;
      loadLessonSubjects().then(() => {
        const ls = document.getElementById('lessonSubjectFilter');
        if (ls && ls.options.length > 1) { ls.selectedIndex = 1; loadLessons(); }
      });
    } else if (lg && lg.value) { loadLessons(); }
  }
  if (id === 'pdfs') {
    const pg = document.getElementById('pdfGradeFilter');
    if (pg && !pg.value && pg.options.length > 1) {
      pg.selectedIndex = 1;
      loadPdfSubjects().then(() => {
        const ps = document.getElementById('pdfSubjectFilter');
        if (ps && ps.options.length > 1) { ps.selectedIndex = 1; loadPdfs(); }
      });
    } else if (pg && pg.value) { loadPdfs(); }
  }
  if (id === 'students') loadStudents();
  if (id === 'subscriptions') loadSubscriptions();
  if (id === 'overview') loadOverview();
  if (id === 'settings') loadSettings();
}
function toggleSidebar() { document.getElementById('sidebar').classList.toggle('collapsed'); }
function toast(msg, type = 'success') { const t = document.getElementById('toast'); t.textContent = msg; t.className = 'toast ' + type; setTimeout(() => t.classList.add('hidden'), 2500); }
function closeModal(id) { document.getElementById(id).classList.add('hidden'); }
async function initDashboard() { await loadOverview(); await populateGradeFilters(); await loadGrades(); loadSettings(); }

// ── Overview ──────────────────────────────────────────────────────────────────
async function loadOverview() {
  try { document.getElementById('stat-grades').textContent = (await fsCollection('grades')).length; } catch { document.getElementById('stat-grades').textContent = '0'; }
  try { document.getElementById('stat-subjects').textContent = (await fsCollection('subjects')).length; } catch { document.getElementById('stat-subjects').textContent = '0'; }
  try { document.getElementById('stat-lessons').textContent = (await fsCollection('lessons')).length; } catch { document.getElementById('stat-lessons').textContent = '0'; }
  try {
    const users = await fsList('users', { orderBy: 'created', orderDir: 'desc' });
    document.getElementById('stat-students').textContent = users.length;
    const recent = users.slice(0, 5);
    if (recent.length) {
      let h = '<table><thead><tr><th>الاسم</th><th>البريد</th><th>التاريخ</th></tr></thead><tbody>';
      recent.forEach(u => { h += `<tr><td>${u.name || '—'}</td><td>${u.email || '—'}</td><td>${u.created ? new Date(u.created.seconds * 1000).toLocaleDateString('ar') : '—'}</td></tr>`; });
      document.getElementById('recentStudents').innerHTML = h + '</tbody></table>';
    } else document.getElementById('recentStudents').innerHTML = '<p class="empty-msg">لا يوجد طلاب بعد</p>';
  } catch { document.getElementById('stat-students').textContent = '0'; document.getElementById('recentStudents').innerHTML = '<p class="empty-msg">لا يوجد طلاب</p>'; }
}

// ── Grades ─────────────────────────────────────────────────────────────────────
async function loadGrades() {
  try {
    const grades = await fsList('grades', { orderBy: 'grade_number' });
    let h = '';
    grades.forEach(g => { h += `<div class="grade-card ${g.is_visible ? '' : 'hidden-grade'}"><div class="grade-num">${g.grade_number}</div><div class="grade-name">${g.name_ar}</div><div class="grade-meta">${g.name_en}</div><div class="grade-actions"><label class="toggle-switch"><input type="checkbox" ${g.is_visible ? 'checked' : ''} onchange="toggleGrade('${g.id}',this.checked)"/><div class="toggle-track"></div></label><span style="font-size:0.82rem;color:var(--text-muted)">${g.is_visible ? 'ظاهر' : 'مخفي'}</span></div></div>`; });
    document.getElementById('gradesList').innerHTML = h || '<p class="empty-msg">لا توجد صفوف</p>';
  } catch (e) { document.getElementById('gradesList').innerHTML = '<p class="empty-msg">خطأ: ' + e.message + '</p>'; }
}
async function toggleGrade(id, v) { try { await fsUpdate('grades', id, { is_visible: v }); toast(v ? 'تم إظهار الصف' : 'تم إخفاء الصف'); await loadGrades(); } catch (e) { toast('خطأ: ' + e.message, 'error'); } }

async function seedKuwaitTracks() {
  try {
    toast('جارٍ إضافة ومزامنة نظام المسارات الجديد...');
    const allGrades = await fsCollection('grades');
    let tracksGrade = allGrades.find(g => (g.grade_number === 10 || g.grade_number === '10') && g.section === 'tracks' && (g.country === 'kw' || !g.country));
    if (!tracksGrade) {
      tracksGrade = await fsCreate('grades', {
        grade_number: 10,
        name_ar: 'الصف العاشر — نظام المسارات (2026)',
        name_en: 'Grade 10 (Tracks)',
        section: 'tracks',
        country: 'kw',
        is_visible: true,
        sort_order: 10.5
      });
    }

    const existingSubs = await fsList('subjects', { where: [['grade_id', '==', tracksGrade.id]] });
    const tracksSubjects = [
      { name_ar: 'العلوم المتكاملة', name_en: 'Integrated Science', icon: '🔬', color: '#059669', sort_order: 1 },
      { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '#F97316', sort_order: 2 },
      { name_ar: 'الحوسبة والذكاء الاصطناعي', name_en: 'Computing & AI', icon: '💻', color: '#6D28D9', sort_order: 3 },
      { name_ar: 'مقرر الاستكشاف (1 و 2)', name_en: 'Exploration Courses', icon: '🧭', color: '#0284C7', sort_order: 4 },
      { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📝', color: '#4F46E5', sort_order: 5 },
      { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🇬🇧', color: '#2563EB', sort_order: 6 },
      { name_ar: 'التربية الإسلامية', name_en: 'Islamic Ed.', icon: '☪️', color: '#10B981', sort_order: 7 },
      { name_ar: 'الدراسات الاجتماعية', name_en: 'Social Studies', icon: '🌍', color: '#B45309', sort_order: 8 },
      { name_ar: 'دليل المسارات المستقبلية', name_en: 'Career Tracks Guide', icon: '🎯', color: '#EC4899', sort_order: 9 }
    ];

    for (const sub of tracksSubjects) {
      const exists = existingSubs.some(s => s.name_ar === sub.name_ar);
      if (!exists) {
        await fsCreate('subjects', {
          ...sub,
          grade_id: tracksGrade.id,
          is_visible: true
        });
      }
    }

    toast('تمت مزامنة نظام المسارات ومواده بنجاح!');
    await loadGrades();
    await populateGradeFilters();
  } catch (e) {
    toast('خطأ في المزامنة: ' + e.message, 'error');
  }
}

async function populateGradeFilters() {
  let grades = []; try { grades = await fsList('grades', { orderBy: 'grade_number' }); } catch { }
  ['subjectGradeFilter', 'lessonGradeFilter', 'pdfGradeFilter', 'subjectGradeId', 'lessonModalGrade', 'pdfModalGrade'].forEach(selId => {
    const sel = document.getElementById(selId); if (!sel) return;
    const first = sel.options[0]; sel.innerHTML = ''; if (first) sel.appendChild(first);
    grades.forEach(g => { const o = document.createElement('option'); o.value = g.id; o.textContent = `الصف ${g.grade_number} — ${g.name_ar}`; sel.appendChild(o); });
  });
}

// ── Subjects ──────────────────────────────────────────────────────────────────
async function loadSubjects() {
  const gid = document.getElementById('subjectGradeFilter').value;
  if (!gid) { document.getElementById('subjectsList').innerHTML = '<p class="empty-msg">اختر صفاً</p>'; return; }
  try {
    const subs = await fsList('subjects', { where: [['grade_id', '==', gid]] });
    subs.sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0));
    if (!subs.length) { document.getElementById('subjectsList').innerHTML = '<p class="empty-msg">لا توجد مواد — أضف مادة جديدة</p>'; return; }
    let h = '<table><thead><tr><th>الأيقونة</th><th>المادة (عربي)</th><th>المادة (إنجليزي)</th><th>الترتيب</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>';
    subs.forEach(s => { h += `<tr><td>${s.icon || '📘'}</td><td>${s.name_ar}</td><td>${s.name_en || '—'}</td><td>${s.sort_order || 0}</td><td><label class="toggle-switch"><input type="checkbox" ${s.is_visible ? 'checked' : ''} onchange="toggleSubject('${s.id}',this.checked)"/><div class="toggle-track"></div></label></td><td class="actions-cell"><button class="btn-icon" onclick="editSubject('${s.id}')">✏️</button><button class="btn-icon btn-danger" onclick="deleteSubject('${s.id}')">🗑️</button></td></tr>`; });
    document.getElementById('subjectsList').innerHTML = h + '</tbody></table>';
  } catch (e) { document.getElementById('subjectsList').innerHTML = '<p class="empty-msg">خطأ: ' + e.message + '</p>'; }
}
async function toggleSubject(id, v) { try { await fsUpdate('subjects', id, { is_visible: v }); toast(v ? 'تم إظهار المادة' : 'تم إخفاء المادة'); await loadSubjects(); } catch (e) { toast('خطأ: ' + e.message, 'error'); } }
function openAddSubjectModal() {
  document.getElementById('subjectId').value = ''; document.getElementById('subjectModalTitle').textContent = 'إضافة مادة جديدة';
  document.getElementById('subjectNameAr').value = ''; document.getElementById('subjectNameEn').value = '';
  document.getElementById('subjectIcon').value = '📘'; document.getElementById('subjectColor').value = '#7c3aed';
  document.getElementById('subjectOrder').value = '1'; document.getElementById('subjectVisible').checked = true;
  document.getElementById('subjectModal').classList.remove('hidden');
}
async function editSubject(id) {
  const s = await fsGet('subjects', id);
  document.getElementById('subjectId').value = id; document.getElementById('subjectModalTitle').textContent = 'تعديل المادة';
  document.getElementById('subjectGradeId').value = s.grade_id; document.getElementById('subjectNameAr').value = s.name_ar;
  document.getElementById('subjectNameEn').value = s.name_en || ''; document.getElementById('subjectIcon').value = s.icon || '';
  document.getElementById('subjectColor').value = s.color || '#7c3aed'; document.getElementById('subjectOrder').value = s.sort_order || 1;
  document.getElementById('subjectVisible').checked = s.is_visible; document.getElementById('subjectModal').classList.remove('hidden');
}
async function saveSubject() {
  const id = document.getElementById('subjectId').value;
  const data = { grade_id: document.getElementById('subjectGradeId').value, name_ar: document.getElementById('subjectNameAr').value, name_en: document.getElementById('subjectNameEn').value, icon: document.getElementById('subjectIcon').value, color: document.getElementById('subjectColor').value, sort_order: +document.getElementById('subjectOrder').value, is_visible: document.getElementById('subjectVisible').checked };
  try { if (id) await fsUpdate('subjects', id, data); else await fsCreate('subjects', data); toast(id ? 'تم تحديث المادة' : 'تمت إضافة المادة'); closeModal('subjectModal'); await loadSubjects(); await loadOverview(); } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}
async function deleteSubject(id) { if (!confirm('حذف هذه المادة؟')) return; await fsDelete('subjects', id); toast('تم حذف المادة'); await loadSubjects(); }

// ── Lessons ───────────────────────────────────────────────────────────────────
async function loadLessonSubjects() {
  const gid = document.getElementById('lessonGradeFilter').value;
  const sel = document.getElementById('lessonSubjectFilter'); sel.innerHTML = '<option value="">— اختر المادة —</option>'; if (!gid) return;
  try {
    const subs = await fsList('subjects', { where: [['grade_id', '==', gid]] });
    subs.sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0));
    subs.forEach(s => { const o = document.createElement('option'); o.value = s.id; o.textContent = s.name_ar; sel.appendChild(o); });
    if (subs.length > 0) {
      sel.selectedIndex = 1;
      await loadLessons();
    }
  } catch (e) { console.error('loadLessonSubjects error:', e); }
}

async function onLessonModalGradeChange(selectSid = null) {
  const gid = document.getElementById('lessonModalGrade').value;
  const sel = document.getElementById('lessonModalSubject');
  sel.innerHTML = '<option value="">— اختر المادة —</option>';
  if (!gid) return;
  try {
    const subs = await fsList('subjects', { where: [['grade_id', '==', gid]] });
    subs.sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0));
    subs.forEach(s => { const o = document.createElement('option'); o.value = s.id; o.textContent = s.name_ar; sel.appendChild(o); });
    if (selectSid) sel.value = selectSid;
    else if (subs.length > 0) sel.selectedIndex = 1;
  } catch (e) { console.error('Error loading lesson modal subjects:', e); }
}

async function loadLessons() {
  const sid = document.getElementById('lessonSubjectFilter').value;
  if (!sid) { document.getElementById('lessonsList').innerHTML = '<p class="empty-msg">اختر مادة</p>'; return; }
  try {
    const items = await fsList('lessons', { where: [['subject_id', '==', sid]] });
    items.sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0));
    if (!items.length) { document.getElementById('lessonsList').innerHTML = '<p class="empty-msg">لا توجد دروس</p>'; return; }
    let h = '<table><thead><tr><th>#</th><th>العنوان</th><th>المدة</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>';
    items.forEach(l => { h += `<tr><td>${l.sort_order || 0}</td><td>${l.title_ar || l.name || ''}</td><td>${l.duration_min || 0} د</td><td><label class="toggle-switch"><input type="checkbox" ${l.is_active ? 'checked' : ''} onchange="toggleLesson('${l.id}',this.checked)"/><div class="toggle-track"></div></label></td><td class="actions-cell"><button class="btn-icon" onclick="editLesson('${l.id}')">✏️</button><button class="btn-icon btn-danger" onclick="deleteLesson('${l.id}')">🗑️</button></td></tr>`; });
    document.getElementById('lessonsList').innerHTML = h + '</tbody></table>';
  } catch (e) { document.getElementById('lessonsList').innerHTML = '<p class="empty-msg">خطأ: ' + e.message + '</p>'; }
}
async function toggleLesson(id, v) { try { await fsUpdate('lessons', id, { is_active: v }); toast(v ? 'مفعّل' : 'معطّل'); loadLessons(); } catch (e) { toast('خطأ: ' + e.message, 'error'); } }

async function openAddLessonModal() {
  document.getElementById('lessonId').value = '';
  document.getElementById('lessonModalTitle').textContent = 'إضافة درس جديد';
  document.getElementById('lessonTitleAr').value = '';
  document.getElementById('lessonTitleEn').value = '';
  document.getElementById('lessonVideoUrl').value = '';
  document.getElementById('lessonDuration').value = '30';
  document.getElementById('lessonOrder').value = '1';
  document.getElementById('lessonActive').checked = true;
  const errEl = document.getElementById('lessonModalError');
  if (errEl) errEl.classList.add('hidden');

  const filterGid = document.getElementById('lessonGradeFilter').value;
  const filterSid = document.getElementById('lessonSubjectFilter').value;
  if (filterGid) {
    document.getElementById('lessonModalGrade').value = filterGid;
    await onLessonModalGradeChange(filterSid);
  } else {
    const sel = document.getElementById('lessonModalGrade');
    if (sel.options.length > 1) {
      sel.selectedIndex = 1;
      await onLessonModalGradeChange();
    }
  }
  document.getElementById('lessonModal').classList.remove('hidden');
}

async function editLesson(id) {
  const l = await fsGet('lessons', id);
  document.getElementById('lessonId').value = id;
  document.getElementById('lessonModalTitle').textContent = 'تعديل الدرس';
  document.getElementById('lessonTitleAr').value = l.title_ar || l.name || '';
  document.getElementById('lessonTitleEn').value = l.title_en || '';
  document.getElementById('lessonVideoUrl').value = l.video_url || '';
  document.getElementById('lessonDuration').value = l.duration_min || 30;
  document.getElementById('lessonOrder').value = l.sort_order || 1;
  document.getElementById('lessonActive').checked = l.is_active;
  const errEl = document.getElementById('lessonModalError');
  if (errEl) errEl.classList.add('hidden');

  let gradeId = '';
  if (l.subject_id) {
    try {
      const sub = await fsGet('subjects', l.subject_id);
      gradeId = sub.grade_id;
    } catch { }
  }
  if (!gradeId) gradeId = document.getElementById('lessonGradeFilter').value;
  if (gradeId) {
    document.getElementById('lessonModalGrade').value = gradeId;
    await onLessonModalGradeChange(l.subject_id);
  }
  document.getElementById('lessonModal').classList.remove('hidden');
}

async function saveLesson() {
  const id = document.getElementById('lessonId').value;
  const gid = document.getElementById('lessonModalGrade').value;
  const sid = document.getElementById('lessonModalSubject').value;
  const titleAr = document.getElementById('lessonTitleAr').value.trim();
  const titleEn = document.getElementById('lessonTitleEn').value.trim();
  const videoUrl = document.getElementById('lessonVideoUrl').value.trim();
  const duration = +document.getElementById('lessonDuration').value || 30;
  const order = +document.getElementById('lessonOrder').value || 1;
  const isActive = document.getElementById('lessonActive').checked;
  const errEl = document.getElementById('lessonModalError');

  if (!gid || !sid) {
    if (errEl) { errEl.textContent = 'يرجى اختيار الصف والمادة أولاً'; errEl.classList.remove('hidden'); }
    return;
  }
  if (!titleAr) {
    if (errEl) { errEl.textContent = 'يرجى إدخال عنوان الدرس'; errEl.classList.remove('hidden'); }
    return;
  }

  const data = {
    subject_id: sid,
    title_ar: titleAr,
    name: titleAr,
    title_en: titleEn,
    video_url: videoUrl,
    duration_min: duration,
    sort_order: order,
    is_active: isActive
  };

  try {
    if (id) await fsUpdate('lessons', id, data);
    else await fsCreate('lessons', data);
    toast(id ? 'تم التحديث بنجاح' : 'تمت إضافة الدرس بنجاح');
    closeModal('lessonModal');

    document.getElementById('lessonGradeFilter').value = gid;
    await loadLessonSubjects();
    document.getElementById('lessonSubjectFilter').value = sid;
    loadLessons();
    loadOverview();
  } catch (e) {
    if (errEl) { errEl.textContent = 'خطأ: ' + e.message; errEl.classList.remove('hidden'); }
  }
}
async function deleteLesson(id) { if (!confirm('حذف هذا الدرس؟')) return; await fsDelete('lessons', id); toast('تم الحذف'); loadLessons(); }

// ── PDFs ──────────────────────────────────────────────────────────────────────
let pdfInputMode = 'link'; // Default to link mode (fastest & 100% free via Google Drive)

function formatDirectPdfUrl(rawUrl) {
  if (!rawUrl) return '';
  let url = rawUrl.trim();
  // Handle Google Drive share links
  const driveMatch = url.match(/\/file\/d\/([a-zA-Z0-9_-]+)/) || url.match(/[?&]id=([a-zA-Z0-9_-]+)/);
  if (driveMatch && (url.includes('drive.google.com') || url.includes('docs.google.com'))) {
    return `https://drive.google.com/uc?export=download&id=${driveMatch[1]}`;
  }
  // Handle Dropbox share links
  if (url.includes('dropbox.com')) {
    return url.replace('?dl=0', '?dl=1').replace('&dl=0', '&dl=1');
  }
  return url;
}

function setPdfMode(mode) {
  pdfInputMode = mode;
  const uploadContainer = document.getElementById('pdfUploadContainer');
  const linkContainer = document.getElementById('pdfLinkContainer');
  const tabUpload = document.getElementById('tabBtnUpload');
  const tabLink = document.getElementById('tabBtnLink');

  if (mode === 'upload') {
    if (uploadContainer) uploadContainer.classList.remove('hidden');
    if (linkContainer) linkContainer.classList.add('hidden');
    if (tabUpload) tabUpload.classList.add('active');
    if (tabLink) tabLink.classList.remove('active');
  } else {
    if (uploadContainer) uploadContainer.classList.add('hidden');
    if (linkContainer) linkContainer.classList.remove('hidden');
    if (tabUpload) tabUpload.classList.remove('active');
    if (tabLink) tabLink.classList.add('active');
  }
}

async function loadPdfSubjects() {
  const gid = document.getElementById('pdfGradeFilter').value;
  const sel = document.getElementById('pdfSubjectFilter');
  sel.innerHTML = '<option value="">— اختر المادة —</option>';
  if (!gid) return;
  try {
    const subs = await fsList('subjects', { where: [['grade_id', '==', gid]] });
    subs.sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0));
    subs.forEach(s => {
      const o = document.createElement('option');
      o.value = s.id;
      o.textContent = s.name_ar;
      sel.appendChild(o);
    });
    if (subs.length > 0) {
      sel.selectedIndex = 1;
      await loadPdfs();
    }
  } catch (e) {
    console.error('loadPdfSubjects error:', e);
  }
}

async function onPdfModalGradeChange(selectSid = null) {
  const gid = document.getElementById('pdfModalGrade').value;
  const sel = document.getElementById('pdfModalSubject');
  sel.innerHTML = '<option value="">— اختر المادة —</option>';
  if (!gid) return;
  try {
    const subs = await fsList('subjects', { where: [['grade_id', '==', gid]] });
    subs.sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0));
    subs.forEach(s => {
      const o = document.createElement('option');
      o.value = s.id;
      o.textContent = s.name_ar;
      sel.appendChild(o);
    });
    if (selectSid) sel.value = selectSid;
    else if (subs.length > 0) sel.selectedIndex = 1;
  } catch (e) {
    console.error('Error loading modal subjects:', e);
  }
}

// ── Interactive lessons (السبورة التفاعلية) ─────────────────────────────────
const generatingLessons = new Set();
function lessonStatusBadge(pdf, il) {
  if (pdf.pdf_type !== 'summary') return '<span style="opacity:.4">—</span>';
  if (generatingLessons.has(pdf.id) || (il && il.status === 'processing')) return '<span class="badge badge-blue">⏳ جارٍ التوليد</span>';
  if (!il) return '<span style="opacity:.5">لم يُولَّد</span>';
  if (il.status === 'error') return `<span class="badge badge-red" title="${(il.error || '').replace(/"/g, '')}">❌ فشل</span>`;
  if (il.status === 'ready') {
    const audio = il.audio_complete ? '🔊' : `🔇 ${il.audio_done || 0}/${il.audio_total || 0}`;
    return `<span class="badge badge-green">✅ جاهز</span> <small>${audio}</small>`;
  }
  return '—';
}
async function generateLessonFor(pdfId, mode = 'full') {
  if (generatingLessons.has(pdfId)) return;
  generatingLessons.add(pdfId);
  toast('⏳ بدأ توليد الشرح التفاعلي بالذكاء الاصطناعي (قد يستغرق 20-30 ثانية)…');
  
  try {
    await db.collection('interactive_lessons').doc(pdfId).set({
      status: 'processing',
      updated: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
  } catch (_) {}
  loadPdfs();

  try {
    // 1. Try Cloud Functions first (if deployed)
    let succeeded = false;
    try {
      const call = functions.httpsCallable('generateInteractiveLesson', { timeout: 180000 });
      const r = (await call({ pdfId, mode })).data || {};
      succeeded = true;
      toast('✅ الشرح التفاعلي جاهز بنجاح!');
    } catch (cfErr) {
      console.warn('Cloud Function unavailable, using direct Gemini generator fallback...', cfErr);
    }

    if (!succeeded && mode === 'audio') {
      // Re-generate only the narration audio from existing slides
      const cDoc = await db.collection('interactive_content').doc(pdfId).get();
      if (!cDoc.exists) throw new Error('لا يوجد محتوى للشرح بعد، ولّد الشرح أولاً');
      const pd = (await db.collection('pdfs').doc(pdfId).get()).data() || {};
      await buildLessonAudio(pdfId, cDoc.data(), await getGeminiKey(), pd.subject_id);
      toast('✅ تم توليد الصوت الخليجي بنجاح!');
    } else if (!succeeded) {
      // 2. Direct Gemini Fallback (Runs on free Spark plan without Cloud Functions)
      const pdfDoc = await db.collection('pdfs').doc(pdfId).get();
      if (!pdfDoc.exists) throw new Error('الملف غير موجود');
      const pdfData = pdfDoc.data();
      const fileUrl = pdfData.file_url;
      if (!fileUrl) throw new Error('رابط الملف غير موجود');

      let geminiKey = await getGeminiKey();

      const title = pdfData.title_ar || pdfData.name || 'درس';
      let subjectName = 'المادة';
      if (pdfData.subject_id) {
        try {
          const sDoc = await db.collection('subjects').doc(pdfData.subject_id).get();
          if (sDoc.exists) subjectName = sDoc.data().name_ar || subjectName;
        } catch (_) {}
      }

      // Download PDF and convert to base64
      const pdfFetch = await fetch(fileUrl);
      if (!pdfFetch.ok) throw new Error('تعذر تحميل ملف الـ PDF من الرابط');
      const pdfBlob = await pdfFetch.blob();
      const pdfBase64 = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result.split(',')[1]);
        reader.onerror = reject;
        reader.readAsDataURL(pdfBlob);
      });

      const prompt = `أنت معلم خبير ومصمم محتوى تعليمي. أمامك ملخص دراسي لمادة "${subjectName}" بعنوان "${title}".
حوّل الملخص إلى درس تفاعلي على شكل شرائح متحركة، وأعد JSON صالحاً فقط بدون أي نص خارجه:
{
  "title": "${title}",
  "subject": "${subjectName}",
  "versions": {
    "mukhtasar": {
      "hook": { "available": false, "text": null, "narration": null },
      "sections": [ { "type": "section", "heading": "...", "content": "...", "narration": "..." } ],
      "zubda": { "text": "...", "narration": "..." }
    },
    "kamila": {
      "hook": { "available": true, "text": "...", "narration": "..." },
      "sections": [ { "type": "section", "heading": "...", "content": "...", "narration": "..." } ],
      "zubda": { "text": "...", "narration": "..." }
    }
  }
}
القواعد:
1) heading: عنوان الشريحة، ضع الكلمات المفتاحية بين [[ ]].
2) content: نص الشريحة (حتى 200 حرف). اكتب المعادلات بيونيكود (x² ، √ ، ± ، ÷ ، × ، ≤ ، ≥ ، π).
3) narration: شرح المعلم بلهجة كويتية بيضاء مفهومة وودودة لطالب أمامك.
4) mukhtasar: من 3 إلى 5 شرائح.
5) kamila: من 6 إلى 12 شريحة تغطي مفاهيم وقوانين الملخص.
6) zubda: خلاصة في جملتين.`;

      const gRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: prompt },
              { inline_data: { mime_type: 'application/pdf', data: pdfBase64 } }
            ]
          }],
          generationConfig: {
            responseMimeType: 'application/json',
            temperature: 0.3
          }
        })
      });

      const gData = await gRes.json();
      if (!gData.candidates || !gData.candidates[0]) {
        throw new Error(gData.error?.message || 'لم يرجع نموذج الذكاء الاصطناعي رداً صالحاً');
      }

      const lessonData = JSON.parse(gData.candidates[0].content.parts[0].text);
      lessonData.common = {
        welcome: { narration: 'مرحباً بكم في منصة تَم التعليمية' },
        intro: { narration: `درسنا اليوم: ${title}` }
      };

      // Save slides first (so text is never lost), then add the voice
      await db.collection('interactive_content').doc(pdfId).set(lessonData);
      await db.collection('interactive_lessons').doc(pdfId).set({
        pdf_id: pdfId,
        subject_id: pdfData.subject_id,
        title_ar: title,
        status: 'processing',
        error: null,
        country: 'kw',
        slides_mukhtasar: lessonData.versions?.mukhtasar?.sections?.length || 0,
        slides_kamila: lessonData.versions?.kamila?.sections?.length || 0,
        updated: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      await buildLessonAudio(pdfId, lessonData, geminiKey, pdfData.subject_id);
      toast('✅ تم توليد الشرح التفاعلي بالصوت الخليجي بنجاح!');
    }
  } catch (e) {
    console.error('Interactive lesson generation error:', e);
    await db.collection('interactive_lessons').doc(pdfId).set({
      status: 'error',
      error: e.message || 'فشل التوليد',
      updated: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    toast('❌ تعذر توليد الشرح: ' + (e.message || ''), 'error');
  } finally {
    generatingLessons.delete(pdfId);
    loadPdfs();
  }
}

// ── Gulf-accent narration (Gemini TTS → MP3 → Firestore) ─────────────────────
const TTS_MODELS = ['gemini-3.8-flash-tts', 'gemini-3.8-flash-lite-tts', 'gemini-3.1-flash-tts-preview', 'gemini-2.5-flash-preview-tts'];
const ttsExhausted = new Set();
const TTS_STYLE = "# AUDIO PROFILE: Ustaz Tam\n## THE SCENE: A calm, friendly classroom in Kuwait.\n### DIRECTOR'S NOTES\n" +
  'Style: a warm, clear and confident school teacher explaining to a student; natural and encouraging.\n' +
  'Accent: natural Kuwaiti Gulf Arabic.\n' +
  'Pace: calm and steady, with short natural pauses between sentences.\n' +
  'Pronunciation: scientific terms pronounced accurately.\n\n#### TRANSCRIPT\n';
const sleepMs = (ms) => new Promise(r => setTimeout(r, ms));

async function getGeminiKey() {
  try {
    const d = await db.collection('config').doc('ai').get();
    if (d.exists && d.data().gemini_api_key) return d.data().gemini_api_key;
  } catch (_) {}
  return atob('QVEuQWI4Uk42Sjc4NWRnYjVKZHFhQ1Y1bjZvSl9RVGxrbFg4UG9LUTd5OHYtQ2xDRGh5LXc=');
}

async function geminiCall(model, key, body) {
  for (let a = 0; a < 5; a++) {
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
      body: JSON.stringify(body)
    });
    if (r.ok) return r.json();
    if (r.status === 429 && model.includes('tts')) { const e = new Error('quota'); e.quota = true; throw e; }
    if (r.status === 429 || r.status >= 500) { await sleepMs(6000 * (a + 1)); continue; }
    throw new Error(`${model}: HTTP ${r.status}`);
  }
  throw new Error(`${model}: فشل بعد عدة محاولات`);
}

function lessonSegments(c) {
  const segs = [c.common.welcome, c.common.intro];
  for (const v of [c.versions.mukhtasar, c.versions.kamila]) {
    if (v.hook && v.hook.available && v.hook.narration) segs.push(v.hook);
    segs.push(...v.sections, v.zubda);
  }
  return segs.filter(s => s && (s.narration || '').trim());
}

async function polishNarrations(key, narrations, subject, title) {
  const prompt = `أنت معلم كويتي خبير تكتب نصوص شرح تُقرأ بصوت عالٍ (TTS) لدرس "${title}" في مادة "${subject}".
أمامك مصفوفة JSON من ${narrations.length} نصاً منطوقاً. أعد كتابة كل نص ليكون:
1) بلهجة خليجية كويتية بيضاء مفهومة وطبيعية (مثل: شنو، وايد، يعني، تعال نشوف، لاحظ، زين) بدون مبالغة، مع الحفاظ على الفصحى للمصطلحات العلمية.
2) نطق صحيح: اكتب الأرقام والرموز والوحدات والمعادلات بالحروف كما تُنطق تماماً، والحروف اللاتينية بنطقها العربي.
3) ضع التشكيل الكامل فقط على الكلمات التي قد يُلتبس نطقها (المصطلحات العلمية والأسماء).
4) جمل قصيرة (8 إلى 14 كلمة) مع علامات ترقيم واضحة ليكون الإيقاع طبيعياً.
5) حافظ على نفس المعنى العلمي بدقة، بدون إضافة أو حذف أي فكرة.
6) لا إيموجي ولا ماركداون ولا أقواس مربعة.
أعد JSON فقط: مصفوفة نصوص بنفس العدد والترتيب.

${JSON.stringify(narrations)}`;
  const j = await geminiCall('gemini-2.5-flash', key, {
    contents: [{ parts: [{ text: prompt }] }],
    generationConfig: { responseMimeType: 'application/json', temperature: 0.3 }
  });
  const arr = JSON.parse(j.candidates[0].content.parts[0].text);
  if (!Array.isArray(arr) || arr.length !== narrations.length) return narrations;
  return arr.map((x, i) => (typeof x === 'string' && x.trim() ? x.trim() : narrations[i]));
}

async function ttsClip(key, voice, text) {
  for (let a = 0; a < 4; a++) {
    const model = TTS_MODELS.find(m => !ttsExhausted.has(m));
    if (!model) throw new Error('انتهت حصة توليد الصوت المجانية اليوم، أعد المحاولة بعد بضع ساعات (زر 🔊)');
    let j;
    try {
      j = await geminiCall(model, key, {
        contents: [{ parts: [{ text: TTS_STYLE + text }] }],
        generationConfig: {
          responseModalities: ['AUDIO'],
          speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: voice } } }
        }
      });
    } catch (e) {
      if (e.quota) { ttsExhausted.add(model); a--; continue; }
      throw e;
    }
    const p = j.candidates?.[0]?.content?.parts?.find(x => x.inlineData?.data);
    if (p) {
      const bin = atob(p.inlineData.data);
      const bytes = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      return new Int16Array(bytes.buffer, 0, Math.floor(bytes.length / 2));
    }
    await sleepMs(2500);
  }
  throw new Error('فشل توليد الصوت');
}

function pcmToMp3B64(samples, kbps) {
  if (typeof lamejs === 'undefined') throw new Error('مكتبة تحويل الصوت لم تُحمّل، حدّث الصفحة');
  const enc = new lamejs.Mp3Encoder(1, 24000, kbps);
  const parts = [];
  for (let i = 0; i < samples.length; i += 1152) {
    const b = enc.encodeBuffer(samples.subarray(i, i + 1152));
    if (b.length) parts.push(b);
  }
  const t = enc.flush();
  if (t.length) parts.push(t);
  const total = parts.reduce((a, p) => a + p.length, 0);
  const all = new Uint8Array(total);
  let off = 0;
  parts.forEach(p => { all.set(p, off); off += p.length; });
  let s = '';
  for (let i = 0; i < all.length; i += 0x8000) s += String.fromCharCode.apply(null, all.subarray(i, i + 0x8000));
  return { b64: btoa(s), bytes: total, duration: samples.length / 24000 };
}

async function buildLessonAudio(pdfId, content, key, subjectId) {
  const voice = 'Charon';
  let subject = content.subject || '';
  const segs = lessonSegments(content);
  if (!content.polished) {
    const polished = await polishNarrations(key, segs.map(s => s.narration), subject, content.title || '');
    segs.forEach((s, i) => { s.narration = polished[i]; delete s.audio; });
    content.common.welcome.narration = 'مَرحبًا بِكم في مِنَصَّةِ تَمّ التَعليمِيَّة.';
    content.common.intro.narration = `دَرسنا اليوم: ${content.title}.`;
    content.polished = true;
    await db.collection('interactive_content').doc(pdfId).set(content);
  }

  const cache = new Map();
  let done = 0;
  let stopErr = null;
  for (let i = 0; i < segs.length; i++) {
    const s = segs[i];
    const text = s.narration.trim();
    if (s.audio && s.audio.path) { cache.set(text, s.audio); done++; continue; }
    if (cache.has(text)) { s.audio = cache.get(text); done++; continue; }
    toast(`🎙️ توليد الصوت ${i + 1}/${segs.length}…`);
    try {
      const pcm = await ttsClip(key, voice, text);
      let mp = pcmToMp3B64(pcm, 56);
      if (mp.b64.length > 900000) mp = pcmToMp3B64(pcm, 32);
      const id = `${pdfId}_${String(i).padStart(2, '0')}`;
      await db.collection('interactive_audio').doc(id).set({
        pdf_id: pdfId, voice, duration: +mp.duration.toFixed(2), bytes: mp.bytes, data: mp.b64
      });
      const ref = { path: `fs:interactive_audio/${id}`, duration: +mp.duration.toFixed(2) };
      cache.set(text, ref);
      s.audio = ref;
      done++;
      await sleepMs(1200);
    } catch (e) { stopErr = e; break; }
  }
  content.voice = voice;
  await db.collection('interactive_content').doc(pdfId).set(content);
  const dur = (v) => Math.round([content.common.welcome, content.common.intro, ...v.sections, v.zubda, ...(v.hook && v.hook.available ? [v.hook] : [])]
    .reduce((a, s) => a + ((s.audio && s.audio.duration) || 0), 0));
  await db.collection('interactive_lessons').doc(pdfId).set({
    pdf_id: pdfId, subject_id: subjectId || '', title_ar: content.title || '',
    status: 'ready', error: null,
    duration_mukhtasar: dur(content.versions.mukhtasar),
    duration_kamila: dur(content.versions.kamila),
    audio_done: done, audio_total: segs.length, audio_complete: done >= segs.length, voice,
    updated: firebase.firestore.FieldValue.serverTimestamp()
  }, { merge: true });
  if (stopErr) toast('⚠️ تم توليد ' + done + ' من ' + segs.length + ' مقطع صوتي، أكمل لاحقاً بزر 🔊: ' + stopErr.message, 'error');
}

async function loadPdfs() {
  const sid = document.getElementById('pdfSubjectFilter').value;
  if (!sid) { document.getElementById('pdfsList').innerHTML = '<p class="empty-msg">اختر مادة لعرض الملفات</p>'; return; }
  try {
    const items = await fsList('pdfs', { where: [['subject_id', '==', sid]] });
    if (!items.length) { document.getElementById('pdfsList').innerHTML = '<p class="empty-msg">لا توجد ملفات مرفوعة لهذه المادة حتى الآن</p>'; return; }
    let ilMap = {};
    try { (await fsList('interactive_lessons', { where: [['subject_id', '==', sid]] })).forEach(x => ilMap[x.id] = x); } catch (e) { console.warn('interactive_lessons load failed', e); }
    const types = { summary: 'ملخص', exam_answer: 'حل امتحان', worksheet: 'ورقة عمل' };
    let h = '<table><thead><tr><th>العنوان</th><th>النوع</th><th>الملف</th><th>الشرح التفاعلي</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>';
    items.forEach(p => {
      const il = ilMap[p.id];
      const isSummary = p.pdf_type === 'summary';
      const genBtn = isSummary ? `<button class="btn-icon" title="توليد / إعادة توليد الشرح التفاعلي" onclick="generateLessonFor('${p.id}')">🎬</button>` : '';
      const audioBtn = (isSummary && il && il.status === 'ready' && !il.audio_complete) ? `<button class="btn-icon" title="إكمال الصوت الناقص" onclick="generateLessonFor('${p.id}','audio')">🔊</button>` : '';
      const linkBtn = p.file_url ? `<a href="${p.file_url}" target="_blank" class="btn-icon" title="معاينة أو تحميل الملف" style="text-decoration:none;display:inline-flex;align-items:center;justify-content:center;">📥</a>` : '<span style="opacity:0.3">—</span>';
      h += `<tr><td>${p.title_ar || p.name || 'ملف بدون عنوان'}</td><td><span class="badge badge-blue">${types[p.pdf_type] || p.pdf_type || '—'}</span></td><td>${linkBtn}</td><td>${lessonStatusBadge(p, il)}</td><td><label class="toggle-switch"><input type="checkbox" ${p.is_active ? 'checked' : ''} onchange="togglePdf('${p.id}',this.checked)"/><div class="toggle-track"></div></label></td><td class="actions-cell">${genBtn}${audioBtn}<button class="btn-icon btn-danger" onclick="deletePdf('${p.id}')" title="حذف الملف">🗑️</button></td></tr>`;
    });
    document.getElementById('pdfsList').innerHTML = h + '</tbody></table>';
  } catch (e) { document.getElementById('pdfsList').innerHTML = '<p class="empty-msg">خطأ: ' + e.message + '</p>'; }
}
async function togglePdf(id, v) { try { await fsUpdate('pdfs', id, { is_active: v }); toast(v ? 'مرئي للطلاب' : 'مخفي عن الطلاب'); loadPdfs(); } catch (e) { toast('خطأ: ' + e.message, 'error'); } }

function onFileSelected(input) {
  const file = input.files[0];
  const nameEl = document.getElementById('fileSelectedName');
  const titleArEl = document.getElementById('pdfTitleAr');
  if (file) {
    const sizeMB = (file.size / (1024 * 1024)).toFixed(2);
    nameEl.textContent = `✅ تم اختيار: ${file.name} (${sizeMB} ميغابايت)`;
    if (!titleArEl.value.trim()) {
      titleArEl.value = file.name.replace(/\.[^/.]+$/, "");
    }
  } else {
    nameEl.textContent = '';
  }
}

function updatePdfProgress(pct) {
  const box = document.getElementById('pdfUploadProgressBox');
  const bar = document.getElementById('pdfProgressBar');
  const label = document.getElementById('pdfProgressPercent');
  if (box) box.classList.remove('hidden');
  if (bar) bar.style.width = pct + '%';
  if (label) label.textContent = pct + '%';
}

function resetPdfProgress() {
  const box = document.getElementById('pdfUploadProgressBox');
  const bar = document.getElementById('pdfProgressBar');
  const label = document.getElementById('pdfProgressPercent');
  if (box) box.classList.add('hidden');
  if (bar) bar.style.width = '0%';
  if (label) label.textContent = '0%';
}

function showPdfModalError(msg) {
  const errEl = document.getElementById('pdfModalError');
  if (errEl) {
    errEl.innerHTML = msg;
    errEl.classList.remove('hidden');
  } else {
    toast(msg.replace(/<[^>]*>?/gm, ''), 'error');
  }
}

async function openAddPdfModal() {
  document.getElementById('pdfId').value = '';
  document.getElementById('pdfTitleAr').value = '';
  document.getElementById('pdfTitleEn').value = '';
  document.getElementById('pdfType').value = 'summary';
  document.getElementById('pdfActive').checked = true;
  document.getElementById('pdfFileInput').value = '';
  document.getElementById('fileSelectedName').textContent = '';
  const directUrlInput = document.getElementById('pdfDirectUrl');
  if (directUrlInput) directUrlInput.value = '';
  const errEl = document.getElementById('pdfModalError');
  if (errEl) errEl.classList.add('hidden');
  resetPdfProgress();
  setPdfMode('link'); // Default to direct link (works instantly without Firebase Storage)

  const filterGid = document.getElementById('pdfGradeFilter').value;
  const filterSid = document.getElementById('pdfSubjectFilter').value;
  if (filterGid) {
    document.getElementById('pdfModalGrade').value = filterGid;
    await onPdfModalGradeChange(filterSid);
  } else {
    const gradeSel = document.getElementById('pdfModalGrade');
    if (gradeSel.options.length > 1) {
      gradeSel.selectedIndex = 1;
      await onPdfModalGradeChange();
    }
  }
  document.getElementById('pdfModal').classList.remove('hidden');
}

async function savePdf() {
  const gradeId = document.getElementById('pdfModalGrade').value;
  const sid = document.getElementById('pdfModalSubject').value;
  const fi = document.getElementById('pdfFileInput');
  const rawDirectUrl = document.getElementById('pdfDirectUrl')?.value.trim() || '';
  const directUrl = formatDirectPdfUrl(rawDirectUrl);
  let titleAr = document.getElementById('pdfTitleAr').value.trim();
  const titleEn = document.getElementById('pdfTitleEn').value.trim();
  const pdfType = document.getElementById('pdfType').value;
  const isActive = document.getElementById('pdfActive').checked;
  const errEl = document.getElementById('pdfModalError');
  const saveBtn = document.getElementById('btnSavePdf');

  if (errEl) errEl.classList.add('hidden');

  if (!gradeId) {
    showPdfModalError('يرجى اختيار الصف الدراسي أولاً');
    return;
  }
  if (!sid) {
    showPdfModalError('يرجى اختيار المادة الدراسية');
    return;
  }

  const file = fi.files[0];
  if (pdfInputMode === 'upload' && !file) {
    showPdfModalError('يرجى اختيار ملف PDF من جهازك أو التبديل إلى "رابط ملف مباشر"');
    return;
  }
  if (pdfInputMode === 'link' && !directUrl) {
    showPdfModalError('يرجى إدخال رابط ملف الـ PDF (رابط مباشر أو رابط مشاركة من Google Drive)');
    return;
  }

  if (!titleAr) {
    if (file) {
      titleAr = file.name.replace(/\.[^/.]+$/, "");
      document.getElementById('pdfTitleAr').value = titleAr;
    } else {
      titleAr = 'ملف بدون عنوان';
    }
  }

  saveBtn.disabled = true;
  saveBtn.textContent = '⏳ جارٍ حفظ الملف...';

  try {
    let fileUrl = directUrl;

    if (pdfInputMode === 'upload' && file) {
      const cleanFileName = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
      const storagePath = `pdfs/${Date.now()}_${cleanFileName}`;
      const fileRef = storage.ref(storagePath);

      fileUrl = await new Promise((resolve, reject) => {
        let finished = false;
        const uploadTask = fileRef.put(file);

        // Safety timeout: prevents infinite freeze if Storage bucket is absent/unprovisioned
        const timer = setTimeout(() => {
          if (!finished) {
            finished = true;
            try { uploadTask.cancel(); } catch (_) {}
            reject(new Error('STORAGE_TIMEOUT'));
          }
        }, 6000);

        uploadTask.on(
          'state_changed',
          (snapshot) => {
            if (snapshot.totalBytes > 0) {
              const progress = Math.round((snapshot.bytesTransferred / snapshot.totalBytes) * 100);
              updatePdfProgress(progress);
            }
          },
          (error) => {
            if (!finished) {
              finished = true;
              clearTimeout(timer);
              reject(error);
            }
          },
          async () => {
            try {
              const downloadUrl = await uploadTask.snapshot.ref.getDownloadURL();
              if (!finished) {
                finished = true;
                clearTimeout(timer);
                resolve(downloadUrl);
              }
            } catch (err) {
              if (!finished) {
                finished = true;
                clearTimeout(timer);
                reject(err);
              }
            }
          }
        );
      });
    }

    const created = await fsCreate('pdfs', {
      grade_id: gradeId,
      subject_id: sid,
      title_ar: titleAr,
      name: titleAr,
      title_en: titleEn,
      pdf_type: pdfType,
      is_active: isActive,
      file_url: fileUrl,
      created_at: firebase.firestore.FieldValue.serverTimestamp()
    });

    toast('✅ تم حفظ ملف الـ PDF بنجاح في قاعدة البيانات!');
    closeModal('pdfModal');

    document.getElementById('pdfGradeFilter').value = gradeId;
    await loadPdfSubjects();
    document.getElementById('pdfSubjectFilter').value = sid;
    await loadPdfs();

    if (pdfType === 'summary' && fileUrl) {
      generateLessonFor(created.id);
    }
  } catch (e) {
    console.error('Error saving PDF:', e);
    resetPdfProgress();

    const isStorageIssue = (
      e.message === 'STORAGE_TIMEOUT' ||
      e.code === 'storage/unknown' ||
      e.code === 'storage/bucket-not-found' ||
      e.code === 'storage/unauthorized' ||
      (e.message && (e.message.includes('bucket') || e.message.includes('Storage') || e.message.includes('storage') || e.message.includes('network')))
    );

    if (isStorageIssue) {
      showPdfModalError(`
        <div style="text-align:right; font-size:0.88rem; line-height:1.7;">
          <div style="font-weight:bold; color:#ef4444; font-size:0.95rem; margin-bottom:6px;">
            ⚠️ تعذر رفع الملف من الجهاز مباشرة (خدمة Firebase Storage غير مفعّلة في المشروع)
          </div>
          <p style="margin:0 0 10px; color:#cbd5e1;">
            مشروع Firebase مجاني حالياً (Spark) ويتطلب ترقية سريعة في لوحة Firebase لتفعيل مساحة التخزين السحابية.
          </p>
          <div style="background:rgba(16,185,129,0.15); border:1px solid rgba(16,185,129,0.3); border-radius:8px; padding:10px 12px; margin-bottom:10px;">
            <strong style="color:#34d399;">💡 الحل الفوري (بدون الحاجة لترقية أو بطاقة):</strong><br/>
            1. ارفع ملف الـ PDF إلى حسابك في <strong>Google Drive</strong>.<br/>
            2. اضغط مشاركة (Share) واجعله (عام - متاح لأي شخص لديه الرابط).<br/>
            3. انقر الزر أدناه والصق الرابط واضغط حفظ فوراً!
          </div>
          <button type="button" class="btn-primary" style="padding:6px 16px; font-size:0.85rem;" onclick="setPdfMode('link'); document.getElementById('pdfDirectUrl').focus();">
            🔗 التبديل إلى رابط مباشر الآن
          </button>
        </div>
      `);
    } else {
      showPdfModalError(e.message || 'حدث خطأ أثناء حفظ الملف');
    }
  } finally {
    saveBtn.disabled = false;
    saveBtn.textContent = 'رفع وحفظ الملف';
  }
}

async function deletePdf(id) {
  if (!confirm('حذف هذا الملف نهائياً؟')) return;
  try {
    await fsDelete('pdfs', id);
    try { await fsDelete('interactive_lessons', id); await fsDelete('interactive_content', id); } catch (e) { }
    toast('✅ تم حذف الملف بنجاح');
    loadPdfs();
  } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}

// ── Students ──────────────────────────────────────────────────────────────────
let allStudents = [];
let activeSubKeys = new Set();
async function loadStudents() {
  try {
    allStudents = await fsList('users', { orderBy: 'created', orderDir: 'desc' });
    // Active subscription records (uid or email) — covers in-app purchases.
    activeSubKeys = new Set();
    try {
      const subs = await fsList('subscriptions');
      const today = new Date().toISOString().split('T')[0];
      subs.forEach(x => {
        if (x.status === 'active' && (!x.end_date || x.end_date >= today)) {
          if (x.firebase_uid) activeSubKeys.add(x.firebase_uid);
          if (x.user_email) activeSubKeys.add(String(x.user_email).toLowerCase());
        }
      });
    } catch (e) { console.error('subscriptions load failed', e); }
    renderStudents(allStudents);
  } catch (e) {
    document.getElementById('studentsList').innerHTML =
      `<p class="empty-msg">❌ خطأ في تحميل الطلاب: ${e.message}</p>`;
  }
}
function searchStudents() { const q = document.getElementById('studentSearch').value.toLowerCase(); renderStudents(allStudents.filter(s => (s.name || '').toLowerCase().includes(q) || (s.email || '').toLowerCase().includes(q))); }
function renderStudents(list) {
  if (!list.length) { document.getElementById('studentsList').innerHTML = '<p class="empty-msg">لا يوجد طلاب</p>'; return; }
  let h = '<table><thead><tr><th>الاسم</th><th>البريد</th><th>الصف/الشعبة</th><th>الحالة</th><th>الاشتراك</th><th>تاريخ التسجيل</th><th>إجراءات</th></tr></thead><tbody>';
  list.forEach(s => {
    const sectionName = s.section === 'scientific' ? 'علمي' : (s.section === 'literary' ? 'أدبي' : s.section || '—');
    const isBlocked = s.is_blocked === true;
    const isSubscribed = s.is_subscribed === true ||
      activeSubKeys.has(s.firebase_uid || s.id) ||
      (s.email && activeSubKeys.has(String(s.email).toLowerCase()));
    h += `<tr>
      <td>${s.name || '—'}</td>
      <td>${s.email || '—'}</td>
      <td>الصف ${s.grade || '—'} (${sectionName})</td>
      <td>${isBlocked ? '<span class="badge badge-red">🚫 محظور</span>' : '<span class="badge badge-green">نشط</span>'}</td>
      <td>${isSubscribed ? '<span class="badge badge-green">✓ مشترك</span>' : '<span class="badge badge-red">غير مشترك</span>'}</td>
      <td>${s.created ? new Date(s.created.seconds * 1000).toLocaleDateString('ar') : '—'}</td>
      <td class="actions-cell">
        <button class="btn-icon" onclick="openStudentModal('${s.id}')" title="تعديل الطالب">✏️</button>
        <button class="btn-icon" onclick="toggleBlockStudent('${s.id}', ${isBlocked})" title="${isBlocked ? 'إلغاء الحظر' : 'حظر الطالب'}">${isBlocked ? '🔓' : '🚫'}</button>
        <button class="btn-icon" onclick="openEditSubscriptionDurationModal('${s.id}', '${s.email || ''}', '${s.firebase_uid || s.id}')" title="تعديل مدة الاشتراك">💰</button>
        <button class="btn-icon btn-danger" onclick="deleteStudent('${s.id}')" title="حذف الطالب">🗑️</button>
      </td>
    </tr>`;
  });
  document.getElementById('studentsList').innerHTML = h + '</tbody></table>';
}

function openStudentModal(id = '') {
  if (id) {
    document.getElementById('studentId').value = id;
    const s = allStudents.find(x => x.id === id);
    if (!s) return;
    document.getElementById('studentModalTitle').innerText = 'تعديل بيانات الطالب';
    document.getElementById('studentName').value = s.name || '';
    document.getElementById('studentEmail').value = s.email || '';
    document.getElementById('studentPassword').value = s.password || '';
    const hint = document.getElementById('studentPasswordHint');
    if (hint) hint.innerText = '💡 لتغيير كلمة مرور الطالب: اضغط الزر أدناه لإرسال رابط إعادة التعيين لإيميله، أو اكتبها (6 أحرف على الأقل).';
    const btnReset = document.getElementById('btnSendStudentReset');
    if (btnReset) btnReset.style.display = 'inline-block';
    document.getElementById('studentGrade').value = s.grade || '12';
    document.getElementById('studentSection').value = s.section || 'scientific';
    document.getElementById('studentSubscribedContainer').classList.add('hidden');
    document.getElementById('studentModalBtn').innerText = 'حفظ التعديلات ✅';
  } else {
    document.getElementById('studentId').value = '';
    document.getElementById('studentModalTitle').innerText = 'إضافة طالب جديد';
    document.getElementById('studentName').value = '';
    document.getElementById('studentEmail').value = '';
    document.getElementById('studentPassword').value = '';
    const hint = document.getElementById('studentPasswordHint');
    if (hint) hint.innerText = 'كلمة المرور يجب ألا تقل عن 6 أحرف ليتمكن الطالب من الدخول للتطبيق.';
    const btnReset = document.getElementById('btnSendStudentReset');
    if (btnReset) btnReset.style.display = 'none';
    document.getElementById('studentGrade').value = '12';
    document.getElementById('studentSection').value = 'scientific';
    document.getElementById('studentSubscribed').checked = false;
    document.getElementById('studentSubscribedContainer').classList.remove('hidden');
    document.getElementById('studentModalBtn').innerText = 'إضافة الطالب ✅';
  }
  document.getElementById('studentModal').classList.remove('hidden');
}

async function sendStudentPasswordReset() {
  const email = document.getElementById('studentEmail').value.trim();
  if (!email) { toast('أدخل البريد الإلكتروني للطالب أولاً', 'error'); return; }
  try {
    await auth.sendPasswordResetEmail(email);
    toast('✅ تم إرسال رابط تعيين كلمة المرور إلى إيميل الطالب (' + email + ')');
  } catch (e) { toast('خطأ في الإرسال: ' + e.message, 'error'); }
}

async function saveStudent() {
  const id = document.getElementById('studentId').value;
  const name = document.getElementById('studentName').value.trim();
  const email = document.getElementById('studentEmail').value.trim();
  const password = document.getElementById('studentPassword').value.trim();
  const grade = parseInt(document.getElementById('studentGrade').value) || 12;
  const section = document.getElementById('studentSection').value;

  if (!name || !email) { toast('يرجى إدخال الاسم والبريد الإلكتروني', 'error'); return; }

  if (id) {
    // Edit existing student in Firestore
    try {
      if (password && password.length < 6) {
        toast('تنبيه: كلمة المرور في فايربيس يجب ألا تقل عن 6 أحرف', 'error');
        return;
      }
      const payload = { name, email, grade, section };
      if (password) payload.password = password;
      await fsUpdate('users', id, payload);
      toast('✅ تم تحديث بيانات الطالب بنجاح');
      closeModal('studentModal');
      loadStudents();
    } catch (e) { toast('خطأ: ' + e.message, 'error'); }
  } else {
    // Add new student
    if (!password || password.length < 6) { toast('يرجى إدخال كلمة مرور لا تقل عن 6 أحرف', 'error'); return; }

    try {
      // Create in Firebase Auth via REST API
      const fbRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${firebaseConfig.apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: false })
      });
      if (!fbRes.ok) {
        const errData = await fbRes.json();
        const errMsg = errData.error ? errData.error.message : '';
        if (errMsg === 'EMAIL_EXISTS') { toast('هذا البريد الإلكتروني مسجل بالفعل', 'error'); return; }
        else { toast('خطأ في التسجيل: ' + errMsg, 'error'); return; }
      }
      const fbData = await fbRes.json();
      const firebase_uid = fbData.localId;
      const is_subscribed = document.getElementById('studentSubscribed').checked;

      // Create user doc in Firestore with UID as document ID
      await fsCreateWithId('users', firebase_uid, {
        firebase_uid, name, email, grade, section, lang: 'ar',
        is_subscribed, is_blocked: false
      });

      if (is_subscribed) {
        const today = new Date().toISOString().split('T')[0];
        const end = new Date(); end.setDate(end.getDate() + 30);
        await fsCreate('subscriptions', {
          user_email: email, firebase_uid,
          plan: 'custom', status: 'active',
          start_date: today, end_date: end.toISOString().split('T')[0]
        });
      }
      toast('✅ تم إضافة الطالب بنجاح');
      closeModal('studentModal');
      loadStudents();
    } catch (e) { toast('خطأ: ' + e.message, 'error'); }
  }
}

async function toggleBlockStudent(id, currentBlocked) {
  const actionText = currentBlocked ? 'إلغاء حظر هذا الطالب؟' : 'حظر هذا الطالب ومنعه من استخدام التطبيق؟';
  if (!confirm(actionText)) return;
  try {
    await fsUpdate('users', id, { is_blocked: !currentBlocked });
    toast(currentBlocked ? '✅ تم إلغاء حظر الطالب' : '🚫 تم حظر الطالب');
    loadStudents();
  } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}

async function openEditSubscriptionDurationModal(studentId, email, firebaseUid) {
  document.getElementById('editSubStudentId').value = studentId;
  document.getElementById('editSubStudentEmail').value = email;
  document.getElementById('editSubStudentUid').value = firebaseUid || studentId;
  document.getElementById('editSubEmailDisplay').value = email;

  let currentSub = null;
  try {
    let subs = [];
    if (firebaseUid) subs = await fsList('subscriptions', { where: [['firebase_uid', '==', firebaseUid]] });
    if (!subs.length && email) subs = await fsList('subscriptions', { where: [['user_email', '==', email]] });
    if (subs.length) currentSub = subs.sort((a, b) => (b.created?.seconds || 0) - (a.created?.seconds || 0))[0];
  } catch (e) { console.error('Error fetching subscription:', e); }

  const statusEl = document.getElementById('editSubStatusDisplay');
  const endDateEl = document.getElementById('editSubEndDate');

  if (currentSub && currentSub.status === 'active') {
    statusEl.innerHTML = `<span class="badge badge-green">فعّال</span> ينتهي في ${currentSub.end_date || 'غير محدد'}`;
    endDateEl.value = currentSub.end_date || new Date().toISOString().split('T')[0];
  } else {
    statusEl.innerHTML = `<span class="badge badge-red">غير مشترك</span>`;
    const defaultEnd = new Date(); defaultEnd.setDate(defaultEnd.getDate() + 30);
    endDateEl.value = defaultEnd.toISOString().split('T')[0];
  }
  document.getElementById('editSubDurationModal').classList.remove('hidden');
}

async function saveSubscriptionDuration() {
  const studentId = document.getElementById('editSubStudentId').value;
  const email = document.getElementById('editSubStudentEmail').value;
  const firebaseUid = document.getElementById('editSubStudentUid').value || studentId;
  const newEndDate = document.getElementById('editSubEndDate').value;
  if (!newEndDate) { toast('يرجى تحديد تاريخ الانتهاء', 'error'); return; }

  try {
    let subs = [];
    if (firebaseUid) {
      subs = await fsList('subscriptions', { where: [['firebase_uid', '==', firebaseUid]] });
    }
    if (!subs.length && email) {
      subs = await fsList('subscriptions', { where: [['user_email', '==', email]] });
    }
    const today = new Date().toISOString().split('T')[0];
    const isFuture = newEndDate >= today;

    if (subs.length) {
      const latest = subs.sort((a, b) => (b.created?.seconds || 0) - (a.created?.seconds || 0))[0];
      await fsUpdate('subscriptions', latest.id, {
        end_date: newEndDate,
        status: isFuture ? 'active' : 'expired',
        firebase_uid: firebaseUid,
        user_email: email
      });
    } else {
      await fsCreate('subscriptions', {
        user_email: email,
        firebase_uid: firebaseUid,
        plan: 'custom',
        status: isFuture ? 'active' : 'expired',
        start_date: today,
        end_date: newEndDate
      });
    }
    await fsUpdate('users', studentId, {
      is_subscribed: isFuture,
      isSubscribed: isFuture,
      subscriptionExpiry: newEndDate + 'T23:59:59.000Z'
    });
    toast('✅ تم تعديل مدة الاشتراك بنجاح');
    closeModal('editSubDurationModal');
    loadStudents();
  } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}

async function deleteStudent(id) {
  if (!confirm('تحذير: هل تريد حذف هذا الطالب نهائياً؟ لا يمكن التراجع.')) return;
  try { await fsDelete('users', id); toast('تم حذف الطالب بنجاح'); loadStudents(); } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}

// ── Subscriptions ─────────────────────────────────────────────────────────────
async function loadSubscriptions() {
  try {
    const items = await fsList('subscriptions', { orderBy: 'created', orderDir: 'desc' });
    const toolbar = `<div class="section-toolbar" style="margin-bottom:1rem"><h3>الاشتراكات</h3><button class="btn-primary" onclick="openAddSubscriptionModal()">+ إضافة اشتراك</button></div>`;
    if (!items.length) { document.getElementById('subscriptionsList').innerHTML = toolbar + '<p class="empty-msg">لا توجد اشتراكات</p>'; return; }
    const st = { active: 'فعّال', expired: 'منتهي', cancelled: 'ملغي' };
    const bc = { active: 'badge-green', expired: 'badge-red', cancelled: 'badge-amber' };
    let h = toolbar + '<table><thead><tr><th>البريد</th><th>Firebase UID</th><th>الخطة</th><th>الحالة</th><th>البداية</th><th>النهاية</th><th>إجراءات</th></tr></thead><tbody>';
    items.forEach(s => {
      const status = s.status || '—';
      h += `<tr><td>${s.user_email || '—'}</td><td style="font-size:0.75rem;color:var(--text-muted)">${(s.firebase_uid || '').substring(0, 14)}…</td><td>${s.plan || '—'}</td><td><span class="badge ${bc[status] || ''}">${st[status] || status}</span></td><td>${s.start_date ? new Date(s.start_date).toLocaleDateString('ar') : '—'}</td><td>${s.end_date ? new Date(s.end_date).toLocaleDateString('ar') : '—'}</td><td class="actions-cell">${status !== 'active' ? `<button class="btn-icon" onclick="activateSub('${s.id}')">✅</button>` : ''} ${status === 'active' ? `<button class="btn-icon btn-danger" onclick="cancelSub('${s.id}')">🚫</button>` : ''}<button class="btn-icon btn-danger" onclick="deleteSub('${s.id}')">🗑️</button></td></tr>`;
    });
    document.getElementById('subscriptionsList').innerHTML = h + '</tbody></table>';
  } catch (e) { document.getElementById('subscriptionsList').innerHTML = '<p class="empty-msg">خطأ: ' + e.message + '</p>'; }
}
async function activateSub(id) {
  const today = new Date().toISOString().split('T')[0];
  const end = new Date(); end.setDate(end.getDate() + 180);
  try {
    await fsUpdate('subscriptions', id, { status: 'active', start_date: today, end_date: end.toISOString().split('T')[0] });
    const rec = await fsGet('subscriptions', id);
    if (rec && rec.firebase_uid) {
      try { await fsUpdate('users', rec.firebase_uid, { is_subscribed: true }); } catch { }
    }
    toast('✅ تم تفعيل الاشتراك'); loadSubscriptions();
  } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}
async function cancelSub(id) {
  if (!confirm('إلغاء هذا الاشتراك؟')) return;
  try { await fsUpdate('subscriptions', id, { status: 'cancelled' }); toast('تم إلغاء الاشتراك'); loadSubscriptions(); } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}
async function deleteSub(id) { if (!confirm('حذف؟')) return; await fsDelete('subscriptions', id); toast('تم الحذف'); loadSubscriptions(); }

function openAddSubscriptionModal() {
  document.getElementById('subEmail').value = '';
  document.getElementById('subFirebaseUid').value = '';
  document.getElementById('subPlan').value = 'monthly';
  document.getElementById('subDays').value = '30';
  document.getElementById('addSubModal').classList.remove('hidden');
}
async function saveSubscription() {
  const email = document.getElementById('subEmail').value.trim();
  const uid = document.getElementById('subFirebaseUid').value.trim();
  const plan = document.getElementById('subPlan').value;
  const days = parseInt(document.getElementById('subDays').value) || 30;
  if (!email && !uid) { toast('أدخل البريد الإلكتروني أو Firebase UID', 'error'); return; }
  const start = new Date(); const end = new Date(); end.setDate(end.getDate() + days);
  const payload = { plan, status: 'active', start_date: start.toISOString().split('T')[0], end_date: end.toISOString().split('T')[0] };
  if (email) payload.user_email = email;
  if (uid) payload.firebase_uid = uid;
  try {
    await fsCreate('subscriptions', payload);
    // Update is_subscribed on user
    if (uid) { try { await fsUpdate('users', uid, { is_subscribed: true }); } catch { } }
    else if (email) {
      const users = await fsList('users', { where: [['email', '==', email]] });
      if (users.length) await fsUpdate('users', users[0].id, { is_subscribed: true });
    }
    toast('✅ تم إضافة الاشتراك');
    closeModal('addSubModal');
    loadSubscriptions();
  } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}

// ── Settings ──────────────────────────────────────────────────────────────────
async function changePassword() {
  const p = document.getElementById('newPassword').value;
  const c = document.getElementById('confirmPassword').value;
  if (p.length < 8) { toast('كلمة المرور يجب أن تكون 8 أحرف على الأقل', 'error'); return; }
  if (p !== c) { toast('كلمتا المرور غير متطابقتين', 'error'); return; }
  try {
    await auth.currentUser.updatePassword(p);
    toast('✅ تم تغيير كلمة المرور بنجاح');
    document.getElementById('newPassword').value = '';
    document.getElementById('confirmPassword').value = '';
  } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}

// ── Gemini AI Settings ────────────────────────────────────────────────────────
async function loadSettings() {
  try {
    const doc = await db.collection('config').doc('ai').get();
    if (doc.exists) {
      const data = doc.data() || {};
      if (data.gemini_api_key) {
        document.getElementById('geminiApiKeyInput').value = data.gemini_api_key;
      }
      if (data.model) {
        document.getElementById('geminiModelSelect').value = data.model;
      }
    }
  } catch (e) {
    console.error('Error loading AI config:', e);
  }
}

async function saveGeminiSettings() {
  const key = document.getElementById('geminiApiKeyInput').value.trim();
  const model = document.getElementById('geminiModelSelect').value;
  if (!key) {
    toast('يرجى إدخال مفتاح API', 'error');
    return;
  }
  try {
    await db.collection('config').doc('ai').set({
      gemini_api_key: key,
      model: model,
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    toast('✅ تم حفظ إعدادات الذكاء الاصطناعي بنجاح');
  } catch (e) {
    toast('خطأ في حفظ الإعدادات: ' + e.message, 'error');
  }
}

async function testGeminiConnection() {
  const key = document.getElementById('geminiApiKeyInput').value.trim();
  const model = document.getElementById('geminiModelSelect').value;
  const statusEl = document.getElementById('geminiStatusMsg');
  if (!key) {
    toast('يرجى إدخال مفتاح API أولاً', 'error');
    return;
  }
  statusEl.innerHTML = '<span style="color:var(--text-muted)">⏳ جارٍ فحص الاتصال بـ Google Gemini...</span>';
  try {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: 'أجب بكلمة واحدة فقط: جاهز' }] }]
      })
    });
    const data = await res.json();
    if (res.ok) {
      const reply = data.candidates?.[0]?.content?.parts?.[0]?.text || 'تم الاتصال';
      statusEl.innerHTML = `<span style="color:#10b981;font-weight:bold">✅ الاتصال ناجح ومفتاح API يعمل بدقة! (رد النموذج: ${reply.trim()})</span>`;
    } else {
      statusEl.innerHTML = `<span style="color:#ef4444;font-weight:bold">❌ فشل الاتصال (${res.status}): ${data.error?.message || 'خطأ غير معروف'}</span>`;
    }
  } catch (e) {
    statusEl.innerHTML = `<span style="color:#ef4444;font-weight:bold">❌ تعذر الاتصال: ${e.message}</span>`;
  }
}

function toggleApiKeyVisibility() {
  const input = document.getElementById('geminiApiKeyInput');
  const btn = document.getElementById('btnToggleApiKey');
  if (input.type === 'password') {
    input.type = 'text';
    btn.textContent = '🙈';
  } else {
    input.type = 'password';
    btn.textContent = '👁️';
  }
}

