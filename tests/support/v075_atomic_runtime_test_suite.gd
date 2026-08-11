extends RefCounted

const ApplicationFlow := preload(
	"res://scripts/v075_runtime/v075_application_flow.gd"
)
const RulesetOwner := preload(
	"res://scripts/v075_runtime/v075_ruleset_runtime_owner.gd"
)
const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)

const PARAMETERS := {
	"player_count": 4,
	"seed": 900626424,
	"map_seed": 900626424,
	"region_count": 16,
	"geography_complexity": "STANDARD",
	"land_ocean_profile": "BALANCED",
}


class FailingInitializeCombatOwner extends V075CombatRuntimeOwner:
	func initialize(
		_player_ids: Array,
		_map_receipt: Dictionary,
		_character_semantics_by_player: Dictionary = {}
	) -> Dictionary:
		set("_initialized", true)
		set("_phase", "initializing")
		set("_skill_state", {
			"pending_private_skill": [{
				"opaque_test_marker": "private.skill.must.not.escape",
			}],
		})
		set("_military_locks", {"mission.injected": {"status": "pending"}})
		set("_processed_receipt_keys", {"receipt.injected": true})
		return {
			"accepted": false,
			"reason_code": "injected_combat_initialize_failure",
			"opaque_test_marker": "private.skill.must.not.escape",
		}


class FailingCleanupCombatOwner extends FailingInitializeCombatOwner:
	func cleanup_failed_initialization(
		_context: Dictionary
	) -> Dictionary:
		return {
			"schema": "V075FailedInitializationCleanupResultV1",
			"accepted": false,
			"reason_code": "injected_cleanup_failure",
			"failed_cleanup_stage": "private_skill_queue",
			"cleanup_invocation_count": 1,
			"already_clean": false,
			"external_state_mutation_count": 0,
			"cleanup_owned_state_only": true,
			"remaining_binding_count": 1,
			"remaining_subscription_count": 1,
			"remaining_private_skill_count": 1,
			"remaining_instant_sequence_count": 1,
			"remaining_military_mission_count": 1,
			"remaining_receipt_count": 1,
			"remaining_ai_binding_count": 1,
			"remaining_player_projection_binding_count": 1,
			"remaining_telemetry_binding_count": 1,
			"remaining_state_entry_count": 1,
			"opaque_test_marker": "private.skill.must.not.escape",
		}


class MissingCleanupCombatOwner extends Node:
	func initialize(
		_player_ids: Array,
		_map_receipt: Dictionary,
		_character_semantics_by_player: Dictionary = {}
	) -> Dictionary:
		return {"accepted": true}


class FailingActivationRuntime extends V075RuntimeOwner:
	var super_activation_completed := false


	func activate_prepared_new_game(
		transaction_id: String
	) -> Dictionary:
		var activated := super.activate_prepared_new_game(transaction_id)
		if not bool(activated.get("accepted", false)):
			return activated
		super_activation_completed = true
		return {
			"accepted": false,
			"reason_code": "injected_owner_activation_failure",
		}


class TypeConfusedAbortRuntime extends FailingActivationRuntime:
	func abort_prepared_new_game(
		_transaction_id: String,
		_primary_failure: Dictionary
	) -> Dictionary:
		return {
			"schema": "V075InitializationFailureV1",
			"accepted": false,
			"reason_code": {
				"opaque_test_marker": "private.flow.whitelist.must.not.escape",
			},
			"failed_stage": "owner_activate",
			"failed_cleanup_stage": [
				"private.flow.whitelist.must.not.escape",
			],
			"remaining_binding_count": {
				"opaque_test_marker": "private.flow.whitelist.must.not.escape",
			},
			"cleanup_failure": {
				"schema": "V075FailedInitializationCleanupResultV1",
				"accepted": false,
				"reason_code": {
					"opaque_test_marker": (
						"private.flow.whitelist.must.not.escape"
					),
				},
				"failed_cleanup_stage": [
					"private.flow.whitelist.must.not.escape",
				],
			},
		}


class FailingPublicationSealRuntime extends V075RuntimeOwner:
	func seal_prepared_new_game_publication(
		_transaction_id: String
	) -> Dictionary:
		return {
			"accepted": false,
			"reason_code": "injected_pre_publication_failure",
		}


class FailingCommitRulesetOwner extends V075RulesetRuntimeOwner:
	func commit_prepared_new_game(
		_transaction_id: String
	) -> Dictionary:
		return {
			"accepted": false,
			"reason_code": "injected_ruleset_session_commit_failure",
		}


class FailingFinalizeRulesetOwner extends V075RulesetRuntimeOwner:
	func finalize_committed_new_game(
		_transaction_id: String
	) -> Dictionary:
		return {
			"accepted": false,
			"reason_code": "injected_ruleset_finalize_failure",
		}


class FailingRollbackRulesetOwner extends V075RulesetRuntimeOwner:
	func rollback_new_game_activation(
		_transaction_id: String
	) -> Dictionary:
		return {
			"accepted": false,
			"reason_code": "injected_ruleset_rollback_failure",
		}


class FailingAbortCleanupCombatOwner extends V075CombatRuntimeOwner:
	var cleanup_invocation_count := 0


	func cleanup_failed_initialization(
		_context: Dictionary
	) -> Dictionary:
		cleanup_invocation_count += 1
		return {
			"schema": "V075FailedInitializationCleanupResultV1",
			"accepted": false,
			"reason_code": "injected_abort_cleanup_failure",
			"failed_cleanup_stage": "combat_abort_cleanup",
			"cleanup_invocation_count": cleanup_invocation_count,
			"already_clean": false,
			"external_state_mutation_count": 0,
			"cleanup_owned_state_only": true,
			"remaining_binding_count": 1,
			"remaining_subscription_count": 1,
			"remaining_private_skill_count": 1,
			"remaining_instant_sequence_count": 1,
			"remaining_military_mission_count": 1,
			"remaining_receipt_count": 1,
			"remaining_ai_binding_count": 1,
			"remaining_player_projection_binding_count": 1,
			"remaining_telemetry_binding_count": 1,
			"remaining_state_entry_count": 1,
		}


class MalformedAcceptedCleanupCombatOwner extends FailingInitializeCombatOwner:
	var cleanup_invocation_count := 0


	func cleanup_failed_initialization(
		_context: Dictionary
	) -> Dictionary:
		cleanup_invocation_count += 1
		return {
			"schema": "V075FailedInitializationCleanupResultV1",
			"accepted": true,
			"reason_code": "combat_failed_initialization_cleaned",
			"failed_cleanup_stage": "",
			"cleanup_invocation_count": cleanup_invocation_count,
			"already_clean": false,
			"external_state_mutation_count": 0,
			"cleanup_owned_state_only": true,
			"remaining_binding_count": 0,
			"remaining_subscription_count": 0,
			"remaining_private_skill_count": 0,
			"remaining_instant_sequence_count": 0,
			"remaining_military_mission_count": 0,
			"remaining_receipt_count": 0,
			"remaining_ai_binding_count": 0,
			"remaining_player_projection_binding_count": 0,
			"remaining_telemetry_binding_count": 0,
		}


class FalseGreenCleanupCombatOwner extends FailingInitializeCombatOwner:
	var cleanup_invocation_count := 0


	func cleanup_failed_initialization(
		_context: Dictionary
	) -> Dictionary:
		cleanup_invocation_count += 1
		return {
			"schema": "V075FailedInitializationCleanupResultV1",
			"accepted": true,
			"reason_code": "combat_failed_initialization_cleaned",
			"failed_cleanup_stage": "",
			"cleanup_invocation_count": cleanup_invocation_count,
			"already_clean": false,
			"external_state_mutation_count": 0,
			"cleanup_owned_state_only": true,
			"remaining_binding_count": 0,
			"remaining_subscription_count": 0,
			"remaining_private_skill_count": 0,
			"remaining_instant_sequence_count": 0,
			"remaining_military_mission_count": 0,
			"remaining_receipt_count": 0,
			"remaining_ai_binding_count": 0,
			"remaining_player_projection_binding_count": 0,
			"remaining_telemetry_binding_count": 0,
			"remaining_state_entry_count": 0,
		}


class TypeConfusedCleanupCombatOwner extends FailingInitializeCombatOwner:
	func cleanup_failed_initialization(
		_context: Dictionary
	) -> Dictionary:
		return {
			"schema": "V075FailedInitializationCleanupResultV1",
			"accepted": false,
			"reason_code": {
				"opaque_test_marker": "private.whitelist.must.not.escape",
			},
			"failed_cleanup_stage": [
				"private.whitelist.must.not.escape",
			],
			"cleanup_invocation_count": 1,
			"already_clean": {
				"opaque_test_marker": "private.whitelist.must.not.escape",
			},
			"external_state_mutation_count": 0,
			"cleanup_owned_state_only": true,
			"remaining_binding_count": 0,
			"remaining_subscription_count": 0,
			"remaining_private_skill_count": 0,
			"remaining_instant_sequence_count": 0,
			"remaining_military_mission_count": 0,
			"remaining_receipt_count": 0,
			"remaining_ai_binding_count": 0,
			"remaining_player_projection_binding_count": 0,
			"remaining_telemetry_binding_count": 0,
			"remaining_state_entry_count": 0,
		}


class TypeConfusedPrimaryActivationRuntime extends V075RuntimeOwner:
	func activate_prepared_new_game(
		transaction_id: String
	) -> Dictionary:
		var activated := super.activate_prepared_new_game(transaction_id)
		if not bool(activated.get("accepted", false)):
			return activated
		return {
			"accepted": false,
			"reason_code": {
				"opaque_test_marker": "private.primary.reason.must.not.escape",
			},
		}


