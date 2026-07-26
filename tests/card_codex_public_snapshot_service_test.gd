extends SceneTree

const SOURCE_SCENE := preload("res://scenes/runtime/CardCodexPublicSourceService.tscn")
const SNAPSHOT_SCENE := preload("res://scenes/runtime/CardCodexPublicSnapshotService.tscn")
const SEMANTIC_CATALOG_SCENE := preload("res://scenes/runtime/CardSemanticCatalogService.tscn")
const PUBLIC_LOCALIZATION_SCENE := preload("res://scenes/runtime/CardPlayerFacePublicLocalizationSourceService.tscn")
const PLAYER_FACE_PROJECTION_SCENE := preload("res://scenes/runtime/CardPlayerFaceProjectionService.tscn")
const FORBIDDEN_KEYS := [
	"owner", "owner_index", "hidden_owner", "true_owner", "player_index", "private_target",
	"private_plan", "ai_private_plan", "hand", "rival_hand", "opponent_hand", "exact_cash",
	"private_discard", "city_share", "project_share", "route_damage", "repair_routes", "direct_cash",
	"direct_gdp", "direct_region_damage", "play_cash_cost", "ai_score", "ai_value", "route_plan",
	"future_bag", "rng_state", "save_payload", "machine", "player", "developer", "effect_payload",
	"effect_kind", "target_kind", "skill", "method_name", "script_path",
]
const RETIRED_TEXT := ["城市产权份额", "项目份额", "项目GDP", "签/拒", "路线HP", "商路伤害", "商路修复"]
const RETIRED_INFERENCE_TEXT := ["何时拿", "怎么配", "会暴露", "策略路线", "推荐对象"]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var semantic_catalog := SEMANTIC_CATALOG_SCENE.instantiate()
	var public_localization := PUBLIC_LOCALIZATION_SCENE.instantiate()
	var player_face_projection := PLAYER_FACE_PROJECTION_SCENE.instantiate()
	var snapshot := SNAPSHOT_SCENE.instantiate()
	var source := SOURCE_SCENE.instantiate()
	root.add_child(semantic_catalog)
	root.add_child(public_localization)
	root.add_child(player_face_projection)
	root.add_child(snapshot)
	root.add_child(source)
	var semantic_report := semantic_catalog.call("configure") as Dictionary
	var localization_report := public_localization.call("configure", semantic_catalog) as Dictionary
	snapshot.call("configure", {})
	var compile_before := int(semantic_report.get("compile_count", -1))
	var configured := source.call("configure", {
		"player_face_projection": player_face_projection,
		"public_localization_source": public_localization,
		"semantic_catalog": semantic_catalog,
		"snapshot": snapshot,
	}) as Dictionary
	var semantic_after := semantic_catalog.call("validation_snapshot") as Dictionary
	_expect(bool(semantic_report.get("configured", false)), "semantic catalog configures before Codex projection")
	_expect(bool(localization_report.get("configured", false)), "public localization owner seals all catalog records")
	_expect(bool(configured.get("service_ready", false)), "source service configures through the real four-dependency chain")
	var stable_dependencies := {
		"player_face_projection": player_face_projection,
		"public_localization_source": public_localization,
		"semantic_catalog": semantic_catalog,
		"snapshot": snapshot,
	}
	var idempotent_configure := source.call("configure", stable_dependencies) as Dictionary
	_expect(bool(idempotent_configure.get("service_ready", false)) and str(idempotent_configure.get("last_error", "")) == "", "identical production dependencies bind idempotently")
	var replacement_snapshot := SNAPSHOT_SCENE.instantiate()
	root.add_child(replacement_snapshot)
	replacement_snapshot.call("configure", {})
	var hostile_rebind_dependencies := stable_dependencies.duplicate()
	hostile_rebind_dependencies["snapshot"] = replacement_snapshot
	var hostile_rebind := source.call("configure", hostile_rebind_dependencies) as Dictionary
	_expect(bool(hostile_rebind.get("service_ready", false)) and str(hostile_rebind.get("last_error", "")) == "dependency_rebind_rejected", "source rejects hostile Owner rebinding while preserving its original ready binding")
	source.call("configure", stable_dependencies)
	var debug := source.call("debug_snapshot") as Dictionary
	_expect(int(debug.get("public_catalog_card_count", 0)) == 348, "v0.6 public catalog exposes 348 cards")
	_expect(int(debug.get("public_catalog_family_count", 0)) == 87, "v0.6 public catalog exposes 87 families")
	_expect(int(debug.get("cached_dto_count", 0)) == 348 and int(debug.get("cached_family_ladder_count", 0)) == 87, "production cache owns 348 DTOs and 87 family ladders")
	_expect(int(debug.get("dto_projection_count", 0)) == 348 and int(debug.get("catalog_record_authorization_count", 0)) == 348, "all catalog records pass public semantic authorization and DTO projection")
	_expect(int(debug.get("localization_issue_count", 0)) == 348, "all DTOs use owner-attested public localization")
	_expect(int(debug.get("semantic_compile_delta", -1)) == 0 and int(semantic_after.get("compile_count", -2)) == compile_before, "Codex and localization projection compile delta is zero")
	_expect(not bool(debug.get("reads_legacy_v04_catalog", true)), "legacy v0.4 catalog is absent from public source")
	_expect(_production_debug_flags_pass(debug, snapshot.call("debug_snapshot") as Dictionary, localization_report, player_face_projection.call("debug_snapshot") as Dictionary), "debug flags describe a DTO-only, public, read-only production chain")
	var all_ids := source.call("ordered_card_ids", "all") as Array[String]
	_expect(all_ids.size() == 348, "all 348 public card ids retain catalog order")
	var coverage := _catalog_projection_coverage(source, all_ids)
	_expect(int(coverage.get("valid_cards", 0)) == 348, "348/348 cards expose canonical DTO-backed facts")
	_expect(int(coverage.get("family_count", 0)) == 87 and bool(coverage.get("ladders_valid", false)), "87/87 families expose exact I-IV ladders")
	_expect(bool(coverage.get("identity_exact", false)), "card and rank identity remain stable IDs rather than localized text")
	_expect(bool(coverage.get("costs_separated", false)), "all facts and ladder rows separate acquisition and activation costs")
	_expect(bool(coverage.get("public_only", false)), "full-catalog facts contain no raw or private value channels")
	var commodity_ids := source.call("ordered_card_ids", "commodity") as Array[String]
	var ordinary_id := _first_non_commodity_with_asset_cost(source, all_ids)
	_expect(not commodity_ids.is_empty() and ordinary_id != "", "commodity and ordinary public cards both exist")
	var commodity := source.call("compose_card_facts", commodity_ids[0], 0) as Dictionary
	var ordinary := source.call("compose_card_facts", ordinary_id, 1) as Dictionary
	_expect(str(commodity.get("acquisition_cost_text", "")) == "免费领取" and str(commodity.get("activation_cost_text", "")) == "打出免费", "commodity cards are free to acquire and activate through canonical cost fields")
	_expect(str(ordinary.get("acquisition_cost_text", "")) == "获取：现金 %d" % int(ordinary.get("acquisition_cash", 0)) and str(ordinary.get("activation_cost_text", "")).begins_with("打出："), "ordinary cards separate acquisition cash from activation assets")
	_expect(not commodity.has("cost") and not commodity.has("price") and not commodity.has("play_cost"), "canonical facts expose no ambiguous cost aliases")
	_expect(str(source.call("resolve_card_id", ordinary_id)) == ordinary_id, "stable card_id resolves exactly")
	_expect(str(source.call("resolve_card_id", str(ordinary.get("display_name", "")))) == "" and str(source.call("resolve_card_id", "%s IV" % ordinary_id)) == "" and str(source.call("resolve_card_id", "怪兽·名称4")) == "", "localized names, Roman ranks, and suffix parsers cannot recover identity")
	var browser := source.call("compose_browser", {
		"names": all_ids.slice(0, 8), "columns": 4, "rows": 2, "page_index": 0, "filter_id": "all",
		"selected_card": all_ids[0], "run_pool_count": 8, "district_supply_count": 0,
	}) as Dictionary
	var detail := source.call("compose_detail", ordinary_id, 1, all_ids.size()) as Dictionary
	_expect((browser.get("cards", []) as Array).size() == 8 and not (detail.get("detail", {}) as Dictionary).is_empty(), "real browser and detail snapshots compose")
	_expect(_structured_detail_matches_facts(detail, ordinary), "detail renders explicit timing, target, condition, ordered effect, duration, counterability, and information sections")
	_expect(_browser_matches_facts(browser, commodity), "browser and hover preserve canonical DTO-backed identity and cost separation")
	_expect(_is_pure_data(browser) and _is_pure_data(detail), "card public snapshots contain pure data only")
	_expect(not _contains_forbidden_key(browser) and not _contains_forbidden_key(detail), "card public snapshots exclude private and retired fields")
	_expect(not _contains_retired_text(browser) and not _contains_retired_text(detail), "card public UI excludes retired v0.4 wording")
	_expect(not _contains_retired_inference_text(browser) and not _contains_retired_inference_text(detail), "Card Codex no longer presents inferred strategy, recommendation, or exposure advice")
	var rejected := source.call("compose_browser", {"filter_id": "all", "hidden_owner": "DO_NOT_LEAK"}) as Dictionary
	_expect(rejected.is_empty(), "private browser request fails closed before rendering")
	semantic_catalog.queue_free()
	public_localization.queue_free()
	player_face_projection.queue_free()
	source.queue_free()
	snapshot.queue_free()
	await process_frame
	_finish()


