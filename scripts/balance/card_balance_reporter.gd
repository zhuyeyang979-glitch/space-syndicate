extends RefCounted
class_name CardBalanceReporter

const ANALYZER_SCRIPT := preload("res://scripts/balance/card_balance_analyzer.gd")


func generate_report() -> String:
	var analyzer: Variant = ANALYZER_SCRIPT.new()
	var result: Dictionary = analyzer.call("analyze")
	var lines: Array[String] = []
	lines.append("# Balance Report v1")
	lines.append("")
	lines.append("This report is advisory for the Hearthstone-grade vertical slice. It does not modify global card data.")
	lines.append("")
	_append_rows(lines, "价格过低 Top 20", result.get("price_too_low_top20", []))
	_append_rows(lines, "价格过高 Top 20", result.get("price_too_high_top20", []))
	_append_anomalies(lines, "Rank I-IV 梯度异常", result.get("rank_gradient_anomalies", []))
	_append_rows(lines, "首局剧本推荐卡", result.get("first_table_recommendations", []))
	_append_rows(lines, "不适合首局剧本的复杂卡", result.get("complexity_exclusions", []))
	return "\n".join(lines) + "\n"


func save_report(path: String = "res://docs/balance_report.md") -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(generate_report())
	return true


func _append_rows(lines: Array[String], heading: String, rows_variant: Variant) -> void:
	lines.append("## %s" % heading)
	lines.append("")
	lines.append("| Card ID | 名称 | 类型 | Rank | 当前 | 建议 | 差值 | 强度 | 复杂度 | 隐藏 | 经济 | 怪兽 | 互动 | 上手 | 剧本 |")
	lines.append("| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
	var rows: Array = rows_variant if rows_variant is Array else []
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant as Dictionary
		var tags: Array = row.get("scenario_fit", []) if row.get("scenario_fit", []) is Array else []
		lines.append("| %s | %s | %s | %s | %d | %d | %+d | %d | %d | %d | %d | %d | %d | %s | %s |" % [
			str(row.get("card_id", "")),
			str(row.get("name", "")),
			str(row.get("type", "")),
			str(row.get("rank", "")),
			int(row.get("current_price", 0)),
			int(row.get("suggested_price", 0)),
			int(row.get("delta", 0)),
			int(row.get("power_score", 0)),
			int(row.get("complexity_score", 0)),
			int(row.get("hidden_info_score", 0)),
			int(row.get("economy_impact_score", 0)),
			int(row.get("monster_impact_score", 0)),
			int(row.get("interaction_score", 0)),
			str(row.get("onboarding_difficulty", "")),
			", ".join(tags),
		])
	lines.append("")


func _append_anomalies(lines: Array[String], heading: String, anomalies_variant: Variant) -> void:
	lines.append("## %s" % heading)
	lines.append("")
	var anomalies: Array = anomalies_variant if anomalies_variant is Array else []
	if anomalies.is_empty():
		lines.append("- No hard rank-gradient drops in the current vertical-slice set.")
	else:
		for anomaly_variant in anomalies:
			if anomaly_variant is Dictionary:
				var anomaly: Dictionary = anomaly_variant as Dictionary
				lines.append("- `%s`: %s" % [str(anomaly.get("card_id", "")), str(anomaly.get("issue", ""))])
	lines.append("")
