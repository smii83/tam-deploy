let PB_URL = 'http://127.0.0.1:8090';
let PB_TOKEN = '';
const GRADES = [
  {num:6,ar:'السادس',en:'Grade 6'},{num:7,ar:'السابع',en:'Grade 7'},
  {num:8,ar:'الثامن',en:'Grade 8'},{num:9,ar:'التاسع',en:'Grade 9'},
  {num:10,ar:'العاشر',en:'Grade 10'},{num:11,ar:'الحادي عشر',en:'Grade 11'},
  {num:12,ar:'الثاني عشر',en:'Grade 12'}
];
async function pbFetch(path,opts={}){
  const r=await fetch(`${PB_URL}/api/${path}`,{...opts,headers:{'Content-Type':'application/json','Authorization':`Bearer ${PB_TOKEN}`,...(opts.headers||{})}});
  if(!r.ok){const e=await r.json().catch(()=>({}));throw new Error(e.message||r.status);}
  return r.json();
}
async function pbList(col,p={}){const q=new URLSearchParams({perPage:200,...p}).toString();const d=await pbFetch(`collections/${col}/records?${q}`);return d.items||[];}
async function pbGet(col,id){return pbFetch(`collections/${col}/records/${id}`);}
async function pbCreate(col,b){return pbFetch(`collections/${col}/records`,{method:'POST',body:JSON.stringify(b)});}
async function pbUpdate(col,id,b){return pbFetch(`collections/${col}/records/${id}`,{method:'PATCH',body:JSON.stringify(b)});}
async function pbDelete(col,id){const r=await fetch(`${PB_URL}/api/collections/${col}/records/${id}`,{method:'DELETE',headers:{'Authorization':`Bearer ${PB_TOKEN}`}});return r.ok;}
async function doLogin(){
  const url=document.getElementById('pbUrl').value.trim();
  const email=document.getElementById('loginEmail').value.trim();
  const pass=document.getElementById('loginPassword').value;
  const errEl=document.getElementById('loginError');
  const btn=document.getElementById('loginBtnText');
  errEl.classList.add('hidden');btn.textContent='جارٍ التحقق...';
  try{
    PB_URL=url.endsWith('/')?url.slice(0,-1):url;
    const resp=await fetch(`${PB_URL}/api/collections/_superusers/auth-with-password`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({identity:email,password:pass})});
    if(!resp.ok){const e=await resp.json().catch(()=>({}));throw new Error(e.message||`HTTP ${resp.status}`);}
    const data=await resp.json();
    PB_TOKEN=data.token;
    localStorage.setItem('pb_url',PB_URL);localStorage.setItem('pb_email',email);
    document.getElementById('loginScreen').classList.add('hidden');
    document.getElementById('dashboard').classList.remove('hidden');
    document.getElementById('currentPbUrl').value=PB_URL;
    document.getElementById('adminName').textContent=email.split('@')[0];
    await initDashboard();
  }catch(e){errEl.textContent='خطأ: '+(e.message||'بيانات غير صحيحة');errEl.classList.remove('hidden');btn.textContent='تسجيل الدخول';}
}
function doLogout(){PB_TOKEN='';localStorage.removeItem('pb_url');localStorage.removeItem('pb_email');location.reload();}
function checkAuth(){const u=localStorage.getItem('pb_url');const e=localStorage.getItem('pb_email');if(u)document.getElementById('pbUrl').value=u;if(e)document.getElementById('loginEmail').value=e;}
checkAuth();
document.addEventListener('DOMContentLoaded',()=>{['loginEmail','loginPassword','pbUrl'].forEach(id=>{const el=document.getElementById(id);if(el)el.addEventListener('keydown',e=>{if(e.key==='Enter')doLogin();});});});
function showSection(id){
  document.querySelectorAll('.section').forEach(s=>s.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n=>n.classList.remove('active'));
  document.getElementById('section-'+id).classList.add('active');
  document.querySelector(`[data-section="${id}"]`).classList.add('active');
  const titles={overview:'نظرة عامة',grades:'الصفوف',subjects:'المواد',lessons:'الدروس',pdfs:'ملفات PDF',students:'الطلاب',subscriptions:'الاشتراكات',settings:'الإعدادات'};
  document.getElementById('pageTitle').textContent=titles[id]||id;
  if(id==='grades')loadGrades();if(id==='subjects')loadSubjects();
  if(id==='students')loadStudents();if(id==='subscriptions')loadSubscriptions();if(id==='overview')loadOverview();
}
function toggleSidebar(){document.getElementById('sidebar').classList.toggle('collapsed');}
function toast(msg,type='success'){const t=document.getElementById('toast');t.textContent=msg;t.className='toast '+type;setTimeout(()=>t.classList.add('hidden'),2500);}
function closeModal(id){document.getElementById(id).classList.add('hidden');}
async function initDashboard(){await loadOverview();await populateGradeFilters();await loadGrades();}
async function loadOverview(){
  try{document.getElementById('stat-grades').textContent=(await pbList('grades')).length;}catch{document.getElementById('stat-grades').textContent='0';}
  try{document.getElementById('stat-subjects').textContent=(await pbList('subjects')).length;}catch{document.getElementById('stat-subjects').textContent='0';}
  try{document.getElementById('stat-lessons').textContent=(await pbList('lessons')).length;}catch{document.getElementById('stat-lessons').textContent='0';}
  try{
    const users=await pbList('users',{sort:'-created_at'});
    document.getElementById('stat-students').textContent=users.length;
    const recent=users.slice(0,5);
    if(recent.length){let h='<table><thead><tr><th>الاسم</th><th>البريد</th><th>التاريخ</th></tr></thead><tbody>';recent.forEach(u=>{h+=`<tr><td>${u.name||'—'}</td><td>${u.email||'—'}</td><td>${u.created_at?new Date(u.created_at).toLocaleDateString('ar'):'—'}</td></tr>`;});document.getElementById('recentStudents').innerHTML=h+'</tbody></table>';}
    else document.getElementById('recentStudents').innerHTML='<p class="empty-msg">لا يوجد طلاب بعد</p>';
  }catch{document.getElementById('stat-students').textContent='0';document.getElementById('recentStudents').innerHTML='<p class="empty-msg">لا يوجد طلاب</p>';}
}
async function loadGrades(){
  try{
    const grades=await pbList('grades',{sort:'+grade_number'});
    let h='';
    grades.forEach(g=>{h+=`<div class="grade-card ${g.is_visible?'':'hidden-grade'}"><div class="grade-num">${g.grade_number}</div><div class="grade-name">${g.name_ar}</div><div class="grade-meta">${g.name_en}</div><div class="grade-actions"><label class="toggle-switch"><input type="checkbox" ${g.is_visible?'checked':''} onchange="toggleGrade('${g.id}',this.checked)"/><div class="toggle-track"></div></label><span style="font-size:0.82rem;color:var(--text-muted)">${g.is_visible?'ظاهر':'مخفي'}</span></div></div>`;});
    document.getElementById('gradesList').innerHTML=h||'<p class="empty-msg">لا توجد صفوف</p>';
  }catch(e){document.getElementById('gradesList').innerHTML='<p class="empty-msg">خطأ: '+e.message+'</p>';}
}
async function toggleGrade(id,v){try{await pbUpdate('grades',id,{is_visible:v});toast(v?'تم إظهار الصف':'تم إخفاء الصف');await loadGrades();}catch(e){toast('خطأ: '+e.message,'error');}}
async function populateGradeFilters(){
  let grades=[];try{grades=await pbList('grades',{sort:'+grade_number'});}catch{}
  ['subjectGradeFilter','lessonGradeFilter','pdfGradeFilter','subjectGradeId'].forEach(selId=>{
    const sel=document.getElementById(selId);if(!sel)return;
    const first=sel.options[0];sel.innerHTML='';sel.appendChild(first);
    grades.forEach(g=>{const o=document.createElement('option');o.value=g.id;o.textContent=`الصف ${g.grade_number} — ${g.name_ar}`;sel.appendChild(o);});
  });
}
async function loadSubjects(){
  const gid=document.getElementById('subjectGradeFilter').value;
  if(!gid){document.getElementById('subjectsList').innerHTML='<p class="empty-msg">اختر صفاً</p>';return;}
  try{
    const subs=await pbList('subjects',{sort:'+sort_order',filter:`grade_id='${gid}'`});
    if(!subs.length){document.getElementById('subjectsList').innerHTML='<p class="empty-msg">لا توجد مواد — أضف مادة جديدة</p>';return;}
    let h='<table><thead><tr><th>الأيقونة</th><th>المادة (عربي)</th><th>المادة (إنجليزي)</th><th>الترتيب</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>';
    subs.forEach(s=>{h+=`<tr><td>${s.icon||'📘'}</td><td>${s.name_ar}</td><td>${s.name_en||'—'}</td><td>${s.sort_order||0}</td><td><label class="toggle-switch"><input type="checkbox" ${s.is_visible?'checked':''} onchange="toggleSubject('${s.id}',this.checked)"/><div class="toggle-track"></div></label></td><td class="actions-cell"><button class="btn-icon" onclick="editSubject('${s.id}')">✏️</button><button class="btn-icon btn-danger" onclick="deleteSubject('${s.id}')">🗑️</button></td></tr>`;});
    document.getElementById('subjectsList').innerHTML=h+'</tbody></table>';
  }catch(e){document.getElementById('subjectsList').innerHTML='<p class="empty-msg">خطأ: '+e.message+'</p>';}
}
async function toggleSubject(id,v){try{await pbUpdate('subjects',id,{is_visible:v});toast(v?'تم إظهار المادة':'تم إخفاء المادة');await loadSubjects();}catch(e){toast('خطأ: '+e.message,'error');}}
function openAddSubjectModal(){
  document.getElementById('subjectId').value='';document.getElementById('subjectModalTitle').textContent='إضافة مادة جديدة';
  document.getElementById('subjectNameAr').value='';document.getElementById('subjectNameEn').value='';
  document.getElementById('subjectIcon').value='📘';document.getElementById('subjectColor').value='#7c3aed';
  document.getElementById('subjectOrder').value='1';document.getElementById('subjectVisible').checked=true;
  document.getElementById('subjectModal').classList.remove('hidden');
}
async function editSubject(id){
  const s=await pbGet('subjects',id);
  document.getElementById('subjectId').value=id;document.getElementById('subjectModalTitle').textContent='تعديل المادة';
  document.getElementById('subjectGradeId').value=s.grade_id;document.getElementById('subjectNameAr').value=s.name_ar;
  document.getElementById('subjectNameEn').value=s.name_en||'';document.getElementById('subjectIcon').value=s.icon||'';
  document.getElementById('subjectColor').value=s.color||'#7c3aed';document.getElementById('subjectOrder').value=s.sort_order||1;
  document.getElementById('subjectVisible').checked=s.is_visible;document.getElementById('subjectModal').classList.remove('hidden');
}
async function saveSubject(){
  const id=document.getElementById('subjectId').value;
  const data={grade_id:document.getElementById('subjectGradeId').value,name_ar:document.getElementById('subjectNameAr').value,name_en:document.getElementById('subjectNameEn').value,icon:document.getElementById('subjectIcon').value,color:document.getElementById('subjectColor').value,sort_order:+document.getElementById('subjectOrder').value,is_visible:document.getElementById('subjectVisible').checked};
  try{if(id)await pbUpdate('subjects',id,data);else await pbCreate('subjects',data);toast(id?'تم تحديث المادة':'تمت إضافة المادة');closeModal('subjectModal');await loadSubjects();await loadOverview();}catch(e){toast('خطأ: '+e.message,'error');}
}
async function deleteSubject(id){if(!confirm('حذف هذه المادة؟'))return;await pbDelete('subjects',id);toast('تم حذف المادة');await loadSubjects();}
async function loadLessonSubjects(){
  const gid=document.getElementById('lessonGradeFilter').value;
  const sel=document.getElementById('lessonSubjectFilter');sel.innerHTML='<option value="">— اختر المادة —</option>';if(!gid)return;
  try{const subs=await pbList('subjects',{filter:`grade_id='${gid}'`,sort:'+sort_order'});subs.forEach(s=>{const o=document.createElement('option');o.value=s.id;o.textContent=s.name_ar;sel.appendChild(o);});}catch{}
}
async function loadLessons(){
  const sid=document.getElementById('lessonSubjectFilter').value;
  if(!sid){document.getElementById('lessonsList').innerHTML='<p class="empty-msg">اختر مادة</p>';return;}
  try{
    const items=await pbList('lessons',{filter:`subject_id='${sid}'`,sort:'+sort_order'});
    if(!items.length){document.getElementById('lessonsList').innerHTML='<p class="empty-msg">لا توجد دروس</p>';return;}
    let h='<table><thead><tr><th>#</th><th>العنوان</th><th>المدة</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>';
    items.forEach(l=>{h+=`<tr><td>${l.sort_order||0}</td><td>${l.title_ar}</td><td>${l.duration_min||0} د</td><td><label class="toggle-switch"><input type="checkbox" ${l.is_active?'checked':''} onchange="toggleLesson('${l.id}',this.checked)"/><div class="toggle-track"></div></label></td><td class="actions-cell"><button class="btn-icon" onclick="editLesson('${l.id}')">✏️</button><button class="btn-icon btn-danger" onclick="deleteLesson('${l.id}')">🗑️</button></td></tr>`;});
    document.getElementById('lessonsList').innerHTML=h+'</tbody></table>';
  }catch(e){document.getElementById('lessonsList').innerHTML='<p class="empty-msg">خطأ: '+e.message+'</p>';}
}
async function toggleLesson(id,v){try{await pbUpdate('lessons',id,{is_active:v});toast(v?'مفعّل':'معطّل');loadLessons();}catch(e){toast('خطأ: '+e.message,'error');}}
function openAddLessonModal(){
  const sid=document.getElementById('lessonSubjectFilter').value;if(!sid){toast('اختر مادة أولاً','error');return;}
  document.getElementById('lessonId').value='';document.getElementById('lessonModalTitle').textContent='إضافة درس';
  document.getElementById('lessonTitleAr').value='';document.getElementById('lessonTitleEn').value='';
  document.getElementById('lessonVideoUrl').value='';document.getElementById('lessonDuration').value='30';
  document.getElementById('lessonOrder').value='1';document.getElementById('lessonActive').checked=true;
  document.getElementById('lessonModal').classList.remove('hidden');
}
async function editLesson(id){
  const l=await pbGet('lessons',id);
  document.getElementById('lessonId').value=id;document.getElementById('lessonModalTitle').textContent='تعديل الدرس';
  document.getElementById('lessonTitleAr').value=l.title_ar;document.getElementById('lessonTitleEn').value=l.title_en||'';
  document.getElementById('lessonVideoUrl').value=l.video_url||'';document.getElementById('lessonDuration').value=l.duration_min||30;
  document.getElementById('lessonOrder').value=l.sort_order||1;document.getElementById('lessonActive').checked=l.is_active;
  document.getElementById('lessonModal').classList.remove('hidden');
}
async function saveLesson(){
  const id=document.getElementById('lessonId').value;const sid=document.getElementById('lessonSubjectFilter').value;
  const data={subject_id:sid,title_ar:document.getElementById('lessonTitleAr').value,title_en:document.getElementById('lessonTitleEn').value,video_url:document.getElementById('lessonVideoUrl').value,duration_min:+document.getElementById('lessonDuration').value,sort_order:+document.getElementById('lessonOrder').value,is_active:document.getElementById('lessonActive').checked};
  try{if(id)await pbUpdate('lessons',id,data);else await pbCreate('lessons',data);toast(id?'تم التحديث':'تمت الإضافة');closeModal('lessonModal');loadLessons();loadOverview();}catch(e){toast('خطأ: '+e.message,'error');}
}
async function deleteLesson(id){if(!confirm('حذف؟'))return;await pbDelete('lessons',id);toast('تم الحذف');loadLessons();}
async function loadPdfSubjects(){
  const gid=document.getElementById('pdfGradeFilter').value;
  const sel=document.getElementById('pdfSubjectFilter');sel.innerHTML='<option value="">— اختر المادة —</option>';if(!gid)return;
  try{const subs=await pbList('subjects',{filter:`grade_id='${gid}'`,sort:'+sort_order'});subs.forEach(s=>{const o=document.createElement('option');o.value=s.id;o.textContent=s.name_ar;sel.appendChild(o);});}catch{}
}
async function loadPdfs(){
  const sid=document.getElementById('pdfSubjectFilter').value;
  if(!sid){document.getElementById('pdfsList').innerHTML='<p class="empty-msg">اختر مادة</p>';return;}
  try{
    const items=await pbList('pdfs',{filter:`subject_id='${sid}'`});
    if(!items.length){document.getElementById('pdfsList').innerHTML='<p class="empty-msg">لا توجد ملفات</p>';return;}
    const types={summary:'ملخص',exam_answer:'حل امتحان',worksheet:'ورقة عمل'};
    let h='<table><thead><tr><th>العنوان</th><th>النوع</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>';
    items.forEach(p=>{h+=`<tr><td>${p.title_ar}</td><td><span class="badge badge-blue">${types[p.pdf_type]||p.pdf_type||'—'}</span></td><td><label class="toggle-switch"><input type="checkbox" ${p.is_active?'checked':''} onchange="togglePdf('${p.id}',this.checked)"/><div class="toggle-track"></div></label></td><td class="actions-cell"><button class="btn-icon btn-danger" onclick="deletePdf('${p.id}')">🗑️</button></td></tr>`;});
    document.getElementById('pdfsList').innerHTML=h+'</tbody></table>';
  }catch(e){document.getElementById('pdfsList').innerHTML='<p class="empty-msg">خطأ: '+e.message+'</p>';}
}
async function togglePdf(id,v){try{await pbUpdate('pdfs',id,{is_active:v});toast(v?'مرئي':'مخفي');loadPdfs();}catch(e){toast('خطأ','error');}}
function onFileSelected(input){const name=input.files[0]?.name||'';document.getElementById('fileSelectedName').textContent=name?'✅ '+name:'';}
function openAddPdfModal(){
  const sid=document.getElementById('pdfSubjectFilter').value;if(!sid){toast('اختر مادة أولاً','error');return;}
  document.getElementById('pdfTitleAr').value='';document.getElementById('pdfTitleEn').value='';
  document.getElementById('pdfType').value='summary';document.getElementById('pdfActive').checked=true;
  document.getElementById('fileSelectedName').textContent='';document.getElementById('pdfModal').classList.remove('hidden');
}
async function savePdf(){
  const sid=document.getElementById('pdfSubjectFilter').value;const fi=document.getElementById('pdfFileInput');
  const fd=new FormData();
  fd.append('subject_id',sid);fd.append('title_ar',document.getElementById('pdfTitleAr').value);
  fd.append('title_en',document.getElementById('pdfTitleEn').value);fd.append('pdf_type',document.getElementById('pdfType').value);
  fd.append('is_active',document.getElementById('pdfActive').checked);
  if(fi.files[0])fd.append('file_data',fi.files[0]);
  try{const r=await fetch(`${PB_URL}/api/collections/pdfs/records`,{method:'POST',headers:{'Authorization':`Bearer ${PB_TOKEN}`},body:fd});if(!r.ok)throw new Error(await r.text());toast('تم رفع الملف');closeModal('pdfModal');loadPdfs();}catch(e){toast('خطأ: '+e.message,'error');}
}
async function deletePdf(id){if(!confirm('حذف؟'))return;await pbDelete('pdfs',id);toast('تم الحذف');loadPdfs();}
let allStudents=[];
async function loadStudents(){
  try{
    // sort by created_at desc
    allStudents=await pbList('users',{sort:'-created_at'});
    renderStudents(allStudents);
  }catch(e){
    document.getElementById('studentsList').innerHTML=
      `<p class="empty-msg">❌ خطأ في تحميل الطلاب: ${e.message}<br><small style="color:var(--text-muted)">تأكد من أن PocketBase يعمل على ${PB_URL}</small></p>`;
  }
}
function searchStudents(){const q=document.getElementById('studentSearch').value.toLowerCase();renderStudents(allStudents.filter(s=>(s.name||'').toLowerCase().includes(q)||(s.email||'').toLowerCase().includes(q)));}
function renderStudents(list){
  if(!list.length){document.getElementById('studentsList').innerHTML='<p class="empty-msg">لا يوجد طلاب</p>';return;}
  let h='<table><thead><tr><th>الاسم</th><th>البريد</th><th>كلمة المرور</th><th>الصف/الشعبة</th><th>الحالة</th><th>الاشتراك</th><th>تاريخ التسجيل</th><th>إجراءات</th></tr></thead><tbody>';
  list.forEach(s=>{
    const sectionName = s.section === 'scientific' ? 'علمي' : (s.section === 'literary' ? 'أدبي' : s.section || '—');
    const isBlocked = s.is_blocked === true;
    const isSubscribed = s.is_subscribed === true;
    h+=`<tr>
      <td>${s.name||'—'}</td>
      <td>${s.email||'—'}</td>
      <td><span style="font-family:monospace;font-size:0.85rem">${s.password||'—'}</span></td>
      <td>الصف ${s.grade||'—'} (${sectionName})</td>
      <td>${isBlocked ? '<span class="badge badge-red">🚫 محظور</span>' : '<span class="badge badge-green">نشط</span>'}</td>
      <td>${isSubscribed ? '<span class="badge badge-green">✓ مشترك</span>' : '<span class="badge badge-red">غير مشترك</span>'}</td>
      <td>${s.created_at ? new Date(s.created_at).toLocaleDateString('ar') : '—'}</td>
      <td class="actions-cell">
        <button class="btn-icon" onclick="openStudentModal('${s.id}')" title="تعديل الطالب">✏️</button>
        <button class="btn-icon" onclick="toggleBlockStudent('${s.id}', ${isBlocked})" title="${isBlocked ? 'إلغاء الحظر' : 'حظر الطالب'}">${isBlocked ? '🔓' : '🚫'}</button>
        <button class="btn-icon" onclick="openEditSubscriptionDurationModal('${s.id}', '${s.email||''}', '${s.firebase_uid||''}')" title="تعديل مدة الاشتراك">💰</button>
        <button class="btn-icon btn-danger" onclick="deleteStudent('${s.id}')" title="حذف الطالب">🗑️</button>
      </td>
    </tr>`;
  });
  document.getElementById('studentsList').innerHTML=h+'</tbody></table>';
}

