@tool
extends Node
class_name TablePublicMapQuery

const MONSTER_COLORS := [Color("#ef4444"), Color("#f97316"), Color("#eab308"), Color("#a855f7"), Color("#06b6d4"), Color("#22c55e")]

var _world_session_state: WorldSessionState
var _authorization: LocalViewerAuthorization
var _world_query: WorldSessionPresentationQuery
var _selection: TableSelectionState
var _monster: MonsterRuntimeController
var _military: MilitaryRuntimeController
var _commodity_flow: CommodityFlowRuntimeController
var _revision := 0
var _last_fingerprint := ""


func configure(
	world_session_state: WorldSessionState,
	authorization: LocalViewerAuthorization,
	world_query: WorldSessionPresentationQuery,
	selection: TableSelectionState,
	monster: MonsterRuntimeController,
	military: MilitaryRuntimeController,
	commodity_flow: CommodityFlowRuntimeController
) -> void:
	_world_session_state = world_session_state
	_authorization = authorization
	_world_query = world_query
	_selection = selection
	_monster = monster
	_military = military
	_commodity_flow = commodity_flow


func snapshot_for_viewer(viewer_index: int, commodity_id := "") -> TablePublicMapProjection:
	var projection := TablePublicMapProjection.new()
	projection.viewer_index = viewer_index
	var public_world := _world_query.public_projection() if _world_query != null else WorldSessionPublicProjection.new()
	projection.districts = public_world.districts.duplicate(true)
	projection.city_markers = _city_markers(viewer_index, public_world.districts)
	projection.unit_markers = _unit_markers(public_world.districts)
	projection.selected_trade_product = commodity_id.strip_edges()
	projection.route_markers = _route_markers(projection.selected_trade_product, public_world.districts)
	var fingerprint := JSON.stringify([projection.districts, projection.city_markers, projection.unit_markers, projection.route_markers, projection.selected_trade_product])
	if fingerprint != _last_fingerprint:
		_last_fingerprint = fingerprint
		_revision += 1
	projection.revision = _revision
	return projection


func public_map_facts() -> Dictionary:
	var public_world := _world_query.public_projection() if _world_query != null else WorldSessionPublicProjection.new()
	var active_city_count := 0
	var destroyed_district_count := 0
	for district_variant in public_world.districts:
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		if bool(district.get("destroyed", false)):
			destroyed_district_count += 1
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		if bool(city.get("present", false)) and bool(city.get("active", false)):
			active_city_count += 1
	var monster_count := _monster.roster_snapshot(false).size() if _monster != null else 0
	var active_monster_count := 0
	if _monster != null:
		for actor_variant in _monster.roster_snapshot(false):
			if actor_variant is Dictionary and not bool((actor_variant as Dictionary).get("down", false)):
				active_monster_count += 1
	return {
		"active_city_count": active_city_count,
		"destroyed_district_count": destroyed_district_count,
		"active_monster_count": active_monster_count,
		"monster_count": monster_count,
		"key_city": {},
	}


func debug_snapshot() -> Dictionary:
	return {
		"configured": _world_query != null and _authorization != null,
		"revision": _revision,
		"uses_public_monster_roster": true,
		"uses_public_military_roster": true,
		"routes_are_actual_flow_only": true,
		"hidden_owner_truth_exposed": false,
		"stable_internal_unit_ids_exposed": false,
	}


func _city_markers(viewer_index: int, public_districts: Array) -> Array:
	var result: Array = []
	var guesses: Dictionary = {}
	if _authorization != null and _authorization.can_view_subject(viewer_index, viewer_index) and _world_session_state != null and viewer_index < _world_session_state.players.size():
		var viewer: Dictionary = _world_session_state.players[viewer_index] if _world_session_state.players[viewer_index] is Dictionary else {}
		guesses = (viewer.get("city_guesses", {}) as Dictionary).duplicate(true) if viewer.get("city_guesses", {}) is Dictionary else {}
	for index in range(public_districts.size()):
		var public_district: Dictionary = public_districts[index] if public_districts[index] is Dictionary else {}
		var public_city: Dictionary = public_district.get("city", {}) if public_district.get("city", {}) is Dictionary else {}
		if not bool(public_city.get("present", false)):
			continue
		var actual_owner := -1
		if _world_session_state != null and index < _world_session_state.districts.size():
			var raw_district: Dictionary = _world_session_state.districts[index] if _world_session_state.districts[index] is Dictionary else {}
			var raw_city: Dictionary = raw_district.get("city", {}) if raw_district.get("city", {}) is Dictionary else {}
			actual_owner = int(raw_city.get("owner", -1))
		var own_city := _authorization != null and _authorization.can_view_subject(viewer_index, viewer_index) and actual_owner == viewer_index
		var guess := int(guesses.get(index, -1))
		var owner_relation := "own" if own_city else ("guessed" if guess >= 0 else "unknown")
		result.append({
			"district": index,
			"position": public_district.get("center", Vector2.ZERO),
			"level": int(public_city.get("level", 0)),
			"active": bool(public_city.get("active", false)),
			"tag": "己" if own_city else ("猜%d" % (guess + 1) if guess >= 0 else "?"),
			"tag_color": Color("#38bdf8") if own_city else (Color("#c084fc") if guess >= 0 else Color("#94a3b8")),
			"products": (public_city.get("products", []) as Array).duplicate(true) if public_city.get("products", []) is Array else [],
			"competition": int(public_city.get("competition_matches", 0)),
			"rise": 1.0,
			"owner_relation": owner_relation,
		})
	return result


