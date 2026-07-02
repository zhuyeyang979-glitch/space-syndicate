extends SceneTree

const VISUAL_LAYER_SCENE := "res://scenes/ui/VisualEventLayer.tscn"
const TARGETING_SCENE := "res://scenes/ui/TargetingOverlay.tscn"
const QUEUE_SCRIPT := preload("res://scripts/runtime/visual_event_queue.gd")
const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/visual_event_snapshot.gd")
const AUDIO_REGISTRY_SCRIPT := preload("res://scripts/audio/audio_event_registry.gd")
const AUDIO_BUS_SCRIPT := preload("res://scripts/audio/audio_event_bus.gd")
const MONSTER_PRESENTER := preload("res://scripts/ui/monster_event_presenter.gd")
const CITY_PRESENTER := preload("res://scripts/ui/city_damage_presenter.gd")
const ROUTE_PRESENTER := preload("res://scripts/ui/route_event_presenter.gd")
const COMBAT_PRESENTER := preload("res://scripts/ui/combat_event_presenter.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(VISUAL_LAYER_SCENE), "VisualEventLayer scene exists")
	_expect(ResourceLoader.exists(TARGETING_SCENE), "TargetingOverlay scene exists")
	var queue: Variant = QUEUE_SCRIPT.new()
	queue.set("reduced_motion", true)
	var events := _sample_events()
	for i in range(40):
		queue.call("enqueue_event", events[i % events.size()])
	_expect(int(queue.call("active_count")) == 32, "VisualEventQueue caps active events at 32")
	var snapshot: Dictionary = queue.call("to_snapshot")
	_expect(bool(snapshot.get("reduced_motion", false)), "VisualEventQueue snapshot preserves reduced_motion")
	var classes: Array = snapshot.get("event_classes", []) if snapshot.get("event_classes", []) is Array else []
	for required_class in ["card_play", "target_arrow", "card_reveal", "monster_spawn", "monster_move", "monster_attack", "city_damage", "route_damage", "cash_gain", "gdp_delta", "final_countdown"]:
		_expect(classes.has(required_class), "VisualEventQueue keeps event class %s" % required_class)
	var visual_packed := load(VISUAL_LAYER_SCENE) as PackedScene
	var visual_layer := visual_packed.instantiate() as Control
	get_root().add_child(visual_layer)
	visual_layer.call("set_visual_events", events, true)
	await process_frame
	_expect(visual_layer.get_child_count() >= 6, "VisualEventLayer creates readable labels for active events")
	var layer_snapshot: Dictionary = visual_layer.call("get_visual_event_snapshot")
	_expect((layer_snapshot.get("events", []) as Array).size() == events.size(), "VisualEventLayer exposes event snapshot for tests")
	var targeting_packed := load(TARGETING_SCENE) as PackedScene
	var targeting := targeting_packed.instantiate() as Control
	get_root().add_child(targeting)
	targeting.call("set_targeting", Vector2(760, 620), Vector2(700, 430), false, "不能出牌", "冷却中")
	await process_frame
	_expect(bool(targeting.call("is_targeting_active")), "TargetingOverlay renders invalid target state")
	var registry: Variant = AUDIO_REGISTRY_SCRIPT.new()
	registry.call("load_default")
	for hook in ["ui_hover", "ui_click", "card_pickup", "card_drop_valid", "card_drop_invalid", "card_play", "card_reveal", "bid_update", "monster_spawn", "monster_move", "monster_attack", "city_damage", "route_damage", "cash_gain", "gdp_delta", "final_countdown"]:
		_expect(bool(registry.call("has_event", hook)), "AudioEventRegistry defines hook %s" % hook)
	var bus: Node = AUDIO_BUS_SCRIPT.new()
	get_root().add_child(bus)
	await process_frame
	bus.call("emit_audio_event", "monster_attack", {"source": "showcase"})
	_expect(str(bus.call("last_event_id")) == "monster_attack", "AudioEventBus records silent monster_attack hook")
	var source_bundle := "\n".join([
		FileAccess.get_file_as_string("res://scripts/ui/visual_event_layer.gd"),
		FileAccess.get_file_as_string("res://scripts/ui/targeting_overlay.gd"),
		FileAccess.get_file_as_string("res://scripts/runtime/visual_event_queue.gd"),
	])
	for forbidden in ["_use_skill", "_claim_district_card", "_build_city", "_apply_", "opponent_private", "true_owner"]:
		_expect(not source_bundle.contains(forbidden), "visual event layer stays UI-only and hidden-info safe (%s)" % forbidden)
	get_root().remove_child(visual_layer)
	visual_layer.queue_free()
	get_root().remove_child(targeting)
	targeting.queue_free()
	get_root().remove_child(bus)
	bus.queue_free()
	await process_frame
	_finish()


func _sample_events() -> Array:
	var events: Array = [
		{"type": "card_hover_glow", "at": Vector2(760, 720), "label": "悬停"},
		{"type": "card_pickup", "from": Vector2(760, 790), "to": Vector2(760, 610), "label": "拿起"},
		{"type": "card_drag_valid", "from": Vector2(760, 610), "to": Vector2(700, 430), "label": "松开出牌"},
		{"type": "card_drag_invalid", "from": Vector2(760, 610), "to": Vector2(560, 430), "label": "不能出牌"},
		{"type": "card_play_flyout", "from": Vector2(760, 790), "to": Vector2(700, 430), "label": "出牌", "progress": 0.5},
		{"type": "card_reveal_flash", "at": Vector2(520, 115), "label": "公开"},
		COMBAT_PRESENTER.target_arrow(Vector2(760, 610), Vector2(700, 430), true, "目标"),
		MONSTER_PRESENTER.monster_spawn(Vector2(650, 420)),
		MONSTER_PRESENTER.monster_move(Vector2(650, 420), Vector2(760, 465)),
		MONSTER_PRESENTER.monster_attack(Vector2(760, 465), Vector2(840, 500), 12),
		ROUTE_PRESENTER.route_damage(Vector2(690, 480), Vector2(875, 540)),
		COMBAT_PRESENTER.military_fire(Vector2(580, 460), Vector2(760, 465)),
		{"type": "cash_gain_float", "at": Vector2(850, 540), "label": "+¥120"},
		{"type": "gdp_delta_float", "at": Vector2(910, 510), "label": "-6 GDP"},
		{"type": "final_countdown_pulse", "at": Vector2(1000, 210), "label": "终局"},
	]
	events.append_array(CITY_PRESENTER.city_damage(Vector2(840, 500), -4, -6))
	return SNAPSHOT_SCRIPT.normalize_events(events)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Visual event smoke test passed.")
		quit(0)
	else:
		printerr("Visual event smoke test failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
