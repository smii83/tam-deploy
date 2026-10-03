/**
 * seed_subjects_grade11_12.js — Seed subjects for grades 11 and 12
 * Detects section from name_ar (علمي/أدبي)
 */
const PB_URL = 'http://127.0.0.1:8090';
const ADMIN_EMAIL = 'tam.app83@gmail.com';
const ADMIN_PASSWORD = 'Tam2025@AdminPass!';

const SUBJECTS_SCIENTIFIC = [
  { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
  { name_ar: 'الفيزياء', name_en: 'Physics', icon: '⚛️', color: '06B6D4', sort_order: 2 },
  { name_ar: 'الكيمياء', name_en: 'Chemistry', icon: '🧪', color: '10B981', sort_order: 3 },
  { name_ar: 'الأحياء', name_en: 'Biology', icon: '🌱', color: '84CC16', sort_order: 4 },
  { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 5 },
  { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 6 },
  { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 7 },
];

const SUBJECTS_LITERARY = [
  { name_ar: 'الرياضيات', name_en: 'Mathematics', icon: '🔢', color: '3B82F6', sort_order: 1 },
  { name_ar: 'اللغة العربية', name_en: 'Arabic', icon: '📖', color: 'EF4444', sort_order: 2 },
  { name_ar: 'اللغة الإنجليزية', name_en: 'English', icon: '🌍', color: 'F59E0B', sort_order: 3 },
  { name_ar: 'التاريخ', name_en: 'History', icon: '📜', color: 'A78BFA', sort_order: 4 },
  { name_ar: 'الجغرافيا', name_en: 'Geography', icon: '🗺️', color: '6366F1', sort_order: 5 },
  { name_ar: 'التربية الإسلامية', name_en: 'Islamic', icon: '🕌', color: '8B5CF6', sort_order: 6 },
  { name_ar: 'الاقتصاد', name_en: 'Economics', icon: '💹', color: 'F59E0B', sort_order: 7 },
];

async function main() {
  // Login
  const authRes = await fetch(`${PB_URL}/api/collections/_superusers/auth-with-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identity: ADMIN_EMAIL, password: ADMIN_PASSWORD }),
  });
  const { token } = await authRes.json();
  const headers = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` };

  // Fetch grade 11 & 12 records
  const gradesRes = await fetch(`${PB_URL}/api/collections/grades/records?perPage=200&sort=grade_number`, { headers });
  const { items: grades } = await gradesRes.json();
  const upperGrades = grades.filter(g => g.grade_number >= 11);
  
  console.log(`Found ${upperGrades.length} grade 11/12 records`);

  let total = 0;
  for (const grade of upperGrades) {
    // Detect section from name_ar: contains "علمي" → scientific, "أدبي" → literary
    const isScientific = grade.name_ar.includes('علمي');
    const isLiterary = grade.name_ar.includes('أدبي');
    const subjectList = isScientific ? SUBJECTS_SCIENTIFIC : (isLiterary ? SUBJECTS_LITERARY : null);
    
    if (!subjectList) {
      console.log(`⚠️  Cannot determine section for grade ${grade.grade_number}: ${grade.name_ar}`);
      continue;
    }

    const sectionLabel = isScientific ? 'علمي' : 'أدبي';
    console.log(`\n📚 Grade ${grade.grade_number} ${sectionLabel} — ${subjectList.length} subjects [ID: ${grade.id}]`);
    
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
        console.log(`  ❌ ${sub.name_ar}: ${err}`);
      }
    }
  }
  console.log(`\n🎉 Done! Added ${total} subjects for grades 11 & 12.`);
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });
