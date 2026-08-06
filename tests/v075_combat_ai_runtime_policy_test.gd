extends SceneTree

const AssetCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)

class RuntimeHarness extends V075RuntimeOwner:
	var fixture_legal: Array = []
	var fixture_facts: Dictionary = {"hand": [], "discard": []}
	var fixture_facilities: Array = []

	func legal_card_actions(_actor_id: String) -> Array:
		return fixture_legal.duplicate(true)

	func _dbg_projection(_actor_id: String) -> Dictionary:
		return {"facts": fixture_facts.duplicate(true)}

	func _card_in_hand(
		_actor_id: String,
		card_instance_id: String
	) -> Dictionary:
		for card_variant in fixture_facts.get("hand", []) as Array:
			var card := card_variant as Dictionary
			if str(card.get("instance_id", "")) == card_instance_id:
				return card.duplicate(true)
		return {}

	func configure_assets(actor_id: String, assets: Dictionary) -> void:
		_asset_state = {"players": {actor_id: {"assets": assets.duplicate(true)}}}

	func canonical_facility_actions(actor_id: String) -> Array:
		return _ai_legal_actions(actor_id)

	func canonical_facility_cards(actor_id: String) -> Array:
		return _ai_own_cards(actor_id)

	func available_actions(
		actor_id: String,
		queue: Array,
		legal: Array
	) -> Array:
		return _auto_available_actions(actor_id, queue, legal)

	func configure_map_receipt(receipt: Dictionary) -> void:
		_map_genesis_receipt = receipt.duplicate(true)

	func preferred_action(
		legal: Array,
		actor_id: String = ACTOR_ID
	) -> Dictionary:
		return _preferred_v075_ai_action(legal, actor_id)

	func configure_acquisition_probe(
		track: RefCounted,
		asset_state: Dictionary,
		actor_id: String
	) -> void:
		_track_core = track
		_asset_state = asset_state.duplicate(true)
		_player_ids = [actor_id]

	func acquisition_facts(actor_id: String) -> Dictionary:
		return _v075_track_acquisition_facts(actor_id)

	func initial_combat_slot_open(actor_id: String) -> bool:
		return _v075_combat_slot_open(actor_id, true)

	func _public_occupied_facilities() -> Array:
		return fixture_facilities.duplicate(true)


const ACTOR_ID := "player.ai.1"
const COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := RuntimeHarness.new()
	root.add_child(runtime)
	_test_zero_asset_projection_is_present(runtime)
	_test_combat_actions_bypass_v074_facility_canonicalization(runtime)
	_test_owned_combat_card_reserves_its_action_assets(runtime)
	_test_monster_deployment_prefers_public_two_hop_route(runtime)
	_test_military_task_selection_is_stable_and_balanced(runtime)
	_expect(
		runtime.initial_combat_slot_open(ACTOR_ID),
		"first visible combat opportunity opens before settlement pacing closes"
	)
	_finish()


func _test_zero_asset_projection_is_present(runtime: RuntimeHarness) -> void:
	var zero_assets := {}
	for color_id in COLORS:
		zero_assets[color_id] = 0
	var asset_state := AssetCore.create_state(
		"batch.zero.asset.projection",
		[ACTOR_ID],
		[ACTOR_ID],
		{ACTOR_ID: zero_assets}
	)
	var track := TrackProjectionStub.new()
	track.projection = {
		"viewer_private_facts": {
			"own_segment_items": [{
				"instance_id": "track.zero.asset.card",
				"card_kind": "normal_card",
				"claimable": true,
			}],
		},
	}
	runtime.configure_acquisition_probe(track, asset_state, ACTOR_ID)
	var facts := runtime.acquisition_facts(ACTOR_ID)
	var available := facts.get("available_unreserved_assets", {}) as Dictionary
	_expect(
		not facts.is_empty() and available.size() == COLORS.size(),
		"zero-valued six-color asset projection remains a valid acquisition input"
	)
	for color_id in COLORS:
		_expect(
			available.has(color_id) and int(available.get(color_id, -1)) == 0,
			"zero asset projection keeps the %s field" % color_id
		)


class TrackProjectionStub extends RefCounted:
	var projection: Dictionary = {}

	func player_projection_v1(_actor_id: String) -> Dictionary:
		return projection.duplicate(true)


func _test_combat_actions_bypass_v074_facility_canonicalization(
	runtime: RuntimeHarness
) -> void:
	runtime.fixture_legal = [
		{
			"card_instance_id": "dbg.player.ai.1.000001",
			"card_definition_id": "facility.factory.life.rank_1",
			"facility_type": "factory",
			"industry_id": "life",
			"facility_action_mode": "BUILD_NEW",
			"target_slot_id": "slot.region.000.factory.life.00",
			"target_region_id": "region.000",
		},
		{
			"action_domain": "monster",
			"card_instance_id": "dbg.player.ai.1.000002",
			"monster_card_mode": "DEPLOY_NEW",
			"target_region_id": "region.000",
		},
		{
			"action_domain": "military",
			"card_instance_id": "dbg.player.ai.1.000003",
			"task_kind": "assault_region",
			"target_region_id": "region.000",
		},
	]
	var canonical := runtime.canonical_facility_actions(ACTOR_ID)
	_expect(
		canonical.size() == 1
		and str((canonical[0] as Dictionary).get("facility_type", ""))
			== "factory",
		"V074 dynamic-map canonical input receives facility actions only"
	)
	_expect(
		runtime.fixture_legal.size() == 3,
		"V075 authoritative legal actions retain monster and military options"
	)
	runtime.fixture_facts = {
		"hand": [
			{
				"instance_id": "dbg.player.ai.1.000001",
				"definition_id": "facility.factory.life.rank_1",
				"card_type": "factory",
				"primary_color": "life",
				"level": 1,
			},
			{
				"instance_id": "dbg.player.ai.1.000002",
				"definition_id": "monster.spore_tide_emperor.life.rank_1",
				"card_type": "monster.spore_tide_emperor",
				"primary_color": "life",
				"level": 1,
			},
			{
				"instance_id": "dbg.player.ai.1.000003",
				"definition_id": "military.planetary_defense_force.life.rank_1",
				"card_type": "military.planetary_defense_force",
				"primary_color": "life",
				"level": 1,
			},
		],
		"discard": [],
	}
	var canonical_cards := runtime.canonical_facility_cards(ACTOR_ID)
	_expect(
		canonical_cards.size() == 1
		and str((canonical_cards[0] as Dictionary).get(
			"facility_type",
			""
		)) == "factory",
		"V074 dynamic-map canonical input receives facility cards only"
	)


