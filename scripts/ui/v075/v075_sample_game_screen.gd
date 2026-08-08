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
const MONSTER_CARD_MODES := [
	"DEPLOY_NEW",
	"REFRESH_EXISTING",
	"UPGRADE_EXISTING",
	"REPLACE_EXISTING",
]
const MONSTER_CARD_MODE_LABELS := {
	"DEPLOY_NEW": "部署新怪兽",
	"REFRESH_EXISTING": "同族回血",
	"UPGRADE_EXISTING": "同族升级",
	"REPLACE_EXISTING": "异族替换",
}
const MONSTER_CARD_MODE_HINTS := {
	"DEPLOY_NEW": "容量以内且没有同族活动来源时，在预绑定地区部署",
	"REFRESH_EXISTING": "同族等级不高于当前来源，按牌面等级恢复生命",
	"UPGRADE_EXISTING": "同族牌等级更高，升至牌面等级并恢复新最大生命",
	"REPLACE_EXISTING": "容量已满且族群不同，撤回旧来源并部署新来源",
}

const ProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const V075CardDefinitionRegistry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const V075_FACILITY_ART_PATHS := [
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "MetalPlates013/MetalPlates013_1K-JPG_Color.jpg",
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "PaintedMetal007/PaintedMetal007_1K-JPG_Color.jpg",
	"res://assets/third_party/commercial/materials/ambientcg/"
	+ "SheetMetal003/SheetMetal003_1K-JPG_Color.jpg",
]
const COMBAT_LAYOUT_MAX_WIDTH := 668.0
const COMBAT_LAYOUT_NARROW_MAX_WIDTH := 720.0
const COMBAT_LAYOUT_REGULAR_MIN_WIDTH := 1480.0
const COMBAT_LAYOUT_HORIZONTAL_GUTTER := 12.0
const COMBAT_LAYOUT_MIN_HEIGHT := 300.0
const COMBAT_LAYOUT_MAX_HEIGHT := 500.0
const GEOMETRY_INTERSECTION_EPSILON := 0.5
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
const COMBAT_MAP_CUE_HISTORY_LIMIT := 12
const COMBAT_MAP_COLOR_VALUES := {
	"life": Color("#76d89b"),
	"energy": Color("#f3cd68"),
	"industry": Color("#f08a74"),
	"technology": Color("#7fb6ff"),
	"commerce": Color("#d993ef"),
	"shipping": Color("#67d8d5"),
}
const COMBAT_MAP_DEFAULT_COLOR := Color("#74d9c6")

@onready var _combat_overlay: PanelContainer = (
	%V075CombatOverlay
)
@onready var _combat_stack_host: HBoxContainer = %V075CombatStackHost
@onready var _combat_surface_host: Control = (
	%SurfaceHost
)
@onready var _combat_surface: Control = (
	%CombatSurface
)
@onready var _combat_title: Label = (
	%Title
)
@onready var _combat_status: Label = (
	%Status
)
@onready var _combat_collapse_button: Button = (
	%CollapseButton
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
var _combat_surface_preferred_height := -1.0
var _combat_layout_remeasure_scheduled := false
var _combat_host_layout_settle_scheduled := false
var _fallback_intent_sequence := 0
var _combat_projection_count := 0
var _combat_receipt_count := 0
var _combat_receipt_applied_count := 0
var _combat_receipt_duplicate_count := 0
var _combat_receipt_rejected_count := 0
var _combat_private_intent_count := 0
var _combat_military_intent_count := 0
var _last_combat_intent_kind := ""
var _monster_mode_popup_card_id := ""
var _combat_map_cues: Array[Dictionary] = []
var _combat_map_projection_apply_count := 0
var _combat_map_cue_apply_count := 0
var _combat_map_marker_count := 0
var _combat_map_trail_count := 0
var _combat_map_effect_count := 0
var _combat_map_callout_count := 0
var _combat_map_last_sync_signature := ""


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
		if _combat_surface.has_signal("responsive_minimum_resolved"):
			_combat_surface.connect(
				"responsive_minimum_resolved",
				Callable(self, "_on_combat_surface_minimum_resolved")
			)
	_combat_collapse_button.pressed.connect(_toggle_combat_surface)
	get_viewport().size_changed.connect(_on_combat_viewport_size_changed)
	super._ready()
	_dock_target_rail_in_production_flow()
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
		str(receipt.get("intent_kind", "")) == "card.queue"
		and bool(receipt.get("accepted", false))
		and str((receipt.get("binding", {}) as Dictionary).get(
			"action_domain",
			""
		)) == "monster"
	):
		_region_popup.visible = false
		_monster_mode_popup_card_id = ""
		_clear_selected_card()
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
	_sync_combat_map_projection()
	combat_projection_applied.emit(normalized.duplicate(true))
	_resolve_combat_layout()
	# CombatSurface resolves its narrow grid on a deferred pass. Re-measure its
	# combined minimum after that pass so SurfaceHost selects fill vs scroll from
	# the final content height, not the previous frame's shape.
	call_deferred("_resolve_combat_layout")


func apply_combat_authority_snapshot(
	authority_snapshot: Dictionary,
	viewer_player_id := "",
	preferred_source_instance_id := ""
) -> void:
	if (
		not viewer_player_id.is_empty()
		and viewer_player_id != _viewer_player_id
	):
		return
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
		"combat_map_projection_apply_count":
			_combat_map_projection_apply_count,
		"combat_map_cue_apply_count": _combat_map_cue_apply_count,
		"combat_map_cue_history_count": _combat_map_cues.size(),
		"combat_map_marker_count": _combat_map_marker_count,
		"combat_map_trail_count": _combat_map_trail_count,
		"combat_map_effect_count": _combat_map_effect_count,
		"combat_map_callout_count": _combat_map_callout_count,
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
	var cue_result := {
		"applied": true,
	}
	if is_instance_valid(_combat_surface):
		cue_result = _combat_surface.call(
			"show_presentation_cue",
			cue
		) as Dictionary
	if not bool(cue_result.get("applied", false)):
		return
	_combat_map_cues.append(cue.duplicate(true))
	while _combat_map_cues.size() > COMBAT_MAP_CUE_HISTORY_LIMIT:
		_combat_map_cues.pop_front()
	_combat_map_cue_apply_count += 1
	_sync_combat_map_projection()


func _on_private_target_selection_requested(request: Dictionary) -> void:
	if _is_combat_terminal():
		return
	var canonical_request := _current_private_skill_request(request)
	if canonical_request.is_empty():
		return
	var parameters := canonical_request.duplicate(true)
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
	var canonical_option := _current_military_option(option)
	if canonical_option.is_empty():
		return
	var parameters := canonical_option.duplicate(true)
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


