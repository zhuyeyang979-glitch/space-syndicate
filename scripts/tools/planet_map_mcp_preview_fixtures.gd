extends RefCounted
class_name PlanetMapMcpPreviewFixtures

const PREVIEW_IDS := [
	"globe_overview",
	"selected_district",
	"local_zoom",
	"monster_markers",
	"trade_routes",
	"underlay_guides",
	"event_effects",
	"render_cutover",
	"empty_map_safe_state",
]


func preview_ids() -> Array[String]:
	var result: Array[String] = []
	for id in PREVIEW_IDS:
		result.append(str(id))
	return result


func preview_label(id: String) -> String:
	var labels := {
		"globe_overview": "Globe Overview",
		"selected_district": "Selected District",
		"local_zoom": "Local Zoom",
		"monster_markers": "Monster Markers",
		"trade_routes": "Trade Routes",
		"underlay_guides": "Underlay Guides",
		"event_effects": "Event Effects",
		"render_cutover": "Render Cutover",
		"empty_map_safe_state": "Empty Safe State",
	}
	return str(labels.get(id, id))


func fixture(id: String) -> Dictionary:
	match id:
		"selected_district":
			return _fixture_selected_district()
		"local_zoom":
			return _fixture_local_zoom()
		"monster_markers":
			return _fixture_monster_markers()
		"trade_routes":
			return _fixture_trade_routes()
		"underlay_guides":
			return _fixture_underlay_guides()
		"event_effects":
			return _fixture_event_effects()
		"render_cutover":
			return _fixture_render_cutover()
		"empty_map_safe_state":
			return _fixture_empty_map_safe_state()
	return _fixture_globe_overview()


func all_fixtures() -> Array:
	var result: Array = []
	for id in PREVIEW_IDS:
		result.append(fixture(id))
	return result


func _fixture_globe_overview() -> Dictionary:
	var data := _base_fixture("globe_overview", "星球总览", "默认从可读的星球总览开始，中心地图不再是空 MapHost。")
	data["selected"] = -1
	return data


func _fixture_selected_district() -> Dictionary:
	var data := _base_fixture("selected_district", "选中区域", "选区高亮、标签和区域牌架提示保持 MapView 兼容。")
	data["selected"] = 1
	data["focus_district"] = 1
	return data


func _fixture_local_zoom() -> Dictionary:
	var data := _base_fixture("local_zoom", "局部投影", "用于检查从星球总览进入局部地图后的区域标签密度。")
	data["selected"] = 2
	data["focus_district"] = 2
	data["projection"] = "local"
	return data


func _fixture_monster_markers() -> Dictionary:
	var data := _base_fixture("monster_markers", "怪兽标记", "怪兽 token、城市标记和选区高亮在同一地图组件内显示。")
	data["selected"] = 0
	data["monster_markers"] = [
		{"name": "雾港巨影", "position": [745, 310], "label": "A", "glyph": "M", "motif": "beast", "color": "#ef4444", "secondary": "#fde68a"},
		{"name": "轨道潜伏者", "position": [1035, 560], "label": "B", "glyph": "Ω", "motif": "wing", "color": "#a855f7", "secondary": "#bfdbfe"},
	]
	data["city_markers"] = _city_markers()
	return data


func _fixture_trade_routes() -> Dictionary:
	var data := _base_fixture("trade_routes", "商路网络", "商路、运输轨迹和公开产品线索在星球桌面上同时可见。")
	data["selected"] = 3
	data["trade_product"] = "ore"
	data["trade_routes"] = [
		{"product": "ore", "points": [[240, 660], [520, 610], [760, 310], [1035, 560]], "disrupted": false},
		{"product": "water", "points": [[360, 260], [520, 610], [1160, 240]], "disrupted": true},
	]
	data["movement_trails"] = [
		{"from": [240, 660], "to": [760, 310], "label": "商队", "color": "#38bdf8", "duration": 1.0, "life": 0.86},
	]
	data["city_markers"] = _city_markers()
	return data


