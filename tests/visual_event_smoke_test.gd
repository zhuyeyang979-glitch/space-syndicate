extends SceneTree

const VISUAL_LAYER_SCENE := "res://scenes/ui/VisualEventLayer.tscn"
const TARGETING_SCENE := "res://scenes/ui/TargetingOverlay.tscn"
const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/visual_event_snapshot.gd")
const AUDIO_REGISTRY_SCRIPT := preload("res://scripts/audio/audio_event_registry.gd")
const AUDIO_BUS_SCRIPT := preload("res://scripts/audio/audio_event_bus.gd")
const MONSTER_PRESENTER := preload("res://scripts/ui/monster_event_presenter.gd")
const ROUTE_PRESENTER := preload("res://scripts/ui/route_event_presenter.gd")

const EXPECTED_LAYER_LIMIT := 32

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_expect(ResourceLoader.exists(VISUAL_LAYER_SCENE), "VisualEventLayer production scene exists")
	_expect(ResourceLoader.exists(TARGETING_SCENE), "TargetingOverlay scene exists")
	var visual_packed := load(VISUAL_LAYER_SCENE) as PackedScene
	_expect(visual_packed != null, "VisualEventLayer production scene parse-loads")
	if visual_packed == null:
		_finish()
		return
	var visual_layer := visual_packed.instantiate() as Control
	_expect(visual_layer != null and visual_layer.has_method("set_visual_events") and visual_layer.has_method("get_visual_event_snapshot"), "VisualEventLayer exposes the production visual-event API")
	if visual_layer == null:
		_finish()
		return
	root.add_child(visual_layer)
	await process_frame

	var public_events := _public_visual_events(40)
	var fixture_leaks: Array[String] = []
	_scan_privacy(public_events, "fixture", fixture_leaks)
	_expect(fixture_leaks.is_empty(), "public visual fixture contains no private player/AI fields")
	var normalized_events: Array = SNAPSHOT_SCRIPT.normalize_events(public_events)
	visual_layer.call("set_visual_events", normalized_events, true)
	await process_frame
	var snapshot := visual_layer.call("get_visual_event_snapshot") as Dictionary
	var events: Array = snapshot.get("events", []) as Array
	var classes: Array = snapshot.get("event_classes", []) as Array
	_expect(int(snapshot.get("max_events", -1)) == EXPECTED_LAYER_LIMIT and events.size() == EXPECTED_LAYER_LIMIT, "production layer caps active events at 32")
	_expect(bool(snapshot.get("reduced_motion", false)) and _all_reduced_motion(events), "reduced motion propagates through the production snapshot")
	for required_class in ["card_play", "card_reveal", "monster_attack", "cash_gain", "gdp_delta", "route_damage"]:
		_expect(classes.has(required_class), "active layer keeps %s visual class" % required_class)
	_expect(classes.has("target_arrow") and _has_label_fragment(events, "天气"), "weather-origin public event uses the current safe target-arrow fallback")
	_expect(visual_layer.visible and visual_layer.is_visible_in_tree() and visual_layer.size.x > 0.0 and visual_layer.size.y > 0.0, "active layer has non-zero visible geometry")
	_expect(_visible_label_geometry(visual_layer), "active event labels have non-zero visible geometry")

	var first_signature := JSON.stringify(snapshot)
	var first_label_count := visual_layer.get_child_count()
	visual_layer.call("set_visual_events", normalized_events, true)
	await process_frame
	var replay_snapshot := visual_layer.call("get_visual_event_snapshot") as Dictionary
	_expect(JSON.stringify(replay_snapshot) == first_signature, "repeating the same snapshot is deterministic")
	_expect(visual_layer.get_child_count() == first_label_count and (replay_snapshot.get("events", []) as Array).size() == EXPECTED_LAYER_LIMIT, "repeated refresh does not accumulate labels or events")

	var expiring_event := SNAPSHOT_SCRIPT.normalize_event({
		"type": "card_reveal_flash",
		"at": Vector2(640, 300),
		"label": "短暂公开",
		"duration": 0.1,
	})
	visual_layer.call("set_visual_events", [expiring_event], false)
	await process_frame
	_expect(is_equal_approx(float(((visual_layer.call("get_visual_event_snapshot") as Dictionary).get("events", []) as Array)[0].get("duration", 0.0)), 0.1), "active layer preserves upstream expiry duration")
	# Expiry is owned by the upstream snapshot producer. The active layer replaces
	# its state when that producer sends the post-expiry empty snapshot.
	visual_layer.call("set_visual_events", [], false)
	await process_frame
	_expect(((visual_layer.call("get_visual_event_snapshot") as Dictionary).get("events", []) as Array).is_empty() and visual_layer.get_child_count() == 0, "post-expiry empty snapshot clears active visuals")
	visual_layer.call("set_visual_events", normalized_events, false)
	await process_frame
	visual_layer.call("clear_events")
	await process_frame
	_expect(((visual_layer.call("get_visual_event_snapshot") as Dictionary).get("events", []) as Array).is_empty() and visual_layer.get_child_count() == 0, "explicit production clear API removes events and labels")

	var snapshot_leaks: Array[String] = []
	_scan_privacy(snapshot, "snapshot", snapshot_leaks)
	_expect(snapshot_leaks.is_empty(), "public VisualEventLayer snapshot recursively contains no private fields")

	await _check_existing_targeting_and_audio_smoke()
	var source_bundle := "\n".join([
		FileAccess.get_file_as_string("res://scripts/ui/visual_event_layer.gd"),
		FileAccess.get_file_as_string("res://scripts/viewmodels/visual_event_snapshot.gd"),
		FileAccess.get_file_as_string("res://scripts/ui/targeting_overlay.gd"),
	])
	for forbidden in ["_use_skill", "_claim_district_card", "_build_city", "opponent_private", "true_owner", "hidden_owner", "owner_truth"]:
		_expect(not source_bundle.contains(forbidden), "active visual path stays presentation-only and hidden-info safe (%s)" % forbidden)

	root.remove_child(visual_layer)
	visual_layer.queue_free()
	await process_frame
	_finish()


