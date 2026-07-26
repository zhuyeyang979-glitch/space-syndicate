@tool
extends Node
class_name CardPlayerFaceProjectionBench

const PlayerFaceDTO := preload("res://scripts/presentation/player_face_dto_v1.gd")
const CardSemanticSchema := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")

@export var auto_run := true
@export var exit_on_complete := false

var manifest: Dictionary = {
	"status": "WAITING",
	"bench_id": "card_player_face_projection.v1",
}

@onready var service: Node = $CardPlayerFaceProjectionService


func _ready() -> void:
	if Engine.is_editor_hint() or not auto_run:
		return
	call_deferred("run_bench")


func run_bench() -> void:
	var semantic := _semantic_spec()
	var localization := _localization_source(semantic)
	var records: Array = []

	var warmup_started := Time.get_ticks_usec()
	var market: Dictionary = service.project(semantic, localization, "market")
	var hand: Dictionary = service.project(semantic, localization, "hand")
	var detail: Dictionary = service.project(semantic, localization, "detail")
	var warmup_usec := Time.get_ticks_usec() - warmup_started
	_record(records, "shared_semantic_fixture_valid", bool(CardSemanticSchema.validate_semantic_spec(semantic).get("valid", false)))
	_record(records, "three_surfaces", not market.is_empty() and not hand.is_empty() and not detail.is_empty())
	_record(records, "dto_closed", bool(PlayerFaceDTO.validate(market).get("valid", false)))
	_record(records, "three_surface_identity_refs", _identity_refs_are_bound(market) and _identity_refs_are_bound(hand) and _identity_refs_are_bound(detail))
	_record(records, "market_acquisition_emphasis", str((market.get("acquisition_cost", {}) as Dictionary).get("emphasis_id", "")) == "primary")
	_record(records, "hand_activation_emphasis", str((hand.get("activation_cost", {}) as Dictionary).get("emphasis_id", "")) == "primary")
	_record(records, "detail_complete_costs", str((detail.get("acquisition_cost", {}) as Dictionary).get("emphasis_id", "")) == "complete" and str((detail.get("activation_cost", {}) as Dictionary).get("emphasis_id", "")) == "complete")
	_record(records, "costs_separate", int((market.get("acquisition_cost", {}) as Dictionary).get("purchase_cash", -1)) == 7 and int(((market.get("activation_cost", {}) as Dictionary).get("asset_cost", {}) as Dictionary).get("technology", -1)) == 2)
	_record(records, "ordered_effect_steps", _ordered_effects(market))
	_record(records, "structured_duration", _has_duration_parameter(market, "duration_seconds"))
	var duration_traps: Array = service._duration_components([{
		"op_id": "lock_random",
		"display_duration_seconds": 5,
		"cooldown_preview": 5,
		"termination_hint": "window.end",
		"persistence_color_token_id": "color.duration",
	}])
	_record(records, "duration_exact_allowlist_only", duration_traps.is_empty())
	var typed_argument_traps: Array = service._typed_args_from_dictionary({"display_cash_bonus": 3, "cooldown_seconds": 4, "speed_rate": 5})
	_record(records, "typed_arguments_exact_table_only", _all_typed_args_use(typed_argument_traps, "integer"))
	_record(records, "stable_keyword_tokens", _stable_keyword_tokens(market))

	var deterministic := true
	var baseline_fingerprint := str(market.get("dto_fingerprint", ""))
	for index in range(24):
		if str(service.project(semantic, localization, "market").get("dto_fingerprint", "")) != baseline_fingerprint:
			deterministic = false
			break
	_record(records, "deterministic_fingerprint", deterministic)

	var private_source := localization.duplicate(true)
	private_source["authorization_scope_id"] = "viewer_private"
	private_source["message_ids"]["timing"] = "not a stable message id"
	var private_report: Dictionary = service.project_report(semantic, private_source, "hand")
	_record(records, "privacy_before_localization", str(private_report.get("reason_id", "")) == "player_face_projection.localization_scope_violation")
	var hidden_source := localization.duplicate(true)
	hidden_source["keyword_rows"][0]["hidden_owner"] = "seat.2"
	_record(records, "hidden_source_rejected", str(service.project_report(semantic, hidden_source, "market").get("reason_id", "")).begins_with("player_face_projection.localization_private_field"))

	var projection_count := 900
	var accepted_count := 0
	var projection_started := Time.get_ticks_usec()
	for index in range(projection_count):
		var surface_id: String = PlayerFaceDTO.SURFACE_IDS[index % PlayerFaceDTO.SURFACE_IDS.size()]
		if not service.project(semantic, localization, surface_id).is_empty():
			accepted_count += 1
	var projection_total_usec := Time.get_ticks_usec() - projection_started
	var projection_average_usec := float(projection_total_usec) / float(projection_count)
	_record(records, "bounded_projection_count", accepted_count == projection_count)
	_record(records, "projection_total_under_5s", projection_total_usec < 5000000)
	_record(records, "projection_average_under_6ms", projection_average_usec < 6000.0)

	var debug: Dictionary = service.debug_snapshot()
	_record(records, "stateless_boundary", bool(debug.get("stateless", false)) and int(debug.get("cache_entries", -1)) == 0 and not bool(debug.get("owns_rules", true)) and not bool(debug.get("owns_legality", true)) and not bool(debug.get("owns_save_state", true)) and not bool(debug.get("uses_rng", true)) and not bool(debug.get("mutates_game_state", true)))
	_record(records, "shared_semantic_authority", str(debug.get("semantic_authority_id", "")) == "card_semantic_schema_v1")
	_record(records, "duration_allowlist_closed", debug.get("duration_parameter_ids", []) == ["counter_window_seconds", "duration_seconds", "persistence_id"])

	var passed_count := 0
	for record_variant in records:
		if bool((record_variant as Dictionary).get("passed", false)):
			passed_count += 1
	var status := "PASS" if passed_count == records.size() else "FAIL"
	manifest = {
		"schema_version": 1,
		"bench_id": "card_player_face_projection.v1",
		"scene_path": "res://scenes/tools/CardPlayerFaceProjectionBench.tscn",
		"service_scene_path": "res://scenes/runtime/CardPlayerFaceProjectionService.tscn",
		"status": status,
		"record_count": records.size(),
		"passed_count": passed_count,
		"records": records,
		"timing": {
			"warmup_usec": warmup_usec,
			"projection_count": projection_count,
			"accepted_count": accepted_count,
			"projection_total_usec": projection_total_usec,
			"projection_average_usec": projection_average_usec,
		},
		"targets": {
			"projection_total_usec_max": 5000000,
			"projection_average_usec_max": 6000,
		},
		"dto_fingerprint": baseline_fingerprint,
		"debug_error_count": 0,
	}
	print("CARD_PLAYER_FACE_PROJECTION_BENCH|status=%s|checks=%d|passed=%d|projections=%d|total_usec=%d|average_usec=%.2f|fingerprint=%s" % [status, records.size(), passed_count, projection_count, projection_total_usec, projection_average_usec, baseline_fingerprint])
	if exit_on_complete:
		get_tree().quit(0 if status == "PASS" else 1)


