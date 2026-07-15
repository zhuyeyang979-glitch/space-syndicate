extends RefCounted
class_name MonsterCatalogV06

const MONSTER_RAMPAGE_MOVE_METERS := 190.0
const EMBER_RING_BOMB_SELF_DAMAGE := 3
const SPECIAL_MONSTER_EARLY_ACTION_WEIGHTS := [2, 2, 2, 0, 0, 0]
const SPECIAL_MONSTER_ESCALATED_ACTION_WEIGHTS := [1, 1, 1, 1, 1, 1]

const MONSTER_ROSTER := [
	{
		"name": "孢雾海皇",
		"hp": 50,
		"armor": 0,
		"move": 190.0,
		"move_damage": 1,
		"collision_damage": 1,
		"resource_drain": 2,
		"movement_traits": ["aquatic"],
		"terrain_move_multiplier": {"ocean": 1.35, "land": 0.72},
		"style": "瘴气水栖型：生命高，海洋移动更快、陆地迟钝，会用瘴气炮和持续区域压力污染城区。",
		"resource_focus": ["深海菌毯", "梦境香氛", "孢子丝绸"],
		"summon_access": "ocean_monster_zone",
		"economy_boon": {"label": "瘴气菌毯红利", "growth_multiplier": 1.35, "route_flow_multiplier": 1.1, "text": "偏好商品会形成黑市药材需求：正向价格增速×1.35，相关商路流通×1.1。"},
		"market_skills": ["城市融资1", "城市融资2", "城市融资3", "星际广告1", "星际广告2", "星际广告3", "轨道融资1", "舆论操控1", "诱导电波1", "过载补给1", "移动2", "移动3", "普攻2", "普攻3", "格挡1", "格挡2", "区域破坏1", "区域破坏2", "区域破坏3", "飞行1", "飞行2", "重壳冲锋1", "重壳冲锋2", "甩尾1", "甩尾2", "装甲再生1", "瘴气炮1", "瘴气炮2", "瘴气结界1", "瘴气结界2", "瘴气爆发1", "瘴气爆发2", "瘴气回收1", "瘴气回收2", "瘴气回收3", "腐蚀吐息1"],
	},
	{
		"name": "砂铠陆行兽",
		"hp": 40,
		"armor": 2,
		"move": 220.0,
		"move_damage": 2,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "冲撞护甲型：初始护甲更高，会用重壳冲锋、潜行和泥石流冲散城区。",
		"resource_focus": ["重力陶瓷", "钛壳贝", "虹膜矿粉"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "地壳矿带开采潮", "growth_multiplier": 1.45, "route_flow_multiplier": 1.15, "text": "偏好矿物商品获得开采热潮：正向价格增速×1.45，相关商路流通×1.15。"},
		"market_skills": ["城市融资1", "城市融资2", "城市融资3", "星际广告1", "星际广告2", "星际广告3", "轨道融资1", "舆论操控1", "诱导电波1", "过载补给1", "移动2", "移动3", "普攻2", "普攻3", "格挡1", "格挡2", "格挡3", "区域破坏1", "区域破坏2", "区域破坏3", "重壳冲锋1", "重壳冲锋2", "重壳冲锋3", "甩尾1", "甩尾2", "装甲再生1", "咆哮1", "咆哮2", "地底潜行1", "地底潜行2", "地底潜行3", "打滚1", "打滚2", "狂奔2", "泥甲1", "泥石流1"],
	},
	{
		"name": "流星哨兵",
		"hp": 30,
		"move": 360.0,
		"move_damage": 1,
		"collision_damage": 1,
		"resource_drain": 1,
		"movement_traits": ["flying"],
		"terrain_move_multiplier": {"land": 1.18, "ocean": 1.18},
		"style": "高速飞行型：移动速度高，飞行移动不会碾压路径区域，适合标准压力局。",
		"resource_focus": ["环晶电池", "活体芯片", "轨迹墨水"],
		"summon_access": "monster_zone",
		"economy_boon": {"label": "高速航线窗口", "growth_multiplier": 1.3, "route_flow_multiplier": 1.35, "text": "偏好科技商品借高速巡航扩散：正向价格增速×1.3，相关商路流通×1.35。"},
		"special_cards": ["火花反制1", "白谱锁定1", "轨降擒投诱导1", "流星航线加速1"],
	},
	{
		"name": "棱刃重甲",
		"hp": 45,
		"move": 280.0,
		"move_damage": 1,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "重装火力型：生命更高，但追击速度较慢。",
		"resource_focus": ["离子香料", "静电蜂蜜", "等离子米"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "军需采购波", "growth_multiplier": 1.55, "route_flow_multiplier": 1.1, "text": "偏好能量食品被军需采购推高：正向价格增速×1.55，相关商路流通×1.1。"},
		"special_cards": ["裂刃预判1", "电击踢破绽1", "垂直裂刃窗口1"],
	},
	{
		"name": "绿洲修复体",
		"hp": 30,
		"move": 300.0,
		"move_damage": 1,
		"collision_damage": 1,
		"resource_drain": 0,
		"style": "防守救援型：低生命、慢追击，适合教学或低压局。",
		"resource_focus": ["光合凝胶", "轨道盆栽", "北极薄荷"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "修复光线招商", "growth_multiplier": 1.2, "route_flow_multiplier": 1.6, "text": "偏好修复商品成为避难刚需：正向价格增速×1.2，相关商路流通×1.6。"},
		"special_cards": ["修复光线干扰1", "定身闪光余波1", "修正铁拳读秒1", "修复光线招商1"],
	},
	{
		"name": "焰环幼星",
		"hp": 45,
		"move": 300.0,
		"move_damage": 1,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "近战爆发型：HP降至15或以下后启动星焰能量，移动更快且近战互伤会追加火焰。",
		"resource_focus": ["太阳鳞片", "火山番茄", "彗尾柑"],
		"summon_access": "land_monster_zone",
		"economy_boon": {"label": "星焰能源热潮", "growth_multiplier": 2.0, "route_flow_multiplier": 1.15, "text": "偏好高能商品被战场能源需求点燃：正向价格增速×2，相关商路流通×1.15。"},
		"special_cards": ["星焰能量诱导1", "飞踢落点预判1", "星焰火焰护甲1", "星焰能源热潮1"],
	},
	{
		"name": "蓝锋骑士",
		"hp": 50,
		"move": 360.0,
		"move_damage": 1,
		"collision_damage": 2,
		"resource_drain": 1,
		"style": "复仇装甲型：HP降至20或以下后穿上复仇之铠，减伤、增伤，并在移动时破坏城区。",
		"resource_focus": ["极光盐", "离岸水晶", "晨昏奶酪"],
		"summon_access": "monster_zone",
		"economy_boon": {"label": "蓝锋专利授权", "growth_multiplier": 1.65, "route_flow_multiplier": 1.35, "text": "偏好晶体/精密商品获得科技授权：正向价格增速×1.65，相关商路流通×1.35。"},
		"special_cards": ["复仇之铠过载1", "热负荷射线诱导1", "蓝锋光刃窗口1", "蓝锋专利授权1"],
	},
	{
		"name": "镜像猎兵",
		"hp": 45,
		"move": 220.0,
		"move_damage": 1,
		"collision_damage": 1,
		"resource_drain": 0,
		"style": "远程迂回型：保持中距离发射光线，近战受击时可能完美格挡并反击后撤。",
		"resource_focus": ["活体芯片", "等离子米", "轨迹墨水"],
		"summon_access": "ocean_monster_zone",
		"economy_boon": {"label": "复制兵器订单", "growth_multiplier": 1.5, "route_flow_multiplier": 1.25, "text": "偏好科技军工商品出现复制订单：正向价格增速×1.5，相关商路流通×1.25。"},
		"special_cards": ["完美格挡破绽1", "混乱光线诱导1", "迂回路线封锁1"],
	},
]

