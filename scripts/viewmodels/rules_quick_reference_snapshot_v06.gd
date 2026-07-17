extends RefCounted
class_name RulesQuickReferenceSnapshotV06

const RULEBOOK_PATH := "res://docs/tabletop_rulebook_v06.md"


static func player_summary_text() -> String:
	return "\n".join([
		"读桌顺序：钱 → 城 → 牌 → 怪兽 → 线索。",
		"开局：公开角色并领取起始怪兽牌；召唤时点由你决定。",
		"赚钱：建设设施、生产商品并连接真实需求；区域控制只统计自己的商品 GDP。",
		"出牌：I 级牌是路线入口；高阶牌按牌面写明的公开条件检查，不使用旧城市份额门槛。",
		"获胜：控制本局要求的区域数，并让其中前 K 区商品 GDP 达到动态门槛。",
	])


static func compose(content_width: float = 1120.0) -> Dictionary:
	return {
		"schema_version": "rules_quick_reference.v06",
		"source_rulebook": RULEBOOK_PATH,
		"visibility_scope": "public_static_rules",
		"title": "v0.6 牌桌规则速览",
		"title_tooltip": "只呈现 v0.6 已裁决的公开规则，不读取世界状态、玩家手牌或准确现金。",
		"tooltip": "v0.6 规则速查：动态胜利、日照牌市、自愿召唤、合并、破产与已退役旧规则。",
		"accent": Color("#93c5fd"),
		"kpi_columns": clampi(int(floor(content_width / 280.0)), 1, 4),
		"module_columns": clampi(int(floor(content_width / 250.0)), 1, 4),
		"chips": [
			{"text": "控制≥30%｜前 K 区", "accent": Color("#fef3c7"), "tooltip": "区域商品 GDP 大于 0 且自己的商品 GDP 占比至少 30%，才算控制该区域。"},
			{"text": "10秒保持｜120秒审计", "accent": Color("#38bdf8"), "tooltip": "同时满足控制区数量和前 K 区商品 GDP 门槛并保持 10 秒，进入 120 秒公开审计。"},
			{"text": "现金<0｜立即破产", "accent": Color("#fb7185"), "tooltip": "原子结算后准确现金小于 0 才破产；现金恰好为 0 仍在局。"},
			{"text": "主动合并｜满手例外", "accent": Color("#c4b5fd"), "tooltip": "同名同级牌由玩家主动合并；满 5 张领取合法同名商品牌时才自动合并一次。"},
			{"text": "召唤自愿｜经营不停", "accent": Color("#67e8f9"), "tooltip": "开局持有起始怪兽牌，但召唤时点完全自愿；未召唤不阻断经济、设施或购牌。"},
			{"text": "120秒自转｜5秒锁价", "accent": Color("#4ade80"), "tooltip": "来源区域中心受光时挂牌才可买；报价确认快照锁定日照资格和价格 5 秒。"},
		],
		"kpis": [
			{"title": "区域怎样算控制？", "body": "自有商品 GDP>0，且占区域商品 GDP 至少 30%。", "meta": "设施租金不计入控制 GDP。", "accent": Color("#fef3c7")},
			{"title": "怎样进入终局？", "body": "控制至少 K 个存续区域，前 K 区自有商品 GDP 达到动态门槛。", "meta": "两项同时保持 10 秒。", "accent": Color("#38bdf8")},
			{"title": "审计怎样结算？", "body": "公开审计持续 120 秒，门槛继续随存续区域变化。", "meta": "终点仍达标才参与比较。", "accent": Color("#facc15")},
			{"title": "现金为 0 会出局吗？", "body": "不会。准确现金小于 0 才立即破产。", "meta": "现金为 0 不能进行现金购买。", "accent": Color("#fb7185")},
			{"title": "普通牌从哪里买？", "body": "全局可查看；来源区域中心受光时才可购买。", "meta": "无怪 1x｜同区每只 +1｜相邻每只 +0.5｜最高 5x。", "tooltip": "最终价向上取整；所有玩家同价；倒地或过期怪兽不计。", "accent": Color("#4ade80")},
			{"title": "怎样升级手牌？", "body": "两张同名同级普通卡由玩家主动合并，I→II→III→IV。", "meta": "IV 为上限。", "accent": Color("#c084fc")},
			{"title": "何时自动合并？", "body": "只有手牌已满 5 张，领取合法同名可升级商品牌时自动一次。", "meta": "无合法目标或目标 IV 级则领取失败。", "accent": Color("#f472b6")},
			{"title": "哪些旧规则已退役？", "body": "旧项目合约签拒链、商路牌与抽象路线损伤不再使用。", "meta": "不得作为 v0.6 新开发依据。", "accent": Color("#94a3b8")},
		],
		"keyword_title": "v0.6 数值｜先认这些边界",
		"keyword_legend": [
			{"symbol": "30%", "label": "区域控制", "body": "自有商品 GDP 占比下限", "accent": Color("#fef3c7")},
			{"symbol": "K", "label": "动态区数", "body": "按存续区域数实时计算", "accent": Color("#38bdf8")},
			{"symbol": "10s", "label": "资格保持", "body": "达标后连续保持时间", "accent": Color("#4ade80")},
			{"symbol": "120s", "label": "公开审计", "body": "终局审计持续时间", "accent": Color("#facc15")},
			{"symbol": "¥<0", "label": "破产线", "body": "现金等于 0 仍在局", "accent": Color("#fb7185")},
			{"symbol": "I+I", "label": "主动合并", "body": "同名同级合成下一等级", "accent": Color("#c084fc")},
			{"symbol": "5张", "label": "满手例外", "body": "合法商品领取才自动一次", "accent": Color("#f472b6")},
			{"symbol": "市场", "label": "日照牌市", "body": "120秒轮换｜5秒锁价", "accent": Color("#4ade80")},
		],
		"module_title": "裁决边界｜展示层只解释，不计算",
		"modules": [
			{"title": "◎ 动态区域胜利", "body": "存续区域决定 K 和总 GDP 门槛。", "meta": "废墟移出分母，重建后回归。", "accent": Color("#fef3c7")},
			{"title": "▥ 商品 GDP 控制", "body": "只统计玩家自己的商品 GDP。", "meta": "占比至少 30%。", "accent": Color("#38bdf8")},
			{"title": "⏳ 公开审计", "body": "达标保持后进入 120 秒审计。", "meta": "终点仍达标才比较。", "accent": Color("#facc15")},
			{"title": "¥ 破产", "body": "准确现金小于 0 才破产。", "meta": "现金为 0 不会提前失败。", "accent": Color("#fb7185")},
			{"title": "▤ 日照动态市场", "body": "日照区可买；全部存活怪兽按位置叠加抬价。", "meta": "确认快照锁定资格和价格 5 秒；倍率最高 5x。", "tooltip": "ceil(B × min(5, 1 + same + 0.5 × adjacent))", "accent": Color("#4ade80")},
			{"title": "⇧ 主动合并", "body": "同名同级牌由玩家选择合并。", "meta": "两张合一张，最高 IV。", "accent": Color("#c084fc")},
			{"title": "◇ 满手领取例外", "body": "满 5 张领取合法同名商品牌才自动一次。", "meta": "失败不弹卖牌或弃牌窗口。", "accent": Color("#f472b6")},
			{"title": "× 退役旧链路", "body": "旧项目合约与抽象路线损伤不再使用。", "meta": "旧 UI 和测试只能作为迁移对象。", "accent": Color("#94a3b8")},
		],
		"footer": "静态公开规则｜不读取世界状态｜不复制任何玩家手牌、准确现金或隐藏归属。",
	}