function openStudentModal(id = ''){
  if (id) {
    document.getElementById('studentId').value = id;
    const s = allStudents.find(x => x.id === id);
    if (!s) return;
    document.getElementById('studentModalTitle').innerText = 'تعديل بيانات الطالب';
    document.getElementById('studentName').value = s.name || '';
    document.getElementById('studentEmail').value = s.email || '';
    document.getElementById('studentPassword').value = s.password || '';
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

async function saveStudent(){
  const id = document.getElementById('studentId').value;
  const name = document.getElementById('studentName').value.trim();
  const email = document.getElementById('studentEmail').value.trim();
  const password = document.getElementById('studentPassword').value.trim();
  const grade = parseInt(document.getElementById('studentGrade').value) || 12;
  const section = document.getElementById('studentSection').value;

  if(!name || !email){
    toast('يرجى إدخال الاسم والبريد الإلكتروني', 'error');
    return;
  }

  const firebaseApiKey = "AIzaSyDdQJvBWxCX4XmdZbH7sKPOhR68Uae7bB8";

  if (id) {
    // Edit existing student
    try {
      const s = allStudents.find(x => x.id === id);
      let firebase_uid = s ? s.firebase_uid : '';
      
      if (password && firebase_uid && !firebase_uid.startsWith('pb_created_')) {
        try {
          const fbRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:update?key=${firebaseApiKey}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              localId: firebase_uid,
              email: email,
              password: password,
              returnSecureToken: true
            })
          });
          if (!fbRes.ok) {
            const errData = await fbRes.json();
            console.error('Firebase update warning:', errData);
          }
        } catch(err) {
          console.error('Firebase update network error:', err);
        }
      }

      const payload = { name, email, password, grade, section };
      await pbUpdate('users', id, payload);
      toast('✅ تم تحديث بيانات الطالب بنجاح');
      closeModal('studentModal');
      loadStudents();
    } catch(e) {
      toast('خطأ: ' + e.message, 'error');
    }
  } else {
    // Add new student
    if (!password || password.length < 6) {
      toast('يرجى إدخال كلمة مرور لا تقل عن 6 أحرف للتحقق في التطبيق', 'error');
      return;
    }

    let firebase_uid = 'pb_created_' + Math.random().toString(36).substring(2, 12);
    
    // Register the student in Firebase Auth first
    try {
      const fbRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${firebaseApiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: email,
          password: password,
          returnSecureToken: true
        })
      });
      if (fbRes.ok) {
        const fbData = await fbRes.json();
        firebase_uid = fbData.localId;
      } else {
        const errData = await fbRes.json();
        const errMsg = errData.error ? errData.error.message : '';
        if (errMsg === 'EMAIL_EXISTS') {
          toast('هذا البريد الإلكتروني مسجل بالفعل في النظام', 'error');
          return;
        } else {
          toast('خطأ في التسجيل بـ Firebase: ' + errMsg, 'error');
          return;
        }
      }
    } catch(err) {
      toast('خطأ في الاتصال بـ Firebase: ' + err.message, 'error');
      return;
    }

    const is_subscribed = document.getElementById('studentSubscribed').checked;
    const payload = {
      name,
      email,
      password,
      firebase_uid,
      grade,
      section,
      lang: 'ar',
      is_subscribed,
      is_blocked: false
    };

    try {
      await pbCreate('users', payload);
      if(is_subscribed) {
        const today = new Date().toISOString().split('T')[0];
        const end = new Date();
        end.setDate(end.getDate() + 30);
        await pbCreate('subscriptions', {
          user_email: email,
          firebase_uid: payload.firebase_uid,
          plan: 'custom',
          status: 'active',
          start_date: today,
          end_date: end.toISOString().split('T')[0]
        });
      }
      toast('✅ تم إضافة الطالب بنجاح');
      closeModal('studentModal');
      loadStudents();
    } catch(e) {
      toast('خطأ: ' + e.message, 'error');
    }
  }
}