const MONSTER_ART_PROFILES := {
	"孢雾海皇": {
		"accent": Color("#a855f7"),
		"secondary": Color("#4ade80"),
		"glyph": "瘴",
		"motif": "miasma",
		"subtitle": "瘴气古龙｜海雾巢",
		"upstream_source_id": "superpowers_asset_packs_cc0",
		"visual_source_id": "superpowers_cc0_dragon_family",
		"sprite_key": "superpowers_dragon",
		"sprite_cell": "full",
	},
	"砂铠陆行兽": {
		"accent": Color("#d97706"),
		"secondary": Color("#facc15"),
		"glyph": "砂",
		"motif": "mud",
		"subtitle": "冲撞泥甲｜荒漠线",
		"upstream_source_id": "monster_battler_cc0",
		"visual_source_id": "monster_battler_cc0_rock_family",
		"sprite_key": "monster_battler_rock",
		"sprite_cell": "full",
	},
	"流星哨兵": {
		"accent": Color("#38bdf8"),
		"secondary": Color("#f87171"),
		"glyph": "杰",
		"motif": "meteor_sentinel",
		"subtitle": "高速机兵｜轨道坠星",
		"upstream_source_id": "kenney_cc0",
		"visual_source_id": "kenney_cc0_enemy_ufo_family",
		"sprite_key": "kenney_enemy_ufo",
		"sprite_cell": "full",
	},
	"棱刃重甲": {
		"accent": Color("#60a5fa"),
		"secondary": Color("#f472b6"),
		"glyph": "断",
		"motif": "prism_armor",
		"subtitle": "重装裂刃｜晶体壳",
		"upstream_source_id": "monster_battler_cc0",
		"visual_source_id": "monster_battler_cc0_dino_family",
		"sprite_key": "monster_battler_dino",
		"sprite_cell": "full",
	},
	"绿洲修复体": {
		"accent": Color("#22c55e"),
		"secondary": Color("#93c5fd"),
		"glyph": "修",
		"motif": "oasis_support",
		"subtitle": "防守救援｜绿洲核",
		"upstream_source_id": "pixelmob_cc0",
		"visual_source_id": "pixelmob_cc0_slime_square_family",
		"sprite_key": "pixelmob_slime_square",
		"sprite_cell": "0",
	},
	"焰环幼星": {
		"accent": Color("#fb7185"),
		"secondary": Color("#f97316"),
		"glyph": "炎",
		"motif": "ember_ring",
		"subtitle": "星焰幼体｜熔环",
		"upstream_source_id": "moth_kaijuice_mit",
		"visual_source_id": "moth_kaijuice_mit_kaiju_family",
		"sprite_key": "moth_kaijuice_kaiju",
		"sprite_cell": "0,0",
	},
	"蓝锋骑士": {
		"accent": Color("#06b6d4"),
		"secondary": Color("#818cf8"),
		"glyph": "刃",
		"motif": "blue_lancer",
		"subtitle": "蓝锋光刃｜复仇铠",
		"upstream_source_id": "superpowers_asset_packs_cc0",
		"visual_source_id": "superpowers_cc0_snake_family",
		"sprite_key": "superpowers_snake",
		"sprite_cell": "full",
	},
	"镜像猎兵": {
		"accent": Color("#ef4444"),
		"secondary": Color("#a3e635"),
		"glyph": "杀",
		"motif": "mirror_hunter",
		"subtitle": "远程猎兵｜镜像眼",
		"upstream_source_id": "kenney_cc0",
		"visual_source_id": "kenney_cc0_alien_blue_family",
		"sprite_key": "kenney_alien_blue",
		"sprite_cell": "full",
	},
}

