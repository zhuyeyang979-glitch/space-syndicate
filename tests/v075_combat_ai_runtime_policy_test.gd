extends SceneTree

const AssetCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)

class RuntimeHarness extends V075RuntimeOwner:
	var fixture_legal: Array = []
	var fixture_facts: Dictionary = {"hand": [], "discard": []}
	var fixture_facilities: Array = []
	var fixture_monsters: Array = []

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

	func prefers_monster_upgrade(actor_id: String) -> bool:
		return _v075_actor_prefers_monster_upgrade(actor_id)

	func choose_matching_monster_action(
		actor_id: String,
		facts: Dictionary
	) -> Dictionary:
		return _v075_choose_matching_monster_action(actor_id, facts)

	func _public_occupied_facilities() -> Array:
		return fixture_facilities.duplicate(true)

	func _v075_public_monsters() -> Array:
		return fixture_monsters.duplicate(true)


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
	_test_rank_one_owner_pursues_one_natural_upgrade(runtime)
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


func _test_rank_one_owner_pursues_one_natural_upgrade(
	runtime: RuntimeHarness
) -> void:
	var actor_id := "player.ai.2"
	var source_id := "monster.source.ai.2"
	var card_id := "dbg.player.ai.2.monster.blue-edge"
	var merge_family_id := "unit.monster.blue_edge_knight"
	runtime.fixture_monsters = [{
		"source_instance_id": source_id,
		"owner_player_id": actor_id,
		"monster_family_id": "blue_edge_knight",
		"status": "active",
		"rank": 1,
	}]
	runtime.fixture_facts = {
		"hand": [{
			"instance_id": card_id,
			"definition_id": "monster.blue_edge_knight.life.rank_1",
			"card_type": "monster.blue_edge_knight",
			"merge_family_id": merge_family_id,
			"primary_color": "life",
			"level": 1,
		}],
		"discard": [],
	}
	var refresh_option := {
		"option_id": "option.monster.refresh.blue-edge",
		"actor_id": actor_id,
		"action_domain": "monster",
		"monster_card_mode": "REFRESH_EXISTING",
		"card_instance_id": card_id,
		"card_definition_id": "monster.blue_edge_knight.life.rank_1",
		"target_source_instance_id": source_id,
	}
	var military_option := {
		"option_id": "option.military.region.after-refresh",
		"actor_id": actor_id,
		"action_domain": "military",
		"task_kind": "assault_region",
	}
	_expect(
		runtime.prefers_monster_upgrade(actor_id),
		"an owner with an active rank-one monster pursues its natural duplicate"
	)
	var single_refresh := runtime.preferred_action([refresh_option], actor_id)
	_expect(
		single_refresh.is_empty(),
		"one active-family card stays in hand for a naturally drawn duplicate"
	)
	(runtime.fixture_facts.get("discard", []) as Array).append({
		"instance_id": "dbg.player.ai.2.monster.blue-edge.duplicate",
		"definition_id": "monster.blue_edge_knight.energy.rank_1",
		"card_type": "monster.blue_edge_knight",
		"merge_family_id": merge_family_id,
		"primary_color": "energy",
		"level": 1,
	})
	var alternate := runtime.preferred_action(
		[refresh_option, military_option],
		actor_id
	)
	_expect(
		str(alternate.get("action_domain", "")) == "military",
		"a known discard duplicate makes refresh yield to another legal action"
	)
	var reserve_assets := {}
	for color_id in COLORS:
		reserve_assets[color_id] = 0
	reserve_assets["life"] = 2
	runtime.configure_assets(actor_id, reserve_assets)
	var facility_card := {
		"instance_id": "dbg.player.ai.2.facility.life",
		"card_type": "factory",
		"primary_color": "life",
		"primary_asset_cost": 1,
	}
	(runtime.fixture_facts.get("hand", []) as Array).append(facility_card)
	var facility_option := {
		"option_id": "option.facility.life.after-hold",
		"card_instance_id": facility_card.get("instance_id"),
		"facility_type": "factory",
		"target_slot_id": "slot.region.000.factory.life.00",
	}
	var available_while_holding := runtime.available_actions(
		actor_id,
		[],
		[refresh_option, facility_option]
	)
	_expect(
		_has_card_option(
			available_while_holding,
			str(facility_card.get("instance_id", ""))
		),
		"a held monster card does not reserve assets away from hand-cycling actions"
	)
	var discard_only_refresh := runtime.preferred_action(
		[refresh_option],
		actor_id
	)
	_expect(
		discard_only_refresh.is_empty(),
		"a hidden reshuffle cannot consume the visible active-family merge seed"
	)
	var duplicate_card := (
		(runtime.fixture_facts.get("discard", []) as Array).pop_back()
		as Dictionary
	)
	(runtime.fixture_facts.get("hand", []) as Array).append(duplicate_card)
	var duplicate_refresh := refresh_option.duplicate(true)
	duplicate_refresh["option_id"] = "option.monster.refresh.blue-edge.duplicate"
	duplicate_refresh["card_instance_id"] = (
		"dbg.player.ai.2.monster.blue-edge.duplicate"
	)
	duplicate_refresh["card_definition_id"] = (
		"monster.blue_edge_knight.energy.rank_1"
	)
	var held_pair := runtime.preferred_action(
		[refresh_option, duplicate_refresh],
		actor_id
	)
	_expect(
		held_pair.is_empty(),
		"a complete same-family pair stays in hand for the imminent maintenance merge"
	)
	runtime.fixture_monsters[0]["rank"] = 2
	_expect(
		not runtime.prefers_monster_upgrade(actor_id),
		"the deterministic acquisition preference ends after the first upgrade"
	)
	runtime.fixture_monsters[0]["rank"] = 1
	runtime.fixture_facts = {
		"hand": [
			{
				"instance_id": "dbg.player.ai.2.mirror.1",
				"card_type": "monster.mirror_hunter",
				"merge_family_id": "unit.monster.mirror_hunter",
				"level": 1,
			},
			{
				"instance_id": "dbg.player.ai.2.mirror.2",
				"card_type": "monster.mirror_hunter",
				"merge_family_id": "unit.monster.mirror_hunter",
				"level": 1,
			},
			{
				"instance_id": "dbg.player.ai.2.spore.1",
				"card_type": "monster.spore_tide_emperor",
				"merge_family_id": "unit.monster.spore_tide_emperor",
				"level": 1,
			},
		],
		"discard": [],
	}
	var replacement_options := [
		{
			"option_id": "option.replace.spore",
			"actor_id": actor_id,
			"action_domain": "monster",
			"monster_card_mode": "REPLACE_EXISTING",
			"card_instance_id": "dbg.player.ai.2.spore.1",
			"card_definition_id": "monster.spore_tide_emperor.life.rank_1",
		},
		{
			"option_id": "option.replace.mirror",
			"actor_id": actor_id,
			"action_domain": "monster",
			"monster_card_mode": "REPLACE_EXISTING",
			"card_instance_id": "dbg.player.ai.2.mirror.1",
			"card_definition_id": "monster.mirror_hunter.energy.rank_1",
		},
	]
	var replacement := runtime.preferred_action(
		replacement_options,
		actor_id
	)
	_expect(
		str(replacement.get("card_instance_id", ""))
			== "dbg.player.ai.2.mirror.1",
		"replacement aligns the active family with the strongest owned merge pair"
	)
	runtime.fixture_facts = {
		"hand": [
			{
				"instance_id": "dbg.player.ai.2.blue.1",
				"card_type": "monster.blue_edge_knight",
				"merge_family_id": "unit.monster.blue_edge_knight",
				"level": 1,
			},
			{
				"instance_id": "dbg.player.ai.2.mirror.only",
				"card_type": "monster.mirror_hunter",
				"merge_family_id": "unit.monster.mirror_hunter",
				"level": 1,
			},
		],
		"discard": [{
			"instance_id": "dbg.player.ai.2.blue.2",
			"card_type": "monster.blue_edge_knight",
			"merge_family_id": "unit.monster.blue_edge_knight",
			"level": 1,
		}],
	}
	var held_replacement := runtime.preferred_action(
		[replacement_options[1]],
		actor_id
	)
	_expect(
		held_replacement.is_empty(),
		"an owned active-family pair cannot be broken by an unrelated replacement"
	)
	var active_family_track := TrackProjectionStub.new()
	var active_family_items := [
		{
			"instance_id": "track.blue.active",
			"card_kind": "normal_card",
			"claimable": true,
			"card_definition_id": (
				"monster.blue_edge_knight.energy.rank_1"
			),
			"primary_color": "energy",
			"primary_asset_cost": 2,
		},
		{
			"instance_id": "track.mirror.unrelated",
			"card_kind": "normal_card",
			"claimable": true,
			"card_definition_id": "monster.mirror_hunter.life.rank_1",
			"primary_color": "life",
			"primary_asset_cost": 2,
		},
	]
	active_family_track.projection = {
		"viewer_private_facts": {
			"own_segment_items": active_family_items,
		},
	}
	var acquisition_assets := {}
	for color_id in COLORS:
		acquisition_assets[color_id] = 10
	runtime.configure_acquisition_probe(
		active_family_track,
		{"players": {actor_id: {"assets": acquisition_assets}}},
		actor_id
	)
	var active_family_action := runtime.choose_matching_monster_action(
		actor_id,
		{
			"viewer_player_id": actor_id,
			"own_segment_items": active_family_items,
			"available_unreserved_assets": acquisition_assets,
		}
	)
	_expect(
		str(active_family_action.get("card_definition_id", ""))
			== "monster.blue_edge_knight.energy.rank_1",
		"an active rank-one source rejects an unrelated family during acquisition: %s"
			% JSON.stringify(active_family_action)
	)
	_test_non_upgrade_cohort_uses_refresh_and_replace(runtime)


