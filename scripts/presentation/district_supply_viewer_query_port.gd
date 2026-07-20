@tool
extends Node
class_name DistrictSupplyViewerQueryPort

const PUBLIC_BROWSE_ACCENT := "#94a3b8ff"

var _query_ports: TablePresentationQueryPorts
var _presentation_state: TableCardSupplyPresentationState
var _region_supply: RegionSupplyRuntimeController
var _purchase: DistrictPurchaseRuntimeController
var _pricing: CardMarketPricingRuntimeController
var _catalog: CardRuntimeCatalogService
var _card_presentation: CardPresentationRuntimeService
var _snapshot_service: DistrictSupplySnapshotService
var _inventory: CardInventoryRuntimeService
var _session: GameSessionRuntimeController
var _query_count := 0
var _private_snapshot_count := 0
var _public_snapshot_count := 0
var _rejected_query_count := 0
var _last_visibility_scope := "closed"
var _last_reason_code := ""


func configure(
	query_ports: TablePresentationQueryPorts,
	presentation_state: TableCardSupplyPresentationState,
	region_supply: RegionSupplyRuntimeController,
	purchase: DistrictPurchaseRuntimeController,
	pricing: CardMarketPricingRuntimeController,
	catalog: CardRuntimeCatalogService,
	card_presentation: CardPresentationRuntimeService,
	snapshot_service: DistrictSupplySnapshotService,
	inventory: CardInventoryRuntimeService,
	session: GameSessionRuntimeController
) -> void:
	_query_ports = query_ports
	_presentation_state = presentation_state
	_region_supply = region_supply
	_purchase = purchase
	_pricing = pricing
	_catalog = catalog
	_card_presentation = card_presentation
	_snapshot_service = snapshot_service
	_inventory = inventory
	_session = session


func snapshot_for_viewer(viewer_index: int) -> Dictionary:
	_query_count += 1
	if not _is_configured():
		return _closed_surface("district_supply_query_unconfigured", viewer_index)
	var viewer_context := _query_ports.viewer_context()
	var open_state := _presentation_state.snapshot()
	var district_index := int(open_state.get("open_district", -1))
	var subject_index := int(open_state.get("open_player", -1))
	if district_index < 0 or subject_index < 0:
		return _closed_surface("district_supply_closed", viewer_index, viewer_context.authorization_revision)
	var public_world := _query_ports.public_world_projection().to_dictionary()
	var districts: Array = public_world.get("districts", []) if public_world.get("districts", []) is Array else []
	if district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return _closed_surface("district_supply_district_invalid", viewer_index, viewer_context.authorization_revision)
	var district := districts[district_index] as Dictionary
	var region_id := str(district.get("region_id", "")).strip_edges()
	if region_id.is_empty():
		return _closed_surface("district_supply_region_missing", viewer_index, viewer_context.authorization_revision)
	var rack_row := _rack_row(region_id)
	if rack_row.is_empty():
		return _closed_surface("district_supply_rack_unavailable", viewer_index, viewer_context.authorization_revision)

	var viewer_authorized := _query_ports.can_view_private_subject(viewer_index, subject_index)
	var private_player: Dictionary = {}
	if viewer_authorized:
		var private_projection := _query_ports.private_world_projection(viewer_index, subject_index).to_dictionary()
		private_player = private_projection.get("player", {}) if private_projection.get("player", {}) is Dictionary else {}
		if private_player.is_empty():
			viewer_authorized = false
	var availability := _pricing.listing_availability(district_index)
	var availability_kind := str(availability.get("availability_kind", "invalid"))
	var previewed_card := str(open_state.get("previewed_district_card", ""))
	var listings: Array = rack_row.get("slots", []) if rack_row.get("slots", []) is Array else []
	var listed_card_ids := _listing_card_ids(listings)
	if not listed_card_ids.has(previewed_card):
		previewed_card = str(listed_card_ids[0]) if not listed_card_ids.is_empty() else ""
	var cards: Array = []
	for listing_variant in listings:
		if not (listing_variant is Dictionary):
			continue
		var listing := listing_variant as Dictionary
		var card_source := _card_source(
			listing,
			district_index,
			subject_index,
			private_player,
			viewer_authorized,
			str(listing.get("card_id", "")) == previewed_card
		)
		if not card_source.is_empty():
			cards.append(card_source)

	var source := {
		"district_index": district_index,
		"district_name": str(district.get("name", rack_row.get("display_name", "区域"))),
		"player_index": subject_index,
		"subject_player_index": subject_index,
		"viewer_player_index": viewer_index,
		"visibility_scope": "viewer_private" if viewer_authorized else "public",
		"viewer_authorized": viewer_authorized,
		"selected_card_name": previewed_card,
		"availability_kind": availability_kind,
		"availability_text": _availability_text(availability_kind),
		"local_product_names": _string_array(district.get("products", [])),
		"cards": cards,
	}
	if viewer_authorized:
		var hand_limit := _inventory.ordinary_hand_limit()
		var hand: Array = private_player.get("hand", []) if private_player.get("hand", []) is Array else []
		var purchase_window := _presentation_purchase_window(_purchase.private_ui_snapshot(viewer_index))
		if int(purchase_window.get("district_index", district_index)) != district_index:
			purchase_window = {}
		source["player_cash"] = int(private_player.get("cash", 0))
		source["counted_hand_size"] = _counted_hand_size(hand)
		source["hand_limit"] = hand_limit
		source["can_buy"] = bool(availability.get("purchasable", false)) and not _session.is_finished()
		source["purchase_window"] = purchase_window
		_private_snapshot_count += 1
	else:
		_public_snapshot_count += 1

	var drawer_snapshot := _snapshot_service.compose(source)
	if drawer_snapshot.is_empty():
		return _closed_surface("district_supply_snapshot_rejected", viewer_index, viewer_context.authorization_revision)
	_last_visibility_scope = str(source.get("visibility_scope", "public"))
	_last_reason_code = "district_supply_surface_ready"
	return {
		"schema_version": 1,
		"visible": true,
		"reason_code": _last_reason_code,
		"district_index": district_index,
		"viewer_index": viewer_index,
		"subject_player_index": subject_index,
		"authorization_revision": viewer_context.authorization_revision,
		"visibility_scope": _last_visibility_scope,
		"snapshot": drawer_snapshot,
	}


