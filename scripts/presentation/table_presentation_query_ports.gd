@tool
extends Node
class_name TablePresentationQueryPorts

signal victory_presentation_receipt_ready(receipt: VictoryPresentationStateChangeReceipt)

const OUTCOME_PRESENTATION_RESULT_KEYS := [
	"schema_version", "receipt_id", "accepted", "duplicate", "reason_id", "outcome_id",
]
const FINAL_SETTLEMENT_PUBLIC_LOG_ACK_KEYS := [
	"schema_version",
	"receipt_id",
	"outcome_id",
	"receipt_fingerprint",
	"accepted",
	"duplicate",
	"reason_id",
]
const PUBLIC_LOG_BINDING_KEYS := ["event_kind", "source_revision", "receipt_fingerprint"]
const SESSION_RESET_REASON_IDS := ["session_began", "session_reset"]
const SESSION_PLAN_APPLIED_REASON_ID := "session_plan_applied"
const SESSION_CHECKPOINT_ROLLED_BACK_REASON_ID := "session_checkpoint_rolled_back"
const SESSION_SAVE_APPLIED_REASON_ID := "session_save_applied"
const SESSION_LOAD_COMPLETED_REASON_ID := "session_load_completed"
const SESSION_PLAN_CHECKPOINT_KEYS := [
	"schema_version",
	"public_log_owner",
	"public_log_producer_port",
	"victory_receipts",
	"viewer_private_feedback",
	"outcome_presentation_results",
	"outcome_presentation_accepted_count",
	"outcome_presentation_rejected_count",
	"outcome_immediate_refresh_receipt_ids",
]

var local_viewer_authorization: LocalViewerAuthorization
var world_session_query: WorldSessionPresentationQuery
var action_query: TableActionPresentationQuery
var public_map_query: TablePublicMapQuery
var public_log_owner: PublicLogPresentationOwner
var public_log_port: PublicLogProducerPort
var victory_receipt_service: VictoryPresentationReceiptService
var viewer_private_feedback_owner: ViewerPrivateFeedbackOwner
var region_infrastructure_public_query: RegionInfrastructureWorldBridge

var _configured := false
var _outcome_presentation_results: Dictionary = {}
var _outcome_presentation_accepted_count := 0
var _outcome_presentation_rejected_count := 0
var _outcome_immediate_refresh_receipt_ids: Dictionary = {}
var _session_plan_checkpoint: Dictionary = {}
var _session_checkpoint_epoch := 0
var _session_checkpoint_kind := ""


func configure(
	world_session_state: WorldSessionState,
	selection: TableSelectionState,
	forced_scheduler: ForcedDecisionRuntimeScheduler,
	purchase: DistrictPurchaseRuntimeController,
	target_choice: CardTargetChoiceRuntimeController,
	card_resolution: CardResolutionRuntimeController,
	queue: CardResolutionQueueRuntimeService,
	history: CardResolutionHistoryRuntimeService,
	monster: MonsterRuntimeController,
	military: MilitaryRuntimeController,
	commodity_flow: CommodityFlowRuntimeController,
	victory: VictoryControlRuntimeController,
	region_infrastructure_query: RegionInfrastructureWorldBridge = null
) -> void:
	_resolve_children()
	if local_viewer_authorization == null or world_session_query == null or action_query == null \
		or public_map_query == null or public_log_owner == null or public_log_port == null \
		or victory_receipt_service == null or viewer_private_feedback_owner == null:
		_configured = false
		return
	local_viewer_authorization.configure(world_session_state)
	world_session_query.configure(world_session_state, local_viewer_authorization)
	action_query.configure(local_viewer_authorization, world_session_query, selection, forced_scheduler, purchase, target_choice, card_resolution, queue, history)
	public_map_query.configure(world_session_state, local_viewer_authorization, world_session_query, selection, monster, military, commodity_flow)
	public_log_port.configure(public_log_owner)
	victory_receipt_service.configure(victory, world_session_query, public_map_query, public_log_port)
	region_infrastructure_public_query = region_infrastructure_query
	if not victory_receipt_service.outcome_presentation_ready.is_connected(_on_outcome_presentation_ready):
		victory_receipt_service.outcome_presentation_ready.connect(_on_outcome_presentation_ready)
	_configured = true


func reset_state() -> void:
	_discard_session_plan_checkpoint()
	_reset_presentation_journals()


