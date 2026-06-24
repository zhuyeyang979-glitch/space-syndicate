extends Control

const PLAYER_COUNT := 4
const BOARD_COLUMNS := 3
const BET_UNIT := 200
const CHARGE_UNIT := 100
const STARTING_CASH := 2000
const DISTRICT_LIMIT := 2

const ACTIONS := [
	{"id": "first", "name": "起始玩家", "hint": "成为下回合先手。"},
	{"id": "bet1", "name": "下注1", "hint": "向已下注区域追加最多200筹码。"},
	{"id": "skill1", "name": "技能1", "hint": "给技能充能，基础上限300。"},
	{"id": "bet2", "name": "下注2", "hint": "在新区域放置判断指示物并下注。"},
	{"id": "skill2", "name": "技能2", "hint": "从公共技能栏获得一张技能并充能。"},
	{"id": "market", "name": "操控市场", "hint": "给选中区域追加200奖金。"},
	{"id": "bet3", "name": "下注3", "hint": "移动自己的200筹码，或执行下注2。"},
	{"id": "skill3", "name": "技能3", "hint": "支付500开启技能槽并执行技能2。"},
	{"id": "control", "name": "操控怪兽", "hint": "获得怪兽操控权并触发战斗轮。"},
	{"id": "bet4", "name": "下注4", "hint": "移动任意玩家200筹码，或执行下注3。"},
]

const SKILL_CATALOG := {
	"赌怪1": {"cost": 3, "kind": "bet_boost", "damage": 0, "move": 0, "range": 0, "text": "向选中区域额外下注200。"},
	"黑幕1": {"cost": 2, "kind": "market_boost", "damage": 0, "move": 0, "range": 0, "text": "选中区域奖金+200。"},
	"移动1": {"cost": 2, "kind": "move", "damage": 0, "move": 1, "range": 0, "text": "怪兽移动1格，进入区域造成1点区域伤害。"},
	"移动2": {"cost": 4, "kind": "move", "damage": 0, "move": 1, "range": 0, "text": "怪兽移动1格，较高充能版。"},
	"普攻1": {"cost": 2, "kind": "attack", "damage": 1, "move": 0, "range": 1, "text": "近战，对守护者造成1点伤害。"},
	"普攻2": {"cost": 4, "kind": "attack", "damage": 2, "move": 0, "range": 1, "text": "近战，对守护者造成2点伤害。"},
	"普攻3": {"cost": 6, "kind": "attack", "damage": 3, "move": 0, "range": 1, "text": "近战，对守护者造成3点伤害。"},
	"区域破坏1": {"cost": 2, "kind": "area_damage", "damage": 1, "move": 0, "range": 1, "text": "对相邻或所在区域造成1点伤害。"},
	"飞行1": {"cost": 3, "kind": "fly", "damage": 0, "move": 5, "range": 0, "text": "飞行移动到选中区域，忽略区域阻挡。"},
	"龙车1": {"cost": 3, "kind": "charge_attack", "damage": 3, "move": 3, "range": 1, "text": "追近守护者并造成3点近战伤害。"},
	"甩尾1": {"cost": 2, "kind": "attack", "damage": 2, "move": 0, "range": 1, "text": "近战造成2点伤害，并抽象为击退效果。"},
	"瘴气炮1": {"cost": 4, "kind": "miasma_shot", "damage": 1, "move": 0, "range": 4, "text": "远程1点伤害，并在选中区域留下瘴气。"},
	"地底潜行1": {"cost": 3, "kind": "burrow", "damage": 0, "move": 3, "range": 0, "text": "无视区域移动到选中区域，怪兽获得2点护甲。"},
}

const MARKET_SKILLS := [
	"赌怪1",
	"黑幕1",
	"移动2",
	"普攻2",
	"普攻3",
	"区域破坏1",
	"飞行1",
	"龙车1",
	"甩尾1",
	"瘴气炮1",
	"地底潜行1",
]

