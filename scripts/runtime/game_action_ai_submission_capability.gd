extends RefCounted
class_name GameActionAiSubmissionCapability

# Opaque composition-time identity. This object must never cross the pure-data
# GameAction wire and deliberately exposes no serialization API.
var _owner_nonce := 0


func bind_owner_nonce(value: int) -> bool:
	if _owner_nonce != 0 or value <= 0:
		return false
	_owner_nonce = value
	return true


func matches_owner_nonce(value: int) -> bool:
	return _owner_nonce > 0 and _owner_nonce == value


func is_bound() -> bool:
	return _owner_nonce > 0