func _reset_presentation_journals() -> void:
	_resolve_children()
	if public_log_owner != null:
		public_log_owner.reset_state()
	if public_log_port != null:
		public_log_port.reset_state()
	if victory_receipt_service != null:
		victory_receipt_service.reset_state()
	if viewer_private_feedback_owner != null:
		viewer_private_feedback_owner.reset_state()
	_outcome_presentation_results.clear()
	_outcome_presentation_accepted_count = 0
	_outcome_presentation_rejected_count = 0
	_outcome_immediate_refresh_receipt_ids.clear()


func _on_session_authorization_context_changed(reason_id: String) -> void:
	if reason_id == SESSION_PLAN_APPLIED_REASON_ID:
		_begin_session_checkpoint(SESSION_PLAN_APPLIED_REASON_ID)
	elif reason_id == SESSION_CHECKPOINT_ROLLED_BACK_REASON_ID:
		_restore_session_checkpoint(SESSION_PLAN_APPLIED_REASON_ID)
	elif reason_id == SESSION_SAVE_APPLIED_REASON_ID:
		if _session_checkpoint_kind == SESSION_SAVE_APPLIED_REASON_ID:
			_restore_session_checkpoint(SESSION_SAVE_APPLIED_REASON_ID)
		else:
			_begin_session_checkpoint(SESSION_SAVE_APPLIED_REASON_ID)
	elif reason_id == SESSION_LOAD_COMPLETED_REASON_ID:
		_discard_session_plan_checkpoint()
		_reset_presentation_journals()
	elif SESSION_RESET_REASON_IDS.has(reason_id):
		reset_state()


func authorized_viewer_index() -> int:
	return local_viewer_authorization.authorized_viewer_index()


func viewer_context() -> TablePresentationViewerContext:
	return local_viewer_authorization.context()


func can_view_private_subject(viewer_index: int, subject_index: int) -> bool:
	return local_viewer_authorization.can_view_subject(viewer_index, subject_index)


func public_world_projection() -> WorldSessionPublicProjection:
	return world_session_query.public_projection()


func public_map_geometry_projection() -> WorldMapGeometryProjection:
	return world_session_query.public_map_geometry_projection()


func private_world_projection(viewer_index: int, subject_index: int) -> WorldSessionPrivateProjection:
	return world_session_query.private_projection(viewer_index, subject_index)


func action_projection(viewer_index: int) -> TableActionPresentationProjection:
	return action_query.snapshot_for_viewer(viewer_index)


func public_card_track_snapshot() -> Dictionary:
	return action_query.public_card_track_snapshot()


func public_map_projection(viewer_index: int, commodity_id := "") -> TablePublicMapProjection:
	return public_map_query.snapshot_for_viewer(viewer_index, commodity_id)


func public_new_facility_target_candidates(
	facility_kind: StringName,
	industry_id: StringName
) -> PublicFacilityTargetCandidatesSnapshot:
	if region_infrastructure_public_query == null \
			or not region_infrastructure_public_query.has_method("public_new_facility_target_candidates"):
		return PublicFacilityTargetCandidatesSnapshot.from_dictionary({
			"facility_kind": str(facility_kind),
			"industry_id": str(industry_id),
		})
	var value_variant: Variant = region_infrastructure_public_query.public_new_facility_target_candidates(
		facility_kind,
		industry_id
	)
	var value: Dictionary = value_variant if value_variant is Dictionary else {}
	return PublicFacilityTargetCandidatesSnapshot.from_dictionary(value)


func selected_map_layer_focus() -> String:
	return action_query.selected_map_layer_focus() if action_query != null else "all"


func monster_wager_presentation_for_viewer(viewer_index: int) -> Dictionary:
	if not can_view_private_subject(viewer_index, viewer_index):
		return {}
	return public_map_query.monster_wager_presentation_for_viewer(viewer_index)


func publish_public_log(
	event_kind: StringName,
	localization_key: StringName,
	public_values: Dictionary,
	source_revision: int,
	world_time: float,
	receipt_id := ""
) -> Dictionary:
	return public_log_port.publish(event_kind, localization_key, public_values, source_revision, world_time, receipt_id)


func append_public_log_receipt(receipt: PublicLogReceipt) -> Dictionary:
	return public_log_port.append_receipt(receipt)