const MONSTER_ACTION_TABLES := {
	"孢雾海皇": [
		{"name": "瘴气漫步", "range": 0.0, "damage": 1, "move_override": 190.0, "miasma_count": 1, "text": "自动向高热城区移动约190米，落点造成1点区域伤害并尝试留下瘴气。"},
		{"name": "腐蚀吐息", "range": 420.0, "damage": 2, "move_override": -1.0, "miasma_count": 2, "text": "420米腐蚀吐息，对目标城区造成2点压力，并在周边留下瘴气。"},
		{"name": "瘴气炮", "range": 520.0, "damage": 2, "move_override": -1.0, "miasma_count": 3, "text": "520米远程瘴气炮，沿路径污染城区并造成2点区域伤害。"},
		{"name": "瘴气结界", "range": 260.0, "damage": 1, "move_override": -1.0, "miasma_count": 4, "text": "260米范围内散布瘴气，制造持续目标偏移和区域压力。"},
		{"name": "瘴气回收", "range": 240.0, "damage": 1, "move_override": -1.0, "self_heal": 2, "text": "回收周边瘴气回复自身，并让附近城区承受1点腐蚀压力。"},
		{"name": "灾厄压迫", "range": 180.0, "damage": 3, "move_override": 160.0, "text": "向最近高价值城区压迫推进，180米内造成3点区域伤害。"},
	],
	"砂铠陆行兽": [
		{"name": "重壳冲锋", "range": 130.0, "damage": 3, "move_override": 320.0, "knockback": 260.0, "text": "自动冲向高权重城区约320米，落点和近身目标承受强力冲撞。"},
		{"name": "甩尾", "range": 160.0, "damage": 2, "move_override": -1.0, "knockback": 220.0, "text": "160米范围尾击，造成2点区域/近身伤害并击退附近怪兽。"},
		{"name": "咆哮", "range": 450.0, "damage": 1, "move_override": -1.0, "delay": 1.5, "text": "450米咆哮造成区域共享生命伤害，并拖慢下一次特殊行动节奏。"},
		{"name": "地底潜行", "range": 0.0, "damage": 1, "move_override": 340.0, "armor": 2, "text": "潜入地下移动约340米，获得2点护甲并在落点造成1点区域破坏。"},
		{"name": "打滚", "range": 140.0, "damage": 2, "move_override": 260.0, "knockback": 180.0, "text": "翻滚推进约260米，落点区域和140米内目标承受2点伤害。"},
		{"name": "泥石流", "range": 220.0, "damage": 2, "move_override": -1.0, "text": "220米范围泥石流，对区域共享生命造成2点伤害。"},
	],
	"流星哨兵": [
		{"name": "翼爪扫击", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米翼爪横扫，2伤害，并击退怪兽约120米。"},
		{"name": "俯冲肩撞", "range": 125.0, "damage": 2, "move_override": 260.0, "knockback": 150.0, "text": "短距俯冲约260米后肩撞，2伤害，并击退怪兽约150米。"},
		{"name": "火花电击", "range": 420.0, "damage": 2, "move_override": -1.0, "paralyze": 1, "text": "420米射程，2伤害，并封锁一张怪兽技能卡。"},
		{"name": "高空气旋", "range": 120.0, "damage": 2, "move_override": -1.0, "throw_radius": 420.0, "text": "120米近战投掷，2坠落伤害，并把怪兽投向420米内区域。"},
		{"name": "白谱光线", "range": 600.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "text": "600米光线，3伤害，并直线击退怪兽约320米。"},
		{"name": "轨降擒投", "range": 120.0, "damage": 4, "move_override": -1.0, "throw_radius": 320.0, "stun": 1, "text": "120米近战空投，4伤害，把怪兽摔向320米内区域并使其补给受挫。"},
	],
	"棱刃重甲": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "电击踢", "range": 120.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "paralyze": 1, "text": "120米近战AOE，2伤害，击退怪兽并封锁一张技能卡。"},
		{"name": "闪光手刀", "range": 120.0, "damage": 3, "move_override": 420.0, "paralyze": 1, "text": "高速追近420米后近战3伤害，并封锁一张技能卡。"},
		{"name": "水平裂刃", "range": 240.0, "damage": 3, "move_override": -1.0, "cripple": 1, "text": "240米射程，3伤害，并致残1张技能卡。"},
		{"name": "十字裂刃", "range": 320.0, "damage": 2, "move_override": -1.0, "cripple": 1, "stun": 1, "text": "320米射程，2伤害，并致残1张技能卡、削减技能补给。"},
		{"name": "垂直裂刃", "range": 260.0, "damage": 4, "move_override": -1.0, "cripple": 2, "text": "260米射程，4伤害，并致残2张技能卡。"},
	],
	"绿洲修复体": [
		{"name": "藤蔓掌击", "range": 110.0, "damage": 2, "move_override": -1.0, "tether": 1, "text": "110米藤蔓掌击，2伤害，并牵制怪兽下次移动。"},
		{"name": "绿洲钩拳", "range": 125.0, "damage": 2, "move_override": -1.0, "tether": 2, "text": "125米绿洲钩拳，2伤害，并施加2层牵制。"},
		{"name": "束缚光线", "range": 420.0, "damage": 2, "move_override": -1.0, "tether": 2, "text": "420米束缚光线，2伤害，并施加2层牵制。"},
		{"name": "修复光线", "range": 420.0, "damage": 3, "move_override": -1.0, "repair": 1, "text": "420米修复光线，3伤害，并修复所在区域。"},
		{"name": "定身闪光", "range": 160.0, "damage": 2, "move_override": -1.0, "repair_radius": 220.0, "tether": 4, "text": "220米修复AOE，并对160米近身目标2伤害，施加4层牵制。"},
		{"name": "修正铁拳", "range": 130.0, "damage": 5, "move_override": 560.0, "repair_path": 1, "stun_if_tethered": 3, "text": "追近560米，沿追击路径修复受损区域，对130米内目标5伤害；若怪兽被牵制则追加强眩晕。"},
	],
	"焰环幼星": [
		{"name": "普攻", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米近战AOE，2伤害，并击退怪兽约120米。"},
		{"name": "重拳", "range": 120.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "text": "120米重拳，3伤害，并击退怪兽约320米。"},
		{"name": "飞踢", "range": 140.0, "damage": 3, "move_override": 420.0, "stun": 1, "text": "向前飞踢追近420米，对140米内目标造成3近战伤害并眩晕1。"},
		{"name": "星焰斩击", "range": 240.0, "damage": 2, "close_range": 120.0, "close_damage": 3, "move_override": -1.0, "cripple": 1, "text": "120米内近战3伤害；否则240米远程2伤害，并致残1张技能牌。"},
		{"name": "星焰爆裂", "range": 320.0, "damage": 4, "move_override": -1.0, "stun": 1, "text": "320米远程爆裂，4伤害，并眩晕1。"},
		{"name": "星焰炸弹", "range": 120.0, "damage": 8, "move_override": -1.0, "stun": 2, "self_damage": EMBER_RING_BOMB_SELF_DAMAGE, "text": "120米近战爆弹，8伤害并眩晕2；之后焰环幼星承受3点反冲。"},
	],
	"蓝锋骑士": [
		{"name": "蓝锋轻斩", "range": 110.0, "damage": 2, "move_override": -1.0, "knockback": 120.0, "text": "110米轻斩AOE，2伤害，并击退怪兽约120米。"},
		{"name": "回旋刃撞", "range": 125.0, "damage": 2, "move_override": 220.0, "knockback": 160.0, "text": "回旋突进约220米，125米内造成2伤害，并击退怪兽约160米。"},
		{"name": "蓝锋斩击", "range": 240.0, "damage": 2, "close_range": 120.0, "close_damage": 3, "move_override": -1.0, "cripple": 1, "text": "120米内近战3伤害；否则240米蓝锋远斩2伤害，并致残1张技能牌。"},
		{"name": "逆刃斩击", "range": 260.0, "damage": 2, "close_range": 120.0, "close_damage": 3, "move_override": -1.0, "cripple": 1, "knockback": 140.0, "text": "260米逆刃斩击；近身3伤害，远程2伤害，并致残1张技能牌、击退约140米。"},
		{"name": "热负荷射线", "range": 420.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "stun": 1, "text": "420米热负荷射线，3伤害，直线击退怪兽约320米并眩晕1。"},
		{"name": "热负荷闪光", "range": 600.0, "damage": 1, "move_override": -1.0, "self_heal": 4, "paralyze": 2, "stun": 2, "text": "自身回复4HP；600米闪光造成1伤害，并麻痹2、眩晕2。"},
	],
	"镜像猎兵": [
		{"name": "劣质光线", "range": 420.0, "damage": 2, "move_override": -1.0, "knockback": 220.0, "chaos_ray": true, "text": "420米劣质光线，2伤害，直线击退怪兽约220米，并破坏光线路径。"},
		{"name": "折射劣光", "range": 460.0, "damage": 2, "move_override": -1.0, "knockback": 180.0, "chaos_ray": true, "text": "460米折射劣光，2伤害，斜向击退怪兽约180米，并破坏光线路径。"},
		{"name": "劣质炸弹", "range": 420.0, "damage": 3, "move_override": -1.0, "stun": 1, "text": "420米劣质炸弹，3伤害，并眩晕1。"},
		{"name": "改良光线", "range": 520.0, "damage": 3, "move_override": -1.0, "knockback": 320.0, "chaos_ray": true, "text": "520米改良光线，3伤害，直线击退怪兽约320米，并破坏光线路径。"},
		{"name": "改良炸弹", "range": 520.0, "damage": 4, "move_override": -1.0, "stun": 2, "text": "520米改良炸弹，4伤害，并眩晕2。"},
		{"name": "优质光线", "range": 600.0, "damage": 5, "move_override": -1.0, "knockback": 600.0, "chaos_ray": true, "text": "600米优质光线，5伤害，直线击退怪兽约600米，并破坏光线路径。"},
	],
}


