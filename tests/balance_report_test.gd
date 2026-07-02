extends SceneTree

const ANALYZER_SCRIPT := preload("res://scripts/balance/card_balance_analyzer.gd")
const REPORTER_SCRIPT := preload("res://scripts/balance/card_balance_reporter.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists("res://data/balance/price_curve_v1.json"), "price_curve_v1 data exists")
	_expect(ResourceLoader.exists("res://data/balance/card_archetypes.json"), "card_archetypes data exists")
	_expect(ResourceLoader.exists("res://data/balance/vertical_slice_card_set.json"), "vertical_slice_card_set data exists")
	var analyzer: Variant = ANALYZER_SCRIPT.new()
	_expect(bool(analyzer.call("load_defaults")), "CardBalanceAnalyzer loads local vertical-slice card data")
	var result: Dictionary = analyzer.call("analyze")
	var low: Array = result.get("price_too_low_top20", []) if result.get("price_too_low_top20", []) is Array else []
	var high: Array = result.get("price_too_high_top20", []) if result.get("price_too_high_top20", []) is Array else []
	var first_table: Array = result.get("first_table_recommendations", []) if result.get("first_table_recommendations", []) is Array else []
	_expect(low.size() >= 10, "balance report emits a meaningful price-too-low Top 20 list")
	_expect(high.size() >= 1, "balance report emits price-too-high anomalies")
	_expect(first_table.size() >= 4, "balance report emits first_table recommended card set")
	for row_variant in low:
		var row: Dictionary = row_variant as Dictionary
		_expect(row.has("card_id") and row.has("suggested_price") and row.has("delta") and row.has("scenario_fit"), "balance row exposes required pricing fields")
	var reporter: Variant = REPORTER_SCRIPT.new()
	var report: String = str(reporter.call("generate_report"))
	_expect(report.contains("价格过低 Top 20") and report.contains("价格过高 Top 20") and report.contains("Rank I-IV 梯度异常") and report.contains("首局剧本推荐卡") and report.contains("不适合首局剧本的复杂卡"), "generated balance_report contains required sections")
	var checked_in_report := FileAccess.get_file_as_string("res://docs/balance_report.md")
	_expect(checked_in_report.contains("价格过低 Top 20") and checked_in_report.contains("首局剧本推荐卡"), "checked-in balance_report is present with required player-facing sections")
	_expect(checked_in_report.contains("does not modify global card data"), "checked-in balance_report explicitly avoids changing global card data")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Balance report test passed.")
		quit(0)
	else:
		printerr("Balance report test failed:")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)