async function toggleBlockStudent(id, currentBlocked){
  const actionText = currentBlocked ? 'إلغاء حظر هذا الطالب؟' : 'حظر هذا الطالب ومنعه من استخدام التطبيق؟';
  if(!confirm(actionText)) return;
  try {
    await pbUpdate('users', id, { is_blocked: !currentBlocked });
    toast(currentBlocked ? '✅ تم إلغاء حظر الطالب' : '🚫 تم حظر الطالب');
    loadStudents();
  } catch(e) {
    toast('خطأ: ' + e.message, 'error');
  }
}

async function openEditSubscriptionDurationModal(studentId, email, firebaseUid) {
  document.getElementById('editSubStudentId').value = studentId;
  document.getElementById('editSubStudentEmail').value = email;
  document.getElementById('editSubStudentUid').value = firebaseUid;
  document.getElementById('editSubEmailDisplay').value = email;
  
  // Fetch subscription from PocketBase
  let currentSub = null;
  try {
    const subs = await pbList('subscriptions', {
      filter: `firebase_uid='${firebaseUid}'||user_email='${email}'`,
      sort: '-created_at',
      perPage: 1
    });
    if (subs.length) currentSub = subs[0];
  } catch(e) {
    console.error('Error fetching subscription:', e);
  }

  const statusEl = document.getElementById('editSubStatusDisplay');
  const endDateEl = document.getElementById('editSubEndDate');

  if (currentSub && currentSub.status === 'active') {
    statusEl.innerHTML = `<span class="badge badge-green">فعّال</span> ينتهي في ${currentSub.end_date || 'غير محدد'}`;
    endDateEl.value = currentSub.end_date || new Date().toISOString().split('T')[0];
  } else {
    statusEl.innerHTML = `<span class="badge badge-red">غير مشترك</span>`;
    const defaultEnd = new Date();
    defaultEnd.setDate(defaultEnd.getDate() + 30);
    endDateEl.value = defaultEnd.toISOString().split('T')[0];
  }

  document.getElementById('editSubDurationModal').classList.remove('hidden');
}

