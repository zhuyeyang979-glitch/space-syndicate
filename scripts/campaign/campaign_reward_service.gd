extends RefCounted
class_name CampaignRewardService

const UNLOCKS_SCRIPT := preload("res://scripts/campaign/campaign_unlocks.gd")
const REWARD_SCRIPT := preload("res://scripts/campaign/campaign_reward.gd")


func build_reward(campaign: Dictionary, chapter: Dictionary, progress: Dictionary, stats: Dictionary = {}) -> Dictionary:
	var completed_ids: Array = progress.get("completed_chapter_ids", []) if progress.get("completed_chapter_ids", []) is Array else []
	var reward: Dictionary = chapter.get("reward", {}) if chapter.get("reward", {}) is Dictionary else {}
	var objectives: Array = chapter.get("objectives", []) if chapter.get("objectives", []) is Array else []
	var next_id := str(reward.get("unlock_chapter", progress.get("next_chapter_id", ""))).strip_edges()
	var packet := {
		"campaign_id": str(campaign.get("id", "")),
		"chapter_id": str(chapter.get("id", "")),
		"title": "%s 完成" % str(chapter.get("title", "关卡")),
		"badge": str(reward.get("badge", "完成")),
		"score": _score_from_stats(stats, objectives.size()),
		"time_text": str(stats.get("time_text", stats.get("elapsed_text", "约%d分钟" % int(chapter.get("estimated_minutes", 5))))),
		"objectives_completed": int(stats.get("objectives_completed", objectives.size())),
		"objectives_total": maxi(1, int(stats.get("objectives_total", objectives.size()))),
		"errors": int(stats.get("errors", 0)),
		"hints": int(stats.get("hints", 0)),
		"unlocks": UNLOCKS_SCRIPT.new().collect_reward_unlocks(chapter),
		"next_chapter_id": next_id,
		"next_label": "继续下一关" if next_id != "" and not completed_ids.has(next_id) else "回到战役",
	}
	return REWARD_SCRIPT.new().apply_dictionary(packet).to_dictionary()


func build_recap(campaign: Dictionary, chapter: Dictionary, action_entries: Array = [], stats: Dictionary = {}) -> Dictionary:
	var teaches: Array = chapter.get("teaches", []) if chapter.get("teaches", []) is Array else []
	var objectives: Array = chapter.get("objectives", []) if chapter.get("objectives", []) is Array else []
	return {
		"campaign_id": str(campaign.get("id", "")),
		"chapter_id": str(chapter.get("id", "")),
		"title": "复盘｜%s" % str(chapter.get("title", "关卡")),
		"learned": _short_array(teaches, 5),
		"key_actions": _public_action_summaries(action_entries, 8),
		"economy_cards": _economy_cards(stats),
		"suggestions": _suggestions_for(chapter, stats, objectives),
		"checkpoint_actions": [
			{"id": "scenario_replay_start", "label": "起点"},
			{"id": "scenario_replay_after_select", "label": "选区后"},
			{"id": "scenario_replay_after_play", "label": "出牌后"},
		],
	}


func _score_from_stats(stats: Dictionary, objective_total: int) -> int:
	var score := 3
	if int(stats.get("errors", 0)) <= 1:
		score += 1
	if int(stats.get("hints", 0)) <= 1 and int(stats.get("objectives_completed", objective_total)) >= objective_total:
		score += 1
	return clampi(score, 1, 5)


func _public_action_summaries(entries: Array, limit: int) -> Array:
	var result: Array = []
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var public_text := str(entry.get("public_text", "")).strip_edges()
		if public_text == "":
			continue
		result.append("%s  %s" % [str(entry.get("time", "--:--")), public_text])
		if result.size() >= limit:
			break
	return result


func _economy_cards(stats: Dictionary) -> Array:
	var economy: Dictionary = stats.get("economy", {}) if stats.get("economy", {}) is Dictionary else {}
	var cash_delta := int(economy.get("cash_delta", stats.get("cash_delta", 0)))
	var final_cash := int(economy.get("final_cash", stats.get("final_cash", 0)))
	var gdp_per_min := int(economy.get("gdp_per_min", stats.get("gdp_per_min", 0)))
	var city_count := int(economy.get("city_count", stats.get("city_count", 0)))
	var total_income := int(economy.get("total_income", stats.get("total_income", 0)))
	var total_spend := int(economy.get("total_spend", stats.get("total_spend", 0)))
	var top_city := str(economy.get("top_city", stats.get("top_city", ""))).strip_edges()
	var pressure := int(economy.get("pressure", stats.get("pressure", 0)))
	var cash_title := "现金 %s" % _signed_cash_text(cash_delta) if cash_delta != 0 else "现金 ¥%d" % final_cash
	var gdp_title := "%d城｜GDP/min %d" % [city_count, gdp_per_min]
	var spend_title := "投入 ¥%d" % total_spend
	var pressure_title := "压力 %d" % pressure if pressure > 0 else "压力低"
	if top_city == "":
		top_city = "先让一座城市跑起来"
	return [
		{
			"kind": "cash",
			"kicker": "现金",
			"title": _short_text(cash_title, 18),
			"detail": "本席最终¥%d；最后仍按现金排名。" % final_cash,
		},
		{
			"kind": "gdp",
			"kicker": "城市/GDP",
			"title": _short_text(gdp_title, 18),
			"detail": "主要看生产、需求、运输和损伤。",
		},
		{
			"kind": "spend",
			"kicker": "投入",
			"title": _short_text(spend_title, 18),
			"detail": "收入¥%d；买牌/建城要留缓冲。" % total_income,
		},
		{
			"kind": "pressure",
			"kicker": "下局抓手",
			"title": _short_text(top_city, 18),
			"detail": "%s；看怪兽、断路和商品竞争。" % pressure_title,
		},
	]


func _suggestions_for(chapter: Dictionary, stats: Dictionary, objectives: Array) -> Array:
	var suggestions: Array = []
	if int(stats.get("hints", 0)) > 1:
		suggestions.append("下次先看当前目标按钮，再打开详情。")
	if int(stats.get("errors", 0)) > 0:
		suggestions.append("动作失败时先看右侧原因，再决定是否换目标。")
	if suggestions.is_empty():
		var objective_text := str(objectives[0]) if not objectives.is_empty() else "保持现金流"
		suggestions.append("继续练习：%s。" % objective_text)
		suggestions.append("尝试更早建立城市，保留现金缓冲。")
	return suggestions


func _signed_cash_text(amount: int) -> String:
	if amount > 0:
		return "+¥%d" % amount
	if amount < 0:
		return "-¥%d" % abs(amount)
	return "¥0"


func _short_text(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return "%s…" % text.left(maxi(1, limit - 1))


func _short_array(value: Array, limit: int) -> Array:
	var result: Array = []
	for item in value:
		var text := str(item).strip_edges()
		if text != "":
			result.append(text)
		if result.size() >= limit:
			break
	return result
