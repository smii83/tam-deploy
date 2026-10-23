// ─────────────────────────────────────────────────────────────────────────────
// TAM Summary Studio — Logic & AI Processor
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

let selectedPdfFile = null;
let selectedPdfBase64 = null;
let currentSummaryData = null;
let generatedPdfBlob = null;

// Admin whitelist
const ADMIN_EMAILS = [
  'admin@tam.com',
  'tamteach01@gmail.com',
  'tam.app83@gmail.com',
  'tm.app83@gmail.com',
  'admin@eduspark.com'
];

// Master studio credentials
const MASTER_USER = 'admin@tam.com';
const MASTER_PASS = 'Tam@2026';

// Initialize on Load
document.addEventListener('DOMContentLoaded', async () => {
  setupDropzone();
  setupAuthListeners();
  checkAuthSession();
});

// ─────────────────────────────────────────────────────────────────────────────
// 0. AUTHENTICATION & LOGIN
// ─────────────────────────────────────────────────────────────────────────────

function setupAuthListeners() {
  const pwdInput = document.getElementById('authPassword');
  const emailInput = document.getElementById('authEmail');
  if (pwdInput) {
    pwdInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') handleStudioLogin();
    });
  }
  if (emailInput) {
    emailInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') handleStudioLogin();
    });
  }
}

function checkAuthSession() {
  const localSession = sessionStorage.getItem('tam_studio_admin');
  if (localSession) {
    grantAccess(localSession);
    return;
  }

  auth.onAuthStateChanged((user) => {
    if (user && isAuthorizedAdmin(user.email)) {
      grantAccess(user.email);
    } else {
      showLoginScreen();
    }
  });
}

function isAuthorizedAdmin(email) {
  if (!email) return false;
  const e = email.toLowerCase().trim();
  return ADMIN_EMAILS.some(a => a.toLowerCase().trim() === e);
}

function showLoginScreen() {
  document.getElementById('loginOverlay').classList.remove('hidden');
  document.getElementById('userSessionBadge').classList.add('hidden');
}

function grantAccess(username) {
  sessionStorage.setItem('tam_studio_admin', username);
  document.getElementById('loginOverlay').classList.add('hidden');
  document.getElementById('sessionUserName').textContent = username.split('@')[0];
  document.getElementById('userSessionBadge').classList.remove('hidden');
  loadGrades();
}

