extends SceneTree

const ScreenScene := preload(
	"res://scenes/ui/v075/V075SampleGameScreen.tscn"
)
const Bench := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)
const ProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const PresentationIdentity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)


class FakeFlow:
	extends Node

	var issued: Array[Dictionary] = []
	var composition_debug: Dictionary = {"runtime": {}}
	var planet_map_view_payload_call_count := 0
	var _sequence := 0

	func issue_intent(
		intent_kind: String,
		parameters: Dictionary = {}
	) -> Dictionary:
		_sequence += 1
		var intent := {
			"schema": "V075ApplicationIntentV1",
			"intent_id": "test.intent.%03d" % _sequence,
			"intent_kind": intent_kind,
			"ruleset_id": "v0.7.5",
			"parameters": parameters.duplicate(true),
		}
		issued.append(intent.duplicate(true))
		return intent

	func debug_snapshot() -> Dictionary:
		return composition_debug.duplicate(true)

	func planet_map_view_payload(
		_selected_card_id: String,
		_selected_region_id: String
	) -> Dictionary:
		planet_map_view_payload_call_count += 1
		return {}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := ScreenScene.instantiate() as V075SampleGameScreen
	root.add_child(screen)
	await process_frame
	var flow := FakeFlow.new()
	flow.set_meta("v075_isolated_preview_flow", true)
	root.add_child(flow)
	var emitted: Array[Dictionary] = []
	screen.application_intent_requested.connect(
		func(intent: Dictionary) -> void:
			emitted.append(intent.duplicate(true))
	)
	screen.bind_application_flow(
		flow,
		{
			"ruleset_id": "v0.7.5",
			"viewer_player_id": "player.local",
		},
		{
			"combat": {
				"private_skill_intent_kind": "combat.skill.request",
				"military_intent_kind": "combat.mission.select",
			},
		}
	)

	var authority := Bench.make_authority_snapshot()
	var projection := ProjectionAdapter.new().project_for_viewer(
		authority,
		"player.local"
	)
	var region_military_option: Dictionary = {}
	var monster_military_option: Dictionary = {}
	for option_variant in projection.get("military_task_options", []) as Array:
		var projected_option := option_variant as Dictionary
		if str(projected_option.get("task_kind", "")) == "assault_region":
			region_military_option = projected_option.duplicate(true)
		elif str(projected_option.get("task_kind", "")) == "assault_monster":
			monster_military_option = projected_option.duplicate(true)
	screen.apply_snapshot({
		"ruleset_id": "v0.7.5",
		"phase": "batch_active",
		"match_started": false,
		"combat_player_projection": projection,
	})
	await process_frame
	var debug := screen.combat_debug_snapshot()
	var planet_title := screen.get_node(
		"RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetHudRow/PlanetTitle"
	) as Label
	_expect(
		planet_title.text == "V0.7.5 动态行星",
		"production wrapper removes inherited V0.7.4 planet chrome"
	)
	_expect(
		str(screen.acceptance_state.get("ruleset_id", "")) == "v0.7.5",
		"wrapper accepts a V0.7.5 snapshot while preserving the V0.7.4 base"
	)
	_expect(
		int(debug.get("projection_count", 0)) == 1
		and bool(debug.get("application_flow_bound", false))
		and str(debug.get("presentation_source_mode", ""))
			== "isolated_preview",
		"application-flow snapshot reaches the combat surface"
	)
	var surface_debug := debug.get("surface", {}) as Dictionary
	var dock_debug := surface_debug.get("owner_skill_dock", {}) as Dictionary
	_expect(
		int(dock_debug.get("skill_card_count", 0)) == 4
		and int(surface_debug.get("military_task_button_count", 0)) == 2,
		"owner surface keeps four private skills and two military actions"
	)

	# Monster cards must use the combat legal-action projection directly. The
	# inherited map rail is reserved for facility bindings and must not consume
	# a monster mode selection.
	screen.apply_snapshot({
		"ruleset_id": "v0.7.5",
		"phase": "submission",
		"match_started": false,
		"legal_actions": [{
			"option_id": "option.monster.local.binding",
			"action_domain": "monster",
			"card_instance_id": "card.monster.local.01",
			"card_definition_id": "monster.spore_tide_emperor.life.rank_1",
			"monster_card_mode": "DEPLOY_NEW",
			"target_slot_id": "combat.monster.deploy_new.region.01",
			"target_region_id": "region.01",
			"target_source_instance_id": "",
			"mode_prebound": true,
			"card_action_binding": Bench.make_card_action_binding_fixture(
				"player.local",
				"card.monster.local.01",
				"monster.spore_tide_emperor.life.rank_1",
				7
			),
		}],
		"personal_dbg": {"facts": {"hand": []}},
		"combat_player_projection": projection,
	})
	screen.call("_on_hand_card_activated", {
		"instance_id": "card.monster.local.01",
		"definition_id": "monster.spore_tide_emperor.life.rank_1",
		"card_type": "monster.spore_tide_emperor",
		"primary_color": "life",
	})
	await process_frame
	var mode_choices := screen.get_node(
		"OverlayLayer/RegionPopup/Center/Panel/Rows/RegionPopupTargetChoices"
	) as VBoxContainer
	var first_mode_row := mode_choices.get_child(0) as HBoxContainer
	_expect(
		mode_choices.get_child_count() == 4
		and first_mode_row != null
		and (first_mode_row.get_child(1) as Button).text == "部署新怪兽",
		"monster hand selection exposes four explicit mode rows"
	)
	(first_mode_row.get_child(1) as Button).pressed.emit()
	await process_frame
	var current_action_confirm := screen.find_child(
		"CurrentActionConfirmButton",
		true,
		false
	) as Button
	_expect(
		current_action_confirm != null and not current_action_confirm.disabled,
		"monster mode selection exposes an enabled fixed confirmation button"
	)
	current_action_confirm.pressed.emit()
	await process_frame
	var monster_queue_intent: Dictionary = {}
	if not emitted.is_empty():
		monster_queue_intent = emitted.back().duplicate(true)
	_expect(
		str(monster_queue_intent.get("intent_kind", "")) == "card.queue"
		and str((monster_queue_intent.get("parameters", {}) as Dictionary).get(
			"target_slot_id",
			""
		)) == "combat.monster.deploy_new.region.01",
		"monster mode uses the normal card queue intent without map resolution"
	)

	var surface := screen.find_child(
		"CombatSurface",
		true,
		false
	) as V075CombatPlayerSurface
	var map_view := screen.get_node(
		"RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/"
		+ "PlanetStageViewport/MapHost/PlanetMapView"
	) as Control
	var map_districts: Array = []
	var map_centers := {
		"region.04": Vector2(160.0, 190.0),
		"region.07": Vector2(280.0, 300.0),
		"region.08": Vector2(390.0, 360.0),
		"region.10": Vector2(510.0, 430.0),
		"region.11": Vector2(620.0, 330.0),
		"region.14": Vector2(740.0, 470.0),
	}
	for region_id_variant in map_centers.keys():
		var region_id := str(region_id_variant)
		var center := map_centers.get(region_id) as Vector2
		map_districts.append({
			"region_id": region_id,
			"name": region_id,
			"center": center,
			"polygon": [
				center + Vector2(-30.0, -24.0),
				center + Vector2(30.0, -24.0),
				center + Vector2(30.0, 24.0),
				center + Vector2(-30.0, 24.0),
			],
			"terrain": "land",
			"terrain_class": "land",
			"legal_target": true,
			"products": [],
		})
	var map_palette: Array = []
	for _district in map_districts:
		map_palette.append(Color("#27485f"))
	map_view.call(
		"set_map",
		map_districts,
		1000.0,
		700.0,
		-1,
		map_palette,
		[],
		[],
		[],
		[],
		[],
		[],
		"",
		"all"
	)
	screen.apply_combat_projection(
		projection,
		"monster.tech.local.01"
	)
	await process_frame
	var map_projection_debug := screen.combat_debug_snapshot()
	_expect(
		int(map_projection_debug.get("combat_map_marker_count", 0)) == 2,
		"combat projection places both public monsters on the production map"
	)
	var emitted_before_invalid_identity := emitted.size()
	surface.private_target_selection_requested.emit(
		{
			"source_instance_id": "monster.tech.local.01",
			"skill_definition_id": "skill.tech.prism.l1",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.tech.local.01",
				"target_source_generation": 4,
			},
			"target_contract": {"target_kind": "self_source"},
		}
	)
	var missing_card_binding := region_military_option.duplicate(true)
	missing_card_binding.erase("card_action_binding")
	surface.military_mission_selected.emit(missing_card_binding)
	surface.private_target_selection_requested.emit(
		{
			"source_instance_id": "monster.tech.local.01",
			"source_generation": 3,
			"skill_definition_id": "skill.tech.prism.l1",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.tech.local.01",
				"target_source_generation": 3,
			},
			"target_contract": {"target_kind": "self_source"},
		}
	)
	var stale_monster_option := monster_military_option.duplicate(true)
	stale_monster_option["target_source_generation"] = 1
	surface.military_mission_selected.emit(stale_monster_option)
	await process_frame
	_expect(
		emitted.size() == emitted_before_invalid_identity,
		"missing or stale source/card/target binding produces no canonical submission"
	)
	surface.private_target_selection_requested.emit(
		{
			"source_instance_id": "monster.tech.local.01",
			"source_generation": 4,
			"skill_definition_id": "skill.tech.prism.l1",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.tech.local.01",
				"target_source_generation": 4,
			},
			"target_contract": {"target_kind": "self_source"},
		}
	)
	surface.military_mission_selected.emit(region_military_option)
	await process_frame
	debug = screen.combat_debug_snapshot()
	var private_intent_count := 0
	var military_intent_count := 0
	for intent in emitted:
		match str(intent.get("intent_kind", "")):
			"combat.skill.request":
				private_intent_count += 1
				_expect(
					str(intent.get("combat_channel", "")) ==
						"private_instant_serial",
					"private skill intent uses the private serial channel"
				)
			"combat.mission.select":
				military_intent_count += 1
				_expect(
					str(intent.get("combat_channel", "")) == "private_direct_action",
					"military intent uses the V076 private direct-action channel"
				)
				_expect(
					str((intent.get("parameters", {}) as Dictionary).get(
						"option_id",
						""
					)) == "option.military.region.local",
					"military intent preserves the selected option identity"
				)
	_expect(
		private_intent_count == 1
		and military_intent_count == 1
		and int(debug.get("private_skill_intent_count", 0)) == 1
		and int(debug.get("military_intent_count", 0)) == 1,
		"surface intents are forwarded exactly once"
	)

	var receipt := {
		"combat_receipt_id": "wrapper.receipt.001",
		"event_kind": "monster_moved",
		"source_rank": 2,
		"movement_profile": "ground_trample",
		"start_region_id": "region.07",
		"destination_region_id": "region.14",
		"ordered_region_path": [
			"region.07",
			"region.10",
			"region.14",
		],
		"public_summary": "公开路径已结算",
	}
	var receipt_v2 := _v2(receipt, 0)
	var first_result := screen.apply_combat_receipt(receipt_v2)
	var duplicate_result := screen.apply_combat_receipt(
		receipt_v2.duplicate(true)
	)
	var after_receipt := screen.combat_debug_snapshot()
	_expect(
		bool(first_result.get("applied", false))
		and str(duplicate_result.get("reason_code", "")) ==
			"combat_presentation_receipt_duplicate",
		"combat receipt reaches the exact-once presentation consumer"
	)
	_expect(
		int(after_receipt.get("receipt_applied_count", 0)) == 1
		and int(after_receipt.get("receipt_duplicate_count", 0)) == 1
		and int(after_receipt.get("gameplay_mutation_count", -1)) == 0
		and int(after_receipt.get("rng_draw_delta", -1)) == 0,
		"presentation forwarding remains read-only"
	)
	var surface_after_receipt := after_receipt.get("surface", {}) as Dictionary
	_expect(
		bool(surface_after_receipt.get("presentation_asset_key_visible", false))
		and int(surface_after_receipt.get("presentation_animation_count", 0)) == 1,
		"public cue renders an asset key and a presentation pulse"
	)
	_expect(
		int(after_receipt.get("combat_map_trail_count", 0)) == 2
		and int(after_receipt.get("combat_map_callout_count", 0)) >= 1,
		"public movement receipt renders two production map trail segments"
	)
	var presentation_sequence := 1
	for sequence_receipt in [
		{
			"combat_receipt_id": "wrapper.receipt.002",
			"event_kind": "monster_trample_resolved",
			"source_instance_id": "monster.tech.local.01",
			"preferred_industry_color": "technology",
			"region_id": "region.10",
			"distance_milli_arc": 170,
			"region_damage_budget": 6,
		},
		{
			"combat_receipt_id": "wrapper.receipt.003",
			"event_kind": "military_region_assault",
			"target_region_id": "region.14",
			"region_damage_budget": 12,
			"military_tier": 2,
		},
		{
			"combat_receipt_id": "wrapper.receipt.004",
			"event_kind": "military_withdrawn",
			"target_region_id": "region.14",
			"military_tier": 2,
		},
	]:
		screen.apply_combat_receipt(
			_v2(sequence_receipt as Dictionary, presentation_sequence)
		)
		presentation_sequence += 1
	await process_frame
	var after_sequence := screen.combat_debug_snapshot()
	var sequence_surface := after_sequence.get("surface", {}) as Dictionary
	var presentation_history := JSON.stringify(
		sequence_surface.get("presentation_history", [])
	)
	_expect(
		int(after_sequence.get("combat_map_effect_count", 0)) >= 2
		and int(after_sequence.get("combat_map_callout_count", 0)) >= 4,
		"trample, military attack and withdrawal remain visible in map layers"
	)
	_expect(
		int(sequence_surface.get("presentation_history_count", 0)) == 4
		and "军队完成地区攻击" in presentation_history
		and "已撤离并弃置" in presentation_history,
		"withdrawal appends to receipt history without erasing the attack cue"
	)

	screen.apply_snapshot({
		"ruleset_id": "v0.7.5",
		"phase": "final_settlement",
		"match_started": false,
		"combat_player_projection": projection,
	})
	await process_frame
	var intents_before_terminal := private_intent_count + military_intent_count
	surface.private_target_selection_requested.emit(
		{
			"source_instance_id": "monster.tech.local.01",
			"source_generation": 4,
			"skill_definition_id": "skill.tech.prism.l1",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.tech.local.01",
				"target_source_generation": 4,
			},
			"target_contract": {"target_kind": "self_source"},
		}
	)
	await process_frame
	var terminal_debug := screen.combat_debug_snapshot()
	_expect(
		int(terminal_debug.get("private_skill_intent_count", 0)) == 1
		and intents_before_terminal == 2,
		"terminal combat rejects new private requests"
	)

	flow.composition_debug = _valid_runtime_acceptance_source()
	screen.apply_snapshot({
		"ruleset_id": "v0.7.5",
		"phase": "settled",
		"match_started": true,
	})
	await process_frame
	_expect(
		flow.planet_map_view_payload_call_count == 1,
		"settled started snapshot exercises the map payload contract once"
	)
	var runtime_acceptance := screen.acceptance_state.get(
		"runtime_acceptance_debug",
		{}
	) as Dictionary
	var expected_acceptance := _expected_runtime_acceptance_debug()
	_expect(
		runtime_acceptance == expected_acceptance
		and _same_variant_shape(runtime_acceptance, expected_acceptance),
		"settled acceptance debug is an exact closed and strictly typed whitelist"
	)
	_expect(
		not _contains_forbidden_acceptance_key(runtime_acceptance),
		"acceptance whitelist excludes runtime identifiers, receipts and payloads"
	)

	var invalid_sources: Array[Dictionary] = []
	var invalid_dictionary := _valid_runtime_acceptance_source()
	var invalid_dictionary_runtime := (
		invalid_dictionary["runtime"] as Dictionary
	)
	invalid_dictionary_runtime["combat"] = []
	invalid_sources.append({
		"label": "dictionary",
		"source": invalid_dictionary,
	})
	var invalid_string := _valid_runtime_acceptance_source()
	var invalid_string_runtime := invalid_string["runtime"] as Dictionary
	invalid_string_runtime["phase"] = 75
	invalid_sources.append({
		"label": "string",
		"source": invalid_string,
	})
	var invalid_boolean := _valid_runtime_acceptance_source()
	var invalid_boolean_runtime := invalid_boolean["runtime"] as Dictionary
	var invalid_boolean_combat := (
		invalid_boolean_runtime["combat"] as Dictionary
	)
	var invalid_effect_integrity := (
		invalid_boolean_combat["combat_effect_integrity"] as Dictionary
	)
	invalid_effect_integrity["green"] = 1
	invalid_sources.append({
		"label": "boolean",
		"source": invalid_boolean,
	})
	var invalid_string_count := _valid_runtime_acceptance_source()
	var invalid_string_count_runtime := (
		invalid_string_count["runtime"] as Dictionary
	)
	invalid_string_count_runtime["runtime_error_count"] = "0"
	invalid_sources.append({
		"label": "string count",
		"source": invalid_string_count,
	})
	var invalid_float_count := _valid_runtime_acceptance_source()
	var invalid_float_count_runtime := (
		invalid_float_count["runtime"] as Dictionary
	)
	invalid_float_count_runtime["runtime_error_count"] = 0.0
	invalid_sources.append({
		"label": "float count",
		"source": invalid_float_count,
	})
	var invalid_negative_count := _valid_runtime_acceptance_source()
	var invalid_negative_count_runtime := (
		invalid_negative_count["runtime"] as Dictionary
	)
	invalid_negative_count_runtime["nonfinite_count"] = -1
	invalid_sources.append({
		"label": "negative count",
		"source": invalid_negative_count,
	})
	var invalid_missing_count := _valid_runtime_acceptance_source()
	var invalid_missing_count_runtime := (
		invalid_missing_count["runtime"] as Dictionary
	)
	invalid_missing_count_runtime.erase("combat_public_receipt_count")
	invalid_sources.append({
		"label": "missing count",
		"source": invalid_missing_count,
	})
	for invalid_case in invalid_sources:
		flow.composition_debug = (
			invalid_case["source"] as Dictionary
		).duplicate(true)
		var rejected_debug := screen.call(
			"_runtime_acceptance_debug_snapshot"
		) as Dictionary
		_expect(
			rejected_debug.is_empty(),
			"acceptance debug fails closed for %s drift" % invalid_case["label"]
		)

	screen.queue_free()
	flow.queue_free()
	_finish()


