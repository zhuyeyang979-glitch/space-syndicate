extends Node
class_name V075ApplicationFlow

signal projection_changed(snapshot: Dictionary)
signal receipt_ready(receipt: Dictionary)
signal owner_private_receipt_ready(receipt: Dictionary)
signal final_settlement_presented(settlement: Dictionary)
signal runtime_fault_presented(receipt: Dictionary)
signal public_resolution_ready(receipt: Dictionary)
signal playtest_observation_ready(receipt: Dictionary)

const RULESET_ID := "v0.7.5"
const SAMPLE_MODE_ID := "NEW_V075_GAME"
const DEFAULT_SEED := 900626424
const CUTOVER_DOMAIN_COUNT := 29
const PRIVATE_SKILL_INTENT_KIND := "combat.monster_private_skill.request"
const V076_PRODUCTION_MILITARY_INTENT_KIND := "combat.military_mission.select"
const V076_PRODUCTION_MILITARY_RECEIPT_SCHEMA := (
	"V076OwnerPrivateMilitaryApplicationReceiptV1"
)
const ProfileCatalog := preload(
	"res://scripts/v076/military/v076_military_unit_profile_catalog_v1.gd"
)

@onready var _ruleset_owner: Node = %V075RulesetRuntimeOwner
@onready var _runtime_owner: Node = %V075RuntimeOwner
@onready var _combat_owner: Node = %V075CombatRuntimeOwner
@onready var _combat_telemetry: Node = %V075CombatTelemetryService
@onready var _v076_kernel: Node = get_node_or_null("V076DeterministicKernel")
@onready var _v076_eta_owner: Node = get_node_or_null(
	"V076MilitaryPhysicalEtaOwnerV1"
)
@onready var _v076_production_adapter: Node = get_node_or_null(
	"V076V075ProductionAdapterV1"
)
@onready var _v076_private_direct_action_owner: Node = get_node_or_null(
	"V076PrivateDirectActionInputOwnerV1"
)

var _intent_sequence := 0
var _session_sequence := 0
var _last_receipt: Dictionary = {}
var _composition_ready := false
var _private_skill_issue_count := 0
var _private_skill_submit_count := 0
var _private_skill_owner_receipt_count := 0
var _new_game_transaction_in_progress := false
var _new_game_transaction_stage := "idle"
var _last_new_game_transaction_stage := "idle"
var _new_game_reentry_rejection_count := 0
var _new_game_publication_count := 0
var _new_game_rollback_count := 0
var _last_published_session_id := ""
var _v076_production_required := false
var _v076_production_ready := false
var _v076_production_seed := 0
var _v076_production_configuration_failure_count := 0
var _v076_private_military_receipt_count := 0


func _ready() -> void:
	_v076_production_required = (
		_v076_kernel != null
		or _v076_eta_owner != null
		or _v076_production_adapter != null
		or _v076_private_direct_action_owner != null
	)
	var telemetry_binding := _runtime_owner.call(
		"bind_combat_telemetry_service",
		_combat_telemetry
	) as Dictionary
	var combat_binding := _runtime_owner.call(
		"bind_combat_owner",
		_combat_owner
	) as Dictionary
	if (
		not bool(telemetry_binding.get("accepted", false))
		or not bool(combat_binding.get("accepted", false))
	):
		push_error("V075 runtime composition binding failed")
		return
	if _v076_production_required:
		if _v076_production_adapter == null \
				or not _v076_production_adapter.has_method("bind_runtime_owner"):
			_v076_production_configuration_failure_count += 1
			push_error("V076 production adapter binding surface missing")
			return
		var adapter_binding := _v076_production_adapter.call(
			"bind_runtime_owner",
			_runtime_owner
		) as Dictionary
		if not bool(adapter_binding.get("accepted", false)):
			_v076_production_configuration_failure_count += 1
			push_error("V076 production adapter binding failed")
			return
	_runtime_owner.state_changed.connect(_on_runtime_state_changed)
	_runtime_owner.final_settlement_committed.connect(
		_on_final_settlement_committed
	)
	_runtime_owner.runtime_fault.connect(_on_runtime_fault)
	_runtime_owner.resolution_presented.connect(
		_on_public_resolution_presented
	)
	_runtime_owner.playtest_observation_ready.connect(
		_on_playtest_observation_ready
	)
	_composition_ready = true


