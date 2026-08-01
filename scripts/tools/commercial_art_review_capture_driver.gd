extends RefCounted
class_name CommercialArtReviewCaptureDriver

const DEFAULT_OUTPUT_ROOT := "user://commercial_art_capture"
const REPOSITORY_OUTPUT_ROOT := "res://docs/art_qa/commercial_art"
const CATALOG_RESOURCE_PATH := "res://resources/presentation/alpha01_card_illustration_catalog.tres"
const CREDITS_DATA_PATH := "res://docs/third_party/credits_data.json"
const MINIMUM_FILE_BYTES := 4096
const MINIMUM_PIXEL_VARIANCE := 0.0005
const MINIMUM_UNIQUE_COLOR_BUCKETS := 24
const MINIMUM_VISIBLE_RATIO := 0.90

const REQUIRED_CREDIT_SECTION_IDS: Array[String] = [
	"third_party_assets",
	"licenses",
	"music",
	"fonts",
]
const REQUIRED_CREDIT_TOKENS: Array[String] = [
	"leaf swirl", "lightning electron", "cog", "circuitry",
	"receive money", "spaceship", "lorc", "delapouite",
	"game-icons.net", "cc by 3.0",
	"pondering the cosmos", "robotic city", "space graveyard", "interstellar fleet 1",
	"noto sans cjk", "oxanium",
]

const EXPECTED_FILE_NAMES: Array[String] = [
	"commercial_art_full_table_1920.png",
	"commercial_art_full_table_1366.png",
	"commercial_art_six_color_assets.png",
	"commercial_art_normal_cards.png",
	"commercial_art_commodity_cards.png",
	"commercial_art_bound_actions.png",
	"commercial_art_hand_hover.png",
	"commercial_art_hand_drag.png",
	"commercial_art_planet_day.png",
	"commercial_art_planet_night.png",
	"commercial_art_planet_zoom.png",
	"commercial_art_facilities.png",
	"commercial_art_monsters.png",
	"commercial_art_military.png",
	"commercial_art_credits.png",
]
const REQUIRED_ASSET_KEYS: Array[String] = [
	"ui.panel.primary", "ui.panel.popup", "ui.button.primary",
	"icon.asset.life", "icon.asset.energy", "icon.asset.industry",
	"icon.asset.technology", "icon.asset.commerce", "icon.asset.shipping",
	"card.frame.normal", "card.frame.commodity", "card.frame.bound_action", "card.back.normal",
	"model.facility.factory.base", "model.facility.market.base",
	"model.facility.warehouse.base", "model.facility.starport.base",
	"model.monster.life", "model.monster.energy", "model.monster.industry",
	"model.monster.technology", "model.monster.commerce", "model.monster.shipping",
	"model.military.tier1", "model.military.tier2", "model.military.tier3", "model.military.tier4",
	"model.shipping.route_marker", "model.shipping.convoy", "model.shipping.starport_showcase",
	"audio.ui.hover", "audio.ui.confirm", "audio.card.lock", "audio.card.merge", "audio.asset.refresh",
	"music.menu", "music.gameplay", "music.crisis", "music.military",
	"font.body.zh", "font.body.ja", "font.display",
]


