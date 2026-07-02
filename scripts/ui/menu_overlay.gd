extends ColorRect
class_name SpaceSyndicateMenuOverlay

signal continue_requested
signal main_menu_requested
signal catalog_step_requested(delta: int)
signal catalog_back_requested

@onready var surface_panel: PanelContainer = %MenuSurfacePanel
@onready var shell_margin: MarginContainer = %MenuShellMargin
@onready var title_label: Label = %MenuTitleLabel
@onready var context_label: Label = %MenuContextLabel
@onready var quick_nav_row: HBoxContainer = %MenuQuickNavRow
@onready var hint_panel: PanelContainer = %MenuInteractionHintPanel
@onready var hint_label: Label = %MenuInteractionHintLabel
@onready var nav_row: HBoxContainer = %MenuNavRow
@onready var continue_button: Button = %MenuContinueButton
@onready var back_button: Button = %MenuBackButton
@onready var catalog_nav_row: HBoxContainer = %MenuCatalogNavRow
@onready var catalog_prev_button: Button = %MenuBestiaryPrevButton
@onready var catalog_next_button: Button = %MenuBestiaryNextButton
@onready var catalog_back_button: Button = %MenuBestiaryBackButton
@onready var content_scroll: ScrollContainer = %MenuContentScroll
@onready var content_box: VBoxContainer = %MenuContentBox
@onready var body_label: Label = %MenuBodyLabel
@onready var preview_box: VBoxContainer = %MenuPreviewBox
@onready var run_save_label: Label = %MenuRunSaveLabel


func _ready() -> void:
	_style_shell()
	_connect_buttons()


func present_menu_shell(data: Dictionary) -> void:
	var title_text := str(data.get("title", "Space Syndicate"))
	var body_text := str(data.get("body", ""))
	var root_table_menu := bool(data.get("root_table_menu", false))
	title_label.text = title_text
	title_label.visible = bool(data.get("title_visible", not root_table_menu))
	context_label.text = str(data.get("context", ""))
	context_label.visible = bool(data.get("context_visible", not root_table_menu))
	hint_label.text = str(data.get("hint", ""))
	hint_panel.visible = bool(data.get("hint_visible", not root_table_menu))
	hint_panel.tooltip_text = hint_label.text
	body_label.text = body_text
	body_label.visible = body_text.strip_edges() != "" and not root_table_menu
	if bool(data.get("clear_preview", true)):
		clear_preview()
	if content_scroll != null and bool(data.get("reset_scroll", true)):
		content_scroll.scroll_vertical = 0
	continue_button.disabled = bool(data.get("continue_disabled", false))
	continue_button.visible = bool(data.get("continue_visible", false))
	back_button.visible = bool(data.get("back_visible", true))
	nav_row.visible = bool(data.get("nav_visible", true))
	run_save_label.visible = bool(data.get("run_save_visible", false))
	set_catalog_navigation({})
	visible = true
	refresh_menu_layout(_dictionary_vector2(data, "viewport_size", Vector2.ZERO), root_table_menu)


func clear_preview() -> void:
	if preview_box == null:
		return
	for child in preview_box.get_children():
		preview_box.remove_child(child)
		child.queue_free()
	preview_box.visible = false


func hide_global_navigation() -> void:
	continue_button.visible = false
	back_button.visible = false
	run_save_label.visible = false
	nav_row.visible = false


func set_catalog_navigation(data: Dictionary) -> void:
	catalog_prev_button.text = str(data.get("prev_text", "Previous"))
	catalog_next_button.text = str(data.get("next_text", "Next"))
	catalog_back_button.text = str(data.get("back_text", "Back"))
	catalog_prev_button.visible = bool(data.get("prev_visible", false))
	catalog_next_button.visible = bool(data.get("next_visible", false))
	catalog_back_button.visible = bool(data.get("back_visible", false))
	catalog_nav_row.visible = catalog_prev_button.visible or catalog_next_button.visible or catalog_back_button.visible