func _valid_runtime_acceptance_source() -> Dictionary:
	return {
		"schema": "V075RuntimeCompositionDebugV1",
		"ruleset_id": "v0.7.5",
		"last_receipt": {"visibility_scope": "actor_private"},
		"runtime": {
			"ruleset_id": "v0.7.5",
			"phase": "settled",
			"match_id": "private.match.001",
			"combat": {
				"monster_card_mode_counts": {
					"DEPLOY_NEW": 2,
					"REFRESH_EXISTING": 3,
					"UPGRADE_EXISTING": 4,
					"REPLACE_EXISTING": 5,
					"source_instance_id": "private.source.001",
				},
				"monster_private_skill_commit_count": 6,
				"monster_trample_region_receipt_count": 7,
				"military_region_assault_count": 8,
				"military_monster_assault_count": 9,
				"runtime_error_count": 0,
				"combat_duplicate_effect_count": 0,
				"combat_effect_integrity": {
					"green": true,
					"violation_count": 0,
					"validation_state": {"private": true},
				},
				"combat_receipt_integrity": {
					"green": true,
					"last_receipt": {"private": true},
				},
				"private_payload": {"owner_player_id": "player.local"},
			},
			"facility_combat_damage_receipt_count": 10,
			"facility_effect_integrity": {
				"green": true,
				"owner_player_id": "player.local",
			},
			"combat_presentation": {
				"applied_receipt_count": 11,
				"duplicate_receipt_count": 0,
				"collision_receipt_count": 0,
				"rejected_receipt_count": 12,
				"presentation_gameplay_mutation_count": 0,
				"presentation_rng_draw_delta": 0,
				"last_cue": {"public_payload": {"damage_amount": 3}},
			},
			"combat_public_receipt_count": 11,
			"final_settlement_count": 1,
			"duplicate_settlement_count": 0,
			"final_settlement_public_log_count": 1,
			"final_settlement_presentation_count": 1,
			"runtime_error_count": 0,
			"hidden_info_violation_count": 0,
			"combat_telemetry": {
				"schema": "V075CombatTelemetryServiceDebugV1",
				"ruleset_id": "v0.7.5",
				"hidden_input_field_count": 13,
				"opponent_skill_definition_input_count": 0,
				"opponent_skill_target_input_count": 0,
				"opponent_skill_cooldown_input_count": 0,
				"instant_sequence_input_count": 0,
				"warehouse_private_stock_input_count": 0,
				"ai_private_plan_input_count": 0,
				"stored_hidden_field_count": 0,
				"gameplay_owner_count": 0,
				"rng_owner_count": 0,
				"world_mutation_count": 0,
				"last_event": {"private_payload": {"hidden": true}},
			},
			"combat_telemetry_hidden_field_count": 0,
			"combat_telemetry_gameplay_owner_count": 0,
			"combat_telemetry_rng_owner_count": 0,
			"combat_telemetry_world_mutation_count": 0,
			"invalid_action_count": 0,
			"ai_combat_invalid_target_count": 0,
			"nonfinite_count": 0,
			"last_receipt": {"visibility_scope": "actor_private"},
		},
	}


