extends Control
class_name CityGdpDerivativeRuntimeBench

const CONTROLLER_SCENE_PATH := "res://scenes/runtime/CityGdpDerivativeRuntimeController.tscn"
const BRIDGE_SCENE_PATH := "res://scenes/runtime/CityGdpDerivativeRuntimeWorldBridge.tscn"
const FORMULA_SCENE_PATH := "res://scenes/runtime/CardEconomyProductRouteFormulaRuntimeService.tscn"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const QUEUE_SCRIPT_PATH := "res://scripts/runtime/card_resolution_queue_runtime_service.gd"
const ELIGIBILITY_SCRIPT_PATH := "res://scripts/runtime/card_play_eligibility_runtime_service.gd"
const PRESENTATION_SCRIPT_PATH := "res://scripts/runtime/card_presentation_runtime_service.gd"
const AI_SCRIPT_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const EXECUTION_SCRIPT_PATH := "res://scripts/runtime/card_resolution_execution_runtime_service.gd"
const CATALOG_PATH := "res://resources/finance/city_gdp_derivatives/city_gdp_derivative_terms_v04_catalog.tres"
const OUTPUT_DIR := "user://space_syndicate_design_qa/city_gdp_derivative_v04/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/city_gdp_derivative_v04_terms_alignment.png"
const CASE_COUNT := 40

const CARD_EXPECTATIONS := {
	"城市买涨1": [1, "up", false, 60.0, 1.0, 0, 120, 260, 120],
	"城市买涨2": [2, "up", false, 75.0, 1.6, 0, 180, 420, 180],
	"城市买涨3": [3, "up", false, 90.0, 2.3, 0, 260, 650, 260],
	"城市买涨4": [4, "up", false, 120.0, 3.2, 0, 360, 900, 360],
	"城市做空1": [1, "down", false, 60.0, 1.0, 180, 120, 260, 120],
	"城市做空2": [2, "down", false, 75.0, 1.7, 320, 180, 420, 180],
	"城市做空3": [3, "down", false, 90.0, 2.5, 520, 260, 650, 260],
	"城市做空4": [4, "down", false, 120.0, 3.4, 760, 360, 900, 360],
	"灾害保单1": [1, "down", true, 75.0, 0.75, 140, 90, 220, 90],
	"灾害保单2": [2, "down", true, 90.0, 1.1, 260, 140, 340, 140],
	"灾害保单3": [3, "down", true, 105.0, 1.55, 430, 210, 520, 210],
	"灾害保单4": [4, "down", true, 120.0, 2.1, 680, 300, 760, 300],
}

const RUNTIME_CASE_IDS := [
	"terms_catalog_valid", "controller_scene_composition", "coordinator_scene_composition",
	"world_bridge_contract", "queue_margin_preflight", "eligibility_margin_reason",
	"presentation_financial_terms", "ai_risk_adjusted_terms", "effect_open_locks_margin",
	"insufficient_margin_atomic_reject", "insurance_owner_reject", "insurance_owner_success",
	"long_favorable_settlement", "long_adverse_settlement", "short_favorable_settlement",
	"short_adverse_settlement", "zero_delta_refunds_margin", "maximum_gain_cap",
	"maximum_loss_cap", "destroyed_city_long_settlement", "destroyed_city_short_settlement",
	"destroyed_city_insurance_settlement", "expiry_exact_once", "destruction_exact_once",
	"current_save_roundtrip", "legacy_save_normalization", "public_snapshot_privacy",
	"main_legacy_engine_absent",
]

@export var auto_run := true

@onready var runtime_host: Node = %RuntimeHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var cases_text: RichTextLabel = %CasesText

var _controller: CityGdpDerivativeRuntimeController
var _bridge: CityGdpDerivativeRuntimeWorldBridge
var _formula: CardEconomyProductRouteFormulaRuntimeService
var _world: FixtureWorld
var _cash_mutation_port: PlayerCashMutationPort
var _mutation_authority: SimulationMutationAuthority
var _monster: MonsterRuntimeController
var _records: Array = []
var _failures: Array[String] = []


