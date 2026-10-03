/**
 * seed_subjects.js — Seed subjects for all grades in PocketBase
 * Run: node seed_subjects.js
 * 
 * Prerequisites: PocketBase running on http://127.0.0.1:8090
 * Edit ADMIN_EMAIL and ADMIN_PASSWORD if needed.
 */
const PB_URL = 'http://127.0.0.1:8090';
const ADMIN_EMAIL = 'tam.app83@gmail.com';
const ADMIN_PASSWORD = 'Tam2025@AdminPass!';

// Subject definitions per grade range
// Format: { name_ar, name_en, icon, color, sort_order }
const SUBJECTS_BY_GRADE = {
  6:  [
    { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
    { name_ar: 'العلوم', name_en: 'Science', icon: '🔬', color: '10B981', sort_order: 2 },
    { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 3 },
    { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 4 },
    { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 5 },
    { name_ar: 'الاجتماعيات', name_en: 'Social Studies', icon: '🗺️', color: '6366F1', sort_order: 6 },
  ],
  7:  [
    { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
    { name_ar: 'العلوم', name_en: 'Science', icon: '🔬', color: '10B981', sort_order: 2 },
    { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 3 },
    { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 4 },
    { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 5 },
    { name_ar: 'الاجتماعيات', name_en: 'Social Studies', icon: '🗺️', color: '6366F1', sort_order: 6 },
  ],
  8:  [
    { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
    { name_ar: 'العلوم', name_en: 'Science', icon: '🔬', color: '10B981', sort_order: 2 },
    { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 3 },
    { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 4 },
    { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 5 },
    { name_ar: 'الاجتماعيات', name_en: 'Social Studies', icon: '🗺️', color: '6366F1', sort_order: 6 },
  ],
  9:  [
    { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
    { name_ar: 'الفيزياء', name_en: 'Physics', icon: '⚛️', color: '06B6D4', sort_order: 2 },
    { name_ar: 'الكيمياء', name_en: 'Chemistry', icon: '🧪', color: '10B981', sort_order: 3 },
    { name_ar: 'الأحياء', name_en: 'Biology', icon: '🌱', color: '84CC16', sort_order: 4 },
    { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 5 },
    { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 6 },
    { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 7 },
    { name_ar: 'الاجتماعيات', name_en: 'Social Studies', icon: '🗺️', color: '6366F1', sort_order: 8 },
  ],
  10: [
    { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
    { name_ar: 'الفيزياء', name_en: 'Physics', icon: '⚛️', color: '06B6D4', sort_order: 2 },
    { name_ar: 'الكيمياء', name_en: 'Chemistry', icon: '🧪', color: '10B981', sort_order: 3 },
    { name_ar: 'الأحياء', name_en: 'Biology', icon: '🌱', color: '84CC16', sort_order: 4 },
    { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 5 },
    { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 6 },
    { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 7 },
    { name_ar: 'الاجتماعيات', name_en: 'Social Studies', icon: '🗺️', color: '6366F1', sort_order: 8 },
  ],
  // Grade 11 & 12 Scientific section
  '11_scientific': [
    { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
    { name_ar: 'الفيزياء', name_en: 'Physics', icon: '⚛️', color: '06B6D4', sort_order: 2 },
    { name_ar: 'الكيمياء', name_en: 'Chemistry', icon: '🧪', color: '10B981', sort_order: 3 },
    { name_ar: 'الأحياء', name_en: 'Biology', icon: '🌱', color: '84CC16', sort_order: 4 },
    { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 5 },
    { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 6 },
    { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 7 },
  ],
  // Grade 11 & 12 Literary section
  '11_literary': [
    { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
    { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 2 },
    { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 3 },
    { name_ar: 'التاريخ', name_en: 'History', icon: '📜', color: 'A78BFA', sort_order: 4 },
    { name_ar: 'الجغرافيا', name_en: 'Geography', icon: '🗺️', color: '6366F1', sort_order: 5 },
    { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 6 },
    { name_ar: 'الاقتصاد', name_en: 'Economics', icon: '💹', color: 'F59E0B', sort_order: 7 },
  ],
  '12_scientific': [
    { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
    { name_ar: 'الفيزياء', name_en: 'Physics', icon: '⚛️', color: '06B6D4', sort_order: 2 },
    { name_ar: 'الكيمياء', name_en: 'Chemistry', icon: '🧪', color: '10B981', sort_order: 3 },
    { name_ar: 'الأحياء', name_en: 'Biology', icon: '🌱', color: '84CC16', sort_order: 4 },
    { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 5 },
    { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 6 },
    { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 7 },
  ],
  '12_literary': [
    { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
    { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 2 },
    { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 3 },
    { name_ar: 'التاريخ', name_en: 'History', icon: '📜', color: 'A78BFA', sort_order: 4 },
    { name_ar: 'الجغرافيا', name_en: 'Geography', icon: '🗺️', color: '6366F1', sort_order: 5 },
    { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 6 },
    { name_ar: 'الاقتصاد', name_en: 'Economics', icon: '💹', color: 'F59E0B', sort_order: 7 },
  ],
};

async function main() {
  // 1. Login as superuser
  console.log('🔑 Logging in...');
  const authRes = await fetch(`${PB_URL}/api/collections/_superusers/auth-with-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identity: ADMIN_EMAIL, password: ADMIN_PASSWORD }),
  });
  if (!authRes.ok) {
    const err = await authRes.text();
    throw new Error(`Login failed: ${err}`);
  }
  const { token } = await authRes.json();
  console.log('✅ Logged in');

  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  };

  // 2. Fetch all grades
  console.log('📋 Fetching grades...');
  const gradesRes = await fetch(`${PB_URL}/api/collections/grades/records?perPage=200&sort=grade_number`, { headers });
  const gradesData = await gradesRes.json();
  const grades = gradesData.items || [];
  console.log(`Found ${grades.length} grades`);

  if (!grades.length) {
    console.error('❌ No grades found! Run seed_grades.js first.');
    process.exit(1);
  }

  // 3. Check existing subjects
  const existingRes = await fetch(`${PB_URL}/api/collections/subjects/records?perPage=200`, { headers });
  const existingData = await existingRes.json();
  const existingSubjects = existingData.items || [];
  console.log(`Found ${existingSubjects.length} existing subjects`);

  if (existingSubjects.length > 0) {
    console.log('⚠️  Subjects already exist. Skipping to avoid duplicates.');
    console.log('   Delete existing subjects from dashboard if you want to re-seed.');
    process.exit(0);
  }

  // 4. Seed subjects for each grade
  let total = 0;
  for (const grade of grades) {
    const gradeNum = grade.grade_number;
    const section = grade.section || null; // 'scientific' or 'literary' or null
    
    // Determine which subject list to use
    let subjectKey;
    if (gradeNum >= 11 && section === 'scientific') subjectKey = `${gradeNum}_scientific`;
    else if (gradeNum >= 11 && section === 'literary') subjectKey = `${gradeNum}_literary`;
    else subjectKey = gradeNum;

    const subjectList = SUBJECTS_BY_GRADE[subjectKey];
    if (!subjectList) {
      console.log(`⚠️  No subjects defined for grade ${gradeNum} ${section || ''}`);
      continue;
    }

    console.log(`\n📚 Seeding ${subjectList.length} subjects for Grade ${gradeNum} (${section || 'all'}) [ID: ${grade.id}]`);
    
    for (const sub of subjectList) {
      const res = await fetch(`${PB_URL}/api/collections/subjects/records`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          grade_id: grade.id,
          name_ar: sub.name_ar,
          name_en: sub.name_en,
          icon: sub.icon,
          color: sub.color,
          sort_order: sub.sort_order,
          is_visible: true,
        }),
      });
      if (res.ok) {
        total++;
        process.stdout.write(`  ✅ ${sub.name_ar}\n`);
      } else {
        const err = await res.text();
        console.log(`  ❌ Failed to create ${sub.name_ar}: ${err}`);
      }
    }
  }

  console.log(`\n🎉 Done! Created ${total} subjects total.`);
}

main().catch(e => { console.error('❌ Error:', e.message); process.exit(1); });