func submit_intent(intent: Dictionary) -> Dictionary:
	var intent_id := str(intent.get("intent_id", "")).strip_edges()
	var intent_kind := str(intent.get("intent_kind", "")).strip_edges()
	var parameters := intent.get("parameters", {}) as Dictionary
	if intent_id.is_empty() or intent_kind.is_empty():
		return _publish_intent_rejection(
			intent_id,
			intent_kind,
			parameters,
			"typed_intent_identity_invalid"
		)
	if not _composition_ready:
		return _publish_intent_rejection(
			intent_id,
			intent_kind,
			parameters,
			"v075_runtime_composition_not_ready"
		)
	var actor_id := str(_runtime_owner.call("local_player_id"))
	var result: Dictionary
	match intent_kind:
		"map.preview":
			result = _preview_map(parameters)
		"new_game.start":
			result = _start_new_game(parameters)
		"track.acquire":
			result = _runtime_owner.call(
				"acquire_track_item",
				actor_id,
				str(parameters.get("source_instance_id", ""))
			) as Dictionary
		"track.set_stance":
			result = _runtime_owner.call(
				"set_track_stance",
				actor_id,
				str(parameters.get("increase_color", "")),
				str(parameters.get("decrease_color", ""))
			) as Dictionary
		"card.queue":
			result = _runtime_owner.call(
				"queue_card_action",
				actor_id,
				str(parameters.get("card_instance_id", "")),
				str(parameters.get("target_slot_id", "")),
				parameters.get("target_binding", {}) as Dictionary
			) as Dictionary
		"queue.reorder":
			result = _runtime_owner.call(
				"reorder_queued_action",
				actor_id,
				int(parameters.get("from_index", -1)),
				int(parameters.get("to_index", -1))
			) as Dictionary
		"queue.remove":
			result = _runtime_owner.call(
				"remove_queued_action",
				actor_id,
				str(parameters.get("action_id", ""))
			) as Dictionary
		"submission.lock":
			result = _runtime_owner.call(
				"lock_player_submission",
				actor_id
			) as Dictionary
		"merge.normal":
			result = _runtime_owner.call(
				"merge_normal_pair",
				actor_id,
				str(parameters.get("left_instance_id", "")),
				str(parameters.get("right_instance_id", ""))
			) as Dictionary
		"maintenance.finish":
			result = _runtime_owner.call(
				"finish_maintenance",
				actor_id
			) as Dictionary
		"sample.accelerate":
			result = _runtime_owner.call(
				"run_accelerated_until_settled",
				int(parameters.get("max_steps", 2000))
			) as Dictionary
		PRIVATE_SKILL_INTENT_KIND:
			_private_skill_submit_count += 1
			result = _runtime_owner.call(
				"request_private_monster_skill",
				actor_id,
				parameters
			) as Dictionary
		"combat.military_mission.select":
			result = _submit_v076_production_military_action(
				intent_id,
				actor_id,
				parameters
			)
		"persistence.save":
			result = _ruleset_owner.call(
				"request_save",
				intent_id
			) as Dictionary
		"persistence.continue":
			result = _ruleset_owner.call(
				"request_load",
				intent_id
			) as Dictionary
		_:
			result = _reject(
				intent_id,
				intent_kind,
				"typed_intent_kind_unsupported"
			)
	if intent_kind == PRIVATE_SKILL_INTENT_KIND:
		return _publish_owner_private_receipt(
			_bind_owner_private_skill_receipt(
				intent_id,
				intent_kind,
				actor_id,
				parameters,
				result
			)
		)
	if intent_kind == V076_PRODUCTION_MILITARY_INTENT_KIND:
		return _publish_owner_private_military_receipt(
			intent_id,
			actor_id,
			result
		)
	return _publish_receipt(_bind_receipt(intent_id, intent_kind, result))


func _submit_v076_production_military_action(
	intent_id: String,
	actor_id: String,
	parameters: Dictionary
) -> Dictionary:
	if not _v076_production_required or not _v076_production_ready:
		return _reject_action_result(
			"v076_production_military_direct_action_not_ready"
		)
	var bundle_result := _runtime_owner.call(
		"authorize_v076_production_military_bundle",
		actor_id,
		parameters
	) as Dictionary
	if not bool(bundle_result.get("accepted", false)):
		return _reject_action_result(str(bundle_result.get(
			"reason_code",
			"v076_production_military_authorization_rejected"
		)))
	var bundle := bundle_result.get("bundle", {}) as Dictionary
	var submission_id := "v076.production.military.%s" % intent_id
	var request_result := _runtime_owner.call(
		"build_v076_production_military_request",
		actor_id,
		submission_id,
		parameters,
		bundle
	) as Dictionary
	if not bool(request_result.get("accepted", false)):
		return _reject_action_result(str(request_result.get(
			"reason",
			"v076_production_military_request_rejected"
		)))
	var submitted := _v076_private_direct_action_owner.call(
		"submit_private_military_direct_action",
		bundle,
		request_result.get("request", {}) as Dictionary
	) as Dictionary
	if not bool(submitted.get("accepted", false)):
		return _reject_action_result(str(submitted.get(
			"reason",
			"v076_production_military_submission_rejected"
		)))
	var result := submitted.duplicate(true)
	result["reason_code"] = "v076_production_military_direct_action_submitted"
	result["submission_id"] = submission_id
	return result