func _v2(raw_receipt: Dictionary, sequence: int) -> Dictionary:
	var source_id := str(raw_receipt.get("combat_receipt_id", ""))
	return PresentationIdentity.build_public(
		source_id,
		PresentationIdentity.source_fingerprint(source_id, raw_receipt),
		sequence,
		str(raw_receipt.get("event_kind", "")),
		0,
		"v0.7.5",
		"session.sample.game.screen.wrapper.test",
		raw_receipt
	)


func _expected_runtime_acceptance_debug() -> Dictionary:
	return {
		"schema": "V075RuntimeAcceptanceDebugV1",
		"ruleset_id": "v0.7.5",
		"phase": "settled",
		"combat": {
			"monster_card_mode_counts": {
				"DEPLOY_NEW": 2,
				"REFRESH_EXISTING": 3,
				"UPGRADE_EXISTING": 4,
				"REPLACE_EXISTING": 5,
			},
			"monster_private_skill_commit_count": 6,
			"monster_trample_region_receipt_count": 7,
			"military_region_assault_count": 8,
			"military_monster_assault_count": 9,
			"runtime_error_count": 0,
			"combat_duplicate_effect_count": 0,
			"combat_effect_integrity": {
				"green": true,
				"violation_count": 0,
			},
			"combat_receipt_integrity": {"green": true},
		},
		"facility_combat_damage_receipt_count": 10,
		"facility_effect_integrity": {"green": true},
		"combat_presentation": {
			"applied_receipt_count": 11,
			"duplicate_receipt_count": 0,
			"collision_receipt_count": 0,
			"rejected_receipt_count": 12,
			"presentation_gameplay_mutation_count": 0,
			"presentation_rng_draw_delta": 0,
		},
		"combat_public_receipt_count": 11,
		"final_settlement_count": 1,
		"duplicate_settlement_count": 0,
		"final_settlement_public_log_count": 1,
		"final_settlement_presentation_count": 1,
		"runtime_error_count": 0,
		"hidden_info_violation_count": 0,
		"combat_telemetry": {
			"schema": "V075CombatTelemetryServiceDebugV1",
			"ruleset_id": "v0.7.5",
			"hidden_input_field_count": 13,
			"opponent_skill_definition_input_count": 0,
			"opponent_skill_target_input_count": 0,
			"opponent_skill_cooldown_input_count": 0,
			"instant_sequence_input_count": 0,
			"warehouse_private_stock_input_count": 0,
			"ai_private_plan_input_count": 0,
			"stored_hidden_field_count": 0,
			"gameplay_owner_count": 0,
			"rng_owner_count": 0,
			"world_mutation_count": 0,
		},
		"combat_telemetry_hidden_field_count": 0,
		"combat_telemetry_gameplay_owner_count": 0,
		"combat_telemetry_rng_owner_count": 0,
		"combat_telemetry_world_mutation_count": 0,
		"invalid_action_count": 0,
		"ai_combat_invalid_target_count": 0,
		"nonfinite_count": 0,
	}