func _current_private_skill_request(candidate: Dictionary) -> Dictionary:
	if (
		candidate.is_empty()
		or str(_combat_projection.get("viewer_player_id", ""))
			!= _viewer_player_id
	):
		return {}
	var source_id := str(candidate.get("source_instance_id", ""))
	var source_generation := int(candidate.get("source_generation", 0))
	var skill_id := str(candidate.get("skill_definition_id", ""))
	if (
		source_id.is_empty()
		or source_id != _preferred_source_instance_id
		or not _positive_int_field(candidate, "source_generation")
		or skill_id.is_empty()
	):
		return {}
	var public_source := _combat_public_source(source_id)
	if (
		public_source.is_empty()
		or str(public_source.get("owner_player_id", "")) != _viewer_player_id
		or not _positive_int_field(public_source, "source_generation")
		or public_source.get("source_generation")
			!= candidate.get("source_generation")
	):
		return {}
	for source_variant in _combat_projection.get(
		"own_monster_skill_sources",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if (
			str(source.get("source_instance_id", "")) != source_id
			or str(source.get("owner_player_id", "")) != _viewer_player_id
			or not _positive_int_field(source, "source_generation")
			or source.get("source_generation")
				!= candidate.get("source_generation")
		):
			continue
		for skill_variant in source.get("skills", []) as Array:
			if not (skill_variant is Dictionary):
				continue
			var skill := skill_variant as Dictionary
			if (
				str(skill.get("skill_definition_id", "")) != skill_id
				or not bool(skill.get("can_request", false))
				or str(skill.get("state", "")) != "READY"
			):
				continue
			var expected_binding := skill.get("target_binding", {}) as Dictionary
			var requested_binding := candidate.get(
				"target_binding",
				{}
			) as Dictionary
			var expected_contract := skill.get("target_contract", {}) as Dictionary
			var requested_contract := candidate.get(
				"target_contract",
				{}
			) as Dictionary
			if (
				expected_binding.is_empty()
				or not _same_flat_dictionary(
					requested_binding,
					expected_binding
				)
				or not _same_flat_dictionary(
					requested_contract,
					expected_contract
				)
			):
				return {}
			return {
				"source_instance_id": source_id,
				"source_generation": source_generation,
				"skill_definition_id": skill_id,
				"target_binding": expected_binding.duplicate(true),
				"target_contract": expected_contract.duplicate(true),
			}
	return {}


func _current_military_option(candidate: Dictionary) -> Dictionary:
	if (
		candidate.is_empty()
		or str(_combat_projection.get("viewer_player_id", ""))
			!= _viewer_player_id
		or str(candidate.get("owner_player_id", "")) != _viewer_player_id
		or str(candidate.get("action_domain", "")) != "military"
		or not _card_action_binding_valid(candidate, _viewer_player_id)
	):
		return {}
	var task_kind := str(candidate.get("task_kind", ""))
	if (
		(task_kind == "assault_monster" and (
			not _positive_int_field(candidate, "target_source_generation")
		))
		or (task_kind == "assault_region" and candidate.has(
			"target_source_generation"
		))
		or task_kind not in ["assault_region", "assault_monster"]
	):
		return {}
	for option_variant in _combat_projection.get(
		"military_task_options",
		[]
	) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if (
			bool(option.get("enabled", false))
			and _same_military_option_identity(candidate, option)
		):
			return option.duplicate(true)
	return {}


func _same_military_option_identity(
	left: Dictionary,
	right: Dictionary
) -> bool:
	for field_name in [
		"option_id",
		"owner_player_id",
		"card_instance_id",
		"card_definition_id",
		"target_slot_id",
		"task_kind",
		"target_region_id",
		"target_monster_source_instance_id",
		"action_domain",
	]:
		if str(left.get(field_name, "")) != str(right.get(field_name, "")):
			return false
	if (
		not _card_action_binding_valid(
			left,
			str(left.get("owner_player_id", ""))
		)
		or not _card_action_binding_valid(
			right,
			str(right.get("owner_player_id", ""))
		)
		or left.get("card_action_binding") != right.get("card_action_binding")
	):
		return false
	if str(left.get("task_kind", "")) == "assault_region":
		return (
			not left.has("target_source_generation")
			and not right.has("target_source_generation")
		)
	return (
		_positive_int_field(left, "target_source_generation")
		and _positive_int_field(right, "target_source_generation")
		and left.get("target_source_generation")
			== right.get("target_source_generation")
	)


func _card_action_binding_valid(
	option: Dictionary,
	expected_owner_id: String
) -> bool:
	var binding_variant: Variant = option.get("card_action_binding")
	if not (binding_variant is Dictionary):
		return false
	var binding := binding_variant as Dictionary
	return (
		not binding.is_empty()
		and str(binding.get("owner_player_id", "")) == expected_owner_id
		and str(binding.get("card_instance_id", ""))
			== str(option.get("card_instance_id", ""))
		and str(binding.get("card_definition_id", ""))
			== str(option.get("card_definition_id", ""))
		and binding.get("authoritative_zone") == "hand"
		and _positive_int_field(binding, "zone_revision")
		and str(binding.get("binding_fingerprint", "")).length() == 64
	)


func _positive_int_field(source: Dictionary, field_name: String) -> bool:
	return (
		source.has(field_name)
		and typeof(source.get(field_name)) == TYPE_INT
		and int(source.get(field_name)) > 0
	)


func _combat_public_source(source_instance_id: String) -> Dictionary:
	for source_variant in _combat_projection.get("public_monsters", []) as Array:
		if (
			source_variant is Dictionary
			and str((source_variant as Dictionary).get(
				"source_instance_id",
				""
			)) == source_instance_id
		):
			return (source_variant as Dictionary).duplicate(true)
	return {}


func _same_flat_dictionary(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key_variant in left.keys():
		if (
			not right.has(key_variant)
			or left.get(key_variant) != right.get(key_variant)
		):
			return false
	return true


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
		var candidate_viewer_id := str(
			candidate.get("viewer_player_id", "")
		)
		if (
			candidate_viewer_id.is_empty()
			or candidate_viewer_id != _viewer_player_id
		):
			return {}
		var projection := candidate.duplicate(true)
		projection["schema"] = "V075CombatPlayerProjectionV1"
		projection["ruleset_id"] = V075_RULESET_ID
		var privacy := _projection_adapter.call(
			"privacy_report",
			projection
		) as Dictionary
		if not bool(privacy.get("valid", false)):
			return {}
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
	quiescent["terminal_combat_quiescent"] = bool(
		projection.get("terminal_combat_quiescent", false)
	)
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
	_sync_combat_map_projection()


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
	_combat_map_cues.clear()
	_combat_map_last_sync_signature = ""
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
	# Containers finish the expanded/collapsed minimum-size negotiation on the
	# following frame. Re-measure once so a populated surface cannot retain the
	# previous state's fill-vs-scroll decision.
	call_deferred("_resolve_combat_layout")


func _on_combat_viewport_size_changed() -> void:
	_resolve_combat_layout()
	# The private grid also changes its column count on resize. Its combined
	# minimum is authoritative only after that deferred container pass.
	call_deferred("_resolve_combat_layout")


func _on_combat_surface_minimum_resolved(preferred_height: float) -> void:
	_combat_surface_preferred_height = maxf(410.0, preferred_height)
	if _combat_layout_remeasure_scheduled:
		return
	_combat_layout_remeasure_scheduled = true
	call_deferred("_remeasure_combat_layout_from_surface")


func _remeasure_combat_layout_from_surface() -> void:
	_combat_layout_remeasure_scheduled = false
	_resolve_combat_layout()


func _resolve_combat_layout() -> void:
	if (
		not is_instance_valid(_combat_overlay)
		or not is_instance_valid(_combat_stack_host)
	):
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var root_scroll := $RootMargin as ScrollContainer
	var layout := _combat_layout_plan(
		viewport_size,
		root_scroll.get_global_rect().size,
		_combat_collapsed
	)
	_combat_layout_mode = str(layout.get("layout_mode", "COMPACT"))
	var panel_size := layout.get("panel_size", Vector2()) as Vector2
	_combat_overlay.custom_minimum_size = panel_size
	_combat_overlay.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_combat_overlay.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_combat_surface_host.custom_minimum_size = Vector2(0.0, 0.0)
	if _combat_surface_host is ScrollContainer:
		_combat_surface.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_WIDE
		)
		_combat_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var content_height := 410.0
		if _combat_surface_preferred_height >= 0.0:
			content_height = _combat_surface_preferred_height
		elif _combat_surface.has_method("preferred_content_height"):
			content_height = float(
				_combat_surface.call("preferred_content_height")
			)
		_combat_surface.custom_minimum_size = Vector2(
			0.0,
			content_height
		)
		# Fill a taller desktop host from its top edge; when content is taller,
		# retain its real minimum so the ScrollContainer exposes a usable range.
		_combat_surface.size_flags_vertical = (
			Control.SIZE_SHRINK_BEGIN
			if content_height
				> _combat_surface_host.size.y + GEOMETRY_INTERSECTION_EPSILON
			else Control.SIZE_EXPAND_FILL
		)
		(_combat_surface_host as ScrollContainer).queue_sort()
	else:
		_combat_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_combat_surface.custom_minimum_size = Vector2(0.0, 0.0)
	_combat_stack_host.queue_sort()
	($RootMargin/Shell as VBoxContainer).queue_sort()
	_schedule_combat_host_layout_settle()


func _schedule_combat_host_layout_settle() -> void:
	if _combat_host_layout_settle_scheduled:
		return
	_combat_host_layout_settle_scheduled = true
	call_deferred("_prepare_combat_host_layout_settle")


func _prepare_combat_host_layout_settle() -> void:
	if (
		is_instance_valid(_combat_surface)
		and is_instance_valid(_combat_surface_host)
	):
		_combat_surface.update_minimum_size()
		_combat_surface_host.update_minimum_size()
		if _combat_surface_host is ScrollContainer:
			(_combat_surface_host as ScrollContainer).queue_sort()
	call_deferred("_finish_combat_host_layout_settle")


func _finish_combat_host_layout_settle() -> void:
	_combat_host_layout_settle_scheduled = false
	if _combat_surface_host is ScrollContainer:
		(_combat_surface_host as ScrollContainer).queue_sort()
	_refresh_combat_geometry_snapshot()


func _combat_layout_plan(
	viewport_size: Vector2,
	safe_size: Vector2,
	collapsed: bool
) -> Dictionary:
	var resolved_viewport := Vector2(
		maxf(1.0, viewport_size.x),
		maxf(1.0, viewport_size.y)
	)
	var layout_mode := "REGULAR"
	if resolved_viewport.x < COMBAT_LAYOUT_NARROW_MAX_WIDTH:
		layout_mode = "NARROW"
	elif resolved_viewport.x < COMBAT_LAYOUT_REGULAR_MIN_WIDTH:
		layout_mode = "COMPACT"
	var available_width := maxf(
		1.0,
		minf(
			resolved_viewport.x - COMBAT_LAYOUT_HORIZONTAL_GUTTER * 2.0,
			maxf(1.0, safe_size.x)
		)
	)
	var panel_width := minf(COMBAT_LAYOUT_MAX_WIDTH, available_width)
	var panel_height := clampf(
		minf(resolved_viewport.y * 0.55, maxf(1.0, safe_size.y)),
		COMBAT_LAYOUT_MIN_HEIGHT,
		COMBAT_LAYOUT_MAX_HEIGHT
	)
	if collapsed:
		panel_height = 46.0
	return {
		"schema": "V075CombatLayoutPlanV2",
		"layout_mode": layout_mode,
		"panel_anchor": "production_flow_stack",
		"panel_size": Vector2(panel_width, panel_height),
		"available_width": available_width,
		"panel_width": panel_width,
		"panel_height": panel_height,
		"acceptance_geometry_source": "runtime_control_rects_required",
	}


func _dock_target_rail_in_production_flow() -> void:
	if (
		not is_instance_valid(_virtual_target_rail_float)
		or not is_instance_valid(_virtual_target_rail)
		or not is_instance_valid(_combat_stack_host)
		or not is_instance_valid(_marker_panel)
	):
		return
	var shell := $RootMargin/Shell as VBoxContainer
	var track_panel := $RootMargin/Shell/TrackPanel as Control
	if _virtual_target_rail_float.get_parent() != shell:
		_virtual_target_rail_float.reparent(shell)
	if (_marker_panel as Control).get_parent() != shell:
		(_marker_panel as Control).reparent(shell)
	if (_marker_panel as Control).get_index() != track_panel.get_index() + 1:
		shell.move_child(_marker_panel as Control, track_panel.get_index() + 1)
	if _combat_stack_host.get_index() != (_marker_panel as Control).get_index() + 1:
		shell.move_child(
			_combat_stack_host,
			(_marker_panel as Control).get_index() + 1
		)
	if _virtual_target_rail_float.get_index() != _combat_stack_host.get_index() + 1:
		shell.move_child(
			_virtual_target_rail_float,
			_combat_stack_host.get_index() + 1
		)
	# V0.7.4 positions this rail in a CanvasLayer using an absolute desktop
	# rectangle. V0.7.5 keeps the same production node and interactions, but
	# makes it a normal flow child so an opened rail cannot cover combat/table UI.
	_virtual_target_rail_float.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_virtual_target_rail_float.position = Vector2.ZERO
	_virtual_target_rail_float.custom_minimum_size = Vector2.ZERO
	_virtual_target_rail_float.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_virtual_target_rail_float.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_virtual_target_rail.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_virtual_target_rail.position = Vector2.ZERO
	_virtual_target_rail.custom_minimum_size.x = 0.0
	_virtual_target_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_virtual_target_rail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_virtual_target_rail_float.z_index = 0
	(_marker_panel as Control).set_anchors_preset(Control.PRESET_TOP_LEFT)
	(_marker_panel as Control).position = Vector2.ZERO
	(_marker_panel as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	(_marker_panel as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	(_marker_panel as Control).z_index = 0
	shell.queue_sort()


func _refresh_combat_geometry_snapshot() -> void:
	if not is_instance_valid(_combat_overlay):
		return
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var root_scroll := $RootMargin as ScrollContainer
	var shell := $RootMargin/Shell as VBoxContainer
	var table_area := $RootMargin/Shell/TableArea as Control
	var track_panel := $RootMargin/Shell/TrackPanel as Control
	var dock_panel := $RootMargin/Shell/DockPanel as Control
	var asset_rail := (
		$RootMargin/Shell/DockPanel/DockMargin/DockRows/DockHeader/AssetRail
		as Control
	)
	var planet_stage := (
		$RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport
		as Control
	)
	var panel_rect := _combat_overlay.get_global_rect()
	var safe_rect := root_scroll.get_global_rect()
	var shell_rect := shell.get_global_rect()
	var table_rect := table_area.get_global_rect()
	var track_rect := track_panel.get_global_rect()
	var dock_rect := dock_panel.get_global_rect()
	var asset_rect := asset_rail.get_global_rect()
	var planet_rect := planet_stage.get_global_rect()
	var surface_host_rect := (_combat_surface_host as Control).get_global_rect()
	var combat_surface_rect := _combat_surface.get_global_rect()
	var utility_rail_rect := _virtual_target_rail.get_global_rect()
	var utility_rail_visible := (
		_virtual_target_rail.visible
		and _virtual_target_rail.is_visible_in_tree()
	)
	var marker_rect := Rect2()
	var marker_visible := false
	var marker_offscreen_count := 0
	if is_instance_valid(_marker_panel):
		marker_rect = (_marker_panel as Control).get_global_rect()
		marker_visible = (
			(_marker_panel as Control).visible
			and (_marker_panel as Control).is_visible_in_tree()
		)
		if _marker_panel.has_method("debug_snapshot"):
			marker_offscreen_count = int(
				(_marker_panel.call("debug_snapshot") as Dictionary).get(
					"offscreen_count",
					1
				)
			)
	var planet_right_half := Rect2(
		planet_rect.position + Vector2(planet_rect.size.x * 0.5, 0.0),
		Vector2(planet_rect.size.x * 0.5, planet_rect.size.y)
	)
	var surface_audit := {}
	if _combat_surface.has_method("debug_geometry_audit"):
		surface_audit = _combat_surface.call("debug_geometry_audit") as Dictionary
	var child_overlap_count := int(
		surface_audit.get("unintended_overlap_count", 0)
	)
	var child_outside_count := int(
		surface_audit.get("outside_surface_count", 0)
	)
	var child_unreachable_count := int(
		surface_audit.get("unreachable_clipped_control_count", 0)
	)
	var planet_overlap_count := _rect_overlap_count(panel_rect, planet_rect)
	var track_overlap_count := _rect_overlap_count(panel_rect, track_rect)
	var dock_overlap_count := _rect_overlap_count(panel_rect, dock_rect)
	var asset_overlap_count := _rect_overlap_count(panel_rect, asset_rect)
	var utility_rail_overlap_count := 0
	if utility_rail_visible:
		for protected_rect in [
			panel_rect,
			track_rect,
			table_rect,
			planet_rect,
			dock_rect,
			asset_rect,
		]:
			utility_rail_overlap_count += _rect_overlap_count(
				utility_rail_rect,
				protected_rect as Rect2
			)
	var marker_overlap_count := 0
	if marker_visible:
		for protected_rect in [
			panel_rect,
			track_rect,
			table_rect,
			planet_rect,
			dock_rect,
			asset_rect,
		]:
			marker_overlap_count += _rect_overlap_count(
				marker_rect,
				protected_rect as Rect2
			)
		if utility_rail_visible:
			marker_overlap_count += _rect_overlap_count(
				marker_rect,
				utility_rail_rect
			)
	var protected_rects := [table_rect, planet_rect, dock_rect, asset_rect]
	if utility_rail_visible:
		protected_rects.append(utility_rail_rect)
	if marker_visible:
		protected_rects.append(marker_rect)
	var protected_nonempty_count := 0
	var protected_content_containment_count := 0
	var protected_scroll_reachable_count := 0
	for protected_rect in protected_rects:
		var resolved_rect := protected_rect as Rect2
		if (
			resolved_rect.size.x > GEOMETRY_INTERSECTION_EPSILON
			and resolved_rect.size.y > GEOMETRY_INTERSECTION_EPSILON
		):
			protected_nonempty_count += 1
		if _rect_encloses_with_epsilon(shell_rect, resolved_rect):
			protected_content_containment_count += 1
		if _rect_reachable_by_root_scroll(
			resolved_rect,
			safe_rect,
			root_scroll
		):
			protected_scroll_reachable_count += 1
	var horizontal_bar := root_scroll.get_h_scroll_bar()
	var vertical_bar := root_scroll.get_v_scroll_bar()
	var horizontal_scroll_range := maxf(
		0.0,
		horizontal_bar.max_value - horizontal_bar.page
	)
	var vertical_scroll_range := maxf(
		0.0,
		vertical_bar.max_value - vertical_bar.page
	)
	var surface_vertical_scroll_range := 0.0
	if _combat_surface_host is ScrollContainer:
		var surface_vertical_bar := (
			(_combat_surface_host as ScrollContainer).get_v_scroll_bar()
		)
		surface_vertical_scroll_range = maxf(
			0.0,
			surface_vertical_bar.max_value - surface_vertical_bar.page
		)
	var panel_overflow_count := int(not viewport_rect.encloses(panel_rect))
	var safe_overflow_count := int(not safe_rect.encloses(panel_rect))
	_combat_layout_snapshot = {
		"schema": "V075CombatLayoutGeometryV3",
		"geometry_source": "instantiated_production_controls",
		"layout_mode": _combat_layout_mode,
		"panel_anchor": "production_flow_stack",
		"viewport_rect": viewport_rect,
		"safe_area_rect": safe_rect,
		"shell_content_rect": shell_rect,
		"panel_rect": panel_rect,
		"table_rect": table_rect,
		"track_rect": track_rect,
		"dock_rect": dock_rect,
		"asset_reserve_lane_rect": asset_rect,
		"planet_stage_rect": planet_rect,
		"combat_surface_host_rect": surface_host_rect,
		"combat_surface_content_rect": combat_surface_rect,
		"combat_surface_preferred_content_height": float(
			surface_audit.get("preferred_content_height", 0.0)
		),
		"combat_surface_rows_combined_minimum_height": float(
			surface_audit.get("rows_combined_minimum_height", 0.0)
		),
		"combat_surface_host_vertical_scroll_range": (
			surface_vertical_scroll_range
		),
		"combat_surface_content_origin_green": (
			absf(combat_surface_rect.position.x - surface_host_rect.position.x)
				<= GEOMETRY_INTERSECTION_EPSILON
			and absf(combat_surface_rect.position.y - surface_host_rect.position.y)
				<= GEOMETRY_INTERSECTION_EPSILON
		),
		"utility_target_rail_rect": utility_rail_rect,
		"utility_marker_rect": marker_rect,
		"panel_width": panel_rect.size.x,
		"panel_height": panel_rect.size.y,
		"panel_available_width": safe_rect.size.x,
		"panel_viewport_overflow_count": panel_overflow_count,
		"panel_safe_area_overflow_count": safe_overflow_count,
		"panel_width_green": (
			panel_rect.size.x > 0.0
			and panel_rect.size.x <= safe_rect.size.x + GEOMETRY_INTERSECTION_EPSILON
		),
		"primary_planet_occlusion_count": planet_overlap_count,
		"planet_right_half_occlusion_count": _rect_overlap_count(
			panel_rect,
			planet_right_half
		),
		"track_panel_overlap_count": track_overlap_count,
		"dock_panel_overlap_count": dock_overlap_count,
		"asset_reserve_lane_overlap_count": asset_overlap_count,
		"utility_target_rail_visible": utility_rail_visible,
		"utility_target_rail_parent_is_flow": (
			_virtual_target_rail_float.get_parent() == shell
		),
		"utility_target_rail_flow_index_green": (
			_virtual_target_rail_float.get_index()
				== _combat_stack_host.get_index() + 1
		),
		"utility_target_rail_overlap_count": utility_rail_overlap_count,
		"utility_marker_visible": marker_visible,
		"utility_marker_parent_is_flow": (
			is_instance_valid(_marker_panel)
			and (_marker_panel as Control).get_parent() == shell
		),
		"utility_marker_flow_index_green": (
			is_instance_valid(_marker_panel)
			and (_marker_panel as Control).get_index()
				== track_panel.get_index() + 1
			and _combat_stack_host.get_index()
				== (_marker_panel as Control).get_index() + 1
		),
		"utility_marker_offscreen_count": marker_offscreen_count,
		"utility_marker_overlap_count": marker_overlap_count,
		"protected_surface_nonempty_count": protected_nonempty_count,
		"protected_surface_content_containment_count": (
			protected_content_containment_count
		),
		"protected_surface_scroll_reachable_count": (
			protected_scroll_reachable_count
		),
		"protected_surface_expected_count": protected_rects.size(),
		"root_horizontal_scroll_range": horizontal_scroll_range,
		"root_vertical_scroll_range": vertical_scroll_range,
		"ui_child_collision_count": child_overlap_count,
		"ui_child_outside_surface_count": child_outside_count,
		"ui_child_unreachable_clipped_control_count": (
			child_unreachable_count
		),
		"private_grid_columns": int(
			surface_audit.get("private_grid_columns", 0)
		),
		"two_column_information_contract": (
			child_overlap_count == 0 and child_unreachable_count == 0
		),
		"track_and_asset_surfaces_untouched": (
			track_overlap_count == 0
			and dock_overlap_count == 0
			and asset_overlap_count == 0
		),
		"root_scroll_accessible": (
			root_scroll.horizontal_scroll_mode
				!= ScrollContainer.SCROLL_MODE_DISABLED
			and root_scroll.vertical_scroll_mode
				!= ScrollContainer.SCROLL_MODE_DISABLED
			and root_scroll.follow_focus
		),
	}


func v075_responsive_geometry_audit() -> Dictionary:
	_refresh_combat_geometry_snapshot()
	return _combat_layout_snapshot.duplicate(true)


func _rect_overlap_count(left: Rect2, right: Rect2) -> int:
	var intersection := left.intersection(right)
	return int(
		intersection.size.x > GEOMETRY_INTERSECTION_EPSILON
		and intersection.size.y > GEOMETRY_INTERSECTION_EPSILON
	)


func _rect_encloses_with_epsilon(outer: Rect2, inner: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - GEOMETRY_INTERSECTION_EPSILON
		and inner.position.y >= outer.position.y - GEOMETRY_INTERSECTION_EPSILON
		and inner.end.x <= outer.end.x + GEOMETRY_INTERSECTION_EPSILON
		and inner.end.y <= outer.end.y + GEOMETRY_INTERSECTION_EPSILON
	)


func _rect_reachable_by_root_scroll(
	target_rect: Rect2,
	safe_rect: Rect2,
	root_scroll: ScrollContainer
) -> bool:
	if (
		target_rect.size.x <= GEOMETRY_INTERSECTION_EPSILON
		or target_rect.size.y <= GEOMETRY_INTERSECTION_EPSILON
	):
		return false
	var horizontal_bar := root_scroll.get_h_scroll_bar()
	var vertical_bar := root_scroll.get_v_scroll_bar()
	var horizontal_before := float(root_scroll.scroll_horizontal)
	var vertical_before := float(root_scroll.scroll_vertical)
	var horizontal_after := maxf(
		0.0,
		horizontal_bar.max_value - horizontal_bar.page - horizontal_before
	)
	var vertical_after := maxf(
		0.0,
		vertical_bar.max_value - vertical_bar.page - vertical_before
	)
	var horizontal_reachable := true
	if target_rect.end.x <= safe_rect.position.x:
		horizontal_reachable = (
			horizontal_before + GEOMETRY_INTERSECTION_EPSILON
				>= safe_rect.position.x - target_rect.end.x
		)
	elif target_rect.position.x >= safe_rect.end.x:
		horizontal_reachable = (
			horizontal_after + GEOMETRY_INTERSECTION_EPSILON
				>= target_rect.position.x - safe_rect.end.x
		)
	var vertical_reachable := true
	if target_rect.end.y <= safe_rect.position.y:
		vertical_reachable = (
			vertical_before + GEOMETRY_INTERSECTION_EPSILON
				>= safe_rect.position.y - target_rect.end.y
		)
	elif target_rect.position.y >= safe_rect.end.y:
		vertical_reachable = (
			vertical_after + GEOMETRY_INTERSECTION_EPSILON
				>= target_rect.position.y - safe_rect.end.y
		)
	return horizontal_reachable and vertical_reachable


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
	_dock_target_rail_in_production_flow()
	_set_v075_chrome()


func _refresh_targets() -> void:
	# Combat cards have typed runtime targets, not V0.7.4 facility bindings.
	# Keep the inherited map rail for facilities and hide it while a combat card
	# is waiting for its explicit owner-private mode/mission choice.
	var combat_domain := _v075_card_domain(_selected_card_definition_id)
	var target_panel := $RootMargin/Shell/TargetPanel as Control
	if combat_domain in ["monster", "military"]:
		if target_panel != null:
			target_panel.visible = false
		return
	if target_panel != null:
		target_panel.visible = true
	super._refresh_targets()


func _on_hand_card_activated(payload: Dictionary) -> void:
	var definition_id := str(payload.get("definition_id", ""))
	var domain := _v075_card_domain(definition_id)
	if domain != "monster":
		_region_popup.visible = false
		_monster_mode_popup_card_id = ""
		super._on_hand_card_activated(payload)
		return
	var incoming_id := str(payload.get("instance_id", ""))
	if incoming_id.is_empty():
		return
	if incoming_id == _selected_card_id:
		_region_popup.visible = false
		_monster_mode_popup_card_id = ""
		_clear_selected_card()
		return
	_selected_card_id = incoming_id
	_selected_card_definition_id = definition_id
	_selected_card_color = str(payload.get("primary_color", ""))
	_selected_card_type = str(payload.get("card_type", ""))
	_interaction_counts["card_selected"] += 1
	_last_public_ui_surface = "hand_dock"
	var summary := _card_summary(payload, "hand_dock")
	_emit_playtest_event("card_selected", summary)
	_emit_playtest_event("monster_card_mode_selection_started", summary)
	_action_status.text = "已选怪兽牌 · 请选择预绑定模式"
	_refresh_hand()
	_refresh_targets()
	_render_monster_card_mode_popup(payload)
	_update_acceptance_state()


func _render_monster_card_mode_popup(payload: Dictionary) -> void:
	var card_id := str(payload.get("instance_id", ""))
	var options := _monster_card_options_for_card(card_id)
	_monster_mode_popup_card_id = card_id
	_region_popup.visible = true
	_region_popup_title.text = "怪兽牌 · 预绑定模式"
	_region_popup_body.text = (
		"[indent][b]%s[/b] · %s\n"
		+ "模式在锁定前选择；结算时不会自动转换。\n"
		+ "当前合法模式 %d / 4[/indent]"
	) % [
		_card_type_label(str(payload.get("definition_id", ""))),
		str(COLOR_LABELS.get(
			str(payload.get("primary_color", "")),
			payload.get("primary_color", "")
		)),
		options.size(),
	]
	_clear_children(_region_popup_choices)
	for mode in MONSTER_CARD_MODES:
		var mode_options: Array = []
		for option_variant in options:
			var option := option_variant as Dictionary
			if str(option.get("monster_card_mode", "")) == mode:
				mode_options.append(option)
		if not mode_options.is_empty():
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0.0, 42.0)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 7)
			var target_menu := OptionButton.new()
			target_menu.custom_minimum_size = Vector2(0.0, 42.0)
			target_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			target_menu.fit_to_longest_item = false
			target_menu.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			for option_variant in mode_options:
				var option := option_variant as Dictionary
				var target_index := target_menu.item_count
				target_menu.add_item(_monster_mode_target_label(option))
				target_menu.set_item_metadata(
					target_index,
					option.duplicate(true)
				)
			target_menu.select(0)
			var choose_button := Button.new()
			choose_button.custom_minimum_size = Vector2(132.0, 42.0)
			choose_button.text = str(MONSTER_CARD_MODE_LABELS.get(mode, mode))
			choose_button.tooltip_text = str(
				MONSTER_CARD_MODE_HINTS.get(mode, "")
			)
			_apply_monster_mode_button_style(choose_button, mode)
			choose_button.pressed.connect(func() -> void:
				var selected := target_menu.get_item_metadata(
					target_menu.selected
				) as Dictionary
				_queue_monster_card_mode(selected)
			)
			row.add_child(target_menu)
			row.add_child(choose_button)
			_region_popup_choices.add_child(row)
		if mode_options.is_empty():
			var unavailable := Label.new()
			unavailable.custom_minimum_size = Vector2(0.0, 26.0)
			unavailable.text = "%s · 当前不可用" % str(
				MONSTER_CARD_MODE_LABELS.get(mode, mode)
			)
			unavailable.add_theme_color_override(
				"font_color",
				Color("#68788d")
			)
			_region_popup_choices.add_child(unavailable)


func _monster_card_options_for_card(card_id: String) -> Array:
	var result: Array = []
	if card_id.is_empty():
		return result
	for option_variant in _v075_snapshot.get("legal_actions", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if (
			str(option.get("action_domain", "")) == "monster"
			and str(option.get("card_instance_id", "")) == card_id
			and str(option.get("monster_card_mode", "")) in MONSTER_CARD_MODES
			and bool(option.get("mode_prebound", true))
		):
			result.append(option.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_mode := MONSTER_CARD_MODES.find(
			str(left.get("monster_card_mode", ""))
		)
		var right_mode := MONSTER_CARD_MODES.find(
			str(right.get("monster_card_mode", ""))
		)
		if left_mode != right_mode:
			return left_mode < right_mode
		return str(left.get("option_id", "")) < str(
			right.get("option_id", "")
		)
	)
	return result


func _monster_mode_target_label(option: Dictionary) -> String:
	var mode := str(option.get("monster_card_mode", ""))
	if mode == "DEPLOY_NEW":
		return "部署至 %s" % str(option.get("target_region_id", ""))
	return "来源 %s" % str(option.get("target_source_instance_id", ""))


func _queue_monster_card_mode(option: Dictionary) -> void:
	if (
		option.is_empty()
		or str(option.get("card_instance_id", "")) != _monster_mode_popup_card_id
		or str(option.get("monster_card_mode", "")) not in MONSTER_CARD_MODES
		or not bool(option.get("mode_prebound", true))
	):
		_show_toast("怪兽模式选项已过期，请重新选择手牌", false)
		return
	_emit_playtest_event("monster_card_mode_selected", {
		"card_instance_id": str(option.get("card_instance_id", "")),
		"monster_card_mode": str(option.get("monster_card_mode", "")),
		"target_region_id": str(option.get("target_region_id", "")),
		"target_source_instance_id": str(option.get(
			"target_source_instance_id",
			""
		)),
	})
	_action_status.text = "%s · 已预绑定，等待锁定" % str(
		MONSTER_CARD_MODE_LABELS.get(
			str(option.get("monster_card_mode", "")),
			option.get("monster_card_mode", "")
		)
	)
	_emit_intent("card.queue", {
		"card_instance_id": str(option.get("card_instance_id", "")),
		"target_slot_id": str(option.get("target_slot_id", "")),
		"target_binding": option.duplicate(true),
	})


func _apply_monster_mode_button_style(button: Button, mode: String) -> void:
	var accent := Color("#55d6bc")
	if mode == "REFRESH_EXISTING":
		accent = Color("#75d994")
	elif mode == "UPGRADE_EXISTING":
		accent = Color("#7bb8ff")
	elif mode == "REPLACE_EXISTING":
		accent = Color("#e48c78")
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#162238")
	normal.border_color = accent.darkened(0.35)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.68)
	hover.border_color = accent
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)


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