static func roster() -> Array:
	return MONSTER_ROSTER.duplicate(true)


static func roster_names() -> Array:
	var result: Array = []
	for entry_variant: Variant in MONSTER_ROSTER:
		if entry_variant is Dictionary:
			result.append(str((entry_variant as Dictionary).get("name", "怪兽")))
	return result


static func catalog_size() -> int:
	return MONSTER_ROSTER.size()


static func catalog_entry(index: int) -> Dictionary:
	if MONSTER_ROSTER.is_empty():
		return {}
	var clamped_index := clampi(index, 0, MONSTER_ROSTER.size() - 1)
	return (MONSTER_ROSTER[clamped_index] as Dictionary).duplicate(true)


static func art_profile(monster_name: String) -> Dictionary:
	if MONSTER_ART_PROFILES.has(monster_name):
		return (MONSTER_ART_PROFILES[monster_name] as Dictionary).duplicate(true)
	return {
		"accent": Color("#94a3b8"),
		"secondary": Color("#e2e8f0"),
		"glyph": "怪",
		"motif": "beast",
		"subtitle": "自动怪兽｜星兽档案",
	}


static func catalog_move_speed(index: int) -> float:
	return float(catalog_entry(index).get("move", MONSTER_RAMPAGE_MOVE_METERS))