func _first_non_commodity_with_asset_cost(source: Node, ids: Array[String]) -> String:
	for card_id: String in ids:
		var facts := source.call("compose_card_facts", card_id, -1) as Dictionary
		if bool(facts.get("valid", false)) and str(facts.get("category_id", "")) != "commodity" and int(facts.get("acquisition_cash", 0)) > 0 and str(facts.get("activation_cost_text", "")) != "打出免费":
			return card_id
	return ""


func _catalog_projection_coverage(source: Node, ids: Array[String]) -> Dictionary:
	var valid_cards := 0
	var families: Dictionary = {}
	var ladders_valid := true
	var identity_exact := true
	var costs_separated := true
	var public_only := true
	for index in range(ids.size()):
		var card_id := ids[index]
		var facts := source.call("compose_card_facts", card_id, index) as Dictionary
		if not bool(facts.get("valid", false)):
			continue
		valid_cards += 1
		var family_id := str(facts.get("family_id", ""))
		families[family_id] = true
		identity_exact = identity_exact and str(facts.get("card_name", "")) == card_id \
			and int(facts.get("rank", 0)) >= 1 and int(facts.get("rank", 0)) <= 4
		costs_separated = costs_separated \
			and str(facts.get("acquisition_cost_text", "")).strip_edges() != "" \
			and str(facts.get("activation_cost_text", "")).strip_edges() != "" \
			and not facts.has("cost") and not facts.has("price") and not facts.has("play_cost")
		public_only = public_only and not _contains_forbidden_key(facts)
		var ladder := facts.get("family_ladder", []) as Array
		if ladder.size() != 4:
			ladders_valid = false
			continue
		for rank_index in range(4):
			var row := ladder[rank_index] as Dictionary
			ladders_valid = ladders_valid \
				and str(row.get("family_id", "")) == family_id \
				and int(row.get("rank", 0)) == rank_index + 1 \
				and str(row.get("acquisition_cost_text", "")).strip_edges() != "" \
				and str(row.get("activation_cost_text", "")).strip_edges() != ""
	return {
		"valid_cards": valid_cards,
		"family_count": families.size(),
		"ladders_valid": ladders_valid,
		"identity_exact": identity_exact,
		"costs_separated": costs_separated,
		"public_only": public_only,
	}