func _v075_combat_card_art_path(definition_id: String) -> String:
	return str(
		V075CardDefinitionRegistry.presentation_descriptor(
			definition_id
		).get("resource_path", "")
	)


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
	if domain in ["monster", "military"]:
		# Known combat definitions fail closed when their typed presentation
		# resource cannot be loaded; facility art must never mask that failure.
		return V075CardDefinitionRegistry.presentation_texture(definition_id)
	return super._card_art(item)


func v075_card_presentation_audit(item: Dictionary) -> Dictionary:
	var definition_id := str(item.get("card_definition_id", ""))
	var definition := _v075_card_definition(definition_id)
	var card_type := str(definition.get("card_type", ""))
	var domain := _v075_card_domain(definition_id)
	var descriptor := V075CardDefinitionRegistry.presentation_descriptor(
		definition_id
	)
	var descriptor_error := (
		V075CardDefinitionRegistry.presentation_descriptor_error(descriptor)
		if not descriptor.is_empty()
		else "presentation_descriptor_missing"
	)
	var art := _card_art(item)
	var art_path := str(art.resource_path) if art != null else ""
	var mapped_path := _v075_combat_card_art_path(definition_id)
	var expected_art := V075CardDefinitionRegistry.presentation_texture(
		definition_id
	)
	var uses_facility_art := (
		art_path in V075_FACILITY_ART_PATHS
		or mapped_path in V075_FACILITY_ART_PATHS
	)
	return {
		"schema": "V075CardPresentationAuditV2",
		"local_slot_index": int(item.get("local_slot_index", -1)),
		"card_definition_id": definition_id,
		"card_type": card_type,
		"domain": domain,
		"type_label": _card_type_label(definition_id),
		"art_present": art != null,
		"art_resource_path": art_path,
		"stable_mapping_path": mapped_path,
		"presentation_asset_key": str(
			descriptor.get("presentation_asset_key", "")
		),
		"presentation_descriptor_error": descriptor_error,
		"resource_loader_exists": (
			ResourceLoader.exists(mapped_path, "Texture2D")
			if not mapped_path.is_empty()
			else false
		),
		"resource_loaded_as_texture": expected_art != null,
		"instance_binding_green": art != null and art == expected_art,
		"uses_facility_art": uses_facility_art,
		"combat_art_mapping_green": (
			domain in ["monster", "military"]
			and descriptor_error.is_empty()
			and art != null
			and art == expected_art
			and art_path == mapped_path
			and not uses_facility_art
			and not mapped_path.is_empty()
		),
	}