func _test_owned_combat_card_reserves_its_action_assets(
	runtime: RuntimeHarness
) -> void:
	var assets := {}
	for color_id in COLORS:
		assets[color_id] = 0
	assets["commerce"] = 2
	var facility_card := {
		"instance_id": "dbg.player.ai.1.000010",
		"card_type": "factory",
		"primary_color": "commerce",
		"primary_asset_cost": 1,
	}
	var military_card := {
		"instance_id": "dbg.player.ai.1.000011",
		"card_type": "military.planetary_defense_force",
		"primary_color": "commerce",
		"primary_asset_cost": 2,
	}
	runtime.fixture_facts = {
		"hand": [facility_card, military_card],
		"discard": [],
	}
	runtime.configure_assets(ACTOR_ID, assets)
	var facility_option := {
		"option_id": "option.facility",
		"card_instance_id": facility_card.get("instance_id"),
		"facility_type": "factory",
		"target_slot_id": "slot.region.000.factory.commerce.00",
	}
	var military_option := {
		"option_id": "option.military",
		"action_domain": "military",
		"card_instance_id": military_card.get("instance_id"),
		"task_kind": "assault_region",
		"target_slot_id": "combat.military.assault_region.region.000",
		"target_region_id": "region.000",
	}
	var available := runtime.available_actions(
		ACTOR_ID,
		[],
		[facility_option, military_option]
	)
	_expect(
		available.size() == 1
		and str((available[0] as Dictionary).get("action_domain", ""))
			== "military",
		"AI preserves the owned combat card cost and can queue that combat action"
	)
	_expect(
		int(assets.get("commerce", -1)) == 2,
		"combat asset reservation policy does not mutate production assets"
	)


func _test_monster_deployment_prefers_public_two_hop_route(
	runtime: RuntimeHarness
) -> void:
	runtime.configure_map_receipt({
		"map_id": "map.ai.policy",
		"map_fingerprint": "fingerprint.ai.policy",
		"region_ids": ["region.000", "region.001", "region.002"],
		"adjacency_graph": {
			"region.000": ["region.001"],
			"region.001": ["region.000", "region.002"],
			"region.002": ["region.001"],
		},
		"edge_distance_milli_arc": {
			"region.000": {"region.001": 500000},
			"region.001": {
				"region.000": 500000,
				"region.002": 500000,
			},
			"region.002": {"region.001": 500000},
		},
	})
	runtime.fixture_facilities = [{
		"facility_id": "facility.enemy.life",
		"facility_generation": 1,
		"owner_player_id": "player.enemy",
		"region_id": "region.002",
		"facility_type": "factory",
		"industry_id": "life",
		"status": "active",
	}]
	var options: Array = []
	for region_id in ["region.002", "region.001", "region.000"]:
		options.append({
			"option_id": "option.%s" % region_id,
			"actor_id": ACTOR_ID,
			"action_domain": "monster",
			"monster_card_mode": "DEPLOY_NEW",
			"card_instance_id": "dbg.player.ai.1.monster.route",
			"card_definition_id": (
				"monster.spore_tide_emperor.life.rank_1"
			),
			"target_region_id": region_id,
			"target_slot_id": "combat.monster.deploy.%s" % region_id,
		})
	var preferred := runtime.preferred_action(options)
	_expect(
		str(preferred.get("target_region_id", "")) == "region.000",
		"AI deploys from a public two-hop route instead of on the target facility"
	)


func _test_military_task_selection_is_stable_and_balanced(
	runtime: RuntimeHarness
) -> void:
	var options := [
		{
			"actor_id": ACTOR_ID,
			"action_domain": "military",
			"task_kind": "assault_region",
			"option_id": "option.military.region",
		},
		{
			"actor_id": ACTOR_ID,
			"action_domain": "military",
			"task_kind": "assault_monster",
			"option_id": "option.military.monster",
		},
	]
	runtime.set("_batch_number", 3)
	var first := runtime.preferred_action(options, ACTOR_ID)
	var replay := runtime.preferred_action(options, ACTOR_ID)
	runtime.set("_batch_number", 4)
	var next_batch := runtime.preferred_action(options, ACTOR_ID)
	_expect(
		first == replay
		and str(first.get("task_kind", ""))
		!= str(next_batch.get("task_kind", "")),
		"military task selection alternates by stable public batch facts"
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("V075_COMBAT_AI_RUNTIME_POLICY_TEST|%s" % JSON.stringify({
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"passed": _checks - _failures.size(),
		"total": _checks,
		"failures": _failures,
	}))
	quit(0 if _failures.is_empty() else 1)
