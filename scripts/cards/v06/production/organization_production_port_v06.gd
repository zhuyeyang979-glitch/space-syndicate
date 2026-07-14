extends RefCounted
class_name OrganizationProductionPortV06

const RULESET_ID := "v0.6"
const EFFECT_KIND := "install_organization_upgrade"
const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/organization/organization_card_effect_adapter_v06.gd")
const CONSUMER_DOMAINS: Array[String] = [
	"asset_recovery",
	"hand_limit",
	"card_window",
	"monster_binding",
	"military_command",
]
const FUNCTIONAL_METHOD_BY_DOMAIN := {
	"asset_recovery": "apply_organization_asset_recovery_terms_v06",
	"hand_limit": "apply_organization_hand_limit_terms_v06",
	"card_window": "apply_organization_card_window_submission_capability_v06",
	"monster_binding": "configure_monster_binding_capability_provider_v06",
	"military_command": "apply_organization_military_command_caps_v06",
}
const REQUIRED_OWNER_METHODS: Array[String] = [
	"prepare_organization_upgrade",
	"commit_organization_upgrade",
	"rollback_organization_upgrade",
	"finalize_organization_upgrade",
	"abort_prepared_organization_upgrade",
	"checkpoint_status",
	"to_save_data",
	"apply_save_data",
	"public_snapshot",
	"private_snapshot",
	"asset_recovery_terms",
	"hand_limit_terms",
	"card_window_submission_capability",
	"validate_card_window_submission_capability",
	"monster_binding_caps",
	"monster_binding_caps_for_target_owner",
	"military_command_caps",
]

var _owner: Object
var _adapter: Object
var _consumer_ports: Dictionary = {}
var _owner_ready := false
var _monster_consumer_bound := false


func configure(owner: Object, consumer_ports: Dictionary = {}) -> Dictionary:
	_owner = owner
	_consumer_ports = consumer_ports.duplicate()
	_adapter = null
	_monster_consumer_bound = false
	_owner_ready = _owner_api_ready()
	if _owner_ready:
		_adapter = ADAPTER_SCRIPT.new()
		var configured_variant: Variant = _adapter.call("configure", _owner)
		var configured: Dictionary = configured_variant if configured_variant is Dictionary else {}
		_owner_ready = bool(configured.get("atomic_mutation_ready", false))
	if _owner_ready:
		_monster_consumer_bound = _configure_monster_binding_consumer()
	return {
		"configured": _owner_ready,
		"reason_code": "organization_production_port_configured" if _owner_ready else "organization_owner_atomic_contract_missing",
		"effect_kind": EFFECT_KIND,
		"consumer_readiness": organization_consumer_readiness_snapshot(),
	}


func prepare_effect(intent: Dictionary) -> Dictionary:
	if str(intent.get("effect_kind", "")) != EFFECT_KIND:
		return _failure(intent, "organization_effect_kind_invalid", "prepare")
	if not _owner_ready or _adapter == null:
		return _failure(intent, "organization_owner_atomic_contract_missing", "prepare")
	if not bool(organization_consumer_readiness_snapshot().get("production_ready", false)):
		return _failure(intent, "organization_consumer_capabilities_incomplete", "prepare")
	var value_variant: Variant = _adapter.call("prepare_effect", intent.duplicate(true))
	return _dictionary(value_variant) if value_variant is Dictionary else _failure(intent, "organization_prepare_receipt_invalid", "prepare")


func commit_effect(prepared: Dictionary) -> Dictionary:
	return _forward("commit_effect", prepared, "committed", "commit")


func rollback_effect(receipt: Dictionary) -> Dictionary:
	return _forward("rollback_effect", receipt, "rolled_back", "rollback")


func finalize_effect(receipt: Dictionary) -> Dictionary:
	return _forward("finalize_effect", receipt, "finalized", "finalize")


func abort_prepared_effect(prepared: Dictionary) -> Dictionary:
	return _forward("abort_prepared_effect", prepared, "rolled_back", "abort")


func checkpoint_status() -> Dictionary:
	if not _owner_ready or _adapter == null or not _adapter.has_method("checkpoint_status"):
		return {"can_checkpoint": false, "reason_code": "organization_owner_checkpoint_unavailable"}
	var value_variant: Variant = _adapter.call("checkpoint_status")
	return _dictionary(value_variant) if value_variant is Dictionary else {"can_checkpoint": false, "reason_code": "organization_owner_checkpoint_invalid"}