func acknowledge_final_settlement_public_log(
	receipt: PublicLogReceipt,
	acknowledgement: Dictionary
) -> void:
	var result := _final_settlement_public_log_acknowledgement(receipt)
	acknowledgement.clear()
	for key_variant in FINAL_SETTLEMENT_PUBLIC_LOG_ACK_KEYS:
		acknowledgement[str(key_variant)] = result.get(str(key_variant))


func recent_public_log_messages(limit := 6) -> Array:
	return public_log_owner.recent_public_messages(limit)


func recent_public_log_entries(limit := 6) -> Array:
	return public_log_owner.recent_public_entries(limit)


func record_viewer_private_feedback(viewer_index: int, message: String) -> Dictionary:
	if not can_view_private_subject(viewer_index, viewer_index):
		return {"applied": false, "reason_code": "viewer_private_feedback_unauthorized"}
	return viewer_private_feedback_owner.append_for_viewer(viewer_index, message)


func recent_viewer_private_feedback(viewer_index: int, limit := 6) -> Array:
	if not can_view_private_subject(viewer_index, viewer_index):
		return []
	return viewer_private_feedback_owner.recent_for_viewer(viewer_index, limit)


func viewer_private_feedback_revision(viewer_index: int) -> int:
	if viewer_private_feedback_owner == null \
			or not can_view_private_subject(viewer_index, viewer_index):
		return -1
	return viewer_private_feedback_owner.current_revision()


func recent_viewer_private_feedback_entries(viewer_index: int, limit := 6) -> Array:
	var source_revision := viewer_private_feedback_revision(viewer_index)
	if source_revision < 0:
		return []
	var result: Array = []
	for message_variant in viewer_private_feedback_owner.recent_for_viewer(viewer_index, limit):
		if not (message_variant is String):
			return []
		result.append({
			"message": str(message_variant),
			"source_revision": source_revision,
		})
	return result


func import_legacy_viewer_feedback(messages: Array) -> Dictionary:
	var viewer := authorized_viewer_index()
	if viewer < 0:
		return {"applied": 0, "reason_code": "viewer_private_feedback_unauthorized"}
	var applied := 0
	for message_variant in messages:
		if bool(viewer_private_feedback_owner.append_for_viewer(viewer, str(message_variant)).get("applied", false)):
			applied += 1
	return {"applied": applied, "reason_code": ""}


func reset_public_log() -> void:
	public_log_owner.reset_state()
	public_log_port.reset_state()


func capture_victory_advance(result: Dictionary) -> VictoryPresentationStateChangeReceipt:
	var receipt := victory_receipt_service.capture_advance_result(result)
	if receipt != null:
		victory_presentation_receipt_ready.emit(receipt)
	return receipt


func capture_victory_outcome(public_snapshot: Dictionary) -> VictoryPresentationStateChangeReceipt:
	var outcome: Dictionary = public_snapshot.get("outcome_receipt", {}) \
		if public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
	var outcome_id := str(outcome.get("outcome_id", "")).strip_edges()
	if outcome_id.is_empty() or victory_receipt_service == null:
		return null
	var receipt := victory_receipt_service.capture_outcome(public_snapshot)
	if receipt == null:
		return null
	var result: Dictionary = _outcome_presentation_results.get(receipt.receipt_id, {}) \
		if _outcome_presentation_results.get(receipt.receipt_id, {}) is Dictionary else {}
	if bool(result.get("accepted", false)) \
			and str(result.get("outcome_id", "")) == outcome_id \
			and victory_outcome_refresh_complete(receipt):
		_outcome_presentation_accepted_count += 1
		return receipt
	_outcome_presentation_rejected_count += 1
	victory_receipt_service.release_outcome_for_retry(receipt)
	return null


func record_victory_outcome_presentation_result(result: Dictionary) -> bool:
	if not _outcome_presentation_result_valid(result):
		return false
	var receipt_id := str(result.get("receipt_id", "")).strip_edges()
	var normalized := result.duplicate(true)
	if _outcome_presentation_results.has(receipt_id):
		return _outcome_presentation_results.get(receipt_id) == normalized
	_outcome_presentation_results[receipt_id] = normalized
	return true