func debug_snapshot() -> Dictionary:
	return {
		"configured": _is_configured(),
		"query_count": _query_count,
		"private_snapshot_count": _private_snapshot_count,
		"public_snapshot_count": _public_snapshot_count,
		"rejected_query_count": _rejected_query_count,
		"last_visibility_scope": _last_visibility_scope,
		"last_reason_code": _last_reason_code,
		"references_main": false,
		"mutates_gameplay": false,
		"opens_market_quote": false,
		"reads_future_supply_bag": false,
		"owns_purchase_window": false,
	}


func _card_source(
	listing: Dictionary,
	district_index: int,
	player_index: int,
	private_player: Dictionary,
	viewer_authorized: bool,
	selected: bool
) -> Dictionary:
	var card_id := str(listing.get("card_id", "")).strip_edges()
	var public_card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	if card_id.is_empty() or public_card.is_empty():
		return {}
	var definition := _catalog.definition(card_id)
	if definition.is_empty():
		definition = public_card.duplicate(true)
	else:
		definition.merge(public_card, true)
	definition["name"] = card_id
	if not definition.has("text"):
		definition["text"] = str(public_card.get("effect_text", ""))
	var base_price := maxi(0, int(listing.get("price_cash", public_card.get("price_cash", 0))))
	var presentation := _card_presentation.compose_card({
		"card_name": card_id,
		"skill": definition,
		"display_name": str(public_card.get("display_name", public_card.get("name", card_id))),
		"display_text": str(public_card.get("effect_text", definition.get("text", ""))),
		"rank": _rank_number(public_card.get("rank", definition.get("rank", 1))),
		"price": base_price,
	})
	var state := _private_purchase_state(listing, district_index, player_index, private_player) \
		if viewer_authorized else _public_purchase_state(listing, district_index)
	var rank := _rank_number(public_card.get("rank", definition.get("rank", 1)))
	var theme_color := _color_hex(presentation.get("accent", Color("#94a3b8")))
	return {
		"card_name": card_id,
		"display_name": str(presentation.get("display_name", public_card.get("display_name", card_id))),
		"icon": str(presentation.get("icon", "◇")),
		"rank": rank,
		"rank_label": str(presentation.get("rank_label", _roman_rank(rank))),
		"kind": str(definition.get("kind", public_card.get("card_type", "ordinary"))),
		"persistent": bool(definition.get("persistent", false)),
		"is_upgrade": rank > 1,
		"selected": selected,
		"strategy_route": str(presentation.get("strategy_route_label", presentation.get("route_label", "通用"))),
		"purchase_state": state,
		"price": int(state.get("price", base_price)),
		"play_share_required": int(definition.get("play_share_required", definition.get("required_share_percent", 0))),
		"play_requirement_text": str(public_card.get("requirement_text", definition.get("play_requirement_text", "条件：见卡面"))),
		"play_cash_cost": int(definition.get("play_cash_cost", 0)),
		"target_kind": _target_kind(public_card, definition),
		"effect_text": str(public_card.get("effect_text", definition.get("text", ""))),
		"key_rule_facts": _string_array(presentation.get("key_rule_facts", [])),
		"art_stats": str(presentation.get("art_stats", "")),
		"theme_color": theme_color,
		"detail_tooltip": str(presentation.get("detail_tooltip", public_card.get("effect_text", ""))),
		"primary_type_label": str(presentation.get("type_label", public_card.get("card_type", "卡牌"))),
		"card_face_facts": {
			"quick_effect": str(presentation.get("quick_effect_compact", public_card.get("effect_text", ""))),
			"use_case": str(presentation.get("use_case", "")),
			"route_text": str(presentation.get("face_route_compact", presentation.get("route_label", ""))),
			"level_text": str(presentation.get("rank_label", _roman_rank(rank))),
		},
	}


