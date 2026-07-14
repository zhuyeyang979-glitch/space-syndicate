@tool
extends Node
class_name FinalSettlementPublicSourceAdapter

const ADAPTER_ID := "final_settlement_public_source_adapter_v06"


func compose_public_source(facts: Dictionary) -> Dictionary:
	if not _is_pure_data(facts):
		return _invalid_source("public_source_not_pure_data")
	var victory_public := _dictionary(facts.get("victory_public_snapshot", {}))
	var public_receipt := _public_outcome_receipt(victory_public)
	if public_receipt.is_empty():
		return _invalid_source("public_outcome_receipt_missing")
	var participants := _participants_by_index(facts.get("participant_public_facts", []))
	var rank_entries: Array = []
	var money_source_entries: Array = []
	for rank_index in range((_array(public_receipt.get("rankings", []))).size()):
		var ranking := _dictionary((_array(public_receipt.get("rankings", [])))[rank_index])
		var player_index := int(ranking.get("player_index", -1))
		if player_index < 0:
			continue
		var participant := _dictionary(participants.get(str(player_index), {}))
		var shared := {
			"rank": rank_index,
			"player_index": player_index,
			"name": str(participant.get("name", "玩家%d" % (player_index + 1))),
			"top_n_gdp_per_minute": int(ranking.get("top_n_gdp_per_minute", ranking.get("top_k_gdp_per_minute", 0))),
			"controlled_region_count": int(ranking.get("controlled_region_count", 0)),
			"winner": bool(ranking.get("winner", false)),
			"active_cities": int(participant.get("active_cities", 0)),
			"gdp_per_minute": int(participant.get("gdp_per_minute", 0)),
			"city_income": int(participant.get("city_income", 0)),
			"card_income": int(participant.get("card_income", 0)),
			"role_income": int(participant.get("role_income", 0)),
			"card_spend": int(participant.get("card_spend", 0)),
			"build_spend": int(participant.get("build_spend", 0)),
			"business_spend": int(participant.get("business_spend", 0)),
			"identity": str(participant.get("identity", "公开经济路线")),
			"eliminated": bool(participant.get("eliminated", false)),
		}
		if str(ranking.get("cash_visibility", "")) == "public_audit" and ranking.has("cash_ledger_cents"):
			shared["cash_visibility"] = "public_audit"
			shared["cash_ledger_cents"] = int(ranking.get("cash_ledger_cents", 0))
		rank_entries.append(shared.duplicate(true))
		money_source_entries.append(shared.duplicate(true))
	var winner_names := _winner_names(public_receipt, participants)
	return {
		"valid": true,
		"reason": str(facts.get("reason", _reason_label(str(public_receipt.get("reason_code", ""))))),
		"winner_names": winner_names,
		"co_victory": bool(public_receipt.get("co_victory", winner_names.size() > 1)),
		"cash_visibility": str(public_receipt.get("cash_visibility", "hidden")),
		"audit_revealed_player_indices": _array(public_receipt.get("audit_revealed_player_indices", [])).duplicate(),
		"required_top_n_gdp_per_minute": int(facts.get("required_top_n_gdp_per_minute", 0)),
		"required_controlled_region_count": int(facts.get("required_controlled_region_count", 0)),
		"comparison_order": _array(public_receipt.get("comparison_order", [])).duplicate(),
		"outcome_receipt": public_receipt,
		"top_city_income_name": str(facts.get("top_city_income_name", "")),
		"top_city_income_amount": int(facts.get("top_city_income_amount", 0)),
		"top_card_income_name": str(facts.get("top_card_income_name", "")),
		"top_card_income_amount": int(facts.get("top_card_income_amount", 0)),
		"top_role_income_name": str(facts.get("top_role_income_name", "")),
		"top_role_income_amount": int(facts.get("top_role_income_amount", 0)),
		"top_card_impact": str(facts.get("top_card_impact", "")),
		"monster_impact": str(facts.get("monster_impact", "")),
		"resolved_card_count": int(facts.get("resolved_card_count", 0)),
		"map_facts": _public_map_facts(_dictionary(facts.get("map_facts", {}))),
		"money_source_entries": money_source_entries,
		"rank_entries": rank_entries,
		"kpi_columns": int(facts.get("kpi_columns", 4)),
		"money_columns": int(facts.get("money_columns", 4)),
		"rank_columns": int(facts.get("rank_columns", 4)),
	}