func pending_accepted_victory_outcome_refresh_kinds(
	receipt: VictoryPresentationStateChangeReceipt
) -> Array[StringName]:
	var context := _accepted_outcome_refresh_context(receipt)
	if context.is_empty():
		return []
	var lineage: Dictionary = _outcome_immediate_refresh_receipt_ids.get(receipt.receipt_id, {}) \
		if _outcome_immediate_refresh_receipt_ids.get(receipt.receipt_id, {}) is Dictionary else {}
	if not lineage.is_empty() and not _outcome_refresh_lineage_matches(lineage, context):
		return []
	var applied_kinds: Dictionary = lineage.get("applied_kinds", {}) \
		if lineage.get("applied_kinds", {}) is Dictionary else {}
	var pending: Array[StringName] = []
	for kind_variant in context.get("required_kinds", []) as Array:
		var kind := str(kind_variant)
		if not applied_kinds.has(kind):
			pending.append(StringName(kind))
	return pending


func record_victory_outcome_refresh_result(
	receipt: VictoryPresentationStateChangeReceipt,
	apply_receipt: TablePresentationApplyReceipt
) -> bool:
	var context := _accepted_outcome_refresh_context(receipt)
	if context.is_empty() or apply_receipt == null or not apply_receipt.applied \
			or not apply_receipt.reason_code.is_empty() \
			or apply_receipt.refresh_receipt_id.strip_edges().is_empty():
		return false
	var kind := str(apply_receipt.kind)
	if not (context.get("required_kinds", []) as Array).has(kind):
		return false
	var lineage: Dictionary = _outcome_immediate_refresh_receipt_ids.get(receipt.receipt_id, {}) \
		if _outcome_immediate_refresh_receipt_ids.get(receipt.receipt_id, {}) is Dictionary else {}
	if lineage.is_empty():
		lineage = {
			"outcome_id": str(context.get("outcome_id", "")),
			"required_kinds": (context.get("required_kinds", []) as Array).duplicate(),
			"applied_kinds": {},
		}
	elif not _outcome_refresh_lineage_matches(lineage, context):
		return false
	var applied_kinds := (lineage.get("applied_kinds", {}) as Dictionary).duplicate(true)
	var applied_binding := {
		"refresh_receipt_id": apply_receipt.refresh_receipt_id,
		"sequence": apply_receipt.sequence,
		"kind": kind,
		"snapshot_revision": apply_receipt.snapshot_revision,
		"target_revision": apply_receipt.target_revision,
	}
	if applied_kinds.has(kind):
		return applied_kinds.get(kind) == applied_binding
	applied_kinds[kind] = applied_binding
	lineage["applied_kinds"] = applied_kinds
	_outcome_immediate_refresh_receipt_ids[receipt.receipt_id] = lineage
	return true


func victory_outcome_refresh_complete(receipt: VictoryPresentationStateChangeReceipt) -> bool:
	var context := _accepted_outcome_refresh_context(receipt)
	if context.is_empty() or (context.get("required_kinds", []) as Array).is_empty():
		return false
	var lineage: Dictionary = _outcome_immediate_refresh_receipt_ids.get(receipt.receipt_id, {}) \
		if _outcome_immediate_refresh_receipt_ids.get(receipt.receipt_id, {}) is Dictionary else {}
	if not _outcome_refresh_lineage_matches(lineage, context):
		return false
	var applied_kinds: Dictionary = lineage.get("applied_kinds", {}) \
		if lineage.get("applied_kinds", {}) is Dictionary else {}
	for kind_variant in context.get("required_kinds", []) as Array:
		if not applied_kinds.has(str(kind_variant)):
			return false
	return true


func debug_snapshot() -> Dictionary:
	_resolve_children()
	if local_viewer_authorization == null or world_session_query == null or action_query == null \
		or public_map_query == null or public_log_owner == null or victory_receipt_service == null \
		or viewer_private_feedback_owner == null:
		return {"configured": false, "references_main": false, "owns_refresh_cadence": false, "owns_ui_targets": false}
	return {
		"configured": _configured,
		"local_viewer": local_viewer_authorization.debug_snapshot(),
		"world_query": world_session_query.debug_snapshot(),
		"action_query": action_query.debug_snapshot(),
		"map_query": public_map_query.debug_snapshot(),
		"public_new_facility_target_query_ready": region_infrastructure_public_query != null,
		"public_log": public_log_owner.debug_snapshot(),
		"viewer_private_feedback": viewer_private_feedback_owner.debug_snapshot(),
		"victory_receipts": victory_receipt_service.debug_snapshot(),
		"outcome_presentation_result_count": _outcome_presentation_results.size(),
		"outcome_presentation_accepted_count": _outcome_presentation_accepted_count,
		"outcome_presentation_rejected_count": _outcome_presentation_rejected_count,
		"outcome_immediate_refresh_count": _outcome_immediate_refresh_receipt_ids.size(),
		"session_plan_checkpoint_pending": not _session_plan_checkpoint.is_empty(),
		"lifecycle_checkpoint_pending": not _session_plan_checkpoint.is_empty(),
		"lifecycle_transition_kind": _session_checkpoint_kind,
		"session_lifecycle_checkpoint_kind": _session_checkpoint_kind,
		"requires_outcome_presentation_acceptance": true,
		"owns_refresh_cadence": false,
		"owns_ui_targets": false,
		"references_main": false,
	}


