extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_SEED := 900626424
const MAX_STEPS := 4000

var _checks := 0
var _failures: Array[String] = []
var _presented_settlements: Array[Dictionary] = []


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
	_expect(flow != null, "one production V075 application flow is reachable")
	_expect(runtime != null, "one production V075 gameplay and Victory owner is reachable")
	_expect(combat != null, "one production V075 combat owner is reachable")
	_expect(telemetry != null, "one production observation owner is reachable")
	_expect(screen != null, "real production V075 GameScreen is reachable")
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

	var accelerated := flow.call("submit_intent", {
		"intent_id": "intent.v076.step13.production.accelerate",
		"intent_kind": "sample.accelerate",
		"parameters": {"max_steps": MAX_STEPS},
	}) as Dictionary
	_expect(
		bool(accelerated.get("accepted", false)),
		"production rules run reaches its natural terminal boundary without state injection"
	)
	for _frame in range(4):
		await process_frame

	var final_flow_debug := flow.call("debug_snapshot") as Dictionary
	var final_runtime_debug := final_flow_debug.get("runtime", {}) as Dictionary
	var final_snapshot := flow.call("local_snapshot") as Dictionary
	var settlement := final_snapshot.get("final_settlement", {}) as Dictionary
	var standings := settlement.get("standings", []) as Array
	var winner_player_id := str(settlement.get("winner_player_id", ""))
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
	_expect(
		bool(replay.get("accepted", false)) and _same_data(before_replay, after_replay),
		"terminal replay is idempotent across owner, public log, and presentation state"
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
