extends RefCounted
class_name SetupDraftCommandReceipt

var accepted := false
var applied := false
var idempotent := false
var reason_code := "setup_command_rejected"
var command_id := ""
var draft_revision := -1


static func make(
	command: SetupDraftCommand,
	is_accepted: bool,
	is_applied: bool,
	reason: String,
	revision: int,
	is_idempotent: bool = false
) -> SetupDraftCommandReceipt:
	var receipt := SetupDraftCommandReceipt.new()
	receipt.command_id = command.command_id if command != null else ""
	receipt.accepted = is_accepted
	receipt.applied = is_applied
	receipt.reason_code = reason
	receipt.draft_revision = revision
	receipt.idempotent = is_idempotent
	return receipt


func to_dictionary() -> Dictionary:
	return {
		"accepted": accepted,
		"applied": applied,
		"idempotent": idempotent,
		"reason_code": reason_code,
		"command_id": command_id,
		"draft_revision": draft_revision,
	}
