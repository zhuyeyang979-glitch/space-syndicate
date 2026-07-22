extends RefCounted
class_name AiBusinessCostDebitReceipt

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var request_id := ""
var request_fingerprint := ""
var accepted := false
var applied := false
var changed := false
var idempotent := false
var reason_code := ""
var player_index := -1
var debit_cents := 0
var total_cents_before := 0
var total_cents_after := 0
var reserved_cents := 0
var available_cents_before := 0
var available_cents_after := 0
var availability_fingerprint := ""
var session_revision := -1
var business_cycle_revision := -1


func detached_copy() -> AiBusinessCostDebitReceipt:
	var copy := AiBusinessCostDebitReceipt.new()
	copy.schema_version = schema_version
	copy.request_id = request_id
	copy.request_fingerprint = request_fingerprint
	copy.accepted = accepted
	copy.applied = applied
	copy.changed = changed
	copy.idempotent = idempotent
	copy.reason_code = reason_code
	copy.player_index = player_index
	copy.debit_cents = debit_cents
	copy.total_cents_before = total_cents_before
	copy.total_cents_after = total_cents_after
	copy.reserved_cents = reserved_cents
	copy.available_cents_before = available_cents_before
	copy.available_cents_after = available_cents_after
	copy.availability_fingerprint = availability_fingerprint
	copy.session_revision = session_revision
	copy.business_cycle_revision = business_cycle_revision
	return copy


func private_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"request_fingerprint": request_fingerprint,
		"accepted": accepted,
		"applied": applied,
		"changed": changed,
		"idempotent": idempotent,
		"reason_code": reason_code,
		"player_index": player_index,
		"debit_cents": debit_cents,
		"total_cents_before": total_cents_before,
		"total_cents_after": total_cents_after,
		"reserved_cents": reserved_cents,
		"available_cents_before": available_cents_before,
		"available_cents_after": available_cents_after,
		"availability_fingerprint": availability_fingerprint,
		"session_revision": session_revision,
		"business_cycle_revision": business_cycle_revision,
	}


func public_redacted_dictionary() -> Dictionary:
	# Cash authorization is private. Public business feedback comes exclusively
	# from ProductMarketRuntimeController's allowlisted public receipt.
	return {}
