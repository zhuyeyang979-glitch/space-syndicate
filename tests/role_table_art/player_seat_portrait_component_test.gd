extends SceneTree

const SeatScene := preload("res://scenes/ui/PlayerSeatPortrait.tscn")
const PreviewScene := preload("res://scenes/tools/RoleTablePortraitPreview.tscn")
const LayoutScript := preload("res://scripts/ui/planet_seat_layout.gd")
const CatalogScript := preload("res://scripts/presentation/role_portrait_catalog.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1600, 960)
	root.add_child(host)
	var seat := SeatScene.instantiate()
	host.add_child(seat)
	await process_frame
	_check(seat.get_node_or_null("VisualRoot/PortraitShadow") != null, "seat has PortraitShadow")
	_check(seat.get_node_or_null("VisualRoot/PortraitMask/PortraitTexture") != null, "seat has PortraitTexture in mask")
	_check(seat.get_node_or_null("VisualRoot/PortraitMask/MissingPortrait") != null, "seat has explicit MISSING PORTRAIT debug surface")
	_check(seat.get_node_or_null("VisualRoot/OrbitalSeatPod") != null, "seat has OrbitalSeatPod")
	_check(seat.get_node_or_null("VisualRoot/OrbitalSeatPod/PlayerColorStrip") != null, "seat has PlayerColorStrip")
	_check(seat.get_node_or_null("VisualRoot/OrbitalSeatPod/SeatNumber") != null, "seat has SeatNumber")
	_check(seat.get_node_or_null("VisualRoot/OrbitalSeatPod/PublicRoleLabel") != null, "seat has PublicRoleLabel")
	_check(seat.get_node_or_null("VisualRoot/OrbitalSeatPod/PublicStatusBadge") != null, "seat has PublicStatusBadge")
	_check(seat.get_node_or_null("HoverArea") != null, "seat has HoverArea")
	_check(seat.mouse_filter == Control.MOUSE_FILTER_IGNORE, "seat transparent root ignores map input")
	seat.apply_public_snapshot({
		"seat_number": 2,
		"role_name": "深海菌毯使团",
		"public_passive_summary": "公开摘要",
		"public_status": "normal",
		"is_public_actor": true,
		"anonymous_action_active": true,
		"cash": 999999,
		"hand_count": 5,
		"hidden_owner": 4,
		"ai_score": 91.2,
	})
	var public_debug: Dictionary = seat.get_public_debug_snapshot()
	_check(not bool(public_debug.get("public_actor_highlighted", true)), "anonymous action suppresses actor highlight")
	seat.apply_public_snapshot({
		"seat_number": 2,
		"role_name": "深海菌毯使团",
		"public_status": "public_actor",
		"is_public_actor": true,
		"anonymous_action_active": true,
	})
	_check(not seat.get_node("VisualRoot/OrbitalSeatPod/PublicStatusBadge").visible, "anonymous action suppresses public actor badge")
	seat.apply_layout_spec({
		"position": Vector2(100, 120),
		"size": Vector2(145, 190),
		"flip_horizontal": true,
	})
	_check(seat.position == Vector2(100, 120), "seat layout applies resolved top-left position")
	_check(seat.size == Vector2(220, 280), "seat retains stable authored size")
	_check(seat.scale.is_equal_approx(Vector2(145.0 / 220.0, 190.0 / 280.0)), "seat visual scales to resolved footprint")
	var serialized := JSON.stringify(public_debug)
	for forbidden in ["cash", "hand_count", "hidden_owner", "ai_score", "owner_truth"]:
		_check(not serialized.contains(forbidden), "public debug omits %s" % forbidden)
	for player_count in [3, 4, 5, 6, 7, 8]:
		var specs: Array[Dictionary] = LayoutScript.resolve(player_count, Vector2(1600, 960))
		_check(specs.size() == player_count, "%d player layout has exact seats" % player_count)
		_check(str(specs[0].get("slot_name", "")) == "left_low", "%d player layout keeps local player at left_low" % player_count)
		_check(bool(specs[0].get("local_player", false)), "%d player left_low seat is local" % player_count)
		var slots: Dictionary = {}
		for spec in specs:
			slots[str(spec.get("slot_name", ""))] = true
			_check(bool(spec.get("faces_planet", false)), "%d player seat faces planet" % player_count)
			var seat_position: Vector2 = spec.get("position", Vector2.ZERO)
			var seat_size: Vector2 = spec.get("size", Vector2.ZERO)
			_check(seat_position.x >= 0.0 and seat_position.y >= 0.0, "%d player seat begins inside viewport" % player_count)
			_check(seat_position.x + seat_size.x <= 1600.0 and seat_position.y + seat_size.y <= 960.0, "%d player seat ends inside viewport" % player_count)
		_check(slots.size() == player_count, "%d player layout has unique slots" % player_count)
	var catalog = CatalogScript.new()
	var fallback := catalog.portrait_texture("不存在但安全回退的角色", "front")
	_check(fallback != null, "missing manifest or role returns procedural fallback")
	_check(bool(fallback.get_meta("role_portrait_is_placeholder", false)), "missing fallback is explicitly marked as placeholder")
	var preview := PreviewScene.instantiate()
	host.add_child(preview)
	await process_frame
	preview.set_player_count(8)
	await process_frame
	var preview_debug: Dictionary = preview.debug_snapshot()
	_check(int(preview_debug.get("seat_count", 0)) == 8, "preview instantiates eight seats")
	_check(int(preview_debug.get("placeholder_count", -1)) == 0, "clean eight-seat preview uses actual portraits only")
	_check(preview.get_node_or_null("BackSeatLayer") != null, "preview has BackSeatLayer")
	_check(preview.get_node_or_null("PlanetLayer") != null, "preview has PlanetLayer")
	_check(preview.get_node_or_null("FrontSeatLayer") != null, "preview has FrontSeatLayer")
	var privacy: Dictionary = preview_debug.get("privacy", {})
	_check(not bool(privacy.get("opponent_hand_count_visible", true)), "preview hides opponent hand count")
	_check(not bool(privacy.get("opponent_cash_visible", true)), "preview hides opponent cash")
	_check(not bool(privacy.get("hidden_owner_visible", true)), "preview hides ownership truth")
	_finish()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("ROLE_TABLE_ART_TEST_FAIL: %s" % label)


func _finish() -> void:
	if _failures.is_empty():
		print("ROLE_TABLE_ART_TEST_PASS checks=%d" % _checks)
		quit(0)
		return
	print("ROLE_TABLE_ART_TEST_FAIL checks=%d failures=%d first=%s" % [_checks, _failures.size(), _failures[0]])
	quit(1)