func _reject_action_result(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}


func issue_intent(intent_kind: String, parameters: Dictionary = {}) -> Dictionary:
	_intent_sequence += 1
	if intent_kind == PRIVATE_SKILL_INTENT_KIND:
		_private_skill_issue_count += 1
	return {
		"schema": "V075ApplicationIntentV1",
		"intent_id": "intent.v075.sample.%06d" % _intent_sequence,
		"intent_kind": intent_kind,
		"ruleset_id": RULESET_ID,
		"parameters": parameters.duplicate(true),
	}


func _ensure_v076_production_configuration(seed_value: int) -> Dictionary:
	if not _v076_production_required:
		return {"accepted": true, "reason_code": "v076_production_not_present"}
	if _v076_production_ready:
		if seed_value != _v076_production_seed:
			return _reject_action_result(
				"v076_production_kernel_seed_reconfiguration_forbidden"
			)
		return {"accepted": true, "reason_code": "v076_production_ready"}
	if (
		_v076_kernel == null
		or _v076_eta_owner == null
		or _v076_private_direct_action_owner == null
		or _v076_production_adapter == null
	):
		_v076_production_configuration_failure_count += 1
		return _reject_action_result("v076_production_dependency_missing")
	var kernel_config := _v076_kernel.call("configure", seed_value) as Dictionary
	if not bool(kernel_config.get("accepted", false)):
		_v076_production_configuration_failure_count += 1
		return _reject_action_result(str(kernel_config.get(
			"reason",
			"v076_production_kernel_configuration_rejected"
		)))
	var profile_authority := ProfileCatalog.new()
	var eta_config := _v076_eta_owner.call(
		"configure",
		profile_authority
	) as Dictionary
	if not bool(eta_config.get("accepted", false)):
		_v076_production_configuration_failure_count += 1
		return _reject_action_result(str(eta_config.get(
			"reason",
			"v076_production_eta_configuration_rejected"
		)))
	var direct_config := _v076_private_direct_action_owner.call(
		"configure_dependencies",
		_v076_kernel,
		_v076_production_adapter,
		_v076_production_adapter,
		_v076_production_adapter,
		_v076_production_adapter,
		profile_authority,
		_v076_eta_owner,
		_runtime_owner,
		_v076_production_adapter
	) as Dictionary
	if not bool(direct_config.get("accepted", false)):
		_v076_production_configuration_failure_count += 1
		return _reject_action_result(str(direct_config.get(
			"reason",
			"v076_production_direct_action_configuration_rejected"
		)))
	_v076_production_seed = seed_value
	_v076_production_ready = true
	return {
		"accepted": true,
		"reason_code": "v076_production_configuration_ready",
		"seed": seed_value,
		"kernel_owner": "V076DeterministicKernel",
		"direct_action_owner": "V076PrivateDirectActionInputOwnerV1",
	}


func _process(delta: float) -> void:
	if not _v076_production_ready:
		return
	var elapsed_us := maxi(0, int(round(delta * 1_000_000.0)))
	if elapsed_us <= 0:
		return
	var advanced := _v076_kernel.call(
		"advance_elapsed_us",
		elapsed_us
	) as Dictionary
	if not bool(advanced.get("accepted", false)):
		push_error("V076 production kernel advance failed")
		return
	if int(advanced.get("advanced_tick_count", 0)) <= 0:
		return
	var intake := _v076_private_direct_action_owner.call(
		"settle_ready_private_actions"
	) as Dictionary
	if not bool(intake.get("accepted", false)):
		push_error("V076 private intake settlement failed")
		return
	for receipt_variant in intake.get("receipts", []) as Array:
		_publish_owner_private_military_receipt(
			str((receipt_variant as Dictionary).get("submission_id", "")),
			str(_runtime_owner.call("local_player_id")),
			receipt_variant as Dictionary
		)
	for submission_id in _v076_private_direct_action_owner.call(
		"withdrawal_ready_submission_ids"
	) as Array:
		var settled := _v076_private_direct_action_owner.call(
			"settle_completed_submission",
			str(submission_id)
		) as Dictionary
		if not bool(settled.get("accepted", false)):
			push_error("V076 private military completion settlement failed")
			continue
		_publish_owner_private_military_receipt(
			str(submission_id),
			str(_runtime_owner.call("local_player_id")),
			settled
		)


