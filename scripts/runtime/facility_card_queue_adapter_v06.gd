@tool
extends Node
class_name FacilityCardQueueAdapterV06

const Binding := preload("res://scripts/cards/v06/queued_facility_card_action_v1.gd")
const SemanticWire := preload("res://scripts/semantic/semantic_wire_v1.gd")
const StableTargetEnvelope := preload("res://scripts/runtime/card_resolution_stable_target_envelope.gd")

const REQUEST_FIELDS := [
	"schema_version",
	"request_id",
	"intent_fingerprint",
	"source_revision",
	"actor_kind_id",
	"actor_id",
	"actor_player_index",
	"session_id",
	"session_revision",
	"hand_slot_id",
	"card_instance_id",
	"source_slot_index",
	"card_semantic_id",
	"region_id",
	"stable_target_envelope",
]
const COLORED_FACILITY_KINDS := ["factory", "market", "warehouse"]
const TRANSPORT_FACILITY_KINDS := ["road", "port", "spaceport"]
const SUBMISSION_SETTLEMENT_SCHEMA_VERSION := 2
const SUBMISSION_SETTLEMENT_KIND_ID := "facility_queue_submission_owner_compensation"
const SUBMISSION_SETTLEMENT_FIELDS := [
	"schema_version",
	"settlement_kind_id",
	"settled",
	"original_failure_reason_code",
	"reason_code",
	"queue_compensation",
	"reservation_compensation",
	"escrow_compensation",
]
const OWNER_COMPENSATION_FIELDS := [
	"schema_version",
	"compensation_kind_id",
	"owner_id",
	"required",
	"commit_expected",
	"attempted",
	"receipt_valid",
	"state_verified",
	"settled",
	"outcome_id",
	"reason_code",
]

var _world: WorldSessionState
var _session: GameSessionRuntimeController
var _queue: CardResolutionQueueRuntimeService
var _resolution: CardResolutionRuntimeController
var _card_state: CardPlayerStateProductionAdapterV06
var _mana: PlayerManaRuntimeController
var _core: CoreEconomicCardRuntimeAdapterV06
var _infrastructure: RegionInfrastructureRuntimeController
var _catalog: Resource
var _submission_port: CardPlaySubmissionRuntimeController
var _submission_capability: RefCounted
var _queue_rollback_capability: RefCounted
var _configured := false
var _submission_count := 0
var _queued_count := 0
var _resolution_count := 0
var _rejection_count := 0
var _rollback_count := 0
var _last_reason_code := "not_configured"
var _last_bundle_fingerprint := ""


func configure(
	world: WorldSessionState,
	session: GameSessionRuntimeController,
	queue: CardResolutionQueueRuntimeService,
	resolution: CardResolutionRuntimeController,
	card_state: CardPlayerStateProductionAdapterV06,
	mana: PlayerManaRuntimeController,
	core: CoreEconomicCardRuntimeAdapterV06,
	infrastructure: RegionInfrastructureRuntimeController,
	catalog: Resource,
	submission_port: CardPlaySubmissionRuntimeController
) -> Dictionary:
	if _configured and (
			_world != world \
			or _session != session \
			or _queue != queue \
			or _resolution != resolution \
			or _card_state != card_state \
			or _mana != mana \
			or _core != core \
			or _infrastructure != infrastructure \
			or _catalog != catalog \
			or _submission_port != submission_port
	):
		_last_reason_code = "facility_queue_reconfigure_rejected"
		return {
			"configured": false,
			"reason_code": _last_reason_code,
			"existing_configuration_preserved": true,
		}
	_world = world
	_session = session
	_queue = queue
	_resolution = resolution
	_card_state = card_state
	_mana = mana
	_core = core
	_infrastructure = infrastructure
	_catalog = catalog
	var queue_rollback_binding := _bind_queue_rollback_owner(queue)
	var submission_binding := _bind_submission_port(submission_port)
	_configured = _dependencies_ready() \
		and bool(queue_rollback_binding.get("bound", false)) \
		and bool(submission_binding.get("bound", false))
	_last_reason_code = "configured" if _configured else str(
		queue_rollback_binding.get("reason_code", "facility_queue_dependencies_missing") \
		if not bool(queue_rollback_binding.get("bound", false)) \
		else submission_binding.get("reason_code", "facility_queue_dependencies_missing")
	)
	return {
		"configured": _configured,
		"reason_code": _last_reason_code,
		"owns_queue": false,
		"owns_card_state": false,
		"owns_asset_state": false,
		"owns_facility_state": false,
		"owns_save_section": false,
	}


func _bind_submission_port(submission_port: CardPlaySubmissionRuntimeController) -> Dictionary:
	if submission_port == null:
		return {"bound": false, "reason_code": "facility_queue_submission_port_missing"}
	if _submission_port != null and _submission_port != submission_port:
		return {"bound": false, "reason_code": "facility_queue_submission_port_rebind_rejected"}
	if _submission_capability == null:
		_submission_capability = RefCounted.new()
	var binding := submission_port.bind_facility_queue_source(self, _submission_capability)
	if not bool(binding.get("bound", false)):
		return binding
	_submission_port = submission_port
	return {"bound": true, "reason_code": "facility_queue_submission_port_bound"}


func _bind_queue_rollback_owner(queue: CardResolutionQueueRuntimeService) -> Dictionary:
	if queue == null:
		return {
			"bound": false,
			"reason_code": "facility_queue_submission_rollback_owner_missing",
		}
	if _queue_rollback_capability == null:
		_queue_rollback_capability = RefCounted.new()
	return queue.bind_facility_submission_rollback_source(
		self,
		_queue_rollback_capability
	)


func reset_state() -> void:
	_submission_count = 0
	_queued_count = 0
	_resolution_count = 0
	_rejection_count = 0
	_rollback_count = 0
	_last_reason_code = "configured" if _configured else "not_configured"
	_last_bundle_fingerprint = ""


