/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  try {
    const pdfs = app.findCollectionByNameOrId("pdfs")
    if (pdfs) {
      // Filter out the old/incorrect index if present, and add the correct one
      const indexes = (pdfs.indexes || []).filter(idx => !idx.includes("idx_pdfs_subject"));
      pdfs.indexes = [
        ...indexes,
        "CREATE INDEX idx_pdfs_subject_id ON pdfs (subject_id, is_active)"
      ];
      app.save(pdfs);
      console.log("✅ Fixed PDFs index to use subject_id");
    }
  } catch(e) {
    console.log("❌ Error updating pdfs index:", e.message);
  }
}, (app) => {
  // Revert
  try {
    const pdfs = app.findCollectionByNameOrId("pdfs")
    if (pdfs) {
      const indexes = (pdfs.indexes || []).filter(idx => !idx.includes("idx_pdfs_subject_id"));
      pdfs.indexes = [
        ...indexes,
        "CREATE INDEX idx_pdfs_subject ON pdfs (subject, is_active)"
      ];
      app.save(pdfs);
    }
  } catch(e) {}
})
