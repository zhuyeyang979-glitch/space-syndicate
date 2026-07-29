extends RefCounted
class_name SaveResumeReceiptV06

const SCHEMA_VERSION := 1
const SLOT_EMPTY := &"empty"
const SLOT_READY := &"ready"
const SLOT_CORRUPT := &"corrupt"
const SLOT_UNAVAILABLE := &"unavailable"
const ALLOWED_SLOT_STATES := [SLOT_EMPTY, SLOT_READY, SLOT_CORRUPT, SLOT_UNAVAILABLE]
const GATEWAY_FIELDS := [
	"schema_version",
	"request_id",
	"operation",
	"slot_id",
	"accepted",
	"applied",
	"reason_code",
	"slot_state",
	"can_save",
	"can_resume",
	"backup_available",
	"saved_at_unix",
	"playtime_seconds",
	"seat_count",
	"ruleset_id",
]

var schema_version := SCHEMA_VERSION
var request_id := ""
var operation: StringName = SaveResumeIntentV06.OPERATION_INSPECT
var slot_id: StringName = SaveSlotPolicyV06.PRODUCTION_SLOT_ID
var accepted := false
var applied := false
var reason_code := "save_resume_rejected"
var slot_state: StringName = SLOT_UNAVAILABLE
var can_save := false
var can_resume := false
var backup_available := false
var saved_at_unix := 0
var playtime_seconds := 0
var seat_count := 0
var ruleset_id := ""


static func from_gateway_result(intent: SaveResumeIntentV06, value: Variant) -> SaveResumeReceiptV06:
	if intent == null or not intent.is_valid():
		return rejected(intent, "intent_invalid")
	var data: Dictionary = {}
	if value is SaveResumeReceiptV06:
		data = (value as SaveResumeReceiptV06).to_dictionary()
	elif value is Dictionary:
		data = (value as Dictionary).duplicate(true)
	if not _has_exact_fields(data, GATEWAY_FIELDS):
		return rejected(intent, "gateway_receipt_shape_invalid")
	var receipt := SaveResumeReceiptV06.new()
	receipt.schema_version = int(data.get("schema_version", 0))
	receipt.request_id = str(data.get("request_id", ""))
	receipt.operation = StringName(str(data.get("operation", "")))
	receipt.slot_id = StringName(str(data.get("slot_id", "")))
	receipt.accepted = bool(data.get("accepted", false))
	receipt.applied = bool(data.get("applied", false))
	receipt.reason_code = str(data.get("reason_code", ""))
	receipt.slot_state = StringName(str(data.get("slot_state", "")))
	receipt.can_save = bool(data.get("can_save", false))
	receipt.can_resume = bool(data.get("can_resume", false))
	receipt.backup_available = bool(data.get("backup_available", false))
	receipt.saved_at_unix = int(data.get("saved_at_unix", 0))
	receipt.playtime_seconds = int(data.get("playtime_seconds", 0))
	receipt.seat_count = int(data.get("seat_count", 0))
	receipt.ruleset_id = str(data.get("ruleset_id", ""))
	if not receipt.is_valid_for(intent):
		return rejected(intent, "gateway_receipt_invalid")
	return receipt


static func rejected(intent: SaveResumeIntentV06, reason: String) -> SaveResumeReceiptV06:
	var receipt := SaveResumeReceiptV06.new()
	if intent != null:
		receipt.request_id = intent.request_id
		receipt.operation = intent.operation
		receipt.slot_id = intent.slot_id
	receipt.reason_code = reason if _safe_reason(reason) else "save_resume_rejected"
	return receipt


func is_valid_for(intent: SaveResumeIntentV06) -> bool:
	if intent == null or not intent.is_valid() or schema_version != SCHEMA_VERSION:
		return false
	if request_id != intent.request_id or operation != intent.operation or slot_id != intent.slot_id:
		return false
	if not _safe_reason(reason_code) or not ALLOWED_SLOT_STATES.has(slot_state):
		return false
	if saved_at_unix < 0 or playtime_seconds < 0 or seat_count < 0 or seat_count > 8:
		return false
	if ruleset_id not in ["", "v0.6"] or (applied and not accepted):
		return false
	if operation == SaveResumeIntentV06.OPERATION_INSPECT and applied:
		return false
	if operation in [SaveResumeIntentV06.OPERATION_SAVE, SaveResumeIntentV06.OPERATION_RESUME] \
			and accepted != applied:
		return false
	if can_resume and slot_state != SLOT_READY:
		return false
	return true


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"operation": String(operation),
		"slot_id": String(slot_id),
		"accepted": accepted,
		"applied": applied,
		"reason_code": reason_code,
		"slot_state": String(slot_state),
		"can_save": can_save,
		"can_resume": can_resume,
		"backup_available": backup_available,
		"saved_at_unix": saved_at_unix,
		"playtime_seconds": playtime_seconds,
		"seat_count": seat_count,
		"ruleset_id": ruleset_id,
	}