func _refresh_planet_presentation() -> void:
	super._refresh_planet_presentation()
	call_deferred("_sync_combat_map_projection")


func _combat_map_view() -> Control:
	if not is_instance_valid(_planet_board):
		return null
	var map_view_variant: Variant = _planet_board.call(
		"get_embedded_map_view"
	)
	return (
		map_view_variant as Control
		if map_view_variant is Control
		else null
	)


func _sync_combat_map_projection() -> bool:
	var map_view := _combat_map_view()
	if not is_instance_valid(map_view) or not map_view.has_method("set_map"):
		return false
	var districts := _combat_array(map_view.get("districts"))
	var palette := _combat_array(map_view.get("palette"))
	if districts.is_empty() or palette.size() != districts.size():
		return false
	var centers := _combat_region_centers(districts)
	if centers.is_empty():
		return false

	var base_markers := _without_v075_combat_rows(
		map_view.get("auto_monster_markers")
	)
	var markers := base_markers.duplicate(true)
	markers.append_array(_combat_monster_markers(centers))

	var base_trails := _without_v075_combat_rows(
		map_view.get("movement_trails")
	)
	var base_effects := _without_v075_combat_rows(
		map_view.get("map_event_effects")
	)
	var base_callouts := _without_v075_combat_rows(
		map_view.get("action_callouts")
	)
	var trails := base_trails.duplicate(true)
	var effects := base_effects.duplicate(true)
	var callouts := base_callouts.duplicate(true)
	for cue in _combat_map_cues:
		_append_combat_cue_layers(
			cue,
			centers,
			trails,
			effects,
			callouts
		)

	var sync_signature := _combat_sync_signature({
		"districts": districts,
		"markers": markers,
		"trails": trails,
		"effects": effects,
		"callouts": callouts,
	})
	if sync_signature == _combat_map_last_sync_signature:
		return true
	_combat_map_last_sync_signature = sync_signature
	_combat_map_marker_count = markers.size() - base_markers.size()
	_combat_map_trail_count = trails.size() - base_trails.size()
	_combat_map_effect_count = effects.size() - base_effects.size()
	_combat_map_callout_count = callouts.size() - base_callouts.size()
	map_view.call(
		"set_map",
		districts,
		float(map_view.get("map_width_m")),
		float(map_view.get("map_height_m")),
		int(map_view.get("selected_district")),
		palette,
		trails,
		callouts,
		effects,
		markers,
		_combat_array(map_view.get("city_markers")),
		_combat_array(map_view.get("trade_route_markers")),
		str(map_view.get("trade_product")),
		str(map_view.get("visual_layer_focus"))
	)
	_combat_map_projection_apply_count += 1
	return true