func submit(capability: RefCounted, request: Dictionary) -> Dictionary:
	_submission_count += 1
	if capability == null or capability != _submission_capability:
		return _reject("facility_queue_submission_unauthorized")
	var validation := _validate_request(request)
	if not bool(validation.get("valid", false)):
		return _reject(str(validation.get("reason_code", "facility_queue_request_invalid")))
	var recovery := _recover_submission_if_present(request)
	if bool(recovery.get("detected", false)):
		return (recovery.get("result", {}) as Dictionary).duplicate(true) \
			if recovery.get("result", {}) is Dictionary else _reject(
				"facility_queue_submission_recovery_invalid"
			)
	var current := _current_source(request)
	if not bool(current.get("valid", false)):
		return _reject(str(current.get("reason_code", "facility_queue_source_invalid")))
	var card: Dictionary = current.get("card", {}) as Dictionary
	var catalog_card: Dictionary = current.get("catalog_card", {}) as Dictionary
	var machine: Dictionary = card.get("machine", {}) as Dictionary
	var player_text: Dictionary = card.get("player", {}) as Dictionary
	var payload: Dictionary = machine.get("effect_payload", {}) as Dictionary
	var target_result := _core.facility_target_context(
		str(request.get("actor_id", "")),
		int(request.get("source_slot_index", -1)),
		str(request.get("card_semantic_id", "")),
		str(request.get("region_id", "")),
		_world.game_time
	)
	if not bool(target_result.get("ready", false)):
		return _reject(str(target_result.get("reason_code", "facility_target_unavailable")))
	var prebound_target: Dictionary = target_result.get("prebound_target", {}) \
		if target_result.get("prebound_target", {}) is Dictionary else {}
	if prebound_target.is_empty():
		return _reject("facility_target_binding_unavailable")

	var source_record_fingerprint := _stable_data_fingerprint(catalog_card)
	var source_slot_fingerprint := _stable_data_fingerprint(card)
	var escrow_id := _escrow_id(request)
	var escrow_plan := _card_state.plan_facility_card_escrow({
		"request_id": str(request.get("request_id", "")),
		"intent_fingerprint": str(request.get("intent_fingerprint", "")),
		"actor_id": str(request.get("actor_id", "")),
		"actor_player_index": int(request.get("actor_player_index", -1)),
		"source_slot_index": int(request.get("source_slot_index", -1)),
		"hand_slot_id": str(request.get("hand_slot_id", "")),
		"card_semantic_id": str(request.get("card_semantic_id", "")),
		"runtime_instance_id": str(request.get("card_instance_id", "")),
		"source_record_fingerprint": source_record_fingerprint,
		"source_slot_fingerprint": source_slot_fingerprint,
		"escrow_id": escrow_id,
	})
	if not bool(escrow_plan.get("planned", false)):
		if bool(escrow_plan.get("terminal", false)):
			return _terminal_submission_replay(escrow_plan)
		return _reject(str(escrow_plan.get("reason_code", "facility_card_escrow_plan_failed")))

	var runtime_state := _resolution.card_play_fact_snapshot()
	var stable_target_envelope := (request.get("stable_target_envelope", {}) as Dictionary).duplicate(true)
	var entry_context := StableTargetEnvelope.context_at_capture(stable_target_envelope)
	if entry_context.is_empty():
		return _reject("facility_stable_target_invalid")
	entry_context["queued_time"] = _world.game_time
	entry_context["stable_target_envelope"] = stable_target_envelope
	var skill := {
		"name": str(player_text.get("name", request.get("card_semantic_id", ""))),
		"display_name": str(player_text.get("name", request.get("card_semantic_id", ""))),
		"kind": "public_facility",
		"rank": int(machine.get("rank", 1)),
		"persistent": false,
		"asset_cost": (machine.get("asset_cost", {}) as Dictionary).duplicate(true),
		"display_seconds": 0,
	}
	var queue_plan := _queue.plan_submission({
		"player_index": int(request.get("actor_player_index", -1)),
		"slot_index": int(request.get("source_slot_index", -1)),
		"already_queued": false,
		"reactive_counter": false,
		"group_card_limit": 1,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"financial_terms_version": "",
		"available_cash_cents": 0,
		"cash_revision": "0",
		"asset_cost": skill["asset_cost"],
		"skill": skill,
		"entry_context": entry_context,
	}, {
		"player_count": _world.players.size(),
		"counter_window_active": bool(runtime_state.get("counter_window_active", false)),
		"batch_locked": bool(runtime_state.get("batch_locked", false)),
		"simultaneous_timer": float(runtime_state.get("simultaneous_timer", 0.0)),
		"lock_duration": float(_resolution.lock_seconds),
		"public_bid_duration": float(_resolution.public_bid_seconds),
		"window_sequence": int(runtime_state.get("window_sequence", 0)),
		"reference_player": int(runtime_state.get("batch_reference_player", -1)),
	})
	if not bool(queue_plan.get("accepted", false)):
		return _reject(str(queue_plan.get("reason", "facility_queue_plan_rejected")))
	var entry: Dictionary = (queue_plan.get("entry", {}) as Dictionary).duplicate(true)
	var resolution_id := int(entry.get("resolution_id", -1))
	var planned_reservation_id := _asset_reservation_id(request)
	var mana_plan := _mana.plan_reservation({
		"transaction_id": planned_reservation_id,
		"player_index": int(request.get("actor_player_index", -1)),
		"asset_cost": skill["asset_cost"],
		"generic_asset_allocation": {},
	})
	if not bool(mana_plan.get("accepted", false)):
		return _reject(str(mana_plan.get("reason", "asset_reservation_rejected")))

	var escrow_commit := _card_state.commit_facility_card_escrow(escrow_plan)
	if not bool(escrow_commit.get("committed", false)):
		var escrow_failure_reason := _safe_reason(str(escrow_commit.get(
			"reason_code",
			"facility_card_escrow_commit_failed"
		)))
		var escrow_snapshot := _card_state.facility_card_escrow_snapshot(escrow_id)
		var observed_escrow_fingerprint := _escrow_fingerprint_from_snapshot(
			escrow_snapshot,
			str(escrow_commit.get("escrow_fingerprint", ""))
		)
		var settlement := _rollback_submission_owners(
			request,
			escrow_id,
			observed_escrow_fingerprint,
			false,
			"",
			false,
			false,
			false,
			resolution_id,
			escrow_failure_reason
		)
		return _submission_failure(escrow_failure_reason, settlement)
	var escrow_fingerprint := str(escrow_commit.get("escrow_fingerprint", ""))
	var reservation_required := bool(mana_plan.get("required", false))
	var reservation_id := planned_reservation_id if reservation_required else ""
	var mana_commit := _mana.commit_reservation(mana_plan)
	if not bool(mana_commit.get("authorized", false)):
		var mana_failure_reason := _safe_reason(str(mana_commit.get(
			"reason",
			"asset_reservation_commit_failed"
		)))
		var settlement := _rollback_submission_owners(
			request,
			escrow_id,
			escrow_fingerprint,
			true,
			reservation_id,
			reservation_required,
			false,
			false,
			resolution_id,
			mana_failure_reason
		)
		return _submission_failure(mana_failure_reason, settlement)
	var reservation_snapshot := _mana.reservation_snapshot(reservation_id) if reservation_required else {}
	var reservation_fingerprint := str(reservation_snapshot.get("fingerprint", "")) \
		if reservation_required else SemanticWire.fingerprint({"required": false, "player_index": int(request.get("actor_player_index", -1))})

	var binding_input := {
		"schema_version": Binding.SCHEMA_VERSION,
		"binding_kind_id": Binding.BINDING_KIND_ID,
		"resolution_id": resolution_id,
		"request_id": str(request.get("request_id", "")),
		"intent_fingerprint": str(request.get("intent_fingerprint", "")),
		"session_id": str(request.get("session_id", "")),
		"session_revision": int(request.get("session_revision", 0)),
		"session_identity_fingerprint": _session.persistent_session_identity_fingerprint(),
		"source_revision": int(request.get("source_revision", 0)),
		"actor_kind_id": str(request.get("actor_kind_id", "")),
		"actor_id": str(request.get("actor_id", "")),
		"actor_player_index": int(request.get("actor_player_index", -1)),
		"card_instance_id": str(request.get("card_instance_id", "")),
		"runtime_instance_id": str(request.get("card_instance_id", "")),
		"card_semantic_id": str(request.get("card_semantic_id", "")),
		"hand_slot_id": str(request.get("hand_slot_id", "")),
		"source_slot_index": int(request.get("source_slot_index", -1)),
		"source_record_fingerprint": source_record_fingerprint,
		"source_slot_fingerprint": source_slot_fingerprint,
		"facility_kind_id": str(payload.get("facility_kind", "")),
		"industry_id": str(payload.get("industry_id", machine.get("industry_id", ""))),
		"rank": int(machine.get("rank", 1)),
		"prebound_target": prebound_target.duplicate(true),
		"asset_reservation": {
			"schema_version": 1,
			"owner_id": "player_mana",
			"required": reservation_required,
			"reservation_id": reservation_id,
			"reservation_state_id": "reserved",
			"reservation_fingerprint": reservation_fingerprint,
		},
		"card_escrow": {
			"schema_version": 1,
			"owner_id": "world_session_state",
			"escrow_id": escrow_id,
			"state_id": "committed_resolution_escrow",
			"escrow_fingerprint": escrow_fingerprint,
		},
		"submitted_at_world_time": maxi(0, int(round(_world.game_time * 1000.0))),
		"queue_revision_at_commit": int(queue_plan.get("expected_revision", 0)) + 1,
		"local_action_index": 0,
		"public_visibility": {
			"schema_version": 1,
			"owner_visibility_id": "anonymous",
			"card_visibility_id": "public",
			"target_visibility_id": "public",
		},
	}
	var binding := Binding.build(binding_input)
	if binding.is_empty():
		var sealed_candidate := SemanticWire.sealed_copy(binding_input, "binding_fingerprint")
		var binding_report := Binding.validation_report(sealed_candidate)
		var reason_code := _safe_reason(str(binding_report.get(
			"reason_id",
			"facility_queue_binding_invalid"
		)))
		var settlement := _rollback_submission_owners(
			request,
			escrow_id,
			escrow_fingerprint,
			true,
			reservation_id,
			reservation_required,
			reservation_required,
			false,
			resolution_id,
			reason_code
		)
		return _submission_failure(reason_code, settlement)
	entry["asset_reservation_id"] = reservation_id
	entry["asset_cost"] = (mana_plan.get("asset_cost", {}) as Dictionary).duplicate(true)
	entry["asset_debit"] = (mana_plan.get("asset_debit", {}) as Dictionary).duplicate(true)
	entry["asset_reservation_required"] = reservation_required
	entry["v06_facility_action"] = binding.duplicate(true)
	queue_plan["entry"] = entry
	var queue_commit := _queue.commit_submission(queue_plan, {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": true,
		"financial_margin_authorized": true,
		"asset_authorized": true,
	})
	if not bool(queue_commit.get("committed", false)):
		var queue_failure_reason := _safe_reason(str(queue_commit.get(
			"reason",
			"facility_queue_commit_failed"
		)))
		var settlement := _rollback_submission_owners(
			request,
			escrow_id,
			escrow_fingerprint,
			true,
			reservation_id,
			reservation_required,
			reservation_required,
			false,
			resolution_id,
			queue_failure_reason
		)
		return _submission_failure(queue_failure_reason, settlement)
	_queued_count += 1
	_last_reason_code = "facility_card_queued"
	_last_bundle_fingerprint = str(binding.get("binding_fingerprint", ""))
	return {
		"accepted": true,
		"queued": true,
		"committed": false,
		"reason_code": _last_reason_code,
		"resolution_id": resolution_id,
		"queue_revision": int(queue_commit.get("revision", 0)),
		"binding_fingerprint": _last_bundle_fingerprint,
		"idempotent_replay": bool(escrow_commit.get("idempotent_replay", false)) \
			or bool(mana_commit.get("duplicate", false)),
	}