func local_snapshot() -> Dictionary:
	var actor_id := str(_runtime_owner.call("local_player_id"))
	return (
		_runtime_owner.call("player_snapshot", actor_id) as Dictionary
		if not actor_id.is_empty()
		else {}
	)


func planet_map_view_payload(
	selected_card_instance_id := "",
	selected_region_id := ""
) -> Dictionary:
	return _runtime_owner.call(
		"planet_map_view_payload",
		_runtime_owner.call("local_player_id"),
		selected_card_instance_id,
		selected_region_id
	) as Dictionary


func region_popup(region_id: String) -> Dictionary:
	return _runtime_owner.call("region_popup", region_id) as Dictionary


func resolve_map_target(
	card_instance_id: String,
	region_id: String,
	facility_type: String,
	industry_id: String,
	action_mode: String
) -> Dictionary:
	return _runtime_owner.call(
		"resolve_map_target",
		card_instance_id,
		region_id,
		facility_type,
		industry_id,
		action_mode
	) as Dictionary


func identity_snapshot() -> Dictionary:
	return _ruleset_owner.call("identity_snapshot") as Dictionary


func capability_snapshot() -> Dictionary:
	return _ruleset_owner.call("capability_snapshot") as Dictionary


func combat_presentation_consumer() -> Node:
	return _runtime_owner.call("combat_presentation_consumer") as Node


func debug_snapshot() -> Dictionary:
	var runtime_debug := _runtime_owner.call("debug_snapshot") as Dictionary
	var telemetry_debug := _combat_telemetry.call(
		"debug_snapshot"
	) as Dictionary
	return {
		"schema": "V075RuntimeCompositionDebugV1",
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"current_production_runtime_ruleset": RULESET_ID,
		"composition_ready": _composition_ready,
		"ruleset_owner_count": 1,
		"gameplay_owner_count": 1,
		"combat_runtime_owner_count": int(
			runtime_debug.get("combat_runtime_owner_count", 0)
		),
		"combat_state_writer_count": int(
			runtime_debug.get("combat_state_writer_count", 0)
		),
		"combat_telemetry_service_count": 1,
		"combat_telemetry_gameplay_owner_count": int(
			telemetry_debug.get("gameplay_owner_count", -1)
		),
		"v06_production_rule_owner_count": 0,
		"old_monster_controller_production_reachable_count": 0,
		"old_military_controller_production_reachable_count": 0,
		"combat_dual_write_count": 0,
		"combat_legacy_fallback_count": 0,
		"mixed_ruleset_state_count": 0,
		"v076_production_required": _v076_production_required,
		"v076_production_ready": _v076_production_ready,
		"v076_kernel_owner_count": 1 if _v076_kernel != null else 0,
		"v076_private_direct_action_owner_count": (
			1 if _v076_private_direct_action_owner != null else 0
		),
		"v076_production_adapter_count": (
			1 if _v076_production_adapter != null else 0
		),
		"v076_military_eta_owner_count": 1 if _v076_eta_owner != null else 0,
		"v076_production_configuration_failure_count": (
			_v076_production_configuration_failure_count
		),
		"v076_private_military_receipt_count": (
			_v076_private_military_receipt_count
		),
		"v076_public_batch_entry_count": 0,
		"v076_shared_sushi_track_resolution_count": 0,
		"save_adapter_connected": false,
		"save_resume_enabled": false,
		"cutover_domain_count": CUTOVER_DOMAIN_COUNT,
		"connected_domain_count": int(
			runtime_debug.get("connected_domain_count", 0)
		),
		"ruleset": _ruleset_owner.call("debug_snapshot"),
		"runtime": runtime_debug,
		"combat_telemetry": telemetry_debug,
		"last_receipt": _last_receipt.duplicate(true),
		"private_skill_issue_count": _private_skill_issue_count,
		"private_skill_submit_count": _private_skill_submit_count,
		"private_skill_owner_receipt_count": (
			_private_skill_owner_receipt_count
		),
		"session_sequence": _session_sequence,
		"new_game_transaction_in_progress": (
			_new_game_transaction_in_progress
		),
		"new_game_transaction_stage": _new_game_transaction_stage,
		"last_new_game_transaction_stage": (
			_last_new_game_transaction_stage
		),
		"pending_initialization_rollback": (
			_new_game_transaction_stage in [
				"prepare",
				"owner_initialize",
				"ruleset_session_commit",
				"owner_activate",
				"pre_publication",
				"finalize_runtime_publication",
				"finalize_ruleset_publication",
				"rollback",
			]
		),
		"new_game_reentry_rejection_count": (
			_new_game_reentry_rejection_count
		),
		"new_game_publication_count": _new_game_publication_count,
		"last_published_session_id": _last_published_session_id,
		"new_game_rollback_count": _new_game_rollback_count,
	}