func refresh_menu_layout(viewport_size: Vector2 = Vector2.ZERO, root_table_menu: bool = false) -> void:
	if viewport_size == Vector2.ZERO and get_viewport() != null:
		viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(960, 640)
	var compact := viewport_size.x < 900.0 or viewport_size.y < 620.0
	var wide := viewport_size.x >= 1400.0 and viewport_size.y >= 780.0
	surface_panel.add_theme_stylebox_override("panel", _root_surface_style() if root_table_menu else _surface_style())
	var side_anchor := 0.025 if compact else (0.10 if wide else 0.07)
	var vertical_anchor := 0.025 if compact else (0.065 if wide else 0.055)
	if root_table_menu:
		side_anchor = 0.0
		vertical_anchor = 0.0
	surface_panel.anchor_left = side_anchor
	surface_panel.anchor_right = 1.0 - side_anchor
	surface_panel.anchor_top = vertical_anchor
	surface_panel.anchor_bottom = 1.0 - vertical_anchor
	surface_panel.custom_minimum_size = Vector2(760, 500) if root_table_menu or compact else Vector2(760, 520)
	var horizontal_margin := 18 if root_table_menu and compact else (44 if root_table_menu and wide else (30 if root_table_menu else (14 if compact else (28 if wide else 22))))
	var vertical_margin := 14 if root_table_menu and compact else (34 if root_table_menu and wide else (22 if root_table_menu else (12 if compact else (22 if wide else 18))))
	shell_margin.add_theme_constant_override("margin_left", horizontal_margin)
	shell_margin.add_theme_constant_override("margin_right", horizontal_margin)
	shell_margin.add_theme_constant_override("margin_top", vertical_margin)
	shell_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	title_label.add_theme_font_size_override("font_size", 30 if root_table_menu and compact else (44 if root_table_menu and wide else (38 if root_table_menu else (24 if compact else (34 if wide else 31)))))
	context_label.add_theme_font_size_override("font_size", 10 if compact else 11)
	hint_label.add_theme_font_size_override("font_size", 9 if compact else 10)
	body_label.add_theme_font_size_override("font_size", 13 if compact else 15)
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL if root_table_menu else Control.SIZE_FILL
	preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL if root_table_menu else Control.SIZE_FILL
	preview_box.custom_minimum_size = Vector2(0, maxf(430.0, viewport_size.y - 210.0)) if root_table_menu else Vector2.ZERO
	nav_row.add_theme_constant_override("separation", 6 if compact else 10)
	quick_nav_row.add_theme_constant_override("separation", 4 if compact else 8)
	catalog_nav_row.add_theme_constant_override("separation", 6 if compact else 8)
	for button in [continue_button, back_button, catalog_prev_button, catalog_next_button, catalog_back_button]:
		button.custom_minimum_size = Vector2(108 if compact else 124, 32 if compact else 34)


func _connect_buttons() -> void:
	if not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if not catalog_prev_button.pressed.is_connected(_on_prev_pressed):
		catalog_prev_button.pressed.connect(_on_prev_pressed)
	if not catalog_next_button.pressed.is_connected(_on_next_pressed):
		catalog_next_button.pressed.connect(_on_next_pressed)
	if not catalog_back_button.pressed.is_connected(_on_catalog_back_pressed):
		catalog_back_button.pressed.connect(_on_catalog_back_pressed)


func _style_shell() -> void:
	surface_panel.add_theme_stylebox_override("panel", _surface_style())
	title_label.add_theme_font_size_override("font_size", 31)
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	context_label.add_theme_font_size_override("font_size", 11)
	context_label.add_theme_color_override("font_color", Color("#94a3b8"))
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color("#dbeafe"))
	body_label.add_theme_font_size_override("font_size", 15)
	body_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	run_save_label.add_theme_font_size_override("font_size", 12)
	run_save_label.add_theme_color_override("font_color", Color("#94a3b8"))
	_style_button(continue_button, Color("#22c55e"), true)
	_style_button(back_button, Color("#38bdf8"))
	_style_button(catalog_prev_button, Color("#93c5fd"))
	_style_button(catalog_next_button, Color("#93c5fd"))
	_style_button(catalog_back_button, Color("#facc15"))


func _style_button(button: Button, accent: Color, primary: bool = false) -> void:
	var fill := Color("#0b1220").lerp(accent, 0.18 if primary else 0.09)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _card_style(accent, fill, 1, 8))
	button.add_theme_stylebox_override("hover", _card_style(accent.lightened(0.18), fill.lightened(0.08), 1, 8))
	button.add_theme_stylebox_override("pressed", _card_style(accent.lightened(0.28), fill.darkened(0.08), 1, 8))
	button.add_theme_stylebox_override("disabled", _card_style(Color("#334155"), Color("#020617"), 1, 8))
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_color_override("font_disabled_color", Color("#64748b"))


func _card_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _surface_style() -> StyleBoxFlat:
	return _card_style(Color("#38bdf8"), Color("#08101f"), 2, 8)


func _root_surface_style() -> StyleBoxFlat:
	var style := _card_style(Color("#020617"), Color("#020617"), 0, 0)
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	return style


func _dictionary_vector2(data: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = data.get(key, fallback)
	if value is Vector2:
		return value as Vector2
	return fallback


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_back_pressed() -> void:
	main_menu_requested.emit()


func _on_prev_pressed() -> void:
	catalog_step_requested.emit(-1)


func _on_next_pressed() -> void:
	catalog_step_requested.emit(1)


func _on_catalog_back_pressed() -> void:
	catalog_back_requested.emit()
