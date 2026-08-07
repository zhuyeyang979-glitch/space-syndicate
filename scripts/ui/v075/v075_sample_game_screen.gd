extends "res://scripts/ui/v074/v074_sample_game_screen.gd"
class_name V075SampleGameScreen

signal combat_projection_applied(projection: Dictionary)
signal combat_receipt_processed(receipt_id: String, result: Dictionary)

const V075_RULESET_ID := "v0.7.5"
const BASE_V074_RULESET_ID := "v0.7.4"
const DEFAULT_VIEWER_ID := "player.local"
const DEFAULT_PRIVATE_SKILL_INTENT_KIND := (
	"combat.monster_private_skill.request"
)
const DEFAULT_MILITARY_INTENT_KIND := "combat.military_mission.select"
const PRIVATE_SKILL_EXECUTION_MODE := "private_instant_serial"
const MILITARY_EXECUTION_MODE := "normal_public_batch"

const ProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const V075CardDefinitionRegistry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const V075_MONSTER_CARD_ART_PATH := (
	"res://assets/art/cards/v06/style_lock/monster/"
	+ "spore_tide_emperor_v01.png"
)
const V075_MILITARY_CARD_ART_PATH := (
	"res://assets/third_party/commercial/icons/game_icons/source/"
	+ "spaceship.svg"
)
const V075_FACILITY_ART_PATHS := [
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "MetalPlates013/MetalPlates013_1K-JPG_Color.jpg",
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "PaintedMetal007/PaintedMetal007_1K-JPG_Color.jpg",
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "SheetMetal003/SheetMetal003_1K-JPG_Color.jpg",
]
const COMBAT_LAYOUT_MIN_WIDTH := 480.0
const COMBAT_LAYOUT_MAX_WIDTH := 660.0
const COMBAT_LAYOUT_PRIMARY_PLANET_INSET_X := 0.32
const COMBAT_LAYOUT_PRIMARY_PLANET_WIDTH := 0.44
const COMBAT_LAYOUT_PRIMARY_PLANET_INSET_Y := 0.12
const COMBAT_LAYOUT_PRIMARY_PLANET_HEIGHT := 0.76
const PresentationConsumer := preload(
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)
const PRESENTATION_SOURCE_UNBOUND := "unbound"
const PRESENTATION_SOURCE_RUNTIME_SHARED := "runtime_shared"
const PRESENTATION_SOURCE_ISOLATED_PREVIEW := "isolated_preview"
const PRESENTATION_SOURCE_RUNTIME_MISSING := "runtime_shared_missing"

const COMBAT_PROJECTION_KEYS := [
	"v075_combat_projection",
	"combat_player_projection",
	"combat_projection",
	"player_combat_projection",
]
const COMBAT_AUTHORITY_KEYS := [
	"v075_combat_authority_snapshot",
	"combat_authority_snapshot",
	"combat_authority",
]
const COMBAT_EVENT_KINDS := [
	"monster_card_purchased",
	"monster_deployed",
	"monster_refreshed",
	"monster_upgraded",
	"monster_replaced",
	"monster_target_selected",
	"monster_moved",
	"monster_trample_resolved",
	"monster_basic_attack",
	"monster_private_skill_requested",
	"monster_private_skill_resolved",
	"monster_skill_fizzled",
	"monster_skill_cooldown_started",
	"monster_skill_ready",
	"military_card_purchased",
	"military_region_assault",
	"military_monster_assault",
	"military_withdrawn",
	"facility_combat_damaged",
]
const TERMINAL_PHASES := [
	"victory_pending",
	"victory_resolved",
	"final_settlement",
	"terminal",
]

@onready var _combat_overlay: PanelContainer = (
	$PlaytestUtilityLayer/PlaytestSafeArea/V075CombatOverlay
)
@onready var _combat_surface_host: Control = (
	$PlaytestUtilityLayer/PlaytestSafeArea/V075CombatOverlay/Margin/Rows/SurfaceHost
)
@onready var _combat_surface: Control = (
	$PlaytestUtilityLayer/PlaytestSafeArea/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface
)
@onready var _combat_title: Label = (
	$PlaytestUtilityLayer/PlaytestSafeArea/V075CombatOverlay/Margin/Rows/Header/Title
)
@onready var _combat_status: Label = (
	$PlaytestUtilityLayer/PlaytestSafeArea/V075CombatOverlay/Margin/Rows/Header/Status
)
@onready var _combat_collapse_button: Button = (
	$PlaytestUtilityLayer/PlaytestSafeArea/V075CombatOverlay/Margin/Rows/Header/CollapseButton
)

var _v075_flow: Node
var _v075_capabilities: Dictionary = {}
var _v075_identity: Dictionary = {}
var _v075_snapshot: Dictionary = {}
var _combat_projection: Dictionary = {}
var _projection_adapter: RefCounted = ProjectionAdapter.new()
var _presentation_consumer: Node
var _presentation_consumer_owner: Node
var _presentation_source_mode := PRESENTATION_SOURCE_UNBOUND
var _presentation_signal_connected := false
var _presentation_source_bind_count := 0
var _presentation_local_preview_creation_count := 0
var _presentation_suppressed_duplicate_consume_count := 0
var _viewer_player_id := DEFAULT_VIEWER_ID
var _preferred_source_instance_id := ""
var _combat_session_key := ""
var _combat_terminal_phase := ""
var _combat_collapsed := true
var _combat_layout_mode := "COMPACT"
var _combat_layout_snapshot: Dictionary = {}
var _fallback_intent_sequence := 0
var _combat_projection_count := 0
var _combat_receipt_count := 0
var _combat_receipt_applied_count := 0
var _combat_receipt_duplicate_count := 0
var _combat_receipt_rejected_count := 0
var _combat_private_intent_count := 0
var _combat_military_intent_count := 0
var _last_combat_intent_kind := ""


