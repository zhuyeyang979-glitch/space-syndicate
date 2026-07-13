extends RefCounted
class_name CurrencyAmountWireV05

const CURRENCY_SCALE := 100
const MIN_CENTS := -9000000000000000
const MAX_CENTS := 9000000000000000
const LEGACY_AMOUNT_KEYS := [
	"cash",
	"bid",
	"amount",
	"available",
	"escrow",
	"ledger_delta",
	"stake",
	"price",
	"reward",
	"cost",
]


static func validate_payload(payload: Dictionary, require_transaction: bool = true) -> Dictionary:
	var errors: Array[String] = []
	var scan := _scan_value(payload, "", errors)
	if int(payload.get("currency_scale", CURRENCY_SCALE)) != CURRENCY_SCALE:
		errors.append("currency_scale_must_be_100")
	if require_transaction and int(scan.get("amount_field_count", 0)) > 0:
		if str(payload.get("transaction_id", "")).strip_edges().is_empty():
			errors.append("transaction_id_required")
	for legacy_key in LEGACY_AMOUNT_KEYS:
		if bool(scan.get("keys", {}).get(legacy_key, false)) and bool(scan.get("keys", {}).get("%s_cents" % legacy_key, false)):
			errors.append("mixed_unit_alias:%s" % legacy_key)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"currency_scale": CURRENCY_SCALE,
		"amount_field_count": int(scan.get("amount_field_count", 0)),
	}


static func validate_conservation(transaction: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var wire_result := validate_payload(transaction, true)
	if not bool(wire_result.get("valid", false)):
		errors.append_array(wire_result.get("errors", []))
	var required_keys := [
		"available_before_cents",
		"escrow_before_cents",
		"available_after_cents",
		"escrow_after_cents",
		"ledger_delta_cents",
	]
	for key in required_keys:
		if not transaction.has(key):
			errors.append("missing_conservation_field:%s" % key)
	if errors.is_empty():
		var before_total := int(transaction.available_before_cents) + int(transaction.escrow_before_cents)
		var after_total := int(transaction.available_after_cents) + int(transaction.escrow_after_cents)
		if after_total != before_total + int(transaction.ledger_delta_cents):
			errors.append("ledger_conservation_failed")
	return {"valid": errors.is_empty(), "errors": errors}


static func validate_exact_once(receipts: Array) -> Dictionary:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for receipt_variant in receipts:
		if not receipt_variant is Dictionary:
			errors.append("receipt_must_be_dictionary")
			continue
		var receipt: Dictionary = receipt_variant
		var transaction_id := str(receipt.get("transaction_id", "")).strip_edges()
		if transaction_id.is_empty():
			errors.append("transaction_id_required")
		elif seen.has(transaction_id):
			errors.append("duplicate_transaction_id:%s" % transaction_id)
		else:
			seen[transaction_id] = true
	return {"valid": errors.is_empty(), "errors": errors, "transaction_count": seen.size()}


static func round_ratio_to_cents(numerator: int, denominator: int) -> int:
	if denominator == 0:
		push_error("CurrencyAmountWireV05 denominator must not be zero")
		return 0
	var sign_value := -1 if (numerator < 0) != (denominator < 0) else 1
	var absolute_numerator := absi(numerator)
	var absolute_denominator := absi(denominator)
	var quotient := int(float(absolute_numerator) / float(absolute_denominator))
	var remainder := absolute_numerator - quotient * absolute_denominator
	if remainder * 2 >= absolute_denominator:
		quotient += 1
	return clampi(sign_value * quotient, MIN_CENTS, MAX_CENTS)


static func apply_basis_points_cents(amount_cents: int, basis_points: int) -> int:
	return round_ratio_to_cents(amount_cents * basis_points, 10000)


static func _scan_value(value: Variant, path: String, errors: Array[String]) -> Dictionary:
	var keys: Dictionary = {}
	var amount_field_count := 0
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant)
			var child_path := key if path.is_empty() else "%s.%s" % [path, key]
			keys[key] = true
			var child: Variant = value[key_variant]
			if LEGACY_AMOUNT_KEYS.has(key):
				errors.append("legacy_unsuffixed_amount:%s" % child_path)
			if key.ends_with("_cents"):
				amount_field_count += 1
				if not child is int:
					errors.append("cents_must_be_integer:%s" % child_path)
				elif int(child) < MIN_CENTS or int(child) > MAX_CENTS:
					errors.append("cents_out_of_range:%s" % child_path)
			var nested := _scan_value(child, child_path, errors)
			amount_field_count += int(nested.get("amount_field_count", 0))
			for nested_key in nested.get("keys", {}).keys():
				keys[nested_key] = true
	elif value is Array:
		for index in value.size():
			var nested := _scan_value(value[index], "%s[%d]" % [path, index], errors)
			amount_field_count += int(nested.get("amount_field_count", 0))
			for nested_key in nested.get("keys", {}).keys():
				keys[nested_key] = true
	return {"keys": keys, "amount_field_count": amount_field_count}
