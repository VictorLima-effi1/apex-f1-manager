extends Control

var opt_window_mode: OptionButton
var opt_resolution: OptionButton
var slider_ui_scale: HSlider
var lbl_scale_val: Label

# Novos elementos de UI
var check_reduce_sc: CheckButton
var opt_language: OptionButton
var btn_credits: Button
var credits_modal: Control = null

# Variáveis locais temporárias (salvam a alteração apenas se clicar em Salvar)
var temp_ui_scale: float
var temp_window_mode: int
var temp_resolution_idx: int
var temp_reduce_sc: bool
var temp_language: String

var previous_view: String = "main_menu"

var resolutions: Array = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

func _ready() -> void:
	previous_view = Database.current_view
	
	# Inicializa as variáveis temporárias
	temp_ui_scale = Database.ui_scale
	temp_window_mode = Database.window_mode_index
	temp_reduce_sc = Database.reduce_speed_on_sc
	temp_language = Database.current_language
	
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
	main_vbox.add_theme_constant_override("separation", 18)
	margin.add_child(main_vbox)

	# Título dinâmico por idioma
	var title_lbl = Label.new()
	title_lbl.text = Database.tr_text("OPTIONS_TITLE")
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color("#ef4444"))
	main_vbox.add_child(title_lbl)

	main_vbox.add_child(HSeparator.new())

	# Form Container para as opções
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 16)
	main_vbox.add_child(grid)

	# --- 1. MODO DE EXIBIÇÃO ---
	_add_field_label(grid, Database.tr_text("DISPLAY_MODE"))
	opt_window_mode = OptionButton.new()
	opt_window_mode.add_item("Janela (Windowed)", 0)
	opt_window_mode.add_item("Tela Cheia (Fullscreen)", 1)
	opt_window_mode.add_item("Janela sem Bordas (Borderless)", 2)
	opt_window_mode.selected = temp_window_mode
	opt_window_mode.item_selected.connect(func(idx): temp_window_mode = idx)
	grid.add_child(opt_window_mode)

	# --- 2. RESOLUÇÃO ---
	_add_field_label(grid, Database.tr_text("RESOLUTION"))
	opt_resolution = OptionButton.new()
	var current_res = DisplayServer.window_get_size()
	temp_resolution_idx = 3

	for i in range(resolutions.size()):
		var r = resolutions[i]
		opt_resolution.add_item("%d x %d" % [r.x, r.y], i)
		if r == current_res:
			temp_resolution_idx = i

	opt_resolution.selected = temp_resolution_idx
	opt_resolution.item_selected.connect(func(idx): temp_resolution_idx = idx)
	grid.add_child(opt_resolution)

	# --- 3. ESCALA DA INTERFACE ---
	_add_field_label(grid, Database.tr_text("UI_SCALE"))
	var hbox_scale = HBoxContainer.new()
	hbox_scale.add_theme_constant_override("separation", 12)

	slider_ui_scale = HSlider.new()
	slider_ui_scale.min_value = 0.8
	slider_ui_scale.max_value = 1.4
	slider_ui_scale.step = 0.05
	slider_ui_scale.value = temp_ui_scale
	slider_ui_scale.custom_minimum_size.x = 200
	slider_ui_scale.value_changed.connect(func(val):
		temp_ui_scale = val
		lbl_scale_val.text = "%d%%" % [int(val * 100.0)]
	)

	lbl_scale_val = Label.new()
	lbl_scale_val.text = "%d%%" % [int(temp_ui_scale * 100.0)]
	lbl_scale_val.add_theme_font_size_override("font_size", 14)
	lbl_scale_val.add_theme_color_override("font_color", Color("#38bdf8"))

	hbox_scale.add_child(slider_ui_scale)
	hbox_scale.add_child(lbl_scale_val)
	grid.add_child(hbox_scale)

	# --- 4. REDUZIR VELOCIDADE NO SAFETY CAR ---
	_add_field_label(grid, Database.tr_text("REDUCE_SC_SPEED"))
	check_reduce_sc = CheckButton.new()
	check_reduce_sc.button_pressed = temp_reduce_sc
	check_reduce_sc.toggled.connect(func(toggled): temp_reduce_sc = toggled)
	grid.add_child(check_reduce_sc)

	# --- 5. IDIOMA DO JOGO ---
	_add_field_label(grid, Database.tr_text("LANGUAGE"))
	opt_language = OptionButton.new()
	opt_language.add_item("Português (Brasil)", 0)
	opt_language.add_item("English", 1)
	opt_language.add_item("Español", 2)

	match temp_language:
		"pt": opt_language.selected = 0
		"en": opt_language.selected = 1
		"es": opt_language.selected = 2

	opt_language.item_selected.connect(func(idx):
		match idx:
			0: temp_language = "pt"
			1: temp_language = "en"
			2: temp_language = "es"
	)
	grid.add_child(opt_language)

	# --- 6. CRÉDITOS ---
	_add_field_label(grid, Database.tr_text("SETTINGS_ABOUT"))
	btn_credits = Button.new()
	btn_credits.text = Database.tr_text("CREDITS_BTN")
	btn_credits.custom_minimum_size = Vector2(160, 32)
	btn_credits.pressed.connect(_show_credits_modal)
	grid.add_child(btn_credits)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)

	# Botões Inferiores
	var hbox_bottom = HBoxContainer.new()
	hbox_bottom.add_theme_constant_override("separation", 15)

	var btn_save = Button.new()
	btn_save.text = Database.tr_text("SAVE_BTN")
	btn_save.custom_minimum_size = Vector2(180, 40)
	btn_save.add_theme_color_override("font_color", Color("#22c55e"))
	btn_save.pressed.connect(_save_and_close)
	hbox_bottom.add_child(btn_save)

	var btn_back = Button.new()
	btn_back.text = Database.tr_text("BACK_BTN")
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

