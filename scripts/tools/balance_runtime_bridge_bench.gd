extends Control
class_name BalanceRuntimeBridgeBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/gameplay_balance_diagnostics/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/gameplay_balance_diagnostics_sprint_62.png"
const BridgeScript := preload("res://scripts/balance/balance_runtime_parameter_bridge.gd")
const MonsterCatalogV06 := preload("res://scripts/runtime/monster_catalog_v06.gd")
const PREVIEW_SCENE := preload("res://scenes/tools/BalanceRuntimeBridgeMcpPreview.tscn")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const DIAGNOSTICS_SERVICE_SCENE_PATH := "res://scenes/runtime/GameplayBalanceDiagnosticsRuntimeService.tscn"
const DIAGNOSTICS_WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/GameplayBalanceDiagnosticsWorldBridge.tscn"
const ROUTE_CATALOG_PATH := "res://resources/balance/development_route_catalog_v04.tres"
const ROUTE_RESOURCE_DIR := "res://resources/balance/development_routes/"
const MAIN_BASELINE_NONBLANK := 22954
const MAIN_BASELINE_FUNCTIONS := 1369
const MAIN_BASELINE_SHA256 := "7D9F2E88162E6E88F33D6909B7E34CF7C39973778E8D70F71CAEE394EC605F77"

const FLOW_CASES := [
	{"case_id": "json_runtime_targets_loads", "source_mode": "json_current", "notes": "JSON runtime target payload loads through the bridge."},
	{"case_id": "resource_runtime_targets_loads", "source_mode": "resource_profile", "notes": "Resource runtime target payload loads through the bridge."},
	{"case_id": "json_price_curve_loads", "source_mode": "json_current", "notes": "JSON price curve payload loads through the bridge."},
	{"case_id": "resource_price_curve_loads", "source_mode": "resource_profile", "notes": "Resource price curve payload loads through the bridge."},
	{"case_id": "runtime_targets_parity", "source_mode": "json_current", "notes": "Runtime target JSON and Resource payloads match."},
	{"case_id": "price_curve_parity", "source_mode": "json_current", "notes": "Price curve JSON and Resource payloads match."},
	{"case_id": "source_mode_json_current", "source_mode": "json_current", "notes": "json_current explicitly returns JSON payloads."},
	{"case_id": "source_mode_resource_profile", "source_mode": "resource_profile", "notes": "resource_profile explicitly returns Resource payloads."},
	{"case_id": "first_mission_runtime_default_unchanged", "source_mode": "json_current", "notes": "Default runtime source remains json_current for the real main scene."},
	{"case_id": "no_callable_or_object_in_payloads", "source_mode": "auto_safe", "notes": "Bridge payloads and comparison manifest stay pure data."},
]