func revalidate(entry: Dictionary) -> Dictionary:
	if not _configured:
		return {"valid": false, "reason_code": "facility_queue_not_configured"}
	var binding: Dictionary = entry.get("v06_facility_action", {}) \
		if entry.get("v06_facility_action", {}) is Dictionary else {}
	var report := Binding.validation_report(binding)
	if not bool(report.get("valid", false)):
		return {"valid": false, "reason_code": str(report.get("reason", "facility_queue_binding_invalid"))}
	if int(binding.get("resolution_id", -1)) != int(entry.get("resolution_id", -2)):
		return {"valid": false, "reason_code": "facility_queue_resolution_binding_changed"}
	if str(binding.get("session_id", "")) != str(_session.session_summary().get("session_id", "")) \
			or str(binding.get("session_identity_fingerprint", "")) != _session.persistent_session_identity_fingerprint():
		return {"valid": false, "reason_code": "facility_queue_session_changed"}
	var player_index := int(binding.get("actor_player_index", -1))
	if player_index < 0 or player_index >= _world.players.size() \
			or not (_world.players[player_index] is Dictionary) \
			or bool((_world.players[player_index] as Dictionary).get("eliminated", false)):
		return {"valid": false, "reason_code": "facility_queue_actor_unavailable"}
	var escrow_ref: Dictionary = binding.get("card_escrow", {}) as Dictionary
	var escrow_result := _card_state.facility_card_escrow_snapshot(str(escrow_ref.get("escrow_id", "")))
	if not bool(escrow_result.get("found", false)):
		return {"valid": false, "reason_code": str(escrow_result.get("reason_code", "facility_card_escrow_missing"))}
	var escrow: Dictionary = escrow_result.get("escrow", {}) as Dictionary
	if str(escrow.get("state_id", "")) != "committed_resolution_escrow" \
			or str(escrow.get("escrow_fingerprint", "")) != str(escrow_ref.get("escrow_fingerprint", "")) \
			or str(escrow.get("request_id", "")) != str(binding.get("request_id", "")) \
			or str(escrow.get("runtime_instance_id", "")) != str(binding.get("runtime_instance_id", "")):
		return {"valid": false, "reason_code": "facility_card_escrow_binding_changed"}
	var card: Dictionary = escrow.get("card_record", {}) as Dictionary
	var catalog_card_variant: Variant = _catalog.call("card_snapshot", str(binding.get("card_semantic_id", "")))
	var catalog_card: Dictionary = catalog_card_variant if catalog_card_variant is Dictionary else {}
	if catalog_card.is_empty() or _stable_data_fingerprint(catalog_card) != str(binding.get("source_record_fingerprint", "")) \
			or card.get("machine", {}) != catalog_card.get("machine", {}) \
			or card.get("player", {}) != catalog_card.get("player", {}) \
			or card.get("developer", {}) != catalog_card.get("developer", {}):
		return {"valid": false, "reason_code": "facility_queue_catalog_binding_changed"}
	var target_ref: Dictionary = binding.get("prebound_target", {}) as Dictionary
	var target_variant: Variant = _infrastructure.facility_target_binding_snapshot(
		str(target_ref.get("region_id", "")),
		str(binding.get("facility_kind_id", "")),
		str(binding.get("industry_id", ""))
	)
	var current_target: Dictionary = target_variant if target_variant is Dictionary else {}
	if current_target != target_ref:
		return {"valid": false, "reason_code": "facility_queue_target_changed"}
	var reservation_ref: Dictionary = binding.get("asset_reservation", {}) as Dictionary
	if bool(reservation_ref.get("required", false)):
		var reservation := _mana.reservation_snapshot(str(reservation_ref.get("reservation_id", "")))
		if reservation.is_empty() \
				or int(reservation.get("player_index", -1)) != player_index \
				or str(reservation.get("state", "")) != "reserved" \
				or str(reservation.get("fingerprint", "")) != str(reservation_ref.get("reservation_fingerprint", "")):
			return {"valid": false, "reason_code": "facility_queue_asset_reservation_changed"}
	var target_context := current_target.duplicate(true)
	target_context["valid"] = true
	target_context["target_kind"] = "region_unique_facility_slot"
	target_context["slot_id"] = str(current_target.get("target_slot_id", ""))
	target_context["industry_id"] = str(binding.get("industry_id", ""))
	target_context["game_time"] = float(int(binding.get("submitted_at_world_time", 0))) / 1000.0
	return {
		"valid": true,
		"reason_code": "facility_queue_binding_current",
		"binding": binding.duplicate(true),
		"card": card.duplicate(true),
		"target_context": target_context,
	}


func resolve(entry: Dictionary) -> Dictionary:
	var current := revalidate(entry)
	if not bool(current.get("valid", false)):
		var rejection := reject_pending(entry, str(current.get("reason_code", "facility_queue_revalidation_failed")))
		return {
			"handled": true,
			"resolved": false,
			"finalized": false,
			"commitment_settled": bool(rejection.get("settled", false)),
			"reason_code": str(current.get("reason_code", "facility_queue_revalidation_failed")),
		}
	var binding: Dictionary = current.get("binding", {}) as Dictionary
	var effect_transaction_id := "facility-resolution.%d.%s" % [
		int(binding.get("resolution_id", 0)),
		str(binding.get("binding_fingerprint", "")).substr(0, 16),
	]
	var preparation := _core.prepare_queued_facility_card(
		str(binding.get("actor_id", "")),
		current.get("card", {}) as Dictionary,
		current.get("target_context", {}) as Dictionary,
		effect_transaction_id
	)
	if not bool(preparation.get("prepared", false)):
		var rejection := reject_pending(entry, str(preparation.get("reason_code", "facility_effect_prepare_failed")))
		return _resolution_failure(str(preparation.get("reason_code", "facility_effect_prepare_failed")), rejection)
	var committed := _core.commit_queued_facility_card(preparation)
	if not bool(committed.get("committed", false)):
		_core.abort_queued_facility_card(preparation)
		var rejection := reject_pending(entry, str(committed.get("reason_code", "facility_effect_commit_failed")))
		return _resolution_failure(str(committed.get("reason_code", "facility_effect_commit_failed")), rejection)
	var effect_receipt: Dictionary = committed.get("effect_receipt", {}) as Dictionary
	var escrow_ref: Dictionary = binding.get("card_escrow", {}) as Dictionary
	var escrow_id := str(escrow_ref.get("escrow_id", ""))
	var escrow_consume := _card_state.consume_facility_card_escrow(
		escrow_id,
		str(escrow_ref.get("escrow_fingerprint", ""))
	)
	if not bool(escrow_consume.get("consumed", false)):
		_core.rollback_queued_facility_card(effect_receipt)
		var rejection := reject_pending(entry, "facility_card_escrow_consume_failed")
		return _resolution_failure("facility_card_escrow_consume_failed", rejection)
	var pending_escrow_fingerprint := str(escrow_consume.get("escrow_fingerprint", ""))
	var reservation_ref: Dictionary = binding.get("asset_reservation", {}) as Dictionary
	var mana_receipt := {"settled": true, "required": false}
	if bool(reservation_ref.get("required", false)):
		mana_receipt = _mana.consume_reservation(
			str(reservation_ref.get("reservation_id", "")),
			{"resolved": true, "committed": true, "resolution_id": int(binding.get("resolution_id", -1))}
		)
	if not bool(mana_receipt.get("settled", false)):
		var compensation := _rollback_resolution_owners(
			effect_receipt,
			escrow_id,
			pending_escrow_fingerprint,
			reservation_ref,
			false,
			"asset_consume_failed"
		)
		return _resolution_failure("asset_consume_failed", compensation)
	var facility_finalize_preflight := _core.preflight_finalize_queued_facility_card(
		effect_receipt
	)
	var escrow_finalize_preflight := _card_state.preflight_finalize_facility_card_escrow(
		escrow_id,
		pending_escrow_fingerprint
	)
	if not bool(facility_finalize_preflight.get("ready", false)) \
			or not bool(escrow_finalize_preflight.get("ready", false)):
		var preflight_reason := str(facility_finalize_preflight.get(
			"reason_code",
			"facility_effect_finalize_preflight_failed"
		)) if not bool(facility_finalize_preflight.get("ready", false)) else str(
			escrow_finalize_preflight.get(
				"reason_code",
				"facility_card_escrow_finalize_preflight_failed"
			)
		)
		var compensation := _rollback_resolution_owners(
			effect_receipt,
			escrow_id,
			pending_escrow_fingerprint,
			reservation_ref,
			bool(reservation_ref.get("required", false)),
			preflight_reason
		)
		return _resolution_failure(preflight_reason, compensation)
	var finalization := _core.finalize_queued_facility_card(effect_receipt)
	if not bool(finalization.get("finalized", false)):
		var finalization_reason := str(finalization.get(
			"reason_code",
			"facility_effect_finalize_failed"
		))
		var compensation := _rollback_resolution_owners(
			effect_receipt,
			escrow_id,
			pending_escrow_fingerprint,
			reservation_ref,
			bool(reservation_ref.get("required", false)),
			finalization_reason
		)
		return _resolution_failure(finalization_reason, compensation)
	var escrow_finalize := _card_state.finalize_facility_card_escrow(
		escrow_id,
		pending_escrow_fingerprint
	)
	if not bool(escrow_finalize.get("finalized", false)):
		_last_reason_code = "facility_card_escrow_finalize_retryable"
		return {
			"handled": true,
			"resolved": true,
			"committed": true,
			"finalized": true,
			"commitment_settled": false,
			"retryable": true,
			"reason_code": _last_reason_code,
			"effect_receipt": effect_receipt.duplicate(true),
			"effect_finalization": finalization.duplicate(true),
			"escrow_receipt": escrow_finalize.duplicate(true),
			"asset_receipt": mana_receipt.duplicate(true),
		}
	_resolution_count += 1
	_last_reason_code = "queued_facility_resolved"
	return {
		"handled": true,
		"resolved": true,
		"committed": true,
		"finalized": true,
		"commitment_settled": true,
		"reason_code": _last_reason_code,
		"effect_receipt": effect_receipt.duplicate(true),
		"effect_finalization": finalization.duplicate(true),
		"escrow_receipt": escrow_finalize.duplicate(true),
		"asset_receipt": mana_receipt.duplicate(true),
	}


