@tool
extends Resource
class_name DevelopmentRouteProfileResource

@export var route_id := "tactical_support"
@export var display_name := "即时战术"
@export_multiline var goal := "补足当前局势。"
@export_multiline var play_pattern := "按局势选择能转化成现金的行动。"
@export_multiline var counterplay := "观察公开线索，打断它的收益链。"
@export_multiline var ai_plan_hint := "按阶段和现金目标调整权重。"
@export var strategy_labels: Array[String] = []
@export var required_for_ai_baseline := false
@export var sort_order := 0


func to_runtime_dictionary() -> Dictionary:
	return {
		"id": route_id,
		"route_id": route_id,
		"label": display_name,
		"display_name": display_name,
		"goal": goal,
		"play_pattern": play_pattern,
		"counterplay": counterplay,
		"ai_plan_hint": ai_plan_hint,
		"strategy_labels": strategy_labels.duplicate(),
		"required_for_ai_baseline": required_for_ai_baseline,
		"sort_order": sort_order,
	}


func validation_issues() -> Array:
	var issues: Array = []
	if route_id.strip_edges() == "":
		issues.append("route_id_missing")
	if display_name.strip_edges() == "":
		issues.append("display_name_missing")
	if goal.strip_edges() == "":
		issues.append("goal_missing")
	if play_pattern.strip_edges() == "":
		issues.append("play_pattern_missing")
	if counterplay.strip_edges() == "":
		issues.append("counterplay_missing")
	if ai_plan_hint.strip_edges() == "":
		issues.append("ai_plan_hint_missing")
	if strategy_labels.is_empty():
		issues.append("strategy_labels_missing")
	return issues
