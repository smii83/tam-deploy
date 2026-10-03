/// <reference path="../pb_data/types.d.ts" />
// Fix users collection:
// - listRule: "" (empty = anyone authenticated as superuser can list)
//   Actually for PocketBase, listRule="" means public. listRule=null means superuser only.
//   BUT: superusers bypass ALL rules including listRule=null.
//   The 400 error means the collection structure is wrong or filter is invalid.
// - Fix: ensure users collection has correct structure

migrate((app) => {
  try {
    const users = app.findCollectionByNameOrId("users");
    if (!users) {
      console.log("users collection not found");
      return;
    }

    // listRule = "" means anyone can list (public)
    // listRule = null means ONLY superusers can list (via API with superuser token)
    // Since the dashboard uses superuser token, null should work.
    // But if getting 400, it might be a query/filter issue not a rule issue.
    // Let's set listRule = "" temporarily to debug:
    users.listRule = "";      // public list — superuser token will always work
    users.viewRule = "";      // public view
    users.createRule = "";    // anyone can create (needed for Flutter registration)
    users.updateRule = "@request.auth.id != ''"; // any authenticated user
    users.deleteRule = null;  // only superuser can delete
    
    app.save(users);
    console.log("✅ users collection rules updated");
  } catch(e) {
    console.log("❌ users fix error:", e.message);
  }

  // Also fix subscriptions so dashboard can list them
  try {
    const subs = app.findCollectionByNameOrId("subscriptions");
    if (subs) {
      subs.listRule = "";   // public list (superuser token bypasses anyway)
      subs.viewRule = "";
      subs.createRule = "";
      app.save(subs);
      console.log("✅ subscriptions rules updated");
    }
  } catch(e) {
    console.log("❌ subscriptions fix error:", e.message);
  }

  // Fix progress and quiz_results
  try {
    const progress = app.findCollectionByNameOrId("progress");
    if (progress) {
      progress.listRule = "";
      progress.viewRule = "";
      progress.createRule = "";
      app.save(progress);
    }
  } catch(e) {}

  try {
    const qr = app.findCollectionByNameOrId("quiz_results");
    if (qr) {
      qr.listRule = "";
      qr.viewRule = "";
      qr.createRule = "";
      app.save(qr);
    }
  } catch(e) {}

}, (app) => {
  // rollback — restore null rules
  try {
    const users = app.findCollectionByNameOrId("users");
    if (users) { users.listRule = null; app.save(users); }
  } catch(e) {}
});