func _ready() -> void:
	if is_instance_valid(_combat_surface):
		_combat_surface.connect(
			"private_target_selection_requested",
			Callable(self, "_on_private_target_selection_requested")
		)
		_combat_surface.connect(
			"military_mission_selected",
			Callable(self, "_on_military_mission_selected")
		)
	_combat_collapse_button.pressed.connect(_toggle_combat_surface)
	get_viewport().size_changed.connect(_resolve_combat_layout)
	super._ready()
	_set_v075_chrome()
	_combat_title.text = "COMBAT · V0.7.5"
	_combat_status.text = "等待战斗投影"
	_set_combat_surface_visibility()
	call_deferred("_resolve_combat_layout")


func bind_application_flow(
	flow: Node,
	identity: Dictionary,
	capabilities: Dictionary
) -> void:
	_v075_flow = flow
	_v075_identity = identity.duplicate(true)
	_v075_capabilities = capabilities.duplicate(true)
	_viewer_player_id = _resolve_viewer_player_id(identity, flow)
	_bind_presentation_source(flow)
	super.bind_application_flow(flow, identity, capabilities)
	_set_v075_chrome()
	_combat_status.text = "等待战斗投影 · %s" % _viewer_player_id
	_update_acceptance_state()


func apply_snapshot(snapshot: Dictionary) -> void:
	var incoming := snapshot.duplicate(true)
	var incoming_ruleset := str(incoming.get("ruleset_id", ""))
	if (
		not incoming_ruleset.is_empty()
		and incoming_ruleset not in [BASE_V074_RULESET_ID, V075_RULESET_ID]
	):
		super.apply_snapshot(snapshot)
		return
	_v075_snapshot = incoming
	_update_combat_session(incoming)
	var parent_snapshot := _parent_compatibility_snapshot(incoming)
	super.apply_snapshot(parent_snapshot)
	_sync_terminal_phase(str(incoming.get("phase", "")))
	var projection := _extract_combat_projection(incoming)
	if not projection.is_empty():
		projection = _projection_for_phase(
			projection,
			str(incoming.get("phase", ""))
		)
	if projection.is_empty():
		_clear_combat_projection()
	else:
		apply_combat_projection(
			projection,
			str(incoming.get("preferred_source_instance_id", ""))
		)
	_update_acceptance_state()


func apply_receipt(receipt: Dictionary) -> void:
	super.apply_receipt(receipt)
	if (
		str(receipt.get("intent_kind", "")) == "new_game.start"
		and bool(receipt.get("accepted", false))
	):
		_reset_combat_state()
	if _is_combat_receipt(receipt):
		apply_combat_receipt(receipt)
	_update_acceptance_state()


func apply_owner_private_receipt(receipt: Dictionary) -> void:
	if str(receipt.get("receipt_scope", "")) != "owner_private":
		return
	super.apply_receipt(receipt)
	_update_acceptance_state()


func present_final_settlement(settlement: Dictionary) -> void:
	_sync_terminal_phase("final_settlement")
	super.present_final_settlement(settlement)
	_update_acceptance_state()


func apply_combat_projection(
	projection: Dictionary,
	preferred_source_instance_id := ""
) -> void:
	var normalized := _normalize_projection(projection)
	if normalized.is_empty():
		_clear_combat_projection()
		return
	normalized = _projection_for_phase(
		normalized,
		str(normalized.get("phase", ""))
	)
	var had_projection := not _combat_projection.is_empty()
	_combat_projection = normalized.duplicate(true)
	_preferred_source_instance_id = (
		preferred_source_instance_id
		if not preferred_source_instance_id.is_empty()
		else _first_owned_source_id(normalized)
	)
	_combat_projection_count += 1
	if not had_projection:
		_combat_collapsed = false
	if is_instance_valid(_combat_surface):
		_combat_surface.call(
			"apply_projection",
			normalized,
			_preferred_source_instance_id
		)
	_combat_overlay.visible = true
	_combat_status.text = _projection_status(normalized)
	_set_combat_surface_visibility()
	combat_projection_applied.emit(normalized.duplicate(true))
	_resolve_combat_layout()


func apply_combat_authority_snapshot(
	authority_snapshot: Dictionary,
	viewer_player_id := "",
	preferred_source_instance_id := ""
) -> void:
	if not viewer_player_id.is_empty():
		_viewer_player_id = viewer_player_id
	var projection := _projection_adapter.call(
		"project_for_viewer",
		authority_snapshot,
		_viewer_player_id
	) as Dictionary
	apply_combat_projection(projection, preferred_source_instance_id)


