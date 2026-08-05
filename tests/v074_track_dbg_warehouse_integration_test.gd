extends SceneTree

const TrackCore := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DbgCore := preload(
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd"
)
const V074Definitions := preload(
	"res://scripts/v074/facility/v074_card_definition_registry.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var roster := ["player.one", "player.two", "player.three"]
	var legacy := TrackCore.new()
	var legacy_started := legacy.start_match(
		roster,
		74001,
		{"match_instance_id": "match.v072.registry.audit"}
	)
	var legacy_contract := legacy.interface_contract_v1()
	_expect(bool(legacy_started.get("accepted", false)), "legacy track starts")
	_expect(
		str(legacy_contract.get("normal_track_definition_registry_id", ""))
		== "space_syndicate.v072.card_definition_registry.v1",
		"legacy track keeps the V0.7.2 registry by default"
	)
	_expect(
		(legacy_contract.get("normal_track_definition_ids", []) as Array).size()
		== 12,
		"legacy track keeps twelve factory and market L1 definitions"
	)

	var v074 := TrackCore.new()
	var v074_started := v074.start_match(
		roster,
		74001,
		{
			"match_instance_id": "match.v074.registry.audit",
			"card_definition_registry_id": V074Definitions.REGISTRY_ID,
		}
	)
	var v074_contract := v074.interface_contract_v1()
	var v074_ids := (
		v074_contract.get("normal_track_definition_ids", []) as Array
	)
	_expect(bool(v074_started.get("accepted", false)), "V0.7.4 track starts")
	_expect(
		str(v074_contract.get("normal_track_definition_registry_id", ""))
		== V074Definitions.REGISTRY_ID,
		"V0.7.4 track binds the complete facility registry"
	)
	_expect(v074_ids.size() == 18, "V0.7.4 track exposes eighteen L1 definitions")
	var warehouse_count := 0
	for definition_id_variant in v074_ids:
		if str(definition_id_variant).contains(".warehouse."):
			warehouse_count += 1
	_expect(warehouse_count == 6, "V0.7.4 track exposes six warehouse L1 definitions")

	var dbg := DbgCore.new()
	var initialized := dbg.initialize("player.one", 74002)
	_expect(bool(initialized.get("initialized", false)), "personal DBG initializes")
	_expect(
		int(initialized.get("starter_card_instance_count", 0)) == 12,
		"personal DBG starter deck remains factory and market only"
	)
	var warehouse_spec := dbg.card_definition_for_active_profile(
		"facility.warehouse.life.rank_1"
	)
	_expect(
		str(warehouse_spec.get("card_type", "")) == "warehouse"
		and int(warehouse_spec.get("primary_asset_cost", 0)) == 1
		and not bool(warehouse_spec.get("starter_badge", true)),
		"warehouse resolves as a paid standard L1 card"
	)
	var purchase_intent := dbg.create_authority_intent(
		"request.warehouse.purchase.audit",
		DbgCore.ACTION_ACCEPT_PURCHASE,
		{
			"purchase_receipt_id": "track.purchase.warehouse.audit",
			"card_spec": warehouse_spec,
		}
	)
	var purchase_receipt := dbg.apply_intent(purchase_intent)
	var state := (
		dbg.core_authority_snapshot().get("state", {}) as Dictionary
	)
	var discard := state.get("discard", []) as Array
	var warehouse_in_discard := false
	for card_variant in discard:
		var card := card_variant as Dictionary
		if str(card.get("definition_id", "")) 				== "facility.warehouse.life.rank_1":
			warehouse_in_discard = true
	_expect(
		bool(purchase_receipt.get("success", false))
		and str(purchase_receipt.get("destination_zone", "")) == "discard",
		"warehouse purchase commits to personal discard"
	)
	_expect(warehouse_in_discard, "purchased warehouse exists in discard")
	_expect(
		(state.get("hand", []) as Array).size() == 5,
		"warehouse purchase does not enter the hand immediately"
	)

	print(
		"V074_TRACK_DBG_WAREHOUSE_INTEGRATION_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)
