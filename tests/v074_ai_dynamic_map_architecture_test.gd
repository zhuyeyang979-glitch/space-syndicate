extends SceneTree

const ADAPTER_PATH := (
	"res://scripts/v074/ai/v074_dynamic_map_ai_observation_adapter.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(ADAPTER_PATH)
	_check(not source.is_empty(), "adapter source readable")
	_check(
		source.contains("class_name V074AIDynamicMapAdapter"),
		"integration class name exposed"
	)
	_check(
		source.contains("func adapt(
	actor_id: String,
	map_receipt: Dictionary,"),
		"plain Dictionary integration API exposed"
	)
	_check(
		source.contains("func indexed_legal_targets_for_card("),
		"indexed card query exposed"
	)
	_check(
		source.contains("func debug_snapshot() -> Dictionary:"),
		"debug counters exposed"
	)
	_check(
		source.contains("func validation_counters() -> Dictionary:"),
		"validation counters exposed"
	)
	_check(
		source.contains(
			'const FACILITY_TYPES := ["factory", "market", "warehouse"]'
		),
		"complete facility registry consumed"
	)
	_check(
		not source.contains('["factory", "market"]'),
		"no factory-market-only registry"
	)
	for retired_id in [
		"region.alpha",
		"region.beta",
		"region.gamma",
		"region.delta",
		"region.epsilon",
		"region.zeta",
	]:
		_check(
			not source.contains(retired_id),
			"no retired production id %s" % retired_id
		)
	for forbidden_api in [
		"RandomNumberGenerator",
		"randf(",
		"randi(",
		"seed(",
		"Time.",
		"scripts/main.gd",
	]:
		_check(
			not source.contains(forbidden_api),
			"adapter excludes %s" % forbidden_api
		)
	var query_start := source.find(
		"func indexed_legal_targets_for_card("
	)
	var query_end := source.find(
		"

func indexed_slots_for_facility(",
		query_start
	)
	var query_source := source.substr(
		query_start,
		query_end - query_start
	) if query_start >= 0 and query_end > query_start else ""
	_check(
		not query_source.contains("
	for "),
		"indexed legal-target query contains no scan loop"
	)
	_check(
		not query_source.contains("public_facility_slots"),
		"indexed legal-target query never touches full slot list"
	)
	_check(
		source.contains('"query_full_slot_scan_count": 0'),
		"zero-scan debug counter is explicit"
	)
	var passed := _failures.is_empty()
	print(
		"V074_AI_DYNAMIC_MAP_ARCHITECTURE_TEST"
		+ "|status=%s|passed=%d|total=%d|details=%s" % [
			"PASS" if passed else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if passed else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)