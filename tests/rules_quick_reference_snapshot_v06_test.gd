extends SceneTree

const RulesSnapshot := preload("res://scripts/viewmodels/rules_quick_reference_snapshot_v06.gd")
const RulesBoardScene := preload("res://scenes/ui/RulesQuickReferenceBoard.tscn")
const SNAPSHOT_SOURCE_PATH := "res://scripts/viewmodels/rules_quick_reference_snapshot_v06.gd"
const PLAYER_COPY_PATHS := [
	"res://scripts/runtime/application_flow_controller.gd",
	"res://scripts/runtime/card_presentation_runtime_service.gd",
	"res://scripts/cards/card_runtime_family_resource.gd",
	"res://scripts/runtime/card_codex_public_snapshot_service.gd",
	"res://scripts/runtime/district_supply_snapshot_service.gd",
	"res://scripts/ui/card_codex_detail.gd",
	"res://scripts/viewmodels/card_codex_detail_snapshot.gd",
	"res://scripts/ui/right_inspector.gd",
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var composer: RefCounted = RulesSnapshot.new()
	_expect(composer != null and composer.get_class() == "RefCounted", "v0.6 rules snapshot owner is data-only RefCounted")
	var snapshot: Dictionary = RulesSnapshot.compose(1120.0)
	_expect(str(snapshot.get("schema_version", "")) == "rules_quick_reference.v06", "snapshot declares the v0.6 presentation contract")
	_expect(str(snapshot.get("source_rulebook", "")) == "res://docs/tabletop_rulebook_v06.md", "snapshot points only to the authoritative v0.6 rulebook")
	_expect(str(snapshot.get("visibility_scope", "")) == "public_static_rules", "snapshot declares static public visibility")
	_expect(_is_pure_data(snapshot), "snapshot contains only serializable presentation data")
	_expect(not _contains_forbidden_key(snapshot), "snapshot contains no world, runtime, private hand, exact cash, or hidden owner fields")
	var source := FileAccess.get_file_as_string(SNAPSHOT_SOURCE_PATH)
	_expect(not source.contains("extends Node") and not source.contains("get_tree(") and not source.contains("WorldBridge") and not source.contains("players"), "snapshot source has no Node, tree, world bridge, or player-state dependency")
	var text := JSON.stringify(snapshot)
	for required in ["前 K", "至少 30%", "120 秒", "现金小于 0", "全局可查看", "区域中心受光", "日照区可买", "召唤时点完全自愿", "同区每只 +1", "相邻每只 +0.5", "最高 5x", "向上取整", "确认快照锁定资格和价格 5 秒", "主动合并", "满 5 张", "自动合并一次", "旧项目合约", "抽象路线损伤"]:
		_expect(text.contains(required), "snapshot exposes v0.6 ruled term: %s" % required)
	for retired_claim in ["重复获得会自动升级", "重复牌自动升级", "满手时私密弃一张", "现金归零会提前失败", "每名玩家必须首召", "强制首召", "全局市场始终可买", "1.00P", "1.30P", "1.75P", "己方存活怪兽"]:
		_expect(not text.contains(retired_claim), "snapshot rejects retired claim: %s" % retired_claim)
	_check_player_copy_contract()
	_check_active_document_entries()
	var board := RulesBoardScene.instantiate() as Control
	_expect(board != null and board.has_method("set_board"), "RulesQuickReferenceBoard still consumes a plain Dictionary")
	if board != null:
		root.add_child(board)
		await process_frame
		board.call("set_board", snapshot)
		await process_frame
		var rendered := _node_text(board)
		_expect(rendered.contains("v0.6 牌桌规则速览") and rendered.contains("召唤自愿") and rendered.contains("全局可查看") and rendered.contains("日照区可买") and rendered.contains("主动合并") and rendered.contains("满手领取例外"), "board renders the v0.6 snapshot without runtime input")
		var kpi_grid := board.find_child("RulesQuickReferenceKpiGrid", true, false)
		var module_grid := board.find_child("RulesQuickReferenceModuleGrid", true, false)
		_expect(kpi_grid != null and kpi_grid.get_child_count() == 8, "board renders all eight v0.6 rule cards")
		_expect(module_grid != null and module_grid.get_child_count() == 8, "board renders all eight v0.6 boundary modules")
		root.remove_child(board)
		board.queue_free()
		await process_frame
	composer = null
	_finish()


func _check_player_copy_contract() -> void:
	var combined := ""
	for path_variant: Variant in PLAYER_COPY_PATHS:
		var path := str(path_variant)
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.is_empty(), "player-copy source is readable: %s" % path)
		combined += "\n" + source
	for retired_claim in ["重复获得同系列卡自动升级", "重复获得会自动合成升级", "重复获得同系列牌会自动升级", "重复牌会升级", "满手时私密弃一张", "私密弃牌", "弃牌后购买", "需弃牌", "城市化份额吃GDP", "高阶牌检查地区GDP份额"]:
		_expect(not combined.contains(retired_claim), "non-main player copy rejects retired claim: %s" % retired_claim)
	_expect(combined.contains("同名同级牌可主动合并升级"), "ordinary player copy teaches manual same-name same-rank merge")
	_expect(FileAccess.get_file_as_string(SNAPSHOT_SOURCE_PATH).contains("高阶牌按牌面写明的公开条件检查"), "application rules copy consumes the current card-condition contract")
	var supply_source := FileAccess.get_file_as_string("res://scripts/runtime/district_supply_snapshot_service.gd")
	_expect(supply_source.contains("满5张") and supply_source.contains("合法同名可升级商品牌") and supply_source.contains("自动合并一次"), "supply-specific copy states the complete full-hand commodity exception")


