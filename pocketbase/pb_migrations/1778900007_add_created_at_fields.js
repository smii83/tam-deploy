/// <reference path="../pb_data/types.d.ts" />
// Add 'created_at' auto-date field to users and subscriptions collections
// so the dashboard can sort by date correctly
// Note: PocketBase base collections don't auto-add 'created'/'updated' like auth collections
migrate((app) => {
  
  // Add created_at field to users
  try {
    const users = app.findCollectionByNameOrId("users");
    if (!users) { console.log("users not found"); return; }
    
    // Check if 'created_at' already exists
    const existingField = users.fields.getByName("created_at");
    if (existingField) {
      console.log("created_at already exists in users");
    } else {
      // Add auto-date field
      const dateField = new AutodateField({
        id: "autodate_users_created",
        name: "created_at",
        onCreate: true,
        onUpdate: false,
      });
      users.fields.add(dateField);
      app.save(users);
      console.log("✅ Added created_at to users");
    }
  } catch(e) {
    console.log("❌ users created_at error:", e.message);
  }

  // Add created_at field to subscriptions
  try {
    const subs = app.findCollectionByNameOrId("subscriptions");
    if (!subs) { console.log("subscriptions not found"); return; }
    
    const existingField = subs.fields.getByName("created_at");
    if (existingField) {
      console.log("created_at already exists in subscriptions");
    } else {
      const dateField = new AutodateField({
        id: "autodate_subs_created",
        name: "created_at",
        onCreate: true,
        onUpdate: false,
      });
      subs.fields.add(dateField);
      app.save(subs);
      console.log("✅ Added created_at to subscriptions");
    }
  } catch(e) {
    console.log("❌ subscriptions created_at error:", e.message);
  }

}, (app) => {
  // rollback
  try {
    const users = app.findCollectionByNameOrId("users");
    if (users) {
      const f = users.fields.getByName("created_at");
      if (f) { users.fields.remove(f); app.save(users); }
    }
  } catch(e) {}
  try {
    const subs = app.findCollectionByNameOrId("subscriptions");
    if (subs) {
      const f = subs.fields.getByName("created_at");
      if (f) { subs.fields.remove(f); app.save(subs); }
    }
  } catch(e) {}
});