func compose_public_summary(facts: Dictionary) -> String:
	var source := compose_public_source(facts)
	if not bool(source.get("valid", false)):
		return "终局总结：没有可用的公开胜利结果。"
	var lines: Array[String] = []
	var winners := _string_array(source.get("winner_names", []))
	lines.append("终局总结：%s获胜；比较顺序为前K区商品GDP、控制区域数、现金并列判定，准确现金数值保密。" % ("、".join(winners) if not winners.is_empty() else "无人"))
	lines.append("钱从哪里来：城市经营最高%s累计¥%d；卡牌/情报收益最高%s累计¥%d；角色收益最高%s累计¥%d。" % [
		str(source.get("top_city_income_name", "")), int(source.get("top_city_income_amount", 0)),
		str(source.get("top_card_income_name", "")), int(source.get("top_card_income_amount", 0)),
		str(source.get("top_role_income_name", "")), int(source.get("top_role_income_amount", 0)),
	])
	var map_facts := _dictionary(source.get("map_facts", {}))
	lines.append("地图影响：存活城市%d座，已毁区域%d个，怪兽在场%d/%d；破坏和商路损伤最终都会反映到GDP变化。" % [
		int(map_facts.get("active_city_count", 0)), int(map_facts.get("destroyed_district_count", 0)),
		int(map_facts.get("active_monster_count", 0)), int(map_facts.get("monster_count", 0)),
	])
	for key in ["top_card_impact", "monster_impact"]:
		var line := str(source.get(key, "")).strip_edges()
		if not line.is_empty():
			lines.append(line)
	lines.append("公开线索：复盘只显示已经发生的卡牌、城市GDP、商路、怪兽和情报结果。")
	var audit_cash_pieces: Array[String] = []
	for entry_variant in _array(source.get("rank_entries", [])):
		var entry := _dictionary(entry_variant)
		if str(entry.get("cash_visibility", "")) == "public_audit" and entry.has("cash_ledger_cents"):
			audit_cash_pieces.append("%s ¥%.2f" % [str(entry.get("name", "玩家")), float(int(entry.get("cash_ledger_cents", 0))) / 100.0])
	if not audit_cash_pieces.is_empty():
		lines.append("终局审计公开现金：%s；未进入权威审计名单的席位准确现金继续保密。" % "、".join(audit_cash_pieces))
	lines.append(_participant_breakdown(_array(source.get("rank_entries", []))))
	var key_city := _dictionary(map_facts.get("key_city", {}))
	if bool(key_city.get("valid", false)):
		lines.append("关键城市：%s（%s）末期GDP¥%d，供:%s，需:%s。" % [
			str(key_city.get("name", "关键城市")), str(key_city.get("owner_name", "公开归属")), int(key_city.get("last_income", 0)),
			", ".join(_string_array(key_city.get("products", []))) if not _string_array(key_city.get("products", [])).is_empty() else "无",
			", ".join(_string_array(key_city.get("demands", []))) if not _string_array(key_city.get("demands", [])).is_empty() else "无",
		])
	return "\n".join(lines)


func public_outcome_log_payload(victory_public_snapshot: Dictionary, participant_names: Dictionary) -> Dictionary:
	if not _is_pure_data(victory_public_snapshot) or not _is_pure_data(participant_names):
		return {"accepted": false, "reason": "victory_outcome_not_pure_data", "entries": []}
	var public_receipt := _public_outcome_receipt(victory_public_snapshot)
	var outcome_id := str(public_receipt.get("outcome_id", "")).strip_edges()
	var rankings := _array(public_receipt.get("rankings", []))
	var winner_indices := _array(public_receipt.get("winner_player_indices", []))
	if outcome_id.is_empty() or rankings.is_empty() or not public_receipt.has("winner_player_indices"):
		return {"accepted": false, "reason": "victory_outcome_invalid", "entries": []}
	var reason := _reason_label(str(public_receipt.get("reason_code", "")))
	var winner_names: Array[String] = []
	for player_index_variant in winner_indices:
		var winner_name := str(participant_names.get(str(int(player_index_variant)), "")).strip_edges()
		if not winner_name.is_empty():
			winner_names.append(winner_name)
	var entries: Array[String] = [
		"游戏结束：%s。" % reason,
		"胜者：%s。比较顺序为前K区商品GDP/min、控制区域数、现金并列判定；准确现金数值保密。" % ("、".join(winner_names) if not winner_names.is_empty() else "无人"),
	]
	for rank_index in range(rankings.size()):
		var ranking := _dictionary(rankings[rank_index])
		var player_index := int(ranking.get("player_index", -1))
		if player_index < 0:
			continue
		var cash_copy := "审计现金¥%.2f。" % (float(int(ranking.get("cash_ledger_cents", 0))) / 100.0) if str(ranking.get("cash_visibility", "")) == "public_audit" and ranking.has("cash_ledger_cents") else "现金仅作最终并列判定；未获审计授权时数值保密。"
		entries.append("#%d %s：前K区GDP/min %d｜控制区域 %d｜%s" % [
			rank_index + 1,
			str(participant_names.get(str(player_index), "玩家%d" % (player_index + 1))),
			int(ranking.get("top_n_gdp_per_minute", ranking.get("top_k_gdp_per_minute", 0))),
			int(ranking.get("controlled_region_count", 0)),
			cash_copy,
		])
	return {"accepted": true, "reason": "", "reason_label": reason, "outcome_id": outcome_id, "entries": entries}