func _preview_map(parameters: Dictionary) -> Dictionary:
	var normalized := _ruleset_owner.call(
		"normalize_map_request",
		_map_request_from_parameters(parameters)
	) as Dictionary
	if not bool(normalized.get("accepted", false)):
		return normalized
	var map_request := normalized.get("request", {}) as Dictionary
	var preview := _runtime_owner.call("preview_map", map_request) as Dictionary
	if not bool(preview.get("accepted", false)):
		return preview
	return {
		"accepted": true,
		"reason_code": "v075_map_preview_generated",
		"ruleset_id": RULESET_ID,
		"map_request": map_request.duplicate(true),
		"map_genesis_receipt": (
			preview.get("map_genesis_receipt", {}) as Dictionary
		).duplicate(true),
	}


func _start_new_game(parameters: Dictionary) -> Dictionary:
	if _new_game_transaction_in_progress:
		_new_game_reentry_rejection_count += 1
		return {
			"accepted": false,
			"reason_code": "v075_new_game_transaction_in_progress",
			"ruleset_id": RULESET_ID,
		}
	var runtime_idle := _runtime_owner.call(
		"validate_new_game_initialization_idle"
	) as Dictionary
	if not bool(runtime_idle.get("accepted", false)):
		return runtime_idle
	_new_game_transaction_in_progress = true
	_new_game_transaction_stage = "prepare"
	var result := _execute_new_game_transaction(parameters)
	_last_new_game_transaction_stage = (
		"complete"
		if bool(result.get("accepted", false))
		else _new_game_transaction_stage
	)
	_new_game_transaction_in_progress = false
	_new_game_transaction_stage = "idle"
	return result


func _new_game_publication_stage_authorized(required_stage: String) -> bool:
	return (
		_new_game_transaction_in_progress
		and required_stage == _new_game_transaction_stage
		and required_stage in [
			"publish_runtime_signals",
			"publish_ruleset_signal",
			"complete_runtime_publication",
		]
	)