func settle_commitment(
	entry: Dictionary,
	release_required: bool,
	reason_code: String
) -> Dictionary:
	var binding: Dictionary = entry.get("v06_facility_action", {}) \
		if entry.get("v06_facility_action", {}) is Dictionary else {}
	if not bool(Binding.validation_report(binding).get("valid", false)):
		return {"settled": false, "reason_code": "facility_queue_binding_invalid"}
	var lifecycle := _facility_lifecycle_snapshot(binding)
	var lifecycle_state := str(lifecycle.get("state", ""))
	var escrow_ref: Dictionary = binding.get("card_escrow", {}) as Dictionary
	var escrow_id := str(escrow_ref.get("escrow_id", ""))
	var escrow_status := _card_state.facility_card_escrow_snapshot(escrow_id)
	if lifecycle_state == "finalized":
		var transitioned_to_terminal := false
		if bool(escrow_status.get("found", false)):
			var escrow: Dictionary = escrow_status.get("escrow", {}) as Dictionary
			if str(escrow.get("state_id", "")) == "consumed_pending_finalization":
				var escrow_finalize := _card_state.finalize_facility_card_escrow(
					escrow_id,
					str(escrow.get("escrow_fingerprint", ""))
				)
				transitioned_to_terminal = bool(escrow_finalize.get("finalized", false)) \
					and not bool(escrow_finalize.get("idempotent_replay", false))
		var finalized_status := commitment_status(entry)
		if transitioned_to_terminal and bool(finalized_status.get("settled", false)):
			_resolution_count += 1
			_last_reason_code = "queued_facility_resolved"
		return finalized_status
	var current_status := commitment_status(entry)
	if bool(current_status.get("settled", false)) or not release_required:
		return current_status
	var safe_reason := _safe_reason(reason_code)
	var facility_rollback := {"rolled_back": lifecycle_state.is_empty() or lifecycle_state == "rolled_back"}
	if lifecycle_state == "applied":
		var owner_receipt: Dictionary = lifecycle.get("original_receipt", {}) \
			if lifecycle.get("original_receipt", {}) is Dictionary else {}
		facility_rollback = _core.rollback_queued_facility_card(owner_receipt)
	var reservation_ref: Dictionary = binding.get("asset_reservation", {}) as Dictionary
	var asset_result := _settle_asset_release(reservation_ref, safe_reason)
	escrow_status = _card_state.facility_card_escrow_snapshot(escrow_id)
	var card_result := {"released": false, "terminal": false}
	if bool(escrow_status.get("terminal", false)):
		var terminal_receipt: Dictionary = escrow_status.get("receipt", {}) \
			if escrow_status.get("receipt", {}) is Dictionary else {}
		card_result = {
			"released": str(terminal_receipt.get("state_id", "")) == "released",
			"terminal": true,
			"receipt": terminal_receipt.duplicate(true),
		}
	elif bool(escrow_status.get("found", false)):
		var escrow: Dictionary = escrow_status.get("escrow", {}) as Dictionary
		card_result = _card_state.release_facility_card_escrow(
			escrow_id,
			str(escrow.get("escrow_fingerprint", "")),
			safe_reason
		)
	var status := commitment_status(entry)
	status["facility_rollback"] = facility_rollback.duplicate(true)
	status["asset_settlement"] = asset_result.duplicate(true)
	status["card_settlement"] = card_result.duplicate(true)
	return status


func _rollback_resolution_owners(
	effect_receipt: Dictionary,
	escrow_id: String,
	escrow_fingerprint: String,
	reservation_ref: Dictionary,
	mana_consumed: bool,
	reason_code: String
) -> Dictionary:
	var safe_reason := _safe_reason(reason_code)
	var facility_rollback := _core.rollback_queued_facility_card(effect_receipt)
	var asset_settled := not bool(reservation_ref.get("required", false))
	var reservation_id := str(reservation_ref.get("reservation_id", ""))
	var asset_rollback: Dictionary = {}
	var asset_release: Dictionary = {}
	if bool(reservation_ref.get("required", false)):
		if mana_consumed:
			asset_rollback = _mana.rollback_consumed_reservation(
				reservation_id,
				str(reservation_ref.get("reservation_fingerprint", "")),
				safe_reason
			)
			if bool(asset_rollback.get("rolled_back", false)):
				asset_release = _mana.release_reservation(reservation_id, safe_reason)
		else:
			asset_release = _mana.release_reservation(reservation_id, safe_reason)
		asset_settled = bool(asset_release.get("settled", false)) \
			and (not mana_consumed or bool(asset_rollback.get("rolled_back", false)))
	var card_release := _card_state.release_facility_card_escrow(
		escrow_id,
		escrow_fingerprint,
		safe_reason
	)
	var settled := bool(facility_rollback.get("rolled_back", false)) \
		and asset_settled \
		and (bool(card_release.get("released", false)) \
			or bool(card_release.get("terminal", false)))
	if settled:
		_rollback_count += 1
	return {
		"settled": settled,
		"reason_code": safe_reason,
		"facility_rollback": facility_rollback.duplicate(true),
		"asset_rollback": asset_rollback.duplicate(true),
		"asset_release": asset_release.duplicate(true),
		"card_release": card_release.duplicate(true),
	}


func reject_pending(entry: Dictionary, reason_code: String) -> Dictionary:
	var binding: Dictionary = entry.get("v06_facility_action", {}) \
		if entry.get("v06_facility_action", {}) is Dictionary else {}
	if not bool(Binding.validation_report(binding).get("valid", false)):
		return {"settled": false, "reason_code": "facility_queue_binding_invalid"}
	var escrow_ref: Dictionary = binding.get("card_escrow", {}) as Dictionary
	var escrow_id := str(escrow_ref.get("escrow_id", ""))
	var escrow_snapshot := _card_state.facility_card_escrow_snapshot(escrow_id)
	var card_settled := bool(escrow_snapshot.get("terminal", false))
	if bool(escrow_snapshot.get("found", false)):
		var escrow: Dictionary = escrow_snapshot.get("escrow", {}) as Dictionary
		var release := _card_state.release_facility_card_escrow(
			escrow_id,
			str(escrow.get("escrow_fingerprint", "")),
			_safe_reason(reason_code)
		)
		card_settled = bool(release.get("released", false)) or bool(release.get("terminal", false))
	var reservation_ref: Dictionary = binding.get("asset_reservation", {}) as Dictionary
	var asset_settled := not bool(reservation_ref.get("required", false))
	if bool(reservation_ref.get("required", false)):
		var reservation_id := str(reservation_ref.get("reservation_id", ""))
		var reservation := _mana.reservation_snapshot(reservation_id)
		if not reservation.is_empty():
			var release_variant := _mana.release_reservation(reservation_id, _safe_reason(reason_code))
			asset_settled = release_variant is Dictionary and bool((release_variant as Dictionary).get("settled", false))
		else:
			asset_settled = true
	var settled := card_settled and asset_settled
	if settled:
		_rollback_count += 1
	return {"settled": settled, "reason_code": _safe_reason(reason_code)}


