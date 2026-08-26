extends SceneTree

## Focused Phase 6 presentation gate.
##
## FIXTURE_CLASS=PRESENTATION_FIXTURE
## This sealed fixture exercises the production facility map bridge and the
## existing track receipt bridge. It is not a gameplay authoring test and it
## does not mutate production authority state directly.

const FIXTURE_CLASS := "PRESENTATION_FIXTURE"
const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_VIEWPORT := Vector2i(1600, 960)
const FIXED_SEED := 900626424
const LOCAL_PLAYER_ID := "player.local"
const RECT_EPSILON := 0.75
const PRIVATE_FIELD_FRAGMENTS := [
	"secret",
	"private",
	"hidden",
	"rng_state",
	"owner_player_id",
	"source_instance_id",
	"card_instance_id",
	"request_revision",
	"authorization",
]

var _application: Node
var _screen: Control
var _flow: Node
var _runtime: Node
var _map_view: Control
var _track_rail: Control
var _director: Node
var _checks := 0
var _failures: Array[String] = []
var _track_receipts: Array[Dictionary] = []
var _facility_receipts: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = TEST_VIEWPORT
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main scene loads")
	if packed == null:
		await _finish()
		return

	_application = packed.instantiate()
	root.add_child(_application)
	await _frames(12)

	_screen = _application.get_node_or_null("V075GameScreen") as Control
	_flow = _application.get_node_or_null("V075RuntimeComposition") as Node
	_expect(_screen != null, "production V075 GameScreen is composed")
	_expect(_flow != null, "production V075 runtime composition is composed")
	if _screen == null or _flow == null:
		await _finish()
		return
	_director = _screen.get_node_or_null("V076PresentationAnimationDirector") as Node
	_expect(_director != null, "production presentation director is composed")
	if _director == null:
		await _finish()
		return

	_runtime = _flow.get("_runtime_owner") as Node
	_expect(_runtime != null, "facility and track bridge reuses the existing RuntimeOwner")
	if _runtime == null:
		await _finish()
		return
	_expect(_flow.has_signal("track_presentation_receipt_ready"), "runtime owner exposes the track receipt bridge")
	_expect(_flow.has_signal("public_resolution_ready"), "runtime owner still exposes the public presentation bridge")
	if _flow.has_signal("track_presentation_receipt_ready"):
		_flow.track_presentation_receipt_ready.connect(_on_track_presentation_receipt_ready)

	_map_view = _screen.find_child("PlanetMapView", true, false) as Control
	_track_rail = _screen.find_child("TrackRail", true, false) as Control
	_expect(_map_view != null, "production PlanetMapView is present")
	_expect(_track_rail != null, "production TrackRail is present")
	if _map_view == null or _track_rail == null:
		await _finish()
		return

	var map_static: Dictionary = {}
	if _map_view.has_method("v074_planet_debug_snapshot"):
		map_static = _map_view.call("v074_planet_debug_snapshot") as Dictionary
	_expect(bool(map_static.get("authoritative_surface_connected", false)) or not map_static.is_empty(), "live map exposes a typed debug snapshot")
	_expect(_map_view.has_method("request_facility_commit_presentation"), "map exposes the facility commit bridge")
	_expect(_map_view.has_signal("facility_presentation_finished"), "map exposes the facility completion signal")
	_expect(_director.has_method("enqueue_receipt") and _director.has_method("finish_receipt"), "director exposes receipt queue/finish APIs")

	_configure_new_game()
	var start_button: Button = _screen.find_child("StartConfiguredButton", true, false) as Button
	_expect(start_button != null, "production start control exists")
	if start_button == null:
		await _finish()
		return

	start_button.pressed.emit()
	_expect(await _wait_for_match_start(12.0), "normal UI starts a real session")
	await _dismiss_coach()
	await _frames(60)
	_expect(await _wait_for_submission(30.0), "production flow reaches submission")

	var snapshot_before: Dictionary = _flow.call("local_snapshot") as Dictionary
	var runtime_before: Dictionary = _runtime.call("debug_snapshot") as Dictionary
	var facility_option: Dictionary = _first_legal_facility_option(snapshot_before)
	var facility_card_id := str(facility_option.get("card_instance_id", ""))
	var facility_type := str(facility_option.get("facility_type", ""))
	_expect(not facility_card_id.is_empty(), "a live facility card is available")
	_expect(["factory", "market", "warehouse"].has(facility_type), "facility type is catalog-owned")
	if facility_card_id.is_empty():
		await _finish()
		return

	var hand_card := _find_visible_hand_card(facility_card_id)
	_expect(hand_card != null, "authoritative facility card has a visible hand control")
	if hand_card == null:
		await _finish()
		return
	await _click(hand_card)
	await _frames(8)
	_expect(str(_screen.get("_selected_card_id")) == facility_card_id, "selected facility card preserves its authority id")
	_expect(
		await _click_first_legal_target(),
		"real map target accepts the selected facility card"
	)
	await _frames(2)
	var binding: Dictionary = _screen.get("_pending_confirm_binding") as Dictionary
	var target_region := str(binding.get("target_region_id", ""))
	_expect(not target_region.is_empty(), "target selection produces an authoritative region binding")
	_expect(str(binding.get("card_instance_id", "")) == facility_card_id, "target binding preserves the facility card identity")
	var confirm: Button = _screen.find_child("CurrentActionConfirmButton", true, false) as Button
	_expect(confirm != null and not confirm.disabled, "fixed action tray exposes an enabled confirm")
	if confirm == null or confirm.disabled:
		await _finish()
		return

	await _click(confirm)
	await _frames(4)
	var queued_snapshot := _flow.call("local_snapshot") as Dictionary
	_expect(
		str(queued_snapshot.get("phase", "")) == "submission",
		"facility queue acceptance remains in submission"
	)
	_expect(
		(queued_snapshot.get("queued_actions", []) as Array).size() >= 1,
		"facility confirmation creates a pending authoritative action"
	)
	# Only accelerate after the real pointer path has placed the action into the
	# authority queue.  This preserves the natural 30-second submission boundary.
	var pace_result: Dictionary = _flow.submit_intent(
		_flow.issue_intent("ui.pacing.set", {"multiplier": 4})
	) as Dictionary
	_expect(bool(pace_result.get("accepted", false)), "4x pace intent is accepted for facility resolution")
	var facility_committed := await _wait_for_facility_commit(
		target_region,
		facility_type,
		90.0
	)
	_expect(facility_committed, "facility commit reaches the live map bridge")
	await _frames(12)

	var after_build_map_debug := _map_debug_snapshot()
	var after_build_facility_debug := _target_facility_debug(
		after_build_map_debug,
		target_region,
		facility_type,
		""
	)
	var committed_facility_id := str(after_build_facility_debug.get(
		"facility_id",
		""
	))
	var after_build_marker_debug := _target_marker_debug(
		after_build_map_debug,
		target_region,
		facility_type,
		committed_facility_id
	)
	var after_build_screen_debug := _screen.call("combat_debug_snapshot") as Dictionary
	var after_build_runtime_debug := _runtime.call("debug_snapshot") as Dictionary
	var after_build_timing := _runtime.call("v076_track_advance_timing_snapshot") as Dictionary
	_expect(int(after_build_map_debug.get("facility_presentation_request_count", 0)) >= 1, "map records at least one facility presentation request")
	_expect(int(after_build_map_debug.get("facility_presentation_accepted_count", 0)) >= 1, "map accepts the facility presentation request")
	_expect(int(after_build_map_debug.get("facility_presentation_started_count", 0)) >= 1, "map starts the facility presentation request")
	_expect(int(after_build_map_debug.get("facility_presentation_finished_count", 0)) >= 1, "map finishes the facility presentation request")
	_expect(int(after_build_map_debug.get("facility_presentation_duplicate_count", 0)) == 0, "first facility receipt is not duplicated")
	_expect(int(after_build_map_debug.get("facility_presentation_collision_count", 0)) == 0, "first facility receipt does not collide")
	_expect(int(after_build_map_debug.get("facility_presentation_rejection_count", 0)) == 0, "first facility receipt is not rejected")
	_expect(int(after_build_map_debug.get("facility_presentation_pending_count", 0)) == 0, "facility presentation queue drains")
	_expect(int(after_build_map_debug.get("facility_presentation_active_count", 0)) == 0, "facility presentation ends cleanly")
	_expect(int(after_build_map_debug.get("facility_presentation_finished_registry_count", 0)) >= 1, "facility presentation registers a finished receipt")
	_expect(int(after_build_map_debug.get("facility_presentation_cue_counts", {}).get("FACILITY_BUILD", 0)) >= 1, "build cue count increments")
	_expect(int(after_build_screen_debug.get("facility_animation", {}).get("map_extended_request_count", 0)) >= 1, "screen forwards the build cue to the live map bridge")
	_expect(int(after_build_screen_debug.get("facility_animation", {}).get("director_queue_count", 0)) >= 1, "screen queues the build cue exactly once")
	_expect(int(after_build_screen_debug.get("facility_animation", {}).get("director_queue_count", 0)) == int(after_build_screen_debug.get("facility_animation", {}).get("director_finish_count", 0)), "screen facility director finishes every queued cue")
	_expect(int(after_build_screen_debug.get("facility_animation", {}).get("map_finish_signal_count", 0)) >= 1, "screen observes the facility completion signal")
	_expect(int(after_build_screen_debug.get("facility_animation", {}).get("map_rejection_count", 0)) == 0, "facility map bridge records no rejection")
	_expect(int(after_build_screen_debug.get("facility_animation", {}).get("expiry_fallback_finish_count", 0)) == 0, "facility animation does not use the expiry fallback")
	_expect(int(after_build_screen_debug.get("facility_animation", {}).get("active_receipt_count", 0)) == 0, "facility director has no active receipt after finish")
	_expect(int(after_build_screen_debug.get("facility_animation", {}).get("anchor_projection_count", 0)) >= 1, "facility bridge projects a live source and target rect")
	_expect(int(after_build_screen_debug.get("facility_animation", {}).get("anchor_missing_count", 0)) == 0, "facility bridge does not fall back to missing anchors")
	_expect(str(after_build_screen_debug.get("facility_animation", {}).get("last_rejection_reason", "")) == "none", "facility bridge has no rejection reason after build")
	_expect(int(after_build_screen_debug.get("track_animation", {}).get("authority_receipt_count", 0)) == int(after_build_runtime_debug.get("v076_track_presentation_receipt_count", 0)), "screen track authority count mirrors the runtime bridge")
	_expect(int(after_build_timing.get("presentation_receipt_count", 0)) == int(after_build_runtime_debug.get("v076_track_presentation_receipt_count", 0)), "runtime track timing snapshot counts the same authority receipt")
	_expect(_track_receipts.is_empty(), "facility-only build does not invent a track receipt")
	_expect(_private_field_count(after_build_map_debug.get("facility_presentation_evidence", [])) == 0, "map facility evidence leaks no private fields")
	_expect(_private_field_count(after_build_marker_debug) == 0, "facility marker snapshot leaks no private fields")

	var after_build_facility_evidence := _target_facility_evidence(
		after_build_map_debug,
		target_region,
		facility_type,
		""
	)
	if after_build_facility_evidence.is_empty():
		_failures.append("committed facility evidence is present in the map snapshot")
	else:
		_expect(bool(after_build_facility_evidence.get("presentation_only", false)), "facility evidence stays presentation-only")
		_expect(bool(after_build_facility_evidence.get("public_only", false)), "facility evidence stays public-only")
		_expect(bool(after_build_facility_evidence.get("destination_authority_parity", false)), "facility evidence preserves destination parity")
		_expect(bool((after_build_facility_evidence.get("start_rect", Rect2()) as Rect2).has_area()), "facility evidence records a start rect")
		_expect(bool((after_build_facility_evidence.get("mid_rect", Rect2()) as Rect2).has_area()), "facility evidence records a mid rect")
		_expect(bool((after_build_facility_evidence.get("end_rect", Rect2()) as Rect2).has_area()), "facility evidence records an end rect")
		_expect(int(after_build_facility_evidence.get("gameplay_mutation_count", 0)) == 0, "facility evidence keeps gameplay mutation at zero")
		_expect(int(after_build_facility_evidence.get("rng_draw_delta", 0)) == 0, "facility evidence keeps RNG mutation at zero")
		_expect(int(after_build_facility_evidence.get("authority_sequence_delta", 0)) == 0, "facility evidence keeps authority sequence mutation at zero")
		_expect(int(after_build_facility_evidence.get("facility_state_mutation_count", 0)) == 0, "facility evidence keeps facility state mutation at zero")

	if after_build_facility_debug.is_empty():
		_failures.append("committed facility marker is present in the sceneized snapshot")
	else:
		_expect(_facility_visual_green(after_build_facility_debug), "committed facility marker is visually distinct and human visible")
		_expect(str(after_build_facility_debug.get("lifecycle_state", "")) == "PRESENTED", "committed facility marker settles to PRESENTED")
		_expect(int(after_build_facility_debug.get("commit_animation_count", 0)) >= 1, "committed facility marker receives a presentation animation")
		_expect(bool(after_build_facility_debug.get("human_visible", false)), "committed facility marker remains human visible")
		_expect(bool(after_build_facility_debug.get("inside_viewport", false)), "committed facility marker stays inside the viewport")
		_expect(not bool(after_build_facility_debug.get("primary_visual_letter_only", true)), "facility silhouette is not letter-only")
		_expect(bool(after_build_facility_debug.get("primary_visual_silhouette", false)), "facility silhouette is the primary visual")
		_expect(not bool(after_build_facility_debug.get("clip_contents", true)), "facility marker root does not clip the silhouette")
		_expect(str(after_build_facility_debug.get("visual_model_kind", "")) in [
			"industrial_factory_silhouette",
			"market_canopy_counter_silhouette",
			"warehouse_crate_bay_silhouette",
		], "facility marker exposes the typed silhouette model")

		var build_receipt_id := "phase6.fixture.facility.build.001"
		_facility_receipts.append(build_receipt_id)
		var direct_build_request: Dictionary = _map_view.request_facility_commit_presentation(
			str(after_build_marker_debug.get("facility_id", facility_card_id)),
			str(after_build_marker_debug.get("slot_id", "")),
			str(after_build_marker_debug.get("facility_type", facility_type)),
			"BUILD_NEW",
			build_receipt_id,
			target_region
		) as Dictionary
		_expect(bool(direct_build_request.get("accepted", false)), "typed BUILD_NEW request is accepted by the live map bridge")

		var duplicate_build := _map_view.request_facility_commit_presentation(
			str(after_build_marker_debug.get("facility_id", facility_card_id)),
			str(after_build_marker_debug.get("slot_id", "")),
			str(after_build_marker_debug.get("facility_type", facility_type)),
			"BUILD_NEW",
			build_receipt_id,
			target_region
		) as Dictionary
		_expect(not bool(duplicate_build.get("accepted", true)) and str(duplicate_build.get("reason_code", "")) == "facility_presentation_duplicate", "duplicate BUILD_NEW request fails closed as an exact-once replay")

		var collision_build := _map_view.request_facility_commit_presentation(
			str(after_build_marker_debug.get("facility_id", facility_card_id)),
			str(after_build_marker_debug.get("slot_id", "")),
			str(after_build_marker_debug.get("facility_type", facility_type)),
			"UPGRADE_OWN",
			build_receipt_id,
			target_region
		) as Dictionary
		_expect(not bool(collision_build.get("accepted", true)) and str(collision_build.get("reason_code", "")) == "facility_presentation_identity_collision", "same BUILD receipt id with a different mode fails closed as a collision")

		var upgrade_receipt_id := "phase6.fixture.facility.upgrade.001"
		_facility_receipts.append(upgrade_receipt_id)
		var upgrade_request: Dictionary = _map_view.request_facility_commit_presentation(
			str(after_build_marker_debug.get("facility_id", facility_card_id)),
			str(after_build_marker_debug.get("slot_id", "")),
			str(after_build_marker_debug.get("facility_type", facility_type)),
			"UPGRADE_OWN",
			upgrade_receipt_id,
			target_region
		) as Dictionary
		_expect(bool(upgrade_request.get("accepted", false)), "typed UPGRADE_OWN request is accepted by the live map bridge")

		var repair_receipt_id := "phase6.fixture.facility.repair.001"
		_facility_receipts.append(repair_receipt_id)
		var repair_request: Dictionary = _map_view.request_facility_commit_presentation(
			str(after_build_marker_debug.get("facility_id", facility_card_id)),
			str(after_build_marker_debug.get("slot_id", "")),
			str(after_build_marker_debug.get("facility_type", facility_type)),
			"REPAIR_OWN",
			repair_receipt_id,
			target_region
		) as Dictionary
		_expect(bool(repair_request.get("accepted", false)), "typed REPAIR_OWN request is accepted by the live map bridge")

		_expect(
			await _wait_for_facility_receipts(_facility_receipts, 30.0),
			"typed map replay finishes the exact BUILD/UPGRADE/REPAIR receipts"
		)

		var after_repair_map_debug := _map_debug_snapshot()
		var after_repair_facility_debug := _target_facility_debug(after_repair_map_debug, target_region, facility_type, facility_card_id)
		var after_repair_marker_debug := _target_marker_debug(after_repair_map_debug, target_region, facility_type, facility_card_id)
		var after_repair_screen_debug := _screen.call("combat_debug_snapshot") as Dictionary
		_expect(int(after_repair_map_debug.get("facility_presentation_finished_count", 0)) >= 4, "four facility cues finish exactly once each")
		_expect(int(after_repair_map_debug.get("facility_presentation_duplicate_count", 0)) >= 1, "duplicate facility replay is recorded")
		_expect(int(after_repair_map_debug.get("facility_presentation_collision_count", 0)) >= 1, "collision facility replay is recorded")
		_expect(int(after_repair_map_debug.get("facility_presentation_pending_count", 0)) == 0, "facility presentation queue remains drained after replay")
		_expect(int(after_repair_map_debug.get("facility_presentation_active_count", 0)) == 0, "facility presentation has no active receipt after replay")
		_expect(int(after_repair_map_debug.get("facility_presentation_cue_counts", {}).get("FACILITY_BUILD", 0)) >= 1, "build cue count stays visible after replay")
		_expect(int(after_repair_map_debug.get("facility_presentation_cue_counts", {}).get("FACILITY_UPGRADE", 0)) >= 1, "upgrade cue count is recorded")
		_expect(int(after_repair_map_debug.get("facility_presentation_cue_counts", {}).get("FACILITY_REPAIR", 0)) >= 1, "repair cue count is recorded")
		_expect(_private_field_count(after_repair_map_debug.get("facility_presentation_evidence", [])) == 0, "replayed map facility evidence leaks no private fields")
		_expect(_private_field_count(after_repair_marker_debug) == 0, "replayed facility marker snapshot leaks no private fields")
		if not after_repair_facility_debug.is_empty():
			_expect(_facility_visual_green(after_repair_facility_debug), "replayed facility marker remains visually distinct")
			_expect(str(after_repair_facility_debug.get("lifecycle_state", "")) == "PRESENTED", "replayed facility marker settles to PRESENTED")
			_expect(bool(after_repair_facility_debug.get("human_visible", false)), "replayed facility marker remains human visible")
			_expect(bool(after_repair_facility_debug.get("inside_viewport", false)), "replayed facility marker stays inside the viewport")
			_expect(not bool(after_repair_facility_debug.get("primary_visual_letter_only", true)), "replayed facility marker remains silhouette-first")
			_expect(bool(after_repair_facility_debug.get("primary_visual_silhouette", false)), "replayed facility marker keeps its silhouette")
			_expect(not bool(after_repair_facility_debug.get("clip_contents", true)), "replayed facility marker root does not clip")
	var track_receipt_count_before := int(after_build_runtime_debug.get("v076_track_presentation_receipt_count", 0))
	var track_rail_settled := false
	_expect(await _wait_for_phase("maintenance", 90.0), "production flow reaches maintenance")
	var finish_maintenance_button: Button = _screen.find_child("FinishMaintenanceButton", true, false) as Button
	_expect(finish_maintenance_button != null, "production finish maintenance control exists")
	if finish_maintenance_button != null:
		finish_maintenance_button.pressed.emit()
	track_rail_settled = await _wait_for_track_advance(track_receipt_count_before + 1, 90.0)
	_expect(track_rail_settled, "maintenance finish publishes a track receipt")
	await _frames(30)
	if _track_rail != null:
		var rail_settled := false
		for _frame in range(180):
			if is_zero_approx(_track_rail.position.x):
				rail_settled = true
				break
			await process_frame
		_expect(rail_settled, "track rail settles at the authoritative origin")
	var after_track_runtime_debug := _runtime.call("debug_snapshot") as Dictionary
	var after_track_timing := _runtime.call("v076_track_advance_timing_snapshot") as Dictionary
	var after_track_screen_debug := _screen.call("combat_debug_snapshot") as Dictionary
	var after_track_animation := after_track_screen_debug.get("track_animation", {}) as Dictionary
	var track_finish_evidence := after_track_animation.get("last_finish_evidence", {}) as Dictionary
	_expect(int(after_track_runtime_debug.get("v076_track_presentation_receipt_count", 0)) >= 1, "runtime owner publishes a track presentation receipt")
	_expect(str(after_track_runtime_debug.get("v076_last_track_presentation_receipt_id", "")) != "", "runtime owner keeps the last track receipt id")
	_expect(int(after_track_runtime_debug.get("track_immediate_authoritative_refill_count", 0)) == 0, "runtime track immediate refill remains zero")
	_expect(int(after_track_runtime_debug.get("track_supply_rng_draw_delta_on_acquisition", 0)) == 0, "runtime track purchase RNG delta remains zero")
	_expect(int(after_track_timing.get("presentation_receipt_count", 0)) == int(after_track_runtime_debug.get("v076_track_presentation_receipt_count", 0)), "runtime track timing snapshot counts the same authority receipt")
	_expect(int(after_track_animation.get("authority_receipt_count", 0)) == int(after_track_runtime_debug.get("v076_track_presentation_receipt_count", 0)), "screen track authority count mirrors the runtime bridge")
	_expect(int(after_track_animation.get("director_queue_count", 0)) >= 1, "screen queues the track presentation cue")
	_expect(int(after_track_animation.get("director_queue_count", 0)) == int(after_track_animation.get("director_finish_count", 0)), "screen track director finishes every queued cue")
	_expect(int(after_track_animation.get("active_receipt_count", 0)) == 0, "screen track director has no active receipt after finish")
	_expect(int(after_track_animation.get("anchor_projection_count", 0)) >= 1, "track bridge projects live source and target rects")
	_expect(int(after_track_animation.get("anchor_missing_count", 0)) == 0, "track bridge never loses its anchor projection")
	_expect(str(after_track_animation.get("last_rejection_reason", "")) == "none", "track bridge has no rejection reason after maintenance finish")
	_expect(float(track_finish_evidence.get("track_vacancy_visual_displacement_min_slot_ratio", 0.0)) >= 0.75, "track finish evidence keeps the vacancy/card ratio at or above 0.75")
	_expect(bool(track_finish_evidence.get("track_visual_end_rect_authority_parity", false)), "track finish evidence preserves end rect parity")
	_expect(int(track_finish_evidence.get("track_visual_return_to_old_phase_count", 0)) == 0, "track finish evidence has no visual return to the old phase")
	_expect(int(track_finish_evidence.get("track_oscillation_only_count", 0)) == 0, "track finish evidence has no oscillation-only pass")
	_expect(int(track_finish_evidence.get("track_immediate_authoritative_refill_count", 0)) == 0, "track finish evidence keeps immediate refill at zero")
	_expect(int(track_finish_evidence.get("track_supply_rng_draw_delta_on_acquisition", 0)) == 0, "track finish evidence keeps purchase RNG delta at zero")
	_expect(_track_receipts.size() >= 1, "track presentation signal is captured by the screen bridge")
	_expect(_private_field_count(_track_receipts) == 0, "track presentation signal leaks no private fields")
	_expect(_private_field_count(after_track_animation.get("last_envelope", {})) == 0, "track envelope leaks no private fields")

	var terminal_snapshot := snapshot_before.duplicate(true)
	terminal_snapshot["phase"] = "final_settlement"
	terminal_snapshot["match_started"] = false
	if _screen.has_method("apply_snapshot"):
		_screen.call("apply_snapshot", terminal_snapshot)
		await _frames(4)
	var terminal_rejection_before := int(
		after_track_animation.get("director_rejection_count", 0)
	)
	if not _track_receipts.is_empty():
		# Negative fixture: replay the immutable public authority receipt after the
		# terminal snapshot.  The production handler must reject it before it can
		# become a new Director cue.
		_screen.call(
			"_on_track_presentation_receipt_ready",
			(_track_receipts[-1] as Dictionary).duplicate(true)
		)
		await _frames(2)
	var terminal_debug := _screen.call("combat_debug_snapshot") as Dictionary
	var terminal_track_debug := _runtime.call("v076_track_advance_timing_snapshot") as Dictionary
	var terminal_track_animation := terminal_debug.get("track_animation", {}) as Dictionary
	_expect(str(terminal_debug.get("terminal_phase", "")) == "final_settlement", "terminal phase is recorded on the production screen")
	_expect(int(terminal_track_debug.get("presentation_receipt_count", 0)) >= 1, "terminal phase keeps the earlier track receipt visible")
	_expect(int(terminal_track_animation.get("authority_receipt_count", 0)) == int(after_track_animation.get("authority_receipt_count", 0)), "terminal fake receipt does not create a new track queue")
	_expect(int(terminal_track_animation.get("director_queue_count", 0)) == int(after_track_animation.get("director_queue_count", 0)), "terminal fake receipt does not queue a new track cue")
	_expect(int(terminal_track_animation.get("active_receipt_count", 0)) == 0, "terminal fake receipt leaves no active track cue")
	_expect(int(terminal_track_animation.get("director_rejection_count", 0)) == terminal_rejection_before + 1, "terminal fake receipt records one presentation rejection")
	_expect(str(terminal_track_animation.get("last_rejection_reason", "")) == "track_animation_terminal_quiescent", "terminal fake receipt is rejected by the quiescence guard")
	_expect(not bool(terminal_debug.get("production_ui_instant_test_mode_reachable", false)), "production UI instant test mode remains unreachable")
	_expect(not bool(terminal_debug.get("combat_window_production_instant_mode_reachable", false)), "production combat instant mode remains unreachable")

	_cleanup()
	await _finish()


