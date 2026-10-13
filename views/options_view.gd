extends Control

var opt_window_mode: OptionButton
var opt_resolution: OptionButton
var slider_ui_scale: HSlider
var lbl_scale_val: Label

# Lista de resoluções suportadas
var resolutions: Array = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_ui()

func build_ui() -> void:
	for child in get_children():
		child.queue_free()

	# Fundo do painel
	var bg_panel = PanelContainer.new()
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#0c0d0e")
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 30)
	bg_panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_vbox)

	# Título
	var title_lbl = Label.new()
	title_lbl.text = "⚙️ CONFIGURAÇÕES DO JOGO"
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color("#ef4444"))
	main_vbox.add_child(title_lbl)

	main_vbox.add_child(HSeparator.new())

	# Form Container para as opções de Vídeo
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 18)
	main_vbox.add_child(grid)

	# --- 1. MODO DE EXIBIÇÃO ---
	_add_field_label(grid, "Modo de Exibição:")
	opt_window_mode = OptionButton.new()
	opt_window_mode.add_item("Janela (Windowed)", 0)
	opt_window_mode.add_item("Tela Cheia (Fullscreen)", 1)
	opt_window_mode.add_item("Janela sem Bordas (Borderless)", 2)
	opt_window_mode.selected = Database.window_mode_index
	opt_window_mode.item_selected.connect(_on_window_mode_selected)
	grid.add_child(opt_window_mode)

	# --- 2. RESOLUÇÃO ---
	_add_field_label(grid, "Resolução da Tela:")
	opt_resolution = OptionButton.new()
	var current_res = DisplayServer.window_get_size()
	var selected_res_idx = 3 # Padrão 1080p

	for i in range(resolutions.size()):
		var r = resolutions[i]
		opt_resolution.add_item("%d x %d" % [r.x, r.y], i)
		if r == current_res:
			selected_res_idx = i

	opt_resolution.selected = selected_res_idx
	opt_resolution.item_selected.connect(_on_resolution_selected)
	grid.add_child(opt_resolution)

	# --- 3. ESCALA DA INTERFACE (UI SCALE) ---
	_add_field_label(grid, "Escala da Interface (UI):")
	var hbox_scale = HBoxContainer.new()
	hbox_scale.add_theme_constant_override("separation", 12)

	slider_ui_scale = HSlider.new()
	slider_ui_scale.min_value = 0.8
	slider_ui_scale.max_value = 1.4
	slider_ui_scale.step = 0.05
	slider_ui_scale.value = Database.ui_scale
	slider_ui_scale.custom_minimum_size.x = 200
	slider_ui_scale.value_changed.connect(_on_ui_scale_changed)

	lbl_scale_val = Label.new()
	lbl_scale_val.text = "%d%%" % [int(Database.ui_scale * 100.0)]
	lbl_scale_val.add_theme_font_size_override("font_size", 14)
	lbl_scale_val.add_theme_color_override("font_color", Color("#38bdf8"))

	hbox_scale.add_child(slider_ui_scale)
	hbox_scale.add_child(lbl_scale_val)
	grid.add_child(hbox_scale)

	# Espaçador vertical
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)

	# Botões de Ação na parte inferior
	var hbox_bottom = HBoxContainer.new()
	hbox_bottom.add_theme_constant_override("separation", 15)

	var btn_save = Button.new()
	btn_save.text = "💾 Salvar Configurações"
	btn_save.custom_minimum_size = Vector2(180, 40)
	btn_save.add_theme_color_override("font_color", Color("#22c55e"))
	btn_save.pressed.connect(_save_and_close)
	hbox_bottom.add_child(btn_save)

	var btn_back = Button.new()
	btn_back.text = "⬅️ Voltar"
	btn_back.custom_minimum_size = Vector2(120, 40)
	btn_back.pressed.connect(_close_options)
	hbox_bottom.add_child(btn_back)

	main_vbox.add_child(hbox_bottom)

func _add_field_label(parent: Control, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
	parent.add_child(lbl)

# --- LÓGICA DAS CONFIGURAÇÕES ---

func _on_window_mode_selected(index: int) -> void:
	Database.window_mode_index = index
	match index:
		0: # Janela
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < resolutions.size():
		var res = resolutions[index]
		DisplayServer.window_set_size(res)
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			var screen_center = DisplayServer.screen_get_position() + (DisplayServer.screen_get_size() / 2)
			DisplayServer.window_set_position(screen_center - (res / 2))

func _on_ui_scale_changed(value: float) -> void:
	Database.ui_scale = value
	lbl_scale_val.text = "%d%%" % [int(value * 100.0)]
	get_tree().root.content_scale_factor = value

func _save_and_close() -> void:
	# Agora chama a função de salvamento de slot corretamente através do método intermediário ou direto
	if Database.has_method("save_game"):
		Database.save_game()
	else:
		Database.save_game_slot(Database.current_slot)
	_close_options()

func _close_options() -> void:
	if Database.current_view == "main_menu" or get_parent() is Window or get_parent() is CanvasLayer:
		queue_free()
	else:
		Database.current_view = "dashboard"
		get_tree().change_scene_to_file("res://views/main_menu_view.tscn")