func public_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"slot_id": String(slot_id),
		"slot_state": String(slot_state),
		"busy": false,
		"active_operation": "",
		"can_save": can_save,
		"can_resume": can_resume,
		"backup_available": backup_available,
		"last_operation": String(operation),
		"last_succeeded": accepted and (operation == SaveResumeIntentV06.OPERATION_INSPECT or applied),
		"summary": player_summary(),
	}


func player_summary() -> String:
	if accepted and applied and operation == SaveResumeIntentV06.OPERATION_SAVE:
		return "存档：已保存当前游戏。"
	if accepted and applied and operation == SaveResumeIntentV06.OPERATION_RESUME:
		return "存档：已恢复，正在返回牌桌。"
	if operation != SaveResumeIntentV06.OPERATION_INSPECT and not accepted:
		return _failure_summary(operation, reason_code, backup_available)
	match slot_state:
		SLOT_EMPTY:
			return "存档：暂无可继续的游戏。"
		SLOT_READY:
			var facts: Array[String] = []
			if ruleset_id == "v0.6":
				facts.append("v0.6")
			if seat_count >= 3:
				facts.append("%d席" % seat_count)
			if playtime_seconds > 0:
				facts.append("游戏%d分钟" % maxi(1, int(float(playtime_seconds) / 60.0)))
			return "存档：可以继续%s。" % ("｜" + "｜".join(facts) if not facts.is_empty() else "")
		SLOT_CORRUPT:
			return "存档：文件无法读取；可尝试备份。" if backup_available else "存档：文件无法读取。"
	return _failure_summary(operation, reason_code, backup_available)


static func busy_public_snapshot(operation_id: StringName) -> Dictionary:
	var summary := "存档：正在检查…"
	if operation_id == SaveResumeIntentV06.OPERATION_SAVE:
		summary = "存档：正在保存…"
	elif operation_id == SaveResumeIntentV06.OPERATION_RESUME:
		summary = "存档：正在读取…"
	return {
		"schema_version": SCHEMA_VERSION,
		"slot_id": String(SaveSlotPolicyV06.PRODUCTION_SLOT_ID),
		"slot_state": "unavailable",
		"busy": true,
		"active_operation": String(operation_id),
		"can_save": false,
		"can_resume": false,
		"backup_available": false,
		"last_operation": "",
		"last_succeeded": false,
		"summary": summary,
	}


static func unavailable_public_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"slot_id": String(SaveSlotPolicyV06.PRODUCTION_SLOT_ID),
		"slot_state": "unavailable",
		"busy": false,
		"active_operation": "",
		"can_save": false,
		"can_resume": false,
		"backup_available": false,
		"last_operation": "",
		"last_succeeded": false,
		"summary": "存档：恢复服务尚未就绪。",
	}


static func _failure_summary(operation_id: StringName, reason: String, has_backup: bool) -> String:
	if reason in ["save_not_found", "file_not_found"]:
		return "存档：暂无可继续的游戏。"
	if reason in ["save_corrupt", "save_read_invalid", "legacy_or_corrupt"]:
		return "存档：文件无法读取；可尝试备份。" if has_backup else "存档：文件无法读取。"
	if reason in ["operation_in_progress", "registry_busy"]:
		return "存档：另一项操作尚未完成。"
	if reason in ["restore_capability_incomplete", "save_resume_gateway_unavailable"]:
		return "存档：恢复功能仍在准备中。"
	if operation_id == SaveResumeIntentV06.OPERATION_SAVE:
		return "存档：保存失败，当前牌桌未受影响。"
	if operation_id == SaveResumeIntentV06.OPERATION_RESUME:
		return "存档：读取失败，当前牌桌未受影响。"
	return "存档：暂时无法检查保存状态。"


static func _safe_reason(value: String) -> bool:
	return SaveResumeIntentV06._safe_token(value, 128)


static func _has_exact_fields(data: Dictionary, fields: Array) -> bool:
	if data.size() != fields.size():
		return false
	for field_variant in fields:
		if not data.has(str(field_variant)):
			return false
	return true