func _execute_new_game_transaction(parameters: Dictionary) -> Dictionary:
	var player_count := int(parameters.get("player_count", 4))
	var seed_value := int(parameters.get("seed", DEFAULT_SEED))
	var v076_configuration := _ensure_v076_production_configuration(seed_value)
	if not bool(v076_configuration.get("accepted", false)):
		_new_game_transaction_stage = "v076_configuration_failed"
		return v076_configuration
	var publication_stage_authority := Callable(
		self,
		"_new_game_publication_stage_authorized"
	)
	var normalized := _ruleset_owner.call(
		"normalize_map_request",
		_map_request_from_parameters(parameters)
	) as Dictionary
	if not bool(normalized.get("accepted", false)):
		_new_game_transaction_stage = "validation_failed"
		return normalized
	var map_request := normalized.get("request", {}) as Dictionary
	var previous_session_sequence := _session_sequence
	var next_session_sequence := previous_session_sequence + 1
	var session_id := "session.v075.sample.%06d" % next_session_sequence
	var ruleset_prepared := _ruleset_owner.call(
		"prepare_new_game_activation",
		session_id,
		player_count,
		1,
		map_request,
		publication_stage_authority
	) as Dictionary
	if not bool(ruleset_prepared.get("accepted", false)):
		_new_game_transaction_stage = "ruleset_prepare_failed"
		return ruleset_prepared
	var ruleset_transaction_id := str(ruleset_prepared.get(
		"transaction_id",
		""
	))
	_new_game_transaction_stage = "owner_initialize"
	var runtime_prepared := _runtime_owner.call(
		"prepare_new_game",
		player_count,
		seed_value,
		false,
		false,
		map_request,
		false,
		publication_stage_authority
	) as Dictionary
	if not bool(runtime_prepared.get("accepted", false)):
		var cancelled := _ruleset_owner.call(
			"rollback_new_game_activation",
			ruleset_transaction_id
		) as Dictionary
		_new_game_transaction_stage = "owner_initialize_failed"
		if not bool(cancelled.get("accepted", false)):
			return _application_transaction_rollback_failure(
				runtime_prepared,
				cancelled,
				{}
			)
		return _public_failure_projection(runtime_prepared)
	var runtime_transaction_id := str(runtime_prepared.get(
		"transaction_id",
		""
	))
	_new_game_transaction_stage = "ruleset_session_commit"
	var ruleset_committed := _ruleset_owner.call(
		"commit_prepared_new_game",
		ruleset_transaction_id
	) as Dictionary
	if not bool(ruleset_committed.get("accepted", false)):
		return _rollback_prepared_new_game(
			runtime_transaction_id,
			ruleset_transaction_id,
			previous_session_sequence,
			ruleset_committed
		)
	_session_sequence = next_session_sequence
	_new_game_transaction_stage = "owner_activate"
	var runtime_activated := _runtime_owner.call(
		"activate_prepared_new_game",
		runtime_transaction_id
	) as Dictionary
	if not bool(runtime_activated.get("accepted", false)):
		return _rollback_prepared_new_game(
			runtime_transaction_id,
			ruleset_transaction_id,
			previous_session_sequence,
			runtime_activated
		)
	_new_game_transaction_stage = "pre_publication"
	var runtime_sealed := _runtime_owner.call(
		"seal_prepared_new_game_publication",
		runtime_transaction_id
	) as Dictionary
	if not bool(runtime_sealed.get("accepted", false)):
		return _rollback_prepared_new_game(
			runtime_transaction_id,
			ruleset_transaction_id,
			previous_session_sequence,
			runtime_sealed
		)
	var ruleset_sealed := _ruleset_owner.call(
		"seal_committed_new_game_publication",
		ruleset_transaction_id
	) as Dictionary
	if not bool(ruleset_sealed.get("accepted", false)):
		return _rollback_prepared_new_game(
			runtime_transaction_id,
			ruleset_transaction_id,
			previous_session_sequence,
			ruleset_sealed
		)
	_new_game_transaction_stage = "finalize_runtime_publication"
	var started := _runtime_owner.call(
		"finalize_prepared_new_game_publication",
		runtime_transaction_id
	) as Dictionary
	if not bool(started.get("accepted", false)):
		return _rollback_prepared_new_game(
			runtime_transaction_id,
			ruleset_transaction_id,
			previous_session_sequence,
			started
		)
	_new_game_transaction_stage = "finalize_ruleset_publication"
	var activation := _ruleset_owner.call(
		"finalize_committed_new_game",
		ruleset_transaction_id
	) as Dictionary
	if not bool(activation.get("accepted", false)):
		return _rollback_prepared_new_game(
			runtime_transaction_id,
			ruleset_transaction_id,
			previous_session_sequence,
			activation
		)
	_new_game_transaction_stage = "publish_runtime_signals"
	_runtime_owner.call(
		"emit_finalized_new_game_signals",
		runtime_transaction_id
	)
	_new_game_transaction_stage = "publish_ruleset_signal"
	_ruleset_owner.call(
		"emit_finalized_new_game",
		ruleset_transaction_id
	)
	_new_game_transaction_stage = "complete_runtime_publication"
	_runtime_owner.call(
		"complete_finalized_new_game_publication",
		runtime_transaction_id
	)
	_new_game_publication_count += 1
	_last_published_session_id = session_id
	_new_game_transaction_stage = "complete"
	return {
		"accepted": true,
		"reason_code": "v075_new_game_application_flow_committed",
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"player_count": player_count,
		"local_human_count": 1,
		"ai_player_count": player_count - 1,
		"session_id": session_id,
		"match_id": str(started.get("match_id", "")),
		"seed": seed_value,
		"map_seed": int(map_request.get("map_seed", 0)),
		"region_count": int(map_request.get("region_count", 0)),
		"geography_complexity": str(
			map_request.get("geography_complexity", "")
		),
		"land_ocean_profile": str(
			map_request.get("land_ocean_profile", "")
		),
		"map_fingerprint": str(started.get("map_fingerprint", "")),
		"combat_balance_profile_id": str(
			started.get("combat_balance_profile_id", "")
		),
		"combat_balance_profile_fingerprint": str(
			started.get("combat_balance_profile_fingerprint", "")
		),
		"runtime_signal_publication_count": int(started.get(
			"runtime_signal_publication_count",
			0
		)),
		"ruleset_signal_publication_count": int(activation.get(
			"ruleset_signal_publication_count",
			0
		)),
		"pending_initialization_rollback": false,
	}


