extends PanelContainer

var _diagnostics_service: GameplayBalanceDiagnosticsRuntimeService

@onready var title_label: Label = %DeveloperBalanceTitle
@onready var summary_label: Label = %DeveloperBalanceSummary
@onready var issue_label: Label = %DeveloperBalanceIssues


func set_report(report: Dictionary) -> void:
	var summary: Dictionary = report.get("summary", {}) if report.get("summary", {}) is Dictionary else {}
	var constraints: Dictionary = report.get("constraints", {}) if report.get("constraints", {}) is Dictionary else {}
	if title_label != null:
		title_label.text = "DEV BALANCE HUB｜%s" % String(report.get("version", "unknown"))
	if summary_label != null:
		summary_label.text = "局长 %.0f-%.0f 分｜卡%d｜商品%d｜怪兽%d｜AI路线%d｜环境%d档" % [
			float(summary.get("target_min_minutes", 30.0)),
			float(summary.get("target_max_minutes", 60.0)),
			int(summary.get("card_vector_count", 0)),
			int(summary.get("product_count", 0)),
			int(summary.get("monster_family_count", 0)),
			int(summary.get("ai_route_count", 0)),
			int(summary.get("environment_depth_count", 0)),
		]
	if issue_label != null:
		var issue_count := int(constraints.get("issue_count", 0))
		var status_text := "PASS"
		if issue_count > 0:
			status_text = "ISSUES %d" % issue_count
		issue_label.text = "约束：%s" % status_text
		var issue_lines := []
		if constraints.get("issues", []) is Array:
			for issue_variant in constraints.get("issues", []):
				issue_lines.append(String(issue_variant))
		issue_label.tooltip_text = "\n".join(issue_lines)


func set_diagnostics_service(service: GameplayBalanceDiagnosticsRuntimeService) -> void:
	_diagnostics_service = service


func refresh_report(sample_only := true) -> void:
	if _diagnostics_service == null:
		return
	set_report(_diagnostics_service.build_developer_panel_snapshot({}, sample_only))