func capture_plan() -> Array[Dictionary]:
	return [
		_spec("full_table_1920", EXPECTED_FILE_NAMES[0], Vector2i(1920, 1080)),
		_spec("full_table_1366", EXPECTED_FILE_NAMES[1], Vector2i(1366, 768)),
		_spec("six_color_assets", EXPECTED_FILE_NAMES[2], Vector2i(1920, 1080)),
		_spec("normal_cards", EXPECTED_FILE_NAMES[3], Vector2i(1920, 1080)),
		_spec("commodity_cards", EXPECTED_FILE_NAMES[4], Vector2i(1920, 1080)),
		_spec("bound_actions", EXPECTED_FILE_NAMES[5], Vector2i(1920, 1080)),
		_spec("hand_hover", EXPECTED_FILE_NAMES[6], Vector2i(1920, 1080)),
		_spec("hand_drag", EXPECTED_FILE_NAMES[7], Vector2i(1920, 1080)),
		_spec("planet_day", EXPECTED_FILE_NAMES[8], Vector2i(1920, 1080)),
		_spec("planet_night", EXPECTED_FILE_NAMES[9], Vector2i(1920, 1080)),
		_spec("planet_zoom", EXPECTED_FILE_NAMES[10], Vector2i(1920, 1080)),
		_spec("facilities", EXPECTED_FILE_NAMES[11], Vector2i(1920, 1080)),
		_spec("monsters", EXPECTED_FILE_NAMES[12], Vector2i(1920, 1080)),
		_spec("military", EXPECTED_FILE_NAMES[13], Vector2i(1920, 1080)),
		_spec("credits", EXPECTED_FILE_NAMES[14], Vector2i(1920, 1080)),
	]


func plan_validation_report() -> Dictionary:
	var plan := capture_plan()
	var errors: Array[String] = []
	var names: Array[String] = []
	var ids: Array[String] = []
	for index in range(plan.size()):
		var spec := plan[index]
		var capture_id := str(spec.get("capture_id", ""))
		var file_name := str(spec.get("file_name", ""))
		var viewport_size: Variant = spec.get("viewport_size")
		if capture_id.is_empty() or ids.has(capture_id):
			errors.append("capture_id_invalid:%d" % index)
		if file_name != EXPECTED_FILE_NAMES[index] or names.has(file_name) \
				or file_name.get_file() != file_name or not file_name.ends_with(".png"):
			errors.append("capture_file_name_invalid:%d" % index)
		if not (viewport_size is Vector2i) \
				or (viewport_size as Vector2i) not in [Vector2i(1920, 1080), Vector2i(1366, 768)]:
			errors.append("capture_viewport_size_invalid:%d" % index)
		ids.append(capture_id)
		names.append(file_name)
	if names != EXPECTED_FILE_NAMES:
		errors.append("capture_file_order_invalid")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"capture_count": plan.size(),
		"file_names": names,
		"capture_ids": ids,
		"supports_1920x1080": plan.any(func(row: Dictionary) -> bool: return row.get("viewport_size") == Vector2i(1920, 1080)),
		"supports_1366x768": plan.any(func(row: Dictionary) -> bool: return row.get("viewport_size") == Vector2i(1366, 768)),
		"placeholder_capture_allowed": false,
	}


func lightweight_capture_preflight() -> Dictionary:
	var plan := plan_validation_report()
	var catalog_text := _catalog_text_contract_preflight()
	var credits := _credits_data_preflight()
	var errors: Array[String] = []
	if not bool(plan.get("valid", false)):
		errors.append("capture_plan_invalid")
	if not bool(catalog_text.get("ready", false)):
		errors.append(str(catalog_text.get("reason_code", "catalog_text_contract_invalid")))
	if not bool(credits.get("ready", false)):
		errors.append(str(credits.get("reason_code", "credits_data_invalid")))
	return {
		"ready": errors.is_empty(),
		"primary_reason_code": "ok" if errors.is_empty() else errors[0],
		"errors": errors,
		"plan": plan,
		"catalog_text_contract": catalog_text,
		"credits_data": credits,
		"heavy_resource_load_authorized": errors.is_empty(),
		"screenshot_write_authorized": false,
		"placeholder_capture_allowed": false,
	}


