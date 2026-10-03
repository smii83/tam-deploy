/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3754236674")

  // Update password field to be hidden
  collection.fields.removeById("text_password")
  collection.fields.addAt(11, new Field({
    "hidden": true,
    "id": "text_password",
    "name": "password",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3754236674")

  // Revert password field to not be hidden
  collection.fields.removeById("text_password")
  collection.fields.addAt(11, new Field({
    "hidden": false,
    "id": "text_password",
    "name": "password",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  return app.save(collection)
})
