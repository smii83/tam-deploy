/// <reference path="../pb_data/types.d.ts" />
// Fix pdfs indexes (wrong column name: subject → subject_id)
// And add file_data field for PDF file storage
migrate((app) => {
  const pdfs = app.findCollectionByNameOrId("pdfs");
  if (!pdfs) return;

  // Remove the wrong index on "subject" (doesn't exist) and replace with correct one
  pdfs.indexes = (pdfs.indexes || []).filter(idx => !idx.includes("idx_pdfs_subject"));
  pdfs.indexes.push("CREATE INDEX idx_pdfs_subject_id ON pdfs (subject_id, is_active)");

  // Add file_data field if not already present
  const existing = pdfs.fields.getByName("file_data");
  if (!existing) {
    pdfs.fields.push(new FileField({
      "id": "file_data_001",
      "maxSelect": 1,
      "maxSize": 52428800,
      "mimeTypes": ["application/pdf"],
      "name": "file_data",
      "presentable": true,
      "protected": false,
      "required": false,
      "system": false,
      "thumbs": []
    }));
  }

  return app.save(pdfs);
}, (app) => {
  // rollback: remove idx_pdfs_subject_id and file_data
  const pdfs = app.findCollectionByNameOrId("pdfs");
  if (!pdfs) return;
  pdfs.indexes = (pdfs.indexes || []).filter(idx => !idx.includes("idx_pdfs_subject_id"));
  const field = pdfs.fields.getByName("file_data");
  if (field) pdfs.fields.remove(field);
  app.save(pdfs);
});
