@tool
extends Node
class_name MonsterRuntimeWorldBridge

signal runtime_event_forwarded(event: Dictionary)

const MONSTER_DEPLOY_CONTRACT_VERSION := "v0.6"
const MONSTER_DEPLOY_SNAPSHOT_METHODS := {
	"region_facts": &"monster_deploy_region_snapshot_v06",
	"monster_profile": &"monster_deploy_profile_snapshot_v06",
	"binding_rule": &"monster_deploy_rule_snapshot_v06",
}
const MONSTER_DEPLOY_STAGE_METHODS := {
	"prepare": &"prepare_monster_deploy_side_effects_v06",
	"commit": &"commit_monster_deploy_side_effects_v06",
	"rollback": &"rollback_monster_deploy_side_effects_v06",
	"finalize": &"finalize_monster_deploy_side_effects_v06",
}
const MONSTER_DEPLOY_PARTICIPANT_CAPABILITIES := [
	"prepare",
	"commit",
	"rollback",
	"finalize",
	"exact_once",
	"checkpoint",
	"save_load",
]

var _world: Node
var _rng_service: RunRngService
var _world_call_count := 0
var _failed_world_call_count := 0
var _monster_deploy_forward_count := 0
var _monster_deploy_failure_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_rng_service(service: RunRngService) -> void:
	_rng_service = service


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func read_world_value(property_name: StringName, default_value: Variant = null) -> Variant:
	if not has_world():
		return default_value
	var value: Variant = _world.get(property_name)
	return default_value if value == null else value


func write_world_value(property_name: StringName, value: Variant) -> bool:
	if not has_world():
		return false
	_world.set(property_name, value)
	return true


func read_world_constant(constant_name: StringName, default_value: Variant = null) -> Variant:
	if not has_world():
		return default_value
	var world_script := _world.get_script() as Script
	if world_script == null:
		return default_value
	var constants := world_script.get_script_constant_map()
	return constants.get(str(constant_name), default_value)


func shared_rng() -> RunRngService:
	return _rng_service


func call_world(method_name: StringName, arguments: Array = []) -> Variant:
	if not has_world() or not _world.has_method(method_name):
		_failed_world_call_count += 1
		push_error("MonsterRuntimeWorldBridge cannot route world method: %s" % method_name)
		return null
	_world_call_count += 1
	return _world.callv(method_name, arguments)


func monster_deploy_region_snapshot_v06(region_id: String) -> Dictionary:
	var normalized_region_id := region_id.strip_edges()
	if normalized_region_id.is_empty():
		return _snapshot_failure("monster_deploy_region_snapshot_invalid", {"region_id": normalized_region_id})
	return _forward_monster_deploy_snapshot(
		"region_facts",
		[normalized_region_id],
		{"region_id": normalized_region_id}
	)


func monster_deploy_profile_snapshot_v06(family_id: String, rank: int) -> Dictionary:
	var normalized_family_id := family_id.strip_edges()
	if normalized_family_id.is_empty() or rank < 1 or rank > 4:
		return _snapshot_failure("monster_deploy_profile_snapshot_invalid", {
			"family_id": normalized_family_id,
			"rank": rank,
		})
	return _forward_monster_deploy_snapshot(
		"monster_profile",
		[normalized_family_id, rank],
		{"family_id": normalized_family_id, "rank": rank}
	)


func monster_deploy_rule_snapshot_v06(actor_id: String) -> Dictionary:
	var normalized_actor_id := actor_id.strip_edges()
	if normalized_actor_id.is_empty():
		return _snapshot_failure("monster_deploy_rule_snapshot_invalid", {"actor_id": normalized_actor_id})
	return _forward_monster_deploy_snapshot(
		"binding_rule",
		[normalized_actor_id],
		{"actor_id": normalized_actor_id}
	)


