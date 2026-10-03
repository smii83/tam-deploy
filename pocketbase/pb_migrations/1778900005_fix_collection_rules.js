/// <reference path="../pb_data/types.d.ts" />
// Fix users collection listRule — allow superuser tokens to list users
// Also ensure subjects, lessons, pdfs are readable without auth (for Flutter app)
migrate((app) => {
  
  // Fix users collection — listRule null means only superusers can access
  // This is correct for superuser dashboard, but let's confirm it's properly set
  try {
    const users = app.findCollectionByNameOrId("users");
    if (users) {
      // Keep listRule as null — superusers should always have access
      // But add createRule to allow creating user records
      users.createRule = "";  // anyone can create (for registration)
      users.viewRule = "@request.auth.id != '' || @request.headers.authorization != ''";
      app.save(users);
    }
  } catch(e) { console.log("users fix error:", e.message); }

  // Fix subjects listRule to allow Flutter app to read without auth
  try {
    const subjects = app.findCollectionByNameOrId("subjects");
    if (subjects) {
      subjects.listRule = "";  // public read
      subjects.viewRule = "";  // public read
      app.save(subjects);
    }
  } catch(e) { console.log("subjects fix error:", e.message); }

  // Fix grades listRule to allow Flutter app to read without auth
  try {
    const grades = app.findCollectionByNameOrId("grades");
    if (grades) {
      grades.listRule = "";  // public read
      grades.viewRule = "";  // public read
      app.save(grades);
    }
  } catch(e) { console.log("grades fix error:", e.message); }

  // Fix lessons listRule
  try {
    const lessons = app.findCollectionByNameOrId("lessons");
    if (lessons) {
      lessons.listRule = "";
      lessons.viewRule = "";
      app.save(lessons);
    }
  } catch(e) { console.log("lessons fix error:", e.message); }

  // Fix pdfs listRule
  try {
    const pdfs = app.findCollectionByNameOrId("pdfs");
    if (pdfs) {
      pdfs.listRule = "";
      pdfs.viewRule = "";
      app.save(pdfs);
    }
  } catch(e) { console.log("pdfs fix error:", e.message); }

  // Fix subscriptions — only admins should list
  // Keep subscriptions.listRule = null (superuser only)

}, (app) => {
  // No rollback needed
});