func _begin_session_checkpoint(checkpoint_kind: String) -> void:
	_resolve_children()
	var checkpoint := _capture_session_plan_checkpoint()
	if checkpoint.is_empty():
		return
	_session_checkpoint_epoch += 1
	var checkpoint_epoch := _session_checkpoint_epoch
	_session_plan_checkpoint = checkpoint
	_session_checkpoint_kind = checkpoint_kind
	_reset_presentation_journals()
	call_deferred("_finalize_session_plan_checkpoint", checkpoint_epoch)


func _capture_session_plan_checkpoint() -> Dictionary:
	if public_log_owner == null or public_log_port == null or victory_receipt_service == null \
			or viewer_private_feedback_owner == null \
			or not public_log_owner.has_method("capture_session_checkpoint") \
			or not public_log_port.has_method("capture_session_checkpoint") \
			or not victory_receipt_service.has_method("capture_session_checkpoint") \
			or not viewer_private_feedback_owner.has_method("capture_session_checkpoint"):
		return {}
	return {
		"schema_version": 1,
		"public_log_owner": public_log_owner.capture_session_checkpoint(),
		"public_log_producer_port": public_log_port.capture_session_checkpoint(),
		"victory_receipts": victory_receipt_service.capture_session_checkpoint(),
		"viewer_private_feedback": viewer_private_feedback_owner.capture_session_checkpoint(),
		"outcome_presentation_results": _outcome_presentation_results.duplicate(true),
		"outcome_presentation_accepted_count": _outcome_presentation_accepted_count,
		"outcome_presentation_rejected_count": _outcome_presentation_rejected_count,
		"outcome_immediate_refresh_receipt_ids": _outcome_immediate_refresh_receipt_ids.duplicate(true),
	}


func _restore_session_checkpoint(expected_kind: String) -> void:
	if _session_plan_checkpoint.is_empty() or _session_checkpoint_kind != expected_kind:
		return
	var checkpoint := _session_plan_checkpoint.duplicate(true)
	_discard_session_plan_checkpoint()
	if not TablePresentationPureDataPolicy.is_pure_data(checkpoint) \
			or not _has_exact_keys(checkpoint, SESSION_PLAN_CHECKPOINT_KEYS) \
			or typeof(checkpoint.get("schema_version")) != TYPE_INT \
			or int(checkpoint.get("schema_version", 0)) != 1:
		return
	_resolve_children()
	if public_log_owner == null or public_log_port == null or victory_receipt_service == null \
			or viewer_private_feedback_owner == null \
			or not public_log_owner.has_method("restore_session_checkpoint") \
			or not public_log_port.has_method("restore_session_checkpoint") \
			or not victory_receipt_service.has_method("restore_session_checkpoint") \
			or not viewer_private_feedback_owner.has_method("restore_session_checkpoint"):
		return
	var public_log_checkpoint: Dictionary = checkpoint.get("public_log_owner", {}) \
		if checkpoint.get("public_log_owner", {}) is Dictionary else {}
	var producer_checkpoint: Dictionary = checkpoint.get("public_log_producer_port", {}) \
		if checkpoint.get("public_log_producer_port", {}) is Dictionary else {}
	var victory_checkpoint: Dictionary = checkpoint.get("victory_receipts", {}) \
		if checkpoint.get("victory_receipts", {}) is Dictionary else {}
	var viewer_checkpoint: Dictionary = checkpoint.get("viewer_private_feedback", {}) \
		if checkpoint.get("viewer_private_feedback", {}) is Dictionary else {}
	if not public_log_owner.restore_session_checkpoint(public_log_checkpoint) \
			or not public_log_port.restore_session_checkpoint(producer_checkpoint) \
			or not victory_receipt_service.restore_session_checkpoint(victory_checkpoint) \
			or not viewer_private_feedback_owner.restore_session_checkpoint(viewer_checkpoint):
		return
	_outcome_presentation_results = (checkpoint.get("outcome_presentation_results", {}) as Dictionary).duplicate(true)
	_outcome_presentation_accepted_count = int(checkpoint.get("outcome_presentation_accepted_count", 0))
	_outcome_presentation_rejected_count = int(checkpoint.get("outcome_presentation_rejected_count", 0))
	_outcome_immediate_refresh_receipt_ids = (checkpoint.get("outcome_immediate_refresh_receipt_ids", {}) as Dictionary).duplicate(true)


