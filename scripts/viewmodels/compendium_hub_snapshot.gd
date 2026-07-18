extends RefCounted
class_name CompendiumHubSnapshot


static func compose(content_width: float) -> Dictionary:
	return {
		"title": "资料大厅",
		"title_tooltip": "图鉴入口页：把长资料集中在 Codex，不挤主桌。",
		"tooltip": "资料大厅：角色、卡牌、商品、区域与怪兽生态都在这里查看。怪兽牌属于卡牌图鉴。",
		"accent": Color("#f472b6"),
		"kpi_columns": clampi(int(floor(content_width / 310.0)), 1, 3),
		"action_columns": clampi(int(floor(content_width / 280.0)), 1, 3),
		"chips": [
			{"text": "角色/卡牌/商品", "accent": Color("#fce7f3"), "tooltip": "公开身份、卡面和商品市场都进资料库。"},
			{"text": "区域/怪兽生态", "accent": Color("#bfdbfe"), "tooltip": "区域图鉴看地图事实；生态档案看场上怪兽行为。"},
			{"text": "主桌不放长资料", "accent": Color("#fde68a"), "tooltip": "长说明只在 Codex，主桌只保留当前行动和短解释。"},
		],
		"kpis": [
			{"title": "资料边界", "body": "怪兽牌属于卡牌图鉴；怪兽生态档案看单位行为。", "meta": "卡牌/单位分开读。", "accent": Color("#fb7185")},
			{"title": "隐私边界", "body": "角色与设施所有者公开；手牌、现金、怪兽归属和内部权重不在图鉴披露。", "meta": "只读取正式公开投影。", "accent": Color("#c084fc")},
			{"title": "返回路径", "body": "进入子图鉴后，用本页返回按钮回资料大厅。", "meta": "Codex 内部导航不影响牌桌。", "accent": Color("#38bdf8")},
		],
		"action_title": "图鉴分支｜选择一个资料板",
		"actions": [
			{"id": "role", "title": "角色图鉴", "body": "查看外星辛迪加角色卡、公开身份和开局能力。", "accent": Color("#c084fc")},
			{"id": "monster", "title": "怪兽生态档案", "body": "查看场上怪兽单位的属性、公开行动类别、资源偏好和破坏数据。", "accent": Color("#fb7185")},
			{"id": "card", "title": "卡牌图鉴", "body": "查看卡面、目标、费用、升级效果和预览。", "accent": Color("#f472b6")},
			{"id": "product", "title": "商品图鉴", "body": "查看外星商品公开价格带、本局供需、天气和运输吞吐。", "accent": Color("#facc15")},
			{"id": "region", "title": "区域图鉴", "body": "查看共享区域完整度、公开设施、供需、天气、吞吐和牌源。", "accent": Color("#38bdf8")},
			{"id": "main", "title": "返回主菜单", "body": "回到星球赌桌大厅。", "accent": Color("#67e8f9")},
		],
		"footer": "资料大厅只承载长资料；主桌继续只保留当前行动、短解释和可点击入口。",
	}