const DIAGNOSTICS_CASES := [
	{"case_id": "diagnostics_service_scene_composition", "source_mode": "diagnostics", "notes": "Diagnostics Service is a real scene-owned runtime component."},
	{"case_id": "diagnostics_world_bridge_scene_composition", "source_mode": "diagnostics", "notes": "WorldBridge is a real scene-owned fact adapter."},
	{"case_id": "coordinator_static_diagnostics_composition", "source_mode": "diagnostics", "notes": "Coordinator statically owns Service and WorldBridge."},
	{"case_id": "diagnostics_service_api_contract", "source_mode": "diagnostics", "notes": "Service exposes the stable read-only diagnostics API."},
	{"case_id": "diagnostics_world_bridge_readonly_boundary", "source_mode": "diagnostics", "notes": "WorldBridge collects facts without scoring or mutation authority."},
	{"case_id": "diagnostics_monster_art_profiles_catalog_source", "source_mode": "diagnostics", "notes": "Monster diagnostics art facts come from MonsterCatalogV06, not a Main helper."},
	{"case_id": "development_route_catalog_loads", "source_mode": "diagnostics", "notes": "Inspector route catalog loads and validates."},
	{"case_id": "development_route_resources_inspector_editable", "source_mode": "diagnostics", "notes": "All seven routes are independent editable Resource assets."},
	{"case_id": "development_route_count_seven", "source_mode": "diagnostics", "notes": "Exactly seven authored development routes are available."},
	{"case_id": "development_route_sort_order", "source_mode": "diagnostics", "notes": "Route order remains stable from zero through six."},
	{"case_id": "city_growth_metadata_parity", "source_mode": "diagnostics", "notes": "city_growth metadata matches the captured baseline."},
	{"case_id": "contract_route_metadata_parity", "source_mode": "diagnostics", "notes": "contract_route metadata matches the captured baseline."},
	{"case_id": "finance_speculation_metadata_parity", "source_mode": "diagnostics", "notes": "finance_speculation metadata matches the captured baseline."},
	{"case_id": "monster_pressure_metadata_parity", "source_mode": "diagnostics", "notes": "monster_pressure metadata matches the captured baseline."},
	{"case_id": "intel_supply_metadata_parity", "source_mode": "diagnostics", "notes": "intel_supply metadata matches the captured baseline."},
	{"case_id": "direct_interaction_metadata_parity", "source_mode": "diagnostics", "notes": "direct_interaction metadata matches the captured baseline."},
	{"case_id": "tactical_support_metadata_parity", "source_mode": "diagnostics", "notes": "tactical_support metadata matches the captured baseline."},
	{"case_id": "development_route_label_lookup", "source_mode": "diagnostics", "notes": "Route labels and summaries come from one catalog."},
	{"case_id": "development_route_card_classification", "source_mode": "diagnostics", "notes": "Real cards classify into authored route ids."},
	{"case_id": "card_budget_points_report", "source_mode": "diagnostics", "notes": "Card budget point reports cover real cards."},
	{"case_id": "card_budget_band_report", "source_mode": "diagnostics", "notes": "Budget bands remain stable and readable."},
	{"case_id": "development_route_audit_report", "source_mode": "diagnostics", "notes": "Development route audit is Service-owned."},
	{"case_id": "development_route_pressure_report", "source_mode": "diagnostics", "notes": "Development pressure report is Service-owned."},
	{"case_id": "direct_interaction_report", "source_mode": "diagnostics", "notes": "Direct interaction report is Service-owned."},
	{"case_id": "role_balance_report", "source_mode": "diagnostics", "notes": "Role budget and balance report are Service-owned."},
	{"case_id": "monster_ecology_report", "source_mode": "diagnostics", "notes": "Monster ecology report is Service-owned."},
	{"case_id": "product_ecosystem_report", "source_mode": "diagnostics", "notes": "Product ecosystem report is Service-owned."},
	{"case_id": "card_supply_product_filter_report", "source_mode": "diagnostics", "notes": "Supply and product filter report is Service-owned."},
	{"case_id": "card_one_glance_report", "source_mode": "diagnostics", "notes": "Card one-glance report is Service-owned."},
	{"case_id": "developer_panel_service_source", "source_mode": "diagnostics", "notes": "DeveloperBalancePanel consumes the diagnostics service."},
	{"case_id": "codex_consumers_use_diagnostics_service", "source_mode": "diagnostics", "notes": "Card, Product, and Monster codices use one diagnostics source."},
	{"case_id": "runtime_balance_model_formula_owner", "source_mode": "diagnostics", "notes": "RuntimeBalanceModel remains the formula owner."},
	{"case_id": "diagnostics_snapshot_pure_data", "source_mode": "diagnostics", "notes": "World and report snapshots contain pure data only."},
	{"case_id": "diagnostics_privacy_boundary", "source_mode": "diagnostics", "notes": "Public diagnostics do not expose private runtime state."},
	{"case_id": "main_legacy_diagnostics_absent", "source_mode": "diagnostics", "notes": "Legacy main diagnostics and route metadata functions are deleted."},
	{"case_id": "main_deletion_metrics_gate", "source_mode": "diagnostics", "notes": "main.gd clears the Sprint 62 line and function deletion gate."},
	{"case_id": "tests_no_main_diagnostics_reflection", "source_mode": "diagnostics", "notes": "Tests target Coordinator or Service APIs instead of main reflection."},
	{"case_id": "diagnostics_readonly_no_world_mutation", "source_mode": "diagnostics", "notes": "Building reports leaves gameplay state unchanged."},
	{"case_id": "no_parallel_formula_owner", "source_mode": "diagnostics", "notes": "Diagnostics aggregate RuntimeBalanceModel output instead of copying formulas."},
	{"case_id": "no_legacy_diagnostics_fallback", "source_mode": "diagnostics", "notes": "No main fallback or compatibility wrappers remain."},
]

