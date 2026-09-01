extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_SEED := 900626424
const MAX_STEPS := 4000
const PresentationReceiptIdentity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)

var _checks := 0
var _failures: Array[String] = []
var _presented_settlements: Array[Dictionary] = []
var _flow: Node
var _final_director_queued: Array[Dictionary] = []
var _final_director_finished: Array[Dictionary] = []
var _final_guard_at_queue: Dictionary = {}
var _final_guard_at_finish: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main scene loads")
	if packed == null:
		_finish()
		return
	var application := packed.instantiate()
	root.add_child(application)
	for _frame in range(4):
		await process_frame

	var flow: Node = application.get_node_or_null("V075RuntimeComposition")
	var runtime: Node = application.get_node_or_null(
		"V075RuntimeComposition/V075RuntimeOwner"
	)
	var combat: Node = application.get_node_or_null(
		"V075RuntimeComposition/V075CombatRuntimeOwner"
	)
	var telemetry: Node = application.get_node_or_null(
		"V075RuntimeComposition/V073PlaytestTelemetryService"
	)
	var screen: Control = application.get_node_or_null("V075GameScreen") as Control
	var director: Node = application.get_node_or_null(
		"V075GameScreen/V076PresentationAnimationDirector"
	)
	var arrangement: Control = application.get_node_or_null(
		"V075GameScreen/RootMargin/Shell/CentralPublicActionArrangement"
	) as Control
	if arrangement == null and screen != null:
		arrangement = screen.find_child(
			"CentralPublicActionArrangement",
			true,
			false
		) as Control
	var overlay: Control = application.get_node_or_null(
		"V075GameScreen/OverlayLayer/SettlementOverlay"
	) as Control
	var panel: Control = application.get_node_or_null(
		"V075GameScreen/OverlayLayer/SettlementOverlay/Center/Panel"
	) as Control
	var title: Label = application.get_node_or_null(
		"V075GameScreen/OverlayLayer/SettlementOverlay/Center/Panel/Rows/SettlementTitle"
	) as Label
	var standings_container: VBoxContainer = application.get_node_or_null(
		"V075GameScreen/OverlayLayer/SettlementOverlay/Center/Panel/Rows/SettlementStandings"
	) as VBoxContainer
	_expect(flow != null, "one production V075 application flow is reachable")
	_expect(runtime != null, "one production V075 gameplay and Victory owner is reachable")
	_expect(combat != null, "one production V075 combat owner is reachable")
	_expect(telemetry != null, "one production observation owner is reachable")
	_expect(screen != null, "real production V075 GameScreen is reachable")
	_expect(director != null, "real production Screen composes the unique animation Director")
	_expect(arrangement != null, "real production Screen composes the resolution arrangement")
	_expect(
		overlay != null
		and panel != null
		and title != null
		and standings_container != null,
		"real production Screen composes the Settlement Overlay surfaces"
	)
	if flow == null or runtime == null or combat == null or screen == null:
		application.queue_free()
		await process_frame
		_finish()
		return

	var main_source := FileAccess.get_file_as_string(MAIN_SCENE)
	_expect(
		main_source.contains("V075RuntimeComposition.tscn")
			and not main_source.contains("GameRuntimeCoordinator")
			and not main_source.contains("VictoryControlRuntimeController"),
		"production composition reuses V075 Victory and does not revive the V06 owner"
	)
	flow.final_settlement_presented.connect(_on_final_settlement_presented)
	_flow = flow
	if director != null:
		director.connect("cue_queued", _on_director_cue_queued)
		director.connect("cue_finished", _on_director_cue_finished)

	var started := flow.call("submit_intent", {
		"intent_id": "intent.v076.step13.production.new-game",
		"intent_kind": "new_game.start",
		"parameters": {"player_count": 4, "seed": TEST_SEED},
	}) as Dictionary
	_expect(bool(started.get("accepted", false)), "production new game starts through the public intent boundary")
	if not bool(started.get("accepted", false)):
		application.queue_free()
		await process_frame
		_finish()
		return
	for _frame in range(3):
		await process_frame

	var initial_flow_debug := flow.call("debug_snapshot") as Dictionary
	var initial_runtime_debug := initial_flow_debug.get("runtime", {}) as Dictionary
	var initial_snapshot := flow.call("local_snapshot") as Dictionary
	_expect(
		str(initial_runtime_debug.get("ruleset_id", "")) == "v0.7.5"
			and str(initial_runtime_debug.get("phase", "")) == "submission",
		"production Victory run begins in the V075 submission phase"
	)
	_expect(
		int(initial_runtime_debug.get("public_progress_points", -1)) == 0
			and int(initial_runtime_debug.get("public_progress_target", 0)) > 0
			and (initial_snapshot.get("final_settlement", {}) as Dictionary).is_empty(),
		"qualification starts below the public target with no preloaded settlement"
	)
	# The production menu lifecycle intentionally pauses the runtime while its
	# modal is open.  This probe enters through the typed Flow boundary rather
	# than clicking the menu, so release that presentation-only pause through the
	# existing test-only pacing intent before asking the RuntimeOwner to advance.
	var pace_result := flow.call("submit_intent", {
		"intent_id": "intent.v076.step13.production.pace",
		"intent_kind": "ui.pacing.set",
		"parameters": {"multiplier": 4},
	}) as Dictionary
	_expect(
		bool(pace_result.get("accepted", false)),
		"production Victory probe releases the menu pause through the existing pacing boundary"
	)

	var accelerated := flow.call("submit_intent", {
		"intent_id": "intent.v076.step13.production.accelerate",
		"intent_kind": "sample.accelerate",
		"parameters": {"max_steps": MAX_STEPS},
	}) as Dictionary
	_expect(
		bool(accelerated.get("accepted", false)),
		"production rules run reaches its natural terminal boundary without state injection"
	)
	var final_presentation_deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < final_presentation_deadline:
		var bridge_probe := _card_table_debug(screen)
		var final_row_probe := _cue_row(bridge_probe, "FINAL_SETTLEMENT")
		var arrangement_probe := (
			arrangement.call("arrangement_debug_snapshot") as Dictionary
			if arrangement != null
			else {}
		)
		var director_probe := (
			director.call("animation_debug_snapshot") as Dictionary
			if director != null
			else {}
		)
		if (
			int(final_row_probe.get("production_finished_count", 0)) == 1
			and int(bridge_probe.get("active_receipt_count", -1)) == 0
			and int(bridge_probe.get("queued_count", -1))
				== int(bridge_probe.get("finished_count", -2))
			and int(arrangement_probe.get("resolution_queue_count", -1)) == 0
			and str(arrangement_probe.get("resolution_stage", "")) == "IDLE"
			and not bool(arrangement_probe.get(
				"resolution_window_active",
				true
			))
			and int(arrangement_probe.get(
				"resolution_prestart_failure_count",
				-1
			)) == 0
			and int(arrangement_probe.get("active_transition_count", -1)) == 0
			and str(arrangement_probe.get(
				"resolution_current_receipt_id",
				"missing"
			)).is_empty()
			and int(director_probe.get("queued_cue_count", -1)) == 0
			and int(bridge_probe.get(
				"pending_final_settlement_count",
				-1
			)) == 0
		):
			break
		await process_frame

	var final_flow_debug := flow.call("debug_snapshot") as Dictionary
	var final_runtime_debug := final_flow_debug.get("runtime", {}) as Dictionary
	var final_snapshot := flow.call("local_snapshot") as Dictionary
	var settlement := final_snapshot.get("final_settlement", {}) as Dictionary
	var standings := settlement.get("standings", []) as Array
	var winner_player_id := str(settlement.get("winner_player_id", ""))
	var bridge := _card_table_debug(screen)
	var final_row := _cue_row(bridge, "FINAL_SETTLEMENT")
	var final_evidence := (
		(bridge.get("cue_evidence", {}) as Dictionary).get(
			"FINAL_SETTLEMENT",
			{}
		) as Dictionary
	).duplicate(true)
	var expected_receipt_id := _bridge_receipt_id(
		"FINAL_SETTLEMENT",
		str(settlement.get("settlement_id", ""))
	)
	_expect(
		str(final_runtime_debug.get("phase", "")) == "settled"
			and int(final_runtime_debug.get("public_progress_points", -1))
				>= int(final_runtime_debug.get("public_progress_target", 0)),
		"production Victory owner reaches qualification and the audited settlement boundary"
	)
	_expect(
		bool(final_runtime_debug.get("solar_validation", false))
			and int(final_runtime_debug.get("final_settlement_count", 0)) == 1,
		"the reused Solar Victory state validates and commits one FinalSettlement"
	)
	_expect(
		str(settlement.get("ruleset_id", "")) == "v0.7.5"
			and not str(settlement.get("settlement_id", "")).is_empty()
			and standings.size() == 4
			and not winner_player_id.is_empty()
			and winner_player_id == str((standings[0] as Dictionary).get("player_id", "")),
		"FinalSettlement binds the V075 ruleset, four standings, and its first-ranked winner"
	)
	_expect(
		int(settlement.get("settlement_count", 0)) == 1
			and int(settlement.get("presentation_count", 0)) == 1
			and int(settlement.get("public_log_count", 0)) == 1,
		"FinalSettlement declares one settlement, presentation, and public log"
	)
	_expect(
		_presented_settlements.size() == 1
			and _same_data(_presented_settlements[0], settlement),
		"production ApplicationFlow emits the exact FinalSettlement once"
	)
	_assert_final_settlement_presentation_chain(
		settlement,
		expected_receipt_id,
		bridge,
		final_row,
		final_evidence,
		screen,
		director,
		arrangement,
		overlay,
		panel,
		title,
		standings_container
	)

	var final_history_rows := _final_settlement_history_rows(
		final_snapshot.get("public_history", []) as Array
	)
	_expect(
		final_history_rows.size() == 1
			and str(final_history_rows[0].get("settlement_id", ""))
				== str(settlement.get("settlement_id", "")),
		"the public terminal log binds the same settlement identity once"
	)
	var acceptance := screen.get("acceptance_state") as Dictionary
	var interaction_counts := acceptance.get("interaction_counts", {}) as Dictionary
	_expect(
		bool(acceptance.get("match_completed", false))
			and bool(acceptance.get("settlement_visible", false))
			and int(interaction_counts.get("settlement_presented", 0)) == 1,
		"the real production GameScreen presents the completed settlement once"
	)
	_expect(
		int(acceptance.get("final_settlement_count", 0)) == 1
			and int(acceptance.get("duplicate_settlement_count", -1)) == 0,
		"the player-facing acceptance projection reports exact-once terminal state"
	)

	var quiescence := combat.call("terminal_quiescence_report") as Dictionary
	_expect(
		bool(quiescence.get("green", false))
			and int(quiescence.get("private_queue_count", -1)) == 0
			and int(quiescence.get("private_skill_resolving_count", -1)) == 0
			and int(quiescence.get("private_skill_atomic_inflight_count", -1)) == 0
			and int(quiescence.get("unresolved_military_lock_count", -1)) == 0,
		"Victory commits only after every private skill and military mission is quiescent"
	)
	var acquisition_policy := runtime.call(
		"v075_track_acquisition_policy_snapshot"
	) as Dictionary
	_expect(
		int(acquisition_policy.get("card_injection_count", -1)) == 0
			and int(acquisition_policy.get("asset_injection_count", -1)) == 0
			and int(acquisition_policy.get("target_injection_count", -1)) == 0,
		"the terminal run injects no card, asset, or target state"
	)
	_expect(
		int(final_runtime_debug.get("runtime_error_count", -1)) == 0
			and int(final_runtime_debug.get("invalid_action_count", -1)) == 0
			and int(final_runtime_debug.get("hidden_info_violation_count", -1)) == 0
			and int(final_runtime_debug.get("dual_authority_count", -1)) == 0
			and int(final_runtime_debug.get("legacy_fallback_count", -1)) == 0,
		"production terminal path has no runtime, privacy, dual-authority, or fallback violation"
	)

	var before_replay := _terminal_signature(
		final_runtime_debug,
		final_snapshot,
		acceptance,
		_presented_settlements.size()
	)
	var bridge_before_replay := _stable_bridge_signature(bridge)
	var director_before_replay := _stable_director_signature(
		director.call("animation_debug_snapshot") as Dictionary
	)
	var overlay_before_replay := {
		"visible": overlay.visible,
		"modulate": overlay.modulate,
		"panel_rect": panel.get_global_rect(),
		"panel_scale": panel.scale,
		"title": title.text,
		"standing_count": standings_container.get_child_count(),
	}
	var replay := flow.call("submit_intent", {
		"intent_id": "intent.v076.step13.production.accelerate.replay",
		"intent_kind": "sample.accelerate",
		"parameters": {"max_steps": MAX_STEPS},
	}) as Dictionary
	for _frame in range(2):
		await process_frame
	var replay_flow_debug := flow.call("debug_snapshot") as Dictionary
	var replay_runtime_debug := replay_flow_debug.get("runtime", {}) as Dictionary
	var replay_snapshot := flow.call("local_snapshot") as Dictionary
	var replay_acceptance := screen.get("acceptance_state") as Dictionary
	var after_replay := _terminal_signature(
		replay_runtime_debug,
		replay_snapshot,
		replay_acceptance,
		_presented_settlements.size()
	)
	var replay_bridge := _card_table_debug(screen)
	var replay_director := director.call("animation_debug_snapshot") as Dictionary
	_expect(
		bool(replay.get("accepted", false)) and _same_data(before_replay, after_replay),
		"terminal replay is idempotent across owner, public log, and presentation state"
	)
	_expect(
		_same_data(bridge_before_replay, _stable_bridge_signature(replay_bridge))
		and _same_data(
			director_before_replay,
			_stable_director_signature(replay_director)
		)
		and _same_data(overlay_before_replay, {
			"visible": overlay.visible,
			"modulate": overlay.modulate,
			"panel_rect": panel.get_global_rect(),
			"panel_scale": panel.scale,
			"title": title.text,
			"standing_count": standings_container.get_child_count(),
		}),
		"terminal replay adds no bridge, Director, or Settlement Overlay presentation"
	)

	var telemetry_debug := (
		telemetry.call("debug_snapshot") as Dictionary
		if telemetry != null
		else {}
	)
	var candidate_identity := telemetry_debug.get(
		"candidate_identity",
		{}
	) as Dictionary
	_expect(
		bool(candidate_identity.get("configured", false))
			and str(candidate_identity.get("product_version", "")) == "v0.7.6"
			and str(candidate_identity.get("runtime_ruleset_id", "")) == "v0.7.5",
		"the terminal run remains bound to the V076 candidate over the V075 runtime"
	)

	application.queue_free()
	for _frame in range(3):
		await process_frame
	_finish()