func commitment_status(entry: Dictionary) -> Dictionary:
	var binding: Dictionary = entry.get("v06_facility_action", {}) \
		if entry.get("v06_facility_action", {}) is Dictionary else {}
	if not bool(Binding.validation_report(binding).get("valid", false)):
		return {"settled": false, "reason_code": "facility_queue_binding_invalid"}
	var escrow_ref := binding.get("card_escrow", {}) as Dictionary
	var escrow_status := _card_state.facility_card_escrow_snapshot(
		str(escrow_ref.get("escrow_id", ""))
	)
	if not bool(escrow_status.get("terminal", false)):
		return {"settled": false, "reason_code": "facility_card_escrow_not_terminal"}
	var receipt: Dictionary = escrow_status.get("receipt", {}) \
		if escrow_status.get("receipt", {}) is Dictionary else {}
	if str(receipt.get("request_id", "")) != str(binding.get("request_id", "")) \
			or str(receipt.get("runtime_instance_id", "")) != str(binding.get("runtime_instance_id", "")) \
			or str(receipt.get("card_semantic_id", "")) != str(binding.get("card_semantic_id", "")):
		return {"settled": false, "reason_code": "facility_card_escrow_terminal_binding_changed"}
	var state_id := str(receipt.get("state_id", ""))
	if state_id not in ["consumed_finalized", "released"]:
		return {"settled": false, "reason_code": "facility_card_escrow_terminal_state_invalid"}
	var reservation_ref := binding.get("asset_reservation", {}) as Dictionary
	var asset_outcome := "not_required"
	if bool(reservation_ref.get("required", false)):
		var asset_status := _mana.reservation_settlement_snapshot(
			str(reservation_ref.get("reservation_id", ""))
		)
		if not bool(asset_status.get("found", false)) \
				or str((asset_status.get("reservation", {}) as Dictionary).get("fingerprint", "")) \
					!= str(reservation_ref.get("reservation_fingerprint", "")):
			return {"settled": false, "reason_code": "facility_asset_reservation_settlement_invalid"}
		asset_outcome = str(asset_status.get("outcome_id", ""))
		var expected_asset_outcome := "consumed" if state_id == "consumed_finalized" else "released"
		if asset_outcome != expected_asset_outcome:
			return {"settled": false, "reason_code": "facility_asset_reservation_outcome_mismatch"}
	var lifecycle := _facility_lifecycle_snapshot(binding)
	var lifecycle_state := str(lifecycle.get("state", ""))
	var expected_lifecycle_state := "finalized" if state_id == "consumed_finalized" else "rolled_back"
	if lifecycle_state != expected_lifecycle_state \
			and not (state_id == "released" and lifecycle_state.is_empty()):
		return {"settled": false, "reason_code": "facility_effect_lifecycle_unsettled"}
	return {
		"settled": true,
		"committed": state_id == "consumed_finalized",
		"released": state_id == "released",
		"asset_outcome_id": asset_outcome,
		"facility_lifecycle_state_id": lifecycle_state if not lifecycle_state.is_empty() else "not_started",
		"commitment_settled": true,
		"reason_code": "facility_queue_commitment_settled",
	}


func _facility_lifecycle_snapshot(binding: Dictionary) -> Dictionary:
	if _infrastructure == null:
		return {}
	var transaction_id := "facility-resolution.%d.%s" % [
		int(binding.get("resolution_id", 0)),
		str(binding.get("binding_fingerprint", "")).substr(0, 16),
	]
	return _infrastructure.facility_action_lifecycle_snapshot(transaction_id)


func _settle_asset_release(reservation_ref: Dictionary, reason_code: String) -> Dictionary:
	if not bool(reservation_ref.get("required", false)):
		return {"settled": true, "outcome_id": "not_required"}
	var reservation_id := str(reservation_ref.get("reservation_id", ""))
	var status := _mana.reservation_settlement_snapshot(reservation_id)
	match str(status.get("outcome_id", "")):
		"released":
			return {"settled": true, "outcome_id": "released", "idempotent_replay": true}
		"consumed":
			var rollback := _mana.rollback_consumed_reservation(
				reservation_id,
				str(reservation_ref.get("reservation_fingerprint", "")),
				reason_code
			)
			if not bool(rollback.get("rolled_back", false)):
				return {"settled": false, "outcome_id": "consumed", "rollback": rollback.duplicate(true)}
			var release := _mana.release_reservation(reservation_id, reason_code)
			return {
				"settled": bool(release.get("settled", false)) \
					and str(release.get("outcome", "")) == "released",
				"outcome_id": str(release.get("outcome", "")),
				"rollback": rollback.duplicate(true),
				"release": release.duplicate(true),
			}
		"pending":
			var release := _mana.release_reservation(reservation_id, reason_code)
			return {
				"settled": bool(release.get("settled", false)) \
					and str(release.get("outcome", "")) == "released",
				"outcome_id": str(release.get("outcome", "")),
				"release": release.duplicate(true),
			}
	return {"settled": false, "outcome_id": str(status.get("outcome_id", "missing"))}


func debug_snapshot() -> Dictionary:
	return {
		"adapter_ready": _configured,
		"submission_count": _submission_count,
		"queued_count": _queued_count,
		"resolution_count": _resolution_count,
		"rejection_count": _rejection_count,
		"rollback_count": _rollback_count,
		"last_reason_code": _last_reason_code,
		"last_bundle_fingerprint": _last_bundle_fingerprint,
		"owns_queue": false,
		"owns_card_state": false,
		"owns_asset_state": false,
		"owns_facility_state": false,
		"owns_save_section": false,
		"private_card_body_visible": false,
	}


func _validate_request(request: Dictionary) -> Dictionary:
	if not _configured or not SemanticWire.is_closed_data(request) \
			or not SemanticWire.exact_fields(request, REQUEST_FIELDS):
		return {"valid": false, "reason_code": "facility_queue_request_invalid"}
	if request.get("schema_version") != 1 \
			or str(request.get("actor_kind_id", "")) not in ["human", "ai"] \
			or not SemanticWire.is_session_id(request.get("request_id")) \
			or not SemanticWire.is_fingerprint(request.get("intent_fingerprint")) \
			or not SemanticWire.is_positive_integer(request.get("source_revision")) \
			or not SemanticWire.is_stable_id(request.get("actor_id")) \
			or not SemanticWire.is_nonnegative_integer(request.get("actor_player_index")) \
			or str(request.get("actor_id", "")) != "player.%d" % int(request.get("actor_player_index", -1)) \
			or not SemanticWire.is_session_id(request.get("session_id")) \
			or not SemanticWire.is_nonnegative_integer(request.get("session_revision")) \
			or not SemanticWire.is_stable_id(request.get("hand_slot_id")) \
			or not SemanticWire.is_session_id(request.get("card_instance_id")) \
			or not SemanticWire.is_nonnegative_integer(request.get("source_slot_index")) \
			or str(request.get("hand_slot_id", "")) != "hand.slot.%d" % int(request.get("source_slot_index", -1)) \
			or not SemanticWire.is_stable_id(request.get("card_semantic_id")) \
			or not SemanticWire.is_stable_id(request.get("region_id")) \
			or not (request.get("stable_target_envelope") is Dictionary):
		return {"valid": false, "reason_code": "facility_queue_request_binding_invalid"}
	var stable_target_envelope := request.get("stable_target_envelope") as Dictionary
	var envelope_validation := StableTargetEnvelope.validate(stable_target_envelope)
	if not bool(envelope_validation.get("valid", false)):
		return {
			"valid": false,
			"reason_code": str(envelope_validation.get(
				"reason_code",
				"facility_queue_stable_target_invalid"
			)),
		}
	if str(stable_target_envelope.get("session_id", "")) != str(request.get("session_id", "")) \
			or int(stable_target_envelope.get("session_revision", -1)) != int(request.get("session_revision", -2)) \
			or str(stable_target_envelope.get("region_id", "")) != str(request.get("region_id", "")):
		return {"valid": false, "reason_code": "facility_queue_stable_target_binding_mismatch"}
	var summary := _session.session_summary()
	if str(summary.get("session_state", "")) != GameSessionRuntimeController.STATE_RUNNING \
			or str(summary.get("session_id", "")) != str(request.get("session_id", "")) \
			or int(request.get("session_revision", -1)) != _session.session_start_revision():
		return {"valid": false, "reason_code": "facility_queue_session_unavailable"}
	return {"valid": true, "reason_code": "facility_queue_request_valid"}


func _current_source(request: Dictionary) -> Dictionary:
	var player_index := int(request.get("actor_player_index", -1))
	var slot_index := int(request.get("source_slot_index", -1))
	if player_index < 0 or player_index >= _world.players.size() \
			or not (_world.players[player_index] is Dictionary):
		return {"valid": false, "reason_code": "facility_queue_actor_missing"}
	var player: Dictionary = _world.players[player_index]
	if bool(player.get("eliminated", false)):
		return {"valid": false, "reason_code": "facility_queue_actor_eliminated"}
	var actor_map := _card_state.actor_player_indices()
	if int(actor_map.get(str(request.get("actor_id", "")), -1)) != player_index:
		return {"valid": false, "reason_code": "facility_queue_actor_binding_changed"}
	var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {"valid": false, "reason_code": "facility_queue_source_slot_missing"}
	var card := (slots[slot_index] as Dictionary).duplicate(true)
	var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
	var payload: Dictionary = machine.get("effect_payload", {}) if machine.get("effect_payload", {}) is Dictionary else {}
	var facility_kind := str(payload.get("facility_kind", ""))
	if str(card.get("runtime_instance_id", "")) != str(request.get("card_instance_id", "")) \
			or str(machine.get("card_id", "")) != str(request.get("card_semantic_id", "")) \
			or str(machine.get("category_id", "")) != "facility" \
			or str(machine.get("effect_kind", "")) != "build_upgrade_or_repair_facility" \
			or str(machine.get("target_kind", "")) != "region_unique_facility_slot" \
			or facility_kind not in COLORED_FACILITY_KINDS + TRANSPORT_FACILITY_KINDS:
		return {"valid": false, "reason_code": "facility_queue_card_binding_changed"}
	var catalog_variant: Variant = _catalog.call("card_snapshot", str(machine.get("card_id", "")))
	var catalog_card: Dictionary = catalog_variant if catalog_variant is Dictionary else {}
	if catalog_card.is_empty() or card.get("machine", {}) != catalog_card.get("machine", {}) \
			or card.get("player", {}) != catalog_card.get("player", {}) \
			or card.get("developer", {}) != catalog_card.get("developer", {}):
		return {"valid": false, "reason_code": "facility_queue_catalog_record_changed"}
	return {"valid": true, "card": card, "catalog_card": catalog_card}