func sanitize_public_log_entries(entries: Array) -> Array:
	var result: Array = []
	for entry_variant in entries:
		var line := str(entry_variant)
		if line.contains("｜准确现金 ") or line.contains("｜现金¥"):
			continue
		result.append(line)
	return result


func debug_snapshot() -> Dictionary:
	return {
		"adapter_id": ADAPTER_ID,
		"pure_data_only": true,
		"owns_victory_rules": false,
		"owns_cash": false,
		"owns_rankings": false,
		"exposes_exact_cash": false,
	}


func _public_outcome_receipt(victory_public_snapshot: Dictionary) -> Dictionary:
	var source := _dictionary(victory_public_snapshot.get("outcome_receipt", {}))
	if str(source.get("outcome_id", "")).strip_edges().is_empty() or not source.get("rankings", []) is Array:
		return {}
	var revealed_cash_by_player := _authorized_audit_cash_by_player(victory_public_snapshot)
	var rankings: Array = []
	for ranking_variant in source.get("rankings", []):
		var ranking := _dictionary(ranking_variant)
		var player_index := int(ranking.get("player_index", -1))
		if player_index < 0:
			continue
		var public_ranking := {
			"player_index": player_index,
			"top_k_gdp_per_minute_cents": int(ranking.get("top_k_gdp_per_minute_cents", 0)),
			"top_k_gdp_per_minute": int(ranking.get("top_k_gdp_per_minute", ranking.get("top_n_gdp_per_minute", 0))),
			"top_n_gdp_per_minute": int(ranking.get("top_n_gdp_per_minute", ranking.get("top_k_gdp_per_minute", 0))),
			"controlled_region_count": int(ranking.get("controlled_region_count", 0)),
			"winner": bool(ranking.get("winner", false)),
		}
		if revealed_cash_by_player.has(str(player_index)):
			public_ranking["cash_visibility"] = "public_audit"
			public_ranking["cash_ledger_cents"] = int(revealed_cash_by_player[str(player_index)])
		rankings.append(public_ranking)
	return {
		"outcome_id": str(source.get("outcome_id", "")),
		"schema_version": str(source.get("schema_version", "")),
		"ruleset_id": str(source.get("ruleset_id", "")),
		"reason_code": str(source.get("reason_code", "")),
		"winner_player_indices": _array(source.get("winner_player_indices", [])).duplicate(),
		"co_victory": bool(source.get("co_victory", false)),
		"comparison_order": _array(source.get("comparison_order", [])).duplicate(),
		"rankings": rankings,
		"cash_visibility": "public_audit" if not revealed_cash_by_player.is_empty() else "hidden",
		"audit_revealed_player_indices": _authorized_audit_player_indices(victory_public_snapshot),
		"visibility_scope": "public",
	}