func _combat_sync_signature(value: Variant) -> String:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var keys: Array[String] = []
		for key_variant in dictionary.keys():
			keys.append(str(key_variant))
		keys.sort()
		var fields: Array[String] = []
		for key in keys:
			fields.append(
				"%s:%s" % [
					JSON.stringify(key),
					_combat_sync_signature(dictionary.get(key)),
				]
			)
		return "{%s}" % ",".join(fields)
	if value is Array:
		var items: Array[String] = []
		for item in value as Array:
			items.append(_combat_sync_signature(item))
		return "[%s]" % ",".join(items)
	return JSON.stringify(value)


func _combat_array(value: Variant) -> Array:
	return (
		(value as Array).duplicate(true)
		if value is Array
		else []
	)


func _without_v075_combat_rows(value: Variant) -> Array:
	var rows: Array = []
	if not (value is Array):
		return rows
	for row_variant in value as Array:
		if (
			row_variant is Dictionary
			and bool(
				(row_variant as Dictionary).get(
					"v075_combat_presentation",
					false
				)
			)
		):
			continue
		rows.append(
			(row_variant as Dictionary).duplicate(true)
			if row_variant is Dictionary
			else row_variant
		)
	return rows


func _combat_region_centers(districts: Array) -> Dictionary:
	var centers := {}
	for district_variant in districts:
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		var region_id := str(district.get("region_id", ""))
		var center_variant: Variant = district.get("center")
		if region_id.is_empty() or not (center_variant is Vector2):
			continue
		centers[region_id] = center_variant
	return centers