class TypeConfusedPostRollbackRuntime extends FailingActivationRuntime:
	func abort_prepared_new_game(
		transaction_id: String,
		primary_failure: Dictionary
	) -> Dictionary:
		var rolled_back := super.abort_prepared_new_game(
			transaction_id,
			primary_failure
		)
		rolled_back["reason_code"] = {
			"opaque_test_marker": "private.rollback.reason.must.not.escape",
		}
		return rolled_back


class MalformedZeroedCleanupCombatOwner extends FailingInitializeCombatOwner:
	var cleanup_invocation_count := 0


	func cleanup_failed_initialization(
		context: Dictionary
	) -> Dictionary:
		cleanup_invocation_count += 1
		super.cleanup_failed_initialization(context)
		return {
			"schema": "V075FailedInitializationCleanupResultV1",
			"accepted": true,
			"reason_code": "combat_failed_initialization_cleaned",
			"failed_cleanup_stage": "",
			"cleanup_invocation_count": cleanup_invocation_count,
			"already_clean": false,
			"external_state_mutation_count": 0,
			"cleanup_owned_state_only": true,
			"remaining_binding_count": 0,
			"remaining_subscription_count": 0,
			"remaining_private_skill_count": 0,
			"remaining_instant_sequence_count": 0,
			"remaining_military_mission_count": 0,
			"remaining_receipt_count": 0,
			"remaining_ai_binding_count": 0,
			"remaining_player_projection_binding_count": 0,
			"remaining_telemetry_binding_count": 0,
			"opaque_test_marker": "private.malformed.zeroed.must.not.escape",
		}


class NonDictionaryZeroedCleanupCombatOwner extends Node:
	var cleanup_invocation_count := 0
	var inner := FailingInitializeCombatOwner.new()


	func _init() -> void:
		add_child(inner)


	func begin_initialization_transaction(
		context: Dictionary
	) -> Dictionary:
		return inner.begin_initialization_transaction(context)


	func initialize(
		player_ids: Array,
		map_receipt: Dictionary,
		character_semantics_by_player: Dictionary = {}
	) -> Dictionary:
		return inner.initialize(
			player_ids,
			map_receipt,
			character_semantics_by_player
		)


	func cleanup_failed_initialization(
		context: Dictionary
	) -> Variant:
		cleanup_invocation_count += 1
		inner.cleanup_failed_initialization(context)
		return [{
			"opaque_test_marker": "private.non_dictionary.must.not.escape",
		}]


	func begin_batch() -> Dictionary:
		return {}


	func set_phase() -> Dictionary:
		return {}


	func prebind_monster_card_action() -> Dictionary:
		return {}


	func resolve_monster_card_action() -> Dictionary:
		return {}


	func build_military_lock() -> Dictionary:
		return {}


	func resolve_military_action() -> Dictionary:
		return {}


	func begin_public_receipt() -> Dictionary:
		return {}


	func complete_public_receipt() -> Dictionary:
		return {}


	func request_private_skill() -> Dictionary:
		return {}


	func resolve_private_skill_safe_boundary() -> Dictionary:
		return {}


	func plan_autonomy() -> Dictionary:
		return {}


	func resolve_autonomy() -> Dictionary:
		return {}


	func public_monsters() -> Array:
		return []


	func owner_private_skill_zone() -> Array:
		return []


	func projection_authority_for_viewer() -> Dictionary:
		return {}


	func capture_checkpoint() -> Dictionary:
		return {}


	func rollback_checkpoint() -> Dictionary:
		return {}


	func debug_snapshot() -> Dictionary:
		return inner.debug_snapshot()

static func run_case(tree: SceneTree, case_id: String) -> Dictionary:
	var state := {
		"checks": 0,
		"failures": [],
	}
	match case_id:
		"application_flow_atomic_activation":
			_case_application_flow_atomic_activation(tree, state)
		"application_flow_signal_after_commit":
			_case_application_flow_signal_after_commit(tree, state)
		"application_flow_sync_reentry":
			_case_application_flow_sync_reentry(tree, state)
		"application_flow_activation_failure_rollback":
			_case_application_flow_activation_failure_rollback(tree, state)
		"runtime_owner_failed_init_cleanup":
			_case_runtime_owner_failed_init_cleanup(tree, state)
		"runtime_owner_cleanup_result_required":
			_case_runtime_owner_cleanup_result_required(tree, state)
		"runtime_owner_cleanup_failure_propagation":
			_case_runtime_owner_cleanup_failure_propagation(tree, state)
		"runtime_owner_cleanup_idempotence":
			_case_runtime_owner_cleanup_idempotence(tree, state)
		"runtime_owner_no_residual_bindings":
			_case_runtime_owner_no_residual_bindings(tree, state)
		"runtime_owner_no_residual_private_skill_state":
			_case_runtime_owner_no_residual_private_skill_state(tree, state)
		_:
			_expect(state, false, "unknown case: %s" % case_id)
	var failures := (state.get("failures", []) as Array).duplicate()
	return {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"checks": int(state.get("checks", 0)),
		"failure_count": failures.size(),
		"failures": failures,
	}