func _rollback_prepared_new_game(
	runtime_transaction_id: String,
	ruleset_transaction_id: String,
	previous_session_sequence: int,
	primary_failure: Dictionary
) -> Dictionary:
	_new_game_transaction_stage = "rollback"
	_session_sequence = previous_session_sequence
	var ruleset_rollback := _ruleset_owner.call(
		"rollback_new_game_activation",
		ruleset_transaction_id
	) as Dictionary
	var runtime_rollback := _runtime_owner.call(
		"abort_prepared_new_game",
		runtime_transaction_id,
		primary_failure
	) as Dictionary
	_new_game_rollback_count += 1
	var rollback_reason_variant: Variant = runtime_rollback.get("reason_code")
	var rollback_reason_is_string := (
		typeof(rollback_reason_variant) == TYPE_STRING
	)
	var runtime_rollback_failed := (
		runtime_rollback.is_empty()
		or not rollback_reason_is_string
		or (
			str(rollback_reason_variant)
			in [
				"prepared_new_game_abort_transaction_invalid",
				"initialization_failed_and_cleanup_failed",
			]
		)
		or runtime_rollback.has("cleanup_failure")
	)
	if (
		not bool(ruleset_rollback.get("accepted", false))
		or runtime_rollback_failed
	):
		return _application_transaction_rollback_failure(
			primary_failure,
			ruleset_rollback,
			runtime_rollback
		)
	return _public_failure_projection(runtime_rollback)


func _application_transaction_rollback_failure(
	primary_failure: Dictionary,
	ruleset_rollback: Dictionary,
	runtime_rollback: Dictionary
) -> Dictionary:
	return {
		"schema": "V075ApplicationNewGameTransactionFailureV1",
		"accepted": false,
		"reason_code": "v075_new_game_transaction_rollback_failed",
		"primary_failure": _public_failure_projection(primary_failure),
		"ruleset_rollback": _public_failure_projection(ruleset_rollback),
		"runtime_rollback": _public_failure_projection(runtime_rollback),
	}