func debug_snapshot() -> Dictionary:
	return manifest.duplicate(true)


func _record(records: Array, case_id: String, passed: bool) -> void:
	records.append({"case_id": case_id, "passed": passed})


func _ordered_effects(dto: Dictionary) -> bool:
	var steps: Array = dto.get("effect_steps", []) as Array
	return steps.size() == 2 \
		and int((steps[0] as Dictionary).get("order", 0)) == 1 \
		and str((steps[0] as Dictionary).get("op_id", "")) == "discard_random" \
		and int((steps[1] as Dictionary).get("order", 0)) == 2 \
		and str((steps[1] as Dictionary).get("op_id", "")) == "lock_random"


func _has_duration_parameter(dto: Dictionary, parameter_id: String) -> bool:
	var duration: Dictionary = dto.get("duration", {}) as Dictionary
	for component_variant in duration.get("components", []) as Array:
		if str((component_variant as Dictionary).get("parameter_id", "")) == parameter_id:
			return true
	return false


func _all_typed_args_use(value: Array, type_id: String) -> bool:
	if value.is_empty():
		return false
	for arg_variant in value:
		if str((arg_variant as Dictionary).get("type_id", "")) != type_id:
			return false
	return true


func _stable_keyword_tokens(dto: Dictionary) -> bool:
	var keywords: Array = dto.get("keywords", []) as Array
	if keywords.is_empty():
		return false
	for row_variant in keywords:
		var row: Dictionary = row_variant
		if not PlayerFaceDTO.is_stable_id(str(row.get("keyword_id", ""))) \
				or not str(row.get("icon_token_id", "")).begins_with("icon.") \
				or not str(row.get("color_token_id", "")).begins_with("color.") \
				or str(row.get("color_token_id", "")).contains("#"):
			return false
	return true


