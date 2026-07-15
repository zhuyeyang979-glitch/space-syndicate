extends SceneTree

const PLANET_MAP_SCENE := preload("res://scenes/ui/PlanetMapView.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 720)
	root.add_child(viewport)
	var map_view := PLANET_MAP_SCENE.instantiate() as Control
	_expect(map_view != null, "PlanetMapView instantiates")
	if map_view == null:
		_finish()
		return
	viewport.add_child(map_view)
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.set("programmatic_focus_animation_enabled", false)
	await process_frame
	var payload := _map_payload()
	_apply_map(map_view, payload)
	await process_frame
	await process_frame
	var district_layer := map_view.get_node_or_null("DistrictLayer") as Control
	var route_layer := map_view.get_node_or_null("RouteLayer") as Control
	var monster_layer := map_view.get_node_or_null("MonsterLayer") as Control
	var effect_layer := map_view.get_node_or_null("EffectLayer") as Control
	var callout_layer := map_view.get_node_or_null("CalloutLayer") as Control
	var district_ids := _child_instance_ids(district_layer)
	var route_ids := _child_instance_ids(route_layer, ["route_segment", "route"])
	var monster_ids := _child_instance_ids(monster_layer)
	var effect_ids := _child_instance_ids(effect_layer)
	var callout_ids := _child_instance_ids(callout_layer)
	_expect(not district_ids.is_empty() and not route_ids.is_empty() and not monster_ids.is_empty() and not effect_ids.is_empty() and not callout_ids.is_empty(), "sceneized map renders static and animated nodes")

	var moving_payload := payload.duplicate(true)
	var moving_monsters := (payload.monsters as Array).duplicate(true)
	var moved_monster := (moving_monsters[0] as Dictionary).duplicate(true)
	moved_monster["position"] = Vector2(470, 500)
	moving_monsters[0] = moved_monster
	moving_payload["monsters"] = moving_monsters
	_apply_map(map_view, moving_payload)
	await process_frame
	await process_frame
	_expect(_child_instance_ids(district_layer) == district_ids and _child_instance_ids(route_layer, ["route_segment", "route"]) == route_ids, "monster movement refresh preserves static map node identities")
	monster_ids = _child_instance_ids(monster_layer)
	effect_ids = _child_instance_ids(effect_layer)
	callout_ids = _child_instance_ids(callout_layer)

	await create_timer(0.24).timeout
	_expect(_child_instance_ids(effect_layer) == effect_ids and _child_instance_ids(callout_layer) == callout_ids, "animated child scenes advance without rebuilding the whole map")

	for _refresh_index in range(6):
		_apply_map(map_view, moving_payload)
		await process_frame
	await process_frame
	_expect(_child_instance_ids(district_layer) == district_ids, "identical live refresh preserves district node identities")
	_expect(_child_instance_ids(route_layer, ["route_segment", "route"]) == route_ids, "identical live refresh preserves route node identities")
	_expect(_child_instance_ids(monster_layer) == monster_ids, "identical live refresh preserves monster node identities")
	_expect(_child_instance_ids(effect_layer) == effect_ids and _child_instance_ids(callout_layer) == callout_ids, "identical live refresh preserves animated node identities")

	map_view.queue_free()
	viewport.queue_free()
	await process_frame
	_finish()


func _apply_map(map_view: Control, payload: Dictionary) -> void:
	map_view.call(
		"set_map",
		payload.districts,
		1400.0,
		950.0,
		0,
		[Color("#0ea5e9"), Color("#22c55e")],
		payload.trails,
		payload.callouts,
		payload.effects,
		payload.monsters,
		payload.cities,
		payload.routes,
		"能源",
		"all"
	)


func _map_payload() -> Dictionary:
	return {
		"districts": [
			{
				"name": "北环区",
				"terrain": "land",
				"center": Vector2(360, 470),
				"polygon": [Vector2(140, 220), Vector2(650, 210), Vector2(640, 730), Vector2(150, 740)],
				"neighbors": [1],
				"products": ["能源"],
				"demands": [],
				"hp": 100,
				"damage": 0,
			},
			{
				"name": "南港区",
				"terrain": "ocean",
				"center": Vector2(1030, 470),
				"polygon": [Vector2(760, 210), Vector2(1260, 220), Vector2(1250, 740), Vector2(750, 730)],
				"neighbors": [0],
				"products": [],
				"demands": ["能源"],
				"hp": 100,
				"damage": 0,
			},
		],
		"monsters": [{"name": "公开测试怪兽", "position": Vector2(410, 470), "label": "M", "glyph": "M", "down": false}],
		"cities": [{"district": 0, "position": Vector2(360, 470), "level": 1, "tag": "1", "products": ["能源"], "active": true}],
		"routes": [{"product": "能源", "points": [Vector2(360, 470), Vector2(1030, 470)], "disrupted": false, "flow_multiplier": 1.0}],
		"trails": [{"from": Vector2(360, 470), "to": Vector2(1030, 470), "label": "运输", "style": "movement", "duration": 2.0, "life": 2.0}],
		"callouts": [{"actor": "公开单位", "action": "移动", "detail": "区域间移动", "duration": 2.0, "life": 2.0}],
		"effects": [{"kind": "impact", "position": Vector2(1030, 470), "from": Vector2(360, 470), "to": Vector2(1030, 470), "label": "抵达", "duration": 2.0, "life": 2.0}],
	}


func _child_instance_ids(parent: Node, kinds: Array[String] = []) -> Array[int]:
	var result: Array[int] = []
	if parent == null:
		return result
	for child in parent.get_children():
		if not (child is Node) or not bool((child as Node).get_meta("sceneized_planet_map_child", false)):
			continue
		var kind := str((child as Node).get_meta("sceneized_planet_map_kind", ""))
		if not kinds.is_empty() and not kinds.has(kind):
			continue
		result.append((child as Node).get_instance_id())
	return result


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("PLANET_MAP_LIVE_REFRESH_IDENTITY_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("PLANET_MAP_LIVE_REFRESH_IDENTITY_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