async function handleStudioLogin() {
  const email = document.getElementById('authEmail').value.trim();
  const pass = document.getElementById('authPassword').value;
  const errEl = document.getElementById('loginErrorMsg');
  const btn = document.getElementById('btnLogin');
  const btnText = document.getElementById('btnLoginText');

  errEl.classList.add('hidden');

  if (!email || !pass) {
    errEl.textContent = 'يرجى إدخال اسم المستخدم وكلمة المرور';
    errEl.classList.remove('hidden');
    return;
  }

  btn.disabled = true;
  btnText.textContent = 'جاري التحقق...';

  // 1. Check Master Studio Credentials
  if (
    (email.toLowerCase() === MASTER_USER.toLowerCase() || email.toLowerCase() === 'tam_admin') &&
    pass === MASTER_PASS
  ) {
    btn.disabled = false;
    btnText.textContent = 'تسجيل الدخول';
    grantAccess(email);
    toast('✅ تم تسجيل الدخول بنجاح كـ مشرف', 'success');
    return;
  }

  // 2. Check Firebase Authentication
  try {
    const cred = await auth.signInWithEmailAndPassword(email, pass);
    if (!isAuthorizedAdmin(email)) {
      await auth.signOut();
      throw new Error('هذا الحساب ليس مشرفاً معتمداً في منصة تَم');
    }
    grantAccess(email);
    toast('✅ تم تسجيل الدخول بنجاح', 'success');
  } catch (err) {
    let msg = 'اسم المستخدم أو كلمة المرور غير صحيحة';
    if (err.code === 'auth/user-not-found') msg = 'البريد الإلكتروني غير مسجل';
    if (err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') msg = 'كلمة المرور غير صحيحة';
    if (err.message && err.message.includes('مشرفاً')) msg = err.message;

    errEl.textContent = msg;
    errEl.classList.remove('hidden');
  } finally {
    btn.disabled = false;
    btnText.textContent = 'تسجيل الدخول';
  }
}

function handleStudioLogout() {
  sessionStorage.removeItem('tam_studio_admin');
  auth.signOut().catch(() => {});
  showLoginScreen();
  toast('تم تسجيل الخروج بنجاح', 'info');
}

// Toast Notifications
function toast(msg, type = 'info') {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.className = `toast show ${type}`;
  setTimeout(() => {
    t.className = 'toast';
  }, 4000);
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. DATA LOADERS (Grades & Subjects from Firestore)
// ─────────────────────────────────────────────────────────────────────────────

async function loadGrades() {
  const gradeSel = document.getElementById('gradeSelect');
  try {
    const snap = await db.collection('grades').orderBy('grade_number').get();
    let options = '<option value="">— اختر الصف الدراسي —</option>';
    
    // Sort or map grades
    snap.docs.forEach(doc => {
      const g = doc.data();
      const name = g.name_ar || `الصف ${g.grade_number}`;
      options += `<option value="${doc.id}" data-number="${g.grade_number}">${name}</option>`;
    });

    gradeSel.innerHTML = options;
  } catch (err) {
    console.error('Error loading grades:', err);
    // Fallback static Kuwait grades if Firestore index/network issues
    gradeSel.innerHTML = `
      <option value="">— اختر الصف الدراسي —</option>
      <option value="grade10">الصف العاشر</option>
      <option value="grade11_sci">الصف الحادي عشر — علمي</option>
      <option value="grade11_lit">الصف الحادي عشر — أدبي</option>
      <option value="grade12_sci">الصف الثاني عشر — علمي</option>
      <option value="grade12_lit">الصف الثاني عشر — أدبي</option>
    `;
  }
}

async function onGradeSelected() {
  const gradeId = document.getElementById('gradeSelect').value;
  const subSel = document.getElementById('subjectSelect');
  
  if (!gradeId) {
    subSel.innerHTML = '<option value="">— اختر الصف أولاً —</option>';
    checkCanProcess();
    return;
  }

  subSel.innerHTML = '<option value="">— جاري تحميل المواد... —</option>';
  try {
    const snap = await db.collection('subjects').where('grade_id', '==', gradeId).get();
    let options = '<option value="">— اختر المادة الدراسية —</option>';
    
    if (snap.empty) {
      // Try fallback by grade_number
      const gradeDoc = await db.collection('grades').doc(gradeId).get();
      const gNum = gradeDoc.exists ? gradeDoc.data().grade_number : null;
      if (gNum) {
        const snap2 = await db.collection('subjects').where('grade', '==', gNum).get();
        snap2.docs.forEach(d => {
          const s = d.data();
          options += `<option value="${d.id}">${s.name_ar || s.name || 'مادة'}</option>`;
        });
      }
    } else {
      snap.docs.forEach(d => {
        const s = d.data();
        options += `<option value="${d.id}">${s.name_ar || s.name || 'مادة'}</option>`;
      });
    }

    if (options === '<option value="">— اختر المادة الدراسية —</option>') {
      // General subjects fallback
      options += `
        <option value="physics">الفيزياء</option>
        <option value="chemistry">الكيمياء</option>
        <option value="biology">الأحياء</option>
        <option value="math">الرياضيات</option>
        <option value="arabic">اللغة العربية</option>
        <option value="english">اللغة الإنجليزية</option>
        <option value="islamic">التربية الإسلامية</option>
      `;
    }

    subSel.innerHTML = options;
  } catch (err) {
    console.error('Error loading subjects:', err);
    subSel.innerHTML = `
      <option value="">— اختر المادة —</option>
      <option value="physics">الفيزياء</option>
      <option value="chemistry">الكيمياء</option>
      <option value="biology">الأحياء</option>
      <option value="math">الرياضيات</option>
    `;
  }
  checkCanProcess();
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. DRAG & DROP FILE HANDLING
// ─────────────────────────────────────────────────────────────────────────────

function setupDropzone() {
  const dropzone = document.getElementById('dropzone');

  ['dragenter', 'dragover'].forEach(eventName => {
    dropzone.addEventListener(eventName, (e) => {
      e.preventDefault();
      e.stopPropagation();
      dropzone.classList.add('dragover');
    }, false);
  });

  ['dragleave', 'drop'].forEach(eventName => {
    dropzone.addEventListener(eventName, (e) => {
      e.preventDefault();
      e.stopPropagation();
      dropzone.classList.remove('dragover');
    }, false);
  });

  dropzone.addEventListener('drop', (e) => {
    const dt = e.dataTransfer;
    const file = dt.files[0];
    if (file && file.type === 'application/pdf') {
      handleFileSelected(file);
    } else {
      toast('يرجى اختيار ملف بصيغة PDF فقط', 'error');
    }
  }, false);

  document.getElementById('subjectSelect').addEventListener('change', checkCanProcess);
  document.getElementById('lessonTitle').addEventListener('input', checkCanProcess);
}

function handleFileSelected(file) {
  if (!file) return;
  if (file.type !== 'application/pdf' && !file.name.endsWith('.pdf')) {
    toast('الملف المختار ليس PDF صالحاً', 'error');
    return;
  }

  selectedPdfFile = file;
  document.getElementById('selectedFileName').textContent = file.name;
  document.getElementById('selectedFileSize').textContent = `(${(file.size / (1024 * 1024)).toFixed(2)} MB)`;
  document.getElementById('fileBadge').classList.remove('hidden');

  // Read as Base64 for Gemini
  const reader = new FileReader();
  reader.onload = (e) => {
    selectedPdfBase64 = e.target.result.split(',')[1];
    checkCanProcess();
  };
  reader.readAsDataURL(file);

  toast('تم تحميل الملف، جاهز للمعالجة', 'success');
}

function removeSelectedFile() {
  selectedPdfFile = null;
  selectedPdfBase64 = null;
  document.getElementById('fileBadge').classList.add('hidden');
  document.getElementById('pdfFileInput').value = '';
  checkCanProcess();
}

function checkCanProcess() {
  const grade = document.getElementById('gradeSelect').value;
  const sub = document.getElementById('subjectSelect').value;
  const hasFile = !!selectedPdfBase64;
  const btn = document.getElementById('btnStartProcess');
  btn.disabled = !(grade && sub && hasFile);
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. AI SANITIZATION & RE-AUTHORING ENGINE (Gemini 2.5 Flash)
// ─────────────────────────────────────────────────────────────────────────────

async function getGeminiKey() {
  try {
    const d = await db.collection('config').doc('ai').get();
    if (d.exists && d.data().gemini_api_key) return d.data().gemini_api_key;
  } catch (_) {}
  return atob('QVEuQWI4Uk42Sjc4NWRnYjVKZHFhQ1Y1bjZvSl9RVGxrbFg4UG9LUTd5OHYtQ2xDRGh5LXc=');
}

async function startAIProcessing() {
  const gradeSel = document.getElementById('gradeSelect');
  const subSel = document.getElementById('subjectSelect');
  const gradeName = gradeSel.options[gradeSel.selectedIndex].text;
  const subjectName = subSel.options[subSel.selectedIndex].text;
  let customTitle = document.getElementById('lessonTitle').value.trim();

  // Switch to Step 2
  setStepper(2);
  document.getElementById('stepCard1').classList.add('hidden');
  document.getElementById('stepCard2').classList.remove('hidden');
  document.getElementById('stepCard3').classList.add('hidden');

  updateProgress(25, 'chk1', 'جاري تحليل المستند واستخراج النصوص والقوانين...');

  try {
    const geminiKey = await getGeminiKey();

    const prompt = `أنت رئيس تحرير المناهج والمحتوى التعليمي في "منصة تَم التعليمية" (TAM Platform).
أمامك ملف PDF يحتوي مذكرة أو ملخص دراسي لمادة "${subjectName}" للصف "${gradeName}".
${customTitle ? `العنوان المطلوب للدرس هو: "${customTitle}".` : 'استخرج عنوان الدرس الدقيق من المحتوى.'}

المطلوب بدقة متناهية:
1. التطهير والفلترة الكاملة (Strict Sanitization):
   - احذف تماماً ودون أي استثناء: أي ذكر لـ "وزارة التربية"، "وزارة التعليم"، "التوجيه الفني"، "منطقة ... التعليمية"، "مدرسة ..."، أسماء المعلمين والمعلمات، أرقام الهواتف أو الواتساب، قنوات التيليجرام أو الإنستغرام أو روابط المواقع، وأي علامات مائية أو حقوق ملكية خارجية.
   - الملخص الناتج بالكامل يجب أن يكون حصرياً ورسمياً لـ "منصة تَم التعليمية" فقط.

2. إعادة الهيكلة التعليمية الفخمة (TAM Pedagogical Re-Authoring):
   - صغ المحتوى بأسلوب راقٍ وشرح مبسط ودقيق.
   - قسّم الدرس إلى أقسام واضحة ومتسلسلة:
     * مفهوم أساسي وتعريفات (concept)
     * قوانين ومعادلات رياضية/علمية بيونيكود واضح (formula)
     * أمثلة تطبيقية محلولة خطوة بخطوة مع توضيح الفكرة (example)
     * نصائح ذهبية وأخطاء شائعة في الاختبارات (tip)
     * اختبر فهمك: سؤال تدريبي سريع (quiz)

3. إعداد شرائح السبورة التفاعلية (Whiteboard Slides):
   - قسّم الشرح إلى (6 إلى 10) شرائح مركزة ومتقنة.
   - heading: عنوان الشريحة (ضع الكلمات المفتاحية بين [[ ]]).
   - content: نص مركز معادل للسبورة (حتى 200 حرف).
   - narration: شرح صوتي طبيعي ومحفز للمعلم بلهجة كويتية بيضاء دافئة وودودة بدون أي حشو.

أعد المخرجات في صيغة JSON صالح حصراً فقط بدون أي علامات markdown إضافية:
{
  "lesson_title": "عنوان الدرس",
  "subject_name": "${subjectName}",
  "grade_name": "${gradeName}",
  "overview": "مقدمة سريعة وشيقة عن فكرة الدرس في سطرين",
  "sections": [
    {
      "type": "concept",
      "badge": "مفهوم أساسي",
      "title": "عنوان القسم",
      "content": "شرح المفهوم بأسلوب تَم الرائع...",
      "bullets": ["نقطة 1", "نقطة 2"]
    },
    {
      "type": "formula",
      "badge": "قانون ذهبي",
      "title": "اسم القانون",
      "content": "توضيح الرموز ووحدات القياس...",
      "formula": "F = m × a"
    },
    {
      "type": "example",
      "badge": "مثال تطبيقي محلول",
      "title": "مسألة على القانون",
      "problem": "نص المسألة...",
      "solution": "خطوات الحل التفصيلية خطوة بخطوة..."
    },
    {
      "type": "tip",
      "badge": "نصيحة ذهبية للاختبار",
      "title": "انتبه لهذا الخطأ الشائع",
      "content": "تنبيه مهم يقع فيه معظم الطلاب..."
    },
    {
      "type": "quiz",
      "badge": "اختبر فهمك",
      "title": "سؤال سريع",
      "question": "نص السؤال...",
      "answer": "الإجابة النموذجية..."
    }
  ],
  "whiteboard_slides": [
    {
      "heading": "...",
      "content": "...",
      "narration": "..."
    }
  ]
}`;

    updateProgress(50, 'chk2', 'جاري تطهير المحتوى وحذف كافة الإشارات الخارجية...');

    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            { inline_data: { mime_type: 'application/pdf', data: selectedPdfBase64 } }
          ]
        }],
        generationConfig: {
          responseMimeType: 'application/json',
          temperature: 0.25
        }
      })
    });

    updateProgress(75, 'chk3', 'جاري إعادة صياغة الملخص بهيكل منصة تَم التعليمية...');

    if (!res.ok) {
      const errJson = await res.json().catch(() => ({}));
      throw new Error(errJson.error?.message || `HTTP ${res.status}`);
    }

    const data = await res.json();
    const rawJson = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!rawJson) throw new Error('لم يرجع نموذج الذكاء الاصطناعي رداً');

    currentSummaryData = JSON.parse(rawJson);

    updateProgress(100, 'chk4', 'اكتمل بناء مستند تَم وشرائح السبورة التفاعلية!');
    await sleep(600);

    // Render Preview & Switch to Step 3
    renderResults(currentSummaryData);
    setStepper(3);
    document.getElementById('stepCard2').classList.add('hidden');
    document.getElementById('stepCard3').classList.remove('hidden');

    toast('🎉 تم تحويل الملخص بنجاح وإعداده لمنصة تَم!', 'success');

  } catch (err) {
    console.error('Processing error:', err);
    toast(`خطأ أثناء المعالجة: ${err.message}`, 'error');
    setStepper(1);
    document.getElementById('stepCard2').classList.add('hidden');
    document.getElementById('stepCard1').classList.remove('hidden');
  }
}

