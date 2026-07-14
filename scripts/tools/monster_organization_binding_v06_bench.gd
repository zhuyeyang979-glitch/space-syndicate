extends Node

class BenchProvider:
	extends RefCounted

	func current_monster_binding_window_snapshot_v06() -> Dictionary:
		return {"available": true, "authoritative": true, "window_sequence": 12, "revision": 4}

	func monster_binding_caps(actor_id: String, window_sequence: int) -> Dictionary:
		return {
			"available": true,
			"authoritative": true,
			"actor_id": actor_id,
			"window_sequence": window_sequence,
			"owner_revision": 6,
			"capability_kind": "monster_caps",
			"controlled_monster_count_limit": 2,
			"primary_monster_rank_limit": 4,
			"secondary_monster_rank_limit": 2,
		}

	func monster_binding_caps_for_target_owner(actor_id: String, window_sequence: int) -> Dictionary:
		return monster_binding_caps(actor_id, window_sequence)

	func validate_monster_binding_caps_v06(snapshot: Dictionary, _for_target_owner: bool) -> Dictionary:
		return {
			"valid": str(snapshot.get("capability_kind", "")) == "monster_caps" and int(snapshot.get("owner_revision", -1)) == 6,
		}


var _provider := BenchProvider.new()


func _ready() -> void:
	var monster_owner := get_node("MonsterRuntimeController") as MonsterRuntimeController
	var configured: Dictionary = monster_owner.configure_monster_binding_capability_provider_v06(_provider)
	var public_snapshot: Dictionary = monster_owner.unit_card_snapshot_v06("monster")
	var private_snapshot: Dictionary = monster_owner.monster_private_snapshot_v06("bench.actor")
	var passed := (
		bool(configured.get("configured", false))
		and bool(public_snapshot.get("available", false))
		and bool(private_snapshot.get("available", false))
		and not JSON.stringify(public_snapshot).contains("capability_fingerprint")
	)
	print("MONSTER_ORGANIZATION_BINDING_V06_BENCH|status=%s|scene_tree=%s|production_class=%s|configure_api=%s|public_privacy=%s" % [
		"PASS" if passed else "FAIL",
		str(monster_owner.get_path()),
		monster_owner.get_class(),
		str(bool(configured.get("configured", false))),
		str(not JSON.stringify(public_snapshot).contains("capability_fingerprint")),
	])
	if not passed:
		push_error("MONSTER_ORGANIZATION_BINDING_V06_BENCH failed")