func _on_final_settlement_presented(settlement: Dictionary) -> void:
	_presented_settlements.append(settlement.duplicate(true))


func _on_director_cue_queued(cue: Dictionary) -> void:
	if str(cue.get("cue_id", "")) != "FINAL_SETTLEMENT":
		return
	var copy := cue.duplicate(true)
	_final_director_queued.append(copy)
	var receipt_id := str(copy.get("receipt_id", ""))
	if not receipt_id.is_empty():
		_final_guard_at_queue[receipt_id] = _stable_authority_guard()


func _on_director_cue_finished(cue: Dictionary) -> void:
	if str(cue.get("cue_id", "")) != "FINAL_SETTLEMENT":
		return
	var copy := cue.duplicate(true)
	_final_director_finished.append(copy)
	var receipt_id := str(copy.get("receipt_id", ""))
	if not receipt_id.is_empty():
		_final_guard_at_finish[receipt_id] = _stable_authority_guard()


func _assert_final_settlement_presentation_chain(
	settlement: Dictionary,
	expected_receipt_id: String,
	bridge: Dictionary,
	final_row: Dictionary,
	final_evidence: Dictionary,
	screen: Control,
	director: Node,
	arrangement: Control,
	overlay: Control,
	panel: Control,
	title: Label,
	standings_container: VBoxContainer
) -> void:
	for field_name in [
		"source_count",
		"envelope_count",
		"queued_count",
		"surface_started_count",
		"surface_finished_count",
		"finished_count",
		"production_source_count",
		"production_queued_count",
		"production_surface_started_count",
		"production_surface_finished_count",
		"production_finished_count",
	]:
		_expect(
			int(final_row.get(field_name, -1)) == 1,
			"FINAL_SETTLEMENT %s is exactly one" % field_name
		)
	for field_name in [
		"duplicate_count",
		"collision_count",
		"rejection_count",
		"finish_missing_count",
		"surface_rejection_count",
		"fixture_source_count",
		"fixture_queued_count",
		"fixture_surface_started_count",
		"fixture_surface_finished_count",
		"fixture_finished_count",
	]:
		_expect(
			int(final_row.get(field_name, -1)) == 0,
			"FINAL_SETTLEMENT %s remains zero" % field_name
		)
	var envelope := final_evidence.get("envelope", {}) as Dictionary
	var start_evidence := final_evidence.get("start_evidence", {}) as Dictionary
	var finish_evidence := final_evidence.get("finish_evidence", {}) as Dictionary
	var queued_cue := final_evidence.get("queued_cue", {}) as Dictionary
	var settlement_id := str(settlement.get("settlement_id", ""))
	var settlement_fingerprint := PresentationReceiptIdentity.canonical_sha256(
		settlement
	)
	var winner_player_id := str(settlement.get("winner_player_id", ""))
	var winner_row := _standing_for_player(
		settlement.get("standings", []) as Array,
		winner_player_id
	)
	var winner_display_name := str(winner_row.get(
		"display_name",
		""
	)).strip_edges()
	_expect(
		str(final_evidence.get("status", "")) == "FINISHED"
		and str(final_evidence.get("receipt_id", "")) == expected_receipt_id
		and str(final_evidence.get("consumer_class", ""))
			== "AUTHORIZED_SETTLEMENT_PROJECTION"
		and str(final_evidence.get("abort_reason", "")) == "",
		"FinalSettlement evidence records a production finish rather than an abort"
	)
	_expect(
		str(envelope.get("schema", ""))
			== "V076FinalSettlementPresentationEnvelopeV1"
		and int(envelope.get("schema_version", 0)) == 1
		and bool(envelope.get("accepted", false))
		and str(envelope.get("receipt_id", "")) == expected_receipt_id
		and str(envelope.get("cue_id", "")) == "FINAL_SETTLEMENT"
		and str(envelope.get("receipt_kind", "")) == "final_settlement_receipt"
		and str(envelope.get("source_lineage_class", ""))
			== "AUTHORIZED_SETTLEMENT_PROJECTION"
		and str(envelope.get("fixture_class", "")) == ""
		and not bool(envelope.get("production_green", true))
		and not bool(envelope.get("human_green", true)),
		"FinalSettlement uses the production settlement Projection without fixture or green inflation"
	)
	_expect(
		str(envelope.get("source_settlement_id_sha256", ""))
			== PresentationReceiptIdentity.canonical_sha256({
				"settlement_id": settlement_id,
			})
		and str(envelope.get("source_settlement_projection_sha256", ""))
			== settlement_fingerprint
		and str(queued_cue.get("receipt_fingerprint", ""))
			== PresentationReceiptIdentity.canonical_sha256(envelope),
		"FinalSettlement ID, projection hash, and Director fingerprint share one canonical lineage"
	)
	_expect(
		_surface_evidence_green(start_evidence, true)
		and _surface_evidence_green(finish_evidence, false)
		and str(finish_evidence.get("terminal_status", "")) == "SETTLED",
		"FinalSettlement has real Rect evidence and a normal SETTLED terminal status"
	)
	_expect(
		_rect_close(
			finish_evidence.get("end_rect", Rect2()) as Rect2,
			panel.get_global_rect()
		)
		and panel.scale.is_equal_approx(Vector2.ONE)
		and overlay.modulate.is_equal_approx(Color.WHITE),
		"FinalSettlement Tween ends on the real settled Panel geometry"
	)
	_expect(
		not winner_row.is_empty()
		and not winner_display_name.is_empty(),
		"FinalSettlement standings resolve a non-empty display name for the winner"
	)
	_expect(
		overlay.visible
		and not winner_player_id.is_empty()
		and title.text.contains(winner_player_id)
		and standings_container.get_child_count() == 4,
		"real Settlement Overlay shows the winner and exactly four standings"
	)
	_expect(
		_director_cue_count(_final_director_queued, expected_receipt_id) == 1
		and _director_cue_count(_final_director_finished, expected_receipt_id) == 1,
		"unique Director queues and finishes the real FinalSettlement once"
	)
	var director_debug := director.call("animation_debug_snapshot") as Dictionary
	var arrangement_debug := arrangement.call(
		"arrangement_debug_snapshot"
	) as Dictionary
	_expect(
		int(bridge.get("active_receipt_count", -1)) == 0
		and int(bridge.get("queued_count", -1))
			== int(bridge.get("finished_count", -2))
		and int(bridge.get("surface_started_count", -1))
			== int(bridge.get("surface_finished_count", -2))
		and int(director_debug.get("queued_cue_count", -1)) == 0
		and int(arrangement_debug.get("resolution_queue_count", -1)) == 0
		and str(arrangement_debug.get("resolution_stage", "")) == "IDLE"
		and not bool(arrangement_debug.get("resolution_window_active", true))
		and int(arrangement_debug.get(
			"resolution_prestart_failure_count",
			-1
		)) == 0
		and int(arrangement_debug.get("active_transition_count", -1)) == 0
		and int(arrangement_debug.get(
			"pending_source_transition_count",
			-1
		)) == 0
		and int(arrangement_debug.get(
			"inflight_source_transition_count",
			-1
		)) == 0
		and int(arrangement_debug.get(
			"pending_anchor_transition_count",
			-1
		)) == 0
		and int(arrangement_debug.get(
			"inflight_anchor_transition_count",
			-1
		)) == 0
		and int(bridge.get("pending_final_settlement_count", -1)) == 0
		and int(bridge.get(
			"pending_final_settlement_present_count",
			-1
		)) == 1
		and int(bridge.get(
			"pending_final_settlement_cancel_count",
			-1
		)) == 0
		and int(bridge.get(
			"pending_final_settlement_timeout_count",
			-1
		)) == 0
		and str(arrangement_debug.get(
			"resolution_current_receipt_id",
			"missing"
		)).is_empty(),
		"FinalSettlement begins only after the presentation chain becomes quiescent"
	)
	_expect(
		_guard_valid(_final_guard_at_queue.get(expected_receipt_id, {}) as Dictionary)
		and _guard_valid(_final_guard_at_finish.get(expected_receipt_id, {}) as Dictionary),
		"FinalSettlement Director boundaries retain valid authority guards"
	)
	_expect(
		int(bridge.get("animation_gameplay_mutation_count", -1)) == 0
		and int(bridge.get("animation_rng_draw_delta", -1)) == 0
		and int(bridge.get("animation_authority_sequence_delta", -1)) == 0
		and int(bridge.get("animation_card_zone_mutation_count", -1)) == 0
		and _director_zero_mutation(director_debug),
		"FinalSettlement presentation owns no gameplay, RNG, sequence, deck, zone, or facility mutation"
	)
	print("V076_FINAL_SETTLEMENT_PRESENTATION_CHAIN|%s" % JSON.stringify({
		"receipt_id": expected_receipt_id,
		"row": final_row,
		"evidence": final_evidence,
		"director_queued_count": _final_director_queued.size(),
		"director_finished_count": _final_director_finished.size(),
	}))


