extends Node
class_name V076V075ProductionAdapterV1

## Stateless consumer adapter for the authorized production composition.
##
## V075RuntimeOwner remains the only production card, asset, military-source,
## and combat mutation authority.  This adapter only translates the narrow
## V076 Direct Action dependency surface; it stores no state and owns no
## ledger, queue, tick, map, asset, unit, damage, or presentation facts.

const CardDefinitionsV075 := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)

const OWNER_ID := "component.current.v075_runtime_owner"
const ADAPTER_ID := "component.v076.v075_production_adapter"

var _runtime_owner: Variant


func bind_runtime_owner(runtime_owner: Variant) -> Dictionary:
	if runtime_owner == null:
		return _reject("v076_v075_production_runtime_owner_missing")
	var required := [
		"validate_v076_production_military_bundle",
		"v076_commit_production_asset_reservation",
		"v076_release_production_asset_reservation",
		"v076_consume_production_asset_reservation",
		"v076_military_unit_index_by_uid",
		"v076_military_roster_snapshot",
		"v076_claim_military_submission",
		"v076_release_military_submission_claim",
		"v076_remove_military_unit",
		"v076_dispatch_military_monster_damage",
	]
	for method_name in required:
		if not runtime_owner.has_method(method_name):
			return _reject("v076_v075_production_runtime_owner_method_missing:%s" % method_name)
	_runtime_owner = runtime_owner
	return {
		"accepted": true,
		"reason": "",
		"adapter_id": ADAPTER_ID,
		"owner_id": OWNER_ID,
	}


func validate_authorized_bundle(bundle: Dictionary) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"validate_v076_production_military_bundle",
		bundle
	) as Dictionary


func exact_definition(card_id: String) -> Dictionary:
	var definition := CardDefinitionsV075.definition(card_id)
	if definition.is_empty() or CardDefinitionsV075.card_domain(
		str(definition.get("card_type", ""))
	) != "military":
		return {}
	var result := definition.duplicate(true)
	result["kind"] = "military_force"
	result["rank"] = int(definition.get("level", 0))
	return result


func rank(card_id: String) -> int:
	return int(CardDefinitionsV075.definition(card_id).get("level", 0))


func commit_reservation(plan: Dictionary) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_commit_production_asset_reservation",
		plan
	) as Dictionary


func release_reservation(reservation_id: String, reason: String) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_release_production_asset_reservation",
		reservation_id,
		reason
	) as Dictionary


func consume_reservation(
	reservation_id: String,
	settlement: Dictionary
) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_consume_production_asset_reservation",
		reservation_id,
		settlement
	) as Dictionary


func unit_index_by_uid(unit_uid: int) -> int:
	if not _bound():
		return -1
	return int(_runtime_owner.call(
		"v076_military_unit_index_by_uid",
		unit_uid
	))


func roster_snapshot(include_hidden: bool = true) -> Array:
	if not _bound():
		return []
	return (_runtime_owner.call(
		"v076_military_roster_snapshot",
		include_hidden
	) as Array).duplicate(true)


func claim_submission(
	unit_uid: int,
	submission_id: String,
	card_instance_id: String,
	request_fingerprint: String
) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_claim_military_submission",
		unit_uid,
		submission_id,
		card_instance_id,
		request_fingerprint
	) as Dictionary


func release_submission_claim(
	unit_uid: int,
	submission_id: String,
	reason: String
) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_release_military_submission_claim",
		unit_uid,
		submission_id,
		reason
	) as Dictionary


func remove_unit(unit_index: int, reason: String) -> bool:
	if not _bound():
		return false
	return bool(_runtime_owner.call(
		"v076_remove_military_unit",
		unit_index,
		reason
	))


func dispatch_military_monster_damage(command: Dictionary) -> Dictionary:
	if not _bound():
		return {"handled": false, "reason": "v076_v075_production_adapter_not_bound"}
	return _runtime_owner.call(
		"v076_dispatch_military_monster_damage",
		command
	) as Dictionary


func debug_snapshot() -> Dictionary:
	return {
		"adapter_id": ADAPTER_ID,
		"owner_id": OWNER_ID,
		"bound": _bound(),
		"owns_tick": false,
		"owns_authority_sequence": false,
		"owns_rng": false,
		"owns_asset_quantity": false,
		"owns_military_unit_state": false,
		"owns_damage": false,
		"owns_card_catalog": false,
		"owns_presentation": false,
	}


func _bound() -> bool:
	return _runtime_owner != null and is_instance_valid(_runtime_owner)


static func _reject(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