func _rollback_submission_owners(
	request: Dictionary,
	escrow_id: String,
	escrow_fingerprint: String,
	escrow_commit_expected: bool,
	reservation_id: String,
	reservation_required: bool,
	reservation_commit_expected: bool,
	queue_commit_expected: bool,
	expected_resolution_id: int,
	reason_code: String,
	queue_receipt: Dictionary = {}
) -> Dictionary:
	var safe_reason := _safe_reason(reason_code)
	var queue_compensation := _settle_submission_queue(
		request,
		escrow_id,
		queue_commit_expected,
		expected_resolution_id,
		safe_reason,
		queue_receipt
	)
	var reservation_compensation: Dictionary
	var escrow_compensation: Dictionary
	if not bool(queue_compensation.get("settled", false)):
		reservation_compensation = _blocked_owner_compensation(
			"reservation_release",
			"player_mana",
			reservation_required,
			reservation_commit_expected
		)
		escrow_compensation = _blocked_owner_compensation(
			"card_escrow_release",
			"world_session_state",
			true,
			escrow_commit_expected
		)
	else:
		reservation_compensation = _settle_submission_reservation(
			reservation_id,
			reservation_required,
			reservation_commit_expected,
			safe_reason
		)
		escrow_compensation = _settle_submission_escrow(
			escrow_id,
			escrow_fingerprint,
			escrow_commit_expected,
			safe_reason
		)
	var settled := bool(queue_compensation.get("settled", false)) \
		and bool(reservation_compensation.get("settled", false)) \
		and bool(escrow_compensation.get("settled", false))
	if settled:
		_rollback_count += 1
	return {
		"schema_version": SUBMISSION_SETTLEMENT_SCHEMA_VERSION,
		"settlement_kind_id": SUBMISSION_SETTLEMENT_KIND_ID,
		"settled": settled,
		"original_failure_reason_code": safe_reason,
		"reason_code": "facility_queue_submission_compensated" if settled \
			else "facility_queue_submission_compensation_incomplete",
		"queue_compensation": queue_compensation,
		"reservation_compensation": reservation_compensation,
		"escrow_compensation": escrow_compensation,
	}


func _settle_submission_queue(
	request: Dictionary,
	escrow_id: String,
	commit_expected: bool,
	expected_resolution_id: int,
	reason_code: String,
	existing_receipt: Dictionary = {}
) -> Dictionary:
	var rollback_request := _queue_rollback_request(
		request,
		escrow_id,
		expected_resolution_id,
		reason_code
	)
	var receipt := existing_receipt.duplicate(true) if not existing_receipt.is_empty() \
		else _queue.rollback_facility_submission(
			_queue_rollback_capability,
			rollback_request
		)
	var receipt_fields := [
		"schema_version",
		"settlement_kind_id",
		"settled",
		"commitment_found",
		"rolled_back",
		"state_verified",
		"resolution_id",
		"outcome_id",
		"reason_code",
		"idempotent_replay",
	]
	var receipt_valid: bool = SemanticWire.is_closed_data(receipt) \
		and SemanticWire.exact_fields(receipt, receipt_fields) \
		and receipt.get("schema_version") == 1 \
		and str(receipt.get("settlement_kind_id", "")) \
			== "facility_queue_submission_rollback" \
		and receipt.get("settled") is bool \
		and receipt.get("commitment_found") is bool \
		and receipt.get("rolled_back") is bool \
		and receipt.get("state_verified") is bool \
		and receipt.get("resolution_id") is int \
		and receipt.get("idempotent_replay") is bool \
		and SemanticWire.is_stable_id(receipt.get("outcome_id")) \
		and SemanticWire.is_stable_id(receipt.get("reason_code"))
	var queue_status := _queue.facility_submission_status(
		_queue_rollback_capability,
		rollback_request
	)
	var queue_status_valid: bool = _queue_submission_status_valid(queue_status)
	var commitment_absent: bool = queue_status_valid \
		and not bool(queue_status.get("commitment_found", true)) \
		and not bool(queue_status.get("active", true)) \
		and int(queue_status.get("resolution_id", -2)) == -1
	var state_verified: bool = receipt_valid \
		and bool(receipt.get("state_verified", false)) \
		and commitment_absent
	var settled: bool = receipt_valid and bool(receipt.get("settled", false)) \
		and state_verified
	var commitment_found: bool = bool(receipt.get("commitment_found", false)) \
		if receipt_valid else false
	if queue_status_valid:
		commitment_found = commitment_found \
			or bool(queue_status.get("commitment_found", false))
	return _owner_compensation(
		"queue_submission_rollback",
		"card_resolution_queue",
		true,
		commit_expected,
		commitment_found,
		receipt_valid,
		state_verified,
		settled,
		str(receipt.get("outcome_id", "receipt_invalid")) if settled \
			else ("commitment_present" if receipt_valid and not commitment_absent \
				else "receipt_invalid"),
		"facility_submission_queue_settled" if settled \
			else "facility_submission_queue_settlement_incomplete"
	)


func _queue_rollback_request(
	request: Dictionary,
	escrow_id: String,
	expected_resolution_id: int,
	reason_code: String
) -> Dictionary:
	return {
		"schema_version": 1,
		"request_id": str(request.get("request_id", "")),
		"intent_fingerprint": str(request.get("intent_fingerprint", "")),
		"actor_id": str(request.get("actor_id", "")),
		"actor_player_index": int(request.get("actor_player_index", -1)),
		"hand_slot_id": str(request.get("hand_slot_id", "")),
		"card_instance_id": str(request.get("card_instance_id", "")),
		"card_semantic_id": str(request.get("card_semantic_id", "")),
		"escrow_id": escrow_id,
		"expected_resolution_id": expected_resolution_id \
			if expected_resolution_id > 0 else -1,
		"reason_code": reason_code,
	}


func _blocked_owner_compensation(
	compensation_kind_id: String,
	owner_id: String,
	required: bool,
	commit_expected: bool
) -> Dictionary:
	return _owner_compensation(
		compensation_kind_id,
		owner_id,
		required,
		commit_expected,
		false,
		false,
		false,
		false,
		"blocked_by_queue",
		"facility_submission_dependency_blocked_by_queue"
	)


func _recover_submission_if_present(request: Dictionary) -> Dictionary:
	var escrow_id := _escrow_id(request)
	var reservation_id := _asset_reservation_id(request)
	var escrow_snapshot := _card_state.facility_card_escrow_snapshot(escrow_id)
	var reservation_status := _mana.reservation_settlement_snapshot(reservation_id)
	var escrow_receipt: Dictionary = escrow_snapshot.get("receipt", {}) \
		if escrow_snapshot.get("receipt", {}) is Dictionary else {}
	if bool(escrow_snapshot.get("terminal", false)) \
			and str(escrow_receipt.get("state_id", "")) == "consumed_finalized":
		return {
			"detected": true,
			"result": _terminal_submission_replay({"finalized": true}),
		}
	var recovery_reason := _submission_recovery_reason(
		escrow_snapshot,
		reservation_status
	)
	var queue_request := _queue_rollback_request(
		request,
		escrow_id,
		-1,
		recovery_reason
	)
	var queue_status := _queue.facility_submission_status(
		_queue_rollback_capability,
		queue_request
	)
	var queue_status_valid := _queue_submission_status_valid(queue_status)
	var queue_present := queue_status_valid \
		and bool(queue_status.get("commitment_found", false))
	var escrow_present := bool(escrow_snapshot.get("found", false)) \
		or bool(escrow_snapshot.get("terminal", false))
	var reservation_present := bool(reservation_status.get("found", false))
	var compensation_started := bool(escrow_snapshot.get("terminal", false)) \
		or str(reservation_status.get("outcome_id", "")) == "released"
	if queue_present and not compensation_started:
		return {
			"detected": true,
			"result": _queued_submission_replay(queue_status),
		}
	if not queue_present and not escrow_present and not reservation_present \
			and queue_status_valid:
		return {"detected": false, "result": {}}
	var queue_receipt := _queue.rollback_facility_submission(
		_queue_rollback_capability,
		queue_request
	)
	var escrow_fingerprint := _escrow_fingerprint_from_snapshot(
		escrow_snapshot,
		""
	)
	var reservation_required := reservation_present \
		and str(reservation_status.get("outcome_id", "missing")) != "missing"
	var settlement := _rollback_submission_owners(
		request,
		escrow_id,
		escrow_fingerprint,
		escrow_present,
		reservation_id if reservation_required else "",
		reservation_required,
		reservation_present,
		queue_present,
		int(queue_receipt.get("resolution_id", -1)),
		recovery_reason,
		queue_receipt
	)
	return {
		"detected": true,
		"result": _submission_failure(recovery_reason, settlement),
	}


