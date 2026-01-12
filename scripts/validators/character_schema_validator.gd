extends Node
class_name CharacterSchemaValidator

const ALLOWED_BODY_PARTS: Array = ["head","eyes","mouth","hair","body","arms","hands","legs","feet"]
const KNOWN_STATS: Array = ["gold","agility","strength","intelligence","constitution","luck"]

# Return default stats used across the app
func default_stats() -> Dictionary:
	return {"gold": 5, "agility": 5, "strength": 5, "intelligence": 5, "constitution": 5, "luck": 5}

# Validate a single character dictionary and return { ok: bool, errors: Array, sanitized: Dictionary (optional) }
func validate(character: Dictionary) -> Dictionary:
	var errors: Array = []
	var sanitized := {}
	if typeof(character) != TYPE_DICTIONARY:
		errors.append("character is not a Dictionary")
		return {"ok": false, "errors": errors}
	# id
	if not character.has("id") or typeof(character["id"]) != TYPE_STRING or character["id"].strip_edges() == "":
		errors.append("missing or invalid 'id'")
	# name
	if not character.has("name") or typeof(character["name"]) != TYPE_STRING or character["name"].strip_edges() == "":
		errors.append("missing or invalid 'name'")
	# body_parts
	if not character.has("body_parts") or typeof(character["body_parts"]) != TYPE_DICTIONARY:
		errors.append("missing or invalid 'body_parts'")
	else:
		for k in character["body_parts"].keys():
			if ALLOWED_BODY_PARTS.find(k) == -1:
				errors.append("unknown body part slot: %s" % k)
				continue
			var v = character["body_parts"][k]
			if typeof(v) != TYPE_STRING or v.strip_edges() == "":
				errors.append("invalid body part id for %s" % k)

	# stats
	if not character.has("stats") or typeof(character["stats"]) != TYPE_DICTIONARY:
		errors.append("missing or invalid 'stats'")
	else:
		# copy stats and attempt to coerce numeric string values
		var sdict = {}
		for sk in character["stats"].keys():
			var sval = character["stats"][sk]
			if typeof(sval) == TYPE_STRING:
				if _is_int_like(sval):
					sval = int(sval)
				else:
					errors.append("stat '%s' not an integer" % sk)
			if typeof(sval) != TYPE_INT:
				# Allow integers only (no floats)
				errors.append("stat '%s' must be integer" % sk)
			else:
				# Known stat-specific checks
				if KNOWN_STATS.find(sk) != -1:
					if sk == "gold":
						if sval < 0:
							errors.append("stat 'gold' must be >= 0")
					else:
						if sval < 1 or sval > 99:
							errors.append("stat '%s' must be 1..99" % sk)
				sdict[sk] = sval
		# missing known stats will be filled in sanitize

	# inventory_capacity
	if character.has("inventory_capacity"):
		if typeof(character["inventory_capacity"]) != TYPE_INT or character["inventory_capacity"] < 0:
			errors.append("invalid 'inventory_capacity' (must be integer >=0)")

	# Build sanitized if possible
	var sanitized_ok = true
	if errors.size() == 0:
		sanitized = character.duplicate(true)
		# ensure missing known stats are present
		if not sanitized.has("stats"):
			sanitized["stats"] = default_stats()
		else:
			for sk in KNOWN_STATS:
				if not sanitized["stats"].has(sk):
					sanitized["stats"][sk] = default_stats()[sk]
		# ensure inventory_capacity
		if not sanitized.has("inventory_capacity"):
			sanitized["inventory_capacity"] = 10
	else:
		# Do not produce a sanitized result when errors exist
		pass

	var ok = errors.size() == 0
	if ok:
		return {"ok": true, "errors": errors, "sanitized": sanitized}
	else:
		return {"ok": false, "errors": errors}

# Validate a map of id -> character dictionaries
func validate_all(char_map: Dictionary) -> Dictionary:
	var valid: Dictionary = {}
	var invalid: Dictionary = {}
	for k in char_map.keys():
		var res = validate(char_map[k])
		if res["ok"]:
			valid[k] = res["sanitized"]
		else:
			invalid[k] = res["errors"]
	return {"valid": valid, "invalid": invalid}

# Return a best-effort sanitized character (fills defaults and coerces when possible)
func sanitize(character: Dictionary) -> Dictionary:
	var res = validate(character)
	if res.has("sanitized") and res["sanitized"] != null:
		return res["sanitized"]
	# If validation failed but we can coerce some fields, attempt light repair
	var repaired = character.duplicate(true)
	# Ensure stats dict exists
	if not repaired.has("stats") or typeof(repaired["stats"]) != TYPE_DICTIONARY:
		repaired["stats"] = default_stats()
	else:
		for sk in KNOWN_STATS:
			if not repaired["stats"].has(sk):
				repaired["stats"][sk] = default_stats()[sk]
			else:
				var v = repaired["stats"][sk]
				if typeof(v) == TYPE_STRING and _is_int_like(v):
					repaired["stats"][sk] = int(v)
	# inventory default
	if not repaired.has("inventory_capacity"):
		repaired["inventory_capacity"] = 10
	return repaired

# Helper: simple integer string checker
func _is_int_like(s: String) -> bool:
	if s == null: return false
	var rx := RegEx.new()
	rx.compile("^[0-9]+$")
	return rx.search(s) != null
