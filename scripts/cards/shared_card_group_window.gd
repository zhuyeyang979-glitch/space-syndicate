extends RefCounted
class_name SharedCardGroupWindow

const TOTAL_SECONDS := 8.0
const ORGANIZE_SECONDS := 6.0
const LOCK_SECONDS := 2.0
const TUTORIAL_MAX_CARDS := 1
const STANDARD_MAX_CARDS := 2
const PRIORITY_BID_OPTIONS_CENTS := [0, 5000, 10000]


static func phase_for_remaining(remaining_seconds: float, lock_seconds: float = LOCK_SECONDS) -> String:
	var remaining := maxf(0.0, remaining_seconds)
	if remaining <= 0.0:
		return "closed"
	if lock_seconds > 0.0 and remaining <= lock_seconds:
		return "lock"
	return "organize"


static func submissions_open(remaining_seconds: float, lock_seconds: float = LOCK_SECONDS) -> bool:
	return phase_for_remaining(remaining_seconds, lock_seconds) == "organize"


static func bidding_open(remaining_seconds: float, lock_seconds: float = LOCK_SECONDS) -> bool:
	return submissions_open(remaining_seconds, lock_seconds)


static func group_id(window_sequence: int, player_index: int) -> String:
	return "window_%d_group_%d" % [maxi(0, window_sequence), player_index]


static func card_limit(value: int = STANDARD_MAX_CARDS) -> int:
	return clampi(value, TUTORIAL_MAX_CARDS, STANDARD_MAX_CARDS)


static func valid_priority_bid_cents(amount_cents: int) -> bool:
	return amount_cents in PRIORITY_BID_OPTIONS_CENTS


static func group_card_count(entries: Array, player_index: int) -> int:
	var count := 0
	for entry_variant in entries:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			count += 1
	return count


static func can_submit(entries: Array, player_index: int, remaining_seconds: float, max_cards: int = STANDARD_MAX_CARDS, lock_seconds: float = LOCK_SECONDS) -> Dictionary:
	var count := group_card_count(entries, player_index)
	var limit := card_limit(max_cards)
	if not submissions_open(remaining_seconds, lock_seconds):
		return {
			"allowed": false,
			"reason": "lock_phase" if phase_for_remaining(remaining_seconds, lock_seconds) == "lock" else "window_closed",
			"card_count": count,
			"card_limit": limit,
		}
	if count >= limit:
		return {
			"allowed": false,
			"reason": "group_full",
			"card_count": count,
			"card_limit": limit,
		}
	return {
		"allowed": true,
		"reason": "",
		"card_count": count,
		"card_limit": limit,
	}


static func with_priority_bid_cents(entries: Array, player_index: int, amount_cents: int) -> Array:
	var result := entries.duplicate(true)
	var bid_cents := amount_cents if valid_priority_bid_cents(amount_cents) else 0
	for index in range(result.size()):
		if not (result[index] is Dictionary):
			continue
		var entry := result[index] as Dictionary
		if int(entry.get("player_index", -1)) != player_index:
			continue
		entry["priority_bid_cents"] = bid_cents
		result[index] = entry
	return result


static func groups_from_entries(entries: Array, reference_player: int, player_count: int) -> Array:
	var by_player := {}
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := (entry_variant as Dictionary).duplicate(true)
		var player_index := int(entry.get("player_index", -1))
		if player_index < 0:
			continue
		var key := str(player_index)
		if not by_player.has(key):
			by_player[key] = {
				"group_id": str(entry.get("group_id", group_id(int(entry.get("window_sequence", 0)), player_index))),
				"player_index": player_index,
				"priority_bid_cents": _entry_priority_bid_cents(entry),
				"cards": [],
				"first_queued_order": int(entry.get("queued_order", 0)),
			}
		var group: Dictionary = by_player[key]
		group["priority_bid_cents"] = maxi(int(group.get("priority_bid_cents", 0)), _entry_priority_bid_cents(entry))
		group["first_queued_order"] = mini(int(group.get("first_queued_order", 0)), int(entry.get("queued_order", 0)))
		(group["cards"] as Array).append(entry)
		by_player[key] = group
	var groups: Array = []
	for group_variant in by_player.values():
		var group := group_variant as Dictionary
		var cards: Array = group.get("cards", []) as Array
		cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var order_a := int(a.get("group_order", a.get("queued_order", 0)))
			var order_b := int(b.get("group_order", b.get("queued_order", 0)))
			if order_a != order_b:
				return order_a < order_b
			return int(a.get("queued_order", 0)) < int(b.get("queued_order", 0))
		)
		group["cards"] = cards
		group["card_count"] = cards.size()
		groups.append(group)
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _group_precedes(a, b, reference_player, player_count)
	)
	return groups


