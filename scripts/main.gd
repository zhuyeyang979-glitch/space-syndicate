extends Control

const PLAYER_COUNT := 4
const BOARD_COLUMNS := 3
const STARTING_CASH := 2000
const BET_UNIT := 200
const WITHDRAW_UNIT := 100
const CHARGE_UNIT := 100
const DISTRICT_LIMIT := 2

const SPEEDS := [
	{"label": "暂停", "value": 0.0},
	{"label": "1x", "value": 1.0},
	{"label": "2x", "value": 2.0},
	{"label": "4x", "value": 4.0},
]

const SKILL_CATALOG := {
	"赌怪1": {"cost": 3, "kind": "bet_boost", "damage": 0, "move": 0, "range": 0, "text": "立即向选中区域额外下注200。"},
	"黑幕1": {"cost": 2, "kind": "market_boost", "damage": 0, "move": 0, "range": 0, "text": "选中区域奖金+200，并提高当地热度。"},
	"移动1": {"cost": 2, "kind": "move", "damage": 0, "move": 1, "range": 0, "text": "指挥怪兽移动1格，进入区域造成1点区域伤害。"},
	"移动2": {"cost": 4, "kind": "move", "damage": 0, "move": 2, "range": 0, "text": "指挥怪兽最多移动2格。"},
	"普攻1": {"cost": 2, "kind": "attack", "damage": 1, "move": 0, "range": 1, "text": "近战，对守护者造成1点伤害。"},
	"普攻2": {"cost": 4, "kind": "attack", "damage": 2, "move": 0, "range": 1, "text": "近战，对守护者造成2点伤害。"},
	"普攻3": {"cost": 6, "kind": "attack", "damage": 3, "move": 0, "range": 1, "text": "近战，对守护者造成3点伤害。"},
	"区域破坏1": {"cost": 2, "kind": "area_damage", "damage": 1, "move": 0, "range": 1, "text": "对相邻或所在区域造成1点伤害。"},
	"飞行1": {"cost": 3, "kind": "fly", "damage": 0, "move": 5, "range": 0, "text": "飞行到选中区域，忽略距离限制。"},
	"龙车1": {"cost": 3, "kind": "charge_attack", "damage": 3, "move": 3, "range": 1, "text": "追近守护者并造成3点近战伤害。"},
	"甩尾1": {"cost": 2, "kind": "attack", "damage": 2, "move": 0, "range": 1, "text": "近战造成2点伤害，抽象为击退。"},
	"瘴气炮1": {"cost": 4, "kind": "miasma_shot", "damage": 1, "move": 0, "range": 4, "text": "远程1点伤害，并在选中区域留下瘴气。"},
	"地底潜行1": {"cost": 3, "kind": "burrow", "damage": 0, "move": 3, "range": 0, "text": "潜行到选中区域，怪兽获得2点护甲。"},
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
	{"name": "普攻", "range": 1, "damage": 2, "text": "近战2伤害。"},
	{"name": "普攻", "range": 1, "damage": 2, "text": "近战2伤害。"},
	{"name": "火花电击", "range": 4, "damage": 2, "text": "距离4，2伤害。"},
	{"name": "奥特飓风", "range": 1, "damage": 2, "text": "近战投掷，2坠落伤害。"},
	{"name": "斯派修姆光线", "range": 6, "damage": 3, "text": "距离6，3伤害。"},
	{"name": "奥特空投", "range": 1, "damage": 4, "text": "近战4伤害。"},
]

var rng := RandomNumberGenerator.new()
var players := []
var districts := []
var skill_market := []
var log_lines := []

var game_time := 0.0
var time_scale := 1.0
var selected_player := 0
var selected_district := 4
var selected_market_skill := "赌怪1"
var prediction_mode := "塌陷"
var game_over := false

var event_timer := 6.0
var guardian_timer := 5.0
var monster_timer := 4.0
var market_timer := 8.0
var ui_timer := 0.0

var monster := {}
var guardian := {}

var status_label: Label
var board_grid: GridContainer
var player_box: VBoxContainer
var district_box: VBoxContainer
var market_box: VBoxContainer
var combat_box: VBoxContainer
var log_view: RichTextLabel


func _ready() -> void:
	rng.randomize()
	_build_layout()
	_new_game()