func _standing_for_player(standings: Array, player_id: String) -> Dictionary:
	if player_id.is_empty():
		return {}
	for row_variant in standings:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		if str(row.get("player_id", "")) == player_id:
			return row.duplicate(true)
	return {}


func _card_table_debug(screen: Control) -> Dictionary:
	if screen == null or not is_instance_valid(screen):
		return {}
	return (
		(screen.call("combat_debug_snapshot") as Dictionary).get(
			"card_table_presentation",
			{}
		) as Dictionary
	).duplicate(true)


func _cue_row(bridge: Dictionary, cue_id: String) -> Dictionary:
	return (
		(bridge.get("cue_counts", {}) as Dictionary).get(cue_id, {})
		as Dictionary
	).duplicate(true)


func _bridge_receipt_id(cue_id: String, source_id: String) -> String:
	return "%s:%s" % [
		cue_id.to_lower().replace("_", "-"),
		PresentationReceiptIdentity.canonical_sha256({
			"cue_id": cue_id,
			"source_id": source_id,
		}).left(32),
	]


func _surface_evidence_green(evidence: Dictionary, is_start: bool) -> bool:
	return (
		not evidence.is_empty()
		and bool(evidence.get("presentation_only", false))
		and int(evidence.get("gameplay_mutation_count", -1)) == 0
		and int(evidence.get("rng_draw_delta", -1)) == 0
		and int(evidence.get("authority_sequence_delta", -1)) == 0
		and (
			_rect_has_area(evidence.get("source_rect", Rect2()))
			and _rect_has_area(evidence.get("target_rect", Rect2()))
			if is_start
			else _rect_has_area(evidence.get("end_rect", Rect2()))
		)
	)