func apply_combat_receipt(receipt: Dictionary) -> Dictionary:
	if not _is_combat_receipt(receipt):
		return {
			"applied": false,
			"reason_code": "not_a_v075_combat_receipt",
		}
	_combat_receipt_count += 1
	var result := {}
	if (
		_presentation_source_mode == PRESENTATION_SOURCE_RUNTIME_SHARED
		and is_instance_valid(_presentation_consumer)
	):
		_presentation_suppressed_duplicate_consume_count += 1
		result = {
			"applied": true,
			"reason_code":
				"combat_presentation_runtime_shared_acknowledged",
			"consume_suppressed": true,
			"presentation_source_mode": _presentation_source_mode,
		}
	else:
		if not is_instance_valid(_presentation_consumer):
			result = {
				"applied": false,
				"reason_code": "combat_presentation_consumer_missing",
				"presentation_source_mode": _presentation_source_mode,
			}
		else:
			result = _presentation_consumer.call(
				"consume_receipt",
				receipt
			) as Dictionary
	if bool(result.get("applied", false)):
		_combat_receipt_applied_count += 1
	else:
		var reason := str(result.get("reason_code", ""))
		if reason == "combat_presentation_receipt_duplicate":
			_combat_receipt_duplicate_count += 1
		else:
			_combat_receipt_rejected_count += 1
	var receipt_id := str(
		receipt.get("combat_receipt_id", receipt.get("receipt_id", ""))
	)
	combat_receipt_processed.emit(receipt_id, result.duplicate(true))
	_update_acceptance_state()
	return result


func combat_debug_snapshot() -> Dictionary:
	var presentation_debug := {}
	if is_instance_valid(_presentation_consumer):
		presentation_debug = _presentation_consumer.call(
			"debug_snapshot"
		) as Dictionary
	var surface_debug := {}
	if is_instance_valid(_combat_surface):
		surface_debug = _combat_surface.call("debug_snapshot") as Dictionary
	return {
		"schema": "V075SampleGameScreenCombatDebugV1",
		"ruleset_id": V075_RULESET_ID,
		"viewer_player_id_present": not _viewer_player_id.is_empty(),
		"projection_count": _combat_projection_count,
		"receipt_count": _combat_receipt_count,
		"receipt_applied_count": _combat_receipt_applied_count,
		"receipt_duplicate_count": _combat_receipt_duplicate_count,
		"receipt_rejected_count": _combat_receipt_rejected_count,
		"presentation_source_mode": _presentation_source_mode,
		"presentation_shared_consumer_count": int(
			_presentation_source_mode == PRESENTATION_SOURCE_RUNTIME_SHARED
			and is_instance_valid(_presentation_consumer)
		),
		"presentation_local_preview_consumer_count": int(
			_presentation_source_mode == PRESENTATION_SOURCE_ISOLATED_PREVIEW
			and is_instance_valid(_presentation_consumer)
		),
		"presentation_source_bind_count":
			_presentation_source_bind_count,
		"presentation_local_preview_creation_count":
			_presentation_local_preview_creation_count,
		"presentation_suppressed_duplicate_consume_count":
			_presentation_suppressed_duplicate_consume_count,
		"presentation_signal_connection_count": int(
			_presentation_signal_is_connected()
		),
		"presentation_consumer_instance_id": (
			_presentation_consumer.get_instance_id()
			if is_instance_valid(_presentation_consumer)
			else 0
		),
		"presentation_runtime_owner_instance_id": (
			_presentation_consumer_owner.get_instance_id()
			if is_instance_valid(_presentation_consumer_owner)
			else 0
		),
		"presentation_shared_identity_green":
			_presentation_source_identity_green(),
		"private_skill_intent_count": _combat_private_intent_count,
		"military_intent_count": _combat_military_intent_count,
		"last_intent_kind": _last_combat_intent_kind,
		"terminal_phase": _combat_terminal_phase,
		"surface_visible": (
			_combat_surface.visible
			if is_instance_valid(_combat_surface)
			else false
		),
		"overlay_visible": (
			_combat_overlay.visible
			if is_instance_valid(_combat_overlay)
			else false
		),
		"overlay_collapsed": _combat_collapsed,
		"layout_mode": _combat_layout_mode,
		"combat_layout": _combat_layout_snapshot.duplicate(true),
		"combat_panel_anchor": str(
			_combat_layout_snapshot.get("panel_anchor", "")
		),
		"combat_primary_planet_occlusion_count": int(
			_combat_layout_snapshot.get(
				"primary_planet_occlusion_count",
				0
			)
		),
		"combat_planet_right_half_occlusion_count": int(
			_combat_layout_snapshot.get(
				"planet_right_half_occlusion_count",
				0
			)
		),
		"presentation": presentation_debug,
		"surface": surface_debug,
		"application_flow_bound": is_instance_valid(_v075_flow),
		"special_support_placeholder_count": 0,
		"presentation_gameplay_mutation_count": 0,
		"presentation_rng_draw_delta": 0,
		"gameplay_mutation_count": 0,
		"rng_draw_delta": 0,
	}


func debug_snapshot() -> Dictionary:
	return combat_debug_snapshot()