const GUARDIAN_ACTIONS := [
	{"name": "普攻", "range": 1, "damage": 2, "text": "近战2伤害，击退1。"},
	{"name": "普攻", "range": 1, "damage": 2, "text": "近战2伤害，击退1。"},
	{"name": "火花电击", "range": 4, "damage": 2, "text": "距离4，2伤害，麻痹1。"},
	{"name": "奥特飓风", "range": 1, "damage": 2, "text": "近战投掷，2坠落伤害。"},
	{"name": "斯派修姆光线", "range": 6, "damage": 3, "text": "距离6，3伤害，直线击退。"},
	{"name": "奥特空投", "range": 1, "damage": 4, "text": "近战4伤害，眩晕1。"},
]

var rng := RandomNumberGenerator.new()
var players := []
var districts := []
var skill_market := []
var taken_actions := {}
var log_lines := []

var round_index := 1
var actions_per_player := 2
var first_player := 0
var next_first_player := 0
var active_player_index := 0
var selected_district := 4
var selected_market_skill := "赌怪1"
var prediction_mode := "塌陷"
var monster_control_pot := 0
var control_chosen_this_round := false
var game_over := false

var monster := {}
var guardian := {}

var status_label: Label
var board_grid: GridContainer
var action_box: VBoxContainer
var player_box: VBoxContainer
var district_box: VBoxContainer
var market_box: VBoxContainer
var combat_box: VBoxContainer
var log_view: RichTextLabel


func _ready() -> void:
	rng.randomize()
	_build_layout()
	_new_game()


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#090d18")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)

	var title := Label.new()
	title.text = "太空辛迪加 / Space Syndicate"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f8fafc"))
	header.add_child(title)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	header.add_child(status_label)

	var reset_button := Button.new()
	reset_button.text = "重新开局"
	reset_button.pressed.connect(Callable(self, "_new_game"))
	header.add_child(reset_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 10)
	body.add_child(left_column)

	var board_panel := _add_panel(left_column, "地区棋盘")
	_panel_container(board_panel).size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_grid = GridContainer.new()
	board_grid.columns = BOARD_COLUMNS
	board_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_grid.add_theme_constant_override("h_separation", 8)
	board_grid.add_theme_constant_override("v_separation", 8)
	board_panel.add_child(board_grid)

	var bottom_row := HBoxContainer.new()
	bottom_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_row.add_theme_constant_override("separation", 10)
	left_column.add_child(bottom_row)

	district_box = _add_panel(bottom_row, "选中区域")
	_panel_container(district_box).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	combat_box = _add_panel(bottom_row, "战斗与状态")
	_panel_container(combat_box).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(430, 0)
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	body.add_child(right_column)

	action_box = _add_panel(right_column, "行动轨")

	player_box = _add_panel(right_column, "当前玩家")

	market_box = _add_panel(right_column, "公共技能栏")

	var log_panel := _add_panel(right_column, "日志")
	_panel_container(log_panel).size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.fit_content = false
	log_view.scroll_following = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(log_view)