class FixtureWorld:
	extends WorldSessionState

	var private_events: Array = []
	var public_events: Array = []

	func reset_fixture(cash := 1000, city_owner_index := 0, current_gdp := 100) -> void:
		game_time = 0.0
		players = [_player(cash, 0), _player(cash, 1)]
		districts = [{"region_id": "region.000", "name": "晨昏港", "city": {"active": true, "owner": city_owner_index, "last_income": current_gdp, "public_clues": []}}]
		private_events = []
		public_events = []

	func _player(cash: int, index: int) -> Dictionary:
		return {
			"id": "player-%d" % index,
			"cash": cash,
			"cash_cents": cash * 100,
			"cash_history": [cash],
			"economic_ledger": [],
			"v06_transaction_ledger": [],
			"total_card_income": 0,
			"total_role_income": 0,
			"eliminated": false,
		}

	func set_gdp(value: int) -> void:
		districts[0]["city"]["last_income"] = value

	func _city_competition_matches(_district_index: int) -> int:
		return 0

	func _city_cycle_income(district_index: int, _competition: int) -> int:
		return int((districts[district_index]["city"] as Dictionary).get("last_income", 0))

	func _append_city_gdp_derivative_public_clue(district_index: int, clue: String) -> bool:
		var city := (districts[district_index]["city"] as Dictionary).duplicate(true)
		var clues: Array = city.get("public_clues", []) as Array
		clues.append(clue)
		city["public_clues"] = clues
		districts[district_index]["city"] = city
		return true

	func _present_city_gdp_derivative_opened(position: Dictionary) -> void:
		public_events.append({"kind": "opened", "position": position.duplicate(true)})

	func _present_city_gdp_derivative_settlement(district_index: int, reason: String, receipts: Array) -> void:
		public_events.append({"kind": "settled", "district_index": district_index, "reason": reason, "receipts": receipts.duplicate(true)})


class FixtureMonster:
	extends MonsterRuntimeController

	func private_wager_cash_commitment_snapshot(player_index: int, excluded_wager_id: int = -1) -> Dictionary:
		return {
			"valid": player_index >= 0,
			"reason_code": "monster_wager_commitment_ready" if player_index >= 0 else "monster_wager_commitment_player_invalid",
			"reserved_cents": 0,
			"commitment_revision": 0,
			"commitment_fingerprint": "fixture:%d:%d" % [player_index, excluded_wager_id],
		}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_runtime_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func runtime_cases() -> Array:
	var result: Array = []
	for card_id_variant in CARD_EXPECTATIONS.keys():
		result.append("terms_%s" % str(card_id_variant))
	result.append_array(RUNTIME_CASE_IDS)
	return result


func build_runtime_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in runtime_cases():
		records.append(_record_shape(str(case_id_variant), false, "preview"))
	return {"ruleset_id": "v0.4", "case_count": records.size(), "records": records, "output_dir": OUTPUT_DIR}


func run_runtime_suite() -> void:
	_records = []
	_failures = []
	if not _setup_runtime():
		_finish_suite()
		return
	_run_terms_cases()
	_run_structure_cases()
	_run_position_cases()
	_run_save_and_privacy_cases()
	_finish_suite()


func _setup_runtime() -> bool:
	_formula = _instantiate(FORMULA_SCENE_PATH) as CardEconomyProductRouteFormulaRuntimeService
	_bridge = _instantiate(BRIDGE_SCENE_PATH) as CityGdpDerivativeRuntimeWorldBridge
	_controller = _instantiate(CONTROLLER_SCENE_PATH) as CityGdpDerivativeRuntimeController
	_world = FixtureWorld.new()
	_world.name = "FixtureWorld"
	for node in [_world, _formula, _bridge, _controller]:
		if node == null:
			_failures.append("runtime_scene_instantiation_failed")
			return false
		runtime_host.add_child(node)
	_formula.configure({"ruleset_id": "v0.4"})
	_bridge.bind_world(_world)
	_bridge.set_world_session_state(_world)
	_monster = FixtureMonster.new()
	var query := MonsterWagerCashCommitmentQueryPort.new()
	var identity := SimulationStateIdentity.new()
	var audit := SimulationDeterminismAudit.new()
	_mutation_authority = SimulationMutationAuthority.new()
	_cash_mutation_port = PlayerCashMutationPort.new()
	var dependencies: Array[Node] = [_monster, query, identity, audit, _mutation_authority, _cash_mutation_port]
	for dependency in dependencies:
		runtime_host.add_child(dependency)
	query.configure(_world, _monster)
	_mutation_authority.bind_diagnostics(identity, audit)
	_mutation_authority.begin_step(1)
	_cash_mutation_port.configure(_world, query, _mutation_authority)
	_bridge.set_cash_commitment_query_port(query)
	_bridge.set_cash_mutation_port(_cash_mutation_port)
	_controller.set_world_bridge(_bridge)
	_controller.configure({"ruleset_id": "v0.4"}, _formula)
	_world.reset_fixture()
	return bool(_controller.debug_snapshot().get("controller_ready", false))


