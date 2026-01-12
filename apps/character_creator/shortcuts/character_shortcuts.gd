extends Node

# Callbacks to be set by controller (allow null until controller wires them)
var on_open_new = null
var on_delete_callback = null
var on_select_callback = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 'N' to open New Character tab
		if event.keycode == Key.KEY_N:
			if on_open_new != null:
				on_open_new.call()
				DialogManager.show_toast("New Character (N)")
		# Delete with Delete key
		elif event.keycode == Key.KEY_DELETE:
			# find focused card
			var focused = UIHelpers.get_focus_owner()
			var target = focused
			# Allow the shortcuts scene to be reused outside the specific node path by trying a local grid first
			if target == null:
				var grid = get_node_or_null("GalleryGrid/GalleryVBox")
				if grid == null:
					grid = get_node_or_null("GalleryVBox")
				if grid != null:
					for ch in grid.get_children():
						if ch.name.begins_with("char_card_"):
							if (ch.has_method("is_focused") and ch.is_focused()) or (ch.has_method("has_focus") and ch.has_focus()):
								target = ch
								break
			if target != null and target.name.begins_with("char_card_"):
				var cid = target.name.replace("char_card_", "")
				DialogManager.show_confirm("Delete Character?", "Delete %s? This is permanent." % CharacterManager.get_character(cid).get("name", ""), func(confirmed):
					if confirmed:
						CharacterManager.soft_delete_character(cid)
						if on_delete_callback != null:
							on_delete_callback.call(cid)
						DialogManager.show_toast("Moved %s to Graveyard" % CharacterManager.get_character(cid).get("name", ""))
				)
		# Navigation and Enter selection handled by UI or other components; keep minimal here
		elif event.keycode == Key.KEY_ENTER or event.keycode == Key.KEY_KP_ENTER:
			if on_select_callback != null:
				on_select_callback.call()