func _queue_submission_status_valid(status: Dictionary) -> bool:
	var fields := [
		"schema_version",
		"status_kind_id",
		"valid",
		"commitment_found",
		"active",
		"state_verified",
		"resolution_id",
		"queue_revision",
		"binding_fingerprint",
		"outcome_id",
		"reason_code",
	]
	return SemanticWire.is_closed_data(status) \
		and SemanticWire.exact_fields(status, fields) \
		and status.get("schema_version") == 1 \
		and str(status.get("status_kind_id", "")) \
			== "facility_queue_submission_status" \
		and status.get("valid") is bool \
		and bool(status.get("valid", false)) \
		and status.get("commitment_found") is bool \
		and status.get("active") is bool \
		and status.get("state_verified") is bool \
		and bool(status.get("state_verified", false)) \
		and status.get("resolution_id") is int \
		and status.get("queue_revision") is int \
		and status.get("binding_fingerprint") is String \
		and SemanticWire.is_stable_id(status.get("outcome_id")) \
		and SemanticWire.is_stable_id(status.get("reason_code"))


func _queued_submission_replay(status: Dictionary) -> Dictionary:
	_last_reason_code = "facility_card_queued_replay"
	return {
		"accepted": true,
		"queued": true,
		"committed": false,
		"reason_code": _last_reason_code,
		"resolution_id": int(status.get("resolution_id", -1)),
		"queue_revision": int(status.get("queue_revision", 0)),
		"binding_fingerprint": str(status.get("binding_fingerprint", "")),
		"idempotent_replay": true,
	}


func _submission_recovery_reason(
	escrow_snapshot: Dictionary,
	reservation_status: Dictionary
) -> String:
	var escrow_receipt: Dictionary = escrow_snapshot.get("receipt", {}) \
		if escrow_snapshot.get("receipt", {}) is Dictionary else {}
	var escrow_reason := _safe_reason(str(escrow_receipt.get("reason_code", "")))
	if not escrow_receipt.is_empty() and escrow_reason != "facility_queue_rejected":
		return escrow_reason
	var reservation_receipt: Dictionary = reservation_status.get("terminal_receipt", {}) \
		if reservation_status.get("terminal_receipt", {}) is Dictionary else {}
	var reservation_reason := _safe_reason(str(reservation_receipt.get("reason", "")))
	if not reservation_receipt.is_empty() \
			and reservation_reason != "facility_queue_rejected":
		return reservation_reason
	return "facility_queue_submission_recovery_replay"


func _escrow_fingerprint_from_snapshot(
	snapshot: Dictionary,
	fallback: String
) -> String:
	var escrow: Dictionary = snapshot.get("escrow", {}) \
		if snapshot.get("escrow", {}) is Dictionary else {}
	if SemanticWire.is_fingerprint(escrow.get("escrow_fingerprint")):
		return str(escrow.get("escrow_fingerprint", ""))
	var receipt: Dictionary = snapshot.get("receipt", {}) \
		if snapshot.get("receipt", {}) is Dictionary else {}
	if SemanticWire.is_fingerprint(receipt.get("escrow_fingerprint")):
		return str(receipt.get("escrow_fingerprint", ""))
	return fallback if SemanticWire.is_fingerprint(fallback) else ""


func _settle_submission_reservation(
	reservation_id: String,
	required: bool,
	commit_expected: bool,
	reason_code: String
) -> Dictionary:
	if not required:
		return _owner_compensation(
			"reservation_release",
			"player_mana",
			false,
			false,
			false,
			true,
			true,
			true,
			"not_required",
			"facility_submission_reservation_not_required"
		)
	if reservation_id.is_empty():
		return _owner_compensation(
			"reservation_release",
			"player_mana",
			true,
			commit_expected,
			false,
			false,
			false,
			false,
			"reservation_id_missing",
			"facility_submission_reservation_id_missing"
		)
	var status := _mana.reservation_settlement_snapshot(reservation_id)
	var outcome_id := str(status.get("outcome_id", "missing"))
	if outcome_id == "missing":
		var missing_settled := not commit_expected
		return _owner_compensation(
			"reservation_release",
			"player_mana",
			true,
			commit_expected,
			false,
			missing_settled,
			missing_settled,
			missing_settled,
			"not_committed" if missing_settled else "missing",
			"facility_submission_reservation_not_committed" if missing_settled \
				else "facility_submission_reservation_missing"
		)
	if outcome_id == "released":
		var replay_verified := _released_reservation_status_valid(status, reservation_id)
		return _owner_compensation(
			"reservation_release",
			"player_mana",
			true,
			commit_expected,
			false,
			replay_verified,
			replay_verified,
			replay_verified,
			"released" if replay_verified else "released_receipt_invalid",
			"facility_submission_reservation_already_released" if replay_verified \
				else "facility_submission_reservation_receipt_invalid"
		)
	if outcome_id != "pending":
		return _owner_compensation(
			"reservation_release",
			"player_mana",
			true,
			commit_expected,
			false,
			false,
			false,
			false,
			outcome_id,
			"facility_submission_reservation_state_invalid"
		)
	var active_reservation: Dictionary = status.get("reservation", {}) \
		if status.get("reservation", {}) is Dictionary else {}
	if str(active_reservation.get("transaction_id", "")) != reservation_id \
			or not SemanticWire.is_fingerprint(active_reservation.get("fingerprint")):
		return _owner_compensation(
			"reservation_release",
			"player_mana",
			true,
			commit_expected,
			false,
			false,
			false,
			false,
			"pending_binding_invalid",
			"facility_submission_reservation_binding_invalid"
		)
	var release := _mana.release_reservation(reservation_id, reason_code)
	var receipt_valid := _is_finite_pure_data(release) \
		and bool(release.get("committed", false)) \
		and bool(release.get("authorized", false)) \
		and bool(release.get("settled", false)) \
		and str(release.get("transaction_id", "")) == reservation_id \
		and str(release.get("outcome", "")) == "released"
	var state_verified := _released_reservation_status_valid(
		_mana.reservation_settlement_snapshot(reservation_id),
		reservation_id
	)
	var settled := receipt_valid and state_verified
	return _owner_compensation(
		"reservation_release",
		"player_mana",
		true,
		commit_expected,
		true,
		receipt_valid,
		state_verified,
		settled,
		"released" if settled else "release_incomplete",
		"facility_submission_reservation_released" if settled \
			else "facility_submission_reservation_release_incomplete"
	)


func _settle_submission_escrow(
	escrow_id: String,
	escrow_fingerprint: String,
	commit_expected: bool,
	reason_code: String
) -> Dictionary:
	var snapshot := _card_state.facility_card_escrow_snapshot(escrow_id)
	if bool(snapshot.get("terminal", false)):
		var replay_verified := _released_escrow_snapshot_valid(
			snapshot,
			escrow_id,
			escrow_fingerprint,
			reason_code
		)
		return _owner_compensation(
			"card_escrow_release",
			"world_session_state",
			true,
			commit_expected,
			false,
			replay_verified,
			replay_verified,
			replay_verified,
			"released" if replay_verified else "terminal_receipt_invalid",
			"facility_submission_escrow_already_released" if replay_verified \
				else "facility_submission_escrow_terminal_invalid"
		)
	if not bool(snapshot.get("found", false)):
		var missing_settled := not commit_expected
		return _owner_compensation(
			"card_escrow_release",
			"world_session_state",
			true,
			commit_expected,
			false,
			missing_settled,
			missing_settled,
			missing_settled,
			"not_committed" if missing_settled else "missing",
			"facility_submission_escrow_not_committed" if missing_settled \
				else "facility_submission_escrow_missing"
		)
	var escrow: Dictionary = snapshot.get("escrow", {}) \
		if snapshot.get("escrow", {}) is Dictionary else {}
	if str(escrow.get("escrow_id", "")) != escrow_id \
			or str(escrow.get("escrow_fingerprint", "")) != escrow_fingerprint \
			or not SemanticWire.is_fingerprint(escrow_fingerprint):
		return _owner_compensation(
			"card_escrow_release",
			"world_session_state",
			true,
			commit_expected,
			false,
			false,
			false,
			false,
			"binding_invalid",
			"facility_submission_escrow_binding_invalid"
		)
	var release := _card_state.release_facility_card_escrow(
		escrow_id,
		escrow_fingerprint,
		reason_code
	)
	var receipt_valid := SemanticWire.is_closed_data(release) \
		and bool(release.get("released", false)) \
		and bool(release.get("terminal", false)) \
		and str(release.get("escrow_id", "")) == escrow_id \
		and str(release.get("state_id", "")) == "released" \
		and str(release.get("escrow_fingerprint", "")) == escrow_fingerprint \
		and SemanticWire.is_fingerprint(release.get("receipt_fingerprint"))
	var state_verified := _released_escrow_snapshot_valid(
		_card_state.facility_card_escrow_snapshot(escrow_id),
		escrow_id,
		escrow_fingerprint,
		reason_code
	)
	var settled := receipt_valid and state_verified
	return _owner_compensation(
		"card_escrow_release",
		"world_session_state",
		true,
		commit_expected,
		true,
		receipt_valid,
		state_verified,
		settled,
		"released" if settled else "release_incomplete",
		"facility_submission_escrow_released" if settled \
			else "facility_submission_escrow_release_incomplete"
	)