func _run_terms_cases() -> void:
	for card_id_variant in CARD_EXPECTATIONS.keys():
		var card_id := str(card_id_variant)
		var expected: Array = CARD_EXPECTATIONS[card_id]
		var terms := _controller.terms_for_card_id(card_id)
		var passed := int(terms.get("rank", 0)) == int(expected[0]) \
			and str(terms.get("direction", "")) == str(expected[1]) \
			and bool(terms.get("insurance", false)) == bool(expected[2]) \
			and is_equal_approx(float(terms.get("duration_seconds", 0.0)), float(expected[3])) \
			and is_equal_approx(float(terms.get("multiplier", 0.0)), float(expected[4])) \
			and int(terms.get("destroy_bonus", -1)) == int(expected[5]) \
			and int(terms.get("margin_cash", -1)) == int(expected[6]) \
			and int(terms.get("maximum_gain", -1)) == int(expected[7]) \
			and int(terms.get("maximum_loss", -1)) == int(expected[8]) \
			and int(terms.get("action_fee_cash", -1)) == 0 \
			and str(terms.get("terms_version", "")) == "v0.4" \
			and _is_data_only(terms)
		_add_record("terms_%s" % card_id, passed, "Inspector Resource terms match the authored v0.4 table.", {"card_id": card_id, "terms_checked": true})


func _run_structure_cases() -> void:
	var catalog_report := _controller.terms_catalog.validation_report() if _controller.terms_catalog != null else {}
	_add_record("terms_catalog_valid", bool(catalog_report.get("valid", false)) and int(catalog_report.get("card_count", 0)) == 12, "The catalog is complete and validates all twelve cards.", {"terms_checked": true})
	var controller_scene := FileAccess.get_file_as_string(CONTROLLER_SCENE_PATH)
	_add_record("controller_scene_composition", controller_scene.contains(CATALOG_PATH) and controller_scene.contains("CityGdpDerivativeRuntimeController"), "The real Controller scene owns the catalog Resource.", {"composition_checked": true})
	var coordinator_scene := FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	_add_record("coordinator_scene_composition", coordinator_scene.contains("CityGdpDerivativeRuntimeController.tscn") and coordinator_scene.contains("CityGdpDerivativeRuntimeWorldBridge.tscn"), "Controller and WorldBridge are static coordinator children.", {"composition_checked": true})
	var bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/city_gdp_derivative_runtime_world_bridge.gd")
	_add_record("world_bridge_contract", bridge_source.contains("set_cash_mutation_port") and not bridge_source.contains("_commit_city_gdp_derivative_cash_delta") and bridge_source.contains("_append_city_gdp_derivative_public_clue") and not bridge_source.contains("maximum_gain"), "WorldBridge routes typed cash mutations and world facts without owning formulas.", {"world_bridge_checked": true})
	var queue_source := FileAccess.get_file_as_string(QUEUE_SCRIPT_PATH)
	_add_record("queue_margin_preflight", queue_source.contains("financial_margin_cents") and queue_source.contains("financial_cash_required_cents") and queue_source.contains("financial_margin_locked_on_queue\": false"), "Queue consumes typed margin cents from eligibility/submission and never locks the margin itself.", {"authorization_checked": true})
	var eligibility_source := FileAccess.get_file_as_string(ELIGIBILITY_SCRIPT_PATH)
	_add_record("eligibility_margin_reason", eligibility_source.contains("financial_margin_insufficient") and eligibility_source.contains("gdp_derivative_terms"), "Eligibility exposes the same stable insufficient-margin reason.", {"authorization_checked": true})
	var presentation_source := FileAccess.get_file_as_string(PRESENTATION_SCRIPT_PATH)
	_add_record("presentation_financial_terms", presentation_source.contains("gdp_derivative_terms") and presentation_source.contains("maximum_gain") and presentation_source.contains("maximum_loss"), "Presentation reads authored terms for duration, margin, and caps.", {"presentation_checked": true})
	var ai_source := FileAccess.get_file_as_string(AI_SCRIPT_PATH)
	_add_record("ai_risk_adjusted_terms", ai_source.contains("_city_gdp_derivative_risk_adjusted_value") and ai_source.contains("maximum_gain") and not ai_source.contains("gdp_bet_"), "AI scores risk-adjusted authored terms without taking settlement ownership.", {"ai_checked": true})


