extends Node

const VALIDATOR := preload("res://scripts/validators/character_schema_validator.gd").new()

# Small migration utility to sanitize existing characters and move irreparable entries to a graveyard folder
func migrate_characters() -> void:
	var path = "res://data/characters/characters.json"
	var abs_path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		Log.info("Character migration: no central characters file to migrate")
		return

	var f = FileAccess.open(abs_path, FileAccess.READ)
	if not f:
		Log.error("Character migration: failed to open characters file")
		return
	var j = JSON.new()
	if j.parse(f.get_as_text()) != OK:
		Log.error("Character migration: invalid JSON in characters file")
		return
	var data = j.data
	if typeof(data) != TYPE_DICTIONARY:
		Log.error("Character migration: unexpected data format")
		return

	var migrated: Dictionary = {}
	for k in data.keys():
		var c = data[k]
		var res = VALIDATOR.validate(c)
		if res["ok"]:
			migrated[k] = res.has("sanitized") and res["sanitized"] or c
		else:
			# Attempt a light sanitize
			var repaired = VALIDATOR.sanitize(c)
			# If still missing required fields, move to graveyard file
			if not repaired.has("id") or not repaired.has("name"):
				var out_dir = "res://data/characters/graveyard/invalid/"
				var abs_out = ProjectSettings.globalize_path(out_dir)
				if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://data/characters/graveyard/")):
					DirAccess.make_dir_absolute(ProjectSettings.globalize_path("res://data/characters/graveyard/"))
				if not DirAccess.dir_exists_absolute(abs_out):
					DirAccess.make_dir_absolute(abs_out)
				var fn = abs_out.path_join("invalid_%s.json" % k)
				var fw = FileAccess.open(fn, FileAccess.WRITE)
				if fw:
					fw.store_string(JSON.stringify(c, "\t"))
					fw.close()
				Log.error("Character migration: moved invalid character %s to graveyard" % k)
			else:
				migrated[k] = repaired

	# Persist migrated set
	var fw_all = FileAccess.open(abs_path, FileAccess.WRITE)
	if fw_all:
		fw_all.store_string(JSON.stringify(migrated, "\t"))
		fw_all.close()
	Log.info("Character migration: completed, %d entries processed" % migrated.size())
