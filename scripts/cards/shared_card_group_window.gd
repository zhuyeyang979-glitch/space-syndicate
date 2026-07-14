extends RefCounted
class_name SharedCardGroupWindow

const TOTAL_SECONDS := 30.0
const PLANNING_SECONDS := 20.0
const PUBLIC_BID_SECONDS := 5.0
const LOCK_SECONDS := 5.0
const OPENING_EXTENDED_WINDOWS := 3
const OPENING_TOTAL_SECONDS := 45.0
const OPENING_PLANNING_SECONDS := 35.0
const ORGANIZE_SECONDS := PLANNING_SECONDS
const TUTORIAL_MAX_CARDS := 1
const ORDINARY_MAX_CARDS := 1
const STANDARD_MAX_CARDS := ORDINARY_MAX_CARDS
const MAXIMUM_WITH_EXPLICIT_CAPABILITY := 3


static func cadence_for_sequence(window_sequence: int) -> Dictionary:
	var extended := window_sequence >= 0 and window_sequence < OPENING_EXTENDED_WINDOWS
	return {
		"window_sequence": window_sequence,
		"extended": extended,
		"total_seconds": OPENING_TOTAL_SECONDS if extended else TOTAL_SECONDS,
		"planning_seconds": OPENING_PLANNING_SECONDS if extended else PLANNING_SECONDS,
		"public_bid_seconds": PUBLIC_BID_SECONDS,
		"lock_seconds": LOCK_SECONDS,
	}


static func phase_for_remaining(remaining_seconds: float, lock_seconds: float = LOCK_SECONDS, public_bid_seconds: float = PUBLIC_BID_SECONDS) -> String:
	var remaining := maxf(0.0, remaining_seconds)
	if remaining <= 0.0:
		return "closed"
	if lock_seconds > 0.0 and remaining <= lock_seconds:
		return "lock"
	if public_bid_seconds > 0.0 and remaining <= lock_seconds + public_bid_seconds:
		return "public_bid"
	return "planning"


static func submissions_open(remaining_seconds: float, lock_seconds: float = LOCK_SECONDS, public_bid_seconds: float = PUBLIC_BID_SECONDS) -> bool:
	return phase_for_remaining(remaining_seconds, lock_seconds, public_bid_seconds) == "planning"


static func bidding_open(remaining_seconds: float, lock_seconds: float = LOCK_SECONDS, public_bid_seconds: float = PUBLIC_BID_SECONDS) -> bool:
	return phase_for_remaining(remaining_seconds, lock_seconds, public_bid_seconds) == "public_bid"


static func group_id(window_sequence: int, player_index: int) -> String:
	return "window_%d_group_%d" % [maxi(0, window_sequence), player_index]


static func card_limit(requested_max_cards: int = ORDINARY_MAX_CARDS, extra_submission_capability: Dictionary = {}) -> int:
	if not _extra_submission_capability_valid(extra_submission_capability):
		return ORDINARY_MAX_CARDS
	var capability_max := clampi(int(extra_submission_capability.get("max_cards", ORDINARY_MAX_CARDS)), ORDINARY_MAX_CARDS, MAXIMUM_WITH_EXPLICIT_CAPABILITY)
	return clampi(mini(requested_max_cards, capability_max), ORDINARY_MAX_CARDS, MAXIMUM_WITH_EXPLICIT_CAPABILITY)


static func group_card_count(entries: Array, player_index: int) -> int:
	var count := 0
	for entry_variant in entries:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("player_index", -1)) == player_index:
			count += 1
	return count


static func can_submit(entries: Array, player_index: int, remaining_seconds: float, max_cards: int = ORDINARY_MAX_CARDS, lock_seconds: float = LOCK_SECONDS, public_bid_seconds: float = PUBLIC_BID_SECONDS, extra_submission_capability: Dictionary = {}) -> Dictionary:
	var count := group_card_count(entries, player_index)
	var limit := card_limit(max_cards, extra_submission_capability)
	if not submissions_open(remaining_seconds, lock_seconds, public_bid_seconds):
		var phase := phase_for_remaining(remaining_seconds, lock_seconds, public_bid_seconds)
		return {
			"allowed": false,
			"reason": "public_bid_phase" if phase == "public_bid" else ("lock_phase" if phase == "lock" else "window_closed"),
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


static func _extra_submission_capability_valid(capability: Dictionary) -> bool:
	var capability_id := str(capability.get("extra_submission_capability", capability.get("capability_id", ""))).strip_edges()
	return not capability_id.is_empty() and int(capability.get("max_cards", ORDINARY_MAX_CARDS)) > ORDINARY_MAX_CARDS


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
				"cards": [],
				"first_queued_order": int(entry.get("queued_order", 0)),
			}
		var group: Dictionary = by_player[key]
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
			entry["group_position"] = group_index + 1
			entry["group_order"] = card_index + 1
			entry["group_size"] = cards.size()
			result.append(entry)
	return result


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
		})
	return result


static func _group_precedes(a: Dictionary, b: Dictionary, reference_player: int, player_count: int) -> bool:
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
