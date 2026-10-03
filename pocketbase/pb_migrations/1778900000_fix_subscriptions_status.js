/// <reference path="../pb_data/types.d.ts" />
// Migration: Rename sub_status → status in subscriptions, add firebase_uid index
migrate((app) => {
  const collection = app.findCollectionByNameOrId("subscriptions");
  if (!collection) return;

  // Find the sub_status field and rename it to status
  const fields = collection.fields;
  let changed = false;
  for (const f of fields) {
    if (f.name === "sub_status") {
      f.name = "status";
      changed = true;
    }
  }

  // Add firebase_uid index if missing
  const hasIdx = (collection.indexes || []).some(i =>
    typeof i === "string" ? i.includes("firebase_uid") : i.name?.includes("firebase_uid")
  );
  if (!hasIdx) {
    collection.indexes = [
      ...(collection.indexes || []),
      "CREATE INDEX idx_sub_firebase_uid ON subscriptions (firebase_uid)",
      "CREATE INDEX idx_sub_status ON subscriptions (status)",
    ];
  }

  if (changed) return app.save(collection);
}, (app) => {
  // Rollback: rename status back to sub_status
  const collection = app.findCollectionByNameOrId("subscriptions");
  if (!collection) return;
  for (const f of collection.fields) {
    if (f.name === "status") f.name = "sub_status";
  }
  return app.save(collection);
})
