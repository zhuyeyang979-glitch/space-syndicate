@tool
extends Node
class_name CardHistoryPublicQueryPort

const SCHEMA_VERSION := 1
const ENTRY_FIELDS := [
	"history_entry_id",
	"public_sequence",
	"public_time",
	"public_card_id",
	"public_card_name",
	"public_target",
	"public_result",
	"public_reveal_state",
	"publicly_revealed_actor",
	"public_action_phase",
	"public_card_category",
	"public_revision",
]

var _history_service: CardResolutionHistoryRuntimeService
var _compose_count := 0


func configure(history_service: CardResolutionHistoryRuntimeService) -> void:
	_history_service = history_service


func compose_history() -> Dictionary:
	_compose_count += 1
	var revision := _history_revision()
	var entries: Array = []
	if _history_service != null:
		for entry_variant in _history_service.public_history_snapshot():
			if entry_variant is Dictionary:
				var public_entry := _compose_entry(entry_variant as Dictionary, revision)
				if not public_entry.is_empty():
					entries.append(public_entry)
	return {
		"schema_version": SCHEMA_VERSION,
		"visibility_scope": "public",
		"revision": revision,
		"entry_count": entries.size(),
		"entries": entries,
	}


func entry_by_id(history_entry_id: String) -> Dictionary:
	var normalized := history_entry_id.strip_edges()
	if normalized.is_empty():
		return {}
	for entry_variant in compose_history().get("entries", []):
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("history_entry_id", "")) == normalized:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": _history_service != null,
		"public_read_only": true,
		"exact_entry_fields": ENTRY_FIELDS.duplicate(),
		"compose_count": _compose_count,
		"reads_hidden_actor": false,
		"reads_private_cash": false,
		"reads_private_hand": false,
		"reads_ai_plan": false,
		"owns_history": false,
		"owns_save_schema": false,
		"source_projection": "CardResolutionHistoryRuntimeService.public_history_snapshot",
	}


func _compose_entry(source: Dictionary, revision: int) -> Dictionary:
	var resolution_id := int(source.get("resolution_id", source.get("queued_order", -1)))
	if resolution_id < 0:
		return {}
	var skill: Dictionary = source.get("skill", {}) if source.get("skill", {}) is Dictionary else {}
	var card_name := str(skill.get("display_name", source.get("card_name", skill.get("name", "")))).strip_edges()
	var card_id := str(skill.get("name", source.get("card_name", ""))).strip_edges()
	var result_text := str(source.get("aftermath_clue", source.get("resolution_outcome", ""))).strip_edges()
	if result_text.is_empty():
		result_text = "已结算" if bool(source.get("resolved", true)) else "等待结算"
	var reveal_state := "公开牌面" if not card_name.is_empty() else "匿名牌面"
	if bool(source.get("countered", false)):
		reveal_state = "已反制"
	return {
		"history_entry_id": "card-history:%d" % resolution_id,
		"public_sequence": maxi(0, int(source.get("public_sequence", source.get("group_order", resolution_id)))),
		"public_time": maxf(0.0, float(source.get("resolved_time", 0.0))),
		"public_card_id": card_id,
		"public_card_name": card_name if not card_name.is_empty() else "未知牌",
		"public_target": _public_target(source),
		"public_result": result_text,
		"public_reveal_state": reveal_state,
		"publicly_revealed_actor": "",
		"public_action_phase": "resolved" if bool(source.get("resolved", true)) else "pending",
		"public_card_category": str(skill.get("kind", source.get("card_kind", "unknown"))),
		"public_revision": revision,
	}


func _public_target(source: Dictionary) -> String:
	if int(source.get("target_player", -1)) >= 0:
		return "玩家%d" % (int(source.get("target_player", -1)) + 1)
	if int(source.get("target_slot", -1)) >= 0:
		return "怪兽%d" % (int(source.get("target_slot", -1)) + 1)
	if int(source.get("selected_district", -1)) >= 0:
		return "区域%d" % (int(source.get("selected_district", -1)) + 1)
	if not str(source.get("selected_trade_product", "")).is_empty():
		return str(source.get("selected_trade_product", ""))
	return "无公开目标"


func _history_revision() -> int:
	if _history_service == null:
		return 0
	return maxi(0, int(_history_service.debug_snapshot().get("revision", 0)))
