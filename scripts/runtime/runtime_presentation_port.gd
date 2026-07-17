extends Node
class_name RuntimePresentationPort

var _visual_cues: VisualCueRuntimeOwner
var _scheduler: TablePresentationRefreshScheduler
var _refresh_port: TablePresentationRefreshPort
var _developer_target: DeveloperBalancePresentationTarget


func bind_dependencies(
	visual_cues: VisualCueRuntimeOwner,
	scheduler: TablePresentationRefreshScheduler,
	refresh_port: TablePresentationRefreshPort,
	developer_target: DeveloperBalancePresentationTarget
) -> void:
	_visual_cues = visual_cues
	_scheduler = scheduler
	_refresh_port = refresh_port
	_developer_target = developer_target


func is_ready() -> bool:
	return is_instance_valid(_visual_cues) and is_instance_valid(_scheduler) and is_instance_valid(_refresh_port)


func advance_visual_cues(delta_seconds: float) -> Dictionary:
	return _visual_cues.advance(delta_seconds) if _visual_cues != null else {
		"advanced": false,
		"reason": "visual_cue_owner_unavailable",
	}


func advance_table_presentation(real_delta_seconds: float) -> Array[TablePresentationApplyReceipt]:
	if _scheduler == null or _refresh_port == null:
		return [] as Array[TablePresentationApplyReceipt]
	var developer_visible := _developer_target != null and _developer_target.enabled
	return _refresh_port.apply_ordered_refresh_receipts(_scheduler.advance_typed(real_delta_seconds, developer_visible))


func debug_snapshot() -> Dictionary:
	return {"port_kind": "presentation", "ready": is_ready(), "operation_count": 2, "owns_presentation_state": false}
