extends SceneTree

const DOCK_SCENE := "res://scenes/ui/table/PlayerCardDock.tscn"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1366, 768)
	var dock := (load(DOCK_SCENE) as PackedScene).instantiate() as SpaceSyndicatePlayerCardDock
	root.add_child(dock)
	dock.size = Vector2(1000, 300)
	await process_frame
	var normal_host := dock.get_node("DockMargin/DockRows/PoolColumns/NormalPool/NormalRows/NormalScroll/NormalHandCards") as HBoxContainer
	_expect(normal_host != null, "production normal-card host loads")
	if normal_host == null:
		_finish()
		return
	var first := dock.call("_create_card_node", &"normal_cards", "normal-a") as Control
	var second := dock.call("_create_card_node", &"normal_cards", "normal-b") as Control
	for pair in [[first, "normal-a"], [second, "normal-b"]]:
		var card := pair[0] as Control
		card.set_meta("player_card_dock_row", {
			"card_instance_id": str(pair[1]),
			"display_name": "测试牌",
			"rank": 1,
			"category_id": "经济",
			"play_state": "available",
			"game_action_offer": {},
		})
		normal_host.add_child(card)
	await process_frame
	dock.call("_refresh_card_node_cache")
	dock.call("_sync_card_rest_position", first)
	dock.call("_sync_card_rest_position", second)

	var debug := dock.debug_snapshot()
	_expect(is_equal_approx(float(debug.get("hover_scale", 0.0)), 1.08) \
		and is_equal_approx(float(debug.get("hover_lift_pixels", 0.0)), 28.0) \
		and int(debug.get("hover_duration_ms", 0)) == 120, "hover constants match the commercial interaction contract")
	_expect(is_equal_approx(float(debug.get("drag_deadzone_pixels", 0.0)), 8.0) \
		and int(debug.get("drag_lift_duration_ms", 0)) == 110 \
		and is_equal_approx(float(debug.get("drag_max_tilt_degrees", 0.0)), 4.0), "drag constants match the commercial interaction contract")

	var rest := first.position
	dock.call("_on_card_hovered", &"normal_cards", first)
	await create_timer(0.14).timeout
	_expect(first.scale.is_equal_approx(Vector2(1.08, 1.08)) \
		and first.position.y <= rest.y - 27.0, "mouse hover lifts and scales the real CardFace")
	dock.call("_on_card_unhovered", &"normal_cards", first)
	await create_timer(0.14).timeout
	_expect(first.scale.is_equal_approx(Vector2.ONE) and first.position.is_equal_approx(rest), "hover exit returns to the stable layout")

	dock.call("_on_card_focus_entered", &"normal_cards", first)
	await create_timer(0.14).timeout
	_expect(first.scale.x > 1.07 and bool((first.get_meta("card_interaction_state", {}) as Dictionary).get("hovered", false)), "keyboard or gamepad focus uses the same visible elevation")
	dock.call("_on_card_focus_exited", &"normal_cards", first)
	await create_timer(0.14).timeout

	var press := first.global_position + first.size * 0.5
	dock.call("_begin_pointer_interaction", &"normal_cards", first, press)
	dock.call("_update_pointer_interaction", press + Vector2(4.0, 0.0))
	_expect(not bool(first.get_meta("commercial_dragging", false)), "movement inside the eight-pixel deadzone does not start drag")
	dock.call("_update_pointer_interaction", second.global_position + second.size * 0.75)
	_expect(bool(first.get_meta("commercial_dragging", false)) \
		and absf(first.rotation) <= deg_to_rad(4.0) + 0.001, "drag starts after the deadzone and tilt stays bounded")
	dock.call("_finish_pointer_interaction", normal_host.get_global_rect().get_center())
	await process_frame
	_expect(int(dock.debug_snapshot().get("local_reorder_count", 0)) == 1, "valid in-pool drag records only a local presentation reorder")

	press = first.global_position + first.size * 0.5
	dock.call("_begin_pointer_interaction", &"normal_cards", first, press)
	dock.call("_update_pointer_interaction", press + Vector2(20.0, 0.0))
	dock.call("_finish_pointer_interaction", normal_host.get_global_rect().end + Vector2(200.0, 200.0))
	await process_frame
	_expect(int(dock.debug_snapshot().get("invalid_drag_bounce_count", 0)) == 1 \
		and not bool(first.get_meta("commercial_dragging", true)), "drop outside the local pool bounces without submitting an action")

	var source := FileAccess.get_file_as_string("res://scripts/ui/table/player_card_dock.gd")
	_expect(source.count("game_action_offer_requested.emit") == 1 \
		and not source.contains("RandomNumberGenerator.new(") \
		and not source.contains("FileAccess.open("), "interaction polish keeps one Action Spine emitter and owns no RNG or Save path")
	dock.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures.append(label)
		push_error("[FAIL] %s" % label)


func _finish() -> void:
	print("COMMERCIAL_PLAYER_CARD_DOCK_INTERACTION checks=%d failures=%d" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
