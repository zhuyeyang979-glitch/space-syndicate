@tool
extends Node
class_name SpaceSyndicateGameThemeLocaleResolver

const CATALOG: CardIllustrationCatalogResource = preload("res://resources/presentation/alpha01_card_illustration_catalog.tres")

@export var game_theme: Theme = preload("res://themes/GameTheme.tres")

var _applied_locale := ""
var _apply_count := 0


func _ready() -> void:
	_apply_locale(TranslationServer.get_locale())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_locale(TranslationServer.get_locale())


func apply_locale_for_test(locale: String) -> bool:
	return _apply_locale(locale)


func debug_snapshot() -> Dictionary:
	return {
		"resolver_id": "game_theme_locale_resolver_v1",
		"locale": _applied_locale,
		"body_asset_key": "font.body.ja" if _is_japanese(_applied_locale) else "font.body.zh",
		"display_asset_key": "font.display",
		"apply_count": _apply_count,
		"presentation_only": true,
		"reads_gameplay": false,
		"owns_save_state": false,
	}


func _apply_locale(locale: String) -> bool:
	var normalized := locale.strip_edges().to_lower()
	var japanese := _is_japanese(normalized)
	var body_key := &"font.body.ja" if japanese else &"font.body.zh"
	var bold_key := &"font.body.ja.bold" if japanese else &"font.body.zh.bold"
	var body := CATALOG.resource_for_asset_key(body_key) as Font
	var bold := CATALOG.resource_for_asset_key(bold_key) as Font
	var display := CATALOG.resource_for_asset_key(&"font.display") as Font
	if body == null or bold == null or display == null:
		return false
	if game_theme == null:
		return false
	game_theme.default_font = body
	game_theme.set_font(&"font", &"BodyBold", bold)
	game_theme.set_font(&"font", &"DisplayLabel", display)
	_applied_locale = normalized
	_apply_count += 1
	return true


func _is_japanese(locale: String) -> bool:
	return locale.strip_edges().to_lower().begins_with("ja")