func _public_purchase_state(listing: Dictionary, district_index: int) -> Dictionary:
	var preview := _listing_preview(listing, district_index)
	var price := int(preview.get("final_price", listing.get("price_cash", 0)))
	return {
		"label": "仅浏览",
		"detail": "公共牌架预览；购买资格、现金和手牌状态仅对本地真人本人显示。",
		"actionable": false,
		"requires_discard": false,
		"price": price,
		"accent": PUBLIC_BROWSE_ACCENT,
	}


func _private_purchase_state(
	listing: Dictionary,
	district_index: int,
	player_index: int,
	private_player: Dictionary
) -> Dictionary:
	var preview := _listing_preview(listing, district_index)
	var quote := _purchase.active_quote(player_index, district_index)
	if str(quote.get("card_id", "")) != str(listing.get("card_id", "")) \
			or str(quote.get("supply_revision", "")) != str(listing.get("supply_revision", "")):
		quote = {}
	var price_source := quote if not quote.is_empty() else preview
	var state := {
		"label": "仅浏览",
		"detail": "可以查看卡面；来源区域受光时才可购买。",
		"actionable": false,
		"requires_discard": false,
		"price": int(price_source.get("final_price", listing.get("price_cash", 0))),
		"accent": PUBLIC_BROWSE_ACCENT,
		"reason_code": "purchase_unavailable",
	}
	if _session.is_finished():
		return _blocked_state(state, "已结束", "本局已结束，不能购买。", "purchase_unavailable")
	var availability_kind := str(preview.get("availability_kind", "invalid"))
	if quote.is_empty():
		state["label"] = "选择以报价"
		state["detail"] = "%s 选择此牌后锁定资格与价格5个世界秒。" % _availability_text(availability_kind)
		state["reason_code"] = "market_quote_unavailable"
		return state
	if not bool(quote.get("quote_active", false)):
		return _blocked_state(state, "报价已过期", "重新选择此牌以获取新报价；界面刷新不会自动续期。", "quote_expired")
	if not bool(quote.get("eligible", false)):
		return _blocked_state(state, "仅浏览", _availability_text(str(quote.get("availability_kind", availability_kind))), _availability_reason_code(str(quote.get("availability_kind", availability_kind))))
	var price := int(state.get("price", 0))
	if int(private_player.get("cash", 0)) < price:
		return _blocked_state(state, "资金不足", "需要¥%d；当前资金不足。" % price, "cash_insufficient", "#fb7185ff")
	var receive_plan := _inventory.preview_receive(_inventory_request(private_player, listing))
	var receive_status := str(receive_plan.get("status", "rejected"))
	if receive_status == CardInventoryRuntimeService.STATUS_REJECTED:
		return _blocked_state(state, "无法接收", "可能已经达到IV级，或没有可私密弃掉的普通手牌。", "purchase_unavailable", "#fb7185ff")
	if receive_status == CardInventoryRuntimeService.STATUS_REQUIRES_DISCARD:
		state["label"] = "需弃牌"
		state["detail"] = "手牌已满；购买后会先进入私密弃牌确认。"
		state["actionable"] = true
		state["requires_discard"] = true
		state["accent"] = "#facc15ff"
		state["reason_code"] = "facility_purchase_ready"
		return state
	state["label"] = "可购买"
	state["detail"] = "%s 当前价¥%d。" % [_availability_text(availability_kind), price]
	state["actionable"] = true
	state["accent"] = "#22c55eff"
	state["reason_code"] = "facility_purchase_ready"
	return state


