extends SceneTree

const SkinScene := preload("res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn")

var checks := 0
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var skin := SkinScene.instantiate()
	root.add_child(skin)
	await process_frame
	var available: bool = skin.apply_public_view_model({
		"seat_index": 1,
		"player_display_name": "公开席位",
		"public_role_name": "星鲸餐饮垄断",
		"player_color": Color("#22d3ee"),
		"is_local_player": true,
		"is_publicly_active": true,
		"public_status": "public_actor",
		"inward_direction": "left",
		"depth_class": "mid",
		"cash": 999999,
		"hand": ["secret"],
		"owner_truth": "secret-owner",
	})
	_check(available and skin.visible, "rendered portrait enables the skin")
	_check(skin.get_combined_minimum_size().is_equal_approx(Vector2(132, 92)), "production portrait skin uses the compact 132x92 side-card frame")
	var public: Dictionary = skin.public_debug_snapshot()
	_check(public.get("owns_layout", true) == false, "skin owns no layout")
	_check(public.get("owns_player_mapping", true) == false, "skin owns no player mapping")
	_check(public.get("owns_input", true) == false, "skin owns no input")
	_check(int(public.get("mouse_filter", -1)) == Control.MOUSE_FILTER_IGNORE, "skin root ignores mouse input")
	_check(not JSON.stringify(public).contains("999999") and not JSON.stringify(public).contains("secret"), "private request fields do not leak")
	_check(not bool(public.get("flip_horizontal", true)), "left-side seat uses the authored inward-facing portrait")
	_check(bool(public.get("local_marker_visible", false)), "local seat uses the public 你 marker")
	_check(str((skin.get_node("VisualRoot/SeatPodFront/PublicStatusBadge") as Label).text).contains("你"), "local marker is visible in the compact status badge")
	skin.apply_public_view_model({
		"seat_index": 1,
		"player_display_name": "公开席位",
		"public_role_name": "星鲸餐饮垄断",
		"is_publicly_active": true,
		"anonymous_action_active": true,
		"public_status": "public_actor",
		"inward_direction": "right",
	})
	public = skin.public_debug_snapshot()
	_check(not bool(public.get("public_actor_highlighted", true)), "anonymous action suppresses actor highlight")
	_check(bool(public.get("flip_horizontal", false)), "right-side seat flips the authored inward-facing portrait")
	var pending_available: bool = skin.apply_public_view_model({
		"seat_index": 1,
		"public_role_name": "虹膜数据券商",
		"inward_direction": "front",
	})
	_check(not pending_available and not skin.visible, "pending portrait hides skin for legacy host fallback")
	var accepted := Array(skin.accepted_public_fields())
	for forbidden in ["cash", "hand", "owner_truth", "hidden_owner", "ai_plan"]:
		_check(not accepted.has(forbidden), "public field allowlist excludes %s" % forbidden)
	_check(not skin.has_method("apply_layout_spec") and not skin.has_method("set_player_count"), "skin exposes no seat algorithm API")
	_check(_all_controls_ignore_mouse(skin), "all decorative descendants ignore mouse input")
	skin.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYER_SEAT_PORTRAIT_SKIN_TEST PASS checks=%d failures=0" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("PLAYER_SEAT_PORTRAIT_SKIN_TEST FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)


func _all_controls_ignore_mouse(node: Node) -> bool:
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child in node.get_children():
		if not _all_controls_ignore_mouse(child):
			return false
	return true


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
