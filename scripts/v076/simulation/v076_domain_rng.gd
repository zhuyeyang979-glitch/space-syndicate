@tool
extends RefCounted
class_name V076DomainRng

const SCHEMA_VERSION := 1
const MODULUS := 2_147_483_647
const MULTIPLIER := 48_271

var _root_seed := 1
var _domain_id := ""
var _state := 1
var _draw_count := 0


func configure(root_seed: int, domain_id: String) -> Dictionary:
	if domain_id.is_empty():
		return {"accepted": false, "reason": "rng_domain_id_empty"}
	_root_seed = root_seed
	_domain_id = domain_id
	_state = _derive_seed(root_seed, domain_id)
	_draw_count = 0
	return {"accepted": true, "reason": "", "initial_state": _state}


func next_int() -> int:
	_state = int((_state * MULTIPLIER) % MODULUS)
	if _state <= 0:
		_state += MODULUS - 1
	_draw_count += 1
	return _state


func randi_range(minimum: int, maximum: int) -> int:
	if maximum < minimum:
		return minimum
	var width := maximum - minimum + 1
	return minimum + (next_int() % width)


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"root_seed": _root_seed,
		"domain_id": _domain_id,
		"state": _state,
		"draw_count": _draw_count,
	}


func restore(snapshot_value: Dictionary) -> Dictionary:
	var field_names := ["schema_version", "root_seed", "domain_id", "state", "draw_count"]
	if snapshot_value.size() != field_names.size():
		return {"accepted": false, "reason": "rng_snapshot_field_count_mismatch"}
	for field_name in field_names:
		if not snapshot_value.has(field_name):
			return {"accepted": false, "reason": "rng_snapshot_field_missing"}
	if typeof(snapshot_value.get("schema_version")) != TYPE_INT or int(snapshot_value.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"accepted": false, "reason": "rng_snapshot_schema_mismatch"}
	if typeof(snapshot_value.get("domain_id")) != TYPE_STRING or str(snapshot_value.get("domain_id", "")) != _domain_id:
		return {"accepted": false, "reason": "rng_snapshot_domain_mismatch"}
	if typeof(snapshot_value.get("root_seed")) != TYPE_INT or int(snapshot_value.get("root_seed", 0)) != _root_seed:
		return {"accepted": false, "reason": "rng_snapshot_root_seed_mismatch"}
	if typeof(snapshot_value.get("state")) != TYPE_INT or typeof(snapshot_value.get("draw_count")) != TYPE_INT:
		return {"accepted": false, "reason": "rng_snapshot_integer_type_mismatch"}
	var candidate_state := int(snapshot_value.get("state", 0))
	var candidate_draw_count := int(snapshot_value.get("draw_count", -1))
	if candidate_state <= 0 or candidate_state >= MODULUS or candidate_draw_count < 0:
		return {"accepted": false, "reason": "rng_snapshot_value_invalid"}
	_state = candidate_state
	_draw_count = candidate_draw_count
	return {"accepted": true, "reason": ""}


static func _derive_seed(root_seed: int, domain_id: String) -> int:
	var digest := ("%d|%s" % [root_seed, domain_id]).sha256_text()
	var value := 0
	for index in range(15):
		var code := digest.unicode_at(index)
		var nibble := code - 48 if code <= 57 else code - 87
		value = (value * 16 + nibble) % (MODULUS - 1)
	return value + 1