async function saveSubscriptionDuration() {
  const studentId = document.getElementById('editSubStudentId').value;
  const email = document.getElementById('editSubStudentEmail').value;
  const firebaseUid = document.getElementById('editSubStudentUid').value;
  const newEndDate = document.getElementById('editSubEndDate').value;

  if (!newEndDate) {
    toast('يرجى تحديد تاريخ الانتهاء', 'error');
    return;
  }

  try {
    // Check if there is an existing subscription
    const subs = await pbList('subscriptions', {
      filter: `firebase_uid='${firebaseUid}'||user_email='${email}'`,
      sort: '-created_at',
      perPage: 1
    });

    const today = new Date().toISOString().split('T')[0];
    const isFuture = newEndDate >= today;

    if (subs.length) {
      // Update existing subscription
      await pbUpdate('subscriptions', subs[0].id, {
        end_date: newEndDate,
        status: isFuture ? 'active' : 'expired'
      });
    } else {
      // Create a new subscription
      await pbCreate('subscriptions', {
        user_email: email,
        firebase_uid: firebaseUid || 'pb_created_' + Math.random().toString(36).substring(2, 12),
        plan: 'custom',
        status: isFuture ? 'active' : 'expired',
        start_date: today,
        end_date: newEndDate
      });
    }

    // Also update is_subscribed status on the student record
    await pbUpdate('users', studentId, { is_subscribed: isFuture });

    toast('✅ تم تعديل مدة الاشتراك بنجاح');
    closeModal('editSubDurationModal');
    loadStudents();
  } catch(e) {
    toast('خطأ: ' + e.message, 'error');
  }
}