func _configure_new_game() -> void:
	var player_option: OptionButton = _screen.find_child("PlayerCountOption", true, false) as OptionButton
	var seed_input: LineEdit = _screen.find_child("SeedInput", true, false) as LineEdit
	if player_option != null:
		for index in range(player_option.item_count):
			if int(player_option.get_item_metadata(index)) == 4:
				player_option.select(index)
				break
	if seed_input != null:
		seed_input.text = str(FIXED_SEED)


func _wait_for_match_start(seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var snapshot: Dictionary = _flow.call("local_snapshot") as Dictionary
		if bool(snapshot.get("match_started", false)):
			return true
		await process_frame
	return false


func _wait_for_submission(seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var snapshot: Dictionary = _flow.call("local_snapshot") as Dictionary
		if str(snapshot.get("phase", "")) == "submission":
			return true
		await process_frame
	return false


func _dismiss_coach() -> void:
	var coach: Node = _screen.get_node_or_null("V073PlaytestCoachMarks") as Node
	if coach == null or not coach.has_method("debug_snapshot"):
		return
	var skip: Button = coach.find_child("CoachSkipAll", true, false) as Button
	if (
		skip != null
		and bool((coach.call("debug_snapshot") as Dictionary).get(
			"active",
			false
		))
	):
		skip.pressed.emit()
		await _frames(4)


func _first_legal_facility_option(snapshot: Dictionary) -> Dictionary:
	for option_variant: Variant in snapshot.get("legal_actions", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option: Dictionary = option_variant as Dictionary
		var card_id := str(option.get("card_instance_id", ""))
		var facility_type := str(option.get("facility_type", ""))
		if not card_id.is_empty() and ["factory", "market", "warehouse"].has(facility_type):
			return option.duplicate(true)
	return {}


func _find_visible_hand_card(card_id: String) -> Control:
	var hand_rail: HBoxContainer = _screen.find_child("HandRail", true, false) as HBoxContainer
	if hand_rail == null:
		return null
	for child_variant: Variant in hand_rail.get_children():
		var card: Control = child_variant as Control
		if card == null or not card.visible or not card.has_method("payload"):
			continue
		var payload: Dictionary = card.call("payload") as Dictionary
		if str(payload.get("instance_id", payload.get("card_instance_id", ""))) == card_id:
			return card
	return null


func _click_first_legal_target() -> bool:
	var target_rail: HBoxContainer = _screen.find_child("TargetRail", true, false) as HBoxContainer
	if target_rail != null:
		for child_variant: Variant in target_rail.get_children():
			var button: Button = child_variant as Button
			if button != null and button.visible and not button.disabled:
				await _click(button)
				await _frames(2)
				if not (_screen.get("_pending_confirm_binding") as Dictionary).is_empty():
					return true
	var board: Node = _screen.find_child("PlanetBoard", true, false) as Node
	var map: Control = board.call("get_embedded_map_view") as Control if board != null and board.has_method("get_embedded_map_view") else null
	if map == null or not map.has_method("get_district_control_position"):
		return false
	for index in range(24):
		var local_position: Vector2 = map.call("get_district_control_position", index) as Vector2
		if local_position.x < 0.0 or local_position.y < 0.0:
			continue
		var point: Vector2 = map.global_position + local_position
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		Input.parse_input_event(motion)
		await process_frame
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = point
		down.global_position = point
		Input.parse_input_event(down)
		await process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = point
		up.global_position = point
		Input.parse_input_event(up)
		await process_frame
		if not (_screen.get("_pending_confirm_binding") as Dictionary).is_empty():
			return true
	return false


func _wait_for_facility_commit(
	region_id: String,
	facility_type: String,
	seconds: float
) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var map_debug := _map_debug_snapshot()
		var evidence := map_debug.get("facility_presentation_evidence", []) as Array
		for evidence_variant: Variant in evidence:
			if not (evidence_variant is Dictionary):
				continue
			var marker: Dictionary = evidence_variant as Dictionary
			if (
				str(marker.get(
					"requested_target_region_id",
					marker.get("region_id", "")
				)) == region_id
				and str(marker.get(
					"requested_facility_type",
					marker.get("facility_type", "")
				)) == facility_type
			):
				return true
		await process_frame
	return false


func _wait_for_facility_finish_count(expected_count: int, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var map_debug := _map_debug_snapshot()
		if int(map_debug.get("facility_presentation_finished_count", 0)) >= expected_count:
			return true
		await process_frame
	return false


func _wait_for_facility_receipts(
	receipt_ids: Array[String],
	seconds: float
) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var observed: Dictionary = {}
		for evidence_variant: Variant in (
			_map_debug_snapshot().get("facility_presentation_evidence", []) as Array
		):
			if evidence_variant is Dictionary:
				observed[str((evidence_variant as Dictionary).get(
					"receipt_id",
					""
				))] = true
		var all_observed := true
		for receipt_id in receipt_ids:
			if not observed.has(receipt_id):
				all_observed = false
				break
		if all_observed:
			return true
		await process_frame
	return false


func _wait_for_phase(phase_name: String, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var snapshot: Dictionary = _flow.call("local_snapshot") as Dictionary
		if str(snapshot.get("phase", "")) == phase_name:
			return true
		await process_frame
	return false


func _wait_for_track_advance(expected_count: int, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var runtime_snapshot := _runtime.call("debug_snapshot") as Dictionary
		if int(runtime_snapshot.get("v076_track_presentation_receipt_count", 0)) >= expected_count:
			return true
		await process_frame
	return false


func _map_debug_snapshot() -> Dictionary:
	if _map_view == null:
		return {}
	var result: Dictionary = {}
	if _map_view.has_method("v074_planet_debug_snapshot"):
		result.merge(_map_view.call("v074_planet_debug_snapshot") as Dictionary, true)
	if _map_view.has_method("get_sceneized_child_snapshot"):
		result.merge(_map_view.call("get_sceneized_child_snapshot") as Dictionary, true)
	return result


func _target_facility_debug(map_debug: Dictionary, region_id: String, facility_type: String, facility_id: String) -> Dictionary:
	for marker_variant: Variant in map_debug.get("facility_marker_debug", []) as Array:
		if not (marker_variant is Dictionary):
			continue
		var marker: Dictionary = marker_variant as Dictionary
		if (
			str(marker.get("region_id", "")) == region_id
			and str(marker.get("facility_type", "")) == facility_type
			and (
				facility_id.is_empty()
				or str(marker.get("facility_id", "")) == facility_id
			)
		):
			return marker.duplicate(true)
	return {}


func _target_marker_debug(map_debug: Dictionary, region_id: String, facility_type: String, facility_id: String) -> Dictionary:
	for marker_variant: Variant in map_debug.get("facility_marker_debug", []) as Array:
		if not (marker_variant is Dictionary):
			continue
		var marker: Dictionary = marker_variant as Dictionary
		if (
			str(marker.get("region_id", "")) == region_id
			and str(marker.get("facility_type", "")) == facility_type
			and (
				facility_id.is_empty()
				or str(marker.get("facility_id", "")) == facility_id
			)
		):
			return marker.duplicate(true)
	return {}


func _target_facility_evidence(map_debug: Dictionary, region_id: String, facility_type: String, facility_id: String) -> Dictionary:
	for evidence_variant: Variant in map_debug.get("facility_presentation_evidence", []) as Array:
		if not (evidence_variant is Dictionary):
			continue
		var evidence: Dictionary = evidence_variant as Dictionary
		if (
			str(evidence.get("requested_target_region_id", evidence.get("region_id", ""))) == region_id
			and str(evidence.get("requested_facility_type", evidence.get("facility_type", ""))) == facility_type
			and (
				facility_id.is_empty()
				or str(evidence.get(
					"requested_facility_id",
					evidence.get("facility_id", "")
				)) == facility_id
			)
		):
			return evidence.duplicate(true)
	return {}


func _facility_visual_green(debug: Dictionary) -> bool:
	return (
		not str(debug.get("visual_model_kind", "")).is_empty()
		and bool(debug.get("primary_visual_silhouette", false))
		and not bool(debug.get("primary_visual_letter_only", true))
		and bool(debug.get("human_visible", false))
		and bool(debug.get("inside_viewport", false))
		and not bool(debug.get("clip_contents", true))
		and int(debug.get("silhouette_primitive_count", 0)) >= 4
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


func _on_track_presentation_receipt_ready(receipt: Dictionary) -> void:
	_track_receipts.append(receipt.duplicate(true))


func _click(control: Control) -> void:
	if control == null:
		return
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	down.global_position = point
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	up.global_position = point
	Input.parse_input_event(up)
	await process_frame


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _cleanup() -> void:
	if _application != null and is_instance_valid(_application):
		_application.queue_free()
	await _frames(4)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"V076_PHASE6_FACILITY_MAP_TRACK_PRESENTATION_GATE|status=%s|checks=%d|passed=%d|track_receipts=%d|facility_receipts=%d|failures=%s"
		% [
			status,
			_checks,
			_checks - _failures.size(),
			_track_receipts.size(),
			_facility_receipts.size(),
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
