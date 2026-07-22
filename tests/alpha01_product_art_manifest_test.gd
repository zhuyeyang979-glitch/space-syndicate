extends SceneTree

const MANIFEST_PATH := "res://data/art/alpha01_product_art_manifest.json"
const ALPHA_MANIFEST_PATH := "res://resources/content/alpha01/alpha01_content_manifest.tres"
const PRODUCT_CATALOG_PATH := "res://resources/content/product_industry_catalog_v05.tres"
const EXPECTED_INDUSTRIES := {
	"life": true,
	"energy": true,
	"industry": true,
	"technology": true,
	"commerce": true,
	"shipping": true,
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(parsed is Dictionary, "product-art proof manifest parses as a Dictionary")
	if not (parsed is Dictionary):
		_finish()
		return
	var manifest := parsed as Dictionary
	_expect(String(manifest.get("schema_version", "")) == "alpha01.product_art_proof.v1", "manifest schema is pinned")
	_expect(String(manifest.get("runtime_policy", "")) == "proof_only_not_connected_to_production_consumers", "proof manifest does not pretend to be a production owner")
	var generated_policy := manifest.get("generated_asset_policy", {}) as Dictionary
	_expect(String(generated_policy.get("provider", "")) == "OpenAI", "generated-art provider is explicit")
	_expect(String(generated_policy.get("model", "")) == "gpt-image-2", "generation model is explicit")
	_expect(not bool(generated_policy.get("third_party_reference_images_used", true)), "no third-party reference images were used")
	_expect(FileAccess.file_exists(String(generated_policy.get("license_path", ""))), "generated-art provenance document exists")
	_expect(FileAccess.file_exists(String(generated_policy.get("prompt_record_path", ""))), "prompt record exists")

	var alpha_manifest: Resource = load(ALPHA_MANIFEST_PATH)
	var catalog: Resource = load(PRODUCT_CATALOG_PATH)
	_expect(alpha_manifest != null and catalog != null, "authoritative Alpha and product catalog resources load")
	if alpha_manifest == null or catalog == null:
		_finish()
		return
	var alpha_product_ids: PackedStringArray = alpha_manifest.get("product_ids")
	var entries := manifest.get("entries", []) as Array
	_expect(entries.size() == 6, "proof has exactly six products")
	var product_ids := {}
	var industries := {}
	var asset_hashes := {}
	var source_hashes := {}
	for entry_variant in entries:
		_expect(entry_variant is Dictionary, "each proof entry is pure dictionary data")
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var product_id := String(entry.get("product_id", ""))
		var industry_id := String(entry.get("industry_id", ""))
		var asset_path := String(entry.get("asset_path", ""))
		var asset_sha := String(entry.get("sha256", ""))
		var source_sha := String(entry.get("source_sha256", ""))
		_expect(alpha_product_ids.has(product_id), "%s belongs to Alpha 0.1" % product_id)
		_expect(String(catalog.call("industry_for_product", product_id)) == industry_id, "%s keeps authoritative industry %s" % [product_id, industry_id])
		_expect(not product_ids.has(product_id), "product id is unique: %s" % product_id)
		_expect(not industries.has(industry_id), "industry is represented once: %s" % industry_id)
		_expect(not asset_hashes.has(asset_sha), "runtime PNG SHA is unique: %s" % product_id)
		_expect(not source_hashes.has(source_sha), "raw generated source SHA is unique: %s" % product_id)
		product_ids[product_id] = true
		industries[industry_id] = true
		asset_hashes[asset_sha] = true
		source_hashes[source_sha] = true
		_expect(asset_path.begins_with("res://assets/art/products/alpha01/proof/"), "asset stays in owned proof directory: %s" % product_id)
		_expect(FileAccess.file_exists(asset_path), "PNG exists: %s" % product_id)
		_expect(FileAccess.get_sha256(asset_path) == asset_sha, "PNG hash is pinned: %s" % product_id)
		_expect(source_sha.length() == 64, "source hash is pinned: %s" % product_id)
		_expect(String(entry.get("source_generation_id", "")).begins_with("imagegen-"), "generation id is explicit: %s" % product_id)
		_expect(String(entry.get("prompt_id", "")) != "", "prompt id is explicit: %s" % product_id)
		var texture := load(asset_path) as Texture2D
		_expect(texture != null, "PNG loads through Godot's imported Texture2D path: %s" % product_id)
		if texture == null:
			continue
		var image := texture.get_image()
		_expect(image != null and not image.is_empty(), "imported texture exposes image data: %s" % product_id)
		if image == null or image.is_empty():
			continue
		_expect(image.get_width() == 512 and image.get_height() == 512, "PNG is 512x512: %s" % product_id)
		_expect(image.get_format() == Image.FORMAT_RGBA8, "PNG imports as RGBA8: %s" % product_id)
		var alpha_range := _sample_alpha_range(image)
		_expect(alpha_range.x <= 0.01 and alpha_range.y >= 0.99, "PNG has transparent background and opaque subject: %s" % product_id)
	_expect(industries == EXPECTED_INDUSTRIES, "all six industries are represented exactly once")
	_expect(product_ids.size() == 6 and asset_hashes.size() == 6 and source_hashes.size() == 6, "six products have unique committed and source hashes")
	_finish()


func _sample_alpha_range(image: Image) -> Vector2:
	var minimum_alpha := 1.0
	var maximum_alpha := 0.0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var alpha := image.get_pixel(x, y).a
			minimum_alpha = minf(minimum_alpha, alpha)
			maximum_alpha = maxf(maximum_alpha, alpha)
	return Vector2(minimum_alpha, maximum_alpha)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ALPHA01_PRODUCT_ART_MANIFEST_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("ALPHA01_PRODUCT_ART_MANIFEST_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