async function deleteStudent(id){
  if(!confirm('تحذير: هل تريد حذف هذا الطالب نهائياً من النظام؟ لا يمكن التراجع عن هذا الإجراء.')) return;
  try {
    await pbDelete('users', id);
    toast('تم حذف الطالب بنجاح');
    loadStudents();
  } catch(e) {
    toast('خطأ: ' + e.message, 'error');
  }
}
async function loadSubscriptions(){
  try{
    // sort by created_at desc
    const items=await pbList('subscriptions',{sort:'-created_at'});
    const toolbar=`<div class="section-toolbar" style="margin-bottom:1rem"><h3>الاشتراكات</h3><button class="btn-primary" onclick="openAddSubscriptionModal()">+ إضافة اشتراك</button></div>`;
    if(!items.length){document.getElementById('subscriptionsList').innerHTML=toolbar+'<p class="empty-msg">لا توجد اشتراكات</p>';return;}
    const st={active:'فعّال',expired:'منتهي',cancelled:'ملغي'};
    const bc={active:'badge-green',expired:'badge-red',cancelled:'badge-amber'};
    let h=toolbar+'<table><thead><tr><th>البريد</th><th>Firebase UID</th><th>الخطة</th><th>الحالة</th><th>البداية</th><th>النهاية</th><th>إجراءات</th></tr></thead><tbody>';
    items.forEach(s=>{
      const status=s.status||s.sub_status||'—';
      h+=`<tr><td>${s.user_email||'—'}</td><td style="font-size:0.75rem;color:var(--text-muted)">${(s.firebase_uid||'').substring(0,14)}…</td><td>${s.plan||'—'}</td><td><span class="badge ${bc[status]||''}">${st[status]||status}</span></td><td>${s.start_date?new Date(s.start_date).toLocaleDateString('ar'):'—'}</td><td>${s.end_date?new Date(s.end_date).toLocaleDateString('ar'):'—'}</td><td class="actions-cell">${status!=='active'?`<button class="btn-icon" onclick="activateSub('${s.id}')">✅</button>`:''} ${status==='active'?`<button class="btn-icon btn-danger" onclick="cancelSub('${s.id}')">🚫</button>`:''}<button class="btn-icon btn-danger" onclick="deleteSub('${s.id}')">🗑️</button></td></tr>`;
    });
    document.getElementById('subscriptionsList').innerHTML=h+'</tbody></table>';
  }catch(e){document.getElementById('subscriptionsList').innerHTML='<p class="empty-msg">خطأ: '+e.message+'</p>';}
}
async function activateSub(id){
  const today=new Date().toISOString().split('T')[0];
  const end=new Date();end.setDate(end.getDate()+180);
  try{
    await pbUpdate('subscriptions',id,{status:'active',start_date:today,end_date:end.toISOString().split('T')[0]});
    // Also update is_subscribed on the user record if firebase_uid is set
    const rec=await pbGet('subscriptions',id);
    if(rec&&rec.firebase_uid){
      const users=await pbList('users',{filter:`firebase_uid='${rec.firebase_uid}'`,perPage:1});
      if(users.length)await pbUpdate('users',users[0].id,{is_subscribed:true});
    }
    toast('✅ تم تفعيل الاشتراك');loadSubscriptions();
  }catch(e){toast('خطأ: '+e.message,'error');}
}
async function cancelSub(id){
  if(!confirm('إلغاء هذا الاشتراك؟'))return;
  try{
    await pbUpdate('subscriptions',id,{status:'cancelled'});
    toast('تم إلغاء الاشتراك');loadSubscriptions();
  }catch(e){toast('خطأ: '+e.message,'error');}
}
async function deleteSub(id){if(!confirm('حذف؟'))return;await pbDelete('subscriptions',id);toast('تم الحذف');loadSubscriptions();}
function openAddSubscriptionModal(){
  document.getElementById('subEmail').value='';
  document.getElementById('subFirebaseUid').value='';
  document.getElementById('subPlan').value='monthly';
  document.getElementById('subDays').value='30';
  document.getElementById('addSubModal').classList.remove('hidden');
}
async function saveSubscription(){
  const email=document.getElementById('subEmail').value.trim();
  const uid=document.getElementById('subFirebaseUid').value.trim();
  const plan=document.getElementById('subPlan').value;
  const days=parseInt(document.getElementById('subDays').value)||30;
  if(!email&&!uid){toast('أدخل البريد الإلكتروني أو Firebase UID','error');return;}
  const start=new Date();const end=new Date();end.setDate(end.getDate()+days);
  const payload={plan,status:'active',start_date:start.toISOString().split('T')[0],end_date:end.toISOString().split('T')[0]};
  if(email)payload.user_email=email;
  if(uid)payload.firebase_uid=uid;
  try{
    await pbCreate('subscriptions',payload);
    // Update is_subscribed flag on user record
    if(uid){
      const users=await pbList('users',{filter:`firebase_uid='${uid}'`,perPage:1});
      if(users.length)await pbUpdate('users',users[0].id,{is_subscribed:true});
    } else if(email){
      const users=await pbList('users',{filter:`email='${email}'`,perPage:1});
      if(users.length)await pbUpdate('users',users[0].id,{is_subscribed:true});
    }
    toast('✅ تم إضافة الاشتراك');
    closeModal('addSubModal');
    loadSubscriptions();
  }catch(e){toast('خطأ: '+e.message,'error');}
}
async function changePassword(){
  const p=document.getElementById('newPassword').value;const c=document.getElementById('confirmPassword').value;
  if(p.length<8){toast('كلمة المرور يجب أن تكون 8 أحرف على الأقل','error');return;}
  if(p!==c){toast('كلمتا المرور غير متطابقتين','error');return;}
  try{
    const me=await pbFetch('collections/_superusers/auth-refresh',{method:'POST'});
    await pbUpdate('_superusers',me.record.id,{password:p,passwordConfirm:c});
    toast('✅ تم تغيير كلمة المرور بنجاح');
    document.getElementById('newPassword').value='';document.getElementById('confirmPassword').value='';
  }catch(e){toast('خطأ: '+e.message,'error');}
}
