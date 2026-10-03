/// <reference path="../pb_data/types.d.ts" />
// Remove unique index on grades.grade_number to allow multiple sections per grade
migrate((app) => {
  const col = app.findCollectionByNameOrId("grades");
  if (!col) return;

  // Remove all indexes that might be unique on grade_number
  col.indexes = (col.indexes || []).filter(idx => {
    const s = typeof idx === 'string' ? idx : '';
    return !s.includes('grade_number');
  });

  return app.save(col);
}, (app) => {
  // No rollback needed
})