func _rect_has_area(value: Variant) -> bool:
	return value is Rect2 and (value as Rect2).has_area()


func _rect_close(left: Rect2, right: Rect2) -> bool:
	return (
		left.position.distance_to(right.position) <= 0.5
		and left.size.distance_to(right.size) <= 0.5
	)


func _director_cue_count(rows: Array[Dictionary], receipt_id: String) -> int:
	var count := 0
	for row in rows:
		if (
			str(row.get("cue_id", "")) == "FINAL_SETTLEMENT"
			and str(row.get("receipt_id", "")) == receipt_id
		):
			count += 1
	return count


func _stable_authority_guard() -> Dictionary:
	if (
		_flow == null
		or not is_instance_valid(_flow)
		or not _flow.has_method("presentation_authority_guard_snapshot")
	):
		return {}
	var guard := _flow.call(
		"presentation_authority_guard_snapshot"
	) as Dictionary
	return {
		"valid": bool(guard.get("valid", false)),
		"kernel_rng_state_sha256": str(guard.get("kernel_rng_state_sha256", "")),
		"runtime_card_zone_state_sha256": str(guard.get("runtime_card_zone_state_sha256", "")),
		"runtime_track_state_sha256": str(guard.get("runtime_track_state_sha256", "")),
		"runtime_facility_state_sha256": str(guard.get("runtime_facility_state_sha256", "")),
		"runtime_settlement_state_sha256": str(guard.get("runtime_settlement_state_sha256", "")),
	}


