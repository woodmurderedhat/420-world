extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	# Ensure clean slate
	CharacterManager.clear_all_characters()
	InventoryManager.slots.clear()
	InventoryManager.containers.clear()

	var logic := CharacterCreatorLogic.new()
	var body_parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	var stats = logic.default_stats()
	var create_ok = logic.create_character_from_data("GraveTester","Test", body_parts, stats)
	if not create_ok["ok"]:
		print("Graveyard test failed: couldn't create character: %s" % create_ok.get("error",""))
		quit(1)

	# Find created character id
	var chars = CharacterManager.get_all_characters()
	if chars.size() == 0:
		print("Graveyard test failed: no characters found after create")
		quit(1)
	var cid = chars[0].get("id")

	# Ensure Inventory has the character item
	var before_count = InventoryManager.count_item(cid)
	if before_count == 0:
		print("Graveyard test failed: character item not in inventory before delete")
		quit(1)

	# Soft-delete
	CharacterManager.soft_delete_character(cid)
	if not CharacterManager.characters[cid].get("deleted", false):
		print("Graveyard test failed: character not marked deleted")
		quit(1)

	# Graveyard should have at least one entry
	if CharacterManager.get_graveyard().size() == 0:
		print("Graveyard test failed: graveyard not appended")
		quit(1)

	# Inventory should have removed the item
	var after_count = InventoryManager.count_item(cid)
	if after_count != 0:
		print("Graveyard test failed: character item still present after delete")
		quit(1)

	# Test archive cleanup: create another and mark archived
	var res2 = logic.create_character_from_data("ArchiveMe","Test", body_parts, stats)
	if not res2["ok"]:
		print("Graveyard test failed: couldn't create archive candidate")
		quit(1)
	var new_c = CharacterManager.get_all_characters()[0]
	var new_id = new_c.get("id")
	CharacterManager.characters[new_id]["_archived"] = true
	CharacterManager._save_all_characters()

	# Run cleanup
	CharacterManager.cleanup_player_created_characters()
	if CharacterManager.characters.has(new_id):
		print("Graveyard test failed: archived character not removed by cleanup")
		quit(1)

	# Test purge container policy: when enabled, container should be deleted on soft-delete
	CharacterManager.purge_containers_on_delete = true
	var res3 = logic.create_character_from_data("PurgeMe","Test", body_parts, stats)
	if not res3["ok"]:
		print("Graveyard test failed: couldn't create purge candidate")
		quit(1)
	var p_id = CharacterManager.get_all_characters()[0].get("id")
	# ensure container exists
	if InventoryManager.get_container_slots(p_id).size() == 0:
		print("Graveyard test failed: container not created for purge candidate")
		quit(1)
	CharacterManager.soft_delete_character(p_id)
	if InventoryManager.get_container_slots(p_id).size() != 0:
		print("Graveyard test failed: container not purged when policy enabled")
		quit(1)
	# reset policy
	CharacterManager.purge_containers_on_delete = false
	print("Graveyard tests passed")
	quit(0)