func monster_deploy_cross_owner_capabilities_v06() -> Dictionary:
	var result := _empty_monster_deploy_capabilities()
	if not has_world() or not _world.has_method(&"monster_deploy_cross_owner_capabilities_v06"):
		return result
	var declared_variant: Variant = _world.call(&"monster_deploy_cross_owner_capabilities_v06")
	if not (declared_variant is Dictionary) or not _is_pure_data(declared_variant):
		result["reason_code"] = "monster_deploy_capability_receipt_invalid"
		return result
	var declared: Dictionary = declared_variant as Dictionary
	result["contract_version"] = str(declared.get("contract_version", ""))
	for fact_name in MONSTER_DEPLOY_SNAPSHOT_METHODS:
		var fact_declared: Dictionary = declared.get(fact_name, {}) if declared.get(fact_name, {}) is Dictionary else {}
		result[fact_name] = {
			"revisioned_snapshot": bool(fact_declared.get("revisioned_snapshot", false)),
			"owner_id": str(fact_declared.get("owner_id", "")),
			"reason_code": str(fact_declared.get("reason_code", "")),
		}
	for participant_name in ["bound_skill_inventory", "product_market_rng", "role_cash_ledger"]:
		var participant_declared: Dictionary = declared.get(participant_name, {}) if declared.get(participant_name, {}) is Dictionary else {}
		result[participant_name] = _normalize_participant_capabilities(participant_declared)
	var methods_ready := _monster_deploy_methods_ready()
	var facts_ready := true
	for fact_name in MONSTER_DEPLOY_SNAPSHOT_METHODS:
		facts_ready = facts_ready and bool((result.get(fact_name, {}) as Dictionary).get("revisioned_snapshot", false))
	var participants_ready := true
	for participant_name in ["bound_skill_inventory", "product_market_rng", "role_cash_ledger"]:
		var participant: Dictionary = result.get(participant_name, {}) as Dictionary
		for capability_name in MONSTER_DEPLOY_PARTICIPANT_CAPABILITIES:
			participants_ready = participants_ready and bool(participant.get(capability_name, false))
	result["methods_ready"] = methods_ready
	result["atomic_ready"] = (
		str(result.get("contract_version", "")) == MONSTER_DEPLOY_CONTRACT_VERSION
		and methods_ready
		and facts_ready
		and participants_ready
	)
	result["reason_code"] = "monster_deploy_cross_owner_ready" if bool(result["atomic_ready"]) else "monster_cross_owner_atomicity_unavailable"
	return result


func prepare_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _forward_monster_deploy_stage("prepare", request, "prepared")


func commit_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _forward_monster_deploy_stage("commit", request, "committed")


func rollback_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _forward_monster_deploy_stage("rollback", request, "rolled_back")


func finalize_monster_deploy_side_effects_v06(request: Dictionary) -> Dictionary:
	return _forward_monster_deploy_stage("finalize", request, "finalized")


func forward_runtime_event(event: Dictionary) -> Dictionary:
	if not _is_pure_data(event):
		push_error("Monster runtime event rejected because it is not pure data.")
		return {
			"forwarded": false,
			"reason_code": "monster_runtime_event_not_pure_data",
			"world_callback_invoked": false,
		}
	runtime_event_forwarded.emit(event.duplicate(true))
	var world_callback_invoked := false
	var world_receipt: Dictionary = {}
	if has_world() and _world.has_method("_on_monster_runtime_event"):
		world_callback_invoked = true
		var world_result: Variant = _world.call("_on_monster_runtime_event", event.duplicate(true))
		if world_result is Dictionary and _is_pure_data(world_result):
			world_receipt = (world_result as Dictionary).duplicate(true)
	return {
		"forwarded": true,
		"reason_code": "monster_runtime_event_forwarded",
		"world_callback_invoked": world_callback_invoked,
		"world_receipt": world_receipt,
	}


func debug_snapshot() -> Dictionary:
	var deploy_capabilities := monster_deploy_cross_owner_capabilities_v06()
	return {
		"bridge_ready": has_world(),
		"world_call_count": _world_call_count,
		"failed_world_call_count": _failed_world_call_count,
		"monster_deploy_forward_count": _monster_deploy_forward_count,
		"monster_deploy_failure_count": _monster_deploy_failure_count,
		"monster_deploy_atomic_ready": bool(deploy_capabilities.get("atomic_ready", false)),
		"monster_deploy_capability_reason": str(deploy_capabilities.get("reason_code", "")),
		"owns_monster_state": false,
		"owns_targeting": false,
		"owns_combat": false,
		"owns_wagers": false,
	}