func _inventory_request(private_player: Dictionary, listing: Dictionary) -> Dictionary:
	var slots: Array = []
	var hand: Array = private_player.get("hand", []) if private_player.get("hand", []) is Array else []
	for card_variant in hand:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		var hand_card_id := str(card.get("card_id", card.get("name", "")))
		var hand_family := str(card.get("family_id", _catalog.family_id(hand_card_id)))
		if hand_family.is_empty():
			hand_family = hand_card_id
		var rank := maxi(1, int(card.get("rank", _catalog.rank(hand_card_id))))
		var next_upgrade := _next_upgrade(hand_family, rank)
		slots.append({
			"slot_index": int(card.get("slot_index", slots.size())),
			"occupied": true,
			"card_id": hand_card_id,
			"family": hand_family,
			"rank": rank,
			"counts_toward_hand_limit": _counts_toward_hand_limit(card),
			"queued_for_resolution": bool(card.get("queued_for_resolution", false)),
			"lock_left": float(card.get("lock_left", 0.0)),
			"next_upgrade_id": str(next_upgrade.get("card_id", "")),
			"next_upgrade_card": (next_upgrade.get("card", {}) as Dictionary).duplicate(true),
		})
	var card_id := str(listing.get("card_id", ""))
	var incoming: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	var definition := _catalog.definition(card_id)
	if not definition.is_empty():
		definition.merge(incoming, true)
		incoming = definition
	var family := str(incoming.get("family_id", _catalog.family_id(card_id)))
	if family.is_empty():
		family = card_id
	return {
		"valid": not card_id.is_empty() and not incoming.is_empty(),
		"incoming_card_id": card_id,
		"incoming_card": incoming.duplicate(true),
		"incoming_family": family,
		"incoming_rank": _rank_number(incoming.get("rank", _catalog.rank(card_id))),
		"incoming_counts_toward_hand_limit": _counts_toward_hand_limit(incoming),
		"incoming_allows_family_upgrade": true,
		"counted_hand_size": _counted_hand_size(hand),
		"hand_limit": _inventory.ordinary_hand_limit(),
		"discard_slot": -1,
		"slots": slots,
	}


func _next_upgrade(family: String, rank: int) -> Dictionary:
	for card_id_variant in _catalog.ordered_card_ids():
		var candidate_id := str(card_id_variant)
		if _catalog.family_id(candidate_id) == family and _catalog.rank(candidate_id) == rank + 1:
			return {"card_id": candidate_id, "card": _catalog.definition(candidate_id)}
	return {}


func _listing_preview(listing: Dictionary, district_index: int) -> Dictionary:
	return _pricing.preview_listing({
		"district_index": district_index,
		"card_id": str(listing.get("card_id", "")),
		"supply_revision": str(listing.get("supply_revision", "")),
		"base_price": maxi(0, int(listing.get("price_cash", 0))),
	})