func _add_panel(parent: Container, title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111827")
	style.border_color = Color("#334155")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#f8fafc"))
	box.add_child(title)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.set_meta("panel_container", panel)
	box.add_child(content)

	parent.add_child(panel)
	return content


func _panel_container(box: VBoxContainer) -> PanelContainer:
	return box.get_meta("panel_container") as PanelContainer


func _new_game() -> void:
	players = []
	districts = []
	skill_market = MARKET_SKILLS.duplicate()
	taken_actions = {}
	log_lines = []
	round_index = 1
	first_player = 0
	next_first_player = 0
	active_player_index = 0
	selected_district = 4
	selected_market_skill = skill_market[0]
	prediction_mode = "塌陷"
	monster_control_pot = 0
	control_chosen_this_round = false
	game_over = false

	for i in range(PLAYER_COUNT):
		players.append({
			"id": i,
			"name": "玩家%d" % (i + 1),
			"cash": STARTING_CASH,
			"actions": 0,
			"slots": [_make_skill("移动1"), _make_skill("普攻1"), null],
		})

	var district_names := ["东京湾", "能源塔", "旧城区", "港口", "地球总部", "商业区", "地下基地", "电视台", "轨道电梯"]
	var hp_values := [2, 3, 2, 3, 4, 2, 3, 2, 4]
	for i in range(district_names.size()):
		districts.append({
			"name": district_names[i],
			"hp": hp_values[i],
			"damage": 0,
			"bonus": 0,
			"destroyed": false,
			"miasma": false,
			"bets": {},
		})

	monster = {
		"name": "尸套龙",
		"hp": 50,
		"max_hp": 50,
		"position": 4,
		"armor": 0,
	}
	guardian = {
		"name": "机械杰克",
		"hp": 30,
		"max_hp": 30,
		"move": 4,
		"position": 0,
	}

	_log("开局：4名玩家各获得2000筹码，尸套龙与机械杰克进入战场。")
	_refresh_ui()


func _make_skill(skill_name: String) -> Dictionary:
	var base: Dictionary = SKILL_CATALOG.get(skill_name, {})
	var skill := base.duplicate(true)
	skill["name"] = skill_name
	skill["charge"] = 0
	return skill


func _refresh_ui() -> void:
	_refresh_status()
	_refresh_board()
	_refresh_actions()
	_refresh_player()
	_refresh_district()
	_refresh_market()
	_refresh_combat()
	_refresh_log()


func _refresh_status() -> void:
	var p: Dictionary = players[active_player_index]
	status_label.text = "第%d回合  当前：%s  行动 %d/%d  怪兽操控奖金：%d" % [
		round_index,
		p["name"],
		p["actions"] + 1,
		actions_per_player,
		monster_control_pot,
	]


func _refresh_board() -> void:
	_clear_children(board_grid)
	for i in range(districts.size()):
		var d: Dictionary = districts[i]
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(240, 150)
		button.text = _district_button_text(i)
		button.clip_text = true
		button.pressed.connect(Callable(self, "_select_district").bind(i))
		if i == selected_district:
			button.add_theme_color_override("font_color", Color("#facc15"))
		elif d["destroyed"]:
			button.add_theme_color_override("font_color", Color("#94a3b8"))
		board_grid.add_child(button)


func _district_button_text(index: int) -> String:
	var d: Dictionary = districts[index]
	var markers := []
	if monster["position"] == index:
		markers.append("怪兽")
	if guardian["position"] == index:
		markers.append("守护者")
	if d["miasma"]:
		markers.append("瘴气")
	var marker_text := ""
	if not markers.is_empty():
		marker_text = "\n[%s]" % " / ".join(markers)
	var destroyed_text := "已破坏" if d["destroyed"] else "HP %d/%d" % [max(0, d["hp"] - d["damage"]), d["hp"]]
	return "%s%s\n%s  奖金:%d\n下注:%d" % [
		d["name"],
		marker_text,
		destroyed_text,
		d["bonus"],
		_total_bets(d),
	]


func _refresh_actions() -> void:
	_clear_children(action_box)
	for action in ACTIONS:
		var id: String = action["id"]
		var button := Button.new()
		button.text = "%s  -  %s" % [action["name"], action["hint"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = game_over or taken_actions.has(id)
		if taken_actions.has(id):
			button.text = "✓ %s  (%s已选)" % [action["name"], players[taken_actions[id]]["name"]]
		button.pressed.connect(Callable(self, "_perform_action").bind(id))
		action_box.add_child(button)


func _refresh_player() -> void:
	_clear_children(player_box)
	var player: Dictionary = players[active_player_index]
	player_box.add_child(_plain_label("%s  筹码:%d" % [player["name"], player["cash"]], 16, Color("#e2e8f0")))
	player_box.add_child(_plain_label("已行动:%d/%d  技能槽:%d/6" % [player["actions"], actions_per_player, player["slots"].size()], 14, Color("#cbd5e1")))

	for i in range(player["slots"].size()):
		var skill = player["slots"][i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		player_box.add_child(row)
		if skill == null:
			row.add_child(_plain_label("槽%d：空" % (i + 1), 14, Color("#94a3b8")))
			continue
		var text := "%s  %d/%d  %s" % [skill["name"], skill["charge"], skill["cost"], skill["text"]]
		var label := _plain_label(text, 13, Color("#e5e7eb"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var use_button := Button.new()
		use_button.text = "释放"
		use_button.disabled = game_over or skill["charge"] < skill["cost"]
		use_button.pressed.connect(Callable(self, "_use_skill").bind(i))
		row.add_child(use_button)


func _refresh_district() -> void:
	_clear_children(district_box)
	var d: Dictionary = districts[selected_district]
	district_box.add_child(_plain_label("%s  %s" % [d["name"], "已破坏" if d["destroyed"] else "未破坏"], 16, Color("#f8fafc")))
	district_box.add_child(_plain_label("区域HP: %d/%d  奖金:%d  瘴气:%s" % [
		max(0, d["hp"] - d["damage"]),
		d["hp"],
		d["bonus"],
		"有" if d["miasma"] else "无",
	], 14, Color("#cbd5e1")))

	var prediction_row := HBoxContainer.new()
	prediction_row.add_theme_constant_override("separation", 6)
	district_box.add_child(prediction_row)
	var collapse_button := Button.new()
	collapse_button.text = "判断: 塌陷"
	collapse_button.toggle_mode = true
	collapse_button.button_pressed = prediction_mode == "塌陷"
	collapse_button.pressed.connect(Callable(self, "_set_prediction").bind("塌陷"))
	prediction_row.add_child(collapse_button)
	var survive_button := Button.new()
	survive_button.text = "判断: 存活"
	survive_button.toggle_mode = true
	survive_button.button_pressed = prediction_mode == "存活"
	survive_button.pressed.connect(Callable(self, "_set_prediction").bind("存活"))
	prediction_row.add_child(survive_button)

	var bets_text := _format_bets(d)
	district_box.add_child(_plain_label("下注：\n%s" % bets_text, 13, Color("#e5e7eb")))


func _refresh_market() -> void:
	_clear_children(market_box)
	if skill_market.is_empty():
		market_box.add_child(_plain_label("公共技能栏为空。", 14, Color("#94a3b8")))
		return
	for skill_name in skill_market:
		var skill: Dictionary = SKILL_CATALOG[skill_name]
		var button := Button.new()
		var prefix := ">> " if skill_name == selected_market_skill else ""
		button.text = "%s%s  %d充能  %s" % [prefix, skill_name, skill["cost"], skill["text"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = game_over
		button.pressed.connect(Callable(self, "_select_market_skill").bind(skill_name))
		market_box.add_child(button)


func _refresh_combat() -> void:
	_clear_children(combat_box)
	combat_box.add_child(_plain_label("怪兽：%s  HP %d/%d  护甲:%d  位置:%s" % [
		monster["name"],
		max(0, monster["hp"]),
		monster["max_hp"],
		monster["armor"],
		districts[monster["position"]]["name"],
	], 14, Color("#fecaca")))
	combat_box.add_child(_plain_label("守护者：%s  HP %d/%d  位置:%s" % [
		guardian["name"],
		max(0, guardian["hp"]),
		guardian["max_hp"],
		districts[guardian["position"]]["name"],
	], 14, Color("#bae6fd")))
	combat_box.add_child(_plain_label("距离：%d格" % _distance(monster["position"], guardian["position"]), 14, Color("#cbd5e1")))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	combat_box.add_child(row)

	var guardian_button := Button.new()
	guardian_button.text = "手动守护者检定"
	guardian_button.disabled = game_over
	guardian_button.pressed.connect(Callable(self, "_run_guardian_checks").bind(1))
	row.add_child(guardian_button)

	var settle_button := Button.new()
	settle_button.text = "强制结算"
	settle_button.disabled = game_over
	settle_button.pressed.connect(Callable(self, "_end_game_by_manual_settlement"))
	row.add_child(settle_button)


func _refresh_log() -> void:
	log_view.clear()
	for line in log_lines:
		log_view.append_text(line + "\n")


func _plain_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _select_district(index: int) -> void:
	selected_district = index
	_refresh_ui()


func _set_prediction(mode: String) -> void:
	prediction_mode = mode
	_refresh_ui()


func _select_market_skill(skill_name: String) -> void:
	selected_market_skill = skill_name
	_refresh_ui()


func _perform_action(action_id: String) -> void:
	if game_over or taken_actions.has(action_id):
		return
	var player: Dictionary = players[active_player_index]
	match action_id:
		"first":
			next_first_player = active_player_index
			_log("%s抢到下回合先手。" % player["name"])
		"bet1":
			_bet_on_selected(BET_UNIT, true)
		"skill1":
			_charge_current_player_skills(_charge_limit(player))
		"bet2":
			_bet_on_selected(BET_UNIT, false)
		"skill2":
			_gain_first_available_skill()
			_charge_current_player_skills(_charge_limit(player))
		"market":
			_add_market_bonus(selected_district, BET_UNIT)
		"bet3":
			if not _move_own_bet_to_selected(BET_UNIT):
				_bet_on_selected(BET_UNIT, false)
		"skill3":
			_expand_skill_slot()
			_gain_first_available_skill()
			_charge_current_player_skills(_charge_limit(player))
		"control":
			_control_monster()
		"bet4":
			if not _move_any_bet_to_selected(BET_UNIT):
				if not _move_own_bet_to_selected(BET_UNIT):
					_bet_on_selected(BET_UNIT, false)
		_:
			_log("未知行动：%s" % action_id)

	taken_actions[action_id] = active_player_index
	player["actions"] += 1
	_advance_turn()
	_refresh_ui()


func _advance_turn() -> void:
	if game_over:
		return
	var all_done := true
	for p in players:
		if p["actions"] < actions_per_player:
			all_done = false
			break
	if all_done:
		_end_round()
		return

	for step in range(1, PLAYER_COUNT + 1):
		var candidate := (active_player_index + step) % PLAYER_COUNT
		if players[candidate]["actions"] < actions_per_player:
			active_player_index = candidate
			return


func _end_round() -> void:
	if not control_chosen_this_round:
		monster_control_pot += 100
		_log("本回合无人操控怪兽，操控怪兽行动格累积100筹码。")
	round_index += 1
	first_player = next_first_player
	active_player_index = first_player
	taken_actions = {}
	control_chosen_this_round = false
	for p in players:
		p["actions"] = 0
	_log("进入第%d回合。先手：%s。" % [round_index, players[first_player]["name"]])


func _bet_on_selected(amount: int, require_existing: bool) -> bool:
	var player: Dictionary = players[active_player_index]
	var district: Dictionary = districts[selected_district]
	if district["destroyed"]:
		_log("%s已被破坏，不能下注。" % district["name"])
		return false
	if player["cash"] <= 0:
		_log("%s没有可下注筹码。" % player["name"])
		return false
	var bets: Dictionary = district["bets"]
	var pid: int = player["id"]
	if not bets.has(pid):
		if require_existing:
			_log("%s还没有在%s放置判断指示物，下注1失败。" % [player["name"], district["name"]])
			return false
		if _bettor_count(district) >= DISTRICT_LIMIT:
			_log("%s的下注人数已满。" % district["name"])
			return false
		bets[pid] = {"amount": 0, "prediction": prediction_mode}
	var placed: int = min(amount, player["cash"])
	player["cash"] -= placed
	bets[pid]["amount"] += placed
	bets[pid]["prediction"] = prediction_mode
	_log("%s在%s押%d，判断为%s。" % [player["name"], district["name"], placed, prediction_mode])
	return true


func _move_own_bet_to_selected(amount: int) -> bool:
	var player: Dictionary = players[active_player_index]
	var pid: int = player["id"]
	var source_index := -1
	var source_amount := 0
	for i in range(districts.size()):
		if i == selected_district:
			continue
		var bets: Dictionary = districts[i]["bets"]
		if bets.has(pid) and bets[pid]["amount"] > source_amount:
			source_index = i
			source_amount = bets[pid]["amount"]
	if source_index == -1:
		_log("%s没有可移动的己方下注。" % player["name"])
		return false
	return _move_bet_between_districts(source_index, selected_district, pid, min(amount, source_amount))


func _move_any_bet_to_selected(amount: int) -> bool:
	var source_index := -1
	var source_pid := -1
	var source_amount := 0
	for i in range(districts.size()):
		if i == selected_district:
			continue
		var bets: Dictionary = districts[i]["bets"]
		for pid in bets.keys():
			if bets[pid]["amount"] > source_amount:
				source_index = i
				source_pid = pid
				source_amount = bets[pid]["amount"]
	if source_index == -1:
		_log("场上没有可移动的下注。")
		return false
	return _move_bet_between_districts(source_index, selected_district, source_pid, min(amount, source_amount))


func _move_bet_between_districts(source_index: int, target_index: int, pid: int, amount: int) -> bool:
	var source: Dictionary = districts[source_index]
	var target: Dictionary = districts[target_index]
	if target["destroyed"]:
		_log("目标区域已破坏，不能移动下注。")
		return false
	if not target["bets"].has(pid):
		if _bettor_count(target) >= DISTRICT_LIMIT:
			_log("目标区域下注人数已满，不能移动下注。")
			return false
		target["bets"][pid] = {"amount": 0, "prediction": prediction_mode}
	source["bets"][pid]["amount"] -= amount
	target["bets"][pid]["amount"] += amount
	if source["bets"][pid]["amount"] <= 0:
		source["bets"].erase(pid)
	_log("将%s的%d筹码从%s移动到%s。" % [players[pid]["name"], amount, source["name"], target["name"]])
	return true


func _add_market_bonus(index: int, amount: int) -> void:
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		_log("已破坏区域不能追加奖金。")
		return
	d["bonus"] += amount
	_log("%s追加%d区域奖金。" % [d["name"], amount])


func _charge_limit(player: Dictionary) -> int:
	return 300 + max(0, player["slots"].size() - 3) * 200


func _charge_current_player_skills(limit_cash: int) -> void:
	var player: Dictionary = players[active_player_index]
	var spent := 0
	for skill in player["slots"]:
		if skill == null:
			continue
		while player["cash"] >= CHARGE_UNIT and spent + CHARGE_UNIT <= limit_cash and skill["charge"] < skill["cost"]:
			player["cash"] -= CHARGE_UNIT
			spent += CHARGE_UNIT
			skill["charge"] += 1
	if spent == 0:
		_log("%s没有可充能的技能或筹码不足。" % player["name"])
	else:
		_log("%s花费%d给技能充能。" % [player["name"], spent])


func _expand_skill_slot() -> void:
	var player: Dictionary = players[active_player_index]
	if player["slots"].size() >= 6:
		_log("%s已达到6个技能槽上限。" % player["name"])
		return
	if player["cash"] < 500:
		_log("%s筹码不足，无法开启新技能槽。" % player["name"])
		return
	player["cash"] -= 500
	player["slots"].append(null)
	_log("%s支付500开启了新的技能槽。" % player["name"])


func _gain_first_available_skill() -> void:
	if skill_market.is_empty():
		_log("公共技能栏为空。")
		return
	if selected_market_skill == "" or not skill_market.has(selected_market_skill):
		selected_market_skill = skill_market[0]
	_gain_specific_skill(selected_market_skill)


func _gain_specific_skill(skill_name: String) -> void:
	if game_over:
		return
	var player: Dictionary = players[active_player_index]
	var empty_index := -1
	for i in range(player["slots"].size()):
		if player["slots"][i] == null:
			empty_index = i
			break
	if empty_index == -1:
		_log("%s没有空技能槽，无法获得%s。" % [player["name"], skill_name])
		return
	if not skill_market.has(skill_name):
		_log("%s不在公共技能栏中。" % skill_name)
		return
	player["slots"][empty_index] = _make_skill(skill_name)
	skill_market.erase(skill_name)
	selected_market_skill = skill_market[0] if not skill_market.is_empty() else ""
	_log("%s获得技能卡：%s。" % [player["name"], skill_name])


func _control_monster() -> void:
	var player: Dictionary = players[active_player_index]
	control_chosen_this_round = true
	var extra_checks := int(monster_control_pot / 100)
	if monster_control_pot > 0:
		player["cash"] += monster_control_pot
		_log("%s拿走操控怪兽行动格上的%d筹码。" % [player["name"], monster_control_pot])
	monster_control_pot = 0
	_log("%s获得本回合怪兽操控权，战斗轮开始。" % player["name"])
	_run_guardian_checks(1 + extra_checks)


func _run_guardian_checks(count: int) -> void:
	if game_over:
		return
	for i in range(count):
		if game_over:
			break
		_guardian_action()


func _guardian_action() -> void:
	var roll := rng.randi_range(1, 6)
	var any_destroyed := false
	for d in districts:
		if d["destroyed"]:
			any_destroyed = true
			break
	if not any_destroyed and roll > 3:
		roll -= 3
	var action: Dictionary = GUARDIAN_ACTIONS[roll - 1]
	_log("守护者D6=%d：%s。" % [roll, action["name"]])
	_move_guardian_until_in_range(action["range"])
	if _distance(guardian["position"], monster["position"]) <= action["range"]:
		_monster_take_damage(action["damage"], action["name"])
	else:
		_log("守护者未能进入射程，攻击落空。")


func _move_guardian_until_in_range(required_range: int) -> void:
	var moved := 0
	while moved < guardian["move"] and _distance(guardian["position"], monster["position"]) > required_range:
		guardian["position"] = _next_step_toward(guardian["position"], monster["position"])
		moved += 1
	if moved > 0:
		_log("守护者移动%d格至%s。" % [moved, districts[guardian["position"]]["name"]])


func _use_skill(slot_index: int) -> void:
	if game_over:
		return
	var player: Dictionary = players[active_player_index]
	var skill = player["slots"][slot_index]
	if skill == null:
		return
	if skill["charge"] < skill["cost"]:
		_log("%s尚未充满。" % skill["name"])
		return
	_log("%s释放%s。" % [player["name"], skill["name"]])

	match skill["kind"]:
		"bet_boost":
			_bet_on_selected(BET_UNIT, false)
		"market_boost":
			_add_market_bonus(selected_district, BET_UNIT)
		"move":
			_move_monster_to_selected(skill["move"], false)
		"fly":
			_move_monster_to_selected(skill["move"], true)
		"burrow":
			_move_monster_to_selected(skill["move"], true)
			monster["armor"] += 2
			_log("怪兽获得2点护甲。")
		"attack":
			_monster_attack_guardian(skill["damage"], skill["range"], skill["name"])
		"charge_attack":
			_move_monster_toward_guardian(skill["move"])
			_monster_attack_guardian(skill["damage"], skill["range"], skill["name"])
		"area_damage":
			if _distance(monster["position"], selected_district) <= skill["range"]:
				_damage_district(selected_district, skill["damage"], skill["name"])
			else:
				_log("选中区域不在区域破坏射程内。")
		"miasma_shot":
			if _distance(monster["position"], guardian["position"]) <= skill["range"]:
				_guardian_take_damage(skill["damage"], skill["name"])
			else:
				_log("守护者不在瘴气炮射程内。")
			districts[selected_district]["miasma"] = true
			_log("%s留下瘴气token。" % districts[selected_district]["name"])
		_:
			_log("该技能暂未实现具体效果。")

	skill["charge"] = 0
	_refresh_ui()


func _move_monster_to_selected(max_steps: int, ignore_distance: bool) -> void:
	if districts[selected_district]["destroyed"]:
		_log("怪兽不能移动到已破坏区域。")
		return
	var dist := _distance(monster["position"], selected_district)
	if not ignore_distance and dist > max_steps:
		_log("选中区域距离%d，超过移动力%d。" % [dist, max_steps])
		return
	monster["position"] = selected_district
	_log("怪兽移动至%s。" % districts[selected_district]["name"])
	_damage_district(selected_district, 1, "怪兽移动")


func _move_monster_toward_guardian(max_steps: int) -> void:
	var moved := 0
	while moved < max_steps and _distance(monster["position"], guardian["position"]) > 1:
		monster["position"] = _next_step_toward(monster["position"], guardian["position"])
		moved += 1
		_damage_district(monster["position"], 1, "怪兽冲撞移动")
	if moved > 0:
		_log("怪兽追近%d格至%s。" % [moved, districts[monster["position"]]["name"]])


func _monster_attack_guardian(damage: int, range_limit: int, source: String) -> void:
	if _distance(monster["position"], guardian["position"]) > range_limit:
		_log("守护者不在%s射程内。" % source)
		return
	_guardian_take_damage(damage, source)


func _guardian_take_damage(damage: int, source: String) -> void:
	var player: Dictionary = players[active_player_index]
	guardian["hp"] -= damage
	var reward := damage * 200
	player["cash"] += reward
	_log("%s对守护者造成%d伤害，%s获得%d筹码。" % [source, damage, player["name"], reward])
	if guardian["hp"] <= 0:
		_finish_game("%s被击败。" % guardian["name"])


func _monster_take_damage(damage: int, source: String) -> void:
	var reduced := max(0, damage - monster["armor"])
	if monster["armor"] > 0:
		_log("怪兽护甲抵消%d点伤害。" % min(damage, monster["armor"]))
	monster["armor"] = max(0, monster["armor"] - damage)
	monster["hp"] -= reduced
	var controller: Dictionary = players[active_player_index]
	var loss := min(controller["cash"], reduced * 100)
	controller["cash"] -= loss
	_log("%s对怪兽造成%d伤害，%s支付%d筹码损失。" % [source, reduced, controller["name"], loss])
	if monster["hp"] <= 0:
		_finish_game("%s被击败。" % monster["name"])


func _damage_district(index: int, amount: int, source: String) -> void:
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return
	d["damage"] += amount
	_log("%s使%s受到%d点区域伤害。" % [source, d["name"], amount])
	if d["damage"] >= d["hp"]:
		d["destroyed"] = true
		_log("%s被破坏，立即结算该区域。" % d["name"])
		_settle_district(index, true)


func _settle_district(index: int, collapsed: bool) -> void:
	var d: Dictionary = districts[index]
	var winning_prediction := "塌陷" if collapsed else "存活"
	var top_amount := -1
	var top_players := []
	for pid in d["bets"].keys():
		var bet: Dictionary = d["bets"][pid]
		if bet["prediction"] == winning_prediction:
			var payout: int = bet["amount"] * 2
			players[pid]["cash"] += payout
			_log("%s猜中%s，获得%d。" % [players[pid]["name"], winning_prediction, payout])
		else:
			_log("%s猜错%s，失去%d下注。" % [players[pid]["name"], winning_prediction, bet["amount"]])
		if bet["amount"] > top_amount:
			top_amount = bet["amount"]
			top_players = [pid]
		elif bet["amount"] == top_amount:
			top_players.append(pid)
	if d["bonus"] > 0 and not top_players.is_empty():
		var share := int(d["bonus"] / top_players.size())
		for pid in top_players:
			players[pid]["cash"] += share
			_log("%s获得%s最高下注奖金%d。" % [players[pid]["name"], d["name"], share])
	d["bets"].clear()
	d["bonus"] = 0


func _finish_game(reason: String) -> void:
	if game_over:
		return
	game_over = true
	_log("游戏结束：%s" % reason)
	for i in range(districts.size()):
		if not districts[i]["destroyed"]:
			_settle_district(i, false)
	var winner := players[0]
	for p in players:
		if p["cash"] > winner["cash"]:
			winner = p
	_log("胜者：%s，筹码%d。" % [winner["name"], winner["cash"]])


func _end_game_by_manual_settlement() -> void:
	_finish_game("手动触发最终结算。")
	_refresh_ui()


func _distance(a: int, b: int) -> int:
	var ax := a % BOARD_COLUMNS
	var ay := int(a / BOARD_COLUMNS)
	var bx := b % BOARD_COLUMNS
	var by := int(b / BOARD_COLUMNS)
	return abs(ax - bx) + abs(ay - by)


func _next_step_toward(from_index: int, to_index: int) -> int:
	var best := from_index
	var best_distance := _distance(from_index, to_index)
	for candidate in _neighbors(from_index):
		if districts[candidate]["destroyed"]:
			continue
		var dist := _distance(candidate, to_index)
		if dist < best_distance:
			best = candidate
			best_distance = dist
	return best


func _neighbors(index: int) -> Array:
	var result := []
	var x := index % BOARD_COLUMNS
	var y := int(index / BOARD_COLUMNS)
	var options := [
		Vector2i(x + 1, y),
		Vector2i(x - 1, y),
		Vector2i(x, y + 1),
		Vector2i(x, y - 1),
	]
	for point in options:
		if point.x >= 0 and point.x < BOARD_COLUMNS and point.y >= 0 and point.y < BOARD_COLUMNS:
			result.append(point.y * BOARD_COLUMNS + point.x)
	return result


func _bettor_count(district: Dictionary) -> int:
	return district["bets"].size()


func _total_bets(district: Dictionary) -> int:
	var total := 0
	for pid in district["bets"].keys():
		total += district["bets"][pid]["amount"]
	return total


func _format_bets(district: Dictionary) -> String:
	if district["bets"].is_empty():
		return "暂无"
	var lines := []
	for pid in district["bets"].keys():
		var bet: Dictionary = district["bets"][pid]
		lines.append("%s：%d / %s" % [players[pid]["name"], bet["amount"], bet["prediction"]])
	return "\n".join(lines)


func _log(message: String) -> void:
	var line := "[第%d回合] %s" % [round_index, message]
	log_lines.append(line)
	while log_lines.size() > 80:
		log_lines.pop_front()