func _run_position_cases() -> void:
	_reset_fixture(1000, 0, 100)
	var opened := _open("城市买涨1", 0)
	_add_record("effect_open_locks_margin", bool(opened.get("committed", false)) and _cash(0) == 880 and int(opened.get("locked_margin", 0)) == 120 and _position_count() == 1, "Effect open rechecks and locks margin exactly once.", {"margin_checked": true, "exact_once_checked": true})

	_reset_fixture(119, 0, 100)
	var rejected := _open("城市买涨1", 0)
	_add_record("insufficient_margin_atomic_reject", not bool(rejected.get("committed", true)) and str(rejected.get("reason", "")) == "financial_margin_insufficient" and _cash(0) == 119 and _position_count() == 0, "Insufficient margin rejects without cash or position mutation.", {"margin_checked": true, "authorization_checked": true})

	_reset_fixture(1000, 1, 100)
	var owner_reject := _open("灾害保单1", 0)
	_add_record("insurance_owner_reject", str(owner_reject.get("reason", "")) == "insurance_owner_mismatch" and _cash(0) == 1000 and _position_count() == 0, "Insurance can target only the actor's active city.", {"target_checked": true})
	_reset_fixture(1000, 0, 100)
	var owner_success := _open("灾害保单1", 0)
	_add_record("insurance_owner_success", bool(owner_success.get("committed", false)) and _cash(0) == 910 and _position_count() == 1, "Owned-city insurance opens through the same Controller route.", {"target_checked": true, "margin_checked": true})

	_add_record("long_favorable_settlement", _settlement_case("城市买涨1", 150, false, 50, 0, 1050), "A favorable long realizes capped gain and returns margin.", {"settlement_checked": true})
	_add_record("long_adverse_settlement", _settlement_case("城市买涨1", 40, false, 0, 60, 940), "An adverse long realizes a capped loss from locked margin.", {"settlement_checked": true})
	_add_record("short_favorable_settlement", _settlement_case("城市做空1", 40, false, 60, 0, 1060), "A favorable short profits from real GDP decline.", {"settlement_checked": true})
	_add_record("short_adverse_settlement", _settlement_case("城市做空1", 160, false, 0, 60, 940), "An adverse short loses only the authored capped amount.", {"settlement_checked": true})
	_add_record("zero_delta_refunds_margin", _settlement_case("城市买涨1", 100, false, 0, 0, 1000), "Zero GDP delta refunds all locked margin.", {"margin_checked": true, "settlement_checked": true})
	_add_record("maximum_gain_cap", _settlement_case("城市买涨1", 1000, false, 260, 0, 1260), "Extreme favorable movement cannot exceed maximum_gain.", {"settlement_checked": true})
	_add_record("maximum_loss_cap", _settlement_case("城市买涨1", -1000, false, 0, 120, 880), "Extreme adverse movement cannot exceed locked margin or maximum_loss.", {"settlement_checked": true})
	_add_record("destroyed_city_long_settlement", _settlement_case("城市买涨1", 0, true, 0, 100, 900), "City destruction immediately settles long loss through the destruction formula.", {"destruction_checked": true})
	_add_record("destroyed_city_short_settlement", _settlement_case("城市做空1", 0, true, 260, 0, 1260), "City destruction settles short gain with destroy bonus and cap.", {"destruction_checked": true})
	_add_record("destroyed_city_insurance_settlement", _settlement_case("灾害保单1", 0, true, 215, 0, 1215), "City destruction settles owned-city insurance with authored cap.", {"destruction_checked": true})

	_reset_fixture(1000, 0, 100)
	_open("城市买涨1", 0)
	_world.set_gdp(150)
	var first := _controller.settle_district(0, 150, "expiry", true)
	var cash_after_first := _cash(0)
	var second := _controller.settle_district(0, 150, "expiry", true)
	_add_record("expiry_exact_once", int(first.get("settled_count", 0)) == 1 and int(second.get("settled_count", 0)) == 0 and _cash(0) == cash_after_first and _position_count() == 0, "Expiry removes the position after one committed receipt.", {"exact_once_checked": true})

	_reset_fixture(1000, 0, 100)
	_open("城市做空1", 0)
	var destroy_first := _controller.settle_destroyed_city(0, "fixture")
	var destroy_cash := _cash(0)
	var destroy_second := _controller.settle_destroyed_city(0, "fixture")
	_add_record("destruction_exact_once", int(destroy_first.get("settled_count", 0)) == 1 and int(destroy_second.get("settled_count", 0)) == 0 and _cash(0) == destroy_cash and _position_count() == 0, "Destruction settlement removes positions and cannot pay twice.", {"exact_once_checked": true})


