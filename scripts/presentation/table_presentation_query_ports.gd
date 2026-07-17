@tool
extends Node
class_name TablePresentationQueryPorts

signal victory_presentation_receipt_ready(receipt: VictoryPresentationStateChangeReceipt)

var local_viewer_authorization: LocalViewerAuthorization
var world_session_query: WorldSessionPresentationQuery
var action_query: TableActionPresentationQuery
var public_map_query: TablePublicMapQuery
var public_log_owner: PublicLogPresentationOwner
var public_log_port: PublicLogProducerPort
var victory_receipt_service: VictoryPresentationReceiptService
var viewer_private_feedback_owner: ViewerPrivateFeedbackOwner

var _configured := false


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
	victory: VictoryControlRuntimeController
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
	if not victory_receipt_service.outcome_presentation_ready.is_connected(_on_outcome_presentation_ready):
		victory_receipt_service.outcome_presentation_ready.connect(_on_outcome_presentation_ready)
	_configured = true


func reset_state() -> void:
	public_log_owner.reset_state()
	public_log_port.reset_state()
	victory_receipt_service.reset_state()
	viewer_private_feedback_owner.reset_state()


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
	return victory_receipt_service.capture_outcome(public_snapshot)


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
		"public_log": public_log_owner.debug_snapshot(),
		"viewer_private_feedback": viewer_private_feedback_owner.debug_snapshot(),
		"victory_receipts": victory_receipt_service.debug_snapshot(),
		"owns_refresh_cadence": false,
		"owns_ui_targets": false,
		"references_main": false,
	}


func _on_outcome_presentation_ready(receipt: VictoryPresentationStateChangeReceipt) -> void:
	victory_presentation_receipt_ready.emit(receipt)


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
