extends RefCounted

const SC_REGULAR := "res://assets/third_party/commercial/fonts/noto_sans_cjk/NotoSansCJKsc-Regular.otf"
const SC_BOLD := "res://assets/third_party/commercial/fonts/noto_sans_cjk/NotoSansCJKsc-Bold.otf"
const JP_REGULAR := "res://assets/third_party/commercial/fonts/noto_sans_cjk/NotoSansCJKjp-Regular.otf"
const JP_BOLD := "res://assets/third_party/commercial/fonts/noto_sans_cjk/NotoSansCJKjp-Bold.otf"
const DISPLAY_MEDIUM := "res://assets/third_party/commercial/fonts/oxanium/Oxanium-Medium.ttf"
const DISPLAY_SEMIBOLD := "res://assets/third_party/commercial/fonts/oxanium/Oxanium-SemiBold.ttf"
const DISPLAY_BOLD := "res://assets/third_party/commercial/fonts/oxanium/Oxanium-Bold.ttf"


static func body_font_path(locale: String, bold := false) -> String:
	var normalized := locale.strip_edges().to_lower().replace("-", "_")
	if normalized == "ja" or normalized.begins_with("ja_"):
		return JP_BOLD if bold else JP_REGULAR
	return SC_BOLD if bold else SC_REGULAR


static func display_font_path(weight: String = "semibold") -> String:
	match weight.strip_edges().to_lower():
		"medium":
			return DISPLAY_MEDIUM
		"bold":
			return DISPLAY_BOLD
	return DISPLAY_SEMIBOLD


static func contract_snapshot() -> Dictionary:
	return {
		"default_body_locale": "zh_Hans",
		"japanese_locale_prefix": "ja",
		"body_font_count": 4,
		"display_font_count": 3,
		"oxanium_cjk_body_allowed": false,
		"paths": [SC_REGULAR, SC_BOLD, JP_REGULAR, JP_BOLD, DISPLAY_MEDIUM, DISPLAY_SEMIBOLD, DISPLAY_BOLD],
	}