func _bind_presentation_source(flow: Node) -> void:
	_release_presentation_source()
	var runtime_binding := _runtime_presentation_binding(flow)
	var runtime_owner := runtime_binding.get("owner") as Node
	var runtime_consumer := runtime_binding.get("consumer") as Node
	if is_instance_valid(runtime_owner):
		_presentation_consumer_owner = runtime_owner
		if not is_instance_valid(runtime_consumer):
			_presentation_source_mode = PRESENTATION_SOURCE_RUNTIME_MISSING
			return
		_presentation_consumer = runtime_consumer
		_presentation_source_mode = PRESENTATION_SOURCE_RUNTIME_SHARED
		_presentation_source_bind_count += 1
		_connect_presentation_signal()
		return
	if not _is_isolated_preview_flow(flow):
		_presentation_source_mode = PRESENTATION_SOURCE_RUNTIME_MISSING
		return
	_presentation_consumer = PresentationConsumer.new()
	_presentation_consumer.name = (
		"V075IsolatedPreviewPresentationConsumer"
	)
	add_child(_presentation_consumer)
	_presentation_source_mode = PRESENTATION_SOURCE_ISOLATED_PREVIEW
	_presentation_local_preview_creation_count += 1
	_connect_presentation_signal()


func _release_presentation_source() -> void:
	var previous_consumer := _presentation_consumer
	var previous_mode := _presentation_source_mode
	var cue_callback := Callable(self, "_on_presentation_cue_ready")
	if (
		is_instance_valid(previous_consumer)
		and previous_consumer.has_signal("presentation_cue_ready")
		and previous_consumer.is_connected(
			"presentation_cue_ready",
			cue_callback
		)
	):
		previous_consumer.disconnect(
			"presentation_cue_ready",
			cue_callback
		)
	if (
		previous_mode == PRESENTATION_SOURCE_ISOLATED_PREVIEW
		and is_instance_valid(previous_consumer)
		and previous_consumer.get_parent() == self
	):
		previous_consumer.queue_free()
	_presentation_consumer = null
	_presentation_consumer_owner = null
	_presentation_signal_connected = false
	_presentation_source_mode = PRESENTATION_SOURCE_UNBOUND


func _connect_presentation_signal() -> void:
	if (
		not is_instance_valid(_presentation_consumer)
		or not _presentation_consumer.has_signal(
			"presentation_cue_ready"
		)
	):
		return
	var cue_callback := Callable(self, "_on_presentation_cue_ready")
	if not _presentation_consumer.is_connected(
		"presentation_cue_ready",
		cue_callback
	):
		_presentation_consumer.connect(
			"presentation_cue_ready",
			cue_callback
		)
	_presentation_signal_connected = (
		_presentation_consumer.is_connected(
			"presentation_cue_ready",
			cue_callback
		)
	)


func _runtime_presentation_binding(flow: Node) -> Dictionary:
	if not is_instance_valid(flow):
		return {}
	var pending: Array[Node] = [flow]
	var cursor := 0
	while cursor < pending.size():
		var candidate := pending[cursor]
		cursor += 1
		if candidate.has_method("combat_presentation_consumer"):
			var consumer_variant: Variant = candidate.call(
				"combat_presentation_consumer"
			)
			return {
				"owner": candidate,
				"consumer": (
					consumer_variant as Node
					if consumer_variant is Node
					else null
				),
			}
		for child_variant in candidate.get_children():
			if child_variant is Node:
				pending.append(child_variant as Node)
	return {}


func _is_isolated_preview_flow(flow: Node) -> bool:
	if not is_instance_valid(flow):
		return false
	if bool(flow.get_meta("v075_isolated_preview_flow", false)):
		return true
	if (
		flow.has_method("local_snapshot")
		or flow.has_method("capability_snapshot")
		or flow.has_method("planet_map_view_payload")
	):
		return false
	var flow_script: Variant = flow.get_script()
	if flow_script is Script:
		var script_path := (flow_script as Script).resource_path
		if (
			script_path.begins_with("res://tests/")
			or script_path.begins_with("res://scripts/tools/")
		):
			return true
	return flow.has_method("issue_intent")


func _presentation_signal_is_connected() -> bool:
	if (
		not _presentation_signal_connected
		or not is_instance_valid(_presentation_consumer)
		or not _presentation_consumer.has_signal(
			"presentation_cue_ready"
		)
	):
		return false
	return _presentation_consumer.is_connected(
		"presentation_cue_ready",
		Callable(self, "_on_presentation_cue_ready")
	)


func _presentation_source_identity_green() -> bool:
	if (
		_presentation_source_mode != PRESENTATION_SOURCE_RUNTIME_SHARED
		or not is_instance_valid(_presentation_consumer_owner)
		or not is_instance_valid(_presentation_consumer)
		or not _presentation_consumer_owner.has_method(
			"combat_presentation_consumer"
		)
	):
		return false
	return (
		_presentation_consumer_owner.call(
			"combat_presentation_consumer"
		) == _presentation_consumer
	)


func _update_acceptance_state() -> void:
	super._update_acceptance_state()
	acceptance_state["schema"] = "V075SampleAcceptanceStateV1"
	acceptance_state["ruleset_id"] = V075_RULESET_ID
	acceptance_state["combat_wrapper"] = combat_debug_snapshot()
	acceptance_state["combat_direct_runtime_owner_count"] = 0
	acceptance_state["combat_direct_rng_owner_count"] = 0


func _on_presentation_cue_ready(cue: Dictionary) -> void:
	if is_instance_valid(_combat_surface):
		_combat_surface.call("show_presentation_cue", cue)


