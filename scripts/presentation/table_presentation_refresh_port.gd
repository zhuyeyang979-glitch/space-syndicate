@tool
extends Node
class_name TablePresentationRefreshPort

var _source: TablePresentationSourceOwner
var _game_screen: SpaceSyndicateGameScreen
var _planet_target: SpaceSyndicatePlanetBoard
var _developer_target: DeveloperBalancePresentationTarget
var _scheduler: TablePresentationRefreshScheduler
var _last_sequence := 0
var _applied_receipt_ids: Dictionary = {}
var _duplicate_receipt_count := 0
var _stale_receipt_count := 0
var _authorization_rejection_count := 0
var _apply_count_by_kind := {"live": 0, "map": 0, "full": 0, "developer": 0}


func configure(
	source: TablePresentationSourceOwner,
	game_screen: SpaceSyndicateGameScreen,
	planet_target: SpaceSyndicatePlanetBoard,
	developer_target: DeveloperBalancePresentationTarget,
	scheduler: TablePresentationRefreshScheduler
) -> void:
	_source = source
	_game_screen = game_screen
	_planet_target = planet_target
	_developer_target = developer_target
	_scheduler = scheduler


func request_immediate(kind: StringName, _reason: StringName = &"state_changed") -> TablePresentationApplyReceipt:
	if _scheduler == null:
		var missing := TablePresentationApplyReceipt.new()
		missing.reason_code = "presentation_scheduler_missing"
		return missing
	return apply_refresh_receipt(_scheduler.immediate_typed(kind))


func apply_ordered_refresh_receipts(receipts: Array[TablePresentationRefreshReceipt]) -> Array[TablePresentationApplyReceipt]:
	var result: Array[TablePresentationApplyReceipt] = []
	for receipt in receipts:
		result.append(apply_refresh_receipt(receipt))
	return result


func apply_refresh_receipt(receipt: TablePresentationRefreshReceipt) -> TablePresentationApplyReceipt:
	var result := TablePresentationApplyReceipt.new()
	if receipt != null:
		result.refresh_receipt_id = receipt.receipt_id
		result.sequence = receipt.sequence
		result.kind = receipt.kind
	if receipt == null or not receipt.is_valid() or _source == null or _game_screen == null or _planet_target == null:
		result.reason_code = "presentation_receipt_invalid_or_source_missing"
		return result
	if _applied_receipt_ids.has(receipt.receipt_id):
		_duplicate_receipt_count += 1
		result.reason_code = "presentation_receipt_duplicate"
		return result
	if receipt.sequence <= _last_sequence:
		_stale_receipt_count += 1
		result.reason_code = "presentation_receipt_stale"
		return result
	var context := _source.viewer_context()
	if not context.authorized:
		_authorization_rejection_count += 1
		result.reason_code = "presentation_viewer_unauthorized"
		return result
	_game_screen.bind_presentation_viewer(context.viewer_index, context.authorization_revision)
	_planet_target.bind_presentation_viewer(context.viewer_index, context.authorization_revision)
	match receipt.kind:
		&"live":
			var snapshot := _source.build_live_snapshot(receipt)
			if snapshot.is_valid() and _snapshot_authorization_valid(snapshot.viewer_index, snapshot.authorization_revision):
				result.target_revision = _game_screen.apply_live_presentation(snapshot)
				result.snapshot_revision = snapshot.revision
				result.applied = true
		&"map":
			var snapshot := _source.build_map_snapshot(receipt)
			if snapshot.is_valid() and _snapshot_authorization_valid(snapshot.viewer_index, snapshot.authorization_revision):
				result.target_revision = _planet_target.apply_map_presentation(snapshot)
				result.snapshot_revision = snapshot.revision
				result.applied = true
		&"full":
			var snapshot := _source.build_full_snapshot(receipt)
			if snapshot.is_valid() and _snapshot_authorization_valid(snapshot.viewer_index, snapshot.authorization_revision):
				result.target_revision = _game_screen.apply_full_presentation(snapshot)
				result.snapshot_revision = snapshot.revision
				result.applied = true
		&"developer":
			var enabled := _developer_target != null and _developer_target.is_available()
			var snapshot := _source.build_developer_snapshot(receipt, enabled)
			if _developer_target != null and snapshot.is_valid():
				result.target_revision = _developer_target.apply_developer_presentation(snapshot)
				result.snapshot_revision = snapshot.revision
				result.applied = enabled
	if not result.applied and result.reason_code.is_empty():
		result.reason_code = "presentation_target_unavailable_or_snapshot_invalid"
	if result.applied:
		_applied_receipt_ids[receipt.receipt_id] = true
		_last_sequence = receipt.sequence
		_apply_count_by_kind[str(receipt.kind)] = int(_apply_count_by_kind.get(str(receipt.kind), 0)) + 1
	return result


func _snapshot_authorization_valid(viewer_index: int, authorization_revision: int) -> bool:
	var current := _source.viewer_context()
	var valid := current.authorized and current.viewer_index == viewer_index \
		and current.authorization_revision == authorization_revision
	if not valid:
		_authorization_rejection_count += 1
	return valid


func debug_snapshot() -> Dictionary:
	return {
		"configured": _source != null and _game_screen != null and _planet_target != null and _scheduler != null,
		"last_sequence": _last_sequence,
		"apply_count_by_kind": _apply_count_by_kind.duplicate(true),
		"duplicate_receipt_count": _duplicate_receipt_count,
		"stale_receipt_count": _stale_receipt_count,
		"authorization_rejection_count": _authorization_rejection_count,
		"main_fallback_count": 0,
		"references_main": false,
	}