func _test_non_upgrade_cohort_uses_refresh_and_replace(
	runtime: RuntimeHarness
) -> void:
	var actor_id := "player.local"
	var source_id := "monster.source.local"
	runtime.fixture_monsters = [{
		"source_instance_id": source_id,
		"owner_player_id": actor_id,
		"monster_family_id": "blue_edge_knight",
		"status": "active",
		"rank": 1,
	}]
	runtime.fixture_facts = {
		"hand": [{
			"instance_id": "dbg.player.local.blue.refresh",
			"card_type": "monster.blue_edge_knight",
			"merge_family_id": "unit.monster.blue_edge_knight",
			"level": 1,
		}],
		"discard": [{
			"instance_id": "dbg.player.local.blue.duplicate",
			"card_type": "monster.blue_edge_knight",
			"merge_family_id": "unit.monster.blue_edge_knight",
			"level": 1,
		}],
	}
	var refresh_option := {
		"option_id": "option.local.refresh",
		"actor_id": actor_id,
		"action_domain": "monster",
		"monster_card_mode": "REFRESH_EXISTING",
		"card_instance_id": "dbg.player.local.blue.refresh",
		"card_definition_id": "monster.blue_edge_knight.life.rank_1",
		"target_source_instance_id": source_id,
	}
	var replace_option := {
		"option_id": "option.local.replace",
		"actor_id": actor_id,
		"action_domain": "monster",
		"monster_card_mode": "REPLACE_EXISTING",
		"card_instance_id": "dbg.player.local.mirror.replace",
		"card_definition_id": "monster.mirror_hunter.energy.rank_1",
		"target_source_instance_id": source_id,
	}
	_expect(
		not runtime.prefers_monster_upgrade(actor_id),
		"a stable non-upgrade cohort remains free to use refresh and replace"
	)
	var refresh := runtime.preferred_action([refresh_option], actor_id)
	_expect(
		str(refresh.get("monster_card_mode", "")) == "REFRESH_EXISTING",
		"the non-upgrade cohort uses a legal same-family refresh"
	)
	var replacement := runtime.preferred_action([replace_option], actor_id)
	_expect(
		str(replacement.get("monster_card_mode", "")) == "REPLACE_EXISTING",
		"the non-upgrade cohort does not hold a legal different-family replacement"
	)


func _has_card_option(options: Array, card_instance_id: String) -> bool:
	for option_variant in options:
		if str((option_variant as Dictionary).get(
			"card_instance_id",
			""
		)) == card_instance_id:
			return true
	return false


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