func _same_variant_shape(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if actual is Dictionary:
		var actual_dictionary := actual as Dictionary
		var expected_dictionary := expected as Dictionary
		if actual_dictionary.size() != expected_dictionary.size():
			return false
		for key_variant in expected_dictionary:
			if (
				not actual_dictionary.has(key_variant)
				or not _same_variant_shape(
					actual_dictionary[key_variant],
					expected_dictionary[key_variant]
				)
			):
				return false
	elif actual is Array:
		var actual_array := actual as Array
		var expected_array := expected as Array
		if actual_array.size() != expected_array.size():
			return false
		for index in range(expected_array.size()):
			if not _same_variant_shape(
				actual_array[index],
				expected_array[index]
			):
				return false
	return true


func _contains_forbidden_acceptance_key(value: Variant) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary:
			if key_variant in [
				"match_id",
				"session_id",
				"intent_id",
				"request_id",
				"source_instance_id",
				"owner_player_id",
				"last_receipt",
				"last_cue",
				"last_event",
				"private_payload",
				"public_payload",
				"validation_state",
			]:
				return true
			if _contains_forbidden_acceptance_key(dictionary[key_variant]):
				return true
	elif value is Array:
		for item in (value as Array):
			if _contains_forbidden_acceptance_key(item):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_SAMPLE_GAME_SCREEN_WRAPPER_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
