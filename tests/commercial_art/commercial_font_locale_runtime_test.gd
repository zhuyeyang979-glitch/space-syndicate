extends SceneTree

const RESOLVER_SCENE := "res://scenes/runtime/presentation/GameThemeLocaleResolver.tscn"
const MENU_SCENE := "res://scenes/ui/MenuOverlay.tscn"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var resolver := (load(RESOLVER_SCENE) as PackedScene).instantiate()
	root.add_child(resolver)
	await process_frame
	_expect(resolver.apply_locale_for_test("zh_Hans") \
		and str(resolver.debug_snapshot().get("body_asset_key", "")) == "font.body.zh", "Chinese locale uses Noto Sans CJK SC")
	_expect(resolver.apply_locale_for_test("ja_JP") \
		and str(resolver.debug_snapshot().get("body_asset_key", "")) == "font.body.ja", "Japanese locale uses Noto Sans CJK JP")
	var theme := load("res://themes/GameTheme.tres") as Theme
	_expect(theme.default_font != null \
		and theme.get_font(&"font", &"BodyBold") != null \
		and theme.get_font(&"font", &"DisplayLabel") != null, "body, bold, and Latin display fonts are resolved")
	var menu := (load(MENU_SCENE) as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	_expect(menu.get_node_or_null("GameThemeLocaleResolver") != null, "production menu lifecycle owns one locale resolver")
	var source := FileAccess.get_file_as_string("res://scripts/presentation/game_theme_locale_resolver.gd")
	_expect(not source.contains("scripts/main.gd") \
		and not source.contains("RandomNumberGenerator") \
		and not source.contains("FileAccess.open("), "locale resolver has no Main, RNG, or Save dependency")
	menu.queue_free()
	resolver.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures.append(label)
		push_error("[FAIL] %s" % label)


func _finish() -> void:
	print("COMMERCIAL_FONT_LOCALE_RUNTIME checks=%d failures=%d" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