func _run_save_and_privacy_cases() -> void:
	_reset_fixture(1000, 0, 100)
	_open("城市买涨2", 0)
	var saved := _controller.to_save_data()
	_controller.reset_state()
	_controller.apply_save_data(saved)
	var restored := _controller.positions_for_district(0, true)
	_add_record("current_save_roundtrip", restored.size() == 1 and str((restored[0] as Dictionary).get("terms_version", "")) == "v0.4" and int((restored[0] as Dictionary).get("locked_margin", 0)) == 180, "Current saves retain locked v0.4 terms and position identity.", {"save_checked": true})

	_reset_fixture(1000, 0, 100)
	var legacy := {"0": [{"owner": 0, "source": "城市买涨1", "baseline_gdp": 100, "direction": "up", "multiplier": 1.0, "destroy_bonus": 0, "expires_at": 60.0}]}
	_controller.apply_save_data({}, legacy)
	var normalized := _controller.positions_for_district(0, true)
	var legacy_position: Dictionary = normalized[0] as Dictionary if not normalized.is_empty() else {}
	_add_record("legacy_save_normalization", int(legacy_position.get("locked_margin", -1)) == 0 and int(legacy_position.get("maximum_loss", -1)) == 0 and int(legacy_position.get("maximum_gain", 0)) == 260 and _cash(0) == 1000, "Legacy positions normalize once without retroactive margin charge or legacy formula branch.", {"save_checked": true})

	var public_snapshot := _controller.public_positions_snapshot()
	var debug := _controller.debug_snapshot()
	var serialized := JSON.stringify({"public": public_snapshot, "debug": debug})
	_add_record("public_snapshot_privacy", _is_data_only(public_snapshot) and _is_data_only(debug) and not serialized.contains("\"owner\"") and not serialized.contains("player_index"), "Public and debug snapshots expose counts and terms, never position owners or private plans.", {"privacy_checked": true, "pure_data_checked": true})

	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SCRIPT_PATH)
	var old_tokens := ["gdp_bet_", "func _apply_city_gdp_derivative(", "func _pay_city_gdp_derivative(", "func _resolve_city_gdp_derivatives(", "gdp_derivative_payout", "gdp_derivative_destroy_payout"]
	var absent := true
	for token_variant in old_tokens:
		absent = absent and not main_source.contains(str(token_variant))
	absent = absent and main_source.contains("city_gdp_derivative_runtime_call") and main_source.contains("city_gdp_derivative_runtime") and not execution_source.contains("CityGdpDerivativeRuntimeController")
	_add_record("main_legacy_engine_absent", absent, "main contains only world adapters/save routing; Execution remains narrow and no parallel derivative engine survives.", {"legacy_formula_absent": true, "execution_boundary_checked": true})


func _settlement_case(card_id: String, current_gdp: int, destroyed: bool, expected_gain: int, expected_loss: int, expected_cash: int) -> bool:
	_reset_fixture(1000, 0, 100)
	var opened := _open(card_id, 0)
	if not bool(opened.get("committed", false)):
		return false
	_world.set_gdp(current_gdp)
	var settlement := _controller.settle_destroyed_city(0, "fixture") if destroyed else _controller.settle_district(0, current_gdp, "fixture", true)
	var receipts: Array = settlement.get("receipts", []) as Array
	if receipts.size() != 1:
		return false
	var receipt := receipts[0] as Dictionary
	return int(receipt.get("gain", -1)) == expected_gain and int(receipt.get("loss", -1)) == expected_loss and _cash(0) == expected_cash and _position_count() == 0


