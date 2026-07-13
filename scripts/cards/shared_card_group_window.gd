extends RefCounted
class_name SharedCardGroupWindow

const TOTAL_SECONDS := 30.0
const ORGANIZE_SECONDS := 25.0
const LOCK_SECONDS := 5.0
const DEFAULT_MAX_CARDS := 3
const EXTENDED_MAX_CARDS := 4


static func phase_for_remaining(remaining_seconds: float, lock_seconds: float = LOCK_SECONDS) -> String:
	var remaining := maxf(0.0, remaining_seconds)
	if remaining <= 0.0:
		return "closed"
	if lock_seconds > 0.0 and remaining <= lock_seconds:
		return "lock"
	return "organize"


static func submissions_open(remaining_seconds: float, lock_seconds: float = LOCK_SECONDS) -> bool:
	return phase_for_remaining(remaining_seconds, lock_seconds) == "organize"


static func bidding_open(remaining_seconds: float) -> bool:
	return remaining_seconds > 0.0


static func group_id(window_sequence: int, player_index: int) -> String:
	return "window_%d_group_%d" % [maxi(0, window_sequence), player_index]


static func card_limit(value: int = DEFAULT_MAX_CARDS) -> int:
	return clampi(value, DEFAULT_MAX_CARDS, EXTENDED_MAX_CARDS)


static func group_card_count(entries: Array, player_index: int) -> int:
	var count := 0
	for entry_variant in entries:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			count += 1
	return count


static func can_submit(entries: Array, player_index: int, remaining_seconds: float, max_cards: int = DEFAULT_MAX_CARDS, lock_seconds: float = LOCK_SECONDS) -> Dictionary:
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


static func positive_bid_taken(entries: Array, player_index: int, amount: int) -> bool:
	if amount <= 0:
		return false
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if int(entry.get("player_index", -1)) == player_index:
			continue
		if _entry_group_bid(entry) == amount:
			return true
	return false


static func with_group_bid(entries: Array, player_index: int, amount: int) -> Array:
	var result := entries.duplicate(true)
	var bid := maxi(0, amount)
	for index in range(result.size()):
		if not (result[index] is Dictionary):
			continue
		var entry := result[index] as Dictionary
		if int(entry.get("player_index", -1)) != player_index:
			continue
		entry["group_bid"] = bid
		entry["tip"] = bid
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
				"bid": _entry_group_bid(entry),
				"cards": [],
				"first_queued_order": int(entry.get("queued_order", 0)),
			}
		var group: Dictionary = by_player[key]
		group["bid"] = maxi(int(group.get("bid", 0)), _entry_group_bid(entry))
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
			entry["group_bid"] = maxi(0, int(group.get("bid", 0)))
			entry["tip"] = maxi(0, int(group.get("bid", 0)))
			entry["group_position"] = group_index + 1
			entry["group_order"] = card_index + 1
			entry["group_size"] = cards.size()
			result.append(entry)
	return result


static func bid_chain(groups: Array) -> Dictionary:
	var positive_groups: Array = []
	var zero_groups: Array = []
	for group_variant in groups:
		if not (group_variant is Dictionary):
			continue
		var group := (group_variant as Dictionary).duplicate(true)
		if int(group.get("bid", 0)) > 0:
			positive_groups.append(group)
		else:
			zero_groups.append(group)
	var records: Array = []
	var player_deltas := {}
	var public_pool := 0
	for index in range(positive_groups.size()):
		var group := positive_groups[index] as Dictionary
		var payer := int(group.get("player_index", -1))
		var amount := maxi(0, int(group.get("bid", 0)))
		player_deltas[str(payer)] = int(player_deltas.get(str(payer), 0)) - amount
		var recipient_player := -1
		var recipient_kind := "public_monster_wager_pool"
		if index == 0:
			public_pool += amount
		else:
			var previous_group := positive_groups[index - 1] as Dictionary
			recipient_player = int(previous_group.get("player_index", -1))
			recipient_kind = "previous_group"
			player_deltas[str(recipient_player)] = int(player_deltas.get(str(recipient_player), 0)) + amount
		records.append({
			"group_id": str(group.get("group_id", "")),
			"payer_player_index": payer,
			"bid": amount,
			"recipient_kind": recipient_kind,
			"recipient_player_index": recipient_player,
		})
	for group_variant in zero_groups:
		var group := group_variant as Dictionary
		records.append({
			"group_id": str(group.get("group_id", "")),
			"payer_player_index": int(group.get("player_index", -1)),
			"bid": 0,
			"recipient_kind": "none",
			"recipient_player_index": -1,
		})
	return {
		"records": records,
		"public_pool": public_pool,
		"highest_bid": public_pool,
		"player_deltas": player_deltas,
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
			"bid": maxi(0, int(group.get("bid", 0))),
		})
	return result


static func _entry_group_bid(entry: Dictionary) -> int:
	return maxi(0, int(entry.get("group_bid", entry.get("tip", 0))))


static func _group_precedes(a: Dictionary, b: Dictionary, reference_player: int, player_count: int) -> bool:
	var bid_a := maxi(0, int(a.get("bid", 0)))
	var bid_b := maxi(0, int(b.get("bid", 0)))
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
