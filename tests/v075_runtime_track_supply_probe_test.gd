extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const Registry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)

const MATCH_SEED := 901626424
const MAP_SEED := 900626424
const PLAYERS := [
	"player.local",
	"player.ai.1",
	"player.ai.2",
	"player.ai.3",
]

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var runtime := RuntimeOwner.new()
	var combat := CombatOwner.new()
	host.add_child(runtime)
	host.add_child(combat)
	var bound := runtime.bind_combat_owner(combat)
	if not bool(bound.get("accepted", false)):
		push_error("runtime combat binding failed")
		quit(1)
		return
	var started := runtime.start_new_game(
		4,
		MATCH_SEED,
		true,
		true,
		{
			"map_seed": MAP_SEED,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	)
	if not bool(started.get("accepted", false)):
		push_error("runtime start failed: %s" % JSON.stringify(started))
		quit(1)
		return
	var rows: Array = []
	for player_id in PLAYERS:
		var snapshot := runtime.player_snapshot(player_id)
		var canonical := snapshot.get("canonical_player_projection", {}) as Dictionary
		var track := canonical.get("unified_track", {}) as Dictionary
		var private_facts := track.get("viewer_private_facts", {}) as Dictionary
		var items: Array = []
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			var item := item_variant as Dictionary
			var definition := Registry.definition(str(item.get("card_definition_id", "")))
			items.append({
				"slot": int(item.get("local_slot_index", -1)),
				"instance": str(item.get("instance_id", "")),
				"domain": Registry.card_domain(str(definition.get("card_type", ""))),
				"definition": str(item.get("card_definition_id", "")),
				"claimable": bool(item.get("claimable", false)),
				"color": str(item.get("primary_color", "")),
			})
		var legal := runtime.legal_card_actions(player_id)
		var legal_domains: Dictionary = {}
		for action_variant in legal:
			var action := action_variant as Dictionary
			var domain := str(action.get("action_domain", "facility"))
			legal_domains[domain] = int(legal_domains.get(domain, 0)) + 1
		var dbg := canonical.get("personal_dbg", {}) as Dictionary
		rows.append({
			"player_id": player_id,
			"track": items,
			"legal_domains": legal_domains,
			"dbg_facts": dbg.get("facts", {}),
		})
	var acquisition_probe: Array = []
	for player_id in ["player.ai.1", "player.ai.2", "player.ai.3"]:
		var acquisition: Dictionary = runtime.call(
			"_auto_acquire_track_item",
			player_id
		) as Dictionary
		var projection: Dictionary = runtime.player_snapshot(player_id)
		var facts := (
			((projection.get("canonical_player_projection", {}) as Dictionary)
			.get("personal_dbg", {}) as Dictionary).get("facts", {}) as Dictionary
		)
		acquisition_probe.append({
			"player_id": player_id,
			"receipt": acquisition,
			"track_policy": runtime.v075_track_acquisition_policy_snapshot(),
			"dbg_hand_count": int(facts.get("hand_count", 0)),
			"dbg_draw_pile_count": int(facts.get("draw_pile_count", 0)),
			"dbg_discard_count": int(facts.get("discard_count", 0)),
		})
	print("V075_RUNTIME_TRACK_SUPPLY_PROBE|%s" % JSON.stringify({
		"started": started,
		"rows": rows,
		"acquisition_probe": acquisition_probe,
		"debug": runtime.debug_snapshot(),
	}))
	quit(0)