func _authorized_audit_cash_by_player(victory_public_snapshot: Dictionary) -> Dictionary:
	var result := {}
	if str(victory_public_snapshot.get("cash_visibility", "")) != "public_audit":
		return result
	var authorized := {}
	for player_index_variant in _array(victory_public_snapshot.get("audit_revealed_player_indices", [])):
		var player_index := int(player_index_variant)
		if player_index >= 0:
			authorized[str(player_index)] = true
	for entry_variant in _array(victory_public_snapshot.get("audit_entries", [])):
		var entry := _dictionary(entry_variant)
		var player_index := int(entry.get("player_index", -1))
		if player_index >= 0 and authorized.has(str(player_index)) and entry.has("cash_ledger_cents"):
			result[str(player_index)] = int(entry.get("cash_ledger_cents", 0))
	var receipt := _dictionary(victory_public_snapshot.get("outcome_receipt", {}))
	for ranking_variant in _array(receipt.get("rankings", [])):
		var ranking := _dictionary(ranking_variant)
		var player_index := int(ranking.get("player_index", -1))
		if player_index >= 0 and authorized.has(str(player_index)) and ranking.has("cash_ledger_cents"):
			result[str(player_index)] = int(ranking.get("cash_ledger_cents", 0))
	return result


func _authorized_audit_player_indices(victory_public_snapshot: Dictionary) -> Array:
	var result: Array = []
	if str(victory_public_snapshot.get("cash_visibility", "")) != "public_audit":
		return result
	for player_index_variant in _array(victory_public_snapshot.get("audit_revealed_player_indices", [])):
		var player_index := int(player_index_variant)
		if player_index >= 0 and not result.has(player_index):
			result.append(player_index)
	return result


func _participants_by_index(value: Variant) -> Dictionary:
	var result := {}
	for participant_variant in _array(value):
		var participant := _dictionary(participant_variant)
		var player_index := int(participant.get("player_index", -1))
		if player_index >= 0:
			result[str(player_index)] = participant
	return result


func _winner_names(receipt: Dictionary, participants: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for player_index_variant in _array(receipt.get("winner_player_indices", [])):
		var player_index := int(player_index_variant)
		var participant := _dictionary(participants.get(str(player_index), {}))
		var player_name := str(participant.get("name", "玩家%d" % (player_index + 1))).strip_edges()
		if not player_name.is_empty():
			result.append(player_name)
	return result


func _participant_breakdown(entries: Array) -> String:
	var pieces: Array[String] = []
	for entry_variant in entries:
		var entry := _dictionary(entry_variant)
		var audit_cash := "｜审计现金¥%.2f" % (float(int(entry.get("cash_ledger_cents", 0))) / 100.0) if str(entry.get("cash_visibility", "")) == "public_audit" and entry.has("cash_ledger_cents") else ""
		pieces.append("#%d %s｜前K区GDP %d/min｜控区%d｜城收¥%d｜卡牌¥%d｜%s%s" % [
			int(entry.get("rank", pieces.size())) + 1,
			str(entry.get("name", "玩家")),
			int(entry.get("top_n_gdp_per_minute", 0)),
			int(entry.get("controlled_region_count", 0)),
			int(entry.get("city_income", 0)),
			int(entry.get("card_income", 0)),
			str(entry.get("identity", "公开经济路线")),
			audit_cash,
		])
	return "玩家概览：%s。准确现金只对权威审计名单公开，其他席位继续保密。" % "；".join(pieces) if not pieces.is_empty() else "玩家概览：没有可显示玩家。"


func _public_map_facts(source: Dictionary) -> Dictionary:
	var key_city_source := _dictionary(source.get("key_city", {}))
	var key_city := {"valid": false}
	if bool(key_city_source.get("valid", false)):
		key_city = {
			"valid": true,
			"name": str(key_city_source.get("name", "关键城市")),
			"owner_name": str(key_city_source.get("owner_name", "公开归属")),
			"last_income": int(key_city_source.get("last_income", 0)),
			"products": _string_array(key_city_source.get("products", [])),
			"demands": _string_array(key_city_source.get("demands", [])),
		}
	return {
		"active_city_count": int(source.get("active_city_count", 0)),
		"destroyed_district_count": int(source.get("destroyed_district_count", 0)),
		"active_monster_count": int(source.get("active_monster_count", 0)),
		"monster_count": int(source.get("monster_count", 0)),
		"key_city": key_city,
	}


func _invalid_source(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}


func _reason_label(reason_code: String) -> String:
	return {
		"public_audit_complete": "公开审计完成",
		"last_survivor": "仅剩一名未淘汰玩家",
		"planet_destroyed": "星球毁灭结算",
	}.get(reason_code, "胜利条件已结算") as String


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for item_variant in _array(value):
		result.append(str(item_variant))
	return result


func _is_pure_data(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true