func _on_private_target_selection_requested(request: Dictionary) -> void:
	if _is_combat_terminal():
		return
	var source_instance_id := str(request.get("source_instance_id", ""))
	var skill_definition_id := str(request.get("skill_definition_id", ""))
	var target_binding := request.get("target_binding", {}) as Dictionary
	if (
		source_instance_id.is_empty()
		or skill_definition_id.is_empty()
		or target_binding.is_empty()
	):
		return
	var parameters := request.duplicate(true)
	parameters["execution_mode"] = _private_skill_execution_mode()
	var intent := _issue_combat_intent(
		_private_skill_intent_kind(),
		parameters,
		true
	)
	if intent.is_empty():
		return
	_combat_private_intent_count += 1
	_combat_status.text = "私密技能请求已交给安全边界"
	_update_acceptance_state()


func _on_military_mission_selected(option: Dictionary) -> void:
	var task_kind := str(option.get("task_kind", ""))
	if _is_combat_terminal() or task_kind not in [
		"assault_region",
		"assault_monster",
	]:
		return
	if (
		str(option.get("option_id", "")).is_empty()
		or str(option.get("card_instance_id", "")).is_empty()
		or str(option.get("target_slot_id", "")).is_empty()
	):
		return
	var parameters := option.duplicate(true)
	parameters["execution_mode"] = _military_execution_mode()
	var intent := _issue_combat_intent(
		_military_intent_kind(),
		parameters,
		false
	)
	if intent.is_empty():
		return
	_combat_military_intent_count += 1
	_combat_status.text = (
		"攻击地区" if task_kind == "assault_region" else "攻击怪兽"
	) + " · 已提交普通行动"
	_update_acceptance_state()


func _issue_combat_intent(
	intent_kind: String,
	parameters: Dictionary,
	private_intent: bool
) -> Dictionary:
	var intent_variant: Variant = null
	if is_instance_valid(_v075_flow) and _v075_flow.has_method("issue_intent"):
		intent_variant = _v075_flow.call(
			"issue_intent",
			intent_kind,
			parameters
		)
	else:
		_fallback_intent_sequence += 1
		intent_variant = {
			"schema": "V075CombatIntentV1",
			"intent_id": "intent.v075.combat.%06d" % _fallback_intent_sequence,
			"intent_kind": intent_kind,
			"ruleset_id": V075_RULESET_ID,
			"parameters": parameters.duplicate(true),
		}
	if not (intent_variant is Dictionary):
		return {}
	var intent := (intent_variant as Dictionary).duplicate(true)
	intent["combat_channel"] = (
		"private_instant_serial" if private_intent else "public_batch"
	)
	_last_combat_intent_kind = intent_kind
	application_intent_requested.emit(intent.duplicate(true))
	return intent


func _private_skill_execution_mode() -> String:
	var combat_capabilities := _v075_capabilities.get("combat", {}) as Dictionary
	return str(combat_capabilities.get(
		"private_skill_execution_mode",
		PRIVATE_SKILL_EXECUTION_MODE
	))


func _military_execution_mode() -> String:
	var combat_capabilities := _v075_capabilities.get("combat", {}) as Dictionary
	return str(combat_capabilities.get(
		"military_execution_mode",
		MILITARY_EXECUTION_MODE
	))


func _extract_combat_projection(snapshot: Dictionary) -> Dictionary:
	for key in COMBAT_PROJECTION_KEYS:
		var candidate: Variant = snapshot.get(key, {})
		if candidate is Dictionary:
			var normalized := _normalize_projection(candidate as Dictionary)
			if not normalized.is_empty():
				return normalized
	for key in COMBAT_AUTHORITY_KEYS:
		var authority: Variant = snapshot.get(key, {})
		if authority is Dictionary:
			return _project_authority(authority as Dictionary)
	var combat: Variant = snapshot.get("combat", {})
	if combat is Dictionary:
		var combat_dict := combat as Dictionary
		for key in ["projection", "player_projection"]:
			var nested_projection: Variant = combat_dict.get(key, {})
			if nested_projection is Dictionary:
				var normalized_nested := _normalize_projection(
					nested_projection as Dictionary
				)
				if not normalized_nested.is_empty():
					return normalized_nested
		for key in ["authority_snapshot", "authority"]:
			var nested_authority: Variant = combat_dict.get(key, {})
			if nested_authority is Dictionary:
				return _project_authority(nested_authority as Dictionary)
		var normalized_combat := _normalize_projection(combat_dict)
		if not normalized_combat.is_empty():
			return normalized_combat
	return {}


func _project_authority(authority_snapshot: Dictionary) -> Dictionary:
	return _projection_adapter.call(
		"project_for_viewer",
		authority_snapshot,
		_viewer_player_id
	) as Dictionary


func _normalize_projection(candidate: Dictionary) -> Dictionary:
	if candidate.is_empty():
		return {}
	var schema := str(candidate.get("schema", ""))
	if (
		schema == "V075CombatPlayerProjectionV1"
		or candidate.has("own_monster_skill_sources")
		or candidate.has("military_task_options")
	):
		var projection := candidate.duplicate(true)
		projection["schema"] = "V075CombatPlayerProjectionV1"
		projection["ruleset_id"] = V075_RULESET_ID
		if str(projection.get("viewer_player_id", "")).is_empty():
			projection["viewer_player_id"] = _viewer_player_id
		return projection
	if candidate.has("public_monsters") or candidate.has("monsters"):
		return _project_authority(candidate)
	return {}