func _forward_monster_deploy_snapshot(kind: String, arguments: Array, identity: Dictionary) -> Dictionary:
	var method_name: StringName = MONSTER_DEPLOY_SNAPSHOT_METHODS.get(kind, &"")
	if not has_world() or method_name == &"" or not _world.has_method(method_name):
		return _snapshot_failure("monster_deploy_%s_snapshot_unavailable" % kind, identity)
	var value_variant: Variant = _world.callv(method_name, arguments)
	if not (value_variant is Dictionary) or not _is_pure_data(value_variant):
		return _snapshot_failure("monster_deploy_%s_snapshot_invalid" % kind, identity)
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not bool(result.get("available", false)) or not bool(result.get("authoritative", false)):
		result["available"] = false
		result["authoritative"] = false
		if str(result.get("reason_code", "")).is_empty():
			result["reason_code"] = "monster_deploy_%s_snapshot_unavailable" % kind
		return result
	for identity_key in identity:
		if result.has(identity_key) and str(result.get(identity_key)) != str(identity.get(identity_key)):
			return _snapshot_failure("monster_deploy_%s_snapshot_binding_mismatch" % kind, identity)
		result[identity_key] = identity.get(identity_key)
	if str(result.get("snapshot_fingerprint", "")).is_empty():
		var fingerprint_source := result.duplicate(true)
		fingerprint_source.erase("snapshot_fingerprint")
		result["snapshot_fingerprint"] = _stable_fingerprint(fingerprint_source)
	return result


func _forward_monster_deploy_stage(stage: String, request: Dictionary, success_key: String) -> Dictionary:
	if request.is_empty() or not _is_pure_data(request) or str(request.get("transaction_id", "")).strip_edges().is_empty():
		return _stage_failure(stage, success_key, "monster_deploy_side_effect_request_invalid")
	var capabilities := monster_deploy_cross_owner_capabilities_v06()
	var method_name: StringName = MONSTER_DEPLOY_STAGE_METHODS.get(stage, &"")
	if not bool(capabilities.get("atomic_ready", false)) or not has_world() or method_name == &"" or not _world.has_method(method_name):
		return _stage_failure(stage, success_key, "monster_cross_owner_atomicity_unavailable")
	var value_variant: Variant = _world.call(method_name, request.duplicate(true))
	if not (value_variant is Dictionary) or not _is_pure_data(value_variant):
		return _stage_failure(stage, success_key, "monster_deploy_side_effect_receipt_invalid")
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	# Never manufacture a successful stage. The authoritative participant must
	# explicitly return the stage flag and the Controller validates its binding.
	if not bool(result.get(success_key, false)):
		result[success_key] = false
		if str(result.get("reason_code", "")).is_empty():
			result["reason_code"] = "monster_deploy_side_effect_%s_failed" % stage
		_monster_deploy_failure_count += 1
		return result
	_monster_deploy_forward_count += 1
	return result


func _empty_monster_deploy_capabilities() -> Dictionary:
	var result := {
		"contract_version": MONSTER_DEPLOY_CONTRACT_VERSION,
		"region_facts": {"revisioned_snapshot": false, "owner_id": "", "reason_code": ""},
		"monster_profile": {"revisioned_snapshot": false, "owner_id": "", "reason_code": ""},
		"binding_rule": {"revisioned_snapshot": false, "owner_id": "", "reason_code": ""},
		"atomic_ready": false,
		"methods_ready": false,
		"reason_code": "monster_cross_owner_atomicity_unavailable",
	}
	for participant_name in ["bound_skill_inventory", "product_market_rng", "role_cash_ledger"]:
		result[participant_name] = _normalize_participant_capabilities({})
	return result


func _normalize_participant_capabilities(declared: Dictionary) -> Dictionary:
	var result := {
		"owner_id": str(declared.get("owner_id", "")),
		"reason_code": str(declared.get("reason_code", "")),
	}
	for capability_name in MONSTER_DEPLOY_PARTICIPANT_CAPABILITIES:
		result[capability_name] = bool(declared.get(capability_name, false))
	return result


func _monster_deploy_methods_ready() -> bool:
	if not has_world() or not _world.has_method(&"monster_deploy_cross_owner_capabilities_v06"):
		return false
	for method_name in MONSTER_DEPLOY_SNAPSHOT_METHODS.values():
		if not _world.has_method(method_name):
			return false
	for method_name in MONSTER_DEPLOY_STAGE_METHODS.values():
		if not _world.has_method(method_name):
			return false
	return true


func _snapshot_failure(reason_code: String, identity: Dictionary = {}) -> Dictionary:
	var result := identity.duplicate(true)
	result["available"] = false
	result["authoritative"] = false
	result["reason_code"] = reason_code
	result["snapshot_fingerprint"] = ""
	return result


func _stage_failure(stage: String, success_key: String, reason_code: String) -> Dictionary:
	_monster_deploy_failure_count += 1
	return {
		success_key: false,
		"stage": stage,
		"reason_code": reason_code,
	}


func _stable_fingerprint(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize(source.get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonicalize(item))
		return result
	return value


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
