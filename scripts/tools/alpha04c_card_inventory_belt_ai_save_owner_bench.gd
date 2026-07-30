extends Node
class_name Alpha04CCardInventoryBeltAiSaveOwnerBench

const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")

@export var auto_run_on_ready := true

var last_result: Dictionary = {}


func _ready() -> void:
	if auto_run_on_ready:
		await get_tree().process_frame
		last_result = run_bench()
		print("ALPHA04C_SAVE_OWNER_BENCH|status=%s|checks=%d|failures=%d" % [
			"PASS" if bool(last_result.get("passed", false)) else "FAIL",
			int(last_result.get("checks", 0)),
			(last_result.get("failures", []) as Array).size(),
		])


func run_bench() -> Dictionary:
	var failures: Array[String] = []
	var checks := 0
	var coordinator := get_node_or_null("GameRuntimeCoordinator") as GameRuntimeCoordinator
	checks += 1
	if coordinator == null:
		failures.append("coordinator_missing")
		return {"passed": false, "checks": checks, "failures": failures}
	coordinator.configure(RULESET_V04.debug_snapshot())
	var card_owner := coordinator.get_node_or_null("CardInventorySaveOwner") as CardInventorySaveOwner
	var belt_owner := coordinator.get_node_or_null("CommodityBeltVisibilitySaveOwner") as CommodityBeltVisibilitySaveOwner
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	checks += 1
	if card_owner == null or belt_owner == null or ai == null:
		failures.append("save_owner_scene_missing")
		return {"passed": false, "checks": checks, "failures": failures}
	var card_state := card_owner.to_save_data()
	checks += 1
	if int(card_state.get("schema_version", 0)) != 3:
		failures.append("card_inventory_v3_capture_failed")
	var belt_state := belt_owner.to_save_data()
	checks += 1
	if int(belt_state.get("schema_version", 0)) != 1 or belt_state.has("visible_actor_ids"):
		failures.append("belt_visibility_v1_attestation_failed")
	ai.configure({"ruleset_id": "v0.6"})
	var ai_state := ai.to_save_data()
	checks += 1
	if int(ai_state.get("schema_version", 0)) != 2 or not (ai_state.get("player_states") is Array):
		failures.append("ai_v2_capture_failed")
	checks += 1
	if not bool(belt_owner.apply_save_data(belt_state).get("applied", false)):
		failures.append("belt_immutable_apply_failed")
	return {"passed": failures.is_empty(), "checks": checks, "failures": failures}