func _check_active_document_entries() -> void:
	var agents := FileAccess.get_file_as_string("res://AGENTS.md")
	var readme := FileAccess.get_file_as_string("res://README.md")
	var summary := FileAccess.get_file_as_string("res://docs/rules_summary.md")
	var rulebook := FileAccess.get_file_as_string("res://docs/tabletop_rulebook_v06.md")
	var legacy_rulebook := FileAccess.get_file_as_string("res://docs/tabletop_rulebook.md")
	_expect(agents.contains("docs/tabletop_rulebook_v06.md") and agents.contains("authoritative v0.6"), "AGENTS points contributors to the v0.6 authority")
	_expect(readme.contains("## Active v0.6 Gameplay") and readme.contains("## Historical v0.4 Prototype Migration Inventory"), "README separates active v0.6 rules from the historical prototype inventory")
	var active_readme := readme.get_slice("## Historical v0.4 Prototype Migration Inventory", 0)
	_expect(active_readme.contains("summoning is entirely voluntary") and active_readme.contains("120 `world_effective` seconds") and active_readme.contains("q2 = min(10") and active_readme.contains("exactly 5 `world_effective` seconds"), "README active v0.6 section exposes voluntary summon, solar rotation, additive pricing, and quote lock")
	_expect(not active_readme.contains("first-summon prompt") and not active_readme.contains("only from a monster's current region"), "README active v0.6 section rejects historical forced-summon and regional purchase gates")
	_expect(summary.contains("tabletop_rulebook_v06.md") and summary.contains("同名、同等级普通卡由玩家主动选择合并"), "current rules summary is a v0.6 quick reference")
	_expect(summary.contains("召唤时点完全自愿") and summary.contains("每 120 秒权威自转一周") and summary.contains("怪兽按公开位置提高同区或相邻区域的牌价") and summary.contains("锁定 5 秒 `world_effective` 时间"), "rules summary exposes voluntary summon, solar rotation, position-based pricing, and quote lock")
	_expect(rulebook.contains("何时召唤完全由玩家决定") and rulebook.contains("每 120 秒完成一周权威自转") and rulebook.contains("q2 = min(10") and rulebook.contains("有效 5 秒 `world_effective` 时间"), "authoritative rulebook records the settled summon, solar, and market rules")
	_expect(not rulebook.contains("首召阶段必须") and not rulebook.contains("强制首召"), "authoritative rulebook retires mandatory first summon")
	_expect(not summary.contains("](tabletop_rulebook.md)"), "current rules summary no longer routes to the v0.4 rulebook")
	_expect(legacy_rulebook.contains("历史/迁移说明") and legacy_rulebook.contains("不再是现役玩家规则"), "legacy v0.4 rulebook is visibly retired")


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			var key := str(key_variant).to_lower()
			if key in ["world", "world_state", "runtime", "players", "hand", "private_hand", "opponent_hand", "cash", "private_cash", "cash_by_player", "owner", "owner_index", "hidden_owner", "owner_truth", "ai_private_plan"]:
				return true
			if _contains_forbidden_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _node_text(node: Node) -> String:
	var parts: Array[String] = []
	_collect_text(node, parts)
	return "\n".join(parts)


func _collect_text(node: Node, parts: Array[String]) -> void:
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		_collect_text(child, parts)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("RULES QUICK REFERENCE V06: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("RULES QUICK REFERENCE V06 PASS")
		quit(0)
		return
	printerr("RULES QUICK REFERENCE V06 FAIL: %d failure(s)" % failures.size())
	for failure in failures:
		printerr("- %s" % failure)
	quit(1)