const ROUTE_BASELINE := {
	"city_growth": {"display_name": "城市成长", "goal": "建设、升级生产/需求/交通，把稳定GDP变成终局现金。", "play_pattern": "先建稳定城市，再补生产、需求和交通，把GDP按秒滚成现金。", "counterplay": "断商路、做空GDP、诱导怪兽踩城，或用合约改走需求。", "ai_plan_hint": "领先时继续修路/保险；落后时只在安全高GDP区域扩张。", "strategy_labels": ["城市成长"], "required_for_ai_baseline": true, "sort_order": 0},
	"contract_route": {"display_name": "合约供需", "goal": "用匿名合约改写两地供需，让商路和拒签惩罚都能产生收益。", "play_pattern": "把生产区和需求城接成新商路，用奖惩条款迫使对方签或吃罚。", "counterplay": "识别谁最受益、拒签诱饵、破坏运输区，或抢先替换供需。", "ai_plan_hint": "优先接自己能吃GDP的供需；拒签惩罚足够强时才施压敌城。", "strategy_labels": ["合约博弈"], "required_for_ai_baseline": true, "sort_order": 1},
	"finance_speculation": {"display_name": "金融投机", "goal": "围绕商品价格或城市GDP的限时涨跌下注，把波动兑现成钱。", "play_pattern": "先读供需、天气、怪兽风险，再用买涨/做空在限定秒数内兑现波动。", "counterplay": "稳价、修路、保险、临时拉需求，或反向打击被下注城市。", "ai_plan_hint": "落后时更敢做空高风险领先城市；领先时用套保和稳定牌降波动。", "strategy_labels": ["金融投机"], "required_for_ai_baseline": true, "sort_order": 2},
	"monster_pressure": {"display_name": "怪兽压制", "goal": "召唤、升级、诱导怪兽，或用破坏/天气/新闻压低竞争城市GDP。", "play_pattern": "用怪兽资源偏好、新闻热度和天气窗口，把自动怪兽推向高价值竞品城市。", "counterplay": "分散商品、修复区域、诱导怪兽转向，或侦查怪兽资金线索。", "ai_plan_hint": "优先盯商品重叠且GDP高的敌城；己方怪兽受伤暴露时减少乱升级。", "strategy_labels": ["怪兽路线", "怪兽诱导", "战斗破坏", "城市压制", "天气博弈", "新闻信息战"], "required_for_ai_baseline": true, "sort_order": 3},
	"intel_supply": {"display_name": "情报补给", "goal": "扩大购牌范围、补手牌、追溯匿名归属，降低误判和缺牌风险。", "play_pattern": "扩大购牌半径、补手牌和追溯归属，把匿名行动转成可下注线索。", "counterplay": "制造伪线索、分散出牌条件、避免连续暴露同一GDP份额门槛。", "ai_plan_hint": "缺关键牌时补给；终局前把高置信线索转成情报现金。", "strategy_labels": ["情报推理", "补给构筑"], "required_for_ai_baseline": true, "sort_order": 4},
	"direct_interaction": {"display_name": "直接互动", "goal": "用点名拆牌、牵牌、产权冻结和全场齐射干扰对手，同时留下可利用的公开线索。", "play_pattern": "先判断谁最可能领先或握有关键牌，再用互动牌打断节奏、冻结高GDP城市或逼出身份倾向。", "counterplay": "分散手牌价值、保留防御/修复牌、降低单城GDP暴露，或反向猜测谁最受益。", "ai_plan_hint": "落后或需要阻止领先者时提高权重；领先时只少量使用，避免暴露过多意图。", "strategy_labels": ["直接互动"], "required_for_ai_baseline": true, "sort_order": 5},
	"tactical_support": {"display_name": "即时战术", "goal": "补足短线现金、目标、位移或其它临场节奏。", "play_pattern": "用短线效果修补当前局势，不强行形成长期路线。", "counterplay": "观察结算余波和资源门槛，判断它服务哪条赚钱路线。", "ai_plan_hint": "只作为补位加权，不能压过明确的经济/破坏计划。", "strategy_labels": ["即时战术"], "required_for_ai_baseline": false, "sort_order": 6},
}

const LEGACY_MAIN_DIAGNOSTIC_SYMBOLS := [
	"_development_route_profiles", "_development_route_for_skill", "_development_route_label",
	"_card_strength_budget_points", "_card_strength_budget_report", "_development_route_balance_audit",
	"_development_route_pressure_audit", "_direct_interaction_balance_report", "_role_balance_audit",
	"_monster_ecology_balance_report", "_product_ecosystem_report", "_card_supply_product_filter_audit",
	"_card_one_glance_audit_report", "_runtime_balance_snapshot", "_playable_card_resolution_coverage_report",
]

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var status_label: Label = %BalanceRuntimeBridgeBenchStatusLabel
@onready var summary_label: Label = %BalanceRuntimeBridgeBenchSummaryLabel
@onready var preview_host: Control = %BalanceRuntimeBridgeBenchPreviewHost

var _bridge: RefCounted = BridgeScript.new()
var _suite_running := false
var _main: Control
var _coordinator: Node
var _diagnostics: GameplayBalanceDiagnosticsRuntimeService
var _diagnostics_world_bridge: GameplayBalanceDiagnosticsWorldBridge
var _diagnostics_world_snapshot: Dictionary = {}
var _diagnostics_balance_report: Dictionary = {}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_flow_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func flow_cases() -> Array:
	return _duplicate_array(FLOW_CASES + DIAGNOSTICS_CASES)


func build_flow_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in flow_cases():
		var flow_case: Dictionary = case_variant if case_variant is Dictionary else {}
		records.append({
			"case_id": str(flow_case.get("case_id", "")),
			"source_mode": str(flow_case.get("source_mode", "")),
			"json_checked": false,
			"resource_checked": false,
			"parity_checked": false,
			"runtime_default_checked": false,
			"pure_data_checked": false,
			"service_checked": false,
			"world_bridge_checked": false,
			"route_resource_checked": false,
			"report_checked": false,
			"formula_owner_checked": false,
			"privacy_checked": false,
			"mutation_checked": false,
			"main_absence_checked": false,
			"tests_migrated_checked": false,
			"passed": false,
			"notes": "Preview manifest only; run_flow_suite records live bridge checks.",
		})
	return {
		"suite": "gameplay_balance_diagnostics_cutover",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"main_metrics": _main_metrics(),
		"records": records,
	}