func _parent_compatibility_snapshot(snapshot: Dictionary) -> Dictionary:
	var compatible := snapshot.duplicate(true)
	compatible["ruleset_id"] = BASE_V074_RULESET_ID
	var phase := str(compatible.get("phase", "idle"))
	compatible["phase"] = _parent_phase(phase)
	return compatible


func _parent_phase(phase: String) -> String:
	match phase:
		"batch_active", "maintenance_before_autonomy":
			return "resolving"
		"public_resolution_between_receipts":
			return "resolving"
		"victory_pending", "victory_resolved", "final_settlement", "terminal":
			return "settled"
	return phase


func _resolve_viewer_player_id(identity: Dictionary, flow: Node) -> String:
	for key in ["viewer_player_id", "local_player_id", "player_id", "actor_id"]:
		var value := str(identity.get(key, ""))
		if not value.is_empty():
			return value
	if is_instance_valid(flow) and flow.has_method("local_player_id"):
		var flow_player_id := str(flow.call("local_player_id"))
		if not flow_player_id.is_empty():
			return flow_player_id
	return DEFAULT_VIEWER_ID


func _first_owned_source_id(projection: Dictionary) -> String:
	for source_variant in projection.get(
		"own_monster_skill_sources",
		[]
	) as Array:
		if source_variant is Dictionary:
			var source_id := str(
				(source_variant as Dictionary).get("source_instance_id", "")
			)
			if not source_id.is_empty():
				return source_id
	return ""


func _projection_status(projection: Dictionary) -> String:
	var public_count := int(projection.get("public_monster_count", 0))
	var own_count := int(
		projection.get("own_private_skill_source_count", 0)
	)
	return "公开怪兽 %d · 所有者技能源 %d" % [public_count, own_count]


func _projection_for_phase(
	projection: Dictionary,
	phase: String
) -> Dictionary:
	if phase not in TERMINAL_PHASES:
		return projection
	var quiescent := projection.duplicate(true)
	quiescent["combat_requests_allowed"] = false
	quiescent["terminal_combat_quiescent"] = true
	var skill_sources: Array[Dictionary] = []
	for source_variant in quiescent.get(
		"own_monster_skill_sources",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := (source_variant as Dictionary).duplicate(true)
		var skills: Array[Dictionary] = []
		for skill_variant in source.get("skills", []) as Array:
			if not (skill_variant is Dictionary):
				continue
			var skill := (skill_variant as Dictionary).duplicate(true)
			skill["can_request"] = false
			skills.append(skill)
		source["skills"] = skills
		skill_sources.append(source)
	quiescent["own_monster_skill_sources"] = skill_sources
	var military_options: Array[Dictionary] = []
	for option_variant in quiescent.get(
		"military_task_options",
		[]
	) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := (option_variant as Dictionary).duplicate(true)
		option["enabled"] = false
		military_options.append(option)
	quiescent["military_task_options"] = military_options
	return quiescent


func _set_v075_chrome() -> void:
	_ruleset_label.text = "v0.7.5 · NEW GAME ONLY"
	_save_notice.text = "V0.7.5样品暂不支持中途保存"
	%Subtitle.text = "V0.7.5 · 真人战斗候选"
	%PersistenceNotice.text = "V0.7.5样品暂不支持中途保存"


func _clear_combat_projection() -> void:
	_combat_projection = {}
	_preferred_source_instance_id = ""
	_combat_collapsed = true
	if is_instance_valid(_combat_surface):
		_combat_surface.call(
			"apply_projection",
			{
				"schema": "V075CombatPlayerProjectionV1",
				"ruleset_id": V075_RULESET_ID,
				"viewer_player_id": _viewer_player_id,
				"phase": "idle",
				"combat_requests_allowed": false,
				"terminal_combat_quiescent": false,
				"public_monsters": [],
				"own_monster_skill_sources": [],
				"military_task_options": [],
				"public_monster_count": 0,
				"own_private_skill_source_count": 0,
			},
			""
		)
	_combat_status.text = "等待战斗投影"
	_set_combat_surface_visibility()


func _update_combat_session(snapshot: Dictionary) -> void:
	var session_key := str(
		snapshot.get(
			"session_id",
			snapshot.get("match_id", snapshot.get("game_id", ""))
		)
	)
	if (
		not session_key.is_empty()
		and not _combat_session_key.is_empty()
		and session_key != _combat_session_key
	):
		_reset_combat_state()
	if not session_key.is_empty():
		_combat_session_key = session_key
	if str(snapshot.get("phase", "")) == "idle":
		if not _combat_terminal_phase.is_empty():
			_reset_combat_state()


func _sync_terminal_phase(phase: String) -> void:
	if phase in TERMINAL_PHASES:
		_combat_terminal_phase = phase
		if (
			_presentation_source_mode
				== PRESENTATION_SOURCE_ISOLATED_PREVIEW
			and is_instance_valid(_presentation_consumer)
		):
			_presentation_consumer.call("set_terminal_phase", phase)
	elif phase in ["idle", "submission", "batch_active", "maintenance"]:
		if not _combat_terminal_phase.is_empty():
			_reset_combat_state()


func _is_combat_terminal() -> bool:
	return not _combat_terminal_phase.is_empty()


func _reset_combat_state() -> void:
	_combat_terminal_phase = ""
	if (
		_presentation_source_mode
			== PRESENTATION_SOURCE_ISOLATED_PREVIEW
		and is_instance_valid(_presentation_consumer)
	):
		_presentation_consumer.call("reset_for_new_match")
	if (
		is_instance_valid(_combat_surface)
		and _combat_surface.has_method("reset_presentation_cues")
	):
		_combat_surface.call("reset_presentation_cues")
	_clear_combat_projection()


func _is_combat_receipt(receipt: Dictionary) -> bool:
	var event_kind := str(receipt.get("event_kind", receipt.get("kind", "")))
	return (
		not str(receipt.get("combat_receipt_id", "")).is_empty()
		or event_kind in COMBAT_EVENT_KINDS
	)


func _private_skill_intent_kind() -> String:
	var combat_capabilities := _v075_capabilities.get("combat", {}) as Dictionary
	return str(combat_capabilities.get(
		"private_skill_intent_kind",
		DEFAULT_PRIVATE_SKILL_INTENT_KIND
	))


func _military_intent_kind() -> String:
	var combat_capabilities := _v075_capabilities.get("combat", {}) as Dictionary
	return str(combat_capabilities.get(
		"military_intent_kind",
		DEFAULT_MILITARY_INTENT_KIND
	))


func _set_combat_surface_visibility() -> void:
	if not is_instance_valid(_combat_surface):
		return
	_combat_surface.visible = not _combat_collapsed
	_combat_collapse_button.text = "展开" if _combat_collapsed else "收起"
	_combat_collapse_button.tooltip_text = (
		"展开战斗投影" if _combat_collapsed else "收起战斗投影"
	)


func _toggle_combat_surface() -> void:
	_combat_collapsed = not _combat_collapsed
	_set_combat_surface_visibility()
	_resolve_combat_layout()


func _resolve_combat_layout() -> void:
	if not is_instance_valid(_combat_overlay):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var table_area := $RootMargin/Shell/TableArea as Control
	var dock_panel := $RootMargin/Shell/DockPanel as Control
	var planet_stage := $RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport as Control
	var layout := _combat_layout_for_geometry(
		viewport_size,
		table_area.get_global_rect(),
		planet_stage.get_global_rect() if planet_stage != null else table_area.get_global_rect(),
		dock_panel.get_global_rect(),
		_combat_collapsed
	)
	_combat_layout_snapshot = layout.duplicate(true)
	_combat_layout_mode = str(layout.get("layout_mode", "COMPACT"))
	var panel_rect := layout.get("panel_rect", Rect2()) as Rect2
	var safe_area := $PlaytestUtilityLayer/PlaytestSafeArea as Control
	var safe_origin := safe_area.global_position if safe_area != null else Vector2.ZERO
	_combat_overlay.position = panel_rect.position - safe_origin
	_combat_overlay.size = panel_rect.size
	_combat_surface_host.custom_minimum_size = Vector2(0.0, 0.0)
	if _combat_surface_host is ScrollContainer:
		_combat_surface.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_WIDE
		)
		_combat_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_combat_surface.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var content_height := 410.0
		if _combat_surface.has_method("preferred_content_height"):
			content_height = float(
				_combat_surface.call("preferred_content_height")
			)
		_combat_surface.custom_minimum_size = Vector2(
			0.0,
			content_height
		)
	else:
		_combat_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_combat_surface.custom_minimum_size = Vector2(0.0, 0.0)