func _presentation_purchase_window(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var result := {
		"state": str(source.get("state", "view_only")),
		"active": bool(source.get("active", false)),
		"requires_reselection": bool(source.get("requires_reselection", false)),
	}
	var source_quote: Dictionary = source.get("quote", {}) if source.get("quote", {}) is Dictionary else {}
	if not source_quote.is_empty():
		var quote := {}
		for key in [
			"quote_active",
			"locked_eligible",
			"eligible",
			"confirmable",
			"viewable",
			"availability_kind",
			"remaining_world_us",
			"final_price",
			"multiplier_q2",
			"same_region_alive_count",
			"directly_adjacent_alive_count",
		]:
			if source_quote.has(key):
				quote[key] = source_quote[key]
		result["quote"] = quote
	return result


func _rack_row(region_id: String) -> Dictionary:
	var rack := _region_supply.public_rack_snapshot(region_id)
	for row_variant in rack.get("regions", []) as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("region_id", "")) == region_id:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _listing_card_ids(listings: Array) -> Array[String]:
	var result: Array[String] = []
	for listing_variant in listings:
		if not (listing_variant is Dictionary):
			continue
		var card_id := str((listing_variant as Dictionary).get("card_id", ""))
		if not card_id.is_empty() and not result.has(card_id):
			result.append(card_id)
	return result


func _counted_hand_size(hand: Array) -> int:
	var count := 0
	for card_variant in hand:
		if card_variant is Dictionary and _counts_toward_hand_limit(card_variant as Dictionary):
			count += 1
	return count


func _counts_toward_hand_limit(card: Dictionary) -> bool:
	var kind := str(card.get("kind", card.get("card_type", "")))
	return not (["monster_bound_action", "military_command"].has(kind) and bool(card.get("persistent", false)))


func _target_kind(public_card: Dictionary, definition: Dictionary) -> String:
	var target_type := str(public_card.get("target_type", definition.get("target_type", ""))).to_lower()
	if target_type.contains("monster"):
		return "monster"
	if target_type.contains("player"):
		return "player"
	if target_type.contains("pair"):
		return "district_pair"
	match str(definition.get("kind", public_card.get("card_type", ""))):
		"area_trade_contract": return "district_pair"
		"monster_card": return "monster_deploy"
		"military_force": return "military_deploy"
	return "current_district"


func _availability_text(kind: String) -> String:
	match kind:
		"sunlit": return "来源区域处于日照半球：可购买；报价锁定5个世界秒。"
		"dark": return "来源区域处于暗面：可以查看，当前不可购买。"
		"destroyed": return "来源区域已摧毁：挂牌不可购买。"
	return "市场资格暂不可用。"


func _availability_reason_code(kind: String) -> String:
	match kind:
		"dark": return "source_region_dark"
		"destroyed": return "source_region_destroyed"
	return "market_unavailable"


func _blocked_state(
	state: Dictionary,
	label: String,
	detail: String,
	reason_code: String,
	accent := PUBLIC_BROWSE_ACCENT
) -> Dictionary:
	state["label"] = label
	state["detail"] = detail
	state["reason_code"] = reason_code
	state["accent"] = accent
	return state


func _rank_number(value: Variant) -> int:
	if value is int or value is float:
		return maxi(1, int(value))
	match str(value).strip_edges().to_upper():
		"II": return 2
		"III": return 3
		"IV": return 4
	return 1


func _roman_rank(rank: int) -> String:
	return ["I", "II", "III", "IV"][clampi(rank, 1, 4) - 1]


func _color_hex(value: Variant) -> String:
	if value is Color:
		return "#%s" % (value as Color).to_html(true)
	var text := str(value)
	return text if text.begins_with("#") else PUBLIC_BROWSE_ACCENT


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item_variant in value:
			var item := str(item_variant).strip_edges()
			if not item.is_empty() and not result.has(item):
				result.append(item)
	return result


func _closed_surface(reason_code: String, viewer_index := -1, authorization_revision := 0) -> Dictionary:
	_rejected_query_count += 1
	_last_visibility_scope = "closed"
	_last_reason_code = reason_code
	return {
		"schema_version": 1,
		"visible": false,
		"reason_code": reason_code,
		"district_index": -1,
		"viewer_index": viewer_index,
		"subject_player_index": -1,
		"authorization_revision": authorization_revision,
		"visibility_scope": "closed",
		"snapshot": {},
	}


func _is_configured() -> bool:
	return _query_ports != null \
		and _presentation_state != null \
		and _region_supply != null \
		and _purchase != null \
		and _pricing != null \
		and _catalog != null \
		and _card_presentation != null \
		and _snapshot_service != null \
		and _inventory != null \
		and _session != null
