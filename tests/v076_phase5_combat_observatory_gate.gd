extends SceneTree

## Focused Phase 5 presentation gate.
##
## FIXTURE_CLASS=PRESENTATION_FIXTURE
## This sealed fixture exercises the production Consumer -> Director -> Surface
## presentation chain. It is not a natural match, a human playtest, or evidence
## for production green. The fixture never issues gameplay commands.

const FIXTURE_CLASS := "PRESENTATION_FIXTURE"
const SCREEN_SCENE := preload(
	"res://scenes/ui/v075/V075SampleGameScreen.tscn"
)
const COMBAT_SURFACE_BENCH := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)
const PRESENTATION_IDENTITY := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const RUNTIME_COMPOSITION_PATH := (
	"res://scenes/runtime/V075RuntimeComposition.tscn"
)
const SCREEN_SCENE_PATH := (
	"res://scenes/ui/v075/V075SampleGameScreen.tscn"
)
const RUNTIME_OWNER_PATH := (
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const COMBAT_OWNER_SCRIPT_PATH := (
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const CONSUMER_SCRIPT_PATH := (
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)
const DIRECTOR_SCRIPT_PATH := (
	"res://scripts/presentation/v076_presentation_animation_director.gd"
)
const TEST_VIEWPORT := Vector2i(1600, 960)
const FIXTURE_SESSION_ID := "session.phase5.combat.observatory.fixture"
const REQUIRED_WINDOW_COUNT := 3
const RECT_EPSILON := 0.75
const PRIVATE_FIELD_FRAGMENTS := [
	"skill_definition",
	"skill_card",
	"skill_target",
	"cooldown_remaining",
	"private",
	"future",
	"instant_sequence",
	"internal_order",
	"warehouse_stock",
	"logistics_plan",
	"ai_plan",
	"hidden",
	"rng_state",
	"owner_player_id",
	"player_id",
	"source_instance_id",
	"card_instance_id",
]


class FixtureFlow:
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
			"intent_id": "phase5.fixture.intent.%03d" % _sequence,
			"intent_kind": intent_kind,
			"ruleset_id": "v0.7.5",
			"parameters": parameters.duplicate(true),
		}
		issued.append(intent.duplicate(true))
		return intent

	func debug_snapshot() -> Dictionary:
		return {"runtime": {}}

	func planet_map_view_payload(
		_selected_card_id: String,
		_selected_region_id: String
	) -> Dictionary:
		return {}


var _checks := 0
var _failures: Array[String] = []
var _finish_signal_count := 0
var _finish_signal_counts: Dictionary = {}
var _finish_evidence_by_receipt: Dictionary = {}
var _static_combat_owner_count := 0
var _static_consumer_count := 0
var _static_director_count := 0
var _critical_map_occlusion_count := 0
var _target_anchor_parity_count := 0
var _private_leak_count := 0
var _final_window_count := 0
var _final_director_queue_count := -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_static_unique_composition()
	var original_size := root.size
	var original_scale_size := root.content_scale_size
	root.content_scale_size = TEST_VIEWPORT
	root.size = TEST_VIEWPORT
	await _settle_frames(3)

	var screen := SCREEN_SCENE.instantiate()
	_expect(screen != null, "production V075 GameScreen instantiates")
	if screen == null:
		_restore_viewport(original_size, original_scale_size)
		_finish()
		return
	root.add_child(screen)
	await _settle_frames(5)

	var flow := FixtureFlow.new()
	flow.name = "Phase5PresentationFixtureFlow"
	flow.set_meta("v075_isolated_preview_flow", true)
	flow.set_meta("fixture_class", FIXTURE_CLASS)
	root.add_child(flow)
	screen.call(
		"bind_application_flow",
		flow,
		{
			"ruleset_id": "v0.7.5",
			"viewer_player_id": "player.local",
			"fixture_class": FIXTURE_CLASS,
		},
		{
			"combat": {
				"private_skill_intent_kind": "combat.skill.request",
				"military_intent_kind": "combat.mission.select",
			},
		}
	)

	var projection := COMBAT_SURFACE_BENCH.make_projection("player.local")
	projection["phase"] = "batch_active"
	var projection_fingerprint_before := _canonical_json(projection).sha256_text()
	screen.call("apply_snapshot", {
		"ruleset_id": "v0.7.5",
		"phase": "batch_active",
		"match_started": false,
		"fixture_class": FIXTURE_CLASS,
		"combat_player_projection": projection.duplicate(true),
	})
	await _settle_frames(6)
	var screen_before := screen.call("combat_debug_snapshot") as Dictionary
	if bool(screen_before.get("overlay_collapsed", true)):
		screen.call("_toggle_combat_surface")
	await _settle_frames(5)

	var surface := screen.find_child("CombatSurface", true, false) as Control
	var director := screen.find_child(
		"V076PresentationAnimationDirector",
		true,
		false
	) as Node
	var map_view := screen.get_node_or_null(
		"RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/"
		+ "PlanetStageViewport/MapHost/PlanetMapView"
	) as Control
	var map_host := screen.get_node_or_null(
		"RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/"
		+ "PlanetStageViewport/MapHost"
	) as Control
	_expect(surface != null, "production Combat Surface is present")
	_expect(director != null, "unique production Animation Director is present")
	_expect(map_view != null and map_host != null, "production planet map is present")
	if surface == null or director == null or map_view == null or map_host == null:
		await _cleanup(screen, flow)
		_restore_viewport(original_size, original_scale_size)
		_finish()
		return
	_expect(
		surface.has_signal("combat_observatory_animation_finished")
			and surface.has_method("show_presentation_cue")
			and surface.has_method("select_combat_observatory_window")
			and surface.has_method("set_combat_observatory_window_expanded")
			and surface.has_method("set_combat_observatory_window_pinned")
			and surface.has_method("set_terminal_phase"),
		"production Surface exposes the one Observatory contract"
	)
	surface.connect(
		"combat_observatory_animation_finished",
		Callable(self, "_on_combat_observatory_animation_finished")
	)
	_expect(
		map_view.has_method("set_map"),
		"fixture uses the existing production map projection owner"
	)
	_install_fixture_map(map_view)
	await _settle_frames(5)

	for region_id in ["region.07", "region.10", "region.14"]:
		var anchor := map_view.call(
			"region_global_screen_anchor",
			region_id
		) as Dictionary
		_expect(
			str(anchor.get("region_id", "")) == region_id
				and anchor.get("global_position", null) is Vector2,
			"live map anchor resolves for %s" % region_id
		)

	var raw_receipts: Array[Dictionary] = [
		{
			"combat_receipt_id": "phase5.fixture.monster.move.001",
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
			"distance_milli_arc": 170,
			"public_summary": "公开怪兽移动已结算",
		},
		{
			"combat_receipt_id": "phase5.fixture.monster.trample.001",
			"event_kind": "monster_trample_resolved",
			"source_rank": 3,
			"region_id": "region.10",
			"distance_milli_arc": 88,
			"damage_amount": 5,
			"facility_type": "factory",
			"public_summary": "公开践踏已结算",
		},
		{
			"combat_receipt_id": "phase5.fixture.military.region.001",
			"event_kind": "military_region_assault",
			"military_tier": 2,
			"task_kind": "assault_region",
			"target_region_id": "region.14",
			"damage_amount": 7,
			"public_summary": "公开军队地区攻击已结算",
		},
	]
	var fixture_intent_count_before_receipts := flow.issued.size()
	var receipts: Array[Dictionary] = []
	var receipt_ids: Array[String] = []
	var apply_results: Array[Dictionary] = []
	for index in range(raw_receipts.size()):
		var receipt := _v2(raw_receipts[index], index)
		receipts.append(receipt)
		receipt_ids.append(str(receipt.get("presentation_receipt_id", "")))
		var result := screen.call(
			"apply_combat_receipt",
			receipt.duplicate(true)
		) as Dictionary
		apply_results.append(result)
		_expect(
			bool(result.get("applied", false)),
			"public fixture receipt %d enters the production presentation chain"
				% (index + 1)
		)

	var duplicate_result := screen.call(
		"apply_combat_receipt",
		receipts[0].duplicate(true)
	) as Dictionary
	_expect(
		str(duplicate_result.get("reason_code", ""))
			== "combat_presentation_receipt_duplicate",
		"Consumer suppresses a byte-equivalent receipt before a second window"
	)
	var collision_raw := raw_receipts[2].duplicate(true)
	collision_raw["damage_amount"] = 8
	var collision_receipt := _v2(collision_raw, 2)
	_expect(
		str(collision_receipt.get("presentation_receipt_id", ""))
			== receipt_ids[2],
		"collision probe preserves the bound public receipt identity"
	)
	var collision_result := screen.call(
		"apply_combat_receipt",
		collision_receipt
	) as Dictionary
	_expect(
		str(collision_result.get("reason_code", ""))
			== "combat_presentation_receipt_collision",
		"Consumer fails closed on a same-ID different-payload collision"
	)

	await _settle_frames(3)
	var active_debug := screen.call("combat_debug_snapshot") as Dictionary
	var active_surface := active_debug.get("surface", {}) as Dictionary
	var active_director := (
		active_debug.get("combat_animation_director", {}) as Dictionary
	)
	_expect(
		int(active_surface.get("concurrent_combat_view_count", 0))
			== REQUIRED_WINDOW_COUNT
			and int(active_surface.get("combat_window_pending_count", 0))
				== REQUIRED_WINDOW_COUNT,
		"three public receipts simultaneously own three pending stable windows"
	)
	_expect(
		int(active_director.get("queued_cue_count", 0))
			== REQUIRED_WINDOW_COUNT
			and int(active_debug.get(
				"combat_animation_active_receipt_count",
				0
			)) == REQUIRED_WINDOW_COUNT,
		"Director queue and Screen active ledger each contain exactly three receipts"
	)

	var expected_source_rects: Dictionary = {}
	var expected_target_rects: Dictionary = {}
	for queued_variant in active_director.get("queued_cues", []) as Array:
		var queued := queued_variant as Dictionary
		var queued_id := str(queued.get("receipt_id", ""))
		var queued_projection := queued.get("projection", {}) as Dictionary
		var source_rect := _anchor_rect(queued_projection.get("source_anchor", {}))
		var target_rect := _anchor_rect(queued_projection.get("target_anchor", {}))
		expected_source_rects[queued_id] = source_rect
		expected_target_rects[queued_id] = target_rect
		_expect(
			queued_id in receipt_ids
				and source_rect.has_area()
				and target_rect.has_area(),
			"Director projection keeps live source/target anchors for %s" % queued_id
		)
		_private_leak_count += _private_field_count(queued)

	var control_actions_green := (
		bool(surface.call(
			"select_combat_observatory_window",
			receipt_ids[0]
		))
		and bool(surface.call(
			"set_combat_observatory_window_expanded",
			receipt_ids[0],
			false
		))
		and bool(surface.call(
			"set_combat_observatory_window_expanded",
			receipt_ids[0],
			true
		))
		and bool(surface.call(
			"set_combat_observatory_window_pinned",
			receipt_ids[1],
			true
		))
		and bool(surface.call(
			"select_combat_observatory_window",
			receipt_ids[2]
		))
	)
	_expect(
		control_actions_green,
		"Observatory supports switch, collapse, expand, and pin controls"
	)
	await _settle_frames(4)
	var controlled_surface := surface.call("debug_snapshot") as Dictionary
	_expect(
		int(controlled_surface.get("combat_window_count", 0))
			== REQUIRED_WINDOW_COUNT
			and int(controlled_surface.get("combat_window_expanded_count", 0))
				== REQUIRED_WINDOW_COUNT
			and int(controlled_surface.get("combat_window_pinned_count", 0)) == 1
			and int(controlled_surface.get("combat_window_collapse_action_count", 0))
				>= 1
			and int(controlled_surface.get("combat_window_expand_action_count", 0))
				>= 1
			and int(controlled_surface.get("combat_window_pin_action_count", 0)) >= 1
			and int(controlled_surface.get("combat_window_switch_count", 0)) >= 2,
		"window control state remains explicit and stable"
	)
	var finish_deadline := Time.get_ticks_msec() + 4500
	while (
		_finish_signal_count < REQUIRED_WINDOW_COUNT
		and Time.get_ticks_msec() < finish_deadline
	):
		await process_frame
	_expect(
		_finish_signal_count == REQUIRED_WINDOW_COUNT,
		"three real Surface animation-finished signals arrive before timeout"
	)

	var finished_debug := screen.call("combat_debug_snapshot") as Dictionary
	var finished_surface := finished_debug.get("surface", {}) as Dictionary
	var finished_director := (
		finished_debug.get("combat_animation_director", {}) as Dictionary
	)
	var finished_window_rects := _window_rects_by_receipt(
		finished_surface.get("combat_windows", []) as Array
	)
	await _settle_frames(3)
	var settled_debug := screen.call("combat_debug_snapshot") as Dictionary
	var settled_surface := settled_debug.get("surface", {}) as Dictionary
	var settled_window_rects := _window_rects_by_receipt(
		settled_surface.get("combat_windows", []) as Array
	)
	_final_window_count = int(finished_surface.get("combat_window_count", 0))
	_final_director_queue_count = int(finished_director.get("queued_cue_count", -1))
	_expect(
		_final_window_count == REQUIRED_WINDOW_COUNT
			and int(finished_surface.get("combat_window_pending_count", -1)) == 0
			and int(finished_surface.get(
				"combat_window_animation_started_count",
				0
			)) == REQUIRED_WINDOW_COUNT
			and int(finished_surface.get(
				"combat_window_animation_finished_count",
				0
			)) == REQUIRED_WINDOW_COUNT
			and int(finished_surface.get("combat_window_finish_duplicate_count", -1))
				== 0,
		"each Observatory window starts and finishes exactly once"
	)
	_expect(
		int(finished_debug.get("combat_animation_envelope_count", 0))
			== REQUIRED_WINDOW_COUNT
			and int(finished_debug.get("combat_animation_director_queue_count", 0))
				== REQUIRED_WINDOW_COUNT
			and int(finished_debug.get("combat_animation_director_finish_count", 0))
				== REQUIRED_WINDOW_COUNT
			and int(finished_debug.get(
				"combat_animation_director_finish_missing_count",
				-1
			)) == 0
			and int(finished_debug.get("combat_animation_active_receipt_count", -1))
				== 0
			and _final_director_queue_count == 0
			and int(finished_director.get("finished_cue_count", 0))
				== REQUIRED_WINDOW_COUNT,
		"Screen ledger and unique Director drain all three receipts exactly once"
	)

	var presentation_debug := finished_debug.get("presentation", {}) as Dictionary
	_expect(
		int(presentation_debug.get("applied_receipt_count", 0))
			== REQUIRED_WINDOW_COUNT
			and int(presentation_debug.get("duplicate_receipt_count", 0)) == 1
			and int(presentation_debug.get("collision_receipt_count", 0)) == 1
			and int(finished_debug.get("combat_animation_surface_applied_count", 0))
				== REQUIRED_WINDOW_COUNT
			and int(finished_surface.get("combat_window_create_count", 0))
				== REQUIRED_WINDOW_COUNT,
		"duplicate and collision probes create no extra queue or window"
	)

	var final_windows := settled_surface.get("combat_windows", []) as Array
	var final_window_rects := _window_rects_by_receipt(final_windows)
	var map_rect := map_host.get_global_rect()
	for receipt_id in receipt_ids:
		var evidence := (
			_finish_evidence_by_receipt.get(receipt_id, {}) as Dictionary
		)
		var start_rect := evidence.get("start_rect", Rect2()) as Rect2
		var mid_rect := evidence.get("mid_rect", Rect2()) as Rect2
		var end_rect := evidence.get("end_rect", Rect2()) as Rect2
		var source_anchor_rect := (
			evidence.get("source_anchor_rect", Rect2()) as Rect2
		)
		var target_anchor_rect := (
			evidence.get("target_anchor_rect", Rect2()) as Rect2
		)
		var expected_source := (
			expected_source_rects.get(receipt_id, Rect2()) as Rect2
		)
		var expected_target := (
			expected_target_rects.get(receipt_id, Rect2()) as Rect2
		)
		var rect_sequence_green := (
			bool(evidence.get("rects_complete", false))
			and start_rect.has_area()
			and mid_rect.has_area()
			and end_rect.has_area()
			and not _rect_close(start_rect, mid_rect)
		)
		_expect(
			rect_sequence_green,
			"%s retains actual start/mid/end Rect evidence" % receipt_id
		)
		var anchor_parity := (
			_rect_close(source_anchor_rect, expected_source)
			and _rect_close(target_anchor_rect, expected_target)
			and str(evidence.get("source_anchor_origin", ""))
				== "director_projection.source_anchor"
			and str(evidence.get("target_anchor_origin", ""))
				== "director_projection.target_anchor"
		)
		if anchor_parity:
			_target_anchor_parity_count += 1
		_expect(
			anchor_parity,
			"%s animation endpoints preserve live map-anchor parity" % receipt_id
		)
		_private_leak_count += _private_field_count(evidence)
		_expect(
			int(_finish_signal_counts.get(receipt_id, 0)) == 1,
			"%s emits one and only one completion signal" % receipt_id
		)
		var stable_rect := finished_window_rects.get(receipt_id, Rect2()) as Rect2
		var final_rect := settled_window_rects.get(receipt_id, Rect2()) as Rect2
		_expect(
			stable_rect.has_area()
				and final_rect.has_area()
				and _rect_close(stable_rect, final_rect, 1.5),
			"%s window remains stable after its animation completes" % receipt_id
		)
		if final_rect.intersection(map_rect).has_area():
			_critical_map_occlusion_count += 1

	_expect(
		_target_anchor_parity_count == REQUIRED_WINDOW_COUNT
			and int(finished_surface.get("rect_evidence_count", 0))
				== REQUIRED_WINDOW_COUNT
			and int(finished_surface.get("source_anchor_evidence_count", 0))
				== REQUIRED_WINDOW_COUNT
			and int(finished_surface.get("target_anchor_evidence_count", 0))
				== REQUIRED_WINDOW_COUNT
			and int(finished_surface.get("missing_anchor_evidence_count", -1)) == 0,
		"all three completions have complete Rect and live-anchor evidence"
	)
	_expect(
		_critical_map_occlusion_count == 0
			and int(finished_debug.get(
				"combat_primary_planet_occlusion_count",
				-1
			)) == 0
			and int(finished_debug.get(
				"combat_planet_right_half_occlusion_count",
				-1
			)) == 0,
		"stable Observatory windows produce zero critical map occlusion"
	)
	_expect(
		_private_leak_count == 0
			and int(finished_debug.get("combat_animation_privacy_rejection_count", -1))
				== 0
			and int(finished_surface.get(
				"combat_window_privacy_violation_count",
				-1
			)) == 0,
		"Director projections and finish evidence contain zero private-field leaks"
	)

	var director_zero_delta := true
	for key in [
		"animation_gameplay_mutation_count",
		"animation_rng_draw_delta",
		"animation_authority_sequence_delta",
		"animation_deck_order_mutation_count",
		"animation_card_zone_mutation_count",
		"animation_facility_state_mutation_count",
	]:
		director_zero_delta = (
			director_zero_delta
			and int(finished_director.get(key, -1)) == 0
		)
	var surface_zero_delta := true
	for key in [
		"presentation_gameplay_mutation_count",
		"presentation_rng_draw_delta",
		"presentation_authority_sequence_delta",
		"presentation_deck_order_mutation_count",
		"presentation_card_zone_mutation_count",
		"presentation_facility_state_mutation_count",
	]:
		surface_zero_delta = (
			surface_zero_delta
			and int(finished_surface.get(key, -1)) == 0
		)
	_expect(
		director_zero_delta and surface_zero_delta,
		"presentation animation/director mutation counters remain zero"
	)
	_expect(
		flow.issued.size() == fixture_intent_count_before_receipts,
		"presentation receipts issue no additional gameplay intents"
	)
	_expect(
		_canonical_json(projection).sha256_text() == projection_fingerprint_before,
		"presentation does not mutate the supplied gameplay projection"
	)
	_expect(
		not bool(finished_director.get(
			"production_ui_instant_test_mode_reachable",
			true
		))
			and not bool(finished_surface.get(
				"combat_window_production_instant_mode_reachable",
				true
			)),
		"instant test mode remains unreachable from production UI"
	)

	var terminal_projection := projection.duplicate(true)
	terminal_projection["phase"] = "final_settlement"
	screen.call("apply_snapshot", {
		"ruleset_id": "v0.7.5",
		"phase": "final_settlement",
		"match_started": false,
		"fixture_class": FIXTURE_CLASS,
		"combat_player_projection": terminal_projection,
	})
	await _settle_frames(3)
	var post_terminal_receipt := _v2({
		"combat_receipt_id": "phase5.fixture.post.terminal.001",
		"event_kind": "monster_moved",
		"source_rank": 1,
		"movement_profile": "ground_trample",
		"start_region_id": "region.10",
		"destination_region_id": "region.07",
		"distance_milli_arc": 94,
		"public_summary": "终局后不得打开新窗口",
	}, 3)
	var post_terminal_result := screen.call(
		"apply_combat_receipt",
		post_terminal_receipt
	) as Dictionary
	await _settle_frames(3)
	var terminal_debug := screen.call("combat_debug_snapshot") as Dictionary
	var terminal_surface := terminal_debug.get("surface", {}) as Dictionary
	var terminal_director := (
		terminal_debug.get("combat_animation_director", {}) as Dictionary
	)
	_expect(
		str(post_terminal_result.get("reason_code", ""))
			== "post_settlement_combat_effect_rejected"
			and str(terminal_debug.get("terminal_phase", ""))
				== "final_settlement"
			and str(terminal_surface.get("combat_window_terminal_phase", ""))
				== "final_settlement"
			and int(terminal_surface.get("combat_window_create_count", 0))
				== REQUIRED_WINDOW_COUNT
			and int(terminal_debug.get("combat_animation_envelope_count", 0))
				== REQUIRED_WINDOW_COUNT
			and int(terminal_director.get("queued_cue_count", -1)) == 0,
		"terminal phase rejects a new combat window before Director enqueue"
	)

	await _cleanup(screen, flow)
	_restore_viewport(original_size, original_scale_size)
	_finish()


func _test_static_unique_composition() -> void:
	var main_source := _read_text(MAIN_SCENE_PATH)
	var composition_source := _read_text(RUNTIME_COMPOSITION_PATH)
	var screen_scene_source := _read_text(SCREEN_SCENE_PATH)
	var runtime_owner_source := _read_text(RUNTIME_OWNER_PATH)
	_static_combat_owner_count = _count_occurrences(
		composition_source,
		"[node name=\"V075CombatRuntimeOwner\""
	)
	_static_consumer_count = _count_occurrences(
		runtime_owner_source,
		"CombatPresentationConsumer.new()"
	)
	_static_director_count = _count_occurrences(
		screen_scene_source,
		"[node name=\"V076PresentationAnimationDirector\""
	)
	_expect(
		_count_occurrences(
			main_source,
			"[node name=\"V075RuntimeComposition\""
		) == 1
			and _count_occurrences(
				main_source,
				"[node name=\"V075GameScreen\""
			) == 1,
		"production main statically owns one runtime composition and one GameScreen"
	)
	_expect(
		_static_combat_owner_count == 1
			and _count_occurrences(
				composition_source,
				COMBAT_OWNER_SCRIPT_PATH
			) == 1,
		"static production composition has one Combat Owner"
	)
	_expect(
		_static_consumer_count == 1
			and _count_occurrences(runtime_owner_source, CONSUMER_SCRIPT_PATH) == 1,
		"static runtime Owner constructs one established Combat Consumer"
	)
	_expect(
		_static_director_count == 1
			and _count_occurrences(screen_scene_source, DIRECTOR_SCRIPT_PATH) == 1,
		"static GameScreen composition has one Animation Director"
	)
	_expect(
		_count_occurrences(screen_scene_source, "CombatObservatory") == 0
			and _count_occurrences(
				_read_text(
					"res://scenes/ui/v075/V075CombatPlayerSurface.tscn"
				),
				"[node name=\"CombatObservatory\""
			) == 1,
		"Observatory lives inside the one established Combat Surface, not beside it"
	)


func _v2(raw_receipt: Dictionary, sequence: int) -> Dictionary:
	var source_id := str(raw_receipt.get("combat_receipt_id", ""))
	return PRESENTATION_IDENTITY.build_public(
		source_id,
		PRESENTATION_IDENTITY.source_fingerprint(source_id, raw_receipt),
		sequence,
		str(raw_receipt.get("event_kind", "")),
		0,
		"v0.7.5",
		FIXTURE_SESSION_ID,
		raw_receipt
	)


func _on_combat_observatory_animation_finished(
	receipt_id: String,
	evidence: Dictionary
) -> void:
	_finish_signal_count += 1
	_finish_signal_counts[receipt_id] = int(
		_finish_signal_counts.get(receipt_id, 0)
	) + 1
	_finish_evidence_by_receipt[receipt_id] = evidence.duplicate(true)


func _install_fixture_map(map_view: Control) -> void:
	var centers := {
		"region.07": Vector2(280.0, 300.0),
		"region.10": Vector2(510.0, 430.0),
		"region.14": Vector2(740.0, 470.0),
	}
	var districts: Array = []
	for region_id_variant in centers.keys():
		var region_id := str(region_id_variant)
		var center := centers.get(region_id) as Vector2
		districts.append({
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
	var palette: Array = [
		Color("#27485f"),
		Color("#31556b"),
		Color("#3b6177"),
	]
	map_view.call(
		"set_map",
		districts,
		1000.0,
		700.0,
		-1,
		palette,
		[],
		[],
		[],
		[],
		[],
		[],
		"",
		"all"
	)


func _window_rects_by_receipt(rows: Array) -> Dictionary:
	var result := {}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var receipt_id := str(row.get("receipt_id", ""))
		var window_rect := row.get("window_rect", Rect2()) as Rect2
		if not receipt_id.is_empty():
			result[receipt_id] = window_rect
	return result


func _anchor_rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value as Rect2
	if value is Vector2:
		return Rect2((value as Vector2) - Vector2(4.0, 4.0), Vector2(8.0, 8.0))
	if value is Dictionary:
		var source := value as Dictionary
		for field_name in ["global_rect", "rect", "control_rect"]:
			var rect_value: Variant = source.get(field_name, null)
			if rect_value is Rect2:
				return rect_value as Rect2
		var position_value: Variant = source.get(
			"global_position",
			source.get("position", null)
		)
		var size_value: Variant = source.get("size", Vector2(8.0, 8.0))
		if position_value is Vector2 and size_value is Vector2:
			return Rect2(position_value as Vector2, size_value as Vector2)
	return Rect2()


func _rect_close(
	left: Rect2,
	right: Rect2,
	epsilon: float = RECT_EPSILON
) -> bool:
	return (
		left.has_area()
		and right.has_area()
		and left.position.distance_to(right.position) <= epsilon
		and left.size.distance_to(right.size) <= epsilon
	)


func _private_field_count(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var normalized := str(key_variant).to_lower()
			for fragment_variant in PRIVATE_FIELD_FRAGMENTS:
				if str(fragment_variant) in normalized:
					count += 1
					break
			count += _private_field_count(dictionary.get(key_variant))
	elif value is Array:
		for child_variant in value as Array:
			count += _private_field_count(child_variant)
	return count


func _canonical_json(value: Variant) -> String:
	return JSON.stringify(_canonical_value(value))


func _canonical_value(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key_variant in source.keys():
			keys.append(str(key_variant))
		keys.sort()
		var result := {}
		for key in keys:
			result[key] = _canonical_value(source.get(key))
		return result
	if value is Array:
		var result: Array = []
		for item in value as Array:
			result.append(_canonical_value(item))
		return result
	return value


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _count_occurrences(source: String, needle: String) -> int:
	if needle.is_empty():
		return 0
	var count := 0
	var cursor := 0
	while cursor < source.length():
		var index := source.find(needle, cursor)
		if index < 0:
			break
		count += 1
		cursor = index + needle.length()
	return count


func _settle_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _cleanup(screen: Node, flow: Node) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	if is_instance_valid(flow):
		flow.queue_free()
	await _settle_frames(4)


func _restore_viewport(
	original_size: Vector2i,
	original_scale_size: Vector2i
) -> void:
	root.content_scale_size = original_scale_size
	root.size = original_size


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("V076 PHASE5 COMBAT OBSERVATORY GATE: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	var marker := (
		"V076_PHASE5_COMBAT_OBSERVATORY_GATE"
		+ "|status=%s|fixture_class=%s|passed=%d|total=%d"
		+ "|static_combat_owner_count=%d|static_consumer_count=%d"
		+ "|static_director_count=%d|concurrent_window_count=%d"
		+ "|finish_signal_count=%d|director_queue_after=%d"
		+ "|target_anchor_parity_count=%d|critical_map_occlusion_count=%d"
		+ "|private_leak_count=%d|human_green=false|production_green=false"
		+ "|details=%s"
	)
	print(marker % [
		status,
		FIXTURE_CLASS,
		_checks - _failures.size(),
		_checks,
		_static_combat_owner_count,
		_static_consumer_count,
		_static_director_count,
		_final_window_count,
		_finish_signal_count,
		_final_director_queue_count,
		_target_anchor_parity_count,
		_critical_map_occlusion_count,
		_private_leak_count,
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
