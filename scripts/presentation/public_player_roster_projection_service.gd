extends RefCounted
class_name PublicPlayerRosterProjectionService

const ROSTER_PROJECTION := preload(
	"res://scripts/presentation/public_player_roster_projection_v1.gd"
)
const INSPECTION_PROJECTION := preload(
	"res://scripts/presentation/player_inspection_projection_v1.gd"
)
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const PLAYER_ACCENTS := [
	"#38bdf8",
	"#f472b6",
	"#facc15",
	"#4ade80",
	"#c084fc",
	"#fb7185",
	"#2dd4bf",
	"#fb923c",
]

var _bound_viewer_index := -1
var _bound_authorization_revision := 0
var _roster_projection: Dictionary = {}
var _inspection_projection: Dictionary = {}
var _roster_signature := ""
var _inspection_signature := ""
var _roster_apply_count := 0
var _inspection_apply_count := 0
var _duplicate_count := 0
var _reject_count := 0
var _stale_count := 0
var _conflict_count := 0
var _last_apply_kind := "none"
var _roster_compose_count := 0
var _inspection_compose_count := 0
var _compose_reject_count := 0


func compose_roster(
	public_players: Array,
	viewer_index: int,
	authorization_revision: int,
	source_revision: int,
	inspected_player_index: int = -1,
	submission_lock_state: Variant = "unlocked"
) -> Dictionary:
	_roster_compose_count += 1
	if viewer_index < 0 or authorization_revision <= 0 or source_revision < 0 \
			or public_players.size() > ROSTER_PROJECTION.MAX_PLAYER_COUNT:
		_compose_reject_count += 1
		return {}
	var rows: Array = []
	var seen_player_ids: Array[String] = []
	for public_order_index in range(public_players.size()):
		var source_variant: Variant = public_players[public_order_index]
		if not (source_variant is Dictionary):
			_compose_reject_count += 1
			return {}
		var source := source_variant as Dictionary
		var player_index := _source_player_index(source, public_order_index)
		var player_id := _source_player_id(source, player_index)
		if player_index < 0 or not WIRE.is_stable_id(player_id) \
				or seen_player_ids.has(player_id):
			_compose_reject_count += 1
			return {}
		seen_player_ids.append(player_id)
		rows.append({
			"player_id": player_id,
			"public_order_index": public_order_index,
			"display_name": _source_text(
				source,
				["display_name", "public_player_name"],
				"玩家%d" % (player_index + 1)
			),
			"role_display_name": _source_text(
				source,
				["role_display_name", "role_name"],
				"外星辛迪加"
			),
			"avatar_key": _source_text(
				source,
				["avatar_key", "portrait_key"],
				"avatar.player-%d" % player_index
			),
			"accent": _source_accent(source, public_order_index),
			"public_status": _stable_id(
				_source_text(source, ["public_status"], "ready"),
				"ready"
			),
			"is_local_player": player_index == viewer_index,
			"is_eliminated": _source_bool(source, ["is_eliminated", "eliminated"]),
			"is_inspected": player_index == inspected_player_index,
			"submission_lock_public_state": _submission_lock_for(
				submission_lock_state,
				player_index,
				player_id
			),
		})
	var projection := ROSTER_PROJECTION.build({
		"schema_version": ROSTER_PROJECTION.SCHEMA_VERSION,
		"viewer_index": viewer_index,
		"authorization_revision": authorization_revision,
		"source_revision": source_revision,
		"players": rows,
	})
	if projection.is_empty():
		_compose_reject_count += 1
	return projection


