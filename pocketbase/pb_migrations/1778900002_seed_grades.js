/// <reference path="../pb_data/types.d.ts" />
// Seed: insert default grades data (grades 6-12 with AR/EN names)
migrate((app) => {
  const col = app.findCollectionByNameOrId("grades");
  if (!col) return;

  const grades = [
    { grade_number: 6,  name_ar: "الصف السادس",          name_en: "Grade 6",  sort_order: 1,  is_visible: true },
    { grade_number: 7,  name_ar: "الصف السابع",          name_en: "Grade 7",  sort_order: 2,  is_visible: true },
    { grade_number: 8,  name_ar: "الصف الثامن",          name_en: "Grade 8",  sort_order: 3,  is_visible: true },
    { grade_number: 9,  name_ar: "الصف التاسع",          name_en: "Grade 9",  sort_order: 4,  is_visible: true },
    { grade_number: 10, name_ar: "الصف العاشر",          name_en: "Grade 10", sort_order: 5,  is_visible: true },
    { grade_number: 11, name_ar: "الصف الحادي عشر — علمي",  name_en: "Grade 11 (Science)", sort_order: 6,  is_visible: true, section: "scientific" },
    { grade_number: 11, name_ar: "الصف الحادي عشر — أدبي",  name_en: "Grade 11 (Literary)", sort_order: 7,  is_visible: true, section: "literary" },
    { grade_number: 12, name_ar: "الصف الثاني عشر — علمي", name_en: "Grade 12 (Science)", sort_order: 8,  is_visible: true, section: "scientific" },
    { grade_number: 12, name_ar: "الصف الثاني عشر — أدبي", name_en: "Grade 12 (Literary)", sort_order: 9,  is_visible: true, section: "literary" },
  ];

  for (const g of grades) {
    // Skip if already exists (idempotent)
    try {
      const existing = app.findRecordsByFilter("grades", `grade_number=${g.grade_number}`, "", 1, 0);
      // For grade 11/12 check by section too if field exists
      if (g.grade_number < 11 && existing.length > 0) continue;
    } catch(_) {}

    const record = new Record(col);
    record.set("grade_number", g.grade_number);
    record.set("name_ar",      g.name_ar);
    record.set("name_en",      g.name_en);
    record.set("sort_order",   g.sort_order);
    record.set("is_visible",   g.is_visible);
    try { app.save(record); } catch(_) {}
  }
}, (app) => {
  // Rollback: delete all seeded grades
  try {
    const col = app.findCollectionByNameOrId("grades");
    const records = app.findAllRecords("grades");
    for (const r of records) { try { app.delete(r); } catch(_) {} }
  } catch(_) {}
})