# --- MODAL DE CRÉDITOS ---

func _show_credits_modal() -> void:
	_close_credits_modal()

	credits_modal = ColorRect.new()
	credits_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_modal.color = Color(0, 0, 0, 0.85)
	add_child(credits_modal)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_modal.add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 260)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.border_width_top = 3
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	var lbl_title = Label.new()
	lbl_title.text = Database.tr_text("CREDITS_TITLE")
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 15)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)

	var lbl_body = Label.new()
	lbl_body.text = Database.tr_text("CREDITS_TEXT")
	lbl_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_body.add_theme_font_size_override("font_size", 12)
	lbl_body.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_body)

	var btn_close = Button.new()
	btn_close.text = Database.tr_text("CLOSE")
	btn_close.custom_minimum_size.y = 35
	btn_close.pressed.connect(_close_credits_modal)
	vbox.add_child(btn_close)

	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

func _close_credits_modal() -> void:
	if is_instance_valid(credits_modal):
		credits_modal.queue_free()
		credits_modal = null

# --- SALVAMENTO E RETORNO ---

func _save_and_close() -> void:
	# 1. Aplica o Modo de Exibição
	Database.window_mode_index = temp_window_mode
	match temp_window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

	# 2. Aplica a Resolução
	if temp_resolution_idx >= 0 and temp_resolution_idx < resolutions.size():
		var res = resolutions[temp_resolution_idx]
		DisplayServer.window_set_size(res)
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			var screen_center = DisplayServer.screen_get_position() + (DisplayServer.screen_get_size() / 2)
			DisplayServer.window_set_position(screen_center - (res / 2))

	# 3. Aplica a Escala de UI
	Database.ui_scale = temp_ui_scale
	get_tree().root.content_scale_factor = temp_ui_scale

	# 4. Aplica as novas Opções (Safety Car e Idioma)
	Database.reduce_speed_on_sc = temp_reduce_sc
	Database.current_language = temp_language
	Database.set_language(temp_language)

	_close_options()

func _close_options() -> void:
	if get_parent() != null and get_parent() != get_tree().root:
		queue_free()
		return

	if previous_view == "dashboard" or Database.current_view == "dashboard":
		get_tree().change_scene_to_file("res://views/dashboard_view.tscn")
	else:
		get_tree().change_scene_to_file("res://views/main_menu_view.tscn")
