// ─────────────────────────────────────────────────────────────────────────────
// TAM Admin Dashboard — Firebase Firestore Edition
// ─────────────────────────────────────────────────────────────────────────────
const firebaseConfig = {
  apiKey: 'AIzaSyDdQJvBWxCX4XmdZbH7sKPOhR68Uae7bB8',
  authDomain: 'tam-app-fd30f.firebaseapp.com',
  projectId: 'tam-app-fd30f',
  storageBucket: 'tam-app-fd30f.firebasestorage.app',
  messagingSenderId: '82581349835',
  appId: '1:82581349835:web:tam_web_app'
};
firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();
const auth = firebase.auth();
const storage = firebase.storage();

// Admin email whitelist — only these emails can log in
const ADMIN_EMAILS = ['admin@tam.com', 'tamteach01@gmail.com', 'tam.app83@gmail.com'];

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
    if (!ADMIN_EMAILS.includes(email.toLowerCase())) {
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
function doLogout() { auth.signOut(); location.reload(); }

// Auto-login check
auth.onAuthStateChanged(user => {
  if (user && ADMIN_EMAILS.includes(user.email.toLowerCase())) {
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
  if (id === 'grades') loadGrades(); if (id === 'subjects') loadSubjects();
  if (id === 'students') loadStudents(); if (id === 'subscriptions') loadSubscriptions(); if (id === 'overview') loadOverview();
}
function toggleSidebar() { document.getElementById('sidebar').classList.toggle('collapsed'); }
function toast(msg, type = 'success') { const t = document.getElementById('toast'); t.textContent = msg; t.className = 'toast ' + type; setTimeout(() => t.classList.add('hidden'), 2500); }
function closeModal(id) { document.getElementById(id).classList.add('hidden'); }
async function initDashboard() { await loadOverview(); await populateGradeFilters(); await loadGrades(); }

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
  ['subjectGradeFilter', 'lessonGradeFilter', 'pdfGradeFilter', 'subjectGradeId'].forEach(selId => {
    const sel = document.getElementById(selId); if (!sel) return;
    const first = sel.options[0]; sel.innerHTML = ''; sel.appendChild(first);
    grades.forEach(g => { const o = document.createElement('option'); o.value = g.id; o.textContent = `الصف ${g.grade_number} — ${g.name_ar}`; sel.appendChild(o); });
  });
}

// ── Subjects ──────────────────────────────────────────────────────────────────
async function loadSubjects() {
  const gid = document.getElementById('subjectGradeFilter').value;
  if (!gid) { document.getElementById('subjectsList').innerHTML = '<p class="empty-msg">اختر صفاً</p>'; return; }
  try {
    const subs = await fsList('subjects', { where: [['grade_id', '==', gid]], orderBy: 'sort_order' });
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
  try { const subs = await fsList('subjects', { where: [['grade_id', '==', gid]], orderBy: 'sort_order' }); subs.forEach(s => { const o = document.createElement('option'); o.value = s.id; o.textContent = s.name_ar; sel.appendChild(o); }); } catch { }
}
async function loadLessons() {
  const sid = document.getElementById('lessonSubjectFilter').value;
  if (!sid) { document.getElementById('lessonsList').innerHTML = '<p class="empty-msg">اختر مادة</p>'; return; }
  try {
    const items = await fsList('lessons', { where: [['subject_id', '==', sid]], orderBy: 'sort_order' });
    if (!items.length) { document.getElementById('lessonsList').innerHTML = '<p class="empty-msg">لا توجد دروس</p>'; return; }
    let h = '<table><thead><tr><th>#</th><th>العنوان</th><th>المدة</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>';
    items.forEach(l => { h += `<tr><td>${l.sort_order || 0}</td><td>${l.title_ar || l.name || ''}</td><td>${l.duration_min || 0} د</td><td><label class="toggle-switch"><input type="checkbox" ${l.is_active ? 'checked' : ''} onchange="toggleLesson('${l.id}',this.checked)"/><div class="toggle-track"></div></label></td><td class="actions-cell"><button class="btn-icon" onclick="editLesson('${l.id}')">✏️</button><button class="btn-icon btn-danger" onclick="deleteLesson('${l.id}')">🗑️</button></td></tr>`; });
    document.getElementById('lessonsList').innerHTML = h + '</tbody></table>';
  } catch (e) { document.getElementById('lessonsList').innerHTML = '<p class="empty-msg">خطأ: ' + e.message + '</p>'; }
}
async function toggleLesson(id, v) { try { await fsUpdate('lessons', id, { is_active: v }); toast(v ? 'مفعّل' : 'معطّل'); loadLessons(); } catch (e) { toast('خطأ: ' + e.message, 'error'); } }
function openAddLessonModal() {
  const sid = document.getElementById('lessonSubjectFilter').value; if (!sid) { toast('اختر مادة أولاً', 'error'); return; }
  document.getElementById('lessonId').value = ''; document.getElementById('lessonModalTitle').textContent = 'إضافة درس';
  document.getElementById('lessonTitleAr').value = ''; document.getElementById('lessonTitleEn').value = '';
  document.getElementById('lessonVideoUrl').value = ''; document.getElementById('lessonDuration').value = '30';
  document.getElementById('lessonOrder').value = '1'; document.getElementById('lessonActive').checked = true;
  document.getElementById('lessonModal').classList.remove('hidden');
}
async function editLesson(id) {
  const l = await fsGet('lessons', id);
  document.getElementById('lessonId').value = id; document.getElementById('lessonModalTitle').textContent = 'تعديل الدرس';
  document.getElementById('lessonTitleAr').value = l.title_ar || l.name || ''; document.getElementById('lessonTitleEn').value = l.title_en || '';
  document.getElementById('lessonVideoUrl').value = l.video_url || ''; document.getElementById('lessonDuration').value = l.duration_min || 30;
  document.getElementById('lessonOrder').value = l.sort_order || 1; document.getElementById('lessonActive').checked = l.is_active;
  document.getElementById('lessonModal').classList.remove('hidden');
}
async function saveLesson() {
  const id = document.getElementById('lessonId').value; const sid = document.getElementById('lessonSubjectFilter').value;
  const data = { subject_id: sid, title_ar: document.getElementById('lessonTitleAr').value, name: document.getElementById('lessonTitleAr').value, title_en: document.getElementById('lessonTitleEn').value, video_url: document.getElementById('lessonVideoUrl').value, duration_min: +document.getElementById('lessonDuration').value, sort_order: +document.getElementById('lessonOrder').value, is_active: document.getElementById('lessonActive').checked };
  try { if (id) await fsUpdate('lessons', id, data); else await fsCreate('lessons', data); toast(id ? 'تم التحديث' : 'تمت الإضافة'); closeModal('lessonModal'); loadLessons(); loadOverview(); } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}
async function deleteLesson(id) { if (!confirm('حذف؟')) return; await fsDelete('lessons', id); toast('تم الحذف'); loadLessons(); }

// ── PDFs ──────────────────────────────────────────────────────────────────────
async function loadPdfSubjects() {
  const gid = document.getElementById('pdfGradeFilter').value;
  const sel = document.getElementById('pdfSubjectFilter'); sel.innerHTML = '<option value="">— اختر المادة —</option>'; if (!gid) return;
  try { const subs = await fsList('subjects', { where: [['grade_id', '==', gid]], orderBy: 'sort_order' }); subs.forEach(s => { const o = document.createElement('option'); o.value = s.id; o.textContent = s.name_ar; sel.appendChild(o); }); } catch { }
}
async function loadPdfs() {
  const sid = document.getElementById('pdfSubjectFilter').value;
  if (!sid) { document.getElementById('pdfsList').innerHTML = '<p class="empty-msg">اختر مادة</p>'; return; }
  try {
    const items = await fsList('pdfs', { where: [['subject_id', '==', sid]] });
    if (!items.length) { document.getElementById('pdfsList').innerHTML = '<p class="empty-msg">لا توجد ملفات</p>'; return; }
    const types = { summary: 'ملخص', exam_answer: 'حل امتحان', worksheet: 'ورقة عمل' };
    let h = '<table><thead><tr><th>العنوان</th><th>النوع</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>';
    items.forEach(p => { h += `<tr><td>${p.title_ar || p.name || ''}</td><td><span class="badge badge-blue">${types[p.pdf_type] || p.pdf_type || '—'}</span></td><td><label class="toggle-switch"><input type="checkbox" ${p.is_active ? 'checked' : ''} onchange="togglePdf('${p.id}',this.checked)"/><div class="toggle-track"></div></label></td><td class="actions-cell"><button class="btn-icon btn-danger" onclick="deletePdf('${p.id}')">🗑️</button></td></tr>`; });
    document.getElementById('pdfsList').innerHTML = h + '</tbody></table>';
  } catch (e) { document.getElementById('pdfsList').innerHTML = '<p class="empty-msg">خطأ: ' + e.message + '</p>'; }
}
async function togglePdf(id, v) { try { await fsUpdate('pdfs', id, { is_active: v }); toast(v ? 'مرئي' : 'مخفي'); loadPdfs(); } catch (e) { toast('خطأ', 'error'); } }
function onFileSelected(input) { const name = input.files[0]?.name || ''; document.getElementById('fileSelectedName').textContent = name ? '✅ ' + name : ''; }
function openAddPdfModal() {
  const sid = document.getElementById('pdfSubjectFilter').value; if (!sid) { toast('اختر مادة أولاً', 'error'); return; }
  document.getElementById('pdfTitleAr').value = ''; document.getElementById('pdfTitleEn').value = '';
  document.getElementById('pdfType').value = 'summary'; document.getElementById('pdfActive').checked = true;
  document.getElementById('fileSelectedName').textContent = ''; document.getElementById('pdfModal').classList.remove('hidden');
}
async function savePdf() {
  const sid = document.getElementById('pdfSubjectFilter').value;
  const fi = document.getElementById('pdfFileInput');
  const titleAr = document.getElementById('pdfTitleAr').value;
  const titleEn = document.getElementById('pdfTitleEn').value;
  const pdfType = document.getElementById('pdfType').value;
  const isActive = document.getElementById('pdfActive').checked;

  try {
    let fileUrl = '';
    if (fi.files[0]) {
      // Upload to Firebase Storage
      const file = fi.files[0];
      const path = `pdfs/${Date.now()}_${file.name}`;
      const ref = storage.ref(path);
      await ref.put(file);
      fileUrl = await ref.getDownloadURL();
    }
    await fsCreate('pdfs', {
      subject_id: sid,
      title_ar: titleAr,
      name: titleAr,
      title_en: titleEn,
      pdf_type: pdfType,
      is_active: isActive,
      file_url: fileUrl,
    });
    toast('تم رفع الملف');
    closeModal('pdfModal');
    loadPdfs();
  } catch (e) { toast('خطأ: ' + e.message, 'error'); }
}
async function deletePdf(id) { if (!confirm('حذف؟')) return; await fsDelete('pdfs', id); toast('تم الحذف'); loadPdfs(); }

// ── Students ──────────────────────────────────────────────────────────────────
let allStudents = [];
async function loadStudents() {
  try {
    allStudents = await fsList('users', { orderBy: 'created', orderDir: 'desc' });
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
    const isSubscribed = s.is_subscribed === true;
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
    document.getElementById('studentPassword').value = '';
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
    document.getElementById('studentGrade').value = '12';
    document.getElementById('studentSection').value = 'scientific';
    document.getElementById('studentSubscribed').checked = false;
    document.getElementById('studentSubscribedContainer').classList.remove('hidden');
    document.getElementById('studentModalBtn').innerText = 'إضافة الطالب ✅';
  }
  document.getElementById('studentModal').classList.remove('hidden');
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
      const payload = { name, email, grade, section };
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
  document.getElementById('editSubStudentUid').value = firebaseUid;
  document.getElementById('editSubEmailDisplay').value = email;

  let currentSub = null;
  try {
    const subs = await fsList('subscriptions', { where: [['firebase_uid', '==', firebaseUid]] });
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
  const firebaseUid = document.getElementById('editSubStudentUid').value;
  const newEndDate = document.getElementById('editSubEndDate').value;
  if (!newEndDate) { toast('يرجى تحديد تاريخ الانتهاء', 'error'); return; }

  try {
    const subs = await fsList('subscriptions', { where: [['firebase_uid', '==', firebaseUid]] });
    const today = new Date().toISOString().split('T')[0];
    const isFuture = newEndDate >= today;

    if (subs.length) {
      const latest = subs.sort((a, b) => (b.created?.seconds || 0) - (a.created?.seconds || 0))[0];
      await fsUpdate('subscriptions', latest.id, { end_date: newEndDate, status: isFuture ? 'active' : 'expired' });
    } else {
      await fsCreate('subscriptions', {
        user_email: email, firebase_uid,
        plan: 'custom', status: isFuture ? 'active' : 'expired',
        start_date: today, end_date: newEndDate
      });
    }
    await fsUpdate('users', studentId, { is_subscribed: isFuture });
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