static func _case_application_flow_atomic_activation(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var fixture := _fixture(tree)
	_expect(
		state,
		bool(fixture.get("bound", {}).get("accepted", false)),
		"production Combat owner binds before the transaction"
	)
	var trace: Array[String] = []
	var visibility_checks: Dictionary = {}
	var visibility_debug: Dictionary = {}
	var runtime := fixture.get("runtime") as Node
	var ruleset := fixture.get("ruleset") as Node
	runtime.connect("match_started", func(_snapshot: Dictionary) -> void:
		trace.append("match_started")
		visibility_checks["match_started"] = _fully_committed(fixture, "runtime")
		visibility_debug["match_started"] = _publication_stage_snapshot(fixture)
	)
	runtime.connect("state_changed", func(_snapshot: Dictionary) -> void:
		trace.append("state_changed")
		visibility_checks["state_changed"] = _fully_committed(fixture, "runtime")
		visibility_debug["state_changed"] = _publication_stage_snapshot(fixture)
	)
	ruleset.connect("ruleset_activated", func(_identity: Dictionary) -> void:
		trace.append("ruleset_activated")
		visibility_checks["ruleset_activated"] = _fully_committed(
			fixture,
			"ruleset"
		)
		visibility_debug["ruleset_activated"] = (
			_publication_stage_snapshot(fixture)
		)
	)
	var started := _start_flow(fixture)
	_expect(
		state,
		bool(started.get("accepted", false)),
		"atomic production transaction succeeds"
	)
	_expect(
		state,
		trace == ["match_started", "state_changed", "ruleset_activated"],
		"public signals publish exactly once after the atomic commit"
	)
	_expect(
		state,
		visibility_checks == {
			"match_started": true,
			"state_changed": true,
			"ruleset_activated": true,
		},
		(
			"every synchronous listener observes a fully committed active Runtime: "
			+ JSON.stringify(visibility_checks)
			+ " debug="
			+ JSON.stringify(visibility_debug)
		)
	)
	var world_before_second_start := _frozen_world_snapshot(fixture)
	var second_start := _start_flow(fixture)
	var world_after_second_start := _frozen_world_snapshot(fixture)
	_expect(
		state,
		not bool(second_start.get("accepted", true))
			and str(second_start.get("reason_code", ""))
				== "new_game_requires_idle_runtime",
		"non-idle Runtime rejects a second initialization before mutation"
	)
	_expect(
		state,
		world_after_second_start == world_before_second_start
			and trace == [
				"match_started",
				"state_changed",
				"ruleset_activated",
			],
		"rejected second initialization preserves the complete prior world"
	)
	_destroy_fixture(fixture)

	var before_owner_fixture := _fixture(
		tree,
		RuntimeOwner.new(),
		RulesetOwner.new(),
		CombatOwner.new(),
		false
	)
	var before_owner_failure := _start_flow(before_owner_fixture)
	var before_ruleset := (
		(before_owner_fixture.get("ruleset") as Node)
		.call("identity_snapshot") as Dictionary
	)
	_expect(
		state,
		not bool(before_owner_failure.get("accepted", true))
			and str(before_owner_failure.get("reason_code", ""))
				== "combat_runtime_owner_not_bound",
		"failure before owner initialize rejects closed"
	)
	_expect(
		state,
		int(before_ruleset.get("activation_count", -1)) == 0
			and str(before_ruleset.get(
				"activation_transaction_stage",
				""
			)) == "idle",
		"failure before owner initialize cancels the staged ruleset"
	)
	_destroy_fixture(before_owner_fixture)

	var commit_fixture := _fixture(
		tree,
		RuntimeOwner.new(),
		FailingCommitRulesetOwner.new(),
		CombatOwner.new()
	)
	var commit_signal_count := {"runtime": 0, "ruleset": 0}
	(commit_fixture.get("runtime") as Node).connect(
		"state_changed",
		func(_snapshot: Dictionary) -> void:
			commit_signal_count["runtime"] += 1
	)
	(commit_fixture.get("ruleset") as Node).connect(
		"ruleset_activated",
		func(_identity: Dictionary) -> void:
			commit_signal_count["ruleset"] += 1
	)
	var commit_failure := _start_flow(commit_fixture)
	var commit_combat_debug := (
		(commit_fixture.get("combat") as Node).call(
			"debug_snapshot"
		) as Dictionary
	)
	_expect(
		state,
		not bool(commit_failure.get("accepted", true))
			and str(commit_failure.get("reason_code", ""))
				== "injected_ruleset_session_commit_failure",
		"failure during ruleset and session commit is preserved"
	)
	_expect(
		state,
		int(commit_signal_count.get("runtime", -1)) == 0
			and int(commit_signal_count.get("ruleset", -1)) == 0
			and not bool(commit_combat_debug.get("initialized", true)),
		"commit failure publishes nothing and cleans the initialized owner"
	)
	_destroy_fixture(commit_fixture)


static func _case_application_flow_signal_after_commit(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var fixture := _fixture(tree)
	var counts := {
		"match_started": 0,
		"state_changed": 0,
		"projection_changed": 0,
		"ruleset_activated": 0,
	}
	var listener_commit_checks: Array[bool] = []
	var ruleset_observation := {
		"payload": {},
		"live_during_signal": {},
	}
	var runtime := fixture.get("runtime") as Node
	var ruleset := fixture.get("ruleset") as Node
	var flow := fixture.get("flow") as Node
	runtime.connect("match_started", func(_snapshot: Dictionary) -> void:
		counts["match_started"] += 1
		listener_commit_checks.append(_fully_committed(fixture, "runtime"))
	)
	runtime.connect("state_changed", func(_snapshot: Dictionary) -> void:
		counts["state_changed"] += 1
		listener_commit_checks.append(_fully_committed(fixture, "runtime"))
	)
	flow.connect("projection_changed", func(_snapshot: Dictionary) -> void:
		counts["projection_changed"] += 1
		listener_commit_checks.append(_fully_committed(fixture, "runtime"))
	)
	ruleset.connect("ruleset_activated", func(identity: Dictionary) -> void:
		counts["ruleset_activated"] += 1
		ruleset_observation["payload"] = identity.duplicate(true)
		ruleset_observation["live_during_signal"] = (
			ruleset.call("identity_snapshot") as Dictionary
		).duplicate(true)
		listener_commit_checks.append(_fully_committed(fixture, "ruleset"))
	)
	var started := _start_flow(fixture)
	_expect(
		state,
		bool(started.get("accepted", false))
			and int(started.get("runtime_signal_publication_count", 0)) == 1
			and int(started.get("ruleset_signal_publication_count", 0)) == 1,
		"transaction receipt proves one runtime and one ruleset publication"
	)
	_expect(
		state,
		counts == {
			"match_started": 1,
			"state_changed": 1,
			"projection_changed": 1,
			"ruleset_activated": 1,
		},
		"all public signals are exact once"
	)
	_expect(
		state,
		not listener_commit_checks.has(false),
		"all public signals occur after ruleset, session, and owner commit"
	)
	var ruleset_payload := (
		ruleset_observation.get("payload", {}) as Dictionary
	)
	var ruleset_live_during_signal := (
		ruleset_observation.get(
			"live_during_signal",
			{}
		) as Dictionary
	)
	var ruleset_final := (
		ruleset.call("identity_snapshot") as Dictionary
	).duplicate(true)
	_expect(
		state,
		not ruleset_payload.is_empty()
			and ruleset_payload == ruleset_live_during_signal
			and ruleset_payload == ruleset_final
			and str(ruleset_payload.get(
				"activation_transaction_stage",
				""
			)) == "idle"
			and not bool(ruleset_payload.get(
				"pending_initialization_rollback",
				true
			))
			and int(ruleset_payload.get(
				"published_activation_count",
				0
			)) == 1,
		"ruleset signal carries the exact canonical completed identity"
	)
	_destroy_fixture(fixture)


static func _case_application_flow_sync_reentry(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var fixture := _fixture(tree)
	var flow := fixture.get("flow") as Node
	var runtime := fixture.get("runtime") as Node
	var ruleset := fixture.get("ruleset") as Node
	var combat := fixture.get("combat") as Node
	var observation := {
		"projection_call_count": 0,
		"runtime_signal_call_count": 0,
		"ruleset_signal_call_count": 0,
		"flow_reentry": {},
		"runtime_reentry_from_runtime_signal": {},
		"runtime_reentry_from_ruleset_signal": {},
		"ruleset_reentry": {},
		"runtime_transaction_id": "",
		"ruleset_transaction_id": "",
		"session_sequence": -1,
		"ruleset": {},
		"runtime": {},
		"combat": {},
		"ruleset_early_emit_preserved": false,
		"runtime_early_complete_preserved": false,
	}
	runtime.connect("match_started", func(_snapshot: Dictionary) -> void:
		observation["runtime_signal_call_count"] += 1
		observation["runtime_reentry_from_runtime_signal"] = (
			_start_runtime(runtime)
		)
		var runtime_transaction := (
			runtime.get("_new_game_transaction") as Dictionary
		)
		var ruleset_transaction := (
			ruleset.get("_finalized_activation") as Dictionary
		)
		observation["runtime_transaction_id"] = str(
			runtime_transaction.get("transaction_id", "")
		)
		observation["ruleset_transaction_id"] = str(
			ruleset_transaction.get("transaction_id", "")
		)
		var ruleset_before := ruleset.call("debug_snapshot") as Dictionary
		var finalized_before := (
			ruleset.get("_finalized_activation") as Dictionary
		).duplicate(true)
		ruleset.call(
			"emit_finalized_new_game",
			str(observation.get("ruleset_transaction_id", ""))
		)
		var ruleset_after := ruleset.call("debug_snapshot") as Dictionary
		var finalized_after := (
			ruleset.get("_finalized_activation") as Dictionary
		).duplicate(true)
		observation["ruleset_early_emit_preserved"] = (
			int(observation.get("ruleset_signal_call_count", -1)) == 0
			and str(flow.get("_new_game_transaction_stage"))
				== "publish_runtime_signals"
			and bool(ruleset_before.get(
				"activation_publication_in_progress",
				false
			))
			and bool(ruleset_after.get(
				"activation_publication_in_progress",
				false
			))
			and finalized_before == finalized_after
			and str(finalized_after.get("transaction_id", ""))
				== str(observation.get("ruleset_transaction_id", ""))
		)
		runtime.call(
			"emit_finalized_new_game_signals",
			str(observation.get("runtime_transaction_id", ""))
		)
		runtime.call(
			"complete_finalized_new_game_publication",
			str(observation.get("runtime_transaction_id", ""))
		)
	)
	flow.connect("projection_changed", func(_snapshot: Dictionary) -> void:
		observation["projection_call_count"] += 1
		observation["session_sequence"] = int(flow.get("_session_sequence"))
		observation["ruleset"] = ruleset.call("identity_snapshot")
		observation["runtime"] = runtime.call("debug_snapshot")
		observation["combat"] = combat.call("debug_snapshot")
		observation["flow_reentry"] = flow.call(
			"_start_new_game",
			PARAMETERS.duplicate(true)
		)
	)
	ruleset.connect("ruleset_activated", func(_identity: Dictionary) -> void:
		observation["ruleset_signal_call_count"] += 1
		ruleset.call(
			"emit_finalized_new_game",
			str(observation.get("ruleset_transaction_id", ""))
		)
		runtime.call(
			"emit_finalized_new_game_signals",
			str(observation.get("runtime_transaction_id", ""))
		)
		var runtime_before := runtime.call("debug_snapshot") as Dictionary
		var transaction_before := (
			runtime.get("_new_game_transaction") as Dictionary
		).duplicate(true)
		runtime.call(
			"complete_finalized_new_game_publication",
			str(observation.get("runtime_transaction_id", ""))
		)
		var runtime_after := runtime.call("debug_snapshot") as Dictionary
		var transaction_after := (
			runtime.get("_new_game_transaction") as Dictionary
		).duplicate(true)
		observation["runtime_early_complete_preserved"] = (
			str(flow.get("_new_game_transaction_stage"))
				== "publish_ruleset_signal"
			and str(runtime_before.get(
				"new_game_transaction_stage",
				""
			)) == "published_waiting_completion"
			and str(runtime_after.get(
				"new_game_transaction_stage",
				""
			)) == "published_waiting_completion"
			and transaction_before == transaction_after
			and str(transaction_after.get("transaction_id", ""))
				== str(observation.get("runtime_transaction_id", ""))
		)
		observation["ruleset_reentry"] = ruleset.call(
			"activate_for_new_game",
			"session.reentry.injected",
			4,
			1,
			{}
		)
		observation["runtime_reentry_from_ruleset_signal"] = (
			_start_runtime(runtime)
		)
	)
	var idle_runtime_before := runtime.call(
		"debug_snapshot"
	) as Dictionary
	var idle_ruleset_before := ruleset.call(
		"debug_snapshot"
	) as Dictionary
	runtime.call(
		"emit_finalized_new_game_signals",
		"runtime.new_game.forged"
	)
	runtime.call(
		"complete_finalized_new_game_publication",
		"runtime.new_game.forged"
	)
	ruleset.call(
		"emit_finalized_new_game",
		"ruleset.new_game.forged"
	)
	var idle_runtime_after := runtime.call(
		"debug_snapshot"
	) as Dictionary
	var idle_ruleset_after := ruleset.call(
		"debug_snapshot"
	) as Dictionary
	_expect(
		state,
		int(observation.get("runtime_signal_call_count", -1)) == 0
			and int(observation.get("projection_call_count", -1)) == 0
			and int(observation.get("ruleset_signal_call_count", -1)) == 0
			and str(idle_runtime_before.get(
				"new_game_transaction_stage",
				""
			)) == str(idle_runtime_after.get(
				"new_game_transaction_stage",
				""
			))
			and int(idle_runtime_before.get(
				"new_game_publication_count",
				-1
			)) == int(idle_runtime_after.get(
				"new_game_publication_count",
				-2
			))
			and bool(idle_ruleset_before.get(
				"activation_publication_in_progress",
				false
			)) == bool(idle_ruleset_after.get(
				"activation_publication_in_progress",
				true
			))
			and int(idle_ruleset_before.get(
				"published_activation_count",
				-1
			)) == int(idle_ruleset_after.get(
				"published_activation_count",
				-2
			)),
		"idle sequencing primitives reject forged transaction identities"
	)
	var started := _start_flow(fixture)
	var flow_reentry := (
		observation.get("flow_reentry", {}) as Dictionary
	)
	var runtime_reentry_during_runtime := (
		observation.get(
			"runtime_reentry_from_runtime_signal",
			{}
		) as Dictionary
	)
	var runtime_reentry_during_ruleset := (
		observation.get(
			"runtime_reentry_from_ruleset_signal",
			{}
		) as Dictionary
	)
	var ruleset_reentry := (
		observation.get("ruleset_reentry", {}) as Dictionary
	)
	var ruleset_observed := observation.get("ruleset", {}) as Dictionary
	var runtime_observed := observation.get("runtime", {}) as Dictionary
	var combat_observed := observation.get("combat", {}) as Dictionary
	_expect(
		state,
		bool(started.get("accepted", false))
			and int(observation.get("projection_call_count", 0)) == 1
			and int(observation.get("runtime_signal_call_count", 0)) == 1
			and int(observation.get("ruleset_signal_call_count", 0)) == 1,
		"top-level transaction succeeds and invokes every reentry probe once"
	)
	_expect(
		state,
		not bool(flow_reentry.get("accepted", true))
			and str(flow_reentry.get("reason_code", ""))
				== "v075_new_game_transaction_in_progress",
		"ApplicationFlow synchronous reentry is rejected"
	)
	_expect(
		state,
		not bool(runtime_reentry_during_runtime.get("accepted", true))
			and str(runtime_reentry_during_runtime.get(
				"reason_code",
				""
			)) == "new_game_transaction_in_progress"
			and not bool(runtime_reentry_during_ruleset.get(
				"accepted",
				true
			))
			and str(runtime_reentry_during_ruleset.get(
				"reason_code",
				""
			)) == "new_game_transaction_in_progress",
		"Runtime owner guard spans both Runtime and Ruleset signal callbacks"
	)
	_expect(
		state,
		bool(observation.get("ruleset_early_emit_preserved", false)),
		"correct-ID Ruleset emit is rejected outside publish_ruleset_signal"
	)
	_expect(
		state,
		bool(observation.get("runtime_early_complete_preserved", false)),
		"correct-ID Runtime completion is rejected during Ruleset listener"
	)
	_expect(
		state,
		not bool(ruleset_reentry.get("accepted", true))
			and str(ruleset_reentry.get("reason_code", ""))
				== "ruleset_activation_transaction_in_progress",
		"Ruleset owner guard spans its synchronous signal callback"
	)
	_expect(
		state,
		int(observation.get("session_sequence", -1)) == 1
			and int(ruleset_observed.get("activation_count", 0)) == 1
			and str(ruleset_observed.get("last_session_id", ""))
				== "session.v075.sample.000001"
			and not bool(ruleset_observed.get(
				"pending_initialization_rollback",
				true
			)),
		"reentrant listener sees the committed session and ruleset"
	)
	_expect(
		state,
		str(runtime_observed.get("new_game_transaction_stage", ""))
				== "publishing"
			and not bool(runtime_observed.get(
				"pending_initialization_rollback",
				true
			))
			and bool(combat_observed.get("initialized", false)),
		"listener sees active Combat while the publication guard remains held"
	)
	var final_ruleset := ruleset.call("identity_snapshot") as Dictionary
	var final_runtime := runtime.call("debug_snapshot") as Dictionary
	_expect(
		state,
		int(flow.get("_new_game_reentry_rejection_count")) == 1
			and int(flow.get("_new_game_publication_count")) == 1
			and not str(observation.get(
				"runtime_transaction_id",
				""
			)).is_empty()
			and not str(observation.get(
				"ruleset_transaction_id",
				""
			)).is_empty()
			and int(final_ruleset.get("activation_count", 0)) == 1
			and int(final_ruleset.get("published_activation_count", 0)) == 1
			and int(final_runtime.get("new_game_publication_count", 0)) == 1
			and str(final_runtime.get("new_game_transaction_stage", ""))
				== "idle",
		"all reentry attempts create no duplicate activation or publication"
	)
	_destroy_fixture(fixture)


static func _case_application_flow_activation_failure_rollback(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var activation_fixture := _fixture(
		tree,
		FailingActivationRuntime.new(),
		RulesetOwner.new(),
		CombatOwner.new()
	)
	var activation_counts := {"runtime": 0, "ruleset": 0}
	(activation_fixture.get("runtime") as Node).connect(
		"state_changed",
		func(_snapshot: Dictionary) -> void:
			activation_counts["runtime"] += 1
	)
	(activation_fixture.get("ruleset") as Node).connect(
		"ruleset_activated",
		func(_identity: Dictionary) -> void:
			activation_counts["ruleset"] += 1
	)
	var activation_failure := _start_flow(activation_fixture)
	_expect(
		state,
		not bool(activation_failure.get("accepted", true))
			and str(activation_failure.get("reason_code", ""))
				== "injected_owner_activation_failure",
		"post-commit owner activation failure is preserved"
	)
	_expect(
		state,
		bool(
			(activation_fixture.get("runtime") as Node).get(
				"super_activation_completed"
			)
		)
			and _rolled_back_to_idle(activation_fixture)
			and activation_counts == {"runtime": 0, "ruleset": 0},
		"post-commit activation failure restores pre-init parity without signals"
	)
	_destroy_fixture(activation_fixture)

	var publication_fixture := _fixture(
		tree,
		FailingPublicationSealRuntime.new(),
		RulesetOwner.new(),
		CombatOwner.new()
	)
	var publication_counts := {"runtime": 0, "ruleset": 0}
	(publication_fixture.get("runtime") as Node).connect(
		"state_changed",
		func(_snapshot: Dictionary) -> void:
			publication_counts["runtime"] += 1
	)
	(publication_fixture.get("ruleset") as Node).connect(
		"ruleset_activated",
		func(_identity: Dictionary) -> void:
			publication_counts["ruleset"] += 1
	)
	var publication_failure := _start_flow(publication_fixture)
	_expect(
		state,
		not bool(publication_failure.get("accepted", true))
			and str(publication_failure.get("reason_code", ""))
				== "injected_pre_publication_failure",
		"failure after activation and before publication is preserved"
	)
	_expect(
		state,
		_rolled_back_to_idle(publication_fixture)
			and publication_counts == {"runtime": 0, "ruleset": 0},
		"pre-publication failure rolls back world, owner, and session"
	)
	_destroy_fixture(publication_fixture)

	var finalize_fixture := _fixture(
		tree,
		RuntimeOwner.new(),
		FailingFinalizeRulesetOwner.new(),
		CombatOwner.new()
	)
	var finalize_counts := {"runtime": 0, "ruleset": 0}
	(finalize_fixture.get("runtime") as Node).connect(
		"state_changed",
		func(_snapshot: Dictionary) -> void:
			finalize_counts["runtime"] += 1
	)
	(finalize_fixture.get("ruleset") as Node).connect(
		"ruleset_activated",
		func(_identity: Dictionary) -> void:
			finalize_counts["ruleset"] += 1
	)
	var finalize_failure := _start_flow(finalize_fixture)
	_expect(
		state,
		not bool(finalize_failure.get("accepted", true))
			and str(finalize_failure.get("reason_code", ""))
				== "injected_ruleset_finalize_failure",
		"ruleset finalize failure occurs before the first public signal"
	)
	_expect(
		state,
		_rolled_back_to_idle(finalize_fixture)
			and finalize_counts == {"runtime": 0, "ruleset": 0},
		"ruleset finalize failure rolls back Runtime, Combat, and session"
	)
	_destroy_fixture(finalize_fixture)


static func _case_runtime_owner_failed_init_cleanup(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var fixture := _runtime_fixture(tree, FailingInitializeCombatOwner.new())
	var runtime := fixture.get("runtime") as Node
	var combat := fixture.get("combat") as Node
	var telemetry := runtime.get("_combat_telemetry_bridge") as Object
	var presentation := runtime.call(
		"combat_presentation_consumer"
	) as Node
	telemetry.set("_receipt_input_count", 7)
	telemetry.set("_last_reason_code", "observer.preexisting")
	presentation.set("_rejected_count", 3)
	presentation.set("_last_cue", {
		"presentation_receipt_id": "observer.preexisting",
	})
	var telemetry_before := (
		telemetry.call("debug_snapshot") as Dictionary
	).duplicate(true)
	var presentation_before := (
		presentation.call("debug_snapshot") as Dictionary
	).duplicate(true)
	var signals := {"match": 0, "state": 0, "fault": 0}
	runtime.connect("match_started", func(_snapshot: Dictionary) -> void:
		signals["match"] += 1
	)
	runtime.connect("state_changed", func(_snapshot: Dictionary) -> void:
		signals["state"] += 1
	)
	runtime.connect("runtime_fault", func(_receipt: Dictionary) -> void:
		signals["fault"] += 1
	)
	var sequence_before := int(runtime.get("_match_sequence"))
	var failed := _start_runtime(runtime)
	var combat_debug := combat.call("debug_snapshot") as Dictionary
	var residual := combat_debug.get(
		"failed_initialization_residuals",
		{}
	) as Dictionary
	_expect(
		state,
		not bool(failed.get("accepted", true))
			and str(failed.get("reason_code", ""))
				== "combat_runtime_initialization_failed",
		"partial owner initialization failure returns its typed primary reason"
	)
	_expect(
		state,
		signals == {"match": 0, "state": 0, "fault": 1},
		"failed initialization publishes no ready state and one fault"
	)
	_expect(
		state,
		int(combat_debug.get("failed_initialization_cleanup_count", 0)) == 1
			and _all_residual_counts_zero(residual)
			and not bool(combat_debug.get("initialized", true)),
		"mandatory cleanup clears every initialization-owned Combat residual"
	)
	_expect(
		state,
		(runtime.call("player_ids") as Array).is_empty()
			and int(runtime.get("_match_sequence")) == sequence_before
			and not bool(runtime.get("_combat_initialized")),
		"outer Runtime and match sequence return to pre-init parity"
	)
	_expect(
		state,
		(telemetry.call("debug_snapshot") as Dictionary)
				== telemetry_before
			and (presentation.call("debug_snapshot") as Dictionary)
				== presentation_before,
		"failed initialization preserves non-empty external observer state"
	)
	_destroy_fixture(fixture)


static func _case_runtime_owner_cleanup_result_required(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var host := Node.new()
	tree.root.add_child(host)
	var runtime := RuntimeOwner.new()
	var incomplete_owner := MissingCleanupCombatOwner.new()
	host.add_child(runtime)
	host.add_child(incomplete_owner)
	var binding := runtime.call(
		"bind_combat_owner",
		incomplete_owner
	) as Dictionary
	_expect(
		state,
		not bool(binding.get("accepted", true))
			and str(binding.get("reason_code", ""))
				== "combat_runtime_owner_method_missing:cleanup_failed_initialization",
		"owner binding requires the typed failed-initialization cleanup result"
	)
	_expect(
		state,
		not is_instance_valid(runtime.get("_combat_owner")),
		"missing cleanup contract leaves no bound Combat owner"
	)
	host.free()

	var malformed_owner := MalformedAcceptedCleanupCombatOwner.new()
	var malformed_fixture := _runtime_fixture(tree, malformed_owner)
	var malformed_runtime := (
		malformed_fixture.get("runtime") as Node
	)
	var ready_signal_count := {"match": 0, "state": 0}
	malformed_runtime.connect(
		"match_started",
		func(_snapshot: Dictionary) -> void:
			ready_signal_count["match"] += 1
	)
	malformed_runtime.connect(
		"state_changed",
		func(_snapshot: Dictionary) -> void:
			ready_signal_count["state"] += 1
	)
	var malformed_failure := _start_runtime(malformed_runtime)
	var malformed_cleanup := (
		malformed_failure.get("cleanup_failure", {}) as Dictionary
	)
	_expect(
		state,
		str(malformed_failure.get("reason_code", ""))
				== "initialization_failed_and_cleanup_failed"
			and malformed_owner.cleanup_invocation_count == 1,
		"accepted=true cannot bypass the complete cleanup result schema"
	)
	_expect(
		state,
		str(malformed_cleanup.get("failed_cleanup_stage", ""))
				== "combat_residual_verification"
			and int(malformed_cleanup.get(
				"remaining_state_entry_count",
				0
			)) > 0
			and ready_signal_count == {"match": 0, "state": 0},
		"malformed cleanup stays red with actual residual evidence"
	)
	_destroy_fixture(malformed_fixture)

	var zeroed_contract_cases := [
		{
			"label": "malformed zeroed Dictionary",
			"owner": MalformedZeroedCleanupCombatOwner.new(),
			"canary": "private.malformed.zeroed.must.not.escape",
		},
		{
			"label": "non-Dictionary zeroed receipt",
			"owner": NonDictionaryZeroedCleanupCombatOwner.new(),
			"canary": "private.non_dictionary.must.not.escape",
		},
	]
	for case_variant in zeroed_contract_cases:
		var case_data := case_variant as Dictionary
		var contract_owner := case_data.get("owner") as Node
		var contract_fixture := _runtime_fixture(tree, contract_owner)
		var contract_runtime := contract_fixture.get("runtime") as Node
		var contract_signals := {"match": 0, "state": 0}
		contract_runtime.connect(
			"match_started",
			func(_snapshot: Dictionary) -> void:
				contract_signals["match"] += 1
		)
		contract_runtime.connect(
			"state_changed",
			func(_snapshot: Dictionary) -> void:
				contract_signals["state"] += 1
		)
		var contract_failure := _start_runtime(contract_runtime)
		var cleanup_failure := (
			contract_failure.get("cleanup_failure", {}) as Dictionary
		)
		var contract_debug := (
			contract_owner.call("debug_snapshot") as Dictionary
		)
		var label := str(case_data.get("label", "cleanup contract case"))
		_expect(
			state,
			str(contract_failure.get("reason_code", ""))
					== "initialization_failed_and_cleanup_failed"
				and typeof(cleanup_failure.get("accepted")) == TYPE_BOOL
				and not bool(cleanup_failure.get("accepted"))
				and str(cleanup_failure.get("reason_code", ""))
					== "cleanup_failed_initialization_result_invalid"
				and str(cleanup_failure.get("failed_cleanup_stage", ""))
					== "cleanup_result_contract"
				and _all_residual_counts_zero(cleanup_failure)
				and typeof(cleanup_failure.get(
					"composition_binding_parity"
				)) == TYPE_BOOL
				and bool(cleanup_failure.get("composition_binding_parity"))
				and typeof(cleanup_failure.get(
					"external_state_mutation_count"
				)) == TYPE_INT
				and int(cleanup_failure.get(
					"external_state_mutation_count"
				)) == 0,
			label + " is normalized to one coherent typed failure"
		)
		_expect(
			state,
			contract_signals == {"match": 0, "state": 0}
				and int(contract_owner.get("cleanup_invocation_count")) == 1
				and typeof(contract_debug.get("initialized")) == TYPE_BOOL
				and not bool(contract_debug.get("initialized"))
				and str(contract_debug.get("phase", "")) == "idle"
				and not JSON.stringify(contract_failure).contains(
					str(case_data.get("canary", "missing.canary"))
				),
			label + " remains clean, private, and non-playable"
		)
		_destroy_fixture(contract_fixture)

	var false_green_owner := FalseGreenCleanupCombatOwner.new()
	var false_green_fixture := _runtime_fixture(tree, false_green_owner)
	var false_green_runtime := (
		false_green_fixture.get("runtime") as Node
	)
	var false_green_signals := {"match": 0, "state": 0}
	false_green_runtime.connect(
		"match_started",
		func(_snapshot: Dictionary) -> void:
			false_green_signals["match"] += 1
	)
	false_green_runtime.connect(
		"state_changed",
		func(_snapshot: Dictionary) -> void:
			false_green_signals["state"] += 1
	)
	var false_green_failure := _start_runtime(false_green_runtime)
	var false_green_cleanup := (
		false_green_failure.get("cleanup_failure", {}) as Dictionary
	)
	var false_green_debug := (
		false_green_owner.call("debug_snapshot") as Dictionary
	)
	var false_green_residuals := (
		false_green_debug.get(
			"failed_initialization_residuals",
			{}
		) as Dictionary
	)
	_expect(
		state,
		str(false_green_failure.get("reason_code", ""))
				== "initialization_failed_and_cleanup_failed"
			and str(false_green_cleanup.get(
				"failed_cleanup_stage",
				""
			)) == "combat_residual_verification"
			and false_green_owner.cleanup_invocation_count == 1,
		"complete typed zero report cannot hide actual Combat residuals"
	)
	_expect(
		state,
		int(false_green_cleanup.get(
			"remaining_state_entry_count",
			0
		)) > 0
			and int(false_green_residuals.get(
				"remaining_state_entry_count",
				0
			)) > 0
			and bool(false_green_debug.get("initialized", false))
			and false_green_signals == {"match": 0, "state": 0},
		"false-green cleanup remains red and publishes no ready signal"
	)
	_destroy_fixture(false_green_fixture)


static func _case_runtime_owner_cleanup_failure_propagation(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var fixture := _runtime_fixture(tree, FailingCleanupCombatOwner.new())
	var runtime := fixture.get("runtime") as Node
	var signals := {"match": 0, "state": 0, "fault": 0}
	runtime.connect("match_started", func(_snapshot: Dictionary) -> void:
		signals["match"] += 1
	)
	runtime.connect("state_changed", func(_snapshot: Dictionary) -> void:
		signals["state"] += 1
	)
	runtime.connect("runtime_fault", func(_receipt: Dictionary) -> void:
		signals["fault"] += 1
	)
	var failed := _start_runtime(runtime)
	var serialized := JSON.stringify(failed)
	_expect(
		state,
		str(failed.get("reason_code", ""))
				== "initialization_failed_and_cleanup_failed"
			and str(failed.get("failed_cleanup_stage", ""))
				== "private_skill_queue",
		"cleanup failure is combined with the primary initialization failure"
	)
	_expect(
		state,
		int(failed.get("remaining_binding_count", 0)) == 2
			and int(failed.get("remaining_subscription_count", 0)) == 1
			and failed.has("primary_initialization_failure")
			and failed.has("cleanup_failure"),
		"combined typed failure carries sanitized cleanup residuals"
	)
	_expect(
		state,
		not serialized.contains("private.skill.must.not.escape"),
		"combined failure does not disclose private Combat content"
	)
	_expect(
		state,
		signals == {"match": 0, "state": 0, "fault": 1}
			and (runtime.call("player_ids") as Array).is_empty()
			and not bool(runtime.get("_combat_initialized")),
		"cleanup failure cannot publish ready state or leave outer Runtime playable"
	)
	_destroy_fixture(fixture)

	var type_confused_fixture := _runtime_fixture(
		tree,
		TypeConfusedCleanupCombatOwner.new()
	)
	var type_confused_runtime := (
		type_confused_fixture.get("runtime") as Node
	)
	var type_confused_failure := _start_runtime(type_confused_runtime)
	var type_confused_cleanup := (
		type_confused_failure.get("cleanup_failure", {}) as Dictionary
	)
	_expect(
		state,
		str(type_confused_failure.get("reason_code", ""))
				== "initialization_failed_and_cleanup_failed"
			and str(type_confused_cleanup.get(
				"failed_cleanup_stage",
				""
			)) == "combat_residual_verification"
			and typeof(type_confused_cleanup.get("reason_code"))
				== TYPE_STRING
			and str(type_confused_cleanup.get("reason_code", ""))
				== "cleanup_failed_initialization_result_invalid"
			and typeof(type_confused_cleanup.get("already_clean"))
				== TYPE_BOOL
			and not bool(type_confused_cleanup.get("already_clean"))
			and not JSON.stringify(type_confused_failure).contains(
				"private.whitelist.must.not.escape"
			),
		"whitelisted failure fields reject non-scalar type-confusion payloads"
	)
	_destroy_fixture(type_confused_fixture)

	var flow_privacy_fixture := _fixture(
		tree,
		TypeConfusedAbortRuntime.new(),
		FailingRollbackRulesetOwner.new(),
		CombatOwner.new()
	)
	var flow_privacy_failure := _start_flow(flow_privacy_fixture)
	var projected_runtime_rollback := (
		flow_privacy_failure.get("runtime_rollback", {}) as Dictionary
	)
	var projected_cleanup_failure := (
		projected_runtime_rollback.get(
			"cleanup_failure",
			{}
		) as Dictionary
	)
	_expect(
		state,
		str(flow_privacy_failure.get("reason_code", ""))
				== "v075_new_game_transaction_rollback_failed"
			and not projected_runtime_rollback.has("reason_code")
			and not projected_runtime_rollback.has(
				"failed_cleanup_stage"
			)
			and not projected_runtime_rollback.has(
				"remaining_binding_count"
			)
			and not projected_cleanup_failure.has("reason_code")
			and not projected_cleanup_failure.has(
				"failed_cleanup_stage"
			)
			and not JSON.stringify(flow_privacy_failure).contains(
				"private.flow.whitelist.must.not.escape"
			),
		"ApplicationFlow recursively rejects type-confused whitelist values"
	)
	_destroy_fixture(flow_privacy_fixture)

	var primary_reason_fixture := _fixture(
		tree,
		TypeConfusedPrimaryActivationRuntime.new(),
		RulesetOwner.new(),
		CombatOwner.new()
	)
	var primary_reason_counts := {"runtime": 0, "ruleset": 0}
	(primary_reason_fixture.get("runtime") as Node).connect(
		"state_changed",
		func(_snapshot: Dictionary) -> void:
			primary_reason_counts["runtime"] += 1
	)
	(primary_reason_fixture.get("ruleset") as Node).connect(
		"ruleset_activated",
		func(_identity: Dictionary) -> void:
			primary_reason_counts["ruleset"] += 1
	)
	var primary_reason_failure := _start_flow(primary_reason_fixture)
	_expect(
		state,
		str(primary_reason_failure.get("reason_code", ""))
				== "v075_prepared_new_game_aborted"
			and not JSON.stringify(primary_reason_failure).contains(
				"private.primary.reason.must.not.escape"
			)
			and _rolled_back_to_idle(primary_reason_fixture)
			and primary_reason_counts == {"runtime": 0, "ruleset": 0},
		"real Runtime rejects type-confused primary reason without disclosure"
	)
	_destroy_fixture(primary_reason_fixture)

	var post_rollback_fixture := _fixture(
		tree,
		TypeConfusedPostRollbackRuntime.new(),
		RulesetOwner.new(),
		CombatOwner.new()
	)
	var post_rollback_counts := {"runtime": 0, "ruleset": 0}
	(post_rollback_fixture.get("runtime") as Node).connect(
		"state_changed",
		func(_snapshot: Dictionary) -> void:
			post_rollback_counts["runtime"] += 1
	)
	(post_rollback_fixture.get("ruleset") as Node).connect(
		"ruleset_activated",
		func(_identity: Dictionary) -> void:
			post_rollback_counts["ruleset"] += 1
	)
	var post_rollback_failure := _start_flow(post_rollback_fixture)
	var projected_post_rollback := (
		post_rollback_failure.get("runtime_rollback", {}) as Dictionary
	)
	_expect(
		state,
		str(post_rollback_failure.get("reason_code", ""))
				== "v075_new_game_transaction_rollback_failed"
			and not projected_post_rollback.has("reason_code")
			and not JSON.stringify(post_rollback_failure).contains(
				"private.rollback.reason.must.not.escape"
			)
			and _rolled_back_to_idle(post_rollback_fixture)
			and post_rollback_counts == {"runtime": 0, "ruleset": 0},
		"Flow rejects and projects a type-confused successful rollback receipt"
	)
	_destroy_fixture(post_rollback_fixture)

	var double_cleanup_owner := FailingAbortCleanupCombatOwner.new()
	var double_failure_fixture := _fixture(
		tree,
		FailingActivationRuntime.new(),
		FailingRollbackRulesetOwner.new(),
		double_cleanup_owner
	)
	var double_signal_count := {"runtime": 0, "ruleset": 0}
	(double_failure_fixture.get("runtime") as Node).connect(
		"state_changed",
		func(_snapshot: Dictionary) -> void:
			double_signal_count["runtime"] += 1
	)
	(double_failure_fixture.get("ruleset") as Node).connect(
		"ruleset_activated",
		func(_identity: Dictionary) -> void:
			double_signal_count["ruleset"] += 1
	)
	var double_failure := _start_flow(double_failure_fixture)
	var ruleset_rollback := (
		double_failure.get("ruleset_rollback", {}) as Dictionary
	)
	var runtime_rollback := (
		double_failure.get("runtime_rollback", {}) as Dictionary
	)
	var nested_primary := (
		runtime_rollback.get(
			"primary_initialization_failure",
			{}
		) as Dictionary
	)
	var nested_cleanup := (
		runtime_rollback.get("cleanup_failure", {}) as Dictionary
	)
	_expect(
		state,
		str(double_failure.get("reason_code", ""))
				== "v075_new_game_transaction_rollback_failed"
			and str(ruleset_rollback.get("reason_code", ""))
				== "injected_ruleset_rollback_failure"
			and str(runtime_rollback.get("reason_code", ""))
				== "initialization_failed_and_cleanup_failed",
		"ruleset rollback and Runtime cleanup failures remain jointly visible"
	)
	_expect(
		state,
		str(nested_primary.get("reason_code", ""))
				== "injected_owner_activation_failure"
			and str(nested_cleanup.get("reason_code", ""))
				== "injected_abort_cleanup_failure"
			and int(nested_cleanup.get(
				"remaining_state_entry_count",
				0
			)) > 0
			and int(runtime_rollback.get(
				"remaining_private_skill_count",
				0
			)) > 0,
		"double failure preserves the full nested typed cleanup composite"
	)
	_expect(
		state,
		double_cleanup_owner.cleanup_invocation_count == 1
			and double_signal_count == {"runtime": 0, "ruleset": 0},
		"double failure executes cleanup once and publishes no signal"
	)
	_destroy_fixture(double_failure_fixture)


static func _case_runtime_owner_cleanup_idempotence(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var host := Node.new()
	tree.root.add_child(host)
	var combat := CombatOwner.new()
	var external_marker := Node.new()
	host.add_child(combat)
	combat.add_child(external_marker)
	combat.set("_initialized", true)
	combat.set("_phase", "initializing")
	combat.set("_skill_state", {"pending": [{"opaque": "private"}]})
	combat.set("_military_locks", {"mission": {"pending": true}})
	var first := combat.call(
		"cleanup_failed_initialization",
		{"failed_stage": "initialize"}
	) as Dictionary
	var second := combat.call(
		"cleanup_failed_initialization",
		{"failed_stage": "repeated_cleanup"}
	) as Dictionary
	_expect(
		state,
		bool(first.get("accepted", false))
			and not bool(first.get("already_clean", true))
			and int(first.get("cleanup_invocation_count", 0)) == 1,
		"first cleanup clears the contaminated initialization state"
	)
	_expect(
		state,
		bool(second.get("accepted", false))
			and bool(second.get("already_clean", false))
			and int(second.get("cleanup_invocation_count", 0)) == 2,
		"repeated cleanup is accepted and reports already-clean idempotence"
	)
	_expect(
		state,
		_all_residual_counts_zero(second)
			and is_instance_valid(external_marker)
			and external_marker.get_parent() == combat,
		"repeated cleanup preserves external Node ownership and has zero residuals"
	)
	host.free()

	var stale_fixture := _runtime_fixture(tree, CombatOwner.new())
	var stale_runtime := stale_fixture.get("runtime") as Node
	var stale_combat := stale_fixture.get("combat") as Node
	var transaction_a := "combat.initialization.stale.a"
	var begin_a := stale_combat.call(
		"begin_initialization_transaction",
		{
			"schema": "V075CombatInitializationTransactionContextV1",
			"ownership_token": transaction_a,
		}
	) as Dictionary
	var cleanup_a := stale_combat.call(
		"cleanup_failed_initialization",
		{
			"schema": "V075FailedInitializationCleanupContextV1",
			"ownership_token": transaction_a,
			"failed_stage": "owner_initialize",
		}
	) as Dictionary
	var started_b := _start_runtime(stale_runtime)
	var active_token_b_before := str(stale_combat.get(
		"_active_initialization_ownership_token"
	))
	var local_player_id := str(stale_runtime.get("_local_player_id"))
	var player_snapshot_before := stale_runtime.call(
		"player_snapshot",
		local_player_id
	) as Dictionary
	var checkpoint_before := stale_combat.call(
		"capture_checkpoint",
		"checkpoint.stale.cleanup.guard"
	) as Dictionary
	var stale_cleanup_a := stale_combat.call(
		"cleanup_failed_initialization",
		{
			"schema": "V075FailedInitializationCleanupContextV1",
			"ownership_token": transaction_a,
			"failed_stage": "stale_duplicate_cleanup",
		}
	) as Dictionary
	var checkpoint_after := stale_combat.call(
		"capture_checkpoint",
		"checkpoint.stale.cleanup.guard"
	) as Dictionary
	var stale_debug := stale_combat.call("debug_snapshot") as Dictionary
	var active_token_b_after := str(stale_combat.get(
		"_active_initialization_ownership_token"
	))
	var player_snapshot_after := stale_runtime.call(
		"player_snapshot",
		local_player_id
	) as Dictionary
	var unknown_token := "combat.initialization.stale.unknown"
	var unknown_checkpoint_before := stale_combat.call(
		"capture_checkpoint",
		"checkpoint.unknown.cleanup.guard"
	) as Dictionary
	var unknown_cleanup := stale_combat.call(
		"cleanup_failed_initialization",
		{
			"schema": "V075FailedInitializationCleanupContextV1",
			"ownership_token": unknown_token,
			"failed_stage": "unknown_cleanup_request",
		}
	) as Dictionary
	var unknown_checkpoint_after := stale_combat.call(
		"capture_checkpoint",
		"checkpoint.unknown.cleanup.guard"
	) as Dictionary
	var active_token_b_after_unknown := str(stale_combat.get(
		"_active_initialization_ownership_token"
	))
	_expect(
		state,
		bool(begin_a.get("accepted", false))
			and bool(cleanup_a.get("accepted", false))
			and bool(started_b.get("accepted", false)),
		"transaction A cleans before transaction B initializes"
	)
	_expect(
		state,
		bool(stale_cleanup_a.get("accepted", false))
			and bool(stale_cleanup_a.get("already_clean", false))
			and int(stale_cleanup_a.get(
				"external_state_mutation_count",
				-1
			)) == 0,
		"stale duplicate cleanup A is an exact-once-safe no-op"
	)
	_expect(
		state,
		checkpoint_before == checkpoint_after
			and player_snapshot_before == player_snapshot_after
			and not active_token_b_before.is_empty()
			and active_token_b_before != transaction_a
			and active_token_b_after == active_token_b_before
			and bool(stale_debug.get("initialized", false))
			and str(stale_debug.get("phase", "idle")) != "idle"
			and bool(stale_debug.get(
				"initialization_transaction_active",
				false
			)),
		"stale cleanup A preserves transaction B checkpoint and active state"
	)
	_expect(
		state,
		not bool(unknown_cleanup.get("accepted", true))
			and str(unknown_cleanup.get("reason_code", ""))
				== "combat_failed_initialization_transaction_mismatch"
			and unknown_checkpoint_before == unknown_checkpoint_after
			and active_token_b_after_unknown == active_token_b_before,
		"unknown cleanup token is rejected without mutating transaction B"
	)
	_expect(
		state,
		not JSON.stringify(begin_a).contains(transaction_a)
			and not JSON.stringify(cleanup_a).contains(transaction_a)
			and not JSON.stringify(stale_cleanup_a).contains(transaction_a)
			and not JSON.stringify(stale_debug).contains(transaction_a)
			and not JSON.stringify(stale_debug).contains(active_token_b_before)
			and not JSON.stringify(unknown_cleanup).contains(unknown_token)
			and int(stale_debug.get(
				"initialization_transaction_token_disclosure_count",
				-1
			)) == 0,
		"Combat transaction receipts and debug never disclose ownership tokens"
	)
	_destroy_fixture(stale_fixture)


static func _case_runtime_owner_no_residual_bindings(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var fixture := _runtime_fixture(tree, FailingInitializeCombatOwner.new())
	var runtime := fixture.get("runtime") as Node
	var combat := fixture.get("combat") as Node
	var owner_before := runtime.get("_combat_owner") as Node
	var presentation_before := runtime.call(
		"combat_presentation_consumer"
	) as Node
	var connection_count_before := runtime.get_signal_connection_list(
		"resolution_presented"
	).size()
	var failed := _start_runtime(runtime)
	var connection_count_after := runtime.get_signal_connection_list(
		"resolution_presented"
	).size()
	var presentation_after := runtime.call(
		"combat_presentation_consumer"
	) as Node
	var residual := (
		combat.call("debug_snapshot") as Dictionary
	).get("failed_initialization_residuals", {}) as Dictionary
	_expect(
		state,
		not bool(failed.get("accepted", true))
			and _all_residual_counts_zero(residual),
		"failed initialization leaves zero initialization-owned bindings"
	)
	_expect(
		state,
		runtime.get("_combat_owner") == owner_before
			and owner_before == combat
			and presentation_after == presentation_before
			and connection_count_after == connection_count_before
			and connection_count_after == 2,
		"cleanup preserves pre-existing composition owner and observer bindings"
	)
	_destroy_fixture(fixture)


static func _case_runtime_owner_no_residual_private_skill_state(
	tree: SceneTree,
	state: Dictionary
) -> void:
	var host := Node.new()
	tree.root.add_child(host)
	var combat := CombatOwner.new()
	host.add_child(combat)
	combat.set("_initialized", true)
	combat.set("_phase", "initializing")
	combat.set("_skill_state", {
		"pending_private_skill": [{
			"opaque_test_marker": "private.skill.must.not.escape",
		}],
	})
	combat.set("_processed_receipt_keys", {
		"private.skill.receipt": true,
	})
	combat.set("_combat_receipt_journal", [{
		"opaque_test_marker": "private.skill.must.not.escape",
	}])
	var cleanup := combat.call(
		"cleanup_failed_initialization",
		{"failed_stage": "private_skill_initialize"}
	) as Dictionary
	var debug := combat.call("debug_snapshot") as Dictionary
	_expect(
		state,
		bool(cleanup.get("accepted", false))
			and int(cleanup.get("remaining_private_skill_count", -1)) == 0
			and int(cleanup.get("remaining_instant_sequence_count", -1)) == 0
			and int(cleanup.get("remaining_receipt_count", -1)) == 0,
		"cleanup clears private skill, sequence, and receipt residuals"
	)
	_expect(
		state,
		(combat.get("_skill_state") as Dictionary).is_empty()
			and (combat.get("_processed_receipt_keys") as Dictionary).is_empty()
			and (combat.get("_combat_receipt_journal") as Array).is_empty()
			and (combat.call(
				"owner_private_skill_zone",
				"player.local"
			) as Array).is_empty(),
		"no private skill request remains reachable after cleanup"
	)
	_expect(
		state,
		not JSON.stringify(cleanup).contains(
			"private.skill.must.not.escape"
		)
			and not JSON.stringify(debug).contains(
				"private.skill.must.not.escape"
			),
		"cleanup receipts and debug projection disclose no private marker"
	)
	host.free()


static func _fixture(
	tree: SceneTree,
	runtime_override: Node = null,
	ruleset_override: Node = null,
	combat_override: Node = null,
	bind_combat: bool = true
) -> Dictionary:
	var host := Node.new()
	host.name = "V075AtomicRuntimeTestHost"
	tree.root.add_child(host)
	var runtime := (
		runtime_override
		if runtime_override != null
		else RuntimeOwner.new()
	)
	var ruleset := (
		ruleset_override
		if ruleset_override != null
		else RulesetOwner.new()
	)
	var combat := (
		combat_override
		if combat_override != null
		else CombatOwner.new()
	)
	host.add_child(runtime)
	host.add_child(ruleset)
	host.add_child(combat)
	var bound: Dictionary = {}
	if bind_combat:
		bound = runtime.call("bind_combat_owner", combat) as Dictionary
	var flow := ApplicationFlow.new()
	flow.set("_ruleset_owner", ruleset)
	flow.set("_runtime_owner", runtime)
	flow.set("_combat_owner", combat)
	flow.set("_composition_ready", true)
	var projection_forwarder := Callable(flow, "_on_runtime_state_changed")
	if not runtime.is_connected("state_changed", projection_forwarder):
		runtime.connect("state_changed", projection_forwarder)
	return {
		"host": host,
		"flow": flow,
		"runtime": runtime,
		"ruleset": ruleset,
		"combat": combat,
		"bound": bound,
	}


static func _runtime_fixture(
	tree: SceneTree,
	combat: Node
) -> Dictionary:
	var host := Node.new()
	host.name = "V075CleanupTestHost"
	tree.root.add_child(host)
	var runtime := RuntimeOwner.new()
	host.add_child(runtime)
	host.add_child(combat)
	var bound := runtime.call("bind_combat_owner", combat) as Dictionary
	return {
		"host": host,
		"runtime": runtime,
		"combat": combat,
		"bound": bound,
	}


static func _start_flow(fixture: Dictionary) -> Dictionary:
	return (fixture.get("flow") as Node).call(
		"_start_new_game",
		PARAMETERS.duplicate(true)
	) as Dictionary


static func _start_runtime(runtime: Node) -> Dictionary:
	return runtime.call(
		"start_new_game",
		4,
		900626424,
		false,
		false,
		{
			"map_seed": 900626424,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	) as Dictionary


static func _frozen_world_snapshot(fixture: Dictionary) -> Dictionary:
	var flow := fixture.get("flow") as Node
	var runtime := fixture.get("runtime") as Node
	var ruleset := fixture.get("ruleset") as Node
	var combat := fixture.get("combat") as Node
	var telemetry := runtime.get("_combat_telemetry_bridge") as Object
	var presentation := runtime.call(
		"combat_presentation_consumer"
	) as Node
	var projection_adapter := runtime.get(
		"_combat_projection_adapter"
	) as Object
	var ai_adapter := runtime.get("_combat_ai_adapter") as Object
	var player_snapshots: Dictionary = {}
	for player_id_variant in runtime.call("player_ids") as Array:
		var player_id := str(player_id_variant)
		player_snapshots[player_id] = (
			runtime.call("player_snapshot", player_id) as Dictionary
		).duplicate(true)
	var runtime_debug := (
		runtime.call("debug_snapshot") as Dictionary
	).duplicate(true)
	runtime_debug.erase("canonical_player_projection_count")
	return {
		"session_sequence": int(flow.get("_session_sequence")),
		"flow_transaction": {
			"in_progress": bool(
				flow.get("_new_game_transaction_in_progress")
			),
			"stage": str(flow.get("_new_game_transaction_stage")),
			"last_stage": str(
				flow.get("_last_new_game_transaction_stage")
			),
			"reentry_rejection_count": int(
				flow.get("_new_game_reentry_rejection_count")
			),
			"publication_count": int(
				flow.get("_new_game_publication_count")
			),
			"rollback_count": int(
				flow.get("_new_game_rollback_count")
			),
			"last_receipt": (
				flow.get("_last_receipt") as Dictionary
			).duplicate(true),
		},
		"ruleset": (
			ruleset.call("identity_snapshot") as Dictionary
		).duplicate(true),
		"runtime": runtime_debug,
		"combat": (
			combat.call("debug_snapshot") as Dictionary
		).duplicate(true),
		"player_snapshots": player_snapshots,
		"combat_owner_instance_id": combat.get_instance_id(),
		"telemetry_instance_id": (
			telemetry.get_instance_id()
			if is_instance_valid(telemetry)
			else 0
		),
		"presentation_instance_id": (
			presentation.get_instance_id()
			if is_instance_valid(presentation)
			else 0
		),
		"projection_adapter_instance_id": (
			projection_adapter.get_instance_id()
			if is_instance_valid(projection_adapter)
			else 0
		),
		"ai_adapter_instance_id": (
			ai_adapter.get_instance_id()
			if is_instance_valid(ai_adapter)
			else 0
		),
		"match_started_connection_count": (
			runtime.get_signal_connection_list("match_started").size()
		),
		"state_changed_connection_count": (
			runtime.get_signal_connection_list("state_changed").size()
		),
		"runtime_fault_connection_count": (
			runtime.get_signal_connection_list("runtime_fault").size()
		),
		"ruleset_signal_connection_count": (
			ruleset.get_signal_connection_list("ruleset_activated").size()
		),
		"telemetry_debug": (
			telemetry.call("debug_snapshot") as Dictionary
			if (
				is_instance_valid(telemetry)
				and telemetry.has_method("debug_snapshot")
			)
			else {}
		),
		"presentation_debug": (
			presentation.call("debug_snapshot") as Dictionary
			if (
				is_instance_valid(presentation)
				and presentation.has_method("debug_snapshot")
			)
			else {}
		),
	}


static func _publication_stage_snapshot(fixture: Dictionary) -> Dictionary:
	var flow := fixture.get("flow") as Node
	var runtime := fixture.get("runtime") as Node
	var ruleset := fixture.get("ruleset") as Node
	var combat := fixture.get("combat") as Node
	var ruleset_identity := ruleset.call("identity_snapshot") as Dictionary
	var ruleset_debug := ruleset.call("debug_snapshot") as Dictionary
	var runtime_debug := runtime.call("debug_snapshot") as Dictionary
	var combat_debug := combat.call("debug_snapshot") as Dictionary
	return {
		"flow_in_progress": bool(
			flow.get("_new_game_transaction_in_progress")
		),
		"flow_stage": str(flow.get("_new_game_transaction_stage")),
		"session_sequence": int(flow.get("_session_sequence")),
		"ruleset_activation_count": int(
			ruleset_identity.get("activation_count", -1)
		),
		"ruleset_last_session_id": str(
			ruleset_identity.get("last_session_id", "")
		),
		"ruleset_pending_rollback": bool(
			ruleset_identity.get(
				"pending_initialization_rollback",
				true
			)
		),
		"ruleset_stage": str(
			ruleset_debug.get("activation_transaction_stage", "")
		),
		"ruleset_publication_in_progress": bool(
			ruleset_debug.get(
				"activation_publication_in_progress",
				false
			)
		),
		"ruleset_publication_finalized": bool(
			ruleset_debug.get(
				"activation_publication_finalized",
				false
			)
		),
		"runtime_stage": str(
			runtime_debug.get("new_game_transaction_stage", "")
		),
		"runtime_in_progress": bool(
			runtime_debug.get(
				"new_game_transaction_in_progress",
				false
			)
		),
		"runtime_pending_rollback": bool(
			runtime_debug.get(
				"pending_initialization_rollback",
				true
			)
		),
		"runtime_combat_owner_count": int(
			runtime_debug.get("combat_runtime_owner_count", -1)
		),
		"runtime_connected_domains": int(
			runtime_debug.get("connected_domain_count", -1)
		),
		"runtime_cutover_domains": int(
			runtime_debug.get("cutover_domain_count", -1)
		),
		"combat_initialized": bool(
			combat_debug.get("initialized", false)
		),
		"combat_phase": str(combat_debug.get("phase", "")),
	}


static func _fully_committed(
	fixture: Dictionary,
	signal_phase: String
) -> bool:
	var flow := fixture.get("flow") as Node
	var runtime := fixture.get("runtime") as Node
	var ruleset := fixture.get("ruleset") as Node
	var combat := fixture.get("combat") as Node
	var ruleset_identity := ruleset.call("identity_snapshot") as Dictionary
	var ruleset_debug := ruleset.call("debug_snapshot") as Dictionary
	var runtime_debug := runtime.call("debug_snapshot") as Dictionary
	var combat_debug := combat.call("debug_snapshot") as Dictionary
	var expected_flow_stage := (
		"publish_ruleset_signal"
		if signal_phase == "ruleset"
		else "publish_runtime_signals"
	)
	var expected_runtime_stage := (
		"published_waiting_completion"
		if signal_phase == "ruleset"
		else "publishing"
	)
	return (
		signal_phase in ["runtime", "ruleset"]
		and bool(flow.get("_new_game_transaction_in_progress"))
		and str(flow.get("_new_game_transaction_stage"))
			== expected_flow_stage
		and int(flow.get("_session_sequence")) == 1
		and int(ruleset_identity.get("activation_count", 0)) == 1
		and str(ruleset_identity.get("last_session_id", ""))
			== "session.v075.sample.000001"
		and not bool(ruleset_identity.get(
			"pending_initialization_rollback",
			true
		))
		and str(ruleset_debug.get(
			"activation_transaction_stage",
			""
		)) == "idle"
		and bool(ruleset_debug.get(
			"activation_publication_in_progress",
			false
		))
		and bool(ruleset_debug.get(
			"activation_publication_finalized",
			false
		)) == (signal_phase == "runtime")
		and str(runtime_debug.get("new_game_transaction_stage", ""))
			== expected_runtime_stage
		and bool(runtime_debug.get(
			"new_game_transaction_in_progress",
			false
		))
		and not bool(runtime_debug.get(
			"pending_initialization_rollback",
			true
		))
		and int(runtime_debug.get("combat_runtime_owner_count", 0)) == 1
		and int(runtime_debug.get("connected_domain_count", 0))
			== int(runtime_debug.get("cutover_domain_count", -1))
		and bool(combat_debug.get("initialized", false))
		and str(combat_debug.get("phase", "")) == "batch_active"
	)


static func _rolled_back_to_idle(fixture: Dictionary) -> bool:
	var flow := fixture.get("flow") as Node
	var runtime := fixture.get("runtime") as Node
	var ruleset := fixture.get("ruleset") as Node
	var combat := fixture.get("combat") as Node
	var ruleset_identity := ruleset.call("identity_snapshot") as Dictionary
	var combat_debug := combat.call("debug_snapshot") as Dictionary
	return (
		int(flow.get("_session_sequence")) == 0
		and int(ruleset_identity.get("activation_count", -1)) == 0
		and str(ruleset_identity.get("last_session_id", "")).is_empty()
		and str(ruleset_identity.get("activation_transaction_stage", ""))
			== "idle"
		and (runtime.call("player_ids") as Array).is_empty()
		and (runtime.call(
			"player_snapshot",
			"player.local"
		) as Dictionary).is_empty()
		and not bool(runtime.get("_combat_initialized"))
		and not bool(combat_debug.get("initialized", true))
		and _all_residual_counts_zero(
			combat_debug.get(
				"failed_initialization_residuals",
				{}
			) as Dictionary
		)
	)


static func _all_residual_counts_zero(source: Dictionary) -> bool:
	for field_name in [
		"remaining_binding_count",
		"remaining_subscription_count",
		"remaining_private_skill_count",
		"remaining_instant_sequence_count",
		"remaining_military_mission_count",
		"remaining_receipt_count",
		"remaining_ai_binding_count",
		"remaining_player_projection_binding_count",
		"remaining_telemetry_binding_count",
		"remaining_state_entry_count",
	]:
		if (
			not source.has(field_name)
			or typeof(source.get(field_name)) != TYPE_INT
			or int(source.get(field_name)) != 0
		):
			return false
	return true


static func _destroy_fixture(fixture: Dictionary) -> void:
	var flow := fixture.get("flow") as Node
	if is_instance_valid(flow):
		flow.free()
	var host := fixture.get("host") as Node
	if is_instance_valid(host):
		host.free()


static func _expect(
	state: Dictionary,
	condition: bool,
	label: String
) -> void:
	state["checks"] = int(state.get("checks", 0)) + 1
	if not condition:
		(state.get("failures", []) as Array).append(label)