func _reset_fixture(cash: int, city_owner_index: int, current_gdp: int) -> void:
	_controller.reset_state()
	_world.reset_fixture(cash, city_owner_index, current_gdp)


func _open(card_id: String, player_index: int) -> Dictionary:
	var skill := _controller.skill_with_terms(card_id, {"name": card_id, "kind": "city_gdp_derivative"})
	return _controller.open_position(player_index, skill, 0)


func _cash(player_index: int) -> int:
	return int((_world.players[player_index] as Dictionary).get("cash", 0))


func _position_count() -> int:
	return int(_controller.public_positions_snapshot().get("position_count", 0))


func _instantiate(path: String) -> Node:
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _add_record(case_id: String, passed: bool, notes: String, flags: Dictionary = {}) -> void:
	var record := _record_shape(case_id, passed, notes)
	record.merge(flags.duplicate(true), true)
	_records.append(record)
	if not passed:
		_failures.append(case_id)


func _record_shape(case_id: String, passed: bool, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"card_id": "",
		"terms_checked": false,
		"authorization_checked": false,
		"margin_checked": false,
		"settlement_checked": false,
		"exact_once_checked": false,
		"save_checked": false,
		"privacy_checked": false,
		"pure_data_checked": true,
		"passed": passed,
		"notes": notes,
	}


func _finish_suite() -> void:
	var passed_count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			passed_count += 1
	var manifest := {
		"ruleset_id": "v0.4",
		"case_count": _records.size(),
		"passed_count": passed_count,
		"failed_count": _records.size() - passed_count,
		"records": _records.duplicate(true),
		"output_dir": OUTPUT_DIR,
		"controller_debug": _controller.debug_snapshot() if _controller != null else {},
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	_save_screenshot()
	print("CityGdpDerivativeRuntimeBench: %d/%d passed" % [passed_count, CASE_COUNT])
	print("CityGdpDerivativeRuntimeBench manifest: %s" % MANIFEST_PATH)
	print("CityGdpDerivativeRuntimeBench report: %s" % REPORT_PATH)
	print("CityGdpDerivativeRuntimeBench screenshot: %s" % SCREENSHOT_PATH)
	if _records.size() != CASE_COUNT:
		push_error("City GDP derivative case count mismatch: %d/%d" % [_records.size(), CASE_COUNT])
	if not _failures.is_empty():
		push_error("City GDP derivative failures: %s" % ", ".join(_failures))
	await get_tree().create_timer(1.5).timeout
	get_tree().quit(0 if _records.size() == CASE_COUNT and _failures.is_empty() else 1)


func _update_ui(manifest: Dictionary) -> void:
	var passed_count := int(manifest.get("passed_count", 0))
	summary_label.text = "%d/%d passed | 12 Resources | margin + capped P&L + exact-once" % [passed_count, CASE_COUNT]
	status_label.text = "PASS" if passed_count == CASE_COUNT else "FAIL"
	status_label.modulate = Color("#86efac") if passed_count == CASE_COUNT else Color("#fb7185")
	var lines: Array[String] = []
	for record_variant in _records:
		var record := record_variant as Dictionary
		lines.append("[color=%s]%s[/color]  %s" % ["#86efac" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", ""))])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# City GDP Derivative v0.4 Terms Alignment",
		"",
		"- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), CASE_COUNT],
		"- Runtime owner: `CityGdpDerivativeRuntimeController`",
		"- Terms source: `%s`" % CATALOG_PATH,
		"- Output: `%s`" % OUTPUT_DIR,
		"",
		"## Cases",
	]
	for record_variant in _records:
		var record := record_variant as Dictionary
		lines.append("- [%s] `%s`: %s" % ["x" if bool(record.get("passed", false)) else " ", str(record.get("case_id", "")), str(record.get("notes", ""))])
	return "\n".join(lines) + "\n"


func _write_text(path: String, content: String) -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("write_failed:%s" % path)
		return
	file.store_string(content)


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var texture := get_viewport().get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://space_syndicate_design_qa/"))
	var error := image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))
	if error != OK:
		_failures.append("screenshot_failed:%s" % error_string(error))


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	if value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
		return true
	return false