func _fixture_event_effects() -> Dictionary:
	var data := _base_fixture("event_effects", "事件与行动反馈", "移动轨迹、事件效果和行动提示已经拆成可编辑地图子组件。")
	data["selected"] = 1
	data["focus_district"] = 1
	data["movement_trails"] = [
		{"from": [360, 260], "to": [760, 310], "label": "拦截", "color": "#facc15", "duration": 1.0, "life": 0.92},
		{"from": [1035, 560], "to": [760, 310], "label": "反击", "color": "#f97316", "duration": 1.0, "life": 0.70, "style": "card_ingress"},
	]
	data["map_event_effects"] = [
		{"kind": "laser", "from": [360, 260], "to": [760, 310], "position": [760, 310], "label": "光束", "color": "#67e8f9", "duration": 1.0, "life": 0.86, "radius_m": 86, "motion_family": "beam_line", "effect_layer": "electric_arc"},
		{"kind": "stomp", "position": [1035, 560], "from": [1035, 560], "to": [1035, 560], "label": "震荡", "color": "#f97316", "duration": 1.0, "life": 0.72, "radius_m": 96, "card_style": "route"},
	]
	data["action_callouts"] = [
		{"actor": "雾港城", "action": "公开受击", "detail": "事件效果节点在 EffectLayer 中渲染。", "color": "#67e8f9", "duration": 1.0, "life": 0.86},
		{"actor": "玩家", "action": "行动提示", "detail": "Action callout 已从 _draw 拆到可编辑面板。", "color": "#facc15", "duration": 1.0, "life": 0.74},
	]
	data["city_markers"] = _city_markers()
	return data


func _fixture_underlay_guides() -> Dictionary:
	var data := _base_fixture("underlay_guides", "底层引导层", "球体背景、轨道辅助线和焦点范围提示由可编辑 underlay 组件承接。")
	data["selected"] = 1
	data["focus_district"] = 1
	data["trade_product"] = "data"
	data["visual_layer_focus"] = "all"
	data["trade_routes"] = [
		{"product": "data", "points": [[360, 260], [760, 310], [1160, 240]], "disrupted": false},
		{"product": "fuel", "points": [[240, 660], [520, 610], [1035, 560]], "disrupted": false},
	]
	data["movement_trails"] = [
		{"from": [520, 610], "to": [760, 310], "label": "聚焦", "color": "#facc15", "duration": 1.0, "life": 0.95},
	]
	data["map_event_effects"] = [
		{"kind": "beam", "from": [1160, 240], "to": [760, 310], "position": [760, 310], "label": "校准", "color": "#38bdf8", "duration": 1.0, "life": 0.82, "radius_m": 72},
	]
	data["action_callouts"] = [
		{"actor": "地图底层", "action": "Sceneized", "detail": "Backdrop / Orbit / Focus overlay 正在使用 render model 数据桥。", "accent": "#38bdf8", "duration": 1.0, "life": 0.9},
	]
	data["monster_markers"] = [
		{"name": "轨道潜伏者", "position": [1035, 560], "label": "B", "glyph": "Ω", "motif": "wing", "color": "#a855f7", "secondary": "#bfdbfe"},
	]
	data["city_markers"] = _city_markers()
	return data


func _fixture_render_cutover() -> Dictionary:
	var data := _base_fixture("render_cutover", "渲染切换验证", "默认渲染应由可编辑地图组件承担；legacy _draw 只作为显式 fallback。")
	data["selected"] = 3
	data["focus_district"] = 3
	data["trade_product"] = "data"
	data["visual_layer_focus"] = "all"
	data["trade_routes"] = [
		{"product": "data", "points": [[240, 660], [520, 610], [760, 310], [1160, 240]], "disrupted": false},
		{"product": "fuel", "points": [[360, 260], [760, 310], [1035, 560]], "disrupted": true},
	]
	data["movement_trails"] = [
		{"from": [240, 660], "to": [760, 310], "label": "默认场景", "color": "#38bdf8", "duration": 1.0, "life": 0.94},
		{"from": [1035, 560], "to": [760, 310], "label": "fallback 关闭", "color": "#facc15", "duration": 1.0, "life": 0.78},
	]
	data["map_event_effects"] = [
		{"kind": "beam", "from": [1160, 240], "to": [760, 310], "position": [760, 310], "label": "场景层", "color": "#38bdf8", "duration": 1.0, "life": 0.9, "radius_m": 78},
		{"kind": "pulse", "position": [1035, 560], "from": [1035, 560], "to": [1035, 560], "label": "切换", "color": "#f97316", "duration": 1.0, "life": 0.72, "radius_m": 84},
	]
	data["action_callouts"] = [
		{"actor": "PlanetMapView", "action": "Sceneized primary", "detail": "scale hint / underlay / geometry / feedback 都来自可编辑组件。", "accent": "#38bdf8", "duration": 1.0, "life": 0.92},
		{"actor": "Legacy _draw", "action": "Fallback only", "detail": "默认不再重复绘制整张地图。", "accent": "#facc15", "duration": 1.0, "life": 0.84},
	]
	data["monster_markers"] = [
		{"name": "雾港巨影", "position": [745, 310], "label": "A", "glyph": "M", "motif": "beast", "color": "#ef4444", "secondary": "#fde68a"},
		{"name": "轨道潜伏者", "position": [1035, 560], "label": "B", "glyph": "Ω", "motif": "wing", "color": "#a855f7", "secondary": "#bfdbfe"},
	]
	data["city_markers"] = _city_markers()
	return data