func compose_inspection(
	public_player: Dictionary,
	viewer_index: int,
	authorization_revision: int,
	source_revision: int,
	public_summaries: Dictionary = {},
	public_history_links: Array = [],
	allowed_navigation_intents: Array = []
) -> Dictionary:
	_inspection_compose_count += 1
	if viewer_index < 0 or authorization_revision <= 0 or source_revision < 0:
		_compose_reject_count += 1
		return {}
	var player_index := _source_player_index(public_player, -1)
	var player_id := _source_player_id(public_player, player_index)
	if not WIRE.is_stable_id(player_id):
		_compose_reject_count += 1
		return {}
	var history_links := _public_history_links(public_history_links)
	var navigation_intents := _public_navigation_intents(allowed_navigation_intents)
	if history_links.size() != public_history_links.size() \
			or navigation_intents.size() != allowed_navigation_intents.size():
		_compose_reject_count += 1
		return {}
	var projection := INSPECTION_PROJECTION.build({
		"schema_version": INSPECTION_PROJECTION.SCHEMA_VERSION,
		"viewer_index": viewer_index,
		"authorization_revision": authorization_revision,
		"source_revision": source_revision,
		"player_id": player_id,
		"display_name": _source_text(
			public_player,
			["display_name", "public_player_name"],
			"玩家%d" % (player_index + 1)
		),
		"role_display_name": _source_text(
			public_player,
			["role_display_name", "role_name"],
			"外星辛迪加"
		),
		"avatar_key": _source_text(
			public_player,
			["avatar_key", "portrait_key"],
			"avatar.player-%d" % maxi(0, player_index)
		),
		"accent": _source_accent(public_player, maxi(0, player_index)),
		"public_status": _source_text(public_player, ["public_status"], "ready"),
		"public_assets_summary": _summary_text(public_summaries, "public_assets_summary"),
		"public_facilities_summary": _summary_text(
			public_summaries,
			"public_facilities_summary"
		),
		"public_military_summary": _summary_text(
			public_summaries,
			"public_military_summary"
		),
		"public_monster_summary": _summary_text(
			public_summaries,
			"public_monster_summary"
		),
		"public_history_links": history_links,
		"allowed_navigation_intents": navigation_intents,
	})
	if projection.is_empty():
		_compose_reject_count += 1
	return projection


func compose_inspection_for_player(
	public_players: Array,
	inspected_player_index: int,
	viewer_index: int,
	authorization_revision: int,
	source_revision: int,
	public_summaries: Dictionary = {},
	public_history_links: Array = [],
	allowed_navigation_intents: Array = []
) -> Dictionary:
	for source_order in range(public_players.size()):
		var source_variant: Variant = public_players[source_order]
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if _source_player_index(source, source_order) == inspected_player_index:
			return compose_inspection(
				source,
				viewer_index,
				authorization_revision,
				source_revision,
				public_summaries,
				public_history_links,
				allowed_navigation_intents
			)
	_compose_reject_count += 1
	return {}


func bind_viewer(viewer_index: int, authorization_revision: int) -> bool:
	if viewer_index < 0 or authorization_revision <= 0:
		_bound_viewer_index = -1
		_bound_authorization_revision = 0
		clear()
		return false
	if viewer_index == _bound_viewer_index \
			and authorization_revision == _bound_authorization_revision:
		return true
	_bound_viewer_index = viewer_index
	_bound_authorization_revision = authorization_revision
	clear()
	return true


func apply_roster_projection(value: Dictionary) -> bool:
	if not ROSTER_PROJECTION.matches_viewer_authorization(
		value,
		_bound_viewer_index,
		_bound_authorization_revision
	):
		_reject_count += 1
		_last_apply_kind = "roster_rejected"
		return false
	var next_revision := int(value.get("source_revision", -1))
	var current_revision := int(_roster_projection.get("source_revision", -1))
	var next_signature := str(value.get("projection_fingerprint", ""))
	var gate := _revision_gate(current_revision, next_revision, _roster_signature, next_signature)
	if gate != "apply":
		_record_gate(gate, "roster")
		return gate == "duplicate"
	_roster_projection = ROSTER_PROJECTION.detached_copy(value)
	_roster_signature = next_signature
	_roster_apply_count += 1
	_last_apply_kind = "roster_applied"
	return true