func _process(delta: float) -> void:
	if game_over or time_scale <= 0.0:
		return

	var scaled_delta := delta * time_scale
	game_time += scaled_delta
	_decay_player_control(scaled_delta)

	event_timer -= scaled_delta
	guardian_timer -= scaled_delta
	monster_timer -= scaled_delta
	market_timer -= scaled_delta

	if event_timer <= 0.0:
		_world_event()
		event_timer = 5.0 + rng.randf_range(0.0, 3.0)
	if monster_timer <= 0.0:
		_monster_tick()
		monster_timer = 3.5 + rng.randf_range(0.0, 2.0)
	if guardian_timer <= 0.0:
		_guardian_tick()
		guardian_timer = 4.5 + rng.randf_range(0.0, 2.5)
	if market_timer <= 0.0:
		_market_tick()
		market_timer = 7.0 + rng.randf_range(0.0, 4.0)

	ui_timer -= delta
	if ui_timer <= 0.0:
		_refresh_ui()
		ui_timer = 0.25


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
	header.add_theme_constant_override("separation", 10)
	page.add_child(header)

	var title := Label.new()
	title.text = "太空辛迪加 / Space Syndicate  即时原型"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#f8fafc"))
	header.add_child(title)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	header.add_child(status_label)

	for speed in SPEEDS:
		var speed_button := Button.new()
		speed_button.text = speed["label"]
		speed_button.pressed.connect(Callable(self, "_set_speed").bind(speed["value"]))
		header.add_child(speed_button)

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

	var board_panel := _add_panel(left_column, "实时地区棋盘")
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

	combat_box = _add_panel(bottom_row, "实时战斗")
	_panel_container(combat_box).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(460, 0)
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	body.add_child(right_column)

	player_box = _add_panel(right_column, "玩家实时操作")
	market_box = _add_panel(right_column, "公共技能栏")

	var log_panel := _add_panel(right_column, "事件日志")
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
	log_lines = []
	game_time = 0.0
	time_scale = 1.0
	selected_player = 0
	selected_district = 4
	selected_market_skill = skill_market[0]
	prediction_mode = "塌陷"
	game_over = false
	event_timer = 4.0
	guardian_timer = 5.0
	monster_timer = 3.0
	market_timer = 8.0

	for i in range(PLAYER_COUNT):
		players.append({
			"id": i,
			"name": "玩家%d" % (i + 1),
			"cash": STARTING_CASH,
			"control": 0.0,
			"slots": [_make_skill("移动1"), _make_skill("普攻1"), null],
		})

	var names := ["东京湾", "能源塔", "旧城区", "港口", "地球总部", "商业区", "地下基地", "电视台", "轨道电梯"]
	var hp_values := [2, 3, 2, 3, 4, 2, 3, 2, 4]
	for i in range(names.size()):
		districts.append({
			"name": names[i],
			"hp": hp_values[i],
			"damage": 0,
			"panic": 15 + i * 3,
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

	_log("即时原型启动：时间持续推进，玩家可随时下注、充能、夺取怪兽控制权。")
	_refresh_ui()


func _make_skill(skill_name: String) -> Dictionary:
	var base: Dictionary = SKILL_CATALOG.get(skill_name, {})
	var skill := base.duplicate(true)
	skill["name"] = skill_name
	skill["charge"] = 0
	return skill


func _set_speed(value: float) -> void:
	time_scale = value
	_refresh_ui()


func _refresh_ui() -> void:
	_refresh_status()
	_refresh_board()
	_refresh_player_panel()
	_refresh_district_panel()
	_refresh_market_panel()
	_refresh_combat_panel()
	_refresh_log()


func _refresh_status() -> void:
	var controller := _monster_controller()
	var controller_text := "无人"
	if controller >= 0:
		controller_text = players[controller]["name"]
	status_label.text = "时间 %s  速度 %.0fx  怪兽控制:%s  怪兽行动 %.1fs  守护者 %.1fs" % [
		_format_time(game_time),
		time_scale,
		controller_text,
		max(0.0, monster_timer),
		max(0.0, guardian_timer),
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
	var state := "已破坏" if d["destroyed"] else "HP %d/%d" % [max(0, d["hp"] - d["damage"]), d["hp"]]
	return "%s%s\n%s  热度:%d\n奖金:%d  下注:%d" % [
		d["name"],
		marker_text,
		state,
		int(d["panic"]),
		d["bonus"],
		_total_bets(d),
	]


func _refresh_player_panel() -> void:
	_clear_children(player_box)

	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 6)
	player_box.add_child(selector)
	for i in range(players.size()):
		var button := Button.new()
		button.text = players[i]["name"]
		button.toggle_mode = true
		button.button_pressed = i == selected_player
		button.pressed.connect(Callable(self, "_select_player").bind(i))
		selector.add_child(button)

	var player: Dictionary = players[selected_player]
	player_box.add_child(_plain_label("%s  筹码:%d  控制权:%.1f" % [
		player["name"],
		player["cash"],
		player["control"],
	], 16, Color("#e2e8f0")))

	var prediction_row := HBoxContainer.new()
	prediction_row.add_theme_constant_override("separation", 6)
	player_box.add_child(prediction_row)
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

	var action_row := GridContainer.new()
	action_row.columns = 2
	action_row.add_theme_constant_override("h_separation", 6)
	action_row.add_theme_constant_override("v_separation", 6)
	player_box.add_child(action_row)
	_add_action_button(action_row, "实时下注 +200", "_place_bet")
	_add_action_button(action_row, "撤回下注 -100", "_withdraw_bet")
	_add_action_button(action_row, "技能充能", "_charge_skills")
	_add_action_button(action_row, "购买选中技能", "_buy_selected_skill")
	_add_action_button(action_row, "夺取怪兽控制", "_seize_control")
	_add_action_button(action_row, "指挥怪兽移动", "_direct_monster")

	for i in range(player["slots"].size()):
		var skill = player["slots"][i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		player_box.add_child(row)
		if skill == null:
			row.add_child(_plain_label("槽%d：空" % (i + 1), 13, Color("#94a3b8")))
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


func _add_action_button(parent: Container, text: String, method: String) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = game_over
	button.pressed.connect(Callable(self, method))
	parent.add_child(button)


func _refresh_district_panel() -> void:
	_clear_children(district_box)
	var d: Dictionary = districts[selected_district]
	district_box.add_child(_plain_label("%s  %s" % [d["name"], "已破坏" if d["destroyed"] else "未破坏"], 16, Color("#f8fafc")))
	district_box.add_child(_plain_label("区域HP: %d/%d  热度:%d  奖金:%d  瘴气:%s" % [
		max(0, d["hp"] - d["damage"]),
		d["hp"],
		int(d["panic"]),
		d["bonus"],
		"有" if d["miasma"] else "无",
	], 14, Color("#cbd5e1")))
	district_box.add_child(_plain_label("下注：\n%s" % _format_bets(d), 13, Color("#e5e7eb")))


func _refresh_market_panel() -> void:
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


func _refresh_combat_panel() -> void:
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
	combat_box.add_child(_plain_label("距离：%d格  事件 %.1fs  市场 %.1fs" % [
		_distance(monster["position"], guardian["position"]),
		max(0.0, event_timer),
		max(0.0, market_timer),
	], 14, Color("#cbd5e1")))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	combat_box.add_child(row)
	var guardian_button := Button.new()
	guardian_button.text = "手动守护者检定"
	guardian_button.disabled = game_over
	guardian_button.pressed.connect(Callable(self, "_guardian_tick"))
	row.add_child(guardian_button)
	var event_button := Button.new()
	event_button.text = "推进突发事件"
	event_button.disabled = game_over
	event_button.pressed.connect(Callable(self, "_world_event"))
	row.add_child(event_button)
	var settle_button := Button.new()
	settle_button.text = "强制结算"
	settle_button.disabled = game_over
	settle_button.pressed.connect(Callable(self, "_manual_settlement"))
	row.add_child(settle_button)


func _refresh_log() -> void:
	log_view.clear()
	for line in log_lines:
		log_view.append_text(line + "\n")


func _select_player(index: int) -> void:
	selected_player = index
	_refresh_ui()


func _select_district(index: int) -> void:
	selected_district = index
	_refresh_ui()


func _set_prediction(mode: String) -> void:
	prediction_mode = mode
	_refresh_ui()


func _select_market_skill(skill_name: String) -> void:
	selected_market_skill = skill_name
	_refresh_ui()


func _place_bet() -> void:
	var player: Dictionary = players[selected_player]
	var district: Dictionary = districts[selected_district]
	if district["destroyed"]:
		_log("%s已被破坏，不能继续下注。" % district["name"])
		return
	if player["cash"] <= 0:
		_log("%s没有可下注筹码。" % player["name"])
		return
	var pid: int = player["id"]
	if not district["bets"].has(pid):
		if _bettor_count(district) >= DISTRICT_LIMIT:
			_log("%s下注席位已满。" % district["name"])
			return
		district["bets"][pid] = {"amount": 0, "prediction": prediction_mode}
	var placed: int = min(BET_UNIT, player["cash"])
	player["cash"] -= placed
	district["bets"][pid]["amount"] += placed
	district["bets"][pid]["prediction"] = prediction_mode
	district["panic"] = min(100, district["panic"] + 4)
	_log("%s实时押注%s %d，判断为%s。" % [player["name"], district["name"], placed, prediction_mode])
	_refresh_ui()


func _withdraw_bet() -> void:
	var player: Dictionary = players[selected_player]
	var district: Dictionary = districts[selected_district]
	var pid: int = player["id"]
	if not district["bets"].has(pid):
		_log("%s在%s没有下注可撤回。" % [player["name"], district["name"]])
		return
	var amount: int = min(WITHDRAW_UNIT, district["bets"][pid]["amount"])
	district["bets"][pid]["amount"] -= amount
	player["cash"] += amount
	if district["bets"][pid]["amount"] <= 0:
		district["bets"].erase(pid)
	_log("%s从%s撤回%d筹码。" % [player["name"], district["name"], amount])
	_refresh_ui()


func _charge_skills() -> void:
	var player: Dictionary = players[selected_player]
	var spent := 0
	var limit := 300 + max(0, player["slots"].size() - 3) * 200
	for skill in player["slots"]:
		if skill == null:
			continue
		while player["cash"] >= CHARGE_UNIT and spent + CHARGE_UNIT <= limit and skill["charge"] < skill["cost"]:
			player["cash"] -= CHARGE_UNIT
			spent += CHARGE_UNIT
			skill["charge"] += 1
	if spent == 0:
		_log("%s没有可充能技能或筹码不足。" % player["name"])
	else:
		_log("%s实时充能花费%d。" % [player["name"], spent])
	_refresh_ui()


func _buy_selected_skill() -> void:
	var player: Dictionary = players[selected_player]
	if selected_market_skill == "" or not skill_market.has(selected_market_skill):
		_log("没有可购买的选中技能。")
		return
	var empty_index := -1
	for i in range(player["slots"].size()):
		if player["slots"][i] == null:
			empty_index = i
			break
	if empty_index == -1:
		if player["slots"].size() >= 6:
			_log("%s已达到6个技能槽上限。" % player["name"])
			return
		if player["cash"] < 500:
			_log("%s需要500筹码开启新技能槽。" % player["name"])
			return
		player["cash"] -= 500
		player["slots"].append(null)
		empty_index = player["slots"].size() - 1
		_log("%s支付500开启新技能槽。" % player["name"])
	player["slots"][empty_index] = _make_skill(selected_market_skill)
	skill_market.erase(selected_market_skill)
	_log("%s购入技能：%s。" % [player["name"], selected_market_skill])
	selected_market_skill = skill_market[0] if not skill_market.is_empty() else ""
	_refresh_ui()


func _seize_control() -> void:
	var player: Dictionary = players[selected_player]
	var cost := min(200, player["cash"])
	if cost <= 0:
		_log("%s没有筹码夺取控制权。" % player["name"])
		return
	player["cash"] -= cost
	player["control"] += 4.0 + float(cost) / 100.0
	_log("%s投入%d筹码夺取怪兽控制权。" % [player["name"], cost])
	_refresh_ui()


func _direct_monster() -> void:
	var player: Dictionary = players[selected_player]
	if player["control"] < 1.0:
		_log("%s控制权不足，无法指挥怪兽。" % player["name"])
		return
	if districts[selected_district]["destroyed"]:
		_log("怪兽不能移动到已破坏区域。")
		return
	player["control"] = max(0.0, player["control"] - 1.0)
	if _distance(monster["position"], selected_district) <= 1:
		monster["position"] = selected_district
	else:
		monster["position"] = _next_step_toward(monster["position"], selected_district)
	_log("%s实时指挥怪兽移动至%s。" % [player["name"], districts[monster["position"]]["name"]])
	_damage_district(monster["position"], 1, "怪兽移动")
	_refresh_ui()


func _use_skill(slot_index: int) -> void:
	var player: Dictionary = players[selected_player]
	var skill = player["slots"][slot_index]
	if skill == null or skill["charge"] < skill["cost"]:
		return
	_log("%s释放%s。" % [player["name"], skill["name"]])
	match skill["kind"]:
		"bet_boost":
			_place_bet()
		"market_boost":
			_add_market_bonus(selected_district, 200)
			districts[selected_district]["panic"] = min(100, districts[selected_district]["panic"] + 12)
		"move":
			_move_monster_by_skill(skill["move"], false)
		"fly":
			_move_monster_by_skill(skill["move"], true)
		"burrow":
			_move_monster_by_skill(skill["move"], true)
			monster["armor"] += 2
			_log("怪兽获得2点护甲。")
		"attack":
			_monster_attack_guardian(skill["damage"], skill["range"], skill["name"], selected_player)
		"charge_attack":
			_move_monster_toward_guardian(skill["move"])
			_monster_attack_guardian(skill["damage"], skill["range"], skill["name"], selected_player)
		"area_damage":
			if _distance(monster["position"], selected_district) <= skill["range"]:
				_damage_district(selected_district, skill["damage"], skill["name"])
			else:
				_log("选中区域不在区域破坏射程内。")
		"miasma_shot":
			if _distance(monster["position"], guardian["position"]) <= skill["range"]:
				_guardian_take_damage(skill["damage"], skill["name"], selected_player)
			else:
				_log("守护者不在瘴气炮射程内。")
			districts[selected_district]["miasma"] = true
			_log("%s留下瘴气token。" % districts[selected_district]["name"])
	skill["charge"] = 0
	_refresh_ui()


func _move_monster_by_skill(max_steps: int, ignore_distance: bool) -> void:
	if districts[selected_district]["destroyed"]:
		_log("怪兽不能移动到已破坏区域。")
		return
	var dist := _distance(monster["position"], selected_district)
	if not ignore_distance and dist > max_steps:
		_log("选中区域距离%d，超过技能移动力%d。" % [dist, max_steps])
		return
	monster["position"] = selected_district
	_log("怪兽移动至%s。" % districts[selected_district]["name"])
	_damage_district(selected_district, 1, "怪兽移动")


func _world_event() -> void:
	var index := _random_intact_district()
	if index < 0:
		_finish_game("所有区域都已破坏。")
		return
	var d: Dictionary = districts[index]
	var heat := rng.randi_range(10, 24)
	d["panic"] = min(100, d["panic"] + heat)
	d["bonus"] += 100
	_log("新闻热度涌向%s：热度+%d，区域奖金+100。" % [d["name"], heat])
	if d["panic"] >= 100:
		d["panic"] = 60
		_damage_district(index, 1, "民众恐慌")


func _monster_tick() -> void:
	var controller := _monster_controller()
	if controller < 0:
		var target := _best_monster_target()
		if target >= 0 and target != monster["position"]:
			monster["position"] = _next_step_toward(monster["position"], target)
			_log("无人稳定操控，怪兽向%s移动。" % districts[monster["position"]]["name"])
	_damage_district(monster["position"], 1, "怪兽暴走")
	if districts[monster["position"]]["miasma"]:
		_guardian_take_damage(1, "瘴气", -1)
		districts[monster["position"]]["miasma"] = false


func _guardian_tick() -> void:
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
	if districts[guardian["position"]]["miasma"]:
		districts[guardian["position"]]["miasma"] = false
		_guardian_take_damage(1, "瘴气", -1)
	if _distance(guardian["position"], monster["position"]) <= action["range"]:
		_monster_take_damage(action["damage"], action["name"])
	else:
		_log("守护者未能进入射程，攻击落空。")
	_refresh_ui()


func _market_tick() -> void:
	var target := _highest_panic_district()
	if target < 0:
		return
	var d: Dictionary = districts[target]
	d["bonus"] += 100
	_log("博彩公司抬高%s奖金，区域奖金+100。" % d["name"])


func _decay_player_control(delta: float) -> void:
	for p in players:
		p["control"] = max(0.0, p["control"] - delta * 0.25)


func _move_guardian_until_in_range(required_range: int) -> void:
	var moved := 0
	while moved < guardian["move"] and _distance(guardian["position"], monster["position"]) > required_range:
		guardian["position"] = _next_step_toward(guardian["position"], monster["position"])
		moved += 1
	if moved > 0:
		_log("守护者移动%d格至%s。" % [moved, districts[guardian["position"]]["name"]])


func _move_monster_toward_guardian(max_steps: int) -> void:
	var moved := 0
	while moved < max_steps and _distance(monster["position"], guardian["position"]) > 1:
		monster["position"] = _next_step_toward(monster["position"], guardian["position"])
		moved += 1
		_damage_district(monster["position"], 1, "怪兽冲撞")
	if moved > 0:
		_log("怪兽追近%d格至%s。" % [moved, districts[monster["position"]]["name"]])


func _monster_attack_guardian(damage: int, range_limit: int, source: String, source_pid: int) -> void:
	if _distance(monster["position"], guardian["position"]) > range_limit:
		_log("守护者不在%s射程内。" % source)
		return
	_guardian_take_damage(damage, source, source_pid)


func _guardian_take_damage(damage: int, source: String, source_pid: int) -> void:
	guardian["hp"] -= damage
	if source_pid >= 0:
		var reward := damage * 200
		players[source_pid]["cash"] += reward
		_log("%s对守护者造成%d伤害，%s获得%d筹码。" % [source, damage, players[source_pid]["name"], reward])
	else:
		_log("%s对守护者造成%d伤害。" % [source, damage])
	if guardian["hp"] <= 0:
		_finish_game("%s被击败。" % guardian["name"])


func _monster_take_damage(damage: int, source: String) -> void:
	var reduced := max(0, damage - monster["armor"])
	if monster["armor"] > 0:
		_log("怪兽护甲抵消%d点伤害。" % min(damage, monster["armor"]))
	monster["armor"] = max(0, monster["armor"] - damage)
	monster["hp"] -= reduced
	var controller := _monster_controller()
	if controller >= 0 and reduced > 0:
		var loss: int = min(players[controller]["cash"], reduced * 100)
		players[controller]["cash"] -= loss
		_log("%s对怪兽造成%d伤害，%s支付%d筹码损失。" % [source, reduced, players[controller]["name"], loss])
	else:
		_log("%s对怪兽造成%d伤害。" % [source, reduced])
	if monster["hp"] <= 0:
		_finish_game("%s被击败。" % monster["name"])


func _damage_district(index: int, amount: int, source: String) -> void:
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		return
	d["damage"] += amount
	d["panic"] = min(100, d["panic"] + amount * 8)
	_log("%s使%s受到%d点区域伤害。" % [source, d["name"], amount])
	if d["damage"] >= d["hp"]:
		d["destroyed"] = true
		_log("%s被破坏，塌陷判断立即结算。" % d["name"])
		_settle_district(index, true)


func _add_market_bonus(index: int, amount: int) -> void:
	var d: Dictionary = districts[index]
	if d["destroyed"]:
		_log("已破坏区域不能追加奖金。")
		return
	d["bonus"] += amount
	_log("%s追加%d区域奖金。" % [d["name"], amount])


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


func _manual_settlement() -> void:
	_finish_game("手动触发最终结算。")
	_refresh_ui()


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


func _monster_controller() -> int:
	var best_pid := -1
	var best_control := 0.5
	for p in players:
		if p["control"] > best_control:
			best_pid = p["id"]
			best_control = p["control"]
	return best_pid


func _best_monster_target() -> int:
	var best_index := -1
	var best_score := -9999
	for i in range(districts.size()):
		var d: Dictionary = districts[i]
		if d["destroyed"]:
			continue
		var score: int = int(d["panic"]) + int(d["bonus"] / 20) + int(_total_bets(d) / 20)
		if score > best_score:
			best_score = score
			best_index = i
	return best_index


func _highest_panic_district() -> int:
	var best_index := -1
	var best_panic := -1
	for i in range(districts.size()):
		var d: Dictionary = districts[i]
		if d["destroyed"]:
			continue
		if int(d["panic"]) > best_panic:
			best_panic = int(d["panic"])
			best_index = i
	return best_index


func _random_intact_district() -> int:
	var options := []
	for i in range(districts.size()):
		if not districts[i]["destroyed"]:
			options.append(i)
	if options.is_empty():
		return -1
	return options[rng.randi_range(0, options.size() - 1)]


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


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var minutes := int(total / 60)
	var rest := total % 60
	return "%02d:%02d" % [minutes, rest]


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


func _log(message: String) -> void:
	var line := "[%s] %s" % [_format_time(game_time), message]
	log_lines.append(line)
	while log_lines.size() > 90:
		log_lines.pop_front()
