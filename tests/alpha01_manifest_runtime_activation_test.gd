extends SceneTree

const Loader := preload("res://scripts/runtime/alpha01_content_manifest_loader.gd")
const Selection := preload("res://scripts/runtime/alpha01_runtime_content_selection.gd")
const InventoryScript := preload("res://scripts/runtime/commodity_card_inventory_runtime_controller.gd")
const CoordinatorScene := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const EXPECTED_ROLE_INDICES := [0, 1, 2, 3, 9, 16, 21, 22]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var selection := Loader.load_active_selection()
	_expect(selection.is_valid(), "runtime selection loads from the curated resource")
	var loader_source := FileAccess.get_file_as_string("res://scripts/runtime/alpha01_content_manifest_loader.gd")
	_expect(not loader_source.contains("res://docs/") and loader_source.contains("res://resources/content/alpha01/alpha01_content_manifest.tres"), "runtime loader uses the export-safe Resource and never reads docs")
	var export_source := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(export_source.contains("docs/*") and not export_source.contains("resources/content/alpha01/*"), "Windows export excludes docs but preserves the runtime Resource path")
	var audit_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/playtest/alpha_0_1/content_manifest.json"))
	var authority: Resource = load("res://resources/content/alpha01/alpha01_content_manifest.tres")
	var authority_snapshot: Dictionary = authority.call("runtime_selection_snapshot") if authority != null else {}
	var audit_selection := Selection.from_dictionary(audit_variant as Dictionary) if audit_variant is Dictionary else Selection.new()
	var authority_selection := Selection.from_dictionary(authority_snapshot)
	_expect(
		audit_selection.is_valid()
			and audit_selection.public_activation_snapshot() == authority_selection.public_activation_snapshot()
			and audit_selection.recommended_configuration == authority_selection.recommended_configuration,
		"docs JSON is parity-locked derived audit evidence, not a second runtime owner"
	)
	_expect(selection.role_source_indices() == EXPECTED_ROLE_INDICES, "eight roles retain authoritative source indices")
	_expect(selection.region_supply_card_ids.size() == 28 and selection.commodity_track_card_ids.size() == 12, "acquisition splits into 28 regional and 12 commodity identities")
	_expect(selection.acquisition_card_ids().size() == 40 and _all_rank_one(selection.acquisition_card_ids()), "runtime activation consumes 40 rank-I identities, never 160 rank records")
	_expect(selection.monster_source_indices() == [0, 1, 2, 3, 4, 5, 6, 7], "all eight recommended monsters retain source identity")
	_expect(str(selection.active_map.get("map_id", "")) == "depth_1_procedural_planet" and selection.active_challenge_depth() == 1, "one active Alpha map is selected")

	var coordinator := CoordinatorScene.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	_expect(coordinator.region_supply_catalog_card_ids() == selection.region_supply_card_ids, "production coordinator exposes exactly the 28 manifest regional identities")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(coordinator_source.contains("AlphaContentLoader.load_active_selection") and not coordinator_source.contains("ranked_card_ids"), "production regional selection reads the acquisition manifest without rank expansion")

	var inventory := InventoryScript.new() as CommodityCardInventoryRuntimeController
	var same_a := inventory.selected_belt_card_order(900626424, selection.commodity_track_card_ids)
	var same_b := inventory.selected_belt_card_order(900626424, selection.commodity_track_card_ids)
	var different := inventory.selected_belt_card_order(900626425, selection.commodity_track_card_ids)
	_expect(bool(same_a.get("valid", false)) and same_a.get("card_ids", []) == same_b.get("card_ids", []), "same seed produces the same commodity-track sequence")
	_expect(same_a.get("card_ids", []) != different.get("card_ids", []), "different seed can vary the commodity-track sequence")
	_expect((same_a.get("card_ids", []) as Array).size() == 12 and _same_set(same_a.get("card_ids", []), selection.commodity_track_card_ids), "seed ordering preserves all and only the 12 selected commodity identities")

	var public_text := JSON.stringify(selection.public_activation_snapshot()).to_lower()
	var privacy_hits: Array[String] = []
	for forbidden in ["cash", "hand", "owner", "private", "ai_", "route_plan", "pressure_bucket", "future_bag"]:
		if public_text.contains(forbidden):
			privacy_hits.append(forbidden)
	_expect(privacy_hits.is_empty(), "public activation snapshot privacy violations remain zero")
	var supply := coordinator.region_supply_runtime_controller()
	_expect(supply != null and not bool(supply.debug_snapshot().get("public_snapshot_exposes_future_bag", true)), "regional public boundary never exposes the future shuffle bag")

	var manifest: Resource = authority
	var report: Dictionary = manifest.call("validation_report") if manifest != null else {}
	var card_audit: Dictionary = report.get("card_audit", {}) if report.get("card_audit", {}) is Dictionary else {}
	_expect(bool(report.get("valid", false)) and int(card_audit.get("active_owner_ranked_card_count", 0)) == 160 and (card_audit.get("retired_hits", []) as Array).is_empty(), "selected definitions have zero pending owners and zero retired identifiers")
	for path in [
		"res://scripts/runtime/alpha01_content_manifest_loader.gd",
		"res://scripts/runtime/alpha01_runtime_content_selection.gd",
		"res://scripts/runtime/session_start_plan_builder.gd",
		"res://scripts/runtime/new_game_setup_draft_service.gd",
	]:
		var source := FileAccess.get_file_as_string(path).to_lower()
		_expect(not source.contains("/main.gd") and not source.contains("/root/main"), "%s adds no Main caller" % path)

	coordinator.free()
	inventory = null
	selection = null
	manifest = null
	authority = null
	audit_selection = null
	authority_selection = null
	report.clear()
	card_audit.clear()
	await process_frame
	await process_frame
	_finish()


func _all_rank_one(ids: Array[String]) -> bool:
	for card_id in ids:
		if not card_id.ends_with(".rank_1"):
			return false
	return true


func _same_set(left: Variant, right: Variant) -> bool:
	var left_values: Array = (left as Array).duplicate() if left is Array else []
	var right_values: Array = (right as Array).duplicate() if right is Array else []
	left_values.sort()
	right_values.sort()
	return left_values == right_values


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("ALPHA01_MANIFEST_RUNTIME_ACTIVATION_TEST|status=%s|checks=%d|failures=%d|details=%s" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