func _guard_valid(guard: Dictionary) -> bool:
	if not bool(guard.get("valid", false)):
		return false
	for field_name in [
		"kernel_rng_state_sha256",
		"runtime_card_zone_state_sha256",
		"runtime_track_state_sha256",
		"runtime_facility_state_sha256",
		"runtime_settlement_state_sha256",
	]:
		if not PresentationReceiptIdentity.valid_sha256(str(guard.get(
			field_name,
			""
		))):
			return false
	return true


func _director_zero_mutation(debug: Dictionary) -> bool:
	for field_name in [
		"animation_gameplay_mutation_count",
		"animation_rng_draw_delta",
		"animation_authority_sequence_delta",
		"animation_deck_order_mutation_count",
		"animation_card_zone_mutation_count",
		"animation_facility_state_mutation_count",
	]:
		if int(debug.get(field_name, -1)) != 0:
			return false
	return true


func _stable_bridge_signature(bridge: Dictionary) -> Dictionary:
	return {
		"active_receipt_count": bridge.get("active_receipt_count", -1),
		"seen_receipt_count": bridge.get("seen_receipt_count", -1),
		"queued_count": bridge.get("queued_count", -1),
		"finished_count": bridge.get("finished_count", -1),
		"duplicate_count": bridge.get("duplicate_count", -1),
		"collision_count": bridge.get("collision_count", -1),
		"rejection_count": bridge.get("rejection_count", -1),
		"finish_missing_count": bridge.get("finish_missing_count", -1),
		"surface_started_count": bridge.get("surface_started_count", -1),
		"surface_finished_count": bridge.get("surface_finished_count", -1),
		"surface_rejection_count": bridge.get("surface_rejection_count", -1),
		"pending_final_settlement_count": bridge.get(
			"pending_final_settlement_count",
			-1
		),
		"pending_final_settlement_present_count": bridge.get(
			"pending_final_settlement_present_count",
			-1
		),
		"pending_final_settlement_cancel_count": bridge.get(
			"pending_final_settlement_cancel_count",
			-1
		),
		"pending_final_settlement_timeout_count": bridge.get(
			"pending_final_settlement_timeout_count",
			-1
		),
		"final_settlement_row": _cue_row(bridge, "FINAL_SETTLEMENT"),
		"final_settlement_evidence": (
			(bridge.get("cue_evidence", {}) as Dictionary).get(
				"FINAL_SETTLEMENT",
				{}
			) as Dictionary
		).duplicate(true),
	}


