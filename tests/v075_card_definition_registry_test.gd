extends SceneTree

const Registry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const TrackCore := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DbgCore := preload(
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := Registry.registry_contract()
	_expect(
		int(contract.get("active_monster_family_count", 0)) == 6,
		"six monster families are registered"
	)
	_expect(
		int(contract.get("active_military_definition_count", 0)) == 3,
		"three military definitions are registered"
	)
	_expect(
		contract.get("normal_subtype_weights_basis_points", {}) == {
			"facility": 7000,
			"monster": 1500,
			"military": 1500,
		},
		"normal subtype weights are 70/15/15"
	)

	var templates := Registry.track_spawn_definition_ids()
	var subtype_counts := {
		"facility": 0,
		"monster": 0,
		"military": 0,
	}
	for definition_id in templates:
		var definition := Registry.definition(definition_id)
		_expect(not definition.is_empty(), "weighted template resolves")
		_expect(
			Registry.definition_error(definition).is_empty(),
			"weighted template is canonical"
		)
		var domain := Registry.card_domain(str(definition.get("card_type", "")))
		subtype_counts[domain] = int(subtype_counts.get(domain, 0)) + 1
	_expect(templates.size() == 240, "weighted normal supply has 240 units")
	_expect(
		subtype_counts == {
			"facility": 168,
			"monster": 36,
			"military": 36,
		},
		"weighted template counts exactly represent 70/15/15"
	)

	var monster := Registry.definition(
		Registry.standard_definition_id(
			"monster.spore_tide_emperor",
			"technology",
			1
		)
	)
	_expect(
		Registry.card_domain(str(monster.get("card_type", ""))) == "monster",
		"monster card domain is explicit"
	)
	_expect(
		str(monster.get("primary_color", "")) == "technology"
		and int(monster.get("primary_asset_cost", 0)) == 2,
		"monster card keeps track color and V075 rank-one cost"
	)
	var monster_other_color := Registry.definition(
		Registry.standard_definition_id(
			"monster.spore_tide_emperor",
			"life",
			1
		)
	)
	_expect(
		str(monster.get("merge_family_id", ""))
			== str(monster_other_color.get("merge_family_id", ""))
			and DbgCore._merge_eligibility_reason(
				monster,
				monster_other_color
			) == "",
		"same-family monster cards merge across independent track cost colors"
	)
	var military := Registry.definition(
		Registry.standard_definition_id(
			"military.air_superiority_fighter",
			"shipping",
			1
		)
	)
	_expect(
		Registry.card_domain(str(military.get("card_type", ""))) == "military",
		"military card domain is explicit"
	)
	_expect(
		str(military.get("primary_color", "")) == "shipping"
		and int(military.get("primary_asset_cost", 0)) == 2,
		"military card keeps track color and V075 rank-one cost"
	)

	var track := TrackCore.new()
	var started := track.start_match(
		["player.one", "player.two", "player.three"],
		75075,
		{
			"balance_profile_id": TrackCore.BALANCE_PROFILE_ID,
			"balance_profile_fingerprint": TrackCore.BALANCE_PROFILE_FINGERPRINT,
			"normal_card_ratio_basis_points": 6000,
			"commodity_card_ratio_basis_points": 4000,
			"local_visible_slot_count": 10,
			"match_instance_id": "match.v075.registry.test",
			"card_definition_registry_id": Registry.REGISTRY_ID,
		}
	)
	_expect(bool(started.get("accepted", false)), "track accepts V075 registry")
	var authority := track.core_authority_v1()
	var track_state := authority.get("authority_state", {}) as Dictionary
	var ratio := (
		track_state.get("type_supply_state", {}) as Dictionary
	).get("ratio_basis_points", {}) as Dictionary
	_expect(
		ratio == {
			"normal_card": 6000,
			"commodity_card": 4000,
		},
		"outer normal commodity ratio remains 6000/4000"
	)
	_expect(
		(
			(track_state.get("normal_supply_state", {}) as Dictionary)
			.get("templates", []) as Array
		).size() == 240,
		"track authority uses weighted V075 normal templates"
	)
	var projection := track.player_projection_v1("player.one")
	var own_items := (
		projection.get("viewer_private_facts", {}) as Dictionary
	).get("own_segment_items", []) as Array
	_expect(own_items.size() == 10, "local V075 track segment exposes ten real cards")
	var instance_ids: Array[String] = []
	for item_variant in own_items:
		var item := item_variant as Dictionary
		var instance_id := str(item.get("instance_id", ""))
		if not instance_ids.has(instance_id):
			instance_ids.append(instance_id)
	_expect(instance_ids.size() == 10, "ten visible cards have unique instances")

	var dbg := DbgCore.new()
	var initialized := dbg.initialize("player.one", 75123)
	_expect(bool(initialized.get("initialized", false)), "DBG initializes")
	var monster_purchase := dbg.create_authority_intent(
		"intent.v075.registry.monster.purchase",
		DbgCore.ACTION_ACCEPT_PURCHASE,
		{
			"purchase_receipt_id": "receipt.track.monster.purchase",
			"card_spec": monster,
		}
	)
	var monster_receipt := dbg.apply_intent(monster_purchase)
	_expect(
		bool(monster_receipt.get("success", false))
		and str(monster_receipt.get("destination_zone", "")) == "discard",
		"purchased monster normal card enters personal discard"
	)
	var military_purchase := dbg.create_authority_intent(
		"intent.v075.registry.military.purchase",
		DbgCore.ACTION_ACCEPT_PURCHASE,
		{
			"purchase_receipt_id": "receipt.track.military.purchase",
			"card_spec": military,
		}
	)
	var military_receipt := dbg.apply_intent(military_purchase)
	_expect(
		bool(military_receipt.get("success", false))
		and str(military_receipt.get("destination_zone", "")) == "discard",
		"purchased military normal card enters personal discard"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_CARD_DEFINITION_REGISTRY_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