func _structured_detail_matches_facts(detail: Dictionary, facts: Dictionary) -> bool:
	var payload := detail.get("detail", {}) as Dictionary
	var tactical := payload.get("tactical", {}) as Dictionary
	var entries := tactical.get("entries", []) as Array
	var fact_cards := payload.get("facts", []) as Array
	var resolution := payload.get("resolution", {}) as Dictionary
	var summary := payload.get("summary", {}) as Dictionary
	if entries.size() != 3 or fact_cards.size() != 4:
		return false
	var timing_entry := entries[0] as Dictionary
	var target_entry := entries[1] as Dictionary
	var condition_entry := entries[2] as Dictionary
	var ordered_effect_entry := fact_cards[1] as Dictionary
	var duration_entry := fact_cards[2] as Dictionary
	return str(tactical.get("title", "")).contains("时机、目标与条件") \
		and str(timing_entry.get("title", "")) == "出牌时机" \
		and str(timing_entry.get("body", "")) == str(facts.get("timing_text", "")) \
		and str(target_entry.get("title", "")) == "目标" \
		and str(target_entry.get("body", "")) == str(facts.get("target_text", "")) \
		and str(condition_entry.get("title", "")) == "条件" \
		and str(ordered_effect_entry.get("title", "")).contains("按序效果") \
		and str(ordered_effect_entry.get("body", "")).begins_with("1. ") \
		and str(duration_entry.get("body", "")).contains(str(facts.get("duration_text", ""))) \
		and str(resolution.get("body", "")) == str(facts.get("counterability_text", "")) \
		and str(resolution.get("meta", "")) == str(facts.get("information_scope_text", "")) \
		and str(summary.get("read_order", "")).contains("获取费用 → 打出费用 → 时机 → 目标 → 条件 → 效果步骤")


