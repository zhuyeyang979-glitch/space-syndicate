extends RefCounted
class_name MonsterCardEffectAdapterV06

const PORT_SCRIPT := preload("res://scripts/cards/v06/units/monster_card_owner_port_v06.gd")

var _port: Object


func configure(owner: Object) -> Dictionary:
	_port = PORT_SCRIPT.new()
	return _port.call("configure_owner", owner)


func prepare_effect(intent: Dictionary) -> Dictionary:
	var normalized := _normalize_card_flow_intent(intent)
	return _port.call("prepare_intent", normalized) if _port != null else _unconfigured(normalized, "prepare")


func commit_effect(prepared: Dictionary) -> Dictionary:
	return _port.call("commit_intent", prepared) if _port != null else _unconfigured(prepared, "commit")


func rollback_effect(receipt: Dictionary) -> Dictionary:
	return _port.call("rollback_intent", receipt) if _port != null else _unconfigured(receipt, "rollback")


func finalize_effect(receipt: Dictionary) -> Dictionary:
	return _port.call("finalize_intent", receipt) if _port != null else _unconfigured(receipt, "finalize")


func abort_prepared_effect(prepared: Dictionary) -> Dictionary:
	return rollback_effect(prepared)


func capability_matrix() -> Dictionary:
	return _port.call("capability_matrix") if _port != null else {"atomic_mutation_ready": false, "capability_reason": "monster_owner_port_unconfigured"}


func checkpoint_status() -> Dictionary:
	return _port.call("checkpoint_status") if _port != null else {"can_checkpoint": false, "reason_code": "monster_owner_port_unconfigured", "inflight_count": -1}


func _unconfigured(source: Dictionary, stage: String) -> Dictionary:
	return UnitCardRuntimeSchemaV06.failure_receipt(source, "monster_owner_port_unconfigured", "怪兽效果尚未接入。", "请选择其他卡牌。", {"stage": stage})


func _normalize_card_flow_intent(intent: Dictionary) -> Dictionary:
	if str(intent.get("contract_version", "")) == UnitCardRuntimeSchemaV06.CONTRACT_VERSION:
		return intent.duplicate(true)
	var effect_kind := str(intent.get("effect_kind", ""))
	var target: Dictionary = intent.get("target_context", {}) if intent.get("target_context", {}) is Dictionary else {}
	var payload: Dictionary = intent.get("effect_payload", {}) if intent.get("effect_payload", {}) is Dictionary else {}
	var action_kind := effect_kind if effect_kind == "deploy_or_upgrade_monster" else str(payload.get("action_kind", target.get("action_kind", "")))
	var expected_revision := int(target.get("expected_owner_revision", -1))
	return UnitCardRuntimeSchemaV06.normalize_card_flow_intent(intent, expected_revision, action_kind)