func catalog_binding_preflight() -> Dictionary:
	var catalog := load(CATALOG_RESOURCE_PATH) as Resource
	var missing_keys: Array[String] = []
	var resources: Array[Resource] = []
	var generic_api_ready := catalog != null and catalog.has_method("resource_for_asset_key")
	if generic_api_ready:
		for asset_key in REQUIRED_ASSET_KEYS:
			var value: Variant = catalog.call("resource_for_asset_key", StringName(asset_key))
			if value is Resource:
				resources.append(value as Resource)
			else:
				missing_keys.append(asset_key)
	else:
		missing_keys.append_array(REQUIRED_ASSET_KEYS)
	var type_counts := _resource_type_counts(resources)
	var types_valid := int(type_counts.get("Texture2D", -1)) == 13 \
		and int(type_counts.get("PackedScene", -1)) == 17 \
		and int(type_counts.get("AudioStream", -1)) == 9 \
		and int(type_counts.get("Font", -1)) == 3 \
		and int(type_counts.get("other", -1)) == 0
	var ready := generic_api_ready and missing_keys.is_empty() \
		and resources.size() == REQUIRED_ASSET_KEYS.size() and types_valid
	return {
		"ready": ready,
		"primary_reason_code": "ok" if ready else (
			"catalog_generic_api_missing" if not generic_api_ready \
			else ("unresolved_presentation_asset_keys" if not missing_keys.is_empty() \
			else "stable_asset_resource_type_mismatch")
		),
		"catalog_resource_path": CATALOG_RESOURCE_PATH,
		"catalog_loaded": catalog != null,
		"catalog_generic_api_ready": generic_api_ready,
		"required_asset_key_count": REQUIRED_ASSET_KEYS.size(),
		"resolved_asset_key_count": resources.size(),
		"missing_asset_key_count": missing_keys.size(),
		"missing_asset_keys": missing_keys,
		"resource_type_counts": type_counts,
		"screenshot_write_authorized": ready,
		"review_scene_instantiation_required": ready,
		"placeholder_capture_allowed": false,
	}


