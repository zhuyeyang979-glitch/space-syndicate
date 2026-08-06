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

	var surface := screen.get_node(
		"PlaytestUtilityLayer/PlaytestSafeArea/V075CombatOverlay/Margin/Rows/SurfaceHost/CombatSurface"
	) as V075CombatPlayerSurface
	surface.private_target_selection_requested.emit(
		"monster.tech.local.01",
		"skill.tech.prism.l1",
		"enemy_facility"
	)
	surface.military_mission_selected.emit("assault_region")
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
		"start_region_id": "region.01",
		"destination_region_id": "region.02",
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

	screen.apply_snapshot({
		"ruleset_id": "v0.7.5",
		"phase": "final_settlement",
		"match_started": false,
		"combat_player_projection": projection,
	})
	await process_frame
	var intents_before_terminal := private_intent_count + military_intent_count
	surface.private_target_selection_requested.emit(
		"monster.tech.local.01",
		"skill.tech.prism.l1",
		"enemy_facility"
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
