extends Node
class_name SetupDraftCommandPort

@export var draft_service_path: NodePath

var _journal: Dictionary = {}
var _submission_count := 0
var _rejection_count := 0


func submit_command(command: SetupDraftCommand) -> SetupDraftCommandReceipt:
	_submission_count += 1
	if command == null or not command.is_valid():
		_rejection_count += 1
		return SetupDraftCommandReceipt.make(command, false, false, "setup_command_invalid", _revision())
	var fingerprint := command.fingerprint()
	if _journal.has(command.command_id):
		var record: Dictionary = _journal[command.command_id]
		if str(record.get("fingerprint", "")) != fingerprint:
			_rejection_count += 1
			return SetupDraftCommandReceipt.make(command, false, false, "setup_command_id_collision", _revision())
		var saved: Dictionary = record.get("receipt", {})
		return SetupDraftCommandReceipt.make(command, bool(saved.get("accepted", false)), false, str(saved.get("reason_code", "setup_command_replayed")), int(saved.get("draft_revision", _revision())), true)
	var service := _draft_service()
	if service == null:
		_rejection_count += 1
		return SetupDraftCommandReceipt.make(command, false, false, "setup_draft_owner_unavailable", -1)
	var receipt := service.apply_command(command)
	_journal[command.command_id] = {
		"fingerprint": fingerprint,
		"receipt": receipt.to_dictionary(),
	}
	if not receipt.accepted:
		_rejection_count += 1
	return receipt


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "setup_draft_command_port_v1",
		"submission_count": _submission_count,
		"rejection_count": _rejection_count,
		"journal_count": _journal.size(),
		"owns_draft": false,
		"references_main": false,
	}


func _draft_service() -> NewGameSetupDraftService:
	return get_node_or_null(draft_service_path) as NewGameSetupDraftService


func _revision() -> int:
	var service := _draft_service()
	return int(service.draft_snapshot().get("draft_revision", -1)) if service != null else -1