func _unit_markers(public_districts: Array) -> Array:
	var result: Array = []
	if _monster != null:
		var monsters := _monster.roster_snapshot(false)
		for index in range(monsters.size()):
			var actor: Dictionary = monsters[index] if monsters[index] is Dictionary else {}
			result.append({
				"position": _entity_position(actor, public_districts),
				"label": "%d" % (index + 1),
				"name": str(actor.get("name", "怪兽")),
				"color": MONSTER_COLORS[index % MONSTER_COLORS.size()],
				"slot_color": MONSTER_COLORS[index % MONSTER_COLORS.size()],
				"secondary": Color("#e2e8f0"),
				"glyph": "怪",
				"motif": "beast",
				"down": bool(actor.get("down", false)),
				"public_slot": index,
			})
	if _military != null:
		var units := _military.roster_snapshot(false)
		for index in range(units.size()):
			var unit: Dictionary = units[index] if units[index] is Dictionary else {}
			result.append({
				"position": _entity_position(unit, public_districts),
				"label": _military.unit_type_glyph(unit),
				"name": "匿名%s" % _military.unit_type_label(unit),
				"color": _military.unit_color(unit),
				"slot_color": Color("#facc15"),
				"secondary": Color("#bfdbfe"),
				"glyph": _military.unit_type_glyph(unit),
				"motif": _military.unit_motif(unit),
				"down": false,
				"public_slot": index,
			})
	return result


func _route_markers(commodity_id: String, public_districts: Array) -> Array:
	if commodity_id.is_empty() or _commodity_flow == null:
		return []
	var snapshot := _commodity_flow.public_actual_flow_snapshot(commodity_id)
	if not bool(snapshot.get("available", false)):
		return []
	var district_by_region_id := {}
	for index in range(public_districts.size()):
		var district: Dictionary = public_districts[index] if public_districts[index] is Dictionary else {}
		district_by_region_id[str(district.get("region_id", ""))] = index
	var result: Array = []
	for row_variant in snapshot.get("rows", []):
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		if str(row.get("commodity_id", "")) != commodity_id:
			continue
		var from_region_id := str(row.get("from_region_id", ""))
		var to_region_id := str(row.get("to_region_id", ""))
		if not district_by_region_id.has(from_region_id) or not district_by_region_id.has(to_region_id):
			continue
		var from_index := int(district_by_region_id[from_region_id])
		var to_index := int(district_by_region_id[to_region_id])
		var from_district := public_districts[from_index] as Dictionary
		var to_district := public_districts[to_index] as Dictionary
		result.append({
			"product": commodity_id,
			"from": from_index,
			"to": to_index,
			"points": [from_district.get("center", Vector2.ZERO), to_district.get("center", Vector2.ZERO)],
			"disrupted": bool(row.get("capacity_limited", false)) or bool(row.get("congested", false)),
			"source_type": str(row.get("flow_kind", "actual_flow")),
			"mode_tags": (row.get("transport_modes", []) as Array).duplicate(true) if row.get("transport_modes", []) is Array else [],
			"flow_multiplier": _strength_multiplier(str(row.get("delivered_units_band", "trace"))),
			"low_emphasis": bool(row.get("low_emphasis", false)),
		})
	return result


func _entity_position(entity: Dictionary, public_districts: Array) -> Vector2:
	if entity.get("world_position", null) is Vector2:
		return entity.get("world_position", Vector2.ZERO)
	var district_index := int(entity.get("position", -1))
	if district_index >= 0 and district_index < public_districts.size():
		return (public_districts[district_index] as Dictionary).get("center", Vector2.ZERO)
	return Vector2.ZERO


func _strength_multiplier(band: String) -> float:
	return {"trace": 0.25, "low": 0.5, "medium": 1.0, "high": 1.5, "bulk": 2.0}.get(band, 0.25)