func apply_inspection_projection(value: Dictionary) -> bool:
	if not INSPECTION_PROJECTION.matches_viewer_authorization(
		value,
		_bound_viewer_index,
		_bound_authorization_revision
	):
		_reject_count += 1
		_last_apply_kind = "inspection_rejected"
		return false
	var next_revision := int(value.get("source_revision", -1))
	var current_revision := int(_inspection_projection.get("source_revision", -1))
	var next_signature := str(value.get("projection_fingerprint", ""))
	var current_player_id := str(_inspection_projection.get("player_id", ""))
	var next_player_id := str(value.get("player_id", ""))
	var gate := _revision_gate(
		current_revision,
		next_revision,
		_inspection_signature,
		next_signature
	)
	# Player inspection is selection-dependent. Switching to another public player at
	# the same world revision is not a projection collision.
	if gate == "conflict" and current_player_id != next_player_id:
		gate = "apply"
	if gate != "apply":
		_record_gate(gate, "inspection")
		return gate == "duplicate"
	_inspection_projection = INSPECTION_PROJECTION.detached_copy(value)
	_inspection_signature = next_signature
	_inspection_apply_count += 1
	_last_apply_kind = "inspection_applied"
	return true


func roster_projection() -> Dictionary:
	return ROSTER_PROJECTION.detached_copy(_roster_projection)


func roster_players() -> Array:
	var players: Array = _roster_projection.get("players", []) as Array
	return players.duplicate(true)


func inspection_projection() -> Dictionary:
	return INSPECTION_PROJECTION.detached_copy(_inspection_projection)


func roster_signature() -> String:
	return _roster_signature


func inspection_signature() -> String:
	return _inspection_signature


func bound_viewer_index() -> int:
	return _bound_viewer_index


func bound_authorization_revision() -> int:
	return _bound_authorization_revision


func clear() -> void:
	_roster_projection = {}
	_inspection_projection = {}
	_roster_signature = ""
	_inspection_signature = ""
	_last_apply_kind = "cleared"


func clear_roster() -> void:
	_roster_projection = {}
	_roster_signature = ""
	_last_apply_kind = "roster_cleared"


func clear_inspection() -> void:
	_inspection_projection = {}
	_inspection_signature = ""
	_last_apply_kind = "inspection_cleared"


func debug_snapshot() -> Dictionary:
	return {
		"viewer_index": _bound_viewer_index,
		"authorization_revision": _bound_authorization_revision,
		"roster_source_revision": int(_roster_projection.get("source_revision", -1)),
		"inspection_source_revision": int(_inspection_projection.get("source_revision", -1)),
		"roster_signature": _roster_signature,
		"inspection_signature": _inspection_signature,
		"roster_apply_count": _roster_apply_count,
		"inspection_apply_count": _inspection_apply_count,
		"duplicate_count": _duplicate_count,
		"reject_count": _reject_count,
		"stale_count": _stale_count,
		"conflict_count": _conflict_count,
		"last_apply_kind": _last_apply_kind,
		"roster_compose_count": _roster_compose_count,
		"inspection_compose_count": _inspection_compose_count,
		"compose_reject_count": _compose_reject_count,
		"public_player_count": (_roster_projection.get("players", []) as Array).size(),
		"rotates_for_local_viewer": false,
		"direct_gameplay_mutation_count": 0,
		"rng_draw_count": 0,
		"private_fact_read_count": 0,
		"projection_assembler_count": 1,
	}


func _revision_gate(
	current_revision: int,
	next_revision: int,
	current_signature: String,
	next_signature: String
) -> String:
	if current_revision >= 0 and next_revision < current_revision:
		return "stale"
	if not current_signature.is_empty() and next_signature == current_signature:
		return "duplicate"
	if current_revision >= 0 and next_revision == current_revision:
		return "conflict"
	return "apply"


func _record_gate(gate: String, surface: String) -> void:
	match gate:
		"duplicate":
			_duplicate_count += 1
		"stale":
			_stale_count += 1
		"conflict":
			_conflict_count += 1
		_:
			_reject_count += 1
	_last_apply_kind = "%s_%s" % [surface, gate]


