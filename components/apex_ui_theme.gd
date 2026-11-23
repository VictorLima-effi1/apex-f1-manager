extends Node

var game_theme: Theme

func _ready() -> void:
	game_theme = _build_game_theme()
	get_tree().root.theme = game_theme
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if not node is Window or node == get_tree().root:
		return

	var popup_window := node as Window
	if popup_window.is_class("Popup"):
		popup_window.theme = game_theme
		return

	popup_window.borderless = true
	popup_window.theme = game_theme
	if popup_window.has_meta("apex_modal_backdrop"):
		return

	var descendants: Array[Node] = [popup_window]
	while not descendants.is_empty():
		var current: Node = descendants.pop_back()
		if current is ColorRect:
			var color_rect := current as ColorRect
			if color_rect.color.r < 0.1 and color_rect.color.g < 0.1 and color_rect.color.b < 0.1:
				color_rect.color = Color("#121316")
		for child in current.get_children():
			descendants.append(child)

	var backdrop := ColorRect.new()
	backdrop.name = "ApexModalBackdrop"
	backdrop.color = Color("#121316")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_window.add_child(backdrop)
	popup_window.move_child(backdrop, 0)
	popup_window.set_meta("apex_modal_backdrop", true)

func _build_game_theme() -> Theme:
	var theme := Theme.new()

	var popup_panel := StyleBoxFlat.new()
	popup_panel.bg_color = Color("#111318")
	popup_panel.set_border_width_all(1)
	popup_panel.border_color = Color("#7f1d1d")
	popup_panel.set_corner_radius_all(4)
	popup_panel.set_content_margin_all(6)
	theme.set_stylebox("panel", "PopupMenu", popup_panel)

	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = Color("#351719")
	popup_hover.set_corner_radius_all(3)
	theme.set_stylebox("hover", "PopupMenu", popup_hover)
	theme.set_color("font_color", "PopupMenu", Color("#e2e8f0"))
	theme.set_color("font_hover_color", "PopupMenu", Color("#ffffff"))
	theme.set_color("font_disabled_color", "PopupMenu", Color("#64748b"))
	theme.set_color("font_accelerator_color", "PopupMenu", Color("#94a3b8"))
	theme.set_color("font_separator_color", "PopupMenu", Color("#ef4444"))

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color("#1b1d22")
	button_normal.set_border_width_all(1)
	button_normal.border_color = Color("#3f2023")
	button_normal.set_corner_radius_all(4)
	button_normal.set_content_margin_all(6)

	var button_hover := StyleBoxFlat.new()
	button_hover.bg_color = Color("#351719")
	button_hover.set_border_width_all(1)
	button_hover.border_color = Color("#ef4444")
	button_hover.set_corner_radius_all(4)
	button_hover.set_content_margin_all(6)

	var button_pressed := StyleBoxFlat.new()
	button_pressed.bg_color = Color("#5b1d22")
	button_pressed.set_border_width_all(1)
	button_pressed.border_color = Color("#ef4444")
	button_pressed.set_corner_radius_all(4)
	button_pressed.set_content_margin_all(6)

	var button_disabled := StyleBoxFlat.new()
	button_disabled.bg_color = Color("#292b30")
	button_disabled.set_corner_radius_all(4)
	button_disabled.set_content_margin_all(6)

	for control_type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", control_type, button_normal)
		theme.set_stylebox("hover", control_type, button_hover)
		theme.set_stylebox("pressed", control_type, button_pressed)
		theme.set_stylebox("disabled", control_type, button_disabled)
		theme.set_color("font_color", control_type, Color("#e2e8f0"))
		theme.set_color("font_hover_color", control_type, Color("#ffffff"))
		theme.set_color("font_pressed_color", control_type, Color("#ffffff"))
		theme.set_color("font_disabled_color", control_type, Color("#64748b"))

	var field_style := StyleBoxFlat.new()
	field_style.bg_color = Color("#111318")
	field_style.set_border_width_all(1)
	field_style.border_color = Color("#3f2023")
	field_style.set_corner_radius_all(3)
	field_style.set_content_margin_all(6)
	theme.set_stylebox("normal", "LineEdit", field_style)
	var field_focus := field_style.duplicate() as StyleBoxFlat
	field_focus.border_color = Color("#ef4444")
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_color("font_color", "LineEdit", Color("#f8fafc"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("#64748b"))
	theme.set_color("caret_color", "LineEdit", Color("#ef4444"))
	theme.set_color("selection_color", "LineEdit", Color("#7f1d1d"))

	return theme