func _fixture_empty_map_safe_state() -> Dictionary:
	return {
		"id": "empty_map_safe_state",
		"title": "空地图安全态",
		"hint": "没有地区数据时显示可编辑组件占位，而不是空白中心舞台。",
		"map_width_m": 1400,
		"map_height_m": 950,
		"selected": -1,
		"districts": [],
		"palette": ["#0ea5e9", "#22c55e", "#f59e0b", "#a855f7"],
		"projection": "globe",
		"monster_markers": [],
		"city_markers": [],
		"trade_routes": [],
		"movement_trails": [],
		"action_callouts": [],
		"map_event_effects": [],
		"trade_product": "",
		"visual_layer_focus": "all",
	}


func _base_fixture(id: String, title: String, hint: String) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"hint": hint,
		"map_width_m": 1400,
		"map_height_m": 950,
		"selected": 0,
		"districts": _districts(),
		"palette": ["#0ea5e9", "#22c55e", "#f59e0b", "#a855f7", "#14b8a6", "#f97316"],
		"projection": "globe",
		"monster_markers": [],
		"city_markers": [],
		"trade_routes": [],
		"movement_trails": [],
		"action_callouts": [
			{"title": "首轮目标", "detail": "选择区域并读右侧详情。", "accent": "#facc15"},
		],
		"map_event_effects": [],
		"trade_product": "",
		"visual_layer_focus": "all",
	}


func _districts() -> Array:
	return [
		{
			"name": "寒冠洋",
			"terrain": "ocean",
			"center": [360, 260],
			"radius_m": 84,
			"hp": 18,
			"damage": 2,
			"panic": 16,
			"products": ["ice", "water"],
			"card_choices": [{"id": "rack_ice", "label": "寒潮合同"}],
			"polygon": [[210, 160], [520, 180], [500, 340], [240, 360]],
		},
		{
			"name": "雾港城",
			"terrain": "land",
			"center": [760, 310],
			"radius_m": 78,
			"hp": 20,
			"damage": 4,
			"panic": 35,
			"products": ["ore"],
			"city": {"level": 2},
			"polygon": [[620, 220], [890, 210], [930, 390], [650, 420]],
		},
		{
			"name": "商路中继",
			"terrain": "ocean",
			"center": [520, 610],
			"radius_m": 68,
			"hp": 16,
			"damage": 1,
			"panic": 8,
			"products": ["water", "food"],
			"polygon": [[360, 500], [620, 500], [640, 700], [390, 720]],
		},
		{
			"name": "试玩罗盘",
			"terrain": "land",
			"center": [1035, 560],
			"radius_m": 74,
			"hp": 22,
			"damage": 6,
			"panic": 48,
			"products": ["data"],
			"polygon": [[900, 455], [1190, 460], [1220, 680], [940, 710]],
		},
		{
			"name": "轨道港",
			"terrain": "land",
			"center": [1160, 240],
			"radius_m": 64,
			"hp": 14,
			"damage": 0,
			"panic": 12,
			"products": ["fuel"],
			"polygon": [[1040, 130], [1300, 160], [1275, 335], [1055, 365]],
		},
		{
			"name": "黑市环礁",
			"terrain": "ocean",
			"center": [240, 660],
			"radius_m": 70,
			"hp": 17,
			"damage": 3,
			"panic": 22,
			"products": ["contraband"],
			"polygon": [[110, 540], [310, 515], [385, 690], [180, 800]],
		},
	]


func _city_markers() -> Array:
	return [
		{"position": [760, 310], "tag": "2", "level": 2, "products": ["ore"], "tag_color": "#38bdf8", "active": true},
		{"position": [1035, 560], "tag": "!", "level": 1, "products": ["data"], "tag_color": "#f97316", "active": false},
	]