function updateProgress(percent, checkId, title) {
  document.getElementById('progressBarFill').style.width = `${percent}%`;
  document.getElementById('processStatusTitle').textContent = title;
  if (checkId) {
    const el = document.getElementById(checkId);
    el.classList.add('done');
    el.querySelector('.icon').textContent = '✅';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. RENDERING & TAM BRANDED PDF PREVIEW
// ─────────────────────────────────────────────────────────────────────────────

function renderResults(data) {
  document.getElementById('resultLessonTitle').textContent = data.lesson_title;
  document.getElementById('resultMeta').textContent = `${data.grade_name} • ${data.subject_name}`;

  // 1. Build the A4 PDF HTML
  const stage = document.getElementById('pdfRenderStage');
  
  // Page 1: TAM Official Royal Cover
  let html = `
    <div class="a4-page tam-cover-page" id="pdfPage1">
      <div>
        <div class="cover-top-badge">منصة تَم التعليمية — TAM PLATFORM</div>
        <h1 class="cover-main-title">${escapeHtml(data.lesson_title)}</h1>
        <p class="cover-sub-title">ملخص دراسي شامل ومركز مهيأ للاختبارات والسبورة التفاعلية</p>
      </div>

      <div class="cover-meta-box">
        <div class="meta-item">
          <span class="lbl">المادة الدراسية:</span>
          <span class="val">${escapeHtml(data.subject_name)}</span>
        </div>
        <div class="meta-item">
          <span class="lbl">الصف الدراسي:</span>
          <span class="val">${escapeHtml(data.grade_name)}</span>
        </div>
        <div class="meta-item">
          <span class="lbl">إعداد وتطوير:</span>
          <span class="val">منصة تَم التعليمية</span>
        </div>
        <div class="meta-item">
          <span class="lbl">طبيعة المحتوى:</span>
          <span class="val">ملخص معتمد + شرح تفاعلي ذكي</span>
        </div>
      </div>

      <div class="cover-footer">
        <p>© ${new Date().getFullYear()} جميع الحقوق محفوظة ومسجلة لمنصة تَم التعليمية</p>
      </div>
    </div>
  `;

  // Page 2+: Inner Content
  html += `
    <div class="a4-page" id="pdfPage2">
      <div>
        <div class="doc-header">
          <span class="doc-brand">منصة تَم التعليمية</span>
          <span class="doc-lesson-title">${escapeHtml(data.subject_name)} — ${escapeHtml(data.lesson_title)}</span>
        </div>

        ${data.overview ? `<div class="doc-section-card tip" style="margin-bottom:24px;"><strong>فكرة الدرس:</strong> ${escapeHtml(data.overview)}</div>` : ''}

        ${data.sections.map(s => {
          let extra = '';
          if (s.formula) {
            extra += `<div class="formula-box">${escapeHtml(s.formula)}</div>`;
          }
          if (s.problem && s.solution) {
            extra += `
              <div style="margin-top:10px; background:#fff; padding:12px; border-radius:8px; border:1px solid #dcfce7;">
                <p><strong>المسألة:</strong> ${escapeHtml(s.problem)}</p>
                <p style="margin-top:6px; color:#166534;"><strong>الحل:</strong> ${escapeHtml(s.solution)}</p>
              </div>`;
          }
          if (s.question && s.answer) {
            extra += `
              <div style="margin-top:10px; background:#fff; padding:12px; border-radius:8px; border:1px solid #f3e8ff;">
                <p><strong>السؤال:</strong> ${escapeHtml(s.question)}</p>
                <p style="margin-top:6px; color:#6b21a8;"><strong>الإجابة:</strong> ${escapeHtml(s.answer)}</p>
              </div>`;
          }
          if (s.bullets && s.bullets.length) {
            extra += `<ul class="doc-bullets">${s.bullets.map(b => `<li>${escapeHtml(b)}</li>`).join('')}</ul>`;
          }

          return `
            <div class="doc-section-card ${s.type || 'concept'}">
              <span class="doc-card-badge">${escapeHtml(s.badge || 'تَم')}</span>
              <h3 class="doc-card-title">${escapeHtml(s.title || '')}</h3>
              <p class="doc-card-content">${escapeHtml(s.content || '')}</p>
              ${extra}
            </div>
          `;
        }).join('')}
      </div>

      <div class="doc-footer">
        <span>منصة تَم التعليمية — تطبيق الطالب الذكي</span>
        <span>صفحة 2</span>
      </div>
    </div>
  `;

  stage.innerHTML = html;

  // 2. Build Whiteboard Slides Preview
  const slidesGrid = document.getElementById('slidesGrid');
  if (data.whiteboard_slides && data.whiteboard_slides.length) {
    slidesGrid.innerHTML = data.whiteboard_slides.map((slide, idx) => `
      <div class="slide-card-preview">
        <div>
          <span class="slide-num">الشريحة ${idx + 1}</span>
          <h4 class="slide-heading">${escapeHtml(slide.heading || '')}</h4>
          <p class="slide-text">${escapeHtml(slide.content || '')}</p>
        </div>
        <div class="slide-narration-box">
          <strong>🎙️ صوت الشرح (لهجة كويتية):</strong>
          <p style="margin-top:4px;">"${escapeHtml(slide.narration || '')}"</p>
        </div>
      </div>
    `).join('');
  } else {
    slidesGrid.innerHTML = '<p style="color:#94a3b8; text-align:center;">لم يتم توليد شرائح</p>';
  }
}

function switchResultTab(tabId) {
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));

  if (tabId === 'pdfView') {
    event.target.classList.add('active');
    document.getElementById('pdfViewContent').classList.add('active');
  } else {
    event.target.classList.add('active');
    document.getElementById('whiteboardViewContent').classList.add('active');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. DOWNLOAD BRANDED TAM PDF
// ─────────────────────────────────────────────────────────────────────────────

async function downloadTamPdf() {
  if (!currentSummaryData) return;
  toast('جاري تجهيز وتنزيل ملف PDF عالي الجودة...', 'info');

  const element = document.getElementById('pdfRenderStage');
  const filename = `ملخص_تم_${currentSummaryData.subject_name}_${currentSummaryData.lesson_title}.pdf`
    .replace(/[\\/:*?"<>| ]/g, '_');

  const opt = {
    margin: 0,
    filename: filename,
    image: { type: 'jpeg', quality: 0.98 },
    html2canvas: { scale: 2, useCORS: true, letterRendering: true },
    jsPDF: { unit: 'pt', format: 'a4', orientation: 'portrait' }
  };

  try {
    await html2pdf().set(opt).from(element).save();
    toast('✅ تم تنزيل الملف بنجاح!', 'success');
  } catch (err) {
    console.error('PDF Download error:', err);
    toast('حدث خطأ أثناء تنزيل الـ PDF: ' + err.message, 'error');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. DIRECT PUBLISH TO TAM & AUTO WHITEBOARD GENERATION
// ─────────────────────────────────────────────────────────────────────────────

async function publishToTamAndGenerateLesson() {
  if (!currentSummaryData) return;

  const btn = document.getElementById('btnPublishDirect');
  btn.disabled = true;
  btn.innerHTML = '<span>جاري النشر وتوليد السبورة... ⏳</span>';

  const gradeId = document.getElementById('gradeSelect').value;
  const subjectId = document.getElementById('subjectSelect').value;
  const title = currentSummaryData.lesson_title;
  const subjectName = currentSummaryData.subject_name;

  try {
    toast('1/3: جاري تصدير مستند PDF الخاص بـ تَم...', 'info');
    
    // Generate PDF Blob
    const element = document.getElementById('pdfRenderStage');
    const pdfBlob = await html2pdf().set({
      margin: 0,
      image: { type: 'jpeg', quality: 0.95 },
      html2canvas: { scale: 1.5, useCORS: true },
      jsPDF: { unit: 'pt', format: 'a4', orientation: 'portrait' }
    }).from(element).output('blob');

    toast('2/3: جاري حفظ الملف في قاعدة بيانات تَم...', 'info');

    // Upload to Firebase Storage
    const storageRef = storage.ref(`pdfs/${subjectId}/${Date.now()}_${encodeURIComponent(title)}.pdf`);
    const snap = await storageRef.put(pdfBlob, { contentType: 'application/pdf' });
    const downloadUrl = await snap.ref.getDownloadURL();

    // 1. Create PDF record in Firestore
    const pdfDocRef = await db.collection('pdfs').add({
      grade_id: gradeId,
      subject_id: subjectId,
      title_ar: title,
      name: title,
      pdf_type: 'summary',
      is_active: true,
      file_url: downloadUrl,
      created_at: firebase.firestore.FieldValue.serverTimestamp()
    });

    const pdfId = pdfDocRef.id;

    toast('3/3: جاري ربط السبورة التفاعلية للشرح الصوتي...', 'info');

    // 2. Prepare Interactive Lesson slides
    const slides = currentSummaryData.whiteboard_slides || [];
    const lessonData = {
      title: title,
      subject: subjectName,
      versions: {
        kamila: {
          hook: {
            available: true,
            text: `مستعد تفهم درس ${title} بكل سهولة؟ خلنا نبدأ!`,
            narration: `مرحباً بكم يا أبطال في منصة تَم التعليمية، اليوم بنشرح درس ${title} بأسلوب سهل وبسيط.`
          },
          sections: slides.map(s => ({
            type: 'section',
            heading: s.heading,
            content: s.content,
            narration: s.narration
          })),
          zubda: {
            text: `خلاصة درس ${title}: ركز على القوانين والمفاهيم الرئيسية التي شرحناها.`,
            narration: 'وهذي كانت زبدة درسنا، ركز بالمسائل والله يوفقك في اختباراتك!'
          }
        }
      },
      common: {
        welcome: { narration: 'مرحباً بكم في منصة تَم التعليمية' },
        intro: { narration: `درسنا اليوم: ${title}` }
      }
    };

    // Save interactive content
    await db.collection('interactive_content').doc(pdfId).set(lessonData);

    // Save interactive lesson meta
    await db.collection('interactive_lessons').doc(pdfId).set({
      pdf_id: pdfId,
      subject_id: subjectId,
      title_ar: title,
      status: 'ready',
      error: null,
      country: 'kw',
      slides_kamila: slides.length,
      audio_done: 0,
      audio_total: slides.length,
      audio_complete: false,
      updated: firebase.firestore.FieldValue.serverTimestamp()
    });

    btn.innerHTML = '<span>✅ تم النشر بنجاح للطلاب والسبورة!</span>';
    btn.style.background = '#059669';

    toast('🎉 تم النشر مباشرة لمنصة تَم! الدرس والسبورة التفاعلية متاحان للطلاب الآن.', 'success');

  } catch (err) {
    console.error('Publish error:', err);
    toast('حدث خطأ أثناء النشر: ' + err.message, 'error');
    btn.disabled = false;
    btn.innerHTML = '<span>إعادة محاولة النشر 🚀</span>';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. UTILITIES & HELPERS
// ─────────────────────────────────────────────────────────────────────────────

function setStepper(step) {
  for (let i = 1; i <= 3; i++) {
    const node = document.getElementById(`stepNode${i}`);
    if (i <= step) node.classList.add('active');
    else node.classList.remove('active');
  }
  const c1 = document.getElementById('conn1');
  const c2 = document.getElementById('conn2');
  if (step >= 2) c1.classList.add('active'); else c1.classList.remove('active');
  if (step >= 3) c2.classList.add('active'); else c2.classList.remove('active');
}

function resetStudio() {
  currentSummaryData = null;
  selectedPdfFile = null;
  selectedPdfBase64 = null;
  document.getElementById('pdfFileInput').value = '';
  document.getElementById('fileBadge').classList.add('hidden');
  document.getElementById('lessonTitle').value = '';
  document.getElementById('stepCard3').classList.add('hidden');
  document.getElementById('stepCard1').classList.remove('hidden');
  setStepper(1);
  checkCanProcess();
}

function escapeHtml(text) {
  if (!text) return '';
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms));
