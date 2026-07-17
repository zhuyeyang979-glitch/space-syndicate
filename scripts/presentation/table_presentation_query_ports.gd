@tool
extends Node
class_name TablePresentationQueryPorts

signal victory_presentation_receipt_ready(receipt: VictoryPresentationStateChangeReceipt)

@onready var local_viewer_authorization: LocalViewerAuthorization = $LocalViewerAuthorization
@onready var world_session_query: WorldSessionPresentationQuery = $WorldSessionPresentationQuery
@onready var action_query: TableActionPresentationQuery = $TableActionPresentationQuery
@onready var public_map_query: TablePublicMapQuery = $TablePublicMapQuery
@onready var public_log_owner: PublicLogPresentationOwner = $PublicLogPresentationOwner
@onready var public_log_port: PublicLogProducerPort = $PublicLogProducerPort
@onready var victory_receipt_service: VictoryPresentationReceiptService = $VictoryPresentationReceiptService

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


func authorized_viewer_index() -> int:
	return local_viewer_authorization.authorized_viewer_index()


func can_view_private_subject(viewer_index: int, subject_index: int) -> bool:
	return local_viewer_authorization.can_view_subject(viewer_index, subject_index)


func public_world_projection() -> WorldSessionPublicProjection:
	return world_session_query.public_projection()


func private_world_projection(viewer_index: int, subject_index: int) -> WorldSessionPrivateProjection:
	return world_session_query.private_projection(viewer_index, subject_index)


func action_projection(viewer_index: int) -> TableActionPresentationProjection:
	return action_query.snapshot_for_viewer(viewer_index)


func public_card_track_snapshot() -> Dictionary:
	return action_query.public_card_track_snapshot()


func public_map_projection(viewer_index: int, commodity_id := "") -> TablePublicMapProjection:
	return public_map_query.snapshot_for_viewer(viewer_index, commodity_id)


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


func import_legacy_public_log(messages: Array) -> Dictionary:
	return public_log_owner.import_legacy_messages(messages)


func reset_public_log() -> void:
	public_log_owner.reset_state()
	public_log_port.reset_state()


func capture_victory_advance(result: Dictionary) -> VictoryPresentationStateChangeReceipt:
	return victory_receipt_service.capture_advance_result(result)


func capture_victory_outcome(public_snapshot: Dictionary) -> VictoryPresentationStateChangeReceipt:
	return victory_receipt_service.capture_outcome(public_snapshot)


func debug_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"local_viewer": local_viewer_authorization.debug_snapshot(),
		"world_query": world_session_query.debug_snapshot(),
		"action_query": action_query.debug_snapshot(),
		"map_query": public_map_query.debug_snapshot(),
		"public_log": public_log_owner.debug_snapshot(),
		"victory_receipts": victory_receipt_service.debug_snapshot(),
		"owns_refresh_cadence": false,
		"owns_ui_targets": false,
		"references_main": false,
	}


func _on_outcome_presentation_ready(receipt: VictoryPresentationStateChangeReceipt) -> void:
	victory_presentation_receipt_ready.emit(receipt)