func _outcome_presentation_result_valid(result: Dictionary) -> bool:
	return TablePresentationPureDataPolicy.is_pure_data(result) \
		and _has_exact_keys(result, OUTCOME_PRESENTATION_RESULT_KEYS) \
		and typeof(result.get("schema_version")) == TYPE_INT \
		and int(result.get("schema_version", 0)) == 1 \
		and result.get("receipt_id") is String \
		and not str(result.get("receipt_id", "")).strip_edges().is_empty() \
		and typeof(result.get("accepted")) == TYPE_BOOL \
		and typeof(result.get("duplicate")) == TYPE_BOOL \
		and result.get("reason_id") is String \
		and result.get("outcome_id") is String


func _accepted_outcome_refresh_context(
	receipt: VictoryPresentationStateChangeReceipt
) -> Dictionary:
	if receipt == null or not receipt.is_valid() or receipt.change_kind != &"outcome":
		return {}
	var outcome: Dictionary = receipt.public_snapshot.get("outcome_receipt", {}) \
		if receipt.public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
	var outcome_id := str(outcome.get("outcome_id", "")).strip_edges()
	var result: Dictionary = _outcome_presentation_results.get(receipt.receipt_id, {}) \
		if _outcome_presentation_results.get(receipt.receipt_id, {}) is Dictionary else {}
	var duplicate := bool(result.get("duplicate", false))
	var result_reason := str(result.get("reason_id", ""))
	var accepted_result_shape := (not duplicate and result_reason.is_empty()) \
		or (duplicate and result_reason == "victory_outcome_already_presented")
	if outcome_id.is_empty() or not _outcome_presentation_result_valid(result) \
			or str(result.get("receipt_id", "")) != receipt.receipt_id \
			or str(result.get("outcome_id", "")) != outcome_id \
			or not bool(result.get("accepted", false)) \
			or not accepted_result_shape:
		return {}
	var required_kinds: Array[String] = []
	for kind_variant in receipt.immediate_refresh_mask:
		var kind := str(kind_variant).strip_edges()
		if kind.is_empty() or required_kinds.has(kind):
			return {}
		required_kinds.append(kind)
	return {
		"outcome_id": outcome_id,
		"required_kinds": required_kinds,
	}


func _outcome_refresh_lineage_matches(lineage: Dictionary, context: Dictionary) -> bool:
	return TablePresentationPureDataPolicy.is_pure_data(lineage) \
		and _has_exact_keys(lineage, ["outcome_id", "required_kinds", "applied_kinds"]) \
		and str(lineage.get("outcome_id", "")) == str(context.get("outcome_id", "")) \
		and lineage.get("required_kinds", []) == context.get("required_kinds", []) \
		and lineage.get("applied_kinds", {}) is Dictionary


func _finalize_session_plan_checkpoint(checkpoint_epoch: int) -> void:
	if checkpoint_epoch == _session_checkpoint_epoch:
		_session_plan_checkpoint.clear()
		_session_checkpoint_kind = ""


func _discard_session_plan_checkpoint() -> void:
	_session_checkpoint_epoch += 1
	_session_plan_checkpoint.clear()
	_session_checkpoint_kind = ""


func _on_outcome_presentation_ready(receipt: VictoryPresentationStateChangeReceipt) -> void:
	if receipt != null:
		_outcome_presentation_results.erase(receipt.receipt_id)
	victory_presentation_receipt_ready.emit(receipt)


