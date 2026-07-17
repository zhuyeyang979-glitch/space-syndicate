extends Control
class_name FirstTableAuthoredRuntimeCutoverBench

const SERVICE_SCENE_PATH := "res://scenes/runtime/FirstTableAuthoredRuntimeService.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/first_table_authored_runtime_cutover/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/first_table_public_rack_recommendation_v06.png"
const SCENARIO_LOADER_SCRIPT := preload("res://scripts/scenarios/scenario_loader.gd")

const LEGACY_FIXED_KEYS := [
	"facility_market_source_district_index",
	"teaching_card_ids",
	"teaching_card_kind",
	"followup_card_ids",
	"featured_card_ids",
	"starter_monster_ids",
	"preferred_product_ids",
]

@export var auto_run := true

@onready var ruleset_bridge: Node = %RulesetRuntimeBridge
@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _records: Array = []
var _failures: Array[String] = []
var _resolved_catalog: Dictionary = {}


func _ready() -> void:
	_configure_runtime()
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_cutover_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func cutover_cases() -> Array:
	return [
		"service_scene_composition",
		"real_fixture_has_no_fixed_fields",
		"legacy_fixture_fields_ignored",
		"catalog_authors_no_fixed_sequence",
		"native_region_supply_snapshot_required",
		"private_rack_fields_rejected",
		"market_before_factory_allowed",
		"factory_before_market_allowed",
		"public_rank_can_recommend",
		"no_suitable_card_uses_generic_hint",
		"recommendation_does_not_mutate_snapshot",
		"content_uses_current_rack_first_and_second",
		"visible_monster_is_observed_not_selected",
		"phase_copy_promises_no_injection",
		"supply_api_is_read_only",
		"listing_api_is_inert",
		"legacy_score_reads_rack_only",
		"public_project_privacy_sanitized",
		"pacing_success_signals_unchanged",
		"all_outputs_data_only",
	]