func _public_visual_events(count: int) -> Array:
	var base: Array = [
		{"type": "card_play_flyout", "from": Vector2(600, 650), "to": Vector2(620, 310), "at": Vector2(620, 310), "label": "公开出牌", "progress": 0.5},
		{"type": "card_reveal_flash", "at": Vector2(520, 115), "label": "卡牌公开"},
		MONSTER_PRESENTER.monster_attack(Vector2(560, 360), Vector2(760, 390), 12),
		{"type": "cash_gain_float", "at": Vector2(850, 440), "label": "+120"},
		{"type": "gdp_delta_float", "at": Vector2(900, 410), "label": "+6 GDP"},
		ROUTE_PRESENTER.route_damage(Vector2(460, 420), Vector2(800, 480)),
		# No first-class weather type exists in the active snapshot contract. A
		# public weather-origin cue therefore takes its documented safe fallback.
		{"type": "weather_pressure", "from": Vector2(380, 210), "to": Vector2(940, 210), "label": "天气预警", "duration": 1.2},
	]
	var result: Array = []
	for index in range(count):
		var event := (base[index % base.size()] as Dictionary).duplicate(true)
		event["label"] = "%s %02d" % [str(event.get("label", "事件")), index]
		result.append(event)
	return result


func _all_reduced_motion(events: Array) -> bool:
	if events.is_empty():
		return false
	for event_variant: Variant in events:
		if not (event_variant is Dictionary) or not bool((event_variant as Dictionary).get("reduced_motion", false)):
			return false
	return true


func _has_label_fragment(events: Array, fragment: String) -> bool:
	for event_variant: Variant in events:
		if event_variant is Dictionary and str((event_variant as Dictionary).get("label", "")).contains(fragment):
			return true
	return false


func _visible_label_geometry(layer: Control) -> bool:
	for child_variant: Variant in layer.get_children():
		var label := child_variant as Label
		if label != null and label.visible and label.is_visible_in_tree() and label.size.x > 0.0 and label.size.y > 0.0:
			return true
	return false


func _scan_privacy(value: Variant, path: String, leaks: Array[String]) -> void:
	var forbidden_keys := [
		"true_owner", "hidden_owner", "owner_truth", "exact_cash", "cash_after",
		"hand", "hand_count", "discard", "discard_count", "ai_plan", "ai_private_plan",
		"ai_score", "ai_private_score", "private_route_plan",
	]
	if value is Dictionary:
		for key_variant: Variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			var child_path := "%s.%s" % [path, key]
			if forbidden_keys.has(key):
				leaks.append(child_path)
			_scan_privacy((value as Dictionary).get(key_variant), child_path, leaks)
	elif value is Array:
		for index in range((value as Array).size()):
			_scan_privacy((value as Array)[index], "%s[%d]" % [path, index], leaks)


func _check_existing_targeting_and_audio_smoke() -> void:
	var targeting_packed := load(TARGETING_SCENE) as PackedScene
	var targeting := targeting_packed.instantiate() as Control
	root.add_child(targeting)
	targeting.call("set_targeting", Vector2(760, 620), Vector2(700, 430), false, "不能出牌", "冷却中")
	await process_frame
	_expect(bool(targeting.call("is_targeting_active")), "TargetingOverlay still renders invalid target state")

	var registry: Variant = AUDIO_REGISTRY_SCRIPT.new()
	registry.call("load_default")
	for hook in ["card_play", "card_reveal", "monster_attack", "route_damage", "cash_gain", "gdp_delta", "final_countdown"]:
		_expect(bool(registry.call("has_event", hook)), "AudioEventRegistry keeps hook %s" % hook)
	var bus: Node = AUDIO_BUS_SCRIPT.new()
	root.add_child(bus)
	await process_frame
	bus.call("emit_audio_event", "monster_attack", {"source": "visual_event_smoke"})
	_expect(str(bus.call("last_event_id")) == "monster_attack", "AudioEventBus records silent monster_attack hook")

	root.remove_child(targeting)
	targeting.queue_free()
	root.remove_child(bus)
	bus.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("VISUAL_EVENT_SMOKE_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("VISUAL_EVENT_SMOKE_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	if not _failures.is_empty():
		print("VISUAL_EVENT_SMOKE_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