static func monster_catalog_index_by_name(monster_name: String) -> int:
	for i in range(MONSTER_ROSTER.size()):
		var entry: Dictionary = MONSTER_ROSTER[i]
		if str(entry.get("name", "")) == monster_name:
			return i
	return -1


static func monster_card_name(index: int, rank: int = 1) -> String:
	var entry := catalog_entry(index)
	return "怪兽·%s%d" % [str(entry.get("name", "怪兽")), clampi(rank, 1, 4)]


static func monster_card_names(rank: int = 1) -> Array:
	var result: Array = []
	for i in range(catalog_size()):
		result.append(monster_card_name(i, rank))
	return result


static func monster_technique_card_name(monster_name: String, action_index: int, rank: int = 1) -> String:
	var catalog_index := monster_catalog_index_by_name(monster_name)
	var actions := catalog_actions(catalog_index) if catalog_index >= 0 else []
	var action_name := "招式"
	if action_index >= 0 and action_index < actions.size():
		var action: Dictionary = actions[action_index]
		action_name = str(action.get("name", "招式"))
	return "兽技·%s·%02d%s%d" % [monster_name, action_index + 1, action_name, clampi(rank, 1, 4)]


static func catalog_actions(index: int) -> Array:
	var entry := catalog_entry(index)
	var monster_name := str(entry.get("name", ""))
	if MONSTER_ACTION_TABLES.has(monster_name):
		return (MONSTER_ACTION_TABLES[monster_name] as Array).duplicate(true)
	return (MONSTER_ACTION_TABLES["孢雾海皇"] as Array).duplicate(true)