func capability_matrix() -> Dictionary:
	var adapter_matrix: Dictionary = {}
	if _adapter != null and _adapter.has_method("capability_matrix"):
		var value_variant: Variant = _adapter.call("capability_matrix")
		if value_variant is Dictionary:
			adapter_matrix = _dictionary(value_variant)
	var readiness := organization_consumer_readiness_snapshot()
	return {
		"ruleset_id": RULESET_ID,
		"effect_kind": EFFECT_KIND,
		"owner_ready": _owner_ready,
		"prepare": _owner_ready and bool(adapter_matrix.get("atomic_mutation_ready", false)),
		"commit": _owner_ready and bool(adapter_matrix.get("atomic_mutation_ready", false)),
		"rollback": _owner_ready and bool(adapter_matrix.get("rollback_ready", false)),
		"finalize": _owner_ready and bool(adapter_matrix.get("finalize_ready", false)),
		"checkpoint": _owner_ready and bool(adapter_matrix.get("checkpoint_ready", false)),
		"save_load": _owner_ready and _owner.has_method("to_save_data") and _owner.has_method("apply_save_data"),
		"exact_once": _owner_ready,
		"consumer_production_ready": bool(readiness.get("production_ready", false)),
		"production_ready": _owner_ready and bool(readiness.get("production_ready", false)),
	}


func organization_consumer_readiness_snapshot() -> Dictionary:
	var consumers: Dictionary = {}
	var missing: Array[String] = []
	for domain in CONSUMER_DOMAINS:
		var detailed := _consumer_readiness(domain)
		var ready := bool(detailed.get("ready", false))
		consumers[domain] = {"ready": ready}
		if not ready:
			missing.append(domain)
	return {
		"available": _owner_ready,
		"production_ready": _owner_ready and missing.is_empty(),
		"reason_code": "organization_consumers_ready" if _owner_ready and missing.is_empty() else "organization_consumer_capabilities_incomplete",
		"consumers": consumers,
		"missing_consumers": missing,
	}


func public_snapshot() -> Dictionary:
	var owner_public: Dictionary = {}
	if _owner_ready and _owner.has_method("public_snapshot"):
		var value_variant: Variant = _owner.call("public_snapshot")
		if value_variant is Dictionary:
			owner_public = _dictionary(value_variant)
	return {
		"available": _owner_ready,
		"ruleset_id": RULESET_ID,
		"effect_kind": EFFECT_KIND,
		"organization": owner_public,
		"consumer_readiness": organization_consumer_readiness_snapshot(),
	}


func public_receipt(receipt: Dictionary) -> Dictionary:
	return {
		"schema_version": RULESET_ID,
		"transaction_id": str(receipt.get("transaction_id", "")),
		"effect_kind": EFFECT_KIND,
		"prepared": bool(receipt.get("prepared", false)),
		"committed": bool(receipt.get("committed", false)),
		"rolled_back": bool(receipt.get("rolled_back", false)),
		"finalized": bool(receipt.get("finalized", false)),
		"reason_code": str(receipt.get("reason_code", "")),
		"organization_axis": str(receipt.get("organization_axis", "")),
		"organization_rank": int(receipt.get("organization_rank", 0)),
		"activation_window_sequence": int(receipt.get("activation_window_sequence", -1)),
	}


func current_monster_binding_window_snapshot_v06() -> Dictionary:
	var queue_variant: Variant = _consumer_ports.get("card_window")
	if not (queue_variant is Object):
		return {"available": false, "authoritative": false, "reason_code": "organization_window_owner_unavailable"}
	var queue := queue_variant as Object
	if not queue.has_method("queue_state_snapshot"):
		return {"available": false, "authoritative": false, "reason_code": "organization_window_owner_api_missing"}
	var value_variant: Variant = queue.call("queue_state_snapshot")
	if not (value_variant is Dictionary):
		return {"available": false, "authoritative": false, "reason_code": "organization_window_snapshot_invalid"}
	var snapshot: Dictionary = value_variant
	var window_sequence := int(snapshot.get("last_group_window_sequence", -1))
	var revision := int(snapshot.get("revision", -1))
	return {
		"available": window_sequence >= 0 and revision >= 0,
		"authoritative": window_sequence >= 0 and revision >= 0,
		"reason_code": "organization_window_snapshot_ready" if window_sequence >= 0 and revision >= 0 else "organization_window_not_started",
		"window_sequence": window_sequence,
		"revision": revision,
	}


func monster_binding_caps(actor_id: String, window_sequence: int) -> Dictionary:
	if not _owner_ready or not _owner.has_method("monster_binding_caps"):
		return {"available": false, "authoritative": false, "reason_code": "organization_owner_unavailable"}
	var value_variant: Variant = _owner.call("monster_binding_caps", actor_id, window_sequence)
	return _dictionary(value_variant) if value_variant is Dictionary else {"available": false, "authoritative": false, "reason_code": "organization_monster_caps_invalid"}