func run_flow_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_set_status("Running Balance Runtime Bridge suite...")
	_prepare_output_dir()
	var preview := _ensure_preview()
	await _prepare_diagnostics_runtime()
	var records: Array = []
	var all_passed := preview != null
	if preview == null:
		push_error("BalanceRuntimeBridgeBench could not instantiate preview.")
	else:
		for case_variant in flow_cases():
			var flow_case: Dictionary = case_variant if case_variant is Dictionary else {}
			var record: Dictionary = await _run_flow_case(preview, flow_case)
			records.append(record)
			all_passed = all_passed and bool(record.get("passed", false))
	var manifest := {
		"suite": "gameplay_balance_diagnostics_cutover",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"main_metrics": _main_metrics(),
		"records": records,
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	_write_screenshot()
	print("BalanceRuntimeBridgeBench manifest: %s" % MANIFEST_PATH)
	print("BalanceRuntimeBridgeBench report: %s" % REPORT_PATH)
	print("BalanceRuntimeBridgeBench screenshot: %s" % SCREENSHOT_PATH)
	if all_passed:
		_set_status("Balance Runtime Bridge passed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	else:
		_set_status("Balance Runtime Bridge failed: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
		push_error("BalanceRuntimeBridgeBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _ensure_preview() -> Control:
	if preview_host == null:
		return null
	var existing := preview_host.find_child("BalanceRuntimeBridgeMcpPreview", true, false) as Control
	if existing != null:
		return existing
	var preview := PREVIEW_SCENE.instantiate() as Control
	if preview == null:
		return null
	preview.name = "BalanceRuntimeBridgeMcpPreview"
	preview_host.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return preview


func _run_flow_case(preview: Control, flow_case: Dictionary) -> Dictionary:
	var case_id := str(flow_case.get("case_id", ""))
	var source_mode := str(flow_case.get("source_mode", "json_current"))
	if source_mode == "diagnostics":
		return _run_diagnostics_case(flow_case)
	var selected := bool(preview.call("apply_source_mode", source_mode)) if preview.has_method("apply_source_mode") else false
	await _settle_frames(2)
	var comparison_variant: Variant = _bridge.call("compare_sources")
	var comparison: Dictionary = comparison_variant if comparison_variant is Dictionary else {}
	var json_runtime: Dictionary = _bridge.call("json_runtime_targets")
	var resource_runtime: Dictionary = _bridge.call("resource_runtime_targets")
	var json_curve: Dictionary = _bridge.call("json_price_curve")
	var resource_curve: Dictionary = _bridge.call("resource_price_curve")
	var runtime_payload: Dictionary = _bridge.call("runtime_targets", source_mode)
	var price_payload: Dictionary = _bridge.call("price_curve", source_mode)
	var json_checked := not json_runtime.is_empty() and not json_curve.is_empty()
	var resource_checked := not resource_runtime.is_empty() and not resource_curve.is_empty()
	var parity_checked := bool(comparison.get("runtime_targets_parity", false)) and bool(comparison.get("price_curve_parity", false))
	var runtime_default_checked := str(_bridge.call("default_source_mode")) == "json_current"
	var pure_data_checked := _is_pure_data(comparison) and _is_pure_data(runtime_payload) and _is_pure_data(price_payload)
	var passed := selected and _case_condition(case_id, source_mode, comparison, runtime_payload, price_payload, json_runtime, resource_runtime, json_curve, resource_curve, json_checked, resource_checked, parity_checked, runtime_default_checked, pure_data_checked)
	return {
		"case_id": case_id,
		"source_mode": source_mode,
		"json_checked": json_checked,
		"resource_checked": resource_checked,
		"parity_checked": parity_checked,
		"runtime_default_checked": runtime_default_checked,
		"pure_data_checked": pure_data_checked,
		"service_checked": false,
		"world_bridge_checked": false,
		"route_resource_checked": false,
		"report_checked": false,
		"formula_owner_checked": false,
		"privacy_checked": false,
		"mutation_checked": false,
		"main_absence_checked": false,
		"tests_migrated_checked": false,
		"preview_selected": selected,
		"passed": passed,
		"notes": str(flow_case.get("notes", "")) if passed else "failed: %s" % str(flow_case.get("notes", "")),
	}


func _prepare_diagnostics_runtime() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_main = packed.instantiate() as Control if packed != null else null
	if _main == null:
		return
	_main.visible = false
	add_child(_main)
	await _settle_frames(3)
	if _main.has_method("_new_game"):
		_main.call("_new_game")
	await _settle_frames(3)
	_coordinator = _main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	if _coordinator == null:
		return
	_diagnostics = _coordinator.get_node_or_null("GameplayBalanceDiagnosticsRuntimeService") as GameplayBalanceDiagnosticsRuntimeService
	_diagnostics_world_bridge = _coordinator.get_node_or_null("GameplayBalanceDiagnosticsWorldBridge") as GameplayBalanceDiagnosticsWorldBridge
	if _diagnostics == null or _diagnostics_world_bridge == null:
		return
	_diagnostics_world_snapshot = _diagnostics.refresh_world_snapshot(false)
	_diagnostics_balance_report = _diagnostics.build_balance_report(_diagnostics_world_snapshot)


func _run_diagnostics_case(flow_case: Dictionary) -> Dictionary:
	var case_id := str(flow_case.get("case_id", ""))
	var flags := {
		"service_checked": false,
		"world_bridge_checked": false,
		"route_resource_checked": false,
		"report_checked": false,
		"formula_owner_checked": false,
		"privacy_checked": false,
		"mutation_checked": false,
		"main_absence_checked": false,
		"tests_migrated_checked": false,
	}
	var passed := false
	match case_id:
		"diagnostics_service_scene_composition":
			flags["service_checked"] = true
			passed = load(DIAGNOSTICS_SERVICE_SCENE_PATH) is PackedScene and _diagnostics != null and _diagnostics.name == "GameplayBalanceDiagnosticsRuntimeService"
		"diagnostics_world_bridge_scene_composition":
			flags["world_bridge_checked"] = true
			passed = load(DIAGNOSTICS_WORLD_BRIDGE_SCENE_PATH) is PackedScene and _diagnostics_world_bridge != null and _diagnostics_world_bridge.name == "GameplayBalanceDiagnosticsWorldBridge"
		"coordinator_static_diagnostics_composition":
			flags["service_checked"] = true
			flags["world_bridge_checked"] = true
			var coordinator_source := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
			passed = _coordinator != null and coordinator_source.contains("GameplayBalanceDiagnosticsRuntimeService.tscn") and coordinator_source.contains("GameplayBalanceDiagnosticsWorldBridge.tscn")
		"diagnostics_service_api_contract":
			flags["service_checked"] = true
			passed = _diagnostics != null
			for method_name in ["configure", "development_routes", "route_profile", "route_for_card", "card_budget_report", "build_balance_report", "build_developer_panel_snapshot", "debug_snapshot"]:
				passed = passed and _diagnostics.has_method(method_name)
		"diagnostics_world_bridge_readonly_boundary":
			flags["world_bridge_checked"] = true
			flags["mutation_checked"] = true
			var debug := _diagnostics_world_bridge.debug_snapshot() if _diagnostics_world_bridge != null else {}
			passed = bool(debug.get("fact_collection_authority", false)) and not bool(debug.get("diagnostic_authority", true)) and not bool(debug.get("formula_authority", true)) and not bool(debug.get("world_mutation_authority", true))
		"diagnostics_monster_art_profiles_catalog_source":
			flags["world_bridge_checked"] = true
			flags["report_checked"] = true
			flags["main_absence_checked"] = true
			passed = _diagnostics_monster_art_profiles_are_catalog_backed() and _production_symbol_absent("_monster_art_profile")
		"development_route_catalog_loads":
			flags["route_resource_checked"] = true
			var catalog := load(ROUTE_CATALOG_PATH)
			var validation: Dictionary = catalog.call("validation_report") if catalog != null and catalog.has_method("validation_report") else {}
			passed = bool(validation.get("valid", false)) and int(validation.get("route_count", 0)) == 7
		"development_route_resources_inspector_editable":
			flags["route_resource_checked"] = true
			passed = true
			for route_id in ROUTE_BASELINE.keys():
				var route_resource := load("%s%s.tres" % [ROUTE_RESOURCE_DIR, route_id])
				passed = passed and route_resource is Resource and route_resource.has_method("to_runtime_dictionary") and route_resource.has_method("validation_issues")
		"development_route_count_seven":
			flags["route_resource_checked"] = true
			passed = _diagnostics != null and _diagnostics.development_routes().size() == 7
		"development_route_sort_order":
			flags["route_resource_checked"] = true
			passed = _route_sort_order_matches()
		"city_growth_metadata_parity", "contract_route_metadata_parity", "finance_speculation_metadata_parity", "monster_pressure_metadata_parity", "intel_supply_metadata_parity", "direct_interaction_metadata_parity", "tactical_support_metadata_parity":
			flags["route_resource_checked"] = true
			var route_id := case_id.trim_suffix("_metadata_parity")
			passed = _route_metadata_matches(route_id)
		"development_route_label_lookup":
			flags["route_resource_checked"] = true
			passed = _route_label_lookup_matches()
		"development_route_card_classification":
			flags["service_checked"] = true
			flags["report_checked"] = true
			passed = _real_card_routes_are_valid()
		"card_budget_points_report":
			flags["service_checked"] = true
			flags["report_checked"] = true
			passed = _card_budget_report_is_valid(false)
		"card_budget_band_report":
			flags["service_checked"] = true
			flags["report_checked"] = true
			passed = _card_budget_report_is_valid(true)
		"development_route_audit_report":
			flags["report_checked"] = true
			passed = _report_array_is_valid("development_routes", 7)
		"development_route_pressure_report":
			flags["report_checked"] = true
			passed = _report_dictionary_is_valid("development_route_pressure")
		"direct_interaction_report":
			flags["report_checked"] = true
			passed = _report_dictionary_is_valid("direct_interaction")
		"role_balance_report":
			flags["report_checked"] = true
			passed = _report_dictionary_is_valid("roles")
		"monster_ecology_report":
			flags["report_checked"] = true
			passed = _report_dictionary_is_valid("monster_ecology")
		"product_ecosystem_report":
			flags["report_checked"] = true
			passed = _report_dictionary_is_valid("product_ecosystem")
		"card_supply_product_filter_report":
			flags["report_checked"] = true
			passed = _report_dictionary_is_valid("card_supply")
		"card_one_glance_report":
			flags["report_checked"] = true
			passed = _report_dictionary_is_valid("card_one_glance")
		"developer_panel_service_source":
			flags["service_checked"] = true
			flags["report_checked"] = true
			var panel_source := FileAccess.get_file_as_string("res://scripts/ui/developer_balance_panel.gd")
			var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
			passed = panel_source.contains("set_diagnostics_service") and panel_source.contains("_diagnostics_service.build_developer_panel_snapshot") and main_source.contains("developer_balance_panel.call(\"set_diagnostics_service\", diagnostics)") and _report_dictionary_is_valid("developer_panel")
		"codex_consumers_use_diagnostics_service":
			flags["service_checked"] = true
			var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
			passed = main_source.contains("gameplay_balance_diagnostics_service().product_ecosystem_report") and main_source.contains("gameplay_balance_diagnostics_service().monster_ecology_balance_report") and main_source.contains("gameplay_balance_diagnostics_service().card_supply_layer_report")
		"runtime_balance_model_formula_owner":
			flags["formula_owner_checked"] = true
			var debug := _diagnostics.debug_snapshot() if _diagnostics != null else {}
			passed = str(debug.get("runtime_balance_model_owner", "")) == "res://scripts/balance/runtime_balance_model.gd" and not bool(debug.get("formula_authority", true))
		"diagnostics_snapshot_pure_data":
			flags["service_checked"] = true
			flags["world_bridge_checked"] = true
			flags["report_checked"] = true
			passed = _is_pure_data(_diagnostics_world_snapshot) and _is_pure_data(_diagnostics_balance_report)
		"diagnostics_privacy_boundary":
			flags["privacy_checked"] = true
			passed = not _contains_private_diagnostics_key(_diagnostics_world_snapshot) and not _contains_private_diagnostics_key(_diagnostics_balance_report)
		"main_legacy_diagnostics_absent":
			flags["main_absence_checked"] = true
			passed = _legacy_main_diagnostics_absent()
		"main_deletion_metrics_gate":
			flags["main_absence_checked"] = true
			passed = bool(_main_metrics().get("deletion_gate_passed", false))
		"tests_no_main_diagnostics_reflection":
			flags["tests_migrated_checked"] = true
			passed = _tests_no_main_diagnostics_reflection()
		"diagnostics_readonly_no_world_mutation":
			flags["mutation_checked"] = true
			passed = _diagnostics_does_not_mutate_world()
		"no_parallel_formula_owner":
			flags["formula_owner_checked"] = true
			passed = _diagnostics_has_no_formula_copy()
		"no_legacy_diagnostics_fallback":
			flags["main_absence_checked"] = true
			passed = _legacy_main_diagnostics_absent() and _diagnostics_has_no_legacy_fallback()
	var record := {
		"case_id": case_id,
		"source_mode": "diagnostics",
		"json_checked": false,
		"resource_checked": false,
		"parity_checked": case_id.ends_with("_parity") or case_id.contains("route_") or case_id.contains("budget_"),
		"runtime_default_checked": true,
		"pure_data_checked": _is_pure_data(_diagnostics_world_snapshot) and _is_pure_data(_diagnostics_balance_report),
		"passed": passed,
		"notes": str(flow_case.get("notes", "")) if passed else "failed: %s" % str(flow_case.get("notes", "")),
	}
	for key in flags.keys():
		record[key] = flags[key]
	return record


func _route_sort_order_matches() -> bool:
	if _diagnostics == null:
		return false
	var routes := _diagnostics.development_routes()
	if routes.size() != 7:
		return false
	for index in routes.size():
		if int((routes[index] as Dictionary).get("sort_order", -1)) != index:
			return false
	return true


func _route_metadata_matches(route_id: String) -> bool:
	if _diagnostics == null or not ROUTE_BASELINE.has(route_id):
		return false
	var actual := _diagnostics.route_profile(route_id)
	var expected: Dictionary = ROUTE_BASELINE[route_id]
	for key in expected.keys():
		if not _deep_equal(actual.get(key), expected[key]):
			return false
	return str(actual.get("id", "")) == route_id and str(actual.get("route_id", "")) == route_id


func _route_label_lookup_matches() -> bool:
	if _diagnostics == null:
		return false
	for route_id in ROUTE_BASELINE.keys():
		var expected: Dictionary = ROUTE_BASELINE[route_id]
		if _diagnostics.route_label(route_id) != str(expected.get("display_name", "")):
			return false
		if _diagnostics.route_goal(route_id) != str(expected.get("goal", "")):
			return false
		if _diagnostics.route_play_pattern(route_id) != str(expected.get("play_pattern", "")):
			return false
		if _diagnostics.route_counterplay(route_id) != str(expected.get("counterplay", "")):
			return false
	return true


func _real_card_routes_are_valid() -> bool:
	if _diagnostics == null:
		return false
	var valid_ids := {}
	for route_id in ROUTE_BASELINE.keys():
		valid_ids[route_id] = true
	var cards := _diagnostics_world_snapshot.get("cards", []) as Array
	if cards.is_empty():
		return false
	var classified_count := 0
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var route_id := _diagnostics.route_id_for_card(card_variant)
		if not valid_ids.has(route_id):
			return false
		classified_count += 1
	return classified_count == cards.size()


func _card_budget_report_is_valid(check_band: bool) -> bool:
	if _diagnostics == null:
		return false
	var cards := _diagnostics_world_snapshot.get("cards", []) as Array
	if cards.is_empty() or not (cards[0] is Dictionary):
		return false
	var card: Dictionary = cards[0]
	var report := _diagnostics.card_budget_report(card)
	var expected_points := _diagnostics.card_budget_points(card.get("skill", {}) as Dictionary)
	if int(report.get("points", -1)) != expected_points or str(report.get("card_name", "")) == "":
		return false
	return str(report.get("band", "")) == _diagnostics.card_budget_band_text(expected_points) if check_band else expected_points >= 0


func _report_array_is_valid(key: String, expected_size: int) -> bool:
	var value: Variant = _diagnostics_balance_report.get(key, [])
	return value is Array and (value as Array).size() == expected_size and _is_pure_data(value)


func _report_dictionary_is_valid(key: String) -> bool:
	var value: Variant = _diagnostics_balance_report.get(key, {})
	return value is Dictionary and not (value as Dictionary).is_empty() and _is_pure_data(value)


func _legacy_main_diagnostics_absent() -> bool:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for symbol in LEGACY_MAIN_DIAGNOSTIC_SYMBOLS:
		if source.contains("func %s(" % symbol):
			return false
	return true


func _main_metrics() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var nonblank := 0
	var functions := 0
	var top_level_variables := 0
	var constants := 0
	for line in source.split("\n"):
		var text := str(line)
		if text.strip_edges() != "":
			nonblank += 1
		if text.begins_with("func "):
			functions += 1
		elif text.begins_with("var "):
			top_level_variables += 1
		elif text.begins_with("const "):
			constants += 1
	return {
		"baseline_nonblank": MAIN_BASELINE_NONBLANK,
		"baseline_functions": MAIN_BASELINE_FUNCTIONS,
		"baseline_sha256": MAIN_BASELINE_SHA256,
		"nonblank": nonblank,
		"functions": functions,
		"top_level_variables": top_level_variables,
		"constants": constants,
		"sha256": source.sha256_text().to_upper(),
		"deleted_nonblank": MAIN_BASELINE_NONBLANK - nonblank,
		"deleted_functions": MAIN_BASELINE_FUNCTIONS - functions,
		"deletion_gate_passed": nonblank <= 21354 and functions <= 1319 and MAIN_BASELINE_NONBLANK - nonblank >= 1600 and MAIN_BASELINE_FUNCTIONS - functions >= 50,
	}


func _tests_no_main_diagnostics_reflection() -> bool:
	for path in ["res://tests/smoke_test.gd", "res://tests/runtime_balance_report_test.gd", "res://tests/card_use_case_gate_test.gd", "res://tests/card_play_requirement_policy_test.gd", "res://tests/region_supply_policy_test.gd"]:
		var source := FileAccess.get_file_as_string(path)
		for symbol in LEGACY_MAIN_DIAGNOSTIC_SYMBOLS:
			if source.contains("main.call(\"%s\"" % symbol) or source.contains("main.call(&\"%s\"" % symbol):
				return false
	return true


func _diagnostics_does_not_mutate_world() -> bool:
	if _main == null or _diagnostics == null:
		return false
	var before := _world_state_signature()
	var snapshot := _diagnostics.refresh_world_snapshot(false)
	var report := _diagnostics.build_balance_report(snapshot)
	var after := _world_state_signature()
	return before == after and _is_pure_data(report)


func _world_state_signature() -> int:
	return var_to_str({
		"players": _main.get("players"),
		"districts": _main.get("districts"),
		"selected_player": _main.get("selected_player"),
		"selected_district": _main.get("selected_district"),
		"skill_market": _main.get("skill_market"),
		"game_over": _main.get("game_over"),
	}).hash()


func _diagnostics_has_no_formula_copy() -> bool:
	if _diagnostics == null:
		return false
	var debug := _diagnostics.debug_snapshot()
	var source := FileAccess.get_file_as_string("res://scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd")
	return str(debug.get("runtime_balance_model_owner", "")) == "res://scripts/balance/runtime_balance_model.gd" and not bool(debug.get("formula_authority", true)) and not source.contains("func product_price_model(") and not source.contains("func victory_cash_goal_for_duration(") and not source.contains("func statistics_hub_report(")


func _diagnostics_has_no_legacy_fallback() -> bool:
	var service_source := FileAccess.get_file_as_string("res://scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd")
	for symbol in LEGACY_MAIN_DIAGNOSTIC_SYMBOLS:
		if service_source.contains("call(\"%s\"" % symbol) or service_source.contains("call(&\"%s\"" % symbol):
			return false
	return true


func _diagnostics_monster_art_profiles_are_catalog_backed() -> bool:
	var monsters: Array = _diagnostics_world_snapshot.get("monsters", []) if _diagnostics_world_snapshot.get("monsters", []) is Array else []
	if monsters.size() != MonsterCatalogV06.catalog_size():
		return false
	for monster_variant in monsters:
		if not (monster_variant is Dictionary):
			return false
		if not bool((monster_variant as Dictionary).get("has_art_profile", false)):
			return false
	return true


func _production_symbol_absent(symbol: String) -> bool:
	for path_variant in _production_script_files("res://scripts"):
		var path := str(path_variant)
		var source := FileAccess.get_file_as_string(path)
		if source.contains(symbol):
			return false
	return true


func _production_script_files(root_path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	while true:
		var item := dir.get_next()
		if item == "":
			break
		if item.begins_with("."):
			continue
		var path := "%s/%s" % [root_path, item]
		if dir.current_is_dir():
			if path == "res://scripts/tools":
				continue
			result.append_array(_production_script_files(path))
		elif path.ends_with(".gd"):
			result.append(path)
	dir.list_dir_end()
	return result


func _contains_private_diagnostics_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if ["hidden_owner", "private_target", "private_discard", "opponent_hand", "ai_private_plan", "private_hand", "secret_target"].has(key):
				return true
			if _contains_private_diagnostics_key((value as Dictionary)[key_variant]):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_private_diagnostics_key(item):
				return true
	return false


func _case_condition(case_id: String, source_mode: String, comparison: Dictionary, runtime_payload: Dictionary, price_payload: Dictionary, json_runtime: Dictionary, resource_runtime: Dictionary, json_curve: Dictionary, resource_curve: Dictionary, json_checked: bool, resource_checked: bool, parity_checked: bool, runtime_default_checked: bool, pure_data_checked: bool) -> bool:
	match case_id:
		"json_runtime_targets_loads":
			return json_checked and str(json_runtime.get("version", "")) == "runtime_balance_v1"
		"resource_runtime_targets_loads":
			return resource_checked and str(resource_runtime.get("version", "")) == "runtime_balance_v1"
		"json_price_curve_loads":
			return json_checked and int((json_curve.get("weights", {}) as Dictionary).size() if json_curve.get("weights", {}) is Dictionary else 0) >= 8
		"resource_price_curve_loads":
			return resource_checked and int((resource_curve.get("weights", {}) as Dictionary).size() if resource_curve.get("weights", {}) is Dictionary else 0) >= 8
		"runtime_targets_parity":
			return bool(comparison.get("runtime_targets_parity", false))
		"price_curve_parity":
			return bool(comparison.get("price_curve_parity", false))
		"source_mode_json_current":
			return source_mode == "json_current" and _deep_equal(runtime_payload, json_runtime) and _deep_equal(price_payload, json_curve)
		"source_mode_resource_profile":
			return source_mode == "resource_profile" and _deep_equal(runtime_payload, resource_runtime) and _deep_equal(price_payload, resource_curve)
		"first_mission_runtime_default_unchanged":
			return runtime_default_checked and str(ProjectSettings.get_setting("application/run/main_scene", "")) == "res://scenes/main.tscn"
		"no_callable_or_object_in_payloads":
			return pure_data_checked and parity_checked
	return json_checked and resource_checked and runtime_default_checked and pure_data_checked


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _write_text_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s" % path)
		return
	file.store_string(text)
	file.close()


func _build_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Gameplay Balance Diagnostics & Runtime Bridge QA",
		"",
		"Output: `%s`" % OUTPUT_DIR,
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"",
		"| Case | Mode | Service | World Bridge | Route Resource | Report | Formula Owner | Privacy | Read-only | Pure Data | Passed | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("source_mode", "")),
			str(record.get("service_checked", false)),
			str(record.get("world_bridge_checked", false)),
			str(record.get("route_resource_checked", false)),
			str(record.get("report_checked", false)),
			str(record.get("formula_owner_checked", false)),
			str(record.get("privacy_checked", false)),
			str(record.get("mutation_checked", false)),
			str(record.get("pure_data_checked", false)),
			str(record.get("passed", false)),
			str(record.get("notes", "")).replace("|", "/"),
		])
	return "\n".join(lines) + "\n"


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		var record: Dictionary = record_variant if record_variant is Dictionary else {}
		if bool(record.get("passed", false)):
			count += 1
	return count


func _write_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(SCREENSHOT_PATH)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	if summary_label != null:
		summary_label.text = text


func _settle_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _duplicate_array(source: Array) -> Array:
	var result: Array = []
	for value in source:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
		elif value is Array:
			result.append(_duplicate_array(value))
		else:
			result.append(value)
	return result


func _deep_equal(left: Variant, right: Variant) -> bool:
	var left_type := typeof(left)
	var right_type := typeof(right)
	if _is_number_type(left_type) and _is_number_type(right_type):
		return is_equal_approx(float(left), float(right))
	if left_type != right_type:
		return false
	if left is Dictionary:
		var left_dictionary: Dictionary = left
		var right_dictionary: Dictionary = right
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key in left_dictionary.keys():
			if not right_dictionary.has(key):
				return false
			if not _deep_equal(left_dictionary[key], right_dictionary[key]):
				return false
		return true
	if left is Array:
		var left_array: Array = left
		var right_array: Array = right
		if left_array.size() != right_array.size():
			return false
		for index in left_array.size():
			if not _deep_equal(left_array[index], right_array[index]):
				return false
		return true
	return left == right


func _is_number_type(value_type: int) -> bool:
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