static func catalog_special_cards(index: int) -> Array:
	var entry := catalog_entry(index)
	if entry.has("market_skills"):
		return (entry.get("market_skills", []) as Array).duplicate(true)
	if entry.has("special_cards"):
		return (entry.get("special_cards", []) as Array).duplicate(true)
	return []


static func catalog_action_weights(actions: Array, any_destroyed: bool) -> Array:
	var source_weights: Array = SPECIAL_MONSTER_ESCALATED_ACTION_WEIGHTS if any_destroyed else SPECIAL_MONSTER_EARLY_ACTION_WEIGHTS
	var weights: Array = []
	for i in range(actions.size()):
		weights.append(int(source_weights[i]) if i < source_weights.size() else 0)
	return weights


static func catalog_action_weights_for_index(index: int, any_destroyed: bool, weight_tables: Dictionary = {}) -> Array:
	var actions := catalog_actions(index)
	var entry := catalog_entry(index)
	var monster_name := str(entry.get("name", ""))
	var table: Dictionary = weight_tables.get(monster_name, {}) if weight_tables.has(monster_name) and weight_tables.get(monster_name, {}) is Dictionary else {}
	var weight_key := "escalated" if any_destroyed else "early"
	var source_weights: Array = table.get(weight_key, []) if table.has(weight_key) else []
	if source_weights.is_empty():
		return catalog_action_weights(actions, any_destroyed)
	var weights: Array = []
	for i in range(actions.size()):
		weights.append(int(source_weights[i]) if i < source_weights.size() else 0)
	return weights


