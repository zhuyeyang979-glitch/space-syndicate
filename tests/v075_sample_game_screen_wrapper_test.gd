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


class FakeFlow:
	extends Node

	var issued: Array[Dictionary] = []
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
		return {"runtime": {}}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var screen := ScreenScene.instantiate() as V075SampleGameScreen
	root.add_child(screen)
	await process_frame
	var flow := FakeFlow.new()
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
		and bool(debug.get("application_flow_bound", false)),
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
			"action_domain": "monster",
			"card_instance_id": "card.monster.local.01",
			"card_definition_id": "monster.spore_tide_emperor.life.rank_1",
			"monster_card_mode": "DEPLOY_NEW",
			"target_slot_id": "combat.monster.deploy_new.region.01",
			"target_region_id": "region.01",
			"target_source_instance_id": "",
			"mode_prebound": true,
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

	var surface := screen.get_node(
		"PlaytestUtilityLayer/PlaytestSafeArea/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface"
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
	surface.private_target_selection_requested.emit(
		{
			"source_instance_id": "monster.tech.local.01",
			"skill_definition_id": "skill.tech.prism.l1",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.tech.local.01",
			},
		}
	)
	surface.military_mission_selected.emit({
		"option_id": "option.military.region.local",
		"owner_player_id": "player.local",
		"card_instance_id": "dbg.military.local.01",
		"card_definition_id": "military.submarine_fleet.life.rank_1",
		"target_slot_id": "combat.military.assault_region.region.14",
		"task_kind": "assault_region",
		"target_region_id": "region.14",
		"target_monster_source_instance_id": "",
	})
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
					str(intent.get("combat_channel", "")) == "public_batch",
					"military intent remains an ordinary batch action"
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
	var first_result := screen.apply_combat_receipt(receipt)
	var duplicate_result := screen.apply_combat_receipt(receipt.duplicate(true))
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
		screen.apply_combat_receipt(sequence_receipt)
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
			"skill_definition_id": "skill.tech.prism.l1",
			"target_binding": {
				"target_kind": "monster",
				"target_id": "monster.tech.local.01",
			},
		}
	)
	await process_frame
	var terminal_debug := screen.combat_debug_snapshot()
	_expect(
		int(terminal_debug.get("private_skill_intent_count", 0)) == 1
		and intents_before_terminal == 2,
		"terminal combat rejects new private requests"
	)

	screen.queue_free()
	flow.queue_free()
	_finish()


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