func _identity_refs_are_bound(dto: Dictionary) -> bool:
	var name_ref: Dictionary = dto.get("name_ref", {}) as Dictionary
	var family_name_ref: Dictionary = dto.get("family_name_ref", {}) as Dictionary
	var name_args: Array = name_ref.get("args", []) as Array
	var family_args: Array = family_name_ref.get("args", []) as Array
	if name_args.size() != 1 or family_args.size() != 1:
		return false
	var name_binding: Dictionary = name_args[0] as Dictionary
	var family_binding: Dictionary = family_args[0] as Dictionary
	return PlayerFaceDTO.is_stable_id(str(name_ref.get("message_id", ""))) \
		and PlayerFaceDTO.is_stable_id(str(family_name_ref.get("message_id", ""))) \
		and str(name_binding.get("arg_id", "")) == "card_id" \
		and str(name_binding.get("value", "")) == str(dto.get("card_id", "")) \
		and str(family_binding.get("arg_id", "")) == "family_id" \
		and str(family_binding.get("value", "")) == str(dto.get("family_id", ""))


func _semantic_spec() -> Dictionary:
	var spec := {
		"schema_version": 1,
		"source_catalog_id": "space_syndicate.card_runtime_catalog.v06",
		"source_definition_fingerprint": "a".repeat(64),
		"semantic_fingerprint": "",
		"identity": {
			"card_id": "interaction.blackout.rank_2",
			"family_id": "interaction.blackout",
			"rank": 2,
			"category_id": "interaction",
			"available_for_acquisition": true,
		},
		"cost": {
			"acquisition": {"acquisition_kind": "region_rack_cash", "purchase_cash": 7},
			"activation": {
				"life": 0,
				"energy": 1,
				"industry": 0,
				"technology": 2,
				"commerce": 0,
				"shipping": 0,
				"generic": 1,
			},
		},
		"timing": {"timing_id": "main_action"},
		"target": {
			"target_id": "player.opponent",
			"selection_id": "actor_choice",
			"cardinality_id": "exactly_one",
			"filter_ids": ["hand.discardable"],
		},
		"effect_ops": [
			{"op_id": "discard_random", "count": 1, "target_cash_penalty": 0},
			{"op_id": "lock_random", "duration_seconds": 5},
		],
		"response": {"response_id": "counterable"},
		"information_policy": {"visibility_policy_id": "authorized_source_only"},
		"runtime_readiness_id": "projection_only",
	}
	spec["semantic_fingerprint"] = CardSemanticSchema.fingerprint(spec, "semantic_fingerprint")
	return spec


func _localization_source(semantic: Dictionary) -> Dictionary:
	return {
		"schema_version": 1,
		"source_id": "player_face.interaction.blackout.rank_2.zh_hans",
		"card_id": "interaction.blackout.rank_2",
		"semantic_fingerprint": str(semantic.get("semantic_fingerprint", "")),
		"authorization_scope_id": "public",
		"authorization_revision": 1,
		"authorized": true,
		"message_ids": {
			"name": "card.name.interaction.blackout.rank_2",
			"family_name": "card.family.interaction.blackout",
			"acquisition_cost": "card.cost.acquisition.region_rack_cash",
			"activation_cost": "card.cost.activation.assets",
			"timing": "card.timing.main_action",
			"duration": "card.duration.effect_defined",
			"counterability": "card.counterability.counterable",
			"information_scope": "card.information.anonymous_direct_interaction",
		},
		"target_message_rows": [
			{"target_id": "player.opponent", "message_id": "card.target.player.opponent"},
		],
		"condition_message_rows": [
			{"condition_id": "hand.discardable", "message_id": "card.condition.hand.discardable"},
		],
		"effect_step_message_rows": [
			{"order": 1, "op_id": "discard_random", "summary_message_id": "card.effect.discard_random.summary", "detail_message_id": "card.effect.discard_random.detail"},
			{"order": 2, "op_id": "lock_random", "summary_message_id": "card.effect.lock_random.summary", "detail_message_id": "card.effect.lock_random.detail"},
		],
		"keyword_rows": [
			{"keyword_id": "interaction.hand_disrupt", "label_message_id": "card.keyword.interaction.hand_disrupt.label", "tooltip_message_id": "card.keyword.interaction.hand_disrupt.tooltip", "icon_token_id": "icon.card.hand_disrupt", "color_token_id": "color.card.interaction"},
			{"keyword_id": "response.counterable", "label_message_id": "card.keyword.response.counterable.label", "tooltip_message_id": "card.keyword.response.counterable.tooltip", "icon_token_id": "icon.card.counterable", "color_token_id": "color.card.response"},
		],
	}