func _final_settlement_public_log_acknowledgement(receipt: PublicLogReceipt) -> Dictionary:
	var receipt_id := receipt.receipt_id if receipt != null else ""
	var outcome_id := str(receipt.public_values.get("outcome_id", "")).strip_edges() \
		if receipt != null and receipt.public_values is Dictionary else ""
	var receipt_fingerprint := receipt.fingerprint() if receipt != null else ""
	var rejected := _final_settlement_public_log_rejected(
		receipt_id,
		outcome_id,
		receipt_fingerprint,
		"final_settlement_public_log_receipt_invalid"
	)
	if receipt == null or not receipt.is_valid() \
			or receipt.event_kind != &"final_settlement" \
			or receipt.localization_key != &"victory.public.final_settlement" \
			or outcome_id.is_empty() or receipt_fingerprint.is_empty():
		return rejected
	_resolve_children()
	if public_log_port == null or not public_log_port.is_ready():
		return _final_settlement_public_log_rejected(
			receipt_id,
			outcome_id,
			receipt_fingerprint,
			"public_log_owner_missing"
		)
	var owner_result := public_log_port.append_receipt(receipt)
	if not TablePresentationPureDataPolicy.is_pure_data(owner_result):
		return _final_settlement_public_log_rejected(
			receipt_id,
			outcome_id,
			receipt_fingerprint,
			"final_settlement_public_log_owner_ack_invalid"
		)
	var applied := bool(owner_result.get("applied", false))
	var duplicate := bool(owner_result.get("duplicate", false))
	var reason_id := str(owner_result.get("reason_code", "")).strip_edges()
	var owner_fingerprint := str(owner_result.get("receipt_fingerprint", ""))
	var owner_binding := public_log_port.receipt_binding(receipt_id)
	var binding_valid := TablePresentationPureDataPolicy.is_pure_data(owner_binding) \
		and _has_exact_keys(owner_binding, PUBLIC_LOG_BINDING_KEYS) \
		and str(owner_binding.get("event_kind", "")) == "final_settlement" \
		and int(owner_binding.get("source_revision", -1)) == receipt.source_revision \
		and str(owner_binding.get("receipt_fingerprint", "")) == receipt_fingerprint
	var first_apply_valid := applied and not duplicate and reason_id.is_empty()
	var exact_duplicate_valid := not applied and duplicate \
		and reason_id == "public_log_receipt_duplicate" \
		and not bool(owner_result.get("legacy_unverified", false)) \
		and not bool(owner_result.get("collision", false)) \
		and not bool(owner_result.get("stale", false))
	if not (first_apply_valid or exact_duplicate_valid) \
			or owner_fingerprint != receipt_fingerprint or not binding_valid:
		return _final_settlement_public_log_rejected(
			receipt_id,
			outcome_id,
			receipt_fingerprint,
			reason_id if not reason_id.is_empty() else "final_settlement_public_log_owner_ack_invalid"
		)
	return {
		"schema_version": 1,
		"receipt_id": receipt_id,
		"outcome_id": outcome_id,
		"receipt_fingerprint": receipt_fingerprint,
		"accepted": true,
		"duplicate": exact_duplicate_valid,
		"reason_id": "",
	}


func _final_settlement_public_log_rejected(
	receipt_id: String,
	outcome_id: String,
	receipt_fingerprint: String,
	reason_id: String
) -> Dictionary:
	return {
		"schema_version": 1,
		"receipt_id": receipt_id,
		"outcome_id": outcome_id,
		"receipt_fingerprint": receipt_fingerprint,
		"accepted": false,
		"duplicate": false,
		"reason_id": reason_id,
	}


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true


func _resolve_children() -> void:
	if local_viewer_authorization == null:
		local_viewer_authorization = get_node_or_null("LocalViewerAuthorization") as LocalViewerAuthorization
	if world_session_query == null:
		world_session_query = get_node_or_null("WorldSessionPresentationQuery") as WorldSessionPresentationQuery
	if action_query == null:
		action_query = get_node_or_null("TableActionPresentationQuery") as TableActionPresentationQuery
	if public_map_query == null:
		public_map_query = get_node_or_null("TablePublicMapQuery") as TablePublicMapQuery
	if public_log_owner == null:
		public_log_owner = get_node_or_null("PublicLogPresentationOwner") as PublicLogPresentationOwner
	if public_log_port == null:
		public_log_port = get_node_or_null("PublicLogProducerPort") as PublicLogProducerPort
	if victory_receipt_service == null:
		victory_receipt_service = get_node_or_null("VictoryPresentationReceiptService") as VictoryPresentationReceiptService
	if viewer_private_feedback_owner == null:
		viewer_private_feedback_owner = get_node_or_null("ViewerPrivateFeedbackOwner") as ViewerPrivateFeedbackOwner