func _source_player_index(source: Dictionary, fallback: int) -> int:
	var value: Variant = source.get("player_index", fallback)
	if value is int:
		return int(value)
	return fallback


func _source_player_id(source: Dictionary, player_index: int) -> String:
	var explicit: Variant = source.get("player_id", "")
	if explicit is String and WIRE.is_stable_id(explicit):
		return str(explicit)
	return "player.%d" % player_index if player_index >= 0 else ""


func _source_text(
	source: Dictionary,
	allowed_fields: Array[String],
	fallback: String
) -> String:
	for field in allowed_fields:
		var value: Variant = source.get(field, null)
		if value is String:
			var text := str(value).strip_edges()
			if not text.is_empty():
				return text.substr(0, 160)
	return fallback.substr(0, 160)


func _source_bool(source: Dictionary, allowed_fields: Array[String]) -> bool:
	for field in allowed_fields:
		var value: Variant = source.get(field, null)
		if value is bool:
			return bool(value)
	return false


func _source_accent(source: Dictionary, public_order_index: int) -> String:
	var value: Variant = source.get("accent", "")
	if value is String and not str(value).strip_edges().is_empty():
		return str(value).strip_edges().substr(0, 80)
	return str(PLAYER_ACCENTS[wrapi(public_order_index, 0, PLAYER_ACCENTS.size())])


func _submission_lock_for(
	state: Variant,
	player_index: int,
	player_id: String
) -> String:
	var candidate: Variant = state
	if state is Dictionary:
		var states := state as Dictionary
		candidate = states.get(player_id, states.get(player_index, "unlocked"))
	elif state is Array:
		var states := state as Array
		candidate = states[player_index] if player_index >= 0 and player_index < states.size() \
			else "unlocked"
	return _stable_id(str(candidate), "unlocked") if candidate is String else "unlocked"


func _stable_id(value: String, fallback: String) -> String:
	var normalized := value.strip_edges().to_lower().replace(" ", "-")
	return normalized if WIRE.is_stable_id(normalized) else fallback


func _summary_text(source: Dictionary, field: String) -> String:
	var value: Variant = source.get(field, "")
	return str(value).substr(0, 1000) if value is String else ""


func _public_history_links(source: Array) -> Array:
	var result: Array = []
	for value_variant in source:
		if not (value_variant is Dictionary):
			return []
		var value := value_variant as Dictionary
		var navigation: Variant = value.get("navigation_intent", null)
		if not (value.get("history_entry_id", null) is String) \
				or not (value.get("label", null) is String) \
				or not (navigation is Dictionary):
			return []
		var normalized_navigation := _public_navigation_intent(
			navigation as Dictionary
		)
		if normalized_navigation.is_empty():
			return []
		result.append({
			"history_entry_id": str(value.get("history_entry_id", "")),
			"label": str(value.get("label", "")).substr(0, 160),
			"navigation_intent": normalized_navigation,
		})
	return result


func _public_navigation_intents(source: Array) -> Array:
	var result: Array = []
	for value_variant in source:
		if not (value_variant is Dictionary):
			return []
		var normalized := _public_navigation_intent(value_variant as Dictionary)
		if normalized.is_empty():
			return []
		result.append(normalized)
	return result


func _public_navigation_intent(source: Dictionary) -> Dictionary:
	if source.has("request_id") and source.has("action_kind") \
			and source.has("source_surface") and source.has("target_card_name"):
		return {
			"request_id": str(source.get("request_id", "")),
			"action_kind": str(source.get("action_kind", "")),
			"source_surface": str(source.get("source_surface", "")),
			"target_card_name": str(source.get("target_card_name", "")),
		}
	if source.has("kind") and source.has("focused_history_entry_id") \
			and source.has("focused_region_id"):
		return {
			"kind": str(source.get("kind", "")),
			"focused_history_entry_id": str(
				source.get("focused_history_entry_id", "")
			),
			"focused_region_id": str(source.get("focused_region_id", "")),
		}
	return {}