func monster_binding_caps_for_target_owner(actor_id: String, window_sequence: int) -> Dictionary:
	if not _owner_ready or not _owner.has_method("monster_binding_caps_for_target_owner"):
		return {"available": false, "authoritative": false, "reason_code": "organization_owner_unavailable"}
	var value_variant: Variant = _owner.call("monster_binding_caps_for_target_owner", actor_id, window_sequence)
	return _dictionary(value_variant) if value_variant is Dictionary else {"available": false, "authoritative": false, "reason_code": "organization_target_owner_monster_caps_invalid"}


func debug_snapshot() -> Dictionary:
	var details: Dictionary = {}
	for domain in CONSUMER_DOMAINS:
		details[domain] = _consumer_readiness(domain)
	return {
		"owner_ready": _owner_ready,
		"capability_matrix": capability_matrix(),
		"consumer_readiness": organization_consumer_readiness_snapshot(),
		"consumer_details": details,
		"checkpoint": checkpoint_status(),
	}


func _forward(method_name: String, source: Dictionary, success_key: String, stage: String) -> Dictionary:
	if not _owner_ready or _adapter == null or not _adapter.has_method(method_name):
		return _failure(source, "organization_owner_%s_unavailable" % stage, stage)
	var value_variant: Variant = _adapter.call(method_name, source.duplicate(true))
	if not (value_variant is Dictionary):
		return _failure(source, "organization_%s_receipt_invalid" % stage, stage)
	var result := _dictionary(value_variant)
	if not bool(result.get(success_key, false)) and str(result.get("reason_code", "")).is_empty():
		result["reason_code"] = "organization_%s_failed" % stage
	return result


func _consumer_readiness(domain: String) -> Dictionary:
	var consumer_variant: Variant = _consumer_ports.get(domain)
	if not (consumer_variant is Object):
		return {"ready": false, "declared": false, "method_ready": false, "reason_code": "consumer_node_missing"}
	var consumer := consumer_variant as Object
	var functional_method := str(FUNCTIONAL_METHOD_BY_DOMAIN.get(domain, ""))
	var method_ready := not functional_method.is_empty() and consumer.has_method(functional_method)
	if domain == "monster_binding":
		return {
			"ready": method_ready and _monster_consumer_bound,
			"declared": _monster_consumer_bound,
			"method_ready": method_ready,
			"reason_code": "consumer_ready" if method_ready and _monster_consumer_bound else "consumer_capability_or_method_missing",
		}
	var declared: Dictionary = {}
	if consumer.has_method("organization_consumer_capabilities_v06"):
		var value_variant: Variant = consumer.call("organization_consumer_capabilities_v06", domain)
		if value_variant is Dictionary:
			declared = _dictionary(value_variant)
	var declaration_ready := (
		str(declared.get("ruleset_id", "")) == RULESET_ID
		and str(declared.get("domain", "")) == domain
		and bool(declared.get("consumes_authoritative_organization_terms", false))
		and bool(declared.get("production_ready", false))
	)
	return {
		"ready": declaration_ready and method_ready,
		"declared": declaration_ready,
		"method_ready": method_ready,
		"reason_code": "consumer_ready" if declaration_ready and method_ready else "consumer_capability_or_method_missing",
	}


func _configure_monster_binding_consumer() -> bool:
	var consumer_variant: Variant = _consumer_ports.get("monster_binding")
	if not (consumer_variant is Object):
		return false
	var consumer := consumer_variant as Object
	if not consumer.has_method("configure_monster_binding_capability_provider_v06"):
		return false
	var value_variant: Variant = consumer.call("configure_monster_binding_capability_provider_v06", self)
	return value_variant is Dictionary and bool((value_variant as Dictionary).get("configured", false))


func _owner_api_ready() -> bool:
	if _owner == null:
		return false
	for method_name in REQUIRED_OWNER_METHODS:
		if not _owner.has_method(method_name):
			return false
	return true


func _failure(source: Dictionary, reason_code: String, stage: String) -> Dictionary:
	var result: Dictionary = {}
	for key in ["transaction_id", "actor_id", "card_id", "card_instance_id", "effect_kind", "target_hash", "payload_hash", "intent_hash"]:
		result[key] = str(source.get(key, ""))
	result.merge({
		"prepared": false,
		"committed": false,
		"rolled_back": false,
		"finalized": false,
		"reason_code": reason_code,
		"failure_stage": stage,
	}, true)
	return result


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
