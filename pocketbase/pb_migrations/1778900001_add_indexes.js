/// <reference path="../pb_data/types.d.ts" />
// Migration: add indexes to users (firebase_uid), grades, subjects, lessons, progress collections
migrate((app) => {
  // users — index on firebase_uid for fast lookup
  try {
    const users = app.findCollectionByNameOrId("users");
    if (users) {
      users.indexes = [
        ...(users.indexes || []),
        "CREATE UNIQUE INDEX idx_users_firebase_uid ON users (firebase_uid)",
        "CREATE INDEX idx_users_grade ON users (grade)",
      ];
      app.save(users);
    }
  } catch(_) {}

  // grades — index on grade_number
  try {
    const grades = app.findCollectionByNameOrId("grades");
    if (grades) {
      grades.indexes = [
        ...(grades.indexes || []),
        "CREATE UNIQUE INDEX idx_grades_number ON grades (grade_number)",
      ];
      app.save(grades);
    }
  } catch(_) {}

  // subjects — composite index on grade_id + sort_order
  try {
    const subjects = app.findCollectionByNameOrId("subjects");
    if (subjects) {
      subjects.indexes = [
        ...(subjects.indexes || []),
        "CREATE INDEX idx_subjects_grade ON subjects (grade_id, sort_order)",
      ];
      app.save(subjects);
    }
  } catch(_) {}

  // lessons — index on subject_id + sort_order
  try {
    const lessons = app.findCollectionByNameOrId("lessons");
    if (lessons) {
      lessons.indexes = [
        ...(lessons.indexes || []),
        "CREATE INDEX idx_lessons_subject ON lessons (subject_id, sort_order)",
      ];
      app.save(lessons);
    }
  } catch(_) {}

  // progress — composite index
  try {
    const progress = app.findCollectionByNameOrId("progress");
    if (progress) {
      progress.indexes = [
        ...(progress.indexes || []),
        "CREATE INDEX idx_progress_uid ON progress (firebase_uid)",
        "CREATE UNIQUE INDEX idx_progress_uid_lesson ON progress (firebase_uid, lesson_id)",
      ];
      app.save(progress);
    }
  } catch(_) {}

  // pdfs — index on subject
  try {
    const pdfs = app.findCollectionByNameOrId("pdfs");
    if (pdfs) {
      pdfs.indexes = [
        ...(pdfs.indexes || []),
        "CREATE INDEX idx_pdfs_subject ON pdfs (subject, is_active)",
      ];
      app.save(pdfs);
    }
  } catch(_) {}

}, (app) => {
  // No rollback needed for index additions
})
