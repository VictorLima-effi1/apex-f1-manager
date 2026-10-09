extends PanelContainer
class_name ResizablePanel

var panel_key: String = ""
var title: String = "" : set = set_title

var is_dragging: bool = false
var is_resizing: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var resize_start_size: Vector2 = Vector2.ZERO
var resize_start_mouse: Vector2 = Vector2.ZERO

var content_container: Control
var header_label: Label

func _ready() -> void:
	_build_panel_structure()

func set_title(new_title: String) -> void:
	title = new_title
	if header_label:
		header_label.text = title

func get_content_node() -> Control:
	if not has_node("MainVBox"):
		_build_panel_structure()
	return content_container

func _build_panel_structure() -> void:
	if has_node("MainVBox"):
		return

	# Estilo visual do Painel Container
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#121315")
	style.border_color = Color("#2a2d32")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	# Container Vertical Principal
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 2)
	add_child(main_vbox)
	
	# Barra Superior (Header de Arraste)
	var header = PanelContainer.new()
	header.custom_minimum_size.y = 26
	
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = Color("#1a1c20")
	# Configuração dos cantos superiores no Godot 4 (substituindo o método inexistente)
	h_style.corner_radius_top_left = 4
	h_style.corner_radius_top_right = 4
	h_style.corner_radius_bottom_right = 0
	h_style.corner_radius_bottom_left = 0
	header.add_theme_stylebox_override("panel", h_style)
	
	var h_margin = MarginContainer.new()
	h_margin.add_theme_constant_override("margin_left", 8)
	h_margin.add_theme_constant_override("margin_right", 8)

	header_label = Label.new()
	header_label.text = title
	header_label.add_theme_font_size_override("font_size", 11)
	header_label.add_theme_color_override("font_color", Color("#ef4444"))
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	h_margin.add_child(header_label)
	header.add_child(h_margin)
	header.gui_input.connect(_on_header_gui_input)
	main_vbox.add_child(header)
	
	# Conteúdo Principal
	content_container = MarginContainer.new()
	content_container.name = "ContentContainer"
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("margin_left", 6)
	content_container.add_theme_constant_override("margin_top", 4)
	content_container.add_theme_constant_override("margin_right", 6)
	content_container.add_theme_constant_override("margin_bottom", 6)
	main_vbox.add_child(content_container)
	
	# Canto inferior direito para redimensionar
	var resize_handle = Control.new()
	resize_handle.custom_minimum_size = Vector2(14, 14)
	resize_handle.size_flags_horizontal = Control.SIZE_SHRINK_END
	resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	main_vbox.add_child(resize_handle)

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = get_global_mouse_position() - position
		else:
			is_dragging = false
			_save_transform()
			
	elif event is InputEventMouseMotion and is_dragging:
		position = get_global_mouse_position() - drag_offset
		_save_transform()

func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_resizing = true
			resize_start_size = size
			resize_start_mouse = get_global_mouse_position()
		else:
			is_resizing = false
			_save_transform()
			
	elif event is InputEventMouseMotion and is_resizing:
		var delta = get_global_mouse_position() - resize_start_mouse
		var new_size = resize_start_size + delta
		custom_minimum_size = Vector2(max(200, new_size.x), max(100, new_size.y))
		size = custom_minimum_size
		_save_transform()

func _save_transform() -> void:
	if panel_key != "" and Database.dashboard_layout.has(panel_key):
		Database.dashboard_layout[panel_key] = {
			"pos": position,
			"size": size
		}
