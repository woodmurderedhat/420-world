extends SceneTree

func _init() -> void:
    call_deferred("run_test")

func run_test() -> void:
    var bpr = null
    if Engine.has_singleton("BodyPartRegistry"):
        bpr = Engine.get_singleton("BodyPartRegistry")
    else:
        var bpr_script = load("res://scripts/body_part_registry.gd")
        bpr = bpr_script.new()
        add_child(bpr)
    bpr.load_all_parts()
    var types = ["head","eyes","mouth","hair","body","arms","hands","legs","feet"]
    var ok: bool = true

    for t in types:
        var parts = bpr.get_parts(t)
        if parts.empty():
            print("WARN: no parts for %s" % t)
            ok = false
            continue
        for p in parts:
            if not p.has("full_path"):
                print("ERR: missing full_path for %s" % p.get("id","<no-id>"))
                ok = false
                continue
            var path = p["full_path"]
            if not ResourceLoader.exists(path):
                print("ERR: resource missing: %s" % path)
                ok = false
            else:
                var tex = bpr.get_part_texture(p.get("id",""))
                if tex == null:
                    print("ERR: texture load failed for %s" % p.get("id",""))
                    ok = false

    # Attempt to render a sample character using the first available parts
    var sample: Dictionary = {}
    for t in types:
        var parts = bpr.get_parts(t)
        if parts.size() > 0:
            sample[t] = parts[0].get("id", "")

    var cr_script = load("res://scripts/character_renderer.gd")
    var out_tex = cr_script.render_character(sample)
    if out_tex == null:
        print("ERR: CharacterRenderer returned null")
        ok = false
    else:
        print("OK: Rendered character texture")

    if ok:
        print("PASS: bodypart UI check")
        var f = FileAccess.open("user://test_bodypart_result.txt", FileAccess.WRITE)
        if f:
            f.store_string("PASS")
            f.close()
        quit()
    else:
        print("FAIL: bodypart UI check")
        var f = FileAccess.open("user://test_bodypart_result.txt", FileAccess.WRITE)
        if f:
            f.store_string("FAIL")
            f.close()
        quit(1)
