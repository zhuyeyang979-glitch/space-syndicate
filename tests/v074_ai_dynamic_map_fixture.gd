extends RefCounted
class_name V074AIDynamicMapFixture

const CODEC := preload(
	"res://scripts/v07_adapters/v07_canonical_data_codec.gd"
)
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const INDUSTRY_IDS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]


static func build_sources(
	region_count: int,
	actor_id: String = "player.1"
) -> Dictionary:
	var region_ids: Array = []
	var terrain_by_region := {}
	var adjacency_graph := {}
	var sunlight_by_region := {}
	for region_index in range(region_count):
		var region_id := "region.%03d" % region_index
		region_ids.append(region_id)
		terrain_by_region[region_id] = (
			"land" if region_index % 3 != 1 else "ocean"
		)
		sunlight_by_region[region_id] = (
			"sunlit" if region_index % 2 == 0 else "dark"
		)
	for region_index in range(region_count):
		var region_id := str(region_ids[region_index])
		adjacency_graph[region_id] = [
			region_ids[(region_index - 1 + region_count) % region_count],
			region_ids[(region_index + 1) % region_count],
		]
	var map_receipt := {
		"schema_version": 1,
		"ruleset_id": "v0.7.4",
		"source_revision": 7,
		"map_id": "map.fixture.%02d" % region_count,
		"map_fingerprint": "",
		"region_count": region_count,
		"region_ids": region_ids,
		"terrain_by_region": terrain_by_region,
		"adjacency_graph": adjacency_graph,
		"sunlight_by_region": sunlight_by_region,
	}
	map_receipt["map_fingerprint"] = CODEC.fingerprint(
		map_receipt,
		"map_fingerprint"
	)

	var slots: Array = []
	for region_index in range(region_count):
		var region_id := str(region_ids[region_index])
		for facility_type in FACILITY_TYPES:
			for industry_id in INDUSTRY_IDS:
				slots.append(_slot(
					region_id,
					facility_type,
					industry_id,
					str(sunlight_by_region.get(region_id, "")),
					actor_id
				))
	var own_cards := [
		_card("card.instance.factory.life", "factory", "life"),
		_card("card.instance.market.energy", "market", "energy"),
		_card(
			"card.instance.warehouse.shipping",
			"warehouse",
			"shipping"
		),
		_card(
			"card.instance.warehouse.commerce",
			"warehouse",
			"commerce"
		),
	]
	var legal_actions := [
		_action(
			own_cards[0],
			"BUILD_NEW",
			"region.000",
			"factory",
			"life"
		),
		_action(
			own_cards[1],
			"UPGRADE_OWN",
			"region.001",
			"market",
			"energy"
		),
		_action(
			own_cards[2],
			"REPAIR_OWN",
			"region.002",
			"warehouse",
			"shipping"
		),
		_action(
			own_cards[3],
			"BUILD_NEW",
			"region.003",
			"warehouse",
			"commerce"
		),
	]
	return {
		"map_receipt": map_receipt,
		"public_facilities": {
			"schema_version": 1,
			"source_revision": 11,
			"public_facility_slots": slots,
		},
		"legal_targets": {
			"schema_version": 1,
			"source_revision": 13,
			"authorized_legal_actions": legal_actions,
		},
		"own_private_facts": {
			"schema_version": 1,
			"source_revision": 17,
			"viewer_id": actor_id,
			"own_cards": own_cards,
		},
	}


static func source_fingerprint(sources: Dictionary) -> String:
	return CODEC.fingerprint(sources)


static func _slot(
	region_id: String,
	facility_type: String,
	industry_id: String,
	solar_state: String,
	actor_id: String
) -> Dictionary:
	var occupied := false
	var owner_id := ""
	var rank := 0
	var damage_points := 0
	if region_id == "region.001" 			and facility_type == "market" 			and industry_id == "energy":
		occupied = true
		owner_id = actor_id
		rank = 1
	elif region_id == "region.002" 			and facility_type == "warehouse" 			and industry_id == "shipping":
		occupied = true
		owner_id = actor_id
		rank = 1
		damage_points = 1
	elif region_id == "region.004" 			and facility_type == "warehouse" 			and industry_id == "life":
		occupied = true
		owner_id = "player.2"
		rank = 2
	var is_warehouse := facility_type == "warehouse" and occupied
	var throughput_multiplier := 2 if solar_state == "sunlit" else 1
	return {
		"slot_id": slot_id(region_id, facility_type, industry_id),
		"region_id": region_id,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"occupied": occupied,
		"facility_id": (
			"facility.%s.%s.%s" % [
				region_id,
				facility_type,
				industry_id,
			]
			if occupied
			else ""
		),
		"owner_id": owner_id,
		"rank": rank,
		"damage_points": damage_points,
		"damage_revision": 1 if occupied else 0,
		"facility_generation": 1 if occupied else 0,
		"slot_generation": 3,
		"solar_efficiency_state": solar_state,
		"public_capacity": rank * 8 if is_warehouse else 0,
		"public_ingress_throughput": (
			rank * 2 * throughput_multiplier if is_warehouse else 0
		),
		"public_egress_throughput": (
			rank * 2 * throughput_multiplier if is_warehouse else 0
		),
	}


static func _card(
	instance_id: String,
	facility_type: String,
	industry_id: String
) -> Dictionary:
	return {
		"card_instance_id": instance_id,
		"card_definition_id": (
			"facility.%s.%s.rank_1" % [facility_type, industry_id]
		),
		"facility_type": facility_type,
		"industry_id": industry_id,
		"rank": 1,
	}


static func _action(
	card: Dictionary,
	action_mode: String,
	region_id: String,
	facility_type: String,
	industry_id: String
) -> Dictionary:
	return {
		"card_instance_id": str(card.get("card_instance_id", "")),
		"card_definition_id": str(card.get(
			"card_definition_id",
			""
		)),
		"facility_type": facility_type,
		"industry_id": industry_id,
		"action_mode": action_mode,
		"target_slot_id": slot_id(
			region_id,
			facility_type,
			industry_id
		),
		"region_id": region_id,
	}


static func slot_id(
	region_id: String,
	facility_type: String,
	industry_id: String
) -> String:
	return "slot.%s.%s.%s" % [
		region_id,
		facility_type,
		industry_id,
	]