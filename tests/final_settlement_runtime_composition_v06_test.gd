extends SceneTree

const COMPOSITION_SCENE := "res://scenes/runtime/FinalSettlementRuntimeComposition.tscn"
const BENCH_SCENE := "res://scenes/tools/FinalSettlementRuntimeCompositionV06Bench.tscn"

const RETIRED_MAIN_SYMBOLS := [
	"_open_final_settlement_menu",
	"_populate_final_settlement_summary_cards",
	"_add_final_settlement_board_panel",
	"_final_settlement_public_facts",
	"_final_settlement_public_snapshot",
	"_on_final_settlement_action_requested",
	"_final_settlement_public_summary_text",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var composition_packed := load(COMPOSITION_SCENE) as PackedScene
	var bench_packed := load(BENCH_SCENE) as PackedScene
	_expect(composition_packed != null and bench_packed != null, "production composition and dedicated bench load")
	var composition := composition_packed.instantiate() if composition_packed != null else null
	_expect(composition != null and composition.has_method("present") and composition.has_method("compose_public_source") and composition.has_method("compose_public_snapshot") and composition.has_method("latest_public_summary"), "composition exposes the narrow public presentation API")
	_expect(composition != null and composition.get_node_or_null("FinalSettlementPublicSourceAdapter") != null and composition.get_node_or_null("FinalSettlementBoardPanel") != null, "composition statically owns one source adapter and one board")
	if composition != null:
		var debug: Dictionary = composition.call("debug_snapshot")
		_expect(not bool(debug.get("owns_victory_rules", true)) and not bool(debug.get("owns_cash", true)) and not bool(debug.get("reads_raw_players", true)) and not bool(debug.get("reads_internal_receipt", true)), "composition declares no Victory, cash, or private-source ownership")
		composition.free()
	var main_scene_source := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(main_scene_source.count("[node name=\"FinalSettlementRuntimeComposition\"") == 1 and main_scene_source.contains("FinalSettlementRuntimeComposition.tscn"), "main scene composes exactly one runtime composition node")
	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var main := main_packed.instantiate() if main_packed != null else null
	var production_composition := main.get_node_or_null("RuntimeServices/FinalSettlementRuntimeComposition") if main != null else null
	_expect(production_composition != null and production_composition.scene_file_path == COMPOSITION_SCENE and production_composition.has_method("present"), "real main exposes the production composition node and API")
	if main != null:
		main.free()
	var retired := true
	for symbol in RETIRED_MAIN_SYMBOLS:
		retired = retired and not main_source.contains("func %s(" % symbol)
	_expect(retired and not main_source.contains("FinalSettlementBoardScene"), "main has no retired final settlement builders, formatters, or dynamic board preload")
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("FINAL_SETTLEMENT_RUNTIME_COMPOSITION_V06_TEST|status=%s|checks=%d|failures=%d|notes=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
