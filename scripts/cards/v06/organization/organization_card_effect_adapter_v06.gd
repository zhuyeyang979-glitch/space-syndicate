extends RefCounted
class_name OrganizationCardEffectAdapterV06

const EFFECT_KIND := "install_organization_upgrade"

var _owner: Object


func configure(owner: Object) -> Dictionary:
	_owner = owner
	var ready := _owner != null \
		and _owner.has_method("prepare_organization_upgrade") \
		and _owner.has_method("commit_organization_upgrade") \
		and _owner.has_method("rollback_organization_upgrade") \
		and _owner.has_method("finalize_organization_upgrade") \
		and _owner.has_method("abort_prepared_organization_upgrade")
	return {"configured": ready, "effect_kind": EFFECT_KIND, "atomic_mutation_ready": ready}


func prepare_effect(intent: Dictionary) -> Dictionary:
	if not _ready():
		return _failure(intent, "organization_owner_unconfigured", "prepare")
	if str(intent.get("effect_kind", "")) != EFFECT_KIND:
		return _failure(intent, "organization_effect_kind_invalid", "prepare")
	return _dictionary(_owner.call("prepare_organization_upgrade", intent.duplicate(true)))


func commit_effect(prepared: Dictionary) -> Dictionary:
	return _dictionary(_owner.call("commit_organization_upgrade", prepared.duplicate(true))) if _ready() else _failure(prepared, "organization_owner_unconfigured", "commit")


func rollback_effect(receipt: Dictionary) -> Dictionary:
	return _dictionary(_owner.call("rollback_organization_upgrade", receipt.duplicate(true))) if _ready() else {"rolled_back": false, "reason_code": "organization_owner_unconfigured"}


func finalize_effect(receipt: Dictionary) -> Dictionary:
	return _dictionary(_owner.call("finalize_organization_upgrade", receipt.duplicate(true))) if _ready() else {"finalized": false, "reason_code": "organization_owner_unconfigured"}


func abort_prepared_effect(prepared: Dictionary) -> Dictionary:
	return _dictionary(_owner.call("abort_prepared_organization_upgrade", prepared.duplicate(true))) if _ready() else {"rolled_back": false, "reason_code": "organization_owner_unconfigured"}


func capability_matrix() -> Dictionary:
	return {
		"configured": _ready(),
		"atomic_mutation_ready": _ready(),
		"rollback_ready": _ready(),
		"finalize_ready": _ready(),
		"checkpoint_ready": _ready() and _owner.has_method("checkpoint_status"),
		"effect_kind": EFFECT_KIND,
	}


func checkpoint_status() -> Dictionary:
	return _dictionary(_owner.call("checkpoint_status")) if _ready() and _owner.has_method("checkpoint_status") else {"can_checkpoint": false, "reason_code": "organization_owner_unconfigured"}


func _ready() -> bool:
	return _owner != null and _owner.has_method("prepare_organization_upgrade")


func _failure(source: Dictionary, reason_code: String, stage: String) -> Dictionary:
	var result: Dictionary = {}
	for key in ["transaction_id", "actor_id", "card_id", "card_instance_id", "effect_kind", "target_hash", "payload_hash", "intent_hash"]:
		result[key] = str(source.get(key, ""))
	result.merge({"prepared": false, "committed": false, "reason_code": reason_code, "failure_stage": stage}, true)
	return result


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