func _released_reservation_status_valid(status: Dictionary, reservation_id: String) -> bool:
	var receipt: Dictionary = status.get("terminal_receipt", {}) \
		if status.get("terminal_receipt", {}) is Dictionary else {}
	return _is_finite_pure_data(status) \
		and bool(status.get("found", false)) \
		and str(status.get("state_id", "")) == "terminal" \
		and str(status.get("outcome_id", "")) == "released" \
		and str(receipt.get("transaction_id", "")) == reservation_id \
		and bool(receipt.get("committed", false)) \
		and bool(receipt.get("authorized", false)) \
		and bool(receipt.get("settled", false)) \
		and str(receipt.get("outcome", "")) == "released"


func _released_escrow_snapshot_valid(
	snapshot: Dictionary,
	escrow_id: String,
	escrow_fingerprint: String,
	reason_code: String
) -> bool:
	var receipt: Dictionary = snapshot.get("receipt", {}) \
		if snapshot.get("receipt", {}) is Dictionary else {}
	return _is_finite_pure_data(snapshot) \
		and not bool(snapshot.get("found", true)) \
		and bool(snapshot.get("terminal", false)) \
		and str(receipt.get("state_id", "")) == "released" \
		and str(receipt.get("escrow_id", "")) == escrow_id \
		and str(receipt.get("escrow_fingerprint", "")) == escrow_fingerprint \
		and str(receipt.get("reason_code", "")) == reason_code \
		and SemanticWire.is_fingerprint(receipt.get("receipt_fingerprint"))


func _owner_compensation(
	compensation_kind_id: String,
	owner_id: String,
	required: bool,
	commit_expected: bool,
	attempted: bool,
	receipt_valid: bool,
	state_verified: bool,
	settled: bool,
	outcome_id: String,
	reason_code: String
) -> Dictionary:
	return {
		"schema_version": SUBMISSION_SETTLEMENT_SCHEMA_VERSION,
		"compensation_kind_id": compensation_kind_id,
		"owner_id": owner_id,
		"required": required,
		"commit_expected": commit_expected,
		"attempted": attempted,
		"receipt_valid": receipt_valid,
		"state_verified": state_verified,
		"settled": settled,
		"outcome_id": outcome_id,
		"reason_code": reason_code,
	}


func _submission_settlement_valid(settlement: Dictionary) -> bool:
	if not SemanticWire.is_closed_data(settlement) \
			or not SemanticWire.exact_fields(settlement, SUBMISSION_SETTLEMENT_FIELDS) \
			or settlement.get("schema_version") != SUBMISSION_SETTLEMENT_SCHEMA_VERSION \
			or str(settlement.get("settlement_kind_id", "")) != SUBMISSION_SETTLEMENT_KIND_ID \
			or not (settlement.get("settled") is bool) \
			or not SemanticWire.is_stable_id(settlement.get("original_failure_reason_code")) \
			or str(settlement.get("reason_code", "")) \
				not in [
					"facility_queue_submission_compensated",
					"facility_queue_submission_compensation_incomplete",
				]:
		return false
	var expected_compensations := {
		"queue_compensation": ["queue_submission_rollback", "card_resolution_queue"],
		"reservation_compensation": ["reservation_release", "player_mana"],
		"escrow_compensation": ["card_escrow_release", "world_session_state"],
	}
	var all_settled := true
	for field_id in expected_compensations:
		var compensation: Dictionary = settlement.get(field_id, {}) \
			if settlement.get(field_id, {}) is Dictionary else {}
		var expected: Array = expected_compensations.get(field_id, [])
		if not SemanticWire.exact_fields(compensation, OWNER_COMPENSATION_FIELDS) \
				or compensation.get("schema_version") != SUBMISSION_SETTLEMENT_SCHEMA_VERSION \
				or str(compensation.get("compensation_kind_id", "")) != str(expected[0]) \
				or str(compensation.get("owner_id", "")) != str(expected[1]) \
				or not SemanticWire.is_stable_id(compensation.get("outcome_id")) \
				or not SemanticWire.is_stable_id(compensation.get("reason_code")):
			return false
		for boolean_field in [
			"required",
			"commit_expected",
			"attempted",
			"receipt_valid",
			"state_verified",
			"settled",
		]:
			if not (compensation.get(boolean_field) is bool):
				return false
		all_settled = all_settled and bool(compensation.get("settled", false))
	var settled := bool(settlement.get("settled", false))
	return settled == all_settled \
		and str(settlement.get("reason_code", "")) \
			== ("facility_queue_submission_compensated" if settled \
				else "facility_queue_submission_compensation_incomplete")


func _invalid_submission_settlement(reason_code: String) -> Dictionary:
	return {
		"schema_version": SUBMISSION_SETTLEMENT_SCHEMA_VERSION,
		"settlement_kind_id": SUBMISSION_SETTLEMENT_KIND_ID,
		"settled": false,
		"original_failure_reason_code": _safe_reason(reason_code),
		"reason_code": "facility_queue_submission_compensation_incomplete",
		"queue_compensation": _owner_compensation(
			"queue_submission_rollback",
			"card_resolution_queue",
			true,
			true,
			false,
			false,
			false,
			false,
			"settlement_invalid",
			"facility_submission_settlement_invalid"
		),
		"reservation_compensation": _owner_compensation(
			"reservation_release",
			"player_mana",
			true,
			true,
			false,
			false,
			false,
			false,
			"settlement_invalid",
			"facility_submission_settlement_invalid"
		),
		"escrow_compensation": _owner_compensation(
			"card_escrow_release",
			"world_session_state",
			true,
			true,
			false,
			false,
			false,
			false,
			"settlement_invalid",
			"facility_submission_settlement_invalid"
		),
	}


func _submission_failure(reason_code: String, settlement: Dictionary) -> Dictionary:
	var original_reason := _safe_reason(reason_code)
	var closed_settlement := settlement.duplicate(true) \
		if _submission_settlement_valid(settlement) \
			and str(settlement.get("original_failure_reason_code", "")) == original_reason \
		else _invalid_submission_settlement(original_reason)
	var settled := bool(closed_settlement.get("settled", false))
	var public_reason := original_reason if settled \
		else "facility_queue_submission_compensation_incomplete"
	var result := _reject(public_reason)
	result["commitment_settled"] = settled
	result["requires_recovery"] = not settled
	result["failure_reason_code"] = original_reason
	result["submission_settlement"] = closed_settlement
	return result


func _terminal_submission_replay(receipt: Dictionary) -> Dictionary:
	_last_reason_code = "facility_queue_request_replay_terminal"
	return {
		"accepted": false,
		"queued": false,
		"committed": bool(receipt.get("finalized", false)),
		"terminal": true,
		"idempotent_replay": true,
		"reason_code": _last_reason_code,
	}


func _resolution_failure(reason_code: String, settlement: Dictionary) -> Dictionary:
	return {
		"handled": true,
		"resolved": false,
		"finalized": false,
		"commitment_settled": bool(settlement.get("settled", false)),
		"reason_code": reason_code,
	}


func _reject(reason_code: String) -> Dictionary:
	_rejection_count += 1
	_last_reason_code = reason_code
	return {
		"accepted": false,
		"queued": false,
		"committed": false,
		"reason_code": reason_code,
	}


func _dependencies_ready() -> bool:
	return _world != null and _session != null and _queue != null and _resolution != null \
		and _card_state != null and _mana != null and _core != null \
		and _infrastructure != null and _catalog != null \
		and _submission_port != null and _submission_capability != null \
		and _queue_rollback_capability != null \
		and _catalog.has_method("card_snapshot")


func _escrow_id(request: Dictionary) -> String:
	return "facility.escrow.%s" % SemanticWire.fingerprint({
		"request_id": request.get("request_id"),
		"intent_fingerprint": request.get("intent_fingerprint"),
		"card_instance_id": request.get("card_instance_id"),
	}).substr(0, 32)


func _asset_reservation_id(request: Dictionary) -> String:
	return "card-asset.%s" % SemanticWire.fingerprint({
		"request_id": request.get("request_id"),
		"intent_fingerprint": request.get("intent_fingerprint"),
		"card_instance_id": request.get("card_instance_id"),
		"actor_id": request.get("actor_id"),
	}).substr(0, 32)


func _safe_reason(reason_code: String) -> String:
	var normalized := reason_code.strip_edges().to_lower().replace("-", "_")
	if SemanticWire.is_stable_id(normalized):
		return normalized
	return "facility_queue_rejected"


func _stable_data_fingerprint(value: Variant) -> String:
	if not _is_finite_pure_data(value):
		return ""
	return JSON.stringify(_canonicalize(value)).sha256_text().to_lower()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize((value as Dictionary).get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value as Array:
			result.append(_canonicalize(item_variant))
		return result
	return value


func _is_finite_pure_data(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is float and not is_finite(value):
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not _is_finite_pure_data(key_variant) \
					or not _is_finite_pure_data((value as Dictionary).get(key_variant)):
				return false
	elif value is Array:
		for item_variant in value as Array:
			if not _is_finite_pure_data(item_variant):
				return false
	return true