func _public_failure_field_has_safe_type(
	field_name: String,
	value: Variant
) -> bool:
	if field_name in [
		"schema",
		"reason_code",
		"ruleset_id",
		"failed_stage",
		"failed_cleanup_stage",
	]:
		return typeof(value) == TYPE_STRING
	if field_name in [
		"accepted",
		"already_clean",
		"cleanup_owned_state_only",
		"composition_binding_parity",
	]:
		return typeof(value) == TYPE_BOOL
	if field_name in [
		"cleanup_invocation_count",
		"external_state_mutation_count",
		"composition_object_binding_delta_count",
		"composition_ai_binding_delta_count",
		"composition_player_projection_delta_count",
		"composition_telemetry_delta_count",
		"composition_subscription_delta_count",
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
		return typeof(value) == TYPE_INT
	return false


func _public_failure_projection(source: Dictionary) -> Dictionary:
	var projection: Dictionary = {}
	for field_name in [
		"schema",
		"accepted",
		"reason_code",
		"ruleset_id",
		"failed_stage",
		"failed_cleanup_stage",
		"cleanup_invocation_count",
		"already_clean",
		"external_state_mutation_count",
		"cleanup_owned_state_only",
		"composition_binding_parity",
		"composition_object_binding_delta_count",
		"composition_ai_binding_delta_count",
		"composition_player_projection_delta_count",
		"composition_telemetry_delta_count",
		"composition_subscription_delta_count",
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
			source.has(field_name)
			and _public_failure_field_has_safe_type(
				field_name,
				source.get(field_name)
			)
		):
			projection[field_name] = source.get(field_name)
	for nested_field_name in [
		"primary_initialization_failure",
		"cleanup_failure",
		"detail",
		"cleanup",
	]:
		if (
			source.has(nested_field_name)
			and source.get(nested_field_name) is Dictionary
		):
			projection[nested_field_name] = _public_failure_projection(
				source.get(nested_field_name) as Dictionary
			)
	return projection


func _map_request_from_parameters(parameters: Dictionary) -> Dictionary:
	return {
		"map_seed": int(parameters.get(
			"map_seed",
			parameters.get("seed", DEFAULT_SEED)
		)),
		"region_count": int(parameters.get("region_count", 16)),
		"geography_complexity": str(
			parameters.get("geography_complexity", "STANDARD")
		),
		"land_ocean_profile": str(
			parameters.get("land_ocean_profile", "BALANCED")
		),
	}


func _bind_receipt(
	intent_id: String,
	intent_kind: String,
	result: Dictionary
) -> Dictionary:
	var receipt := result.duplicate(true)
	if not receipt.has("accepted") and receipt.has("success"):
		receipt["accepted"] = bool(receipt.get("success", false))
	receipt["schema"] = "V075ApplicationReceiptV1"
	receipt["intent_id"] = intent_id
	receipt["intent_kind"] = intent_kind
	receipt["ruleset_id"] = RULESET_ID
	return receipt


func _publish_receipt(receipt: Dictionary) -> Dictionary:
	_last_receipt = receipt.duplicate(true)
	receipt_ready.emit(receipt.duplicate(true))
	return receipt


func _publish_intent_rejection(
	intent_id: String,
	intent_kind: String,
	parameters: Dictionary,
	reason_code: String
) -> Dictionary:
	var rejection := _reject(intent_id, intent_kind, reason_code)
	if intent_kind == PRIVATE_SKILL_INTENT_KIND:
		return _publish_owner_private_receipt(
			_bind_owner_private_skill_receipt(
				intent_id,
				intent_kind,
				"",
				parameters,
				rejection
			)
		)
	return _publish_receipt(rejection)


func _bind_owner_private_skill_receipt(
	intent_id: String,
	intent_kind: String,
	actor_id: String,
	parameters: Dictionary,
	result: Dictionary
) -> Dictionary:
	var accepted := bool(result.get("accepted", false))
	return {
		"schema": "V075OwnerPrivateApplicationReceiptV1",
		"accepted": accepted,
		"reason_code": str(result.get(
			"reason_code",
			"private_skill_request_rejected"
		)),
		"event_kind": (
			"monster_private_skill_requested"
			if accepted
			else "monster_private_skill_request_rejected"
		),
		"combat_channel": "private_instant_serial",
		"receipt_scope": "owner_private",
		"request_status": "accepted" if accepted else "rejected",
		"owner_player_id": actor_id,
		"source_instance_id": str(parameters.get(
			"source_instance_id",
			""
		)),
		"skill_definition_id": str(parameters.get(
			"skill_definition_id",
			""
		)),
		"intent_id": intent_id,
		"intent_kind": intent_kind,
		"ruleset_id": RULESET_ID,
	}


func _publish_owner_private_receipt(receipt: Dictionary) -> Dictionary:
	_private_skill_owner_receipt_count += 1
	_last_receipt = {
		"schema": "V075ApplicationReceiptRedactionV1",
		"accepted": bool(receipt.get("accepted", false)),
		"receipt_scope": "owner_private_redacted",
		"ruleset_id": RULESET_ID,
	}
	owner_private_receipt_ready.emit(receipt.duplicate(true))
	return receipt


func _publish_owner_private_military_receipt(
	receipt_id: String,
	actor_id: String,
	result: Dictionary
) -> Dictionary:
	## Military acknowledgements share the established owner-private signal but
	## expose no card, target, route, asset, damage, or mission-lock payload on
	## the generic/public receipt projection.
	_v076_private_military_receipt_count += 1
	var accepted := bool(result.get("accepted", false))
	var private_receipt := {
		"schema": V076_PRODUCTION_MILITARY_RECEIPT_SCHEMA,
		"accepted": accepted,
		"reason_code": str(result.get(
			"reason_code",
			result.get(
				"reason",
				"v076_production_military_action_rejected"
			)
		)),
		"event_kind": (
			"military_direct_action_acknowledged"
			if accepted
			else "military_direct_action_rejected"
		),
		"receipt_scope": "owner_private",
		"request_status": "accepted" if accepted else "rejected",
		"owner_player_id": actor_id,
		"receipt_id": receipt_id,
		"ruleset_id": RULESET_ID,
	}
	_last_receipt = {
		"schema": "V075ApplicationReceiptRedactionV1",
		"accepted": accepted,
		"receipt_scope": "owner_private_redacted",
		"ruleset_id": RULESET_ID,
	}
	owner_private_receipt_ready.emit(private_receipt.duplicate(true))
	return private_receipt


func _reject(
	intent_id: String,
	intent_kind: String,
	reason_code: String
) -> Dictionary:
	return {
		"schema": "V075ApplicationReceiptV1",
		"accepted": false,
		"reason_code": reason_code,
		"intent_id": intent_id,
		"intent_kind": intent_kind,
		"ruleset_id": RULESET_ID,
	}


func _on_runtime_state_changed(snapshot: Dictionary) -> void:
	projection_changed.emit(snapshot.duplicate(true))


func _on_final_settlement_committed(settlement: Dictionary) -> void:
	final_settlement_presented.emit(settlement.duplicate(true))


func _on_runtime_fault(receipt: Dictionary) -> void:
	runtime_fault_presented.emit(receipt.duplicate(true))


func _on_public_resolution_presented(receipt: Dictionary) -> void:
	public_resolution_ready.emit(receipt.duplicate(true))


func _on_playtest_observation_ready(receipt: Dictionary) -> void:
	playtest_observation_ready.emit(receipt.duplicate(true))