func _stable_director_signature(debug: Dictionary) -> Dictionary:
	return {
		"queued_cue_count": debug.get("queued_cue_count", -1),
		"finished_cue_count": debug.get("finished_cue_count", -1),
		"seen_receipt_count": debug.get("seen_receipt_count", -1),
		"receipt_duplicate_count": debug.get("receipt_duplicate_count", -1),
		"receipt_collision_count": debug.get("receipt_collision_count", -1),
		"receipt_rejection_count": debug.get("receipt_rejection_count", -1),
		"last_rejection_reason": debug.get("last_rejection_reason", ""),
		"zero_mutation": _director_zero_mutation(debug),
	}


func _final_settlement_history_rows(history: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row_variant in history:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		if str(row.get("outcome_id", "")) == "final_settlement":
			result.append(row.duplicate(true))
	return result


func _terminal_signature(
	runtime_debug: Dictionary,
	snapshot: Dictionary,
	acceptance: Dictionary,
	presented_count: int
) -> Dictionary:
	return {
		"phase": runtime_debug.get("phase", ""),
		"final_settlement_count": runtime_debug.get("final_settlement_count", -1),
		"final_settlement_public_log_count": runtime_debug.get(
			"final_settlement_public_log_count",
			-1
		),
		"final_settlement_presentation_count": runtime_debug.get(
			"final_settlement_presentation_count",
			-1
		),
		"duplicate_settlement_count": runtime_debug.get(
			"duplicate_settlement_count",
			-1
		),
		"final_settlement": (
			snapshot.get("final_settlement", {}) as Dictionary
		).duplicate(true),
		"final_public_history_rows": _final_settlement_history_rows(
			snapshot.get("public_history", []) as Array
		),
		"screen_settlement_presented_count": int((
			acceptance.get("interaction_counts", {}) as Dictionary
		).get("settlement_presented", -1)),
		"flow_settlement_presented_count": presented_count,
	}


func _same_data(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print(
		"V076_PRODUCTION_VICTORY_AUDIT_READINESS_TEST|status=%s|checks=%d|failures=%d|step13_readiness=%s|step13_golden=false|human_executed=false|human_confirmed=false|details=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
			str(_failures.is_empty()).to_lower(),
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
