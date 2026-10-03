// Script to seed grades via PocketBase Admin API
// Run with: node seed_grades.js
const PB_URL = 'http://127.0.0.1:8090';
const EMAIL  = 'tam.app83@gmail.com';
const PASS   = 'Tam2025@AdminPass!';

const GRADES = [
  { grade_number: 6,  name_ar: 'الصف السادس',               name_en: 'Grade 6',            section: '',          sort_order: 1,  is_visible: true },
  { grade_number: 7,  name_ar: 'الصف السابع',               name_en: 'Grade 7',            section: '',          sort_order: 2,  is_visible: true },
  { grade_number: 8,  name_ar: 'الصف الثامن',               name_en: 'Grade 8',            section: '',          sort_order: 3,  is_visible: true },
  { grade_number: 9,  name_ar: 'الصف التاسع',               name_en: 'Grade 9',            section: '',          sort_order: 4,  is_visible: true },
  { grade_number: 10, name_ar: 'الصف العاشر',               name_en: 'Grade 10',           section: '',          sort_order: 5,  is_visible: true },
  { grade_number: 11, name_ar: 'الصف الحادي عشر — علمي',   name_en: 'Grade 11 (Science)', section: 'scientific', sort_order: 6,  is_visible: true },
  { grade_number: 11, name_ar: 'الصف الحادي عشر — أدبي',   name_en: 'Grade 11 (Literary)',section: 'literary',  sort_order: 7,  is_visible: true },
  { grade_number: 12, name_ar: 'الصف الثاني عشر — علمي',   name_en: 'Grade 12 (Science)', section: 'scientific', sort_order: 8,  is_visible: true },
  { grade_number: 12, name_ar: 'الصف الثاني عشر — أدبي',   name_en: 'Grade 12 (Literary)',section: 'literary',  sort_order: 9,  is_visible: true },
];

async function main() {
  // 1. Login as superuser
  const authRes = await fetch(`${PB_URL}/api/collections/_superusers/auth-with-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identity: EMAIL, password: PASS }),
  });
  if (!authRes.ok) { console.error('Auth failed:', await authRes.text()); return; }
  const { token } = await authRes.json();
  const headers = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` };

  // 2. Delete all existing grades first (clean seed)
  const listRes = await fetch(`${PB_URL}/api/collections/grades/records?perPage=200`, { headers });
  const { items = [] } = await listRes.json();
  for (const item of items) {
    await fetch(`${PB_URL}/api/collections/grades/records/${item.id}`, { method: 'DELETE', headers });
    console.log(`Deleted grade ${item.grade_number} ${item.name_en || ''}`);
  }

  // 3. Insert new grades
  for (const g of GRADES) {
    const r = await fetch(`${PB_URL}/api/collections/grades/records`, {
      method: 'POST', headers,
      body: JSON.stringify(g),
    });
    const d = await r.json();
    if (r.ok) console.log(`✅ Created: ${g.name_ar}`);
    else console.error(`❌ Failed: ${g.name_ar}`, d.message);
  }
  console.log('\nDone! Refresh the admin dashboard to see the grades.');
}

main().catch(console.error);