func build_cutover_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), false, "preview"))
	return {
		"suite": "first-table-public-rack-recommendation-v06",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_cutover_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	_configure_runtime()
	_resolved_catalog = _resolve_catalog()
	for case_id_variant in cutover_cases():
		var case_id := str(case_id_variant)
		var record := _run_case(case_id)
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "failed"))])
	var manifest := {
		"suite": "first-table-public-rack-recommendation-v06",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": _records.size(),
		"passed_count": _passed_count(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("FIRST_TABLE_PUBLIC_RACK_RECOMMENDATION_BENCH|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_records.size(),
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("FirstTable public-rack bench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	var passed := false
	var notes := ""
	var flags := {}
	var service := _service_node()
	match case_id:
		"service_scene_composition":
			passed = service != null and service.scene_file_path == SERVICE_SCENE_PATH
			flags["service_checked"] = true
			notes = "Coordinator composes the editable first-table recommendation service"
		"real_fixture_has_no_fixed_fields":
			var fixture: Dictionary = coordinator.call("first_table_fixture_snapshot")
			passed = str(fixture.get("focus", "")) == "first_table_authored_content" and _contains_none(fixture, LEGACY_FIXED_KEYS)
			flags["fixture_checked"] = true
			notes = "active first_table fixture carries no fixed card, monster, product, or source-district selectors"
		"legacy_fixture_fields_ignored":
			var definition: Dictionary = SCENARIO_LOADER_SCRIPT.new().load_by_id("first_table")
			var fixture: Dictionary = (definition.get("fixture", {}) as Dictionary).duplicate(true)
			fixture["followup_card_ids"] = ["城市融资1"]
			fixture["starter_monster_ids"] = ["固定怪兽"]
			definition["fixture"] = fixture
			service.call("configure", {"scenario_definition": definition})
			var debug: Dictionary = service.call("debug_snapshot")
			passed = _contains_none(service.call("fixture_snapshot"), LEGACY_FIXED_KEYS) and int(debug.get("legacy_fixed_fixture_field_count", 0)) == 2
			service.call("configure", {"scenario_definition": SCENARIO_LOADER_SCRIPT.new().load_by_id("first_table")})
			flags["fixture_checked"] = true
			notes = "legacy fixed fields are ignored rather than migrated into live recommendation state"
		"catalog_authors_no_fixed_sequence":
			passed = int(_resolved_catalog.get("available_card_count", -1)) == 0 \
				and bool(_resolved_catalog.get("catalog_input_ignored", false)) \
				and (_resolved_catalog.get("catalog_card_ids", []) as Array).is_empty() \
				and (_resolved_catalog.get("runtime_card_ids", []) as Array).is_empty() \
				and str(_resolved_catalog.get("followup_card_id", "")).is_empty() \
				and (_resolved_catalog.get("starter_monster_ids", []) as Array).is_empty()
			flags["catalog_checked"] = true
			notes = "catalog compatibility ignores the global catalog and authors no fixed sequence"
		"native_region_supply_snapshot_required":
			var recommendation: Dictionary = service.call("recommend_rack_item", {
				"available": true,
				"cards": [_card("card.route.one", "路线牌", "route", "", 1)],
			})
			passed = not bool(recommendation.get("available", true)) and str(recommendation.get("reason_code", "")) == "public_rack_regions_invalid"
			flags["ownership_checked"] = true
			notes = "the service consumes the authoritative RegionSupply regions/slots shape instead of a parallel cards array"
		"private_rack_fields_rejected":
			var rack := _rack([_card("card.route.one", "路线牌", "route", "", 1)], 2)
			rack["player_cash"] = 777777
			rack["purchase_window"] = {"private": true}
			var regions: Array = rack.get("regions", [])
			var region: Dictionary = regions[0]
			var slots: Array = region.get("slots", [])
			var listing: Dictionary = slots[0]
			var card: Dictionary = listing.get("card", {})
			card["owner_truth"] = 4
			listing["card"] = card
			slots[0] = listing
			region["slots"] = slots
			regions[0] = region
			rack["regions"] = regions
			var recommendation: Dictionary = service.call("recommend_rack_item", rack)
			passed = not bool(recommendation.get("available", true)) \
				and str(recommendation.get("reason_code", "")) == "public_rack_private_field_rejected" \
				and not JSON.stringify(recommendation).contains("777777") \
				and not JSON.stringify(recommendation).contains("owner_truth")
			flags["privacy_checked"] = true
			notes = "recursive cash, quote, owner and other private fields are rejected and never echoed"
		"market_before_factory_allowed":
			var recommendation: Dictionary = service.call("recommend_rack_item", _rack([
				_card("card.market.green.rank_1", "绿色市场", "facility", "market", 1),
				_card("card.factory.green.rank_1", "绿色工厂", "facility", "factory", 1),
			], 3))
			passed = str(recommendation.get("card_id", "")) == "card.market.green.rank_1"
			flags["order_checked"] = true
			notes = "market may be the current-rack recommendation before a factory"
		"factory_before_market_allowed":
			var recommendation: Dictionary = service.call("recommend_rack_item", _rack([
				_card("card.factory.green.rank_1", "绿色工厂", "facility", "factory", 1),
				_card("card.market.green.rank_1", "绿色市场", "facility", "market", 1),
			], 4))
			passed = str(recommendation.get("card_id", "")) == "card.factory.green.rank_1"
			flags["order_checked"] = true
			notes = "factory may likewise be recommended first; category does not reorder the rack"
		"public_rank_can_recommend":
			var recommendation: Dictionary = service.call("recommend_rack_item", _rack([
				_card("card.route.rank_2", "二级路线牌", "route", "", 2),
				_card("card.weather.rank_1", "一级天气牌", "weather", "", 1),
			], 5))
			passed = str(recommendation.get("card_id", "")) == "card.weather.rank_1"
			flags["recommendation_checked"] = true
			notes = "a lower public rank may improve a recommendation while equal scores retain rack order"
		"no_suitable_card_uses_generic_hint":
			var recommendation: Dictionary = service.call("recommend_rack_item", _rack([], 6))
			passed = not bool(recommendation.get("available", true)) and str(recommendation.get("label", "")) == "浏览当前牌架"
			flags["recommendation_checked"] = true
			notes = "no suitable public listing produces the generic browse-current-rack hint"
		"recommendation_does_not_mutate_snapshot":
			var rack := _sample_rack()
			var before := JSON.stringify(rack)
			service.call("recommend_rack_item", rack)
			passed = JSON.stringify(rack) == before
			flags["ownership_checked"] = true
			notes = "selection leaves the supplied rack snapshot unchanged"
		"content_uses_current_rack_first_and_second":
			var content := _compose({"public_region_supply_rack_snapshot": _sample_rack(), "visible_monster_name": "实际怪兽"})
			passed = str(content.get("teaching_card_id", "")) == "card.market.blue.rank_1" \
				and str(content.get("followup_card_id", "")) == "card.route.rank_1" \
				and str(content.get("rack_public_revision", "")) == "region:region.bench:17" \
				and not bool(content.get("rack_mutation_requested", true))
			flags["content_checked"] = true
			notes = "first and second hints are selected from the same current public rack without mutation"
		"visible_monster_is_observed_not_selected":
			var actual := _compose({"public_region_supply_rack_snapshot": _sample_rack(), "visible_monster_name": "实际怪兽"})
			var absent := _compose({"public_region_supply_rack_snapshot": _rack([], 18)})
			passed = str(actual.get("visible_monster_name", "")) == "实际怪兽" \
				and str(absent.get("visible_monster_name", "")) == "场上怪兽" \
				and (actual.get("starter_monster_ids", []) as Array).is_empty()
			flags["content_checked"] = true
			notes = "service reports actual public monster pressure and never selects a starter slot"
		"phase_copy_promises_no_injection":
			var content := _compose({"public_region_supply_rack_snapshot": _rack([], 19)})
			var phase: Dictionary = coordinator.call("first_table_contextualize_phase", {"id": "buy_followup"}, content)
			var detail := str(phase.get("detail", ""))
			passed = detail.contains("浏览当前牌架") and detail.contains("不会注入") and not detail.contains("保证槽") and not detail.contains("城市融资1")
			flags["context_checked"] = true
			notes = "coach copy explicitly falls back to browsing and promises no injection or reservation"
		"supply_api_is_read_only":
			var plan: Dictionary = coordinator.call("first_table_supply_plan", _sample_rack())
			passed = bool(plan.get("ready", false)) \
				and str(plan.get("operation", "")) == "read_only_recommendation" \
				and str(plan.get("followup_card_id", "")).is_empty() \
				and str(plan.get("inject_after_signal", "")).is_empty() \
				and not bool(plan.get("mutates_rack", true))
			flags["ownership_checked"] = true
			notes = "legacy supply API is now a read-only recommendation envelope"
		"listing_api_is_inert":
			var plan: Dictionary = service.call("market_listing_plan")
			passed = not bool(plan.get("ready", true)) \
				and not plan.has("source_district_index") \
				and not bool(plan.get("mutates_rack", true))
			flags["ownership_checked"] = true
			notes = "fixed source-district listing plan is retired"
		"legacy_score_reads_rack_only":
			var rack_score := int(coordinator.call("first_table_score_district", {"public_region_supply_rack_snapshot": _sample_rack()}, _resolved_catalog))
			var old_fact_score := int(coordinator.call("first_table_score_district", {"product_ids": ["固定商品"], "transport_score": 999.0}, _resolved_catalog))
			passed = rack_score == 1 and old_fact_score == -1000000
			flags["recommendation_checked"] = true
			notes = "compatibility scoring ignores product, transport and category assumptions"
		"public_project_privacy_sanitized":
			var content := _compose({
				"public_region_supply_rack_snapshot": _sample_rack(),
			})
			var encoded := JSON.stringify(content)
			passed = not encoded.contains("hidden_owner") and not encoded.contains("private_target") and not encoded.contains("ai_score")
			flags["privacy_checked"] = true
			notes = "existing public project sanitizer remains intact"
		"pacing_success_signals_unchanged":
			var profile: Dictionary = coordinator.call("first_table_pacing_profile")
			var evaluation: Dictionary = coordinator.call("first_table_evaluate_pacing", {
				"scenario_started_at": 100.0,
				"elapsed_seconds": 1200.0,
				"completed_signal_times": {
					"card_bought": 320.0,
					"economy_checked": 540.0,
					"followup_card_bought": 760.0,
					"public_clue_read": 980.0,
					"monster_pressure_observed": 1120.0,
					"route_chosen": 1300.0,
				},
			})
			passed = (profile.get("milestones", []) as Array).size() == 6 and bool(evaluation.get("pacing_gate_passed", false))
			flags["pacing_checked"] = true
			notes = "map seed, success signals and pacing formulas remain unchanged"
		"all_outputs_data_only":
			var content := _compose({"public_region_supply_rack_snapshot": _sample_rack()})
			var recommendation: Dictionary = service.call("recommend_rack_item", _sample_rack())
			var debug: Dictionary = service.call("debug_snapshot")
			passed = _is_data_only(_resolved_catalog) and _is_data_only(content) and _is_data_only(recommendation) and _is_data_only(debug)
			flags["pure_data_checked"] = true
			notes = "service boundary exposes only recursively pure data"
	var debug: Dictionary = service.call("debug_snapshot") if service != null else {}
	flags["pure_data_checked"] = bool(flags.get("pure_data_checked", true)) and _is_data_only(debug)
	return _record(case_id, passed and bool(flags.get("pure_data_checked", true)), notes, flags)


func _configure_runtime() -> void:
	var ruleset: Dictionary = ruleset_bridge.call("active_profile") if ruleset_bridge != null else {}
	coordinator.call("configure", ruleset)


func _service_node() -> Node:
	return coordinator.get_node_or_null("FirstTableAuthoredRuntimeService") if coordinator != null else null


func _resolve_catalog() -> Dictionary:
	var value: Variant = coordinator.call("first_table_resolve_content_catalog", {
		"card_ids": ["城市融资1", "card.market.blue.rank_1", "card.route.rank_1"],
		"monster_ids": ["固定怪兽"],
		"product_ids": ["固定商品"],
	})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _compose(world: Dictionary) -> Dictionary:
	var value: Variant = coordinator.call("first_table_compose_runtime_content", {
		"district_index": int(world.get("district_index", 2)),
		"district_name": str(world.get("district_name", "曙光港")),
		"public_region_supply_rack_snapshot": world.get("public_region_supply_rack_snapshot", {}),
		"owned_facilities": world.get("owned_facilities", []),
		"city_present": bool(world.get("city_present", false)),
		"gdp_per_minute": int(world.get("gdp_per_minute", 0)),
		"cashflow_paid_total": int(world.get("cashflow_paid_total", 0)),
		"public_clue_count": int(world.get("public_clue_count", 0)),
		"visible_monster_name": str(world.get("visible_monster_name", "")),
	}, _resolved_catalog)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _sample_rack() -> Dictionary:
	return _rack([
		_card("card.market.blue.rank_1", "蓝色市场", "facility", "market", 1),
		_card("card.route.rank_1", "短程商路", "route", "", 1),
	], 17)


func _rack(cards: Array, revision: int) -> Dictionary:
	var slots: Array = []
	for slot_index in range(cards.size()):
		var card: Dictionary = cards[slot_index] if cards[slot_index] is Dictionary else {}
		var card_id := str(card.get("card_id", ""))
		slots.append({
			"item_id": "region-supply:region.bench:%d:%d:%s" % [slot_index, revision, card_id],
			"card_id": card_id,
			"card": card.duplicate(true),
			"source_region_id": "region.bench",
			"source_district_index": 2,
			"slot_index": slot_index,
			"price_cash": 100,
			"supply_revision": "region:region.bench:slot:%d:revision:%d" % [slot_index, revision],
		})
	return {
		"available": true,
		"reason_code": "region_supply_public_snapshot",
		"state_revision": revision,
		"regions": [{
			"region_id": "region.bench",
			"region_index": 2,
			"display_name": "Bench 区域",
			"rack_revision": "region:region.bench:%d" % revision,
			"slots": slots,
		}],
	}


func _card(
	card_id: String,
	display_name: String,
	kind: String,
	_facility_type: String,
	rank: int,
	_tags: Array = [],
	_tutorial_eligible := true,
	_product_id := ""
) -> Dictionary:
	return {
		"card_id": card_id,
		"display_name": display_name,
		"card_type": kind,
		"rank": rank,
		"effect_text": "公开卡面条件",
		"requirement_text": "公开条件",
	}


func _contains_none(value: Dictionary, keys: Array) -> bool:
	for key_variant in keys:
		if value.has(str(key_variant)):
			return false
	return true


func _record(case_id: String, passed: bool, notes: String, overrides: Dictionary = {}) -> Dictionary:
	var debug: Dictionary = _service_node().call("debug_snapshot") if _service_node() != null else {}
	var record := {
		"case_id": case_id,
		"scenario_id": "first_table",
		"fixture_checked": false,
		"catalog_checked": false,
		"recommendation_checked": false,
		"order_checked": false,
		"content_checked": false,
		"context_checked": false,
		"ownership_checked": false,
		"pacing_checked": false,
		"privacy_checked": false,
		"service_checked": false,
		"pure_data_checked": false,
		"service_ready": bool(debug.get("service_ready", false)),
		"mutates_region_supply_rack": bool(debug.get("mutates_region_supply_rack", true)),
		"passed": passed,
		"notes": notes,
	}
	record.merge(overrides, true)
	return record


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "%d/%d public-rack cases passed" % [int(manifest.get("passed_count", 0)), _records.size()]
	status_label.text = "PASS" if _failures.is_empty() else "FAIL"
	status_label.modulate = Color("4ade80") if _failures.is_empty() else Color("fb7185")
	ownership_text.text = "[b]Read-only first-table recommendation[/b]\nFirstTableAuthoredRuntimeService reads the current public RegionSupply rack snapshot and recommends a visible listing without reserving, refreshing, injecting or mutating any slot.\n\n[b]No suitable listing[/b]\nThe service emits the generic “浏览当前牌架” hint. Factory and market categories keep the order supplied by the randomized rack."
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color]  %s\n%s" % [
			"#4ade80" if bool(record.get("passed", false)) else "#fb7185",
			"PASS" if bool(record.get("passed", false)) else "FAIL",
			str(record.get("case_id", "")),
			str(record.get("notes", "")),
		])
	results_text.text = "\n\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# First Table Public Rack Recommendation v0.6",
		"",
		"- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Service: `%s`" % SERVICE_SCENE_PATH,
		"- RegionSupply mutation: none",
		"",
		"| Case | Result | Notes |",
		"| --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s |" % [
			str(record.get("case_id", "")),
			"PASS" if bool(record.get("passed", false)) else "FAIL",
			str(record.get("notes", "")).replace("|", "/"),
		])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	var absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	for file_name in ["manifest.json", "report.md"]:
		var file_path := absolute.path_join(file_name)
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("viewport screenshot is empty")
		return
	var error := image.save_png(SCREENSHOT_PATH)
	if error != OK:
		_failures.append("screenshot save failed: %s" % error_string(error))


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false