func _browser_matches_facts(browser: Dictionary, facts: Dictionary) -> bool:
	var cards := browser.get("cards", []) as Array
	if cards.is_empty():
		return false
	var first := cards[0] as Dictionary
	var preview := browser.get("preview", {}) as Dictionary
	return str(first.get("card_name", "")) == str(facts.get("card_name", "")) \
		and int(first.get("rank_number", 0)) == int(facts.get("rank", 0)) \
		and str(preview.get("body", "")).contains(str(facts.get("acquisition_cost_text", ""))) \
		and str(preview.get("body", "")).contains(str(facts.get("activation_cost_text", "")))


func _production_debug_flags_pass(
	source_debug: Dictionary,
	snapshot_debug: Dictionary,
	localization_debug: Dictionary,
	projection_debug: Dictionary
) -> bool:
	var adapter := source_debug.get("adapter", {}) as Dictionary
	return int(source_debug.get("dependency_count", 0)) == 4 \
		and bool(source_debug.get("service_authoritative", false)) \
		and bool(source_debug.get("uses_catalog_owned_semantic", false)) \
		and bool(source_debug.get("uses_owner_attested_localization", false)) \
		and bool(source_debug.get("uses_player_card_codex_dto_v1", false)) \
		and not bool(source_debug.get("reads_private_world", true)) \
		and not bool(source_debug.get("owns_rules", true)) \
		and not bool(source_debug.get("owns_save_state", true)) \
		and bool(adapter.get("dto_only_semantic_input", false)) \
		and not bool(adapter.get("reads_raw_card_record", true)) \
		and not bool(adapter.get("infers_rules_from_text", true)) \
		and bool(snapshot_debug.get("uses_existing_browser_viewmodel", false)) \
		and bool(snapshot_debug.get("uses_existing_detail_viewmodel", false)) \
		and not bool(snapshot_debug.get("infers_tactical_advice", true)) \
		and int(localization_debug.get("sealed_bundle_count", 0)) == 348 \
		and not bool(localization_debug.get("supports_arbitrary_card_id_lookup", true)) \
		and not bool(localization_debug.get("supports_catalog_enumeration", true)) \
		and not bool(localization_debug.get("retains_full_card_records", true)) \
		and not bool(localization_debug.get("owns_save_state", true)) \
		and not bool(localization_debug.get("uses_rng", true)) \
		and bool(projection_debug.get("stateless", false)) \
		and not bool(projection_debug.get("owns_rules", true)) \
		and not bool(projection_debug.get("uses_rng", true))


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if FORBIDDEN_KEYS.has(str(key_variant).to_lower()) or _contains_forbidden_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _contains_retired_text(value: Variant) -> bool:
	if value is String or value is StringName:
		for token: String in RETIRED_TEXT:
			if str(value).contains(token):
				return true
	elif value is Dictionary:
		for key_variant: Variant in value:
			if _contains_retired_text(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_retired_text(item_variant):
				return true
	return false


func _contains_retired_inference_text(value: Variant) -> bool:
	if value is String or value is StringName:
		for token: String in RETIRED_INFERENCE_TEXT:
			if str(value).contains(token):
				return true
	elif value is Dictionary:
		for key_variant: Variant in value:
			if _contains_retired_inference_text(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_retired_inference_text(item_variant):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CARD CODEX PUBLIC SNAPSHOT SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("CARD CODEX PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	print("CARD CODEX PUBLIC SNAPSHOT SERVICE FAIL: %d | %s" % [failures.size(), JSON.stringify(failures)])
	quit(1)
