extends RefCounted
class_name ScenarioFixtureFactory

const LOADER_SCRIPT := preload("res://scripts/scenarios/scenario_loader.gd")


func make_fixture(scenario_id: String, snapshot_key: String = "start") -> Dictionary:
	var scenario := LOADER_SCRIPT.new().load_by_id(scenario_id)
	if scenario.is_empty():
		return {}
	var fixture: Dictionary = scenario.get("fixture", {}) if scenario.get("fixture", {}) is Dictionary else {}
	var visual_events := _visual_events_fixture(scenario_id, snapshot_key)
	return {
		"scenario_id": scenario_id,
		"stage_id": "%s_%s_runtime_fixture" % [scenario_id, snapshot_key],
		"snapshot_key": snapshot_key,
		"title": str(scenario.get("title", scenario_id)),
		"inspector": str(fixture.get("public_summary", "")),
		"scenario": scenario,
		"coach": _coach_fixture(scenario, snapshot_key),
		"action_log": _log_fixture(scenario, snapshot_key),
		"table_state": _table_state_fixture(scenario_id, fixture, snapshot_key),
		"replay": _replay_fixture(scenario, snapshot_key),
		"visual_events": visual_events,
	}


func _coach_fixture(scenario: Dictionary, snapshot_key: String) -> Dictionary:
	var phases: Array = scenario.get("phases", []) if scenario.get("phases", []) is Array else []
	var index := 0
	for i in range(phases.size()):
		var phase: Dictionary = phases[i] if phases[i] is Dictionary else {}
		if str(phase.get("snapshot_key", phase.get("id", ""))) == snapshot_key:
			index = i
			break
	var phase_data: Dictionary = phases[index] if index >= 0 and index < phases.size() and phases[index] is Dictionary else {}
	return {
		"scenario_id": str(scenario.get("id", "")),
		"title": str(scenario.get("title", "")),
		"current_index": index,
		"total": phases.size(),
		"current_phase": phase_data,
		"completed": false,
		"closed_to_chip": false,
	}


func _log_fixture(scenario: Dictionary, snapshot_key: String) -> Dictionary:
	var title := str(scenario.get("title", "试玩剧本"))
	return {
		"scenario_id": str(scenario.get("id", "")),
		"title": "%s｜行动日志" % title,
		"entries": [
			{"time": "00:00", "phase_id": "start", "public_text": "开始剧本：%s" % title, "private_text": "", "developer_text": "fixture:%s" % snapshot_key, "snapshot_key": "start", "focus_target": "scenario_coach"},
		],
	}


func _table_state_fixture(scenario_id: String, fixture: Dictionary, snapshot_key: String) -> Dictionary:
	return {
		"id": scenario_id,
		"snapshot_key": snapshot_key,
		"privacy": "current_player_only",
		"public_summary": str(fixture.get("public_summary", "")),
		"focus": str(fixture.get("focus", scenario_id)),
		"has_public_track": bool(fixture.get("has_public_track", scenario_id in ["public_track_intro", "bid_practice", "intel_guess"])),
		"has_bid_board": bool(fixture.get("has_bid_board", scenario_id == "bid_practice")),
		"has_monster_pressure": bool(fixture.get("has_monster_pressure", scenario_id == "monster_pressure")),
		"has_final_countdown": bool(fixture.get("has_final_countdown", scenario_id == "final_countdown")),
	}


func _replay_fixture(scenario: Dictionary, snapshot_key: String) -> Dictionary:
	var snapshots: Array = scenario.get("replay_snapshots", []) if scenario.get("replay_snapshots", []) is Array else []
	return {
		"scenario_id": str(scenario.get("id", "")),
		"title": str(scenario.get("title", "")),
		"current_snapshot": snapshot_key,
		"snapshots": snapshots,
	}


func _visual_events_fixture(scenario_id: String, snapshot_key: String) -> Array:
	match scenario_id:
		"monster_pressure":
			return [
				{"type": "monster_move_trail", "from": [500, 360], "to": [665, 405], "label": "怪兽逼近", "reason": "自动目标权重指向高 GDP 城市", "duration": 0.9},
				{"type": "monster_attack_windup", "from": [665, 405], "to": [725, 420], "label": "蓄力", "reason": "攻击前摇公开可见", "duration": 0.7},
				{"type": "monster_attack_impact", "from": [665, 405], "to": [725, 420], "label": "撞击城市", "reason": "城市受损会压低 GDP", "duration": 0.8},
				{"type": "city_damage_crack", "at": [725, 420], "label": "城市 -18 HP", "reason": "破坏反馈到收入", "duration": 0.9},
				{"type": "gdp_delta_float", "at": [760, 380], "label": "GDP -12", "reason": "城市损伤与路线压力", "duration": 1.0},
				{"type": "cash_gain_float", "at": [910, 150], "label": "预计现金 -35", "reason": "下个结算窗口的公开估算", "duration": 0.9},
			]
		"public_track_intro":
			return [
				{"type": "card_reveal_flash", "from": [520, 86], "to": [640, 86], "label": "匿名牌公开", "reason": "牌轨只公开牌和条件", "duration": 0.8},
				{"type": "target_arrow", "from": [640, 120], "to": [905, 245], "label": "查看右侧详情", "reason": "公开线索进入右侧面板", "duration": 0.6},
				{"type": "route_damage_spark", "from": [500, 480], "to": [760, 430], "label": "商路受扰", "reason": "结果公开，但出牌者匿名", "duration": 0.9},
			]
		"bid_practice":
			return [
				{"type": "target_arrow", "from": [770, 720], "to": [930, 640], "label": "最高报价", "reason": "公开金额用于竞价判断", "duration": 0.6},
				{"type": "card_reveal_flash", "from": [555, 84], "to": [680, 84], "label": "候补牌入轨", "reason": "同批出牌等待竞价排序", "duration": 0.8},
				{"type": "cash_gain_float", "at": [940, 620], "label": "+20 小费", "reason": "小费给当前结算牌的匿名玩家", "duration": 0.9},
			]
		"first_table":
			return [
				{"type": "card_play_flyout", "from": [580, 740], "to": [720, 435], "label": "首召怪兽", "reason": "起始怪兽打开附近牌架", "duration": 0.8},
				{"type": "card_reveal_flash", "from": [520, 86], "to": [640, 86], "label": "匿名公开", "reason": "所有人看到牌，不知道是谁打出", "duration": 0.8},
				{"type": "monster_spawn_pulse", "at": [720, 435], "label": "怪兽降落", "reason": "区域周边开始可买牌", "duration": 0.9},
				{"type": "gdp_delta_float", "at": [760, 410], "label": "GDP +18", "reason": "城市化带来现金流", "duration": 1.0},
				{"type": "cash_gain_float", "at": [275, 135], "label": "+120", "reason": "玩家自己的现金变化只给自己看", "duration": 0.9},
			]
	return []