func v075_combat_layout_for_geometry(
	viewport_size: Vector2,
	table_rect: Rect2,
	planet_stage_rect: Rect2,
	dock_rect: Rect2
) -> Dictionary:
	return _combat_layout_for_geometry(
		viewport_size,
		table_rect,
		planet_stage_rect,
		dock_rect
	)


func _combat_layout_for_geometry(
	viewport_size: Vector2,
	table_rect: Rect2,
	planet_stage_rect: Rect2,
	dock_rect: Rect2,
	collapsed := false
) -> Dictionary:
	var resolved_viewport := Vector2(
		maxf(1.0, viewport_size.x),
		maxf(1.0, viewport_size.y)
	)
	var compact := resolved_viewport.x < 1180.0
	var layout_mode := "COMPACT" if compact else "REGULAR"
	var panel_width := clampf(
		resolved_viewport.x * 0.39,
		COMBAT_LAYOUT_MIN_WIDTH,
		COMBAT_LAYOUT_MAX_WIDTH
	)
	if resolved_viewport.x < 720.0:
		panel_width = maxf(0.0, resolved_viewport.x - 20.0)
	var requested_panel_width := panel_width
	var panel_height := clampf(
		resolved_viewport.y * 0.52,
		300.0,
		500.0
	)
	var top_clearance := 96.0
	var table_top := maxf(top_clearance, table_rect.position.y)
	var panel_bottom := minf(
		resolved_viewport.y - 12.0,
		dock_rect.position.y - 8.0
	)
	var available_height := maxf(46.0, panel_bottom - table_top)
	panel_height = minf(panel_height, available_height)
	if collapsed:
		panel_height = 46.0
	var primary_planet_rect := _combat_primary_planet_rect(
		planet_stage_rect
	)
	var left := maxf(10.0, table_rect.position.x)
	var width_limit := (
		primary_planet_rect.position.x - 14.0 - left
		if primary_planet_rect.size.x > 0.0
		else resolved_viewport.x - left - 10.0
	)
	if width_limit > 0.0:
		panel_width = minf(panel_width, width_limit)
	var top := maxf(table_top, panel_bottom - panel_height)
	var panel_rect := Rect2(
		Vector2(left, top),
		Vector2(panel_width, panel_height)
	)
	var planet_right_half := Rect2(
		planet_stage_rect.position
			+ Vector2(planet_stage_rect.size.x * 0.5, 0.0),
		Vector2(
			planet_stage_rect.size.x * 0.5,
			planet_stage_rect.size.y
		)
	)
	return {
		"schema": "V075CombatLayoutGeometryV1",
		"layout_mode": layout_mode,
		"panel_anchor": "left_utility_lane",
		"panel_rect": panel_rect,
		"requested_panel_width": requested_panel_width,
		"panel_width": panel_width,
		"panel_height": panel_height,
		"primary_planet_rect": primary_planet_rect,
		"primary_planet_occlusion_count": int(
			panel_rect.intersects(primary_planet_rect)
		),
		"planet_right_half_occlusion_count": int(
			panel_rect.intersects(planet_right_half)
		),
		"panel_viewport_overflow_count": int(
			not Rect2(Vector2.ZERO, resolved_viewport).encloses(panel_rect)
		),
		"panel_min_width_green": (
			panel_width >= COMBAT_LAYOUT_MIN_WIDTH
			or resolved_viewport.x < 720.0
		),
		"two_column_information_contract": "preserved",
		"track_and_asset_surfaces_untouched": true,
	}


