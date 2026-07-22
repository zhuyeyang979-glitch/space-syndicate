@tool
extends RefCounted
class_name CommodityFlowPostCommitPublicReceipt

const SCHEMA_VERSION := 1
const EVENT_KIND := "commodity_flow_sale_batch_committed"
const LOCALIZATION_KEY := "public.commodity_flow.sale_batch_committed"
const DATA_KEYS := [
	"schema_version",
	"event_kind",
	"localization_key",
	"batch_id",
	"batch_sequence",
	"batch_fingerprint",
	"flow_revision",
	"settled_at",
	"sale_count",
	"result",
	"public_status",
	"value_band",
	"receipt_fingerprint",
]

var batch_id := ""
var batch_sequence := 0
var batch_fingerprint := ""
var flow_revision := 0
var settled_at := 0.0
var sale_count := 0
var result := ""
var public_status := ""
var value_band := ""
var receipt_fingerprint := ""


static func from_committed_batch(batch: Dictionary) -> CommodityFlowPostCommitPublicReceipt:
	var receipt := CommodityFlowPostCommitPublicReceipt.new()
	var receipt_ids: Array = batch.get("receipt_ids", []) if batch.get("receipt_ids", []) is Array else []
	var receipts: Array = batch.get("receipts", []) if batch.get("receipts", []) is Array else []
	if receipt_ids.is_empty() or receipt_ids.size() != receipts.size():
		return receipt
	receipt.batch_id = str(batch.get("batch_id", ""))
	receipt.batch_sequence = int(batch.get("batch_sequence", 0))
	receipt.batch_fingerprint = str(batch.get("batch_fingerprint", ""))
	receipt.flow_revision = int(batch.get("flow_revision", 0))
	receipt.settled_at = float(batch.get("settled_at", 0.0))
	receipt.sale_count = receipt_ids.size()
	receipt.result = "committed"
	receipt.public_status = "sale_receipt"
	receipt.value_band = "single" if receipt.sale_count == 1 else "multiple"
	receipt.receipt_fingerprint = fingerprint_for_data(receipt._dictionary_without_fingerprint())
	return receipt


static func from_dictionary(data: Dictionary) -> CommodityFlowPostCommitPublicReceipt:
	var receipt := CommodityFlowPostCommitPublicReceipt.new()
	if not dictionary_shape_valid(data):
		return receipt
	receipt.batch_id = str(data.get("batch_id", ""))
	receipt.batch_sequence = int(data.get("batch_sequence", 0))
	receipt.batch_fingerprint = str(data.get("batch_fingerprint", ""))
	receipt.flow_revision = int(data.get("flow_revision", 0))
	receipt.settled_at = float(data.get("settled_at", 0.0))
	receipt.sale_count = int(data.get("sale_count", 0))
	receipt.result = str(data.get("result", ""))
	receipt.public_status = str(data.get("public_status", ""))
	receipt.value_band = str(data.get("value_band", ""))
	receipt.receipt_fingerprint = str(data.get("receipt_fingerprint", ""))
	return receipt if receipt.is_valid() else CommodityFlowPostCommitPublicReceipt.new()


static func dictionary_shape_valid(data: Dictionary) -> bool:
	if not _has_exact_keys(data, DATA_KEYS) \
			or not (data.get("schema_version") is int) \
			or not (data.get("event_kind") is String) \
			or not (data.get("localization_key") is String) \
			or not (data.get("batch_id") is String) \
			or not (data.get("batch_sequence") is int) \
			or not (data.get("batch_fingerprint") is String) \
			or not (data.get("flow_revision") is int) \
			or not (data.get("settled_at") is float) \
			or not (data.get("sale_count") is int) \
			or not (data.get("result") is String) \
			or not (data.get("public_status") is String) \
			or not (data.get("value_band") is String) \
			or not (data.get("receipt_fingerprint") is String):
		return false
	return int(data.get("schema_version", -1)) == SCHEMA_VERSION \
		and str(data.get("event_kind", "")) == EVENT_KIND \
		and str(data.get("localization_key", "")) == LOCALIZATION_KEY


func is_valid() -> bool:
	if batch_id.is_empty() or batch_sequence <= 0 or batch_fingerprint.length() != 64 \
			or flow_revision <= 0 or not is_finite(settled_at) or settled_at < 0.0 \
			or sale_count <= 0 or result != "committed" or public_status != "sale_receipt" \
			or value_band != ("single" if sale_count == 1 else "multiple") \
			or receipt_fingerprint.length() != 64:
		return false
	return receipt_fingerprint == fingerprint_for_data(_dictionary_without_fingerprint())


func matches_committed_batch(batch: Dictionary) -> bool:
	if not is_valid():
		return false
	var expected := CommodityFlowPostCommitPublicReceipt.from_committed_batch(batch)
	return expected.is_valid() and to_dictionary() == expected.to_dictionary()


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	var data := _dictionary_without_fingerprint()
	data["receipt_fingerprint"] = receipt_fingerprint
	return data


func to_public_log_receipt() -> PublicLogReceipt:
	if not is_valid():
		return null
	return PublicLogReceipt.create(
		"commodity-postcommit-public:%s:%s" % [batch_id, batch_fingerprint],
		StringName(EVENT_KIND),
		StringName(LOCALIZATION_KEY),
		{
			"result": result,
			"public_status": public_status,
			"value_band": value_band,
		},
		batch_sequence,
		settled_at
	)


static func fingerprint_for_data(data: Dictionary) -> String:
	var canonical := data.duplicate(true)
	canonical.erase("receipt_fingerprint")
	return JSON.stringify(_canonicalize(canonical)).sha256_text()


func _dictionary_without_fingerprint() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"event_kind": EVENT_KIND,
		"localization_key": LOCALIZATION_KEY,
		"batch_id": batch_id,
		"batch_sequence": batch_sequence,
		"batch_fingerprint": batch_fingerprint,
		"flow_revision": flow_revision,
		"settled_at": settled_at,
		"sale_count": sale_count,
		"result": result,
		"public_status": public_status,
		"value_band": value_band,
	}


static func _has_exact_keys(dictionary: Dictionary, expected: Array) -> bool:
	if dictionary.size() != expected.size():
		return false
	for key in expected:
		if not dictionary.has(key):
			return false
	return true


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array = source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var normalized := {}
		for key_variant in keys:
			normalized[str(key_variant)] = _canonicalize(source[key_variant])
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for child in value:
			normalized_array.append(_canonicalize(child))
		return normalized_array
	return value