func _combat_monster_markers(centers: Dictionary) -> Array:
	var markers: Array = []
	for source_variant in _combat_projection.get(
		"public_monsters",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		var region_id := str(source.get("region_id", ""))
		if region_id.is_empty() or not centers.has(region_id):
			continue
		var color_id := str(
			source.get("preferred_industry_color", "")
		)
		var accent := _combat_map_color(color_id)
		var display_name := str(
			source.get(
				"display_name",
				source.get("monster_family_id", "怪兽")
			)
		)
		markers.append({
			"v075_combat_presentation": true,
			"source_instance_id": str(
				source.get("source_instance_id", "")
			),
			"owner_player_id": str(
				source.get("owner_player_id", "")
			),
			"position": centers.get(region_id),
			"name": display_name,
			"label": "L%d" % int(source.get("rank", 1)),
			"glyph": "M",
			"display_subtitle": (
				"HP %d/%d · 护甲 %d · 偏好%s"
				% [
					int(source.get("hp", 0)),
					int(source.get("max_hp", 0)),
					int(source.get("armor", 0)),
					_combat_color_label(color_id),
				]
			),
			"color": accent,
			"secondary": accent.lightened(0.28),
			"model_asset_key": str(
				source.get("model_asset_key", "")
			),
			"status": str(source.get("status", "active")),
			"region_id": region_id,
		})
	return markers


func _append_combat_cue_layers(
	cue: Dictionary,
	centers: Dictionary,
	trails: Array,
	effects: Array,
	callouts: Array
) -> void:
	var event_kind := str(cue.get("event_kind", ""))
	var payload := cue.get("public_payload", {}) as Dictionary
	var accent := _combat_map_cue_color(event_kind, payload)
	var target_region_id := _combat_cue_target_region(payload)
	if event_kind == "monster_moved":
		var path := payload.get("ordered_region_path", []) as Array
		for index in range(maxi(0, path.size() - 1)):
			var from_region_id := str(path[index])
			var to_region_id := str(path[index + 1])
			if (
				not centers.has(from_region_id)
				or not centers.has(to_region_id)
			):
				continue
			trails.append({
				"v075_combat_presentation": true,
				"from": centers.get(from_region_id),
				"to": centers.get(to_region_id),
				"label": "怪兽自动移动",
				"style": "monster",
				"life": 6.0,
				"duration": 6.0,
				"color": accent,
				"source_region_id": from_region_id,
				"target_region_id": to_region_id,
			})
	elif event_kind == "monster_trample_resolved":
		if centers.has(target_region_id):
			effects.append({
				"v075_combat_presentation": true,
				"kind": "impact",
				"position": centers.get(target_region_id),
				"label": "践踏 %d" % int(payload.get(
					"region_damage_budget",
					payload.get("damage_amount", 0)
				)),
				"life": 6.0,
				"duration": 6.0,
				"radius_m": 110.0,
				"motion_family": "monster_trample",
				"effect_layer": "combat",
				"color": accent,
				"region_id": target_region_id,
			})
	elif event_kind in [
		"monster_deployed",
		"monster_refreshed",
		"monster_upgraded",
		"monster_replaced",
		"monster_basic_attack",
		"monster_private_skill_resolved",
		"monster_damaged",
		"monster_downed",
		"monster_destroyed",
		"facility_combat_damaged",
		"armor_absorbed",
		"military_region_assault",
		"military_monster_assault",
	]:
		if centers.has(target_region_id):
			effects.append({
				"v075_combat_presentation": true,
				"kind": (
					"beam"
					if event_kind in [
						"monster_basic_attack",
						"monster_private_skill_resolved",
					]
					else "impact"
				),
				"from": centers.get(
					str(payload.get("start_region_id", "")),
					centers.get(target_region_id)
				),
				"to": centers.get(target_region_id),
				"position": centers.get(target_region_id),
				"label": _combat_map_cue_summary(
					event_kind,
					payload
				),
				"life": 6.0,
				"duration": 6.0,
				"radius_m": 90.0,
				"motion_family": event_kind,
				"effect_layer": "combat",
				"color": accent,
				"region_id": target_region_id,
			})
	var summary := _combat_map_cue_summary(event_kind, payload)
	if summary.is_empty():
		return
	callouts.append({
		"v075_combat_presentation": true,
		"title": _combat_map_cue_title(event_kind),
		"detail": summary,
		"life": 8.0,
		"duration": 8.0,
		"color": accent,
		"event_kind": event_kind,
		"region_id": target_region_id,
	})


func _combat_cue_target_region(payload: Dictionary) -> String:
	for field in [
		"region_id",
		"target_region_id",
		"destination_region_id",
		"start_region_id",
	]:
		var region_id := str(payload.get(field, ""))
		if not region_id.is_empty():
			return region_id
	var target_source_id := str(
		payload.get("target_monster_source_instance_id", "")
	)
	if target_source_id.is_empty():
		return ""
	for source_variant in _combat_projection.get(
		"public_monsters",
		[]
	) as Array:
		if not (source_variant is Dictionary):
			continue
		var source := source_variant as Dictionary
		if str(source.get("source_instance_id", "")) == target_source_id:
			return str(source.get("region_id", ""))
	return ""


func _combat_map_cue_title(event_kind: String) -> String:
	if event_kind.begins_with("military_"):
		return "军队"
	if event_kind == "facility_combat_damaged":
		return "设施受损"
	if event_kind == "monster_trample_resolved":
		return "怪兽践踏"
	return "怪兽"


func _combat_map_cue_summary(
	event_kind: String,
	payload: Dictionary
) -> String:
	match event_kind:
		"monster_deployed":
			return "怪兽部署至 %s" % _combat_cue_target_region(payload)
		"monster_refreshed":
			return "同族牌恢复 %d%% 最大生命" % int(
				payload.get("refresh_percent", 0)
			)
		"monster_upgraded":
			return "升级至 L%d，旧技能冷却保持" % int(
				payload.get("new_rank", payload.get("source_rank", 1))
			)
		"monster_replaced":
			return "旧怪兽撤回，新怪兽部署"
		"monster_moved":
			return "沿动态地区最短路径移动"
		"monster_trample_resolved":
			return "%s · 距离 %d · 伤害 %d" % [
				str(payload.get("region_id", "")),
				int(payload.get("distance_milli_arc", 0)),
				int(payload.get(
					"region_damage_budget",
					payload.get("damage_amount", 0)
				)),
			]
		"monster_basic_attack":
			return "到达后基础攻击 · %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_private_skill_resolved":
			return "私密技能公开效果已结算"
		"monster_damaged":
			return "怪兽受到 %d 伤害" % int(
				payload.get("damage_amount", 0)
			)
		"monster_downed":
			return "怪兽倒地"
		"monster_destroyed":
			return "怪兽被摧毁"
		"military_region_assault":
			return "区域总伤害预算已分配"
		"military_monster_assault":
			return "锁定怪兽受到一次攻击"
		"military_withdrawn":
			return "任务完成，军队撤离并进入弃牌池"
		"facility_combat_damaged":
			return "%s · %s设施受到战斗伤害" % [
				_combat_cue_target_region(payload),
				str(payload.get("facility_type", "")),
			]
		"armor_absorbed":
			return "护甲吸收伤害"
	return ""


func _combat_map_cue_color(
	event_kind: String,
	payload: Dictionary
) -> Color:
	if event_kind.begins_with("military_"):
		return Color("#ef9a74")
	if event_kind == "facility_combat_damaged":
		return Color("#e4bd69")
	return _combat_map_color(
		str(payload.get("preferred_industry_color", ""))
	)


func _combat_map_color(color_id: String) -> Color:
	var value: Variant = COMBAT_MAP_COLOR_VALUES.get(
		color_id,
		COMBAT_MAP_DEFAULT_COLOR
	)
	return value as Color if value is Color else COMBAT_MAP_DEFAULT_COLOR


func _combat_color_label(color_id: String) -> String:
	return str({
		"life": "生命",
		"energy": "能源",
		"industry": "工业",
		"technology": "科技",
		"commerce": "商业",
		"shipping": "航运",
	}.get(color_id, color_id))