func _combat_primary_planet_rect(planet_stage_rect: Rect2) -> Rect2:
	if planet_stage_rect.size.x <= 0.0 or planet_stage_rect.size.y <= 0.0:
		return Rect2()
	return Rect2(
		planet_stage_rect.position
			+ Vector2(
				planet_stage_rect.size.x
					* COMBAT_LAYOUT_PRIMARY_PLANET_INSET_X,
				planet_stage_rect.size.y
					* COMBAT_LAYOUT_PRIMARY_PLANET_INSET_Y
			),
		Vector2(
			planet_stage_rect.size.x
				* COMBAT_LAYOUT_PRIMARY_PLANET_WIDTH,
			planet_stage_rect.size.y
				* COMBAT_LAYOUT_PRIMARY_PLANET_HEIGHT
		)
	)


func _configure_planet_shell() -> void:
	if _planet_board.has_method("set_board_state"):
		_planet_board.call("set_board_state", {
			"title": "V0.7.5 动态行星",
			"hint": "MAP %s" % str(
				_v075_snapshot.get("map_fingerprint", "")
			).left(12),
			"left_rail": {"hidden": true},
			"right_rail": {"hidden": true},
			"flow_compass": {"hidden": true},
		})


func _apply_responsive_layout() -> void:
	super._apply_responsive_layout()
	_set_v075_chrome()
# V0.7.5 combat cards use the authoritative registry domain before falling
# back to the inherited facility renderer. This keeps the public card face
# aligned with the combat definition without changing supply or projection.
func _v075_card_definition(definition_id: String) -> Dictionary:
	if definition_id.is_empty():
		return {}
	return V075CardDefinitionRegistry.definition(definition_id)


func _v075_card_domain(definition_id: String) -> String:
	var definition := _v075_card_definition(definition_id)
	if definition.is_empty():
		return ""
	return V075CardDefinitionRegistry.card_domain(
		str(definition.get("card_type", ""))
	)


func _v075_combat_card_art_path(domain: String) -> String:
	match domain:
		"monster":
			return V075_MONSTER_CARD_ART_PATH
		"military":
			return V075_MILITARY_CARD_ART_PATH
	return ""


func _card_type_label(definition_id: String) -> String:
	match _v075_card_domain(definition_id):
		"monster":
			return "怪兽"
		"military":
			return "军队"
	return super._card_type_label(definition_id)


func _card_art(item: Dictionary) -> Texture2D:
	var definition_id := str(item.get("card_definition_id", ""))
	var domain := _v075_card_domain(definition_id)
	var combat_art_path := _v075_combat_card_art_path(domain)
	if not combat_art_path.is_empty():
		var combat_art := _texture(combat_art_path)
		if combat_art != null:
			return combat_art
	return super._card_art(item)


func v075_card_presentation_audit(item: Dictionary) -> Dictionary:
	var definition_id := str(item.get("card_definition_id", ""))
	var definition := _v075_card_definition(definition_id)
	var card_type := str(definition.get("card_type", ""))
	var domain := _v075_card_domain(definition_id)
	var art := _card_art(item)
	var art_path := str(art.resource_path) if art != null else ""
	var mapped_path := _v075_combat_card_art_path(domain)
	var uses_facility_art := (
		art_path in V075_FACILITY_ART_PATHS
		or mapped_path in V075_FACILITY_ART_PATHS
	)
	return {
		"schema": "V075CardPresentationAuditV1",
		"local_slot_index": int(item.get("local_slot_index", -1)),
		"card_definition_id": definition_id,
		"card_type": card_type,
		"domain": domain,
		"type_label": _card_type_label(definition_id),
		"art_present": art != null,
		"art_resource_path": art_path,
		"stable_mapping_path": mapped_path,
		"uses_facility_art": uses_facility_art,
		"combat_art_mapping_green": (
			domain in ["monster", "military"]
			and art != null
			and not uses_facility_art
			and not mapped_path.is_empty()
		),
	}