func capture_preflight(review: Control) -> Dictionary:
	var plan_report := plan_validation_report()
	var errors: Array[String] = []
	if not bool(plan_report.get("valid", false)):
		errors.append("capture_plan_invalid")
	if review == null or not review.has_method("debug_snapshot") \
			or not review.has_method("prepare_capture_state"):
		errors.append("review_capture_api_missing")
		return _preflight_result(errors, {}, plan_report)
	var snapshot_variant: Variant = review.call("debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var required := int(snapshot.get("required_asset_key_count", -1))
	var resolved := int(snapshot.get("resolved_asset_key_count", -1))
	var missing := int(snapshot.get("missing_asset_key_count", -1))
	if not bool(snapshot.get("catalog_generic_api_ready", false)):
		errors.append("catalog_generic_api_missing")
	if required != 42 or resolved != 42 or missing != 0:
		errors.append("unresolved_presentation_asset_keys")
	var type_counts: Dictionary = snapshot.get("resolved_resource_type_counts", {}) \
		if snapshot.get("resolved_resource_type_counts") is Dictionary else {}
	if int(type_counts.get("Texture2D", -1)) != 13 \
			or int(type_counts.get("PackedScene", -1)) != 17 \
			or int(type_counts.get("AudioStream", -1)) != 9 \
			or int(type_counts.get("Font", -1)) != 3 \
			or int(type_counts.get("other", -1)) != 0:
		errors.append("stable_asset_resource_type_mismatch")
	if resolved == 42 and int(snapshot.get("instantiated_model_preview_count", -1)) != 17:
		errors.append("model_previews_incomplete")
	if int(snapshot.get("credits_placeholder_count", -1)) != 0:
		errors.append("credits_placeholder_capture_forbidden")
	var planet: Dictionary = snapshot.get("planet", {}) if snapshot.get("planet") is Dictionary else {}
	if not bool(planet.get("planet_opaque", false)) \
			or not bool(planet.get("back_face_culling", false)) \
			or not bool(planet.get("depth_test", false)) \
			or int(planet.get("backside_region_marker_visible_count", -1)) != 0 \
			or int(planet.get("backside_facility_visible_count", -1)) != 0 \
			or int(planet.get("outer_orbit_decoration_count", -1)) != 0:
		errors.append("planet_capture_contract_invalid")
	for field in ["creates_session", "writes_save"]:
		if bool(snapshot.get(field, true)):
			errors.append("review_authority_boundary_invalid:%s" % field)
	for field in ["rng_draw_count", "gameplay_mutation_count", "production_connection_count", "main_reference_count"]:
		if int(snapshot.get(field, -1)) != 0:
			errors.append("review_authority_boundary_invalid:%s" % field)
	return _preflight_result(errors, snapshot, plan_report)


func image_metrics(image: Image, expected_size: Vector2i) -> Dictionary:
	if image == null or image.is_empty():
		return {
			"valid": false,
			"reason_code": "capture_image_empty",
			"width": 0,
			"height": 0,
			"pixel_variance": 0.0,
			"sample_count": 0,
		}
	var width := image.get_width()
	var height := image.get_height()
	var step_x := maxi(1, width / 64)
	var step_y := maxi(1, height / 36)
	var sample_count := 0
	var visible_count := 0
	var luminance_sum := 0.0
	var luminance_squared_sum := 0.0
	var color_buckets: Dictionary = {}
	for y in range(0, height, step_y):
		for x in range(0, width, step_x):
			var color := image.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			luminance_sum += luminance
			luminance_squared_sum += luminance * luminance
			sample_count += 1
			if color.a >= 0.05:
				visible_count += 1
			var bucket := "%02x%02x%02x" % [
				int(round(color.r * 15.0)),
				int(round(color.g * 15.0)),
				int(round(color.b * 15.0)),
			]
			color_buckets[bucket] = true
	var mean := luminance_sum / float(sample_count) if sample_count > 0 else 0.0
	var variance := maxf(
		0.0,
		luminance_squared_sum / float(sample_count) - mean * mean
	) if sample_count > 0 else 0.0
	var visible_ratio := float(visible_count) / float(sample_count) if sample_count > 0 else 0.0
	var size_matches := Vector2i(width, height) == expected_size
	var valid := size_matches \
		and sample_count >= 512 \
		and visible_ratio >= MINIMUM_VISIBLE_RATIO \
		and mean >= 0.015 and mean <= 0.985 \
		and variance >= MINIMUM_PIXEL_VARIANCE \
		and color_buckets.size() >= MINIMUM_UNIQUE_COLOR_BUCKETS
	return {
		"valid": valid,
		"reason_code": "ok" if valid else "capture_pixel_quality_invalid",
		"width": width,
		"height": height,
		"expected_width": expected_size.x,
		"expected_height": expected_size.y,
		"size_matches": size_matches,
		"sample_count": sample_count,
		"visible_pixel_ratio": visible_ratio,
		"mean_luminance": mean,
		"pixel_variance": variance,
		"unique_color_bucket_count": color_buckets.size(),
	}


func save_and_validate_capture(image: Image, output_path: String, expected_size: Vector2i) -> Dictionary:
	var pre_save := image_metrics(image, expected_size)
	if not bool(pre_save.get("valid", false)):
		return {
			"valid": false,
			"reason_code": "pre_save_image_validation_failed",
			"output_path": output_path,
			"pre_save": pre_save,
		}
	var absolute_path := ProjectSettings.globalize_path(output_path)
	if FileAccess.file_exists(absolute_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			return {"valid": false, "reason_code": "stale_capture_remove_failed", "output_path": output_path}
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		return {
			"valid": false,
			"reason_code": "capture_png_save_failed",
			"output_path": output_path,
			"save_error": save_error,
		}
	var file := FileAccess.open(absolute_path, FileAccess.READ)
	var file_bytes := file.get_length() if file != null else 0
	var reloaded := Image.new()
	var reload_error := reloaded.load(absolute_path)
	var post_save := image_metrics(reloaded, expected_size) if reload_error == OK else {
		"valid": false,
		"reason_code": "capture_png_reload_failed",
	}
	var valid := file_bytes >= MINIMUM_FILE_BYTES and reload_error == OK \
		and bool(post_save.get("valid", false))
	return {
		"valid": valid,
		"reason_code": "ok" if valid else "capture_file_validation_failed",
		"output_path": output_path,
		"file_name": output_path.get_file(),
		"file_bytes": file_bytes,
		"sha256": FileAccess.get_sha256(absolute_path) if valid else "",
		"pre_save": pre_save,
		"post_save": post_save,
	}


func output_root_from_arguments(arguments: PackedStringArray) -> String:
	for argument in arguments:
		if not argument.begins_with("--commercial-art-output-root="):
			continue
		var requested := argument.trim_prefix("--commercial-art-output-root=").trim_suffix("/")
		if requested == REPOSITORY_OUTPUT_ROOT \
				or (requested.begins_with("user://") and not requested.contains("..")):
			return requested
	return DEFAULT_OUTPUT_ROOT


func prepare_output_root(output_root: String) -> Dictionary:
	if output_root != REPOSITORY_OUTPUT_ROOT \
			and (not output_root.begins_with("user://") or output_root.contains("..")):
		return {"valid": false, "reason_code": "capture_output_root_rejected"}
	var absolute_root := ProjectSettings.globalize_path(output_root)
	var error := DirAccess.make_dir_recursive_absolute(absolute_root)
	return {
		"valid": error == OK,
		"reason_code": "ok" if error == OK else "capture_output_root_create_failed",
		"output_root": output_root,
		"absolute_root": absolute_root,
		"error": error,
	}


func _preflight_result(errors: Array[String], snapshot: Dictionary, plan_report: Dictionary) -> Dictionary:
	return {
		"ready": errors.is_empty(),
		"primary_reason_code": "ok" if errors.is_empty() else errors[0],
		"errors": errors,
		"plan": plan_report,
		"required_asset_key_count": int(snapshot.get("required_asset_key_count", -1)),
		"resolved_asset_key_count": int(snapshot.get("resolved_asset_key_count", -1)),
		"missing_asset_key_count": int(snapshot.get("missing_asset_key_count", -1)),
		"missing_asset_keys": snapshot.get("missing_asset_keys", []),
		"resource_type_counts": snapshot.get("resolved_resource_type_counts", {}),
		"credits_placeholder_count": int(snapshot.get("credits_placeholder_count", -1)),
		"placeholder_capture_allowed": false,
		"screenshot_write_authorized": errors.is_empty(),
	}


func _resource_type_counts(resources: Array[Resource]) -> Dictionary:
	var counts := {
		"Texture2D": 0,
		"PackedScene": 0,
		"AudioStream": 0,
		"Font": 0,
		"other": 0,
	}
	for resource in resources:
		if resource is Texture2D:
			counts["Texture2D"] += 1
		elif resource is PackedScene:
			counts["PackedScene"] += 1
		elif resource is AudioStream:
			counts["AudioStream"] += 1
		elif resource is Font:
			counts["Font"] += 1
		else:
			counts["other"] += 1
	return counts


func _catalog_text_contract_preflight() -> Dictionary:
	if not FileAccess.file_exists(CATALOG_RESOURCE_PATH):
		return {
			"ready": false,
			"reason_code": "catalog_resource_missing",
			"required_asset_key_count": REQUIRED_ASSET_KEYS.size(),
			"textually_declared_asset_key_count": 0,
			"missing_asset_keys": REQUIRED_ASSET_KEYS.duplicate(),
		}
	var source := FileAccess.get_file_as_string(CATALOG_RESOURCE_PATH)
	var missing_keys: Array[String] = []
	for asset_key in REQUIRED_ASSET_KEYS:
		if not source.contains("\"%s\"" % asset_key):
			missing_keys.append(asset_key)
	var schema_declared := source.contains("stable_asset_schema_version = \"commercial.presentation_assets.v1\"")
	var parallel_arrays_declared := source.contains("stable_asset_keys = PackedStringArray(") \
		and source.contains("stable_asset_resources = Array[Resource]([") \
		and source.contains("stable_asset_kinds = PackedStringArray(")
	var ready := not source.is_empty() and schema_declared \
		and parallel_arrays_declared and missing_keys.is_empty()
	return {
		"ready": ready,
		"reason_code": "ok" if ready else (
			"catalog_text_asset_keys_incomplete" if not missing_keys.is_empty() \
			else "catalog_text_contract_invalid"
		),
		"catalog_resource_path": CATALOG_RESOURCE_PATH,
		"catalog_bytes": source.to_utf8_buffer().size(),
		"schema_declared": schema_declared,
		"parallel_arrays_declared": parallel_arrays_declared,
		"required_asset_key_count": REQUIRED_ASSET_KEYS.size(),
		"textually_declared_asset_key_count": REQUIRED_ASSET_KEYS.size() - missing_keys.size(),
		"missing_asset_keys": missing_keys,
		"loads_external_resources": false,
	}


func _credits_data_preflight() -> Dictionary:
	if not FileAccess.file_exists(CREDITS_DATA_PATH):
		return {
			"ready": false,
			"reason_code": "credits_data_missing",
			"credits_data_path": CREDITS_DATA_PATH,
			"section_count": 0,
			"entry_count": 0,
			"missing_section_ids": REQUIRED_CREDIT_SECTION_IDS.duplicate(),
			"missing_required_tokens": REQUIRED_CREDIT_TOKENS.duplicate(),
		}
	var source := FileAccess.get_file_as_string(CREDITS_DATA_PATH)
	var parsed: Variant = JSON.parse_string(source)
	if not (parsed is Dictionary):
		return {
			"ready": false,
			"reason_code": "credits_data_parse_failed",
			"credits_data_path": CREDITS_DATA_PATH,
			"section_count": 0,
			"entry_count": 0,
		}
	var data := parsed as Dictionary
	var sections: Dictionary = data.get("sections", {}) as Dictionary \
		if data.get("sections", {}) is Dictionary else {}
	var missing_sections: Array[String] = []
	var empty_sections: Array[String] = []
	var entry_count := 0
	for section_id in REQUIRED_CREDIT_SECTION_IDS:
		if not sections.has(section_id):
			missing_sections.append(section_id)
			continue
		var entries: Variant = sections.get(section_id)
		if not (entries is Array) or (entries as Array).is_empty():
			empty_sections.append(section_id)
		else:
			entry_count += (entries as Array).size()
	var normalized := source.to_lower()
	var missing_tokens: Array[String] = []
	for token in REQUIRED_CREDIT_TOKENS:
		if not normalized.contains(token):
			missing_tokens.append(token)
	var attribution := str(data.get("game_icons_attribution", "")).to_lower()
	var attribution_ready := attribution.contains("game-icons.net") \
		and attribution.contains("cc by 3.0")
	var ready := sections.size() == REQUIRED_CREDIT_SECTION_IDS.size() \
		and missing_sections.is_empty() and empty_sections.is_empty() \
		and missing_tokens.is_empty() and attribution_ready
	return {
		"ready": ready,
		"reason_code": "ok" if ready else "credits_data_contract_invalid",
		"credits_data_path": CREDITS_DATA_PATH,
		"credits_bytes": source.to_utf8_buffer().size(),
		"section_count": sections.size(),
		"entry_count": entry_count,
		"missing_section_ids": missing_sections,
		"empty_section_ids": empty_sections,
		"missing_required_tokens": missing_tokens,
		"game_icons_attribution_ready": attribution_ready,
	}


func _spec(capture_id: String, file_name: String, viewport_size: Vector2i) -> Dictionary:
	return {
		"capture_id": capture_id,
		"file_name": file_name,
		"viewport_size": viewport_size,
		"await_render_frame_before_capture": true,
		"requires_nonempty_image": true,
		"requires_exact_dimensions": true,
		"requires_pixel_variance": true,
	}
