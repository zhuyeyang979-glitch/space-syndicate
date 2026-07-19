extends RefCounted
class_name IntelPrivateCommandReceipt

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var command_id := ""
var command_kind: StringName = &""
var viewer_index := -1
var subject_id := ""
var accepted := false
var applied := false
var changed := false
var idempotent_replay := false
var reason_code := ""
var owner_revision_before := ""
var owner_revision_after := ""
var save_dirty_delta := 0
var role_usage_delta := 0
var notification_delta := 0
var public_log_delta := 0


func replay_copy() -> IntelPrivateCommandReceipt:
	var receipt := duplicate_receipt()
	receipt.idempotent_replay = true
	receipt.save_dirty_delta = 0
	receipt.role_usage_delta = 0
	receipt.notification_delta = 0
	receipt.public_log_delta = 0
	return receipt


func duplicate_receipt() -> IntelPrivateCommandReceipt:
	var receipt := IntelPrivateCommandReceipt.new()
	receipt.schema_version = schema_version
	receipt.command_id = command_id
	receipt.command_kind = command_kind
	receipt.viewer_index = viewer_index
	receipt.subject_id = subject_id
	receipt.accepted = accepted
	receipt.applied = applied
	receipt.changed = changed
	receipt.idempotent_replay = idempotent_replay
	receipt.reason_code = reason_code
	receipt.owner_revision_before = owner_revision_before
	receipt.owner_revision_after = owner_revision_after
	receipt.save_dirty_delta = save_dirty_delta
	receipt.role_usage_delta = role_usage_delta
	receipt.notification_delta = notification_delta
	receipt.public_log_delta = public_log_delta
	return receipt


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"command_id": command_id,
		"command_kind": command_kind,
		"viewer_index": viewer_index,
		"subject_id": subject_id,
		"accepted": accepted,
		"applied": applied,
		"changed": changed,
		"idempotent_replay": idempotent_replay,
		"reason_code": reason_code,
		"owner_revision_before": owner_revision_before,
		"owner_revision_after": owner_revision_after,
		"save_dirty_delta": save_dirty_delta,
		"role_usage_delta": role_usage_delta,
		"notification_delta": notification_delta,
		"public_log_delta": public_log_delta,
	}
