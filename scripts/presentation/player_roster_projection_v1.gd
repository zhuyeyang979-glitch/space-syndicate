extends RefCounted
class_name PlayerRosterProjectionV1

const SCHEMA_VERSION := 1
const FIELDS := ["schema_version", "source_revision", "viewer_index", "authorization_revision", "visibility_scope", "players"]
const PLAYER_FIELDS := [
	"player_index",
	"public_order_index",
	"public_player_name",
	"role_name",
	"player_color",
	"is_local_player",
	"public_status",
	"is_publicly_active",
	"public_activity_is_anonymous",
]
const FORBIDDEN_KEYS := [
	"cash", "cash_cents", "hand", "slots", "discard", "hidden_owner",
	"ai_plan", "ai_score", "future_rack", "future_track_sequence", "rng_state",
	"node", "object", "resource", "callable", "node_path", "method_name",
]


static func build(source: Dictionary) -> Dictionary:
	if not _valid_without_fingerprint(source):
		return {}
	return TablePresentationPureDataPolicy.detached_copy(source) as Dictionary


static func is_valid(value: Variant) -> bool:
	return value is Dictionary and _valid_without_fingerprint(value as Dictionary)


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if is_valid(value) else {}


static func _valid_without_fingerprint(value: Dictionary) -> bool:
	if not TablePresentationPureDataPolicy.is_pure_data(value) \
			or not _exact_fields(value, FIELDS) \
			or int(value.get("schema_version", 0)) != SCHEMA_VERSION \
			or int(value.get("source_revision", -1)) < 0 \
			or int(value.get("viewer_index", -1)) < 0 \
			or int(value.get("authorization_revision", 0)) <= 0 \
			or str(value.get("visibility_scope", "")) != "viewer_scoped_public" \
			or not (value.get("players", []) is Array) \
			or _contains_forbidden_key(value):
		return false
	var players := value.get("players", []) as Array
	if players.size() < 3 or players.size() > 8:
		return false
	var indices: Array[int] = []
	var orders: Array[int] = []
	var local_count := 0
	for row_variant in players:
		if not (row_variant is Dictionary):
			return false
		var row := row_variant as Dictionary
		if not _exact_fields(row, PLAYER_FIELDS):
			return false
		var index := int(row.get("player_index", -1))
		var order := int(row.get("public_order_index", -1))
		if index < 0 or order < 0 or index in indices or order in orders:
			return false
		indices.append(index)
		orders.append(order)
		if bool(row.get("is_local_player", false)):
			local_count += 1
			if index != int(value.get("viewer_index", -1)):
				return false
	return local_count == 1


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


static func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant).to_lower() in FORBIDDEN_KEYS \
					or _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_forbidden_key(child):
				return true
	return false