static func flatten_groups(groups: Array) -> Array:
	var result: Array = []
	for group_index in range(groups.size()):
		if not (groups[group_index] is Dictionary):
			continue
		var group := groups[group_index] as Dictionary
		var cards: Array = group.get("cards", []) as Array
		for card_index in range(cards.size()):
			if not (cards[card_index] is Dictionary):
				continue
			var entry := (cards[card_index] as Dictionary).duplicate(true)
			entry["group_id"] = str(group.get("group_id", ""))
			entry["priority_bid_cents"] = maxi(0, int(group.get("priority_bid_cents", 0)))
			entry["group_position"] = group_index + 1
			entry["group_order"] = card_index + 1
			entry["group_size"] = cards.size()
			result.append(entry)
	return result


static func public_wager_pool_receipt(groups: Array, window_sequence: int) -> Dictionary:
	var records: Array = []
	var total_cents := 0
	for group_variant in groups:
		if not (group_variant is Dictionary):
			continue
		var group := group_variant as Dictionary
		var amount_cents := maxi(0, int(group.get("priority_bid_cents", 0)))
		total_cents += amount_cents
		records.append({
			"transaction_id": "card_group_bid.%d.%s" % [maxi(0, window_sequence), str(group.get("group_id", ""))],
			"group_id": str(group.get("group_id", "")),
			"payer_player_index": int(group.get("player_index", -1)),
			"amount_cents": amount_cents,
		})
	return {
		"receipt_id": "public_wager_pool.card_window.%d" % maxi(0, window_sequence),
		"window_sequence": maxi(0, window_sequence),
		"currency_scale": 100,
		"records": records,
		"total_cents": total_cents,
		"recipient_kind": "public_monster_wager_pool",
	}


static func public_group_snapshot(groups: Array) -> Array:
	var result: Array = []
	for index in range(groups.size()):
		if not (groups[index] is Dictionary):
			continue
		var group := groups[index] as Dictionary
		result.append({
			"group_id": str(group.get("group_id", "")),
			"group_position": index + 1,
			"card_count": int(group.get("card_count", (group.get("cards", []) as Array).size())),
			"priority_bid_cents": maxi(0, int(group.get("priority_bid_cents", 0))),
		})
	return result


static func _entry_priority_bid_cents(entry: Dictionary) -> int:
	return maxi(0, int(entry.get("priority_bid_cents", 0)))


static func _group_precedes(a: Dictionary, b: Dictionary, reference_player: int, player_count: int) -> bool:
	var bid_a := maxi(0, int(a.get("priority_bid_cents", 0)))
	var bid_b := maxi(0, int(b.get("priority_bid_cents", 0)))
	if bid_a != bid_b:
		return bid_a > bid_b
	var distance_a := _clockwise_distance(int(a.get("player_index", -1)), reference_player, player_count)
	var distance_b := _clockwise_distance(int(b.get("player_index", -1)), reference_player, player_count)
	if distance_a != distance_b:
		return distance_a < distance_b
	return int(a.get("first_queued_order", 0)) < int(b.get("first_queued_order", 0))


static func _clockwise_distance(player_index: int, reference_player: int, player_count: int) -> int:
	if player_count <= 1 or player_index < 0 or reference_player < 0:
		return maxi(0, player_index)
	if player_index == reference_player:
		return player_count
	var distance := (player_index - reference_player + player_count) % player_count
	return distance if distance > 0 else player_count