static func ranked_action_weights(source_weights: Array, rank: int) -> Array:
	var weights := source_weights.duplicate()
	var bonus_rank: int = clampi(rank, 1, 4) - 1
	if bonus_rank <= 0:
		return weights
	for i in range(weights.size()):
		var weight := int(weights[i])
		if i >= 3:
			weight += bonus_rank * (i - 1)
		elif i >= 1:
			weight += max(0, bonus_rank - 1)
		weights[i] = weight
	return weights


static func weight_total(weights: Array) -> int:
	var total := 0
	for weight in weights:
		total += max(0, int(weight))
	return total


static func probability_text(weight: int, total: int) -> String:
	if total <= 0:
		return "0%"
	return "%.0f%%" % (float(weight) * 100.0 / float(total))


static func catalog_ranked_action_weights_for_index(index: int, any_destroyed: bool, rank: int, weight_tables: Dictionary = {}) -> Array:
	return ranked_action_weights(catalog_action_weights_for_index(index, any_destroyed, weight_tables), rank)


static func level_text(rank: int) -> String:
	return "%s级" % roman_level(rank)


static func roman_level(rank: int) -> String:
	match clampi(rank, 1, 10):
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		6:
			return "VI"
		7:
			return "VII"
		8:
			return "VIII"
		9:
			return "IX"
		10:
			return "X"
	return "I"


static func meters_text(value: float) -> String:
	if value >= 1000.0:
		return "%.1fkm" % (value / 1000.0)
	return "%.0fm" % value


static func monster_card_region_text(skill: Dictionary, compact: bool = false) -> String:
	if bool(skill.get("starter_play_free", false)):
		return "不限区" if compact else "无（起始怪兽牌）"
	match str(skill.get("summon_access", "any")):
		"monster_zone":
			return "怪区邻接" if compact else "怪兽落地区或相邻区域"
		"land_monster_zone":
			return "陆地怪区" if compact else "陆地区域，且必须是怪兽落地区或相邻区域"
		"ocean_monster_zone":
			return "海洋怪区" if compact else "海洋区域，且必须是怪兽落地区或相邻区域"
		"land":
			return "仅陆地" if compact else "仅限陆地区域"
		"ocean":
			return "仅海洋" if compact else "仅限海洋区域"
		"any", "":
			return "不限区" if compact else "无"
	return str(skill.get("summon_access", "无"))
