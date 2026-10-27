extends Control

var time_passed: float = 0.0
var title_node: Label
var subtitle_node: Label
var button_container: VBoxContainer
var active_modal: Control = null

# Referências para tradução dinâmica
var btn_new: Button
var btn_load: Button
var btn_opts: Button
var btn_exit: Button

# Variaveis para controle dos submenus do Modo Manager
var input_team_name: LineEdit = null
var input_boss_name: LineEdit = null
var input_country: LineEdit = null
var color_picker: ColorPickerButton = null
var team_option_button: OptionButton = null
var team_info_container: VBoxContainer = null
var manager_selected_drivers: Array = []
var selected_engine: Dictionary = {} # Ex: {"name": "Ferrari", "price": 15}
var selected_chassis: Dictionary = {} # Ex: {"name": "Custom Chassis", "price": 10}
var driver_negotiation_attempts: Dictionary = {}

func _ready() -> void:
	if Database.has_signal("language_changed"):
		if not Database.language_changed.is_connected(_update_texts):
			Database.language_changed.connect(_update_texts)
	
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_saved_settings()
	build_ui()
	_animate_menu_entrance()

func _apply_saved_settings() -> void:
	var window = get_window()
	window.content_scale_factor = Database.ui_scale
	
	match Database.window_mode_index:
		0:
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
		1:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		2:
			window.mode = Window.MODE_WINDOWED
			window.borderless = true
	
	if Database.window_mode_index != 1:
		match Database.aspect_index:
			0: window.size = Vector2i(1920, 1080)
			1: window.size = Vector2i(1920, 1200)
			2: window.size = Vector2i(2560, 1080)
			3: window.size = Vector2i(1440, 1080)

func _process(delta: float) -> void:
	time_passed += delta * 1.2
	queue_redraw()

func _draw() -> void:
	var screen_size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#0b0e14"))
	
	var cols = 18
	var rows = 12
	var cell_w = screen_size.x / cols
	var cell_h = screen_size.y / rows
	
	for r in range(rows + 2):
		for c in range(cols + 2):
			if (r + c) % 2 == 0:
				var wave_offset_x = sin(time_passed + r * 0.3 + c * 0.2) * 20.0
				var wave_offset_y = cos(time_passed * 0.8 + c * 0.3) * 15.0
				var pos = Vector2(c * cell_w + wave_offset_x - 30, r * cell_h + wave_offset_y - 30)
				var alpha = 0.03 + (sin(time_passed + c * 0.4) * 0.015)
				draw_rect(Rect2(pos, Vector2(cell_w * 0.85, cell_h * 0.85)), Color(1, 1, 1, alpha))

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 440)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	style.border_width_left = 4
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 25
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_bottom", 35)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 24)
	
	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 6)
	
	title_node = Label.new()
	title_node.text = "APEX F1 MANAGER"
	title_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_node.add_theme_font_size_override("font_size", 24)
	title_node.add_theme_color_override("font_color", Color("#ef4444"))
	header_vbox.add_child(title_node)
	
	subtitle_node = Label.new()
	subtitle_node.text = Database.tr_text("MENU_SUBTITLE") if Database.has_method("tr_text") else "SEASON MANAGEMENT SIMULATOR"
	subtitle_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_node.add_theme_font_size_override("font_size", 10)
	subtitle_node.add_theme_color_override("font_color", Color("#64748b"))
	header_vbox.add_child(subtitle_node)
	
	main_vbox.add_child(header_vbox)
	
	button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	
	# Instancia e armazena a referência aos botões
	var txt_new = Database.tr_text("MENU_NEW_GAME") if Database.has_method("tr_text") else "🚀 NOVO JOGO"
	var txt_load = Database.tr_text("MENU_LOAD_GAME") if Database.has_method("tr_text") else "📂 CARREGAR JOGO"
	var txt_opts = Database.tr_text("MENU_OPTIONS") if Database.has_method("tr_text") else "⚙️ OPÇÕES"
	var txt_exit = Database.tr_text("MENU_EXIT") if Database.has_method("tr_text") else "❌ SAIR DO JOGO"
	
	btn_new = _create_styled_button(txt_new, _on_btn_new_game_pressed)
	btn_load = _create_styled_button(txt_load, _on_load_game)
	btn_opts = _create_styled_button(txt_opts, _on_options)
	btn_exit = _create_styled_button(txt_exit, _on_exit)
	
	main_vbox.add_child(button_container)
	margin.add_child(main_vbox)
	card.add_child(margin)
	center.add_child(card)
	
	var footer = Label.new()
	footer.text = "v1.0.4 • Apex F1 SimEngine"
	footer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.position = Vector2(-20, -35)
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color("#475569"))
	add_child(footer)

func _create_styled_button(text: String, callable: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 44
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 13)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.11, 0.14, 0.20, 0.9)
	style_normal.set_corner_radius_all(4)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.18, 0.22, 0.32, 1.0)
	style_hover.border_width_left = 3
	style_hover.border_color = Color("#ef4444")
	style_hover.set_corner_radius_all(4)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_color_override("font_color", Color("#e2e8f0"))
	btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
	
	btn.pressed.connect(callable)
	button_container.add_child(btn)
	return btn

# FUNÇÃO QUE ATUALIZA APENAS OS TEXTOS (SEGURO)
func _update_texts() -> void:
	if not Database.has_method("tr_text"):
		return
		
	if is_instance_valid(subtitle_node):
		subtitle_node.text = Database.tr_text("MENU_SUBTITLE")
	if is_instance_valid(btn_new):
		btn_new.text = Database.tr_text("MENU_NEW_GAME")
	if is_instance_valid(btn_load):
		btn_load.text = Database.tr_text("MENU_LOAD_GAME")
	if is_instance_valid(btn_opts):
		btn_opts.text = Database.tr_text("MENU_OPTIONS")
	if is_instance_valid(btn_exit):
		btn_exit.text = Database.tr_text("MENU_EXIT")

func _animate_menu_entrance() -> void:
	if not is_instance_valid(title_node) or not is_instance_valid(button_container):
		return
		
	title_node.modulate.a = 0.0
	subtitle_node.modulate.a = 0.0
	button_container.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(title_node, "modulate:a", 1.0, 0.5)
	tween.tween_property(subtitle_node, "modulate:a", 1.0, 0.6)
	tween.tween_property(button_container, "modulate:a", 1.0, 0.7)

# --- FLUXO DE ESCOLHA DE MODO DE JOGO ---

func _on_btn_new_game_pressed() -> void:
	_show_mode_selection_modal()

func _show_mode_selection_modal() -> void:
	if is_instance_valid(active_modal):
		active_modal.queue_free()
		
	active_modal = ColorRect.new()
	active_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_modal.color = Color(0, 0, 0, 0.85)
	add_child(active_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_modal.add_child(center)
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(650, 480)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.border_width_top = 4
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(8)
	style.shadow_size = 25
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	
	# Título traduzido
	var lbl_title = Label.new()
	lbl_title.text = Database.tr_text("MODE_TITLE") if Database.has_method("tr_text") else "ESCOLHA O MODO DE JOGO"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 14)
	
	var desc_card = PanelContainer.new()
	desc_card.custom_minimum_size.y = 120
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	desc_style.border_width_left = 4
	desc_style.border_color = Color("#ef4444")
	desc_style.set_corner_radius_all(6)
	desc_card.add_theme_stylebox_override("panel", desc_style)
	
	var desc_margin = MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 18)
	desc_margin.add_theme_constant_override("margin_right", 18)
	desc_margin.add_theme_constant_override("margin_top", 14)
	desc_margin.add_theme_constant_override("margin_bottom", 14)
	
	# Obtenção das descrições traduzidas
	var txt_default = Database.tr_text("MODE_DEFAULT_DESC") if Database.has_method("tr_text") else "Passe o mouse sobre um modo de jogo para ver os detalhes."
	var txt_obs = Database.tr_text("MODE_OBSERVER_DESC") if Database.has_method("tr_text") else "Observador: Para quem quer deixar a simulação seguir de forma independente..."
	var txt_man = Database.tr_text("MODE_MANAGER_DESC") if Database.has_method("tr_text") else "Manager: Permite escolher/criar uma equipe..."

	var lbl_desc = Label.new()
	lbl_desc.text = txt_default
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_font_size_override("font_size", 13)
	lbl_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	desc_margin.add_child(lbl_desc)
	desc_card.add_child(desc_margin)

	# Botão Modo Observador traduzido
	var btn_obs = Button.new()
	btn_obs.text = Database.tr_text("MODE_OBSERVER_BTN") if Database.has_method("tr_text") else "MODO OBSERVADOR"
	btn_obs.custom_minimum_size.y = 52
	btn_obs.add_theme_font_size_override("font_size", 16)
	
	var style_obs = StyleBoxFlat.new()
	style_obs.bg_color = Color(0.012, 0.412, 0.0, 1.0)
	style_obs.set_corner_radius_all(6)
	btn_obs.add_theme_stylebox_override("normal", style_obs)
	
	btn_obs.mouse_entered.connect(func():
		lbl_desc.text = txt_obs
		lbl_desc.add_theme_color_override("font_color", Color("#e2e8f0"))
	)
	btn_obs.mouse_exited.connect(func():
		lbl_desc.text = txt_default
		lbl_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	)
	btn_obs.pressed.connect(func():
		if is_instance_valid(active_modal):
			active_modal.queue_free()
		_start_observer_mode()
	)
	btn_vbox.add_child(btn_obs)
	
	# Botão Modo Manager traduzido
	var btn_man = Button.new()
	btn_man.text = Database.tr_text("MODE_MANAGER_BTN") if Database.has_method("tr_text") else "MODO MANAGER"
	btn_man.custom_minimum_size.y = 52
	btn_man.add_theme_font_size_override("font_size", 16)
	
	var style_man = StyleBoxFlat.new()
	style_man.bg_color = Color(0.745, 0.331, 0.0, 1.0)
	style_man.set_corner_radius_all(6)
	btn_man.add_theme_stylebox_override("normal", style_man)
	
	btn_man.mouse_entered.connect(func():
		lbl_desc.text = txt_man
		lbl_desc.add_theme_color_override("font_color", Color("#e2e8f0"))
	)
	btn_man.mouse_exited.connect(func():
		lbl_desc.text = txt_default
		lbl_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	)
	btn_man.pressed.connect(func():
		_show_manager_options_menu(card)
	)
	btn_vbox.add_child(btn_man)
	
	vbox.add_child(btn_vbox)
	vbox.add_child(desc_card)
	
	# Botão Voltar traduzido
	var btn_cancel = Button.new()
	btn_cancel.text = Database.tr_text("BTN_BACK") if Database.has_method("tr_text") else "VOLTAR"
	btn_cancel.custom_minimum_size.y = 42
	btn_cancel.add_theme_font_size_override("font_size", 13)
	
	var style_cancel = StyleBoxFlat.new()
	style_cancel.bg_color = Color(0.18, 0.22, 0.30, 0.8)
	style_cancel.set_corner_radius_all(4)
	btn_cancel.add_theme_stylebox_override("normal", style_cancel)
	
	btn_cancel.pressed.connect(func():
		if is_instance_valid(active_modal):
			active_modal.queue_free()
			active_modal = null
	)
	vbox.add_child(btn_cancel)
	
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

# --- FLUXO DO MODO MANAGER ---
func _show_manager_options_menu(parent_card: PanelContainer) -> void:
	parent_card.custom_minimum_size = Vector2(750, 480)
	for c in parent_card.get_children():
		c.queue_free()

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_right", 35)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)

	# Título principal do menu
	var lbl_title = Label.new()
	lbl_title.text = Database.tr_text("MANAGER_TITLE") if Database.has_method("tr_text") else "OPÇÕES DO MODO MANAGER"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)

	var grid_opts = HBoxContainer.new()
	grid_opts.add_theme_constant_override("separation", 20)

	# Card 1: Criar Equipe
	var card_create = PanelContainer.new()
	card_create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_c = StyleBoxFlat.new()
	st_c.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	st_c.set_corner_radius_all(6)
	card_create.add_theme_stylebox_override("panel", st_c)
	
	var m_c = MarginContainer.new()
	m_c.add_theme_constant_override("margin_left", 20)
	m_c.add_theme_constant_override("margin_right", 20)
	m_c.add_theme_constant_override("margin_top", 20)
	m_c.add_theme_constant_override("margin_bottom", 20)
	var vb_c = VBoxContainer.new()
	vb_c.add_theme_constant_override("separation", 10)
	
	var l_c_title = Label.new()
	l_c_title.text = Database.tr_text("MANAGER_CREATE_TITLE") if Database.has_method("tr_text") else "🛠️ CRIAR NOVA EQUIPE"
	l_c_title.add_theme_font_size_override("font_size", 16)
	l_c_title.add_theme_color_override("font_color", Color("#ffffff"))
	vb_c.add_child(l_c_title)
	
	var l_c_desc = Label.new()
	l_c_desc.text = Database.tr_text("MANAGER_CREATE_DESC") if Database.has_method("tr_text") else "Fundação total da sua escuderia: defina o nome, cores oficiais, chefe de equipe e país de origem."
	l_c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_c_desc.add_theme_font_size_override("font_size", 12)
	l_c_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	l_c_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb_c.add_child(l_c_desc)
	
	var btn_create = Button.new()
	btn_create.text = Database.tr_text("MANAGER_CREATE_BTN") if Database.has_method("tr_text") else "CRIAR EQUIPE"
	btn_create.custom_minimum_size.y = 44
	btn_create.pressed.connect(func(): _show_create_team_form(parent_card))
	vb_c.add_child(btn_create)
	
	m_c.add_child(vb_c)
	card_create.add_child(m_c)
	grid_opts.add_child(card_create)

	# Card 2: Equipe Existente
	var card_exist = PanelContainer.new()
	card_exist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_e = StyleBoxFlat.new()
	st_e.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	st_e.set_corner_radius_all(6)
	card_exist.add_theme_stylebox_override("panel", st_e)
	
	var m_e = MarginContainer.new()
	m_e.add_theme_constant_override("margin_left", 20)
	m_e.add_theme_constant_override("margin_right", 20)
	m_e.add_theme_constant_override("margin_top", 20)
	m_e.add_theme_constant_override("margin_bottom", 20)
	var vb_e = VBoxContainer.new()
	vb_e.add_theme_constant_override("separation", 10)
	
	var l_e_title = Label.new()
	l_e_title.text = Database.tr_text("MANAGER_EXISTING_TITLE") if Database.has_method("tr_text") else "🏁 EQUIPE EXISTENTE"
	l_e_title.add_theme_font_size_override("font_size", 16)
	l_e_title.add_theme_color_override("font_color", Color("#ffffff"))
	vb_e.add_child(l_e_title)
	
	var l_e_desc = Label.new()
	l_e_desc.text = Database.tr_text("MANAGER_EXISTING_DESC") if Database.has_method("tr_text") else "Assuma o comando de uma das equipes oficiais do campeonato e gerencie seus pilotos e orçamentos."
	l_e_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_e_desc.add_theme_font_size_override("font_size", 12)
	l_e_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	l_e_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb_e.add_child(l_e_desc)
	
	var btn_existing = Button.new()
	btn_existing.text = Database.tr_text("MANAGER_EXISTING_BTN") if Database.has_method("tr_text") else "ESCOLHER EXISTENTE"
	btn_existing.custom_minimum_size.y = 44
	btn_existing.pressed.connect(func(): _show_select_existing_team_form(parent_card))
	vb_e.add_child(btn_existing)
	
	m_e.add_child(vb_e)
	card_exist.add_child(m_e)
	grid_opts.add_child(card_exist)

	vbox.add_child(grid_opts)

	# Botão Voltar
	var btn_back = Button.new()
	btn_back.text = Database.tr_text("BTN_BACK") if Database.has_method("tr_text") else "VOLTAR"
	btn_back.custom_minimum_size.y = 42
	btn_back.add_theme_font_size_override("font_size", 13)
	btn_back.pressed.connect(func(): _show_mode_selection_modal())
	vbox.add_child(btn_back)

	margin.add_child(vbox)
	parent_card.add_child(margin)

func _show_create_team_form(parent_card: PanelContainer) -> void:
	parent_card.custom_minimum_size = Vector2(800, 520)
	for c in parent_card.get_children():
		c.queue_free()

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_right", 35)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)

	# Título principal
	var lbl_title = Label.new()
	lbl_title.text = Database.tr_text("CREATE_TEAM_TITLE") if Database.has_method("tr_text") else "CRIAR SUA EQUIPE"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 14)

	# Campo 1: Nome da Equipe
	var v_tname = VBoxContainer.new()
	v_tname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_tname = Label.new()
	l_tname.text = Database.tr_text("FIELD_TEAM_NAME") if Database.has_method("tr_text") else "Nome da Equipe:"
	l_tname.add_theme_font_size_override("font_size", 13)
	l_tname.add_theme_color_override("font_color", Color("#cbd5e1"))
	v_tname.add_child(l_tname)
	
	var in_tname = LineEdit.new()
	in_tname.placeholder_text = Database.tr_text("PLACEHOLDER_TEAM_NAME") if Database.has_method("tr_text") else "Ex: Apex Grand Prix"
	in_tname.custom_minimum_size.y = 40
	v_tname.add_child(in_tname)
	grid.add_child(v_tname)

	# Campo 2: Chefe de Equipe
	var v_pname = VBoxContainer.new()
	v_pname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_pname = Label.new()
	l_pname.text = Database.tr_text("FIELD_PRINCIPAL_NAME") if Database.has_method("tr_text") else "Nome do Chefe de Equipe:"
	l_pname.add_theme_font_size_override("font_size", 13)
	l_pname.add_theme_color_override("font_color", Color("#cbd5e1"))
	v_pname.add_child(l_pname)
	
	var in_pname = LineEdit.new()
	in_pname.placeholder_text = Database.tr_text("PLACEHOLDER_PRINCIPAL_NAME") if Database.has_method("tr_text") else "Ex: Seu Nome"
	in_pname.custom_minimum_size.y = 40
	v_pname.add_child(in_pname)
	grid.add_child(v_pname)

	# Campo 3: País Sede
	var v_country = VBoxContainer.new()
	v_country.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_country = Label.new()
	l_country.text = Database.tr_text("FIELD_COUNTRY") if Database.has_method("tr_text") else "País Sede:"
	l_country.add_theme_font_size_override("font_size", 13)
	l_country.add_theme_color_override("font_color", Color("#cbd5e1"))
	v_country.add_child(l_country)
	
	var in_country = LineEdit.new()
	in_country.placeholder_text = Database.tr_text("PLACEHOLDER_COUNTRY") if Database.has_method("tr_text") else "Ex: Brasil"
	in_country.custom_minimum_size.y = 40
	v_country.add_child(in_country)
	grid.add_child(v_country)

	# Campo 4: Cor Principal da Equipe
	var v_color = VBoxContainer.new()
	v_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_color = Label.new()
	l_color.text = Database.tr_text("FIELD_MAIN_COLOR") if Database.has_method("tr_text") else "Cor Principal da Equipe:"
	l_color.add_theme_font_size_override("font_size", 13)
	l_color.add_theme_color_override("font_color", Color("#cbd5e1"))
	v_color.add_child(l_color)
	
	var color_picker = ColorPickerButton.new()
	color_picker.color = Color("#ef4444")
	color_picker.custom_minimum_size.y = 40
	v_color.add_child(color_picker)
	grid.add_child(v_color)

	vbox.add_child(grid)

	# Nota Informativa
	var note_card = PanelContainer.new()
	var note_style = StyleBoxFlat.new()
	note_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	note_style.set_corner_radius_all(6)
	note_style.border_width_left = 3
	note_style.border_color = Color("#f59e0b")
	note_card.add_theme_stylebox_override("panel", note_style)

	var note_margin = MarginContainer.new()
	note_margin.add_theme_constant_override("margin_left", 14)
	note_margin.add_theme_constant_override("margin_right", 14)
	note_margin.add_theme_constant_override("margin_top", 10)
	note_margin.add_theme_constant_override("margin_bottom", 10)

	var lbl_note = Label.new()
	lbl_note.text = Database.tr_text("CREATE_TEAM_NOTE") if Database.has_method("tr_text") else "💡 Após criar sua equipe, você iniciará com os parâmetros padrão da categoria e um orçamento inicial básico para desenvolvimento."
	lbl_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_note.add_theme_font_size_override("font_size", 12)
	lbl_note.add_theme_color_override("font_color", Color("#94a3b8"))
	note_margin.add_child(lbl_note)
	note_card.add_child(note_margin)
	vbox.add_child(note_card)

	# Botões Inferiores
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)

	var btn_confirm = Button.new()
	btn_confirm.text = Database.tr_text("BTN_CONFIRM_CREATION") if Database.has_method("tr_text") else "CONFIRMAR CRIAÇÃO"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 44
	btn_confirm.pressed.connect(func():
		var team_name = in_tname.text.strip_edges()
		if team_name.is_empty():
			team_name = "Apex Grand Prix"
		_show_driver_recruitment_menu(parent_card, team_name, 135)
	)
	btn_hbox.add_child(btn_confirm)

	var btn_back = Button.new()
	btn_back.text = Database.tr_text("BTN_BACK") if Database.has_method("tr_text") else "VOLTAR"
	btn_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_back.custom_minimum_size.y = 44
	btn_back.pressed.connect(func(): _show_manager_options_menu(parent_card))
	btn_hbox.add_child(btn_back)

	vbox.add_child(btn_hbox)
	margin.add_child(vbox)
	parent_card.add_child(margin)

func _show_select_existing_team_form(parent_card: PanelContainer) -> void:
	parent_card.custom_minimum_size = Vector2(850, 560)
	for c in parent_card.get_children():
		c.queue_free()

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_right", 35)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)

	# Título principal
	var lbl_title = Label.new()
	lbl_title.text = Database.tr_text("SELECT_TEAM_TITLE") if Database.has_method("tr_text") else "SELEÇÃO DE EQUIPE EXISTENTE"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)

	# Seletor
	var sel_hbox = HBoxContainer.new()
	var l_sel = Label.new()
	l_sel.text = (Database.tr_text("SELECT_TEAM_LABEL") if Database.has_method("tr_text") else "Escolha a Equipe: ") + " "
	l_sel.add_theme_font_size_override("font_size", 14)
	l_sel.add_theme_color_override("font_color", Color("#cbd5e1"))
	sel_hbox.add_child(l_sel)
	
	team_option_button = OptionButton.new()
	team_option_button.custom_minimum_size.y = 42
	team_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_option_button.add_theme_font_size_override("font_size", 14)
	_apply_custom_option_button_styles(team_option_button)
	team_option_button.item_selected.connect(_on_team_dropdown_selected)
	sel_hbox.add_child(team_option_button)
	vbox.add_child(sel_hbox)

	team_info_container = VBoxContainer.new()
	team_info_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	team_info_container.add_theme_constant_override("separation", 12)
	vbox.add_child(team_info_container)

	_populate_existing_teams()

	# Botões inferiores
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)

	var btn_confirm = Button.new()
	btn_confirm.text = Database.tr_text("BTN_SELECT_THIS_TEAM") if Database.has_method("tr_text") else "SELECIONAR ESTA EQUIPE"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 44
	btn_confirm.pressed.connect(func():
		var title = Database.tr_text("MANAGER_MODE_TITLE") if Database.has_method("tr_text") else "MANAGER MODE"
		var msg = Database.tr_text("DEV_MODE_MSG") if Database.has_method("tr_text") else "Modo em desenvolvimento"
		_show_custom_modal(title, msg)
	)
	btn_hbox.add_child(btn_confirm)

	var btn_back = Button.new()
	btn_back.text = Database.tr_text("BTN_BACK") if Database.has_method("tr_text") else "VOLTAR"
	btn_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_back.custom_minimum_size.y = 44
	btn_back.pressed.connect(func(): _show_manager_options_menu(parent_card))
	btn_hbox.add_child(btn_back)

	vbox.add_child(btn_hbox)
	margin.add_child(vbox)
	parent_card.add_child(margin)

func _apply_custom_option_button_styles(opt_btn: OptionButton) -> void:
	var st_norm = StyleBoxFlat.new()
	st_norm.bg_color = Color(0.09, 0.12, 0.18, 1.0)
	st_norm.set_border_width_all(1)
	st_norm.border_color = Color(0.2, 0.25, 0.35, 1.0)
	st_norm.set_corner_radius_all(6)

	var st_hover = StyleBoxFlat.new()
	st_hover.bg_color = Color(0.14, 0.18, 0.26, 1.0)
	st_hover.border_width_left = 3
	st_hover.border_color = Color("#ef4444")
	st_hover.set_corner_radius_all(6)

	opt_btn.add_theme_stylebox_override("normal", st_norm)
	opt_btn.add_theme_stylebox_override("hover", st_hover)
	opt_btn.add_theme_stylebox_override("pressed", st_hover)
	opt_btn.add_theme_color_override("font_color", Color("#f8fafc"))
	opt_btn.add_theme_color_override("font_hover_color", Color("#ffffff"))

	var popup = opt_btn.get_popup()
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	popup_style.set_border_width_all(1)
	popup_style.border_color = Color("#ef4444")
	popup_style.set_corner_radius_all(6)
	popup_style.set_content_margin_all(8)
	
	popup.add_theme_stylebox_override("panel", popup_style)
	popup.add_theme_color_override("font_color", Color("#cbd5e1"))
	popup.add_theme_color_override("font_hover_color", Color("#ffffff"))
	popup.add_theme_color_override("font_radio_color", Color("#ef4444"))
	popup.add_theme_font_size_override("font_size", 13)

func _populate_existing_teams() -> void:
	if not is_instance_valid(team_option_button):
		return
		
	team_option_button.clear()
	var teams = Database.teams if "teams" in Database else []
	for i in range(teams.size()):
		var t_name = teams[i].get("Nome", teams[i].get("nome", "Equipe " + str(i + 1)))
		team_option_button.add_item(t_name, i)
	if teams.size() > 0:
		_on_team_dropdown_selected(0)

func _on_team_dropdown_selected(index: int) -> void:
	if not is_instance_valid(team_info_container):
		return

	for c in team_info_container.get_children():
		c.queue_free()

	var teams = Database.teams if "teams" in Database else []
	if index < 0 or index >= teams.size():
		return
		
	var team = teams[index]
	var team_name = team.get("Nome", team.get("nome", "-"))

	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# COLUNA ESQUERDA
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 12)

	var car_card = PanelContainer.new()
	var st_car = StyleBoxFlat.new()
	st_car.bg_color = Color(0.06, 0.08, 0.12, 0.85)
	st_car.set_corner_radius_all(6)
	st_car.border_width_left = 3
	st_car.border_color = Color("#3b82f6")
	car_card.add_theme_stylebox_override("panel", st_car)

	var m_car = MarginContainer.new()
	m_car.add_theme_constant_override("margin_left", 14)
	m_car.add_theme_constant_override("margin_right", 14)
	m_car.add_theme_constant_override("margin_top", 12)
	m_car.add_theme_constant_override("margin_bottom", 12)

	var vb_car = VBoxContainer.new()
	vb_car.add_theme_constant_override("separation", 8)

	var lbl_car_title = Label.new()
	lbl_car_title.text = Database.tr_text("CAR_PERFORMANCE_TITLE") if Database.has_method("tr_text") else "🏎️ DESEMPENHO DO CARRO"
	lbl_car_title.add_theme_font_size_override("font_size", 14)
	lbl_car_title.add_theme_color_override("font_color", Color("#60a5fa"))
	vb_car.add_child(lbl_car_title)

	var motor_val = team.get("Motor", team.get("motor", 0))
	var aero_val = team.get("Aero", team.get("aero", 0))
	var chassi_val = team.get("Chassi", team.get("chassi", 0))
	var conf_val = team.get("Confiabilidade", team.get("confiabilidade", 0))

	var txt_engine = (Database.tr_text("ATTR_ENGINE") if Database.has_method("tr_text") else "Motor") + ":"
	var txt_aero = (Database.tr_text("ATTR_AERO") if Database.has_method("tr_text") else "Aerodinâmica") + ":"
	var txt_chassis = (Database.tr_text("ATTR_CHASSIS") if Database.has_method("tr_text") else "Chassi") + ":"
	var txt_reliab = (Database.tr_text("ATTR_RELIABILITY") if Database.has_method("tr_text") else "Confiabilidade") + ":"

	vb_car.add_child(_create_attribute_bar(txt_engine, motor_val))
	vb_car.add_child(_create_attribute_bar(txt_aero, aero_val))
	vb_car.add_child(_create_attribute_bar(txt_chassis, chassi_val))
	vb_car.add_child(_create_attribute_bar(txt_reliab, conf_val, "%"))

	m_car.add_child(vb_car)
	car_card.add_child(m_car)
	left_vbox.add_child(car_card)

	var budget_card = PanelContainer.new()
	var st_b = StyleBoxFlat.new()
	st_b.bg_color = Color(0.06, 0.08, 0.12, 0.85)
	st_b.set_corner_radius_all(6)
	st_b.border_width_left = 3
	st_b.border_color = Color("#10b981")
	budget_card.add_theme_stylebox_override("panel", st_b)

	var m_b = MarginContainer.new()
	m_b.add_theme_constant_override("margin_left", 14)
	m_b.add_theme_constant_override("margin_right", 14)
	m_b.add_theme_constant_override("margin_top", 10)
	m_b.add_theme_constant_override("margin_bottom", 10)

	var vb_b = VBoxContainer.new()
	var lbl_b_title = Label.new()
	lbl_b_title.text = Database.tr_text("BUDGET_TITLE") if Database.has_method("tr_text") else "💰 ORÇAMENTO DISPONÍVEL"
	lbl_b_title.add_theme_font_size_override("font_size", 12)
	lbl_b_title.add_theme_color_override("font_color", Color("#34d399"))
	vb_b.add_child(lbl_b_title)

	var budget = team.get("Orcamento", team.get("orcamento", team.get("Budget", 0)))
	var unit_millions = Database.tr_text("UNIT_MILLIONS") if Database.has_method("tr_text") else "Milhões"
	var lbl_b_val = Label.new()
	lbl_b_val.text = "$" + str(budget) + " " + unit_millions
	lbl_b_val.add_theme_font_size_override("font_size", 20)
	lbl_b_val.add_theme_color_override("font_color", Color("#ffffff"))
	vb_b.add_child(lbl_b_val)

	m_b.add_child(vb_b)
	budget_card.add_child(m_b)
	left_vbox.add_child(budget_card)

	content_hbox.add_child(left_vbox)

	# COLUNA DIREITA
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var drivers_card = PanelContainer.new()
	drivers_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st_d = StyleBoxFlat.new()
	st_d.bg_color = Color(0.06, 0.08, 0.12, 0.85)
	st_d.set_corner_radius_all(6)
	st_d.border_width_left = 3
	st_d.border_color = Color("#f59e0b")
	drivers_card.add_theme_stylebox_override("panel", st_d)

	var m_d = MarginContainer.new()
	m_d.add_theme_constant_override("margin_left", 14)
	m_d.add_theme_constant_override("margin_right", 14)
	m_d.add_theme_constant_override("margin_top", 12)
	m_d.add_theme_constant_override("margin_bottom", 12)

	var vb_d = VBoxContainer.new()
	vb_d.add_theme_constant_override("separation", 10)

	var lbl_d_title = Label.new()
	lbl_d_title.text = Database.tr_text("MAIN_DRIVERS_TITLE") if Database.has_method("tr_text") else "👤 PILOTOS TITULARES"
	lbl_d_title.add_theme_font_size_override("font_size", 14)
	lbl_d_title.add_theme_color_override("font_color", Color("#fbbf24"))
	vb_d.add_child(lbl_d_title)

	var drivers = []
	var all_drivers = Database.drivers if "drivers" in Database else []
	for d in all_drivers:
		var d_team = d.get("Equipe", d.get("equipe", ""))
		if d_team == team_name:
			drivers.append(d)

	if drivers.size() == 0:
		var l_empty = Label.new()
		l_empty.text = Database.tr_text("NO_DRIVERS_FOUND") if Database.has_method("tr_text") else "Nenhum piloto vinculado a esta equipe."
		l_empty.add_theme_font_size_override("font_size", 12)
		l_empty.add_theme_color_override("font_color", Color("#94a3b8"))
		vb_d.add_child(l_empty)
	else:
		for d in drivers:
			var d_box = HBoxContainer.new()
			var d_name = d.get("Nome", d.get("nome", "-"))
			var d_ovr = d.get("Habilidade", d.get("Overall", d.get("overall", "-")))

			var l_name = Label.new()
			l_name.text = d_name
			l_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l_name.add_theme_font_size_override("font_size", 13)
			l_name.add_theme_color_override("font_color", Color("#ffffff"))
			d_box.add_child(l_name)

			var l_ovr = Label.new()
			l_ovr.text = "OVR: " + str(d_ovr)
			l_ovr.add_theme_font_size_override("font_size", 13)
			l_ovr.add_theme_color_override("font_color", Color("#fbbf24"))
			d_box.add_child(l_ovr)

			vb_d.add_child(d_box)

	m_d.add_child(vb_d)
	drivers_card.add_child(m_d)
	right_vbox.add_child(drivers_card)

	content_hbox.add_child(right_vbox)
	team_info_container.add_child(content_hbox)

func _create_attribute_bar(label_text: String, value: int, suffix: String = "") -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 110
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
	hbox.add_child(lbl)
	var pbar = ProgressBar.new()
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbar.custom_minimum_size.y = 16
	pbar.min_value = 0
	pbar.max_value = 100
	pbar.value = value
	pbar.show_percentage = false
	hbox.add_child(pbar)
	var lbl_val = Label.new()
	lbl_val.text = str(value) + suffix
	lbl_val.custom_minimum_size.x = 35
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_val.add_theme_font_size_override("font_size", 12)
	lbl_val.add_theme_color_override("font_color", Color("#ffffff"))
	hbox.add_child(lbl_val)
	return hbox

func _start_observer_mode() -> void:
	if Database.has_method("reset_database"):
		Database.reset_database()
	Database.current_view = "dashboard"
	get_tree().change_scene_to_file("res://main.tscn")

func _on_load_game() -> void:
	if Database.has_any_save():
		var modal = SaveSlotModal.new()
		modal.open_modal(self, SaveSlotModal.Mode.LOAD, func():
			Database.current_view = "dashboard"
			get_tree().change_scene_to_file("res://main.tscn")
		)
	else:
		_show_custom_modal("CARREGAR JOGO", "Nenhum arquivo de save foi encontrado nos slots.")

func _on_options() -> void:
	var options_script = preload("res://views/options_view.gd")
	var options_node = options_script.new()
	
	# o menu principal atualiza imediatamente todos os textos para o idioma salvo!
	options_node.tree_exited.connect(_update_texts)
	
	add_child(options_node)

func _on_exit() -> void:
	_show_exit_confirmation_modal()

func _show_exit_confirmation_modal() -> void:
	if is_instance_valid(active_modal):
		active_modal.queue_free()
	active_modal = ColorRect.new()
	active_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_modal.color = Color(0, 0, 0, 0.8)
	add_child(active_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_modal.add_child(center)
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 200)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.border_width_top = 3
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(6)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	
	var lbl_title = Label.new()
	lbl_title.text = Database.tr_text("EXIT_MODAL_TITLE") if Database.has_method("tr_text") else "SAIR DO JOGO"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var lbl_msg = Label.new()
	lbl_msg.text = Database.tr_text("EXIT_MODAL_MSG") if Database.has_method("tr_text") else "Tem certeza de que deseja sair do Apex F1 Manager?"
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 13)
	lbl_msg.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_msg)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	
	var btn_confirm = Button.new()
	btn_confirm.text = Database.tr_text("EXIT_BTN_YES") if Database.has_method("tr_text") else "Sim, Sair"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 38
	btn_confirm.add_theme_font_size_override("font_size", 12)
	var style_confirm = StyleBoxFlat.new()
	style_confirm.bg_color = Color(0.8, 0.15, 0.15, 1.0)
	style_confirm.set_corner_radius_all(4)
	btn_confirm.add_theme_stylebox_override("normal", style_confirm)
	btn_confirm.pressed.connect(func(): get_tree().quit())
	
	var btn_cancel = Button.new()
	btn_cancel.text = Database.tr_text("EXIT_BTN_NO") if Database.has_method("tr_text") else "Não, Cancelar"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.custom_minimum_size.y = 38
	btn_cancel.add_theme_font_size_override("font_size", 12)
	var style_cancel = StyleBoxFlat.new()
	style_cancel.bg_color = Color(0.18, 0.22, 0.30, 1.0)
	style_cancel.set_corner_radius_all(4)
	btn_cancel.add_theme_stylebox_override("normal", style_cancel)
	btn_cancel.pressed.connect(func():
		if is_instance_valid(active_modal):
			active_modal.queue_free()
			active_modal = null
	)
	
	btn_hbox.add_child(btn_confirm)
	btn_hbox.add_child(btn_cancel)
	vbox.add_child(btn_hbox)
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

func _show_custom_modal(title: String, message: String) -> void:
	if is_instance_valid(active_modal):
		active_modal.queue_free()
		
	active_modal = ColorRect.new()
	active_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_modal.color = Color(0, 0, 0, 0.8)
	add_child(active_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_modal.add_child(center)
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 200)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.border_width_top = 3
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(6)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var lbl_msg = Label.new()
	lbl_msg.text = message
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 13)
	lbl_msg.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_msg)
	
	var btn_ok = Button.new()
	btn_ok.text = Database.tr_text("BTN_UNDERSTOOD") if Database.has_method("tr_text") else "ENTENDIDO"
	btn_ok.custom_minimum_size.y = 38
	btn_ok.add_theme_font_size_override("font_size", 12)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.22, 0.30, 1.0)
	btn_style.set_corner_radius_all(4)
	btn_ok.add_theme_stylebox_override("normal", btn_style)
	
	btn_ok.pressed.connect(func():
		if is_instance_valid(active_modal):
			active_modal.queue_free()
			active_modal = null
	)
	
	vbox.add_child(btn_ok)
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

func _show_driver_recruitment_menu(parent_card: PanelContainer, team_name: String, remaining_budget: int) -> void:
	parent_card.custom_minimum_size = Vector2(1220, 640)
	for c in parent_card.get_children():
		c.queue_free()

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)

	# Título Principal do Menu
	var lbl_main_title = Label.new()
	lbl_main_title.text = (Database.tr_text("MANAGER_RECRUIT_TITLE") if Database.has_method("tr_text") else "CONTRATAÇÃO DE PILOTOS") + " - " + team_name
	lbl_main_title.add_theme_font_size_override("font_size", 18)
	lbl_main_title.add_theme_color_override("font_color", Color("#ef4444"))
	main_vbox.add_child(lbl_main_title)

	# Grid Horizontal dividindo Tabela (Esquerda) e Caixa de Resumo (Direita)
	var body_hbox = HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 16)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ==========================================
	# COLUNA ESQUERDA: TABELA DE MERCADO
	# ==========================================
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)

	# Cabeçalho da Tabela
	var table_header = PanelContainer.new()
	var th_style = StyleBoxFlat.new()
	th_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	th_style.set_corner_radius_all(4)
	table_header.add_theme_stylebox_override("panel", th_style)

	var th_margin = MarginContainer.new()
	th_margin.add_theme_constant_override("margin_left", 10)
	th_margin.add_theme_constant_override("margin_right", 10)
	th_margin.add_theme_constant_override("margin_top", 8)
	th_margin.add_theme_constant_override("margin_bottom", 8)

	var th_hbox = HBoxContainer.new()
	th_hbox.add_theme_constant_override("separation", 8)

	_add_header_col(th_hbox, Database.tr_text("TABLE_NAME"), 150)
	_add_header_col(th_hbox, Database.tr_text("TABLE_AGE"), 65)
	_add_header_col(th_hbox, Database.tr_text("TABLE_TEAM"), 115)
	_add_header_col(th_hbox, Database.tr_text("TABLE_OVR"), 160)
	_add_header_col(th_hbox, Database.tr_text("TABLE_PRICE"), 110)
	_add_header_col(th_hbox, Database.tr_text("TABLE_ACTION"), 95)

	th_margin.add_child(th_hbox)
	table_header.add_child(th_margin)
	left_vbox.add_child(table_header)

	# Scroll de Pilotos
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 400

	var drivers_vbox = VBoxContainer.new()
	drivers_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drivers_vbox.add_theme_constant_override("separation", 6)

	var all_drivers = (Database.drivers if "drivers" in Database else []).duplicate()
	all_drivers.sort_custom(func(a, b):
		var ovr_a = float(a.get("Habilidade", a.get("Overall", a.get("overall", 75))))
		var ovr_b = float(b.get("Habilidade", b.get("Overall", b.get("overall", 75))))
		return ovr_a > ovr_b
	)

	for driver in all_drivers:
		var card_driver = _build_driver_market_row(driver, parent_card, team_name, remaining_budget)
		drivers_vbox.add_child(card_driver)

	scroll.add_child(drivers_vbox)
	left_vbox.add_child(scroll)
	body_hbox.add_child(left_vbox)

	# ==========================================
	# COLUNA DIREITA: CAIXA DE RESUMO DA EQUIPE
	# ==========================================
	var summary_card = PanelContainer.new()
	summary_card.custom_minimum_size.x = 330
	var sum_style = StyleBoxFlat.new()
	sum_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	sum_style.border_width_left = 3
	sum_style.border_color = Color("#ef4444")
	sum_style.set_corner_radius_all(6)
	summary_card.add_theme_stylebox_override("panel", sum_style)

	var sum_margin = MarginContainer.new()
	sum_margin.add_theme_constant_override("margin_left", 14)
	sum_margin.add_theme_constant_override("margin_right", 14)
	sum_margin.add_theme_constant_override("margin_top", 14)
	sum_margin.add_theme_constant_override("margin_bottom", 14)

	var sum_vbox = VBoxContainer.new()
	sum_vbox.add_theme_constant_override("separation", 10)

	var lbl_sum_title = Label.new()
	lbl_sum_title.text = Database.tr_text("SUMMARY_BOX_TITLE") if Database.has_method("tr_text") else "RESUMO DA ESCUDERIA"
	lbl_sum_title.add_theme_font_size_override("font_size", 14)
	lbl_sum_title.add_theme_color_override("font_color", Color("#ef4444"))
	sum_vbox.add_child(lbl_sum_title)

	var txt_undef = Database.tr_text("STATUS_UNDEFINED") if Database.has_method("tr_text") else "A definir"

	# 1. Pilotos Contratados (Com Ressarcimento/Cancelamento)
	var lbl_drv_title = Label.new()
	lbl_drv_title.text = Database.tr_text("SUMMARY_DRIVERS") if Database.has_method("tr_text") else "👤 PILOTOS CONTRATADOS"
	lbl_drv_title.add_theme_font_size_override("font_size", 12)
	lbl_drv_title.add_theme_color_override("font_color", Color("#fbbf24"))
	sum_vbox.add_child(lbl_drv_title)

	for i in range(2):
		var p_box = HBoxContainer.new()
		p_box.add_theme_constant_override("separation", 6)

		var l_p = Label.new()
		l_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l_p.add_theme_font_size_override("font_size", 11)
		l_p.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

		var l_v = Label.new()
		l_v.add_theme_font_size_override("font_size", 11)

		if manager_selected_drivers.size() > i:
			var d = manager_selected_drivers[i]
			var d_salary = int(d.get("signed_salary", _calculate_driver_asking_price(d)))
			l_p.text = "• " + str(d.get("Nome", "Piloto"))
			l_p.add_theme_color_override("font_color", Color("#ffffff"))
			l_v.text = "$" + str(d_salary) + "M"
			l_v.add_theme_color_override("font_color", Color("#38bdf8"))

			# Botão de Cancelamento com RESSARCIMENTO do Orçamento
			var btn_rem_d = Button.new()
			btn_rem_d.text = "❌"
			btn_rem_d.custom_minimum_size = Vector2(24, 20)
			btn_rem_d.add_theme_font_size_override("font_size", 10)
			btn_rem_d.flat = true
			btn_rem_d.pressed.connect(func():
				manager_selected_drivers.remove_at(i)
				# Devolve o valor exato do salário de volta ao orçamento restante
				var restored_budget = remaining_budget + d_salary
				_show_driver_recruitment_menu(parent_card, team_name, restored_budget)
			)
			p_box.add_child(l_p)
			p_box.add_child(l_v)
			p_box.add_child(btn_rem_d)
		else:
			l_p.text = "• " + txt_undef
			l_p.add_theme_color_override("font_color", Color("#64748b"))
			l_v.text = "-"
			l_v.add_theme_color_override("font_color", Color("#64748b"))
			p_box.add_child(l_p)
			p_box.add_child(l_v)

		sum_vbox.add_child(p_box)

	# 2. Motor Escolhido (Com Cancelamento)
	var lbl_eng_title = Label.new()
	lbl_eng_title.text = Database.tr_text("SUMMARY_ENGINE") if Database.has_method("tr_text") else "🏎️ MOTOR DA EQUIPE"
	lbl_eng_title.add_theme_font_size_override("font_size", 12)
	lbl_eng_title.add_theme_color_override("font_color", Color("#fbbf24"))
	sum_vbox.add_child(lbl_eng_title)

	var eng_box = HBoxContainer.new()
	eng_box.add_theme_constant_override("separation", 6)
	var l_eng_p = Label.new()
	l_eng_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_eng_p.add_theme_font_size_override("font_size", 11)

	var l_eng_v = Label.new()
	l_eng_v.add_theme_font_size_override("font_size", 11)

	if not selected_engine.is_empty():
		var eng_price = int(selected_engine.get("price", 0))
		l_eng_p.text = "• " + str(selected_engine.get("name", "Motor"))
		l_eng_p.add_theme_color_override("font_color", Color("#ffffff"))
		l_eng_v.text = "$" + str(eng_price) + "M"
		l_eng_v.add_theme_color_override("font_color", Color("#38bdf8"))

		var btn_rem_eng = Button.new()
		btn_rem_eng.text = "❌"
		btn_rem_eng.custom_minimum_size = Vector2(24, 20)
		btn_rem_eng.add_theme_font_size_override("font_size", 10)
		btn_rem_eng.flat = true
		btn_rem_eng.pressed.connect(func():
			selected_engine.clear()
			_show_driver_recruitment_menu(parent_card, team_name, remaining_budget + eng_price)
		)
		eng_box.add_child(l_eng_p)
		eng_box.add_child(l_eng_v)
		eng_box.add_child(btn_rem_eng)
	else:
		l_eng_p.text = "• " + txt_undef
		l_eng_p.add_theme_color_override("font_color", Color("#64748b"))
		l_eng_v.text = "-"
		l_eng_v.add_theme_color_override("font_color", Color("#64748b"))
		eng_box.add_child(l_eng_p)
		eng_box.add_child(l_eng_v)
	sum_vbox.add_child(eng_box)

	# 3. Chassi Escolhido (Com Cancelamento)
	var lbl_cha_title = Label.new()
	lbl_cha_title.text = Database.tr_text("SUMMARY_CHASSIS") if Database.has_method("tr_text") else "🛠️ CHASSI DA EQUIPE"
	lbl_cha_title.add_theme_font_size_override("font_size", 12)
	lbl_cha_title.add_theme_color_override("font_color", Color("#fbbf24"))
	sum_vbox.add_child(lbl_cha_title)

	var cha_box = HBoxContainer.new()
	cha_box.add_theme_constant_override("separation", 6)
	var l_cha_p = Label.new()
	l_cha_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_cha_p.add_theme_font_size_override("font_size", 11)

	var l_cha_v = Label.new()
	l_cha_v.add_theme_font_size_override("font_size", 11)

	if not selected_chassis.is_empty():
		var cha_price = int(selected_chassis.get("price", 0))
		l_cha_p.text = "• " + str(selected_chassis.get("name", "Chassi"))
		l_cha_p.add_theme_color_override("font_color", Color("#ffffff"))
		l_cha_v.text = "$" + str(cha_price) + "M"
		l_cha_v.add_theme_color_override("font_color", Color("#38bdf8"))

		var btn_rem_cha = Button.new()
		btn_rem_cha.text = "❌"
		btn_rem_cha.custom_minimum_size = Vector2(24, 20)
		btn_rem_cha.add_theme_font_size_override("font_size", 10)
		btn_rem_cha.flat = true
		btn_rem_cha.pressed.connect(func():
			selected_chassis.clear()
			_show_driver_recruitment_menu(parent_card, team_name, remaining_budget + cha_price)
		)
		cha_box.add_child(l_cha_p)
		cha_box.add_child(l_cha_v)
		cha_box.add_child(btn_rem_cha)
	else:
		l_cha_p.text = "• " + txt_undef
		l_cha_p.add_theme_color_override("font_color", Color("#64748b"))
		l_cha_v.text = "-"
		l_cha_v.add_theme_color_override("font_color", Color("#64748b"))
		cha_box.add_child(l_cha_p)
		cha_box.add_child(l_cha_v)
	sum_vbox.add_child(cha_box)

	# 4. Atributos do Carro
	var lbl_car_title = Label.new()
	lbl_car_title.text = Database.tr_text("SUMMARY_CAR_PERF") if Database.has_method("tr_text") else "📊 ATRIBUTOS DO CARRO"
	lbl_car_title.add_theme_font_size_override("font_size", 12)
	lbl_car_title.add_theme_color_override("font_color", Color("#60a5fa"))
	sum_vbox.add_child(lbl_car_title)

	var txt_eng = Database.tr_text("ATTR_ENGINE") if Database.has_method("tr_text") else "Motor"
	var txt_aero = Database.tr_text("ATTR_AERO") if Database.has_method("tr_text") else "Aerodinâmica"
	var txt_chas = Database.tr_text("ATTR_CHASSIS") if Database.has_method("tr_text") else "Chassi"
	var txt_rel = Database.tr_text("ATTR_RELIABILITY") if Database.has_method("tr_text") else "Confiabilidade"

	sum_vbox.add_child(_create_attribute_bar(txt_eng + ":", 70))
	sum_vbox.add_child(_create_attribute_bar(txt_aero + ":", 70))
	sum_vbox.add_child(_create_attribute_bar(txt_chas + ":", 70))
	sum_vbox.add_child(_create_attribute_bar(txt_rel + ":", 75, "%"))

	# 5. Orçamento Restante
	var budget_divider = HSeparator.new()
	sum_vbox.add_child(budget_divider)

	var txt_budget_label = Database.tr_text("BUDGET_REMAINING") if Database.has_method("tr_text") else "Orçamento Restante:"
	var lbl_b_title = Label.new()
	lbl_b_title.text = "💰 " + txt_budget_label
	lbl_b_title.add_theme_font_size_override("font_size", 12)
	lbl_b_title.add_theme_color_override("font_color", Color("#34d399"))
	sum_vbox.add_child(lbl_b_title)

	var lbl_b_val = Label.new()
	lbl_b_val.text = "$" + str(remaining_budget) + "M"
	lbl_b_val.add_theme_font_size_override("font_size", 22)
	lbl_b_val.add_theme_color_override("font_color", Color("#10b981"))
	sum_vbox.add_child(lbl_b_val)

	sum_margin.add_child(sum_vbox)
	summary_card.add_child(sum_margin)
	body_hbox.add_child(summary_card)

	main_vbox.add_child(body_hbox)

	# ==========================================
	# BOTÕES INFERIORES (CANTO INFERIOR ESQUERDO)
	# ==========================================
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)

	# Condição de preenchimento total: 2 pilotos contratados + motor + chassi
	var is_all_selected = (manager_selected_drivers.size() >= 2) and (not selected_engine.is_empty()) and (not selected_chassis.is_empty())

	if is_all_selected:
		# Botão AVANÇAR em Verde no Canto Inferior Esquerdo
		var btn_advance = Button.new()
		btn_advance.text = Database.tr_text("BTN_ADVANCE") if Database.has_method("tr_text") else "▶ AVANÇAR"
		btn_advance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_advance.custom_minimum_size.y = 42

		var st_adv = StyleBoxFlat.new()
		st_adv.bg_color = Color("#10b981") # Verde
		st_adv.set_corner_radius_all(4)
		btn_advance.add_theme_stylebox_override("normal", st_adv)
		btn_advance.add_theme_color_override("font_color", Color("#ffffff"))
		btn_advance.add_theme_font_size_override("font_size", 14)

		btn_advance.pressed.connect(func():
			var title = Database.tr_text("MANAGER_MODE_TITLE") if Database.has_method("tr_text") else "MODO MANAGER"
			var msg = Database.tr_text("DEV_MODE_MSG") if Database.has_method("tr_text") else "Modo em desenvolvimento"
			_show_custom_modal(title, msg)
		)
		btn_hbox.add_child(btn_advance)
	else:
		# Exibe o botão padrão de "FINALIZAR E INICIAR TEMPORADA" desativado até completar todas as escolhas
		var btn_finalize = Button.new()
		btn_finalize.text = Database.tr_text("CONFIRM_TEAM_FINAL") if Database.has_method("tr_text") else "FINALIZAR E INICIAR TEMPORADA"
		btn_finalize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_finalize.custom_minimum_size.y = 42
		btn_finalize.disabled = true
		btn_hbox.add_child(btn_finalize)

	var btn_back = Button.new()
	btn_back.text = Database.tr_text("BTN_BACK") if Database.has_method("tr_text") else "VOLTAR"
	btn_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_back.custom_minimum_size.y = 42
	btn_back.pressed.connect(func(): _show_manager_options_menu(parent_card))
	btn_hbox.add_child(btn_back)

	main_vbox.add_child(btn_hbox)
	margin.add_child(main_vbox)
	parent_card.add_child(margin)

func _create_summary_item(title: String, val: String) -> VBoxContainer:
	var vb = VBoxContainer.new()
	var l_t = Label.new()
	l_t.text = title
	l_t.add_theme_font_size_override("font_size", 11)
	l_t.add_theme_color_override("font_color", Color("#94a3b8"))

	var l_v = Label.new()
	l_v.text = "• " + val
	l_v.add_theme_font_size_override("font_size", 11)
	l_v.add_theme_color_override("font_color", Color("#64748b") if val == Database.tr_text("STATUS_UNDEFINED") else Color("#ffffff"))

	vb.add_child(l_t)
	vb.add_child(l_v)
	return vb

func _add_header_col(parent: HBoxContainer, text: String, min_width: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_width
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#ef4444"))
	if min_width == 100:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)

func _build_driver_market_row(driver: Dictionary, parent_card: PanelContainer, team_name: String, remaining_budget: int) -> PanelContainer:
	var row = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	row_style.set_corner_radius_all(4)
	row.add_theme_stylebox_override("panel", row_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var d_name = driver.get("Nome", driver.get("nome", "Piloto"))
	var d_age = int(driver.get("Idade", driver.get("idade", 20)))
	var d_ovr = float(driver.get("Habilidade", driver.get("Overall", driver.get("overall", 75))))
	var d_team = driver.get("Equipe", driver.get("equipe", "Free Agent"))
	var d_val = _calculate_driver_asking_price(driver)

	# Coluna 1: Nome (150px)
	var lbl_name = Label.new()
	lbl_name.text = d_name
	lbl_name.custom_minimum_size.x = 150
	lbl_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_name.add_theme_font_size_override("font_size", 13)
	lbl_name.add_theme_color_override("font_color", Color("#ffffff"))
	hbox.add_child(lbl_name)

	# Coluna 2: Idade (65px)
	var txt_yrs = Database.tr_text("TEXT_YEARS_SHORT") if Database.has_method("tr_text") else "anos"
	var lbl_age = Label.new()
	lbl_age.text = str(d_age) + " " + txt_yrs
	lbl_age.custom_minimum_size.x = 65
	lbl_age.add_theme_font_size_override("font_size", 12)
	lbl_age.add_theme_color_override("font_color", Color("#cbd5e1"))
	hbox.add_child(lbl_age)

	# Coluna 3: Equipe (115px)
	var lbl_team = Label.new()
	lbl_team.text = d_team
	lbl_team.custom_minimum_size.x = 115
	lbl_team.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_team.add_theme_font_size_override("font_size", 12)
	lbl_team.add_theme_color_override("font_color", Color("#94a3b8"))
	hbox.add_child(lbl_team)

	# Coluna 4: OVR (160px)
	var ovr_container = HBoxContainer.new()
	ovr_container.custom_minimum_size.x = 160
	ovr_container.add_theme_constant_override("separation", 6)

	var progress = TextureProgressBar.new()
	progress.min_value = 0
	progress.max_value = 100
	progress.value = d_ovr
	progress.custom_minimum_size = Vector2(95, 14)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.nine_patch_stretch = true
	progress.tint_progress = Color("#f59e0b")

	var bg_img = Image.create(95, 14, false, Image.FORMAT_RGBA8)
	bg_img.fill(Color(0.2, 0.25, 0.35, 1.0))
	progress.texture_under = ImageTexture.create_from_image(bg_img)

	var fill_img = Image.create(95, 14, false, Image.FORMAT_RGBA8)
	fill_img.fill(Color(1.0, 1.0, 1.0, 1.0))
	progress.texture_progress = ImageTexture.create_from_image(fill_img)

	ovr_container.add_child(progress)

	var lbl_ovr = Label.new()
	lbl_ovr.text = str(snapped(d_ovr, 0.1))
	lbl_ovr.add_theme_font_size_override("font_size", 12)
	lbl_ovr.add_theme_color_override("font_color", Color("#fbbf24"))
	ovr_container.add_child(lbl_ovr)

	hbox.add_child(ovr_container)

	# Coluna 5: Valor de Contratação (110px)
	var lbl_price = Label.new()
	lbl_price.text = "$" + str(d_val) + "M"
	lbl_price.custom_minimum_size.x = 110
	lbl_price.add_theme_font_size_override("font_size", 13)
	lbl_price.add_theme_color_override("font_color", Color("#fbbf24"))
	hbox.add_child(lbl_price)

	# Coluna 6: Botão Negociar
	var btn_negotiate = Button.new()
	btn_negotiate.custom_minimum_size = Vector2(95, 30)
	btn_negotiate.add_theme_font_size_override("font_size", 11)

	var is_signed = false
	for s_driver in manager_selected_drivers:
		if s_driver.get("Nome", "") == d_name:
			is_signed = true
			break

	var attempts = driver_negotiation_attempts.get(d_name, 0)

	if is_signed:
		btn_negotiate.text = "OK"
		btn_negotiate.disabled = true
	elif attempts >= 3:
		btn_negotiate.text = Database.tr_text("BTN_LOCKED") if Database.has_method("tr_text") else "BLOQUEADO"
		btn_negotiate.disabled = true
		btn_negotiate.add_theme_color_override("font_color", Color("#ef4444"))
	else:
		btn_negotiate.text = (Database.tr_text("HIRE_BTN") if Database.has_method("tr_text") else "NEGOCIAR") + (" (%d/3)" % (3 - attempts) if attempts > 0 else "")
		btn_negotiate.pressed.connect(func():
			# --- MECÂNICA DE RECUSA POR PRESTÍGIO DA EQUIPE ---
			var refusal_chance: float = 0.0
			
			if d_ovr > 85.0:
				# Pilotos TOP (OVR > 85): entre 85% e 99% de chance de recusar
				refusal_chance = 85.0 + (float(abs(hash(d_name)) % 15))
			else:
				# Outros pilotos: entre 1% e 10% de chance de recusar
				refusal_chance = 1.0 + (float(abs(hash(d_name)) % 10))

			# Sorteio do teste de recusa
			var roll = randf() * 100.0
			if roll < refusal_chance:
				# Bloqueia o piloto permanentemente marcando o limite de 3 tentativas
				driver_negotiation_attempts[d_name] = 3
				
				var alert_title = Database.tr_text("REFUSAL_MODAL_TITLE") if Database.has_method("tr_text") else "🚫 NEGOCIAÇÃO RECUSADA"
				var alert_template = Database.tr_text("REFUSAL_MODAL_MSG") if Database.has_method("tr_text") else "O piloto %s não tem interesse em negociar com uma nova escuderia sem prestígio no momento."
				var alert_msg = alert_template % d_name
				
				# Exibe o alerta sem fechar a interface do fundo
				_show_alert_modal(alert_title, alert_msg)
				
				# Atualiza a lista/botão para exibir o status "BLOQUEADO"
				_show_driver_recruitment_menu(parent_card, team_name, remaining_budget)
				return

			# Se o piloto aceitar ouvir a proposta, abre o modal de contrato
			_show_negotiation_modal(driver, parent_card, team_name, remaining_budget)
		)

	hbox.add_child(btn_negotiate)
	margin.add_child(hbox)
	row.add_child(margin)
	return row

func _show_negotiation_modal(driver: Dictionary, parent_card: PanelContainer, team_name: String, remaining_budget: int) -> void:
	# 1. Instancia uma tela de sobreposição própria (não destrói a tela de recrutamento do fundo)
	var neg_modal = ColorRect.new()
	neg_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	neg_modal.color = Color(0, 0, 0, 0.85)
	add_child(neg_modal)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	neg_modal.add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 500)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.border_width_top = 4
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(8)
	style.shadow_size = 25
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)

	var d_name = driver.get("Nome", driver.get("nome", "Piloto"))
	var d_ovr = float(driver.get("Habilidade", driver.get("Overall", driver.get("overall", 75))))

	var asking_price = _calculate_driver_asking_price(driver)
	var expected_salary = int(snapped(asking_price, 1.0))
	var expected_years = 3 if d_ovr >= 90 else (2 if d_ovr >= 80 else 1)
	var expected_role_index = 0 if d_ovr >= 88 else 1

	var lbl_title = Label.new()
	lbl_title.text = (Database.tr_text("NEGOTIATION_TITLE") if Database.has_method("tr_text") else "PROPOSTA DE CONTRATO") + " - " + d_name
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)

	var body_grid = HBoxContainer.new()
	body_grid.add_theme_constant_override("separation", 20)

	# Coluna Esquerda: Exigências do Piloto
	var exp_card = PanelContainer.new()
	exp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var exp_style = StyleBoxFlat.new()
	exp_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	exp_style.border_width_left = 3
	exp_style.border_color = Color("#f59e0b")
	exp_style.set_corner_radius_all(6)
	exp_card.add_theme_stylebox_override("panel", exp_style)

	var exp_margin = MarginContainer.new()
	exp_margin.add_theme_constant_override("margin_left", 14)
	exp_margin.add_theme_constant_override("margin_right", 14)
	exp_margin.add_theme_constant_override("margin_top", 14)
	exp_margin.add_theme_constant_override("margin_bottom", 14)

	var exp_vbox = VBoxContainer.new()
	exp_vbox.add_theme_constant_override("separation", 12)

	var lbl_exp_title = Label.new()
	lbl_exp_title.text = Database.tr_text("EXPECTATIONS_TITLE") if Database.has_method("tr_text") else "📋 EXIGÊNCIAS DO PILOTO"
	lbl_exp_title.add_theme_font_size_override("font_size", 13)
	lbl_exp_title.add_theme_color_override("font_color", Color("#fbbf24"))
	exp_vbox.add_child(lbl_exp_title)

	var txt_role_name = (Database.tr_text("ROLE_FIRST_DRIVER") if expected_role_index == 0 else Database.tr_text("ROLE_SECOND_DRIVER"))

	exp_vbox.add_child(_create_detail_label(Database.tr_text("EXPECTED_SALARY") if Database.has_method("tr_text") else "Salário Desejado:", "$" + str(expected_salary) + "M / ano"))
	exp_vbox.add_child(_create_detail_label(Database.tr_text("EXPECTED_YEARS") if Database.has_method("tr_text") else "Contrato Desejado:", str(expected_years) + " ano(s)"))
	exp_vbox.add_child(_create_detail_label(Database.tr_text("EXPECTED_ROLE") if Database.has_method("tr_text") else "Função Desejada:", txt_role_name))

	exp_margin.add_child(exp_vbox)
	exp_card.add_child(exp_margin)
	body_grid.add_child(exp_card)

	# Coluna Direita: Formulário da Proposta
	var form_vbox = VBoxContainer.new()
	form_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_vbox.add_theme_constant_override("separation", 10)

	var l_sal = Label.new()
	l_sal.text = Database.tr_text("FIELD_SALARY") if Database.has_method("tr_text") else "Salário Anual ($M):"
	l_sal.add_theme_font_size_override("font_size", 12)
	form_vbox.add_child(l_sal)

	var in_sal = LineEdit.new()
	in_sal.text = str(expected_salary)
	in_sal.placeholder_text = "Valor em $M"
	form_vbox.add_child(in_sal)

	var l_years = Label.new()
	l_years.text = Database.tr_text("FIELD_CONTRACT_YEARS") if Database.has_method("tr_text") else "Duração do Contrato:"
	l_years.add_theme_font_size_override("font_size", 12)
	form_vbox.add_child(l_years)

	var opt_years = OptionButton.new()
	opt_years.add_item("1 Ano", 1)
	opt_years.add_item("2 Anos", 2)
	opt_years.add_item("3 Anos", 3)
	opt_years.select(expected_years - 1)
	form_vbox.add_child(opt_years)

	var l_role = Label.new()
	l_role.text = Database.tr_text("FIELD_DRIVER_ROLE") if Database.has_method("tr_text") else "Função na Equipe:"
	l_role.add_theme_font_size_override("font_size", 12)
	form_vbox.add_child(l_role)

	var opt_role = OptionButton.new()
	opt_role.add_item(Database.tr_text("ROLE_FIRST_DRIVER") if Database.has_method("tr_text") else "1º Piloto", 0)
	opt_role.add_item(Database.tr_text("ROLE_SECOND_DRIVER") if Database.has_method("tr_text") else "2º Piloto", 1)
	opt_role.select(expected_role_index)
	form_vbox.add_child(opt_role)

	body_grid.add_child(form_vbox)
	vbox.add_child(body_grid)

	# Container de Feedback e Progresso
	var status_container = VBoxContainer.new()
	status_container.custom_minimum_size.y = 30

	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 10)
	progress_bar.show_percentage = false
	progress_bar.visible = false

	var lbl_status = Label.new()
	lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_status.add_theme_font_size_override("font_size", 12)

	status_container.add_child(progress_bar)
	status_container.add_child(lbl_status)
	vbox.add_child(status_container)

	# Botões Inferiores
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)

	var btn_send = Button.new()
	btn_send.text = Database.tr_text("BTN_SEND_PROPOSAL") if Database.has_method("tr_text") else "ENVIAR PROPOSTA"
	btn_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_send.custom_minimum_size.y = 40

	var btn_cancel = Button.new()
	btn_cancel.text = Database.tr_text("BTN_BACK") if Database.has_method("tr_text") else "VOLTAR"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.custom_minimum_size.y = 40

	btn_cancel.pressed.connect(func():
		if is_instance_valid(neg_modal):
			neg_modal.queue_free()
		if is_instance_valid(parent_card):
			_show_driver_recruitment_menu(parent_card, team_name, remaining_budget)
	)

	btn_send.pressed.connect(func():
		var current_attempts = driver_negotiation_attempts.get(d_name, 0)
		if current_attempts >= 3:
			lbl_status.text = Database.tr_text("NEGOTIATION_FAIL_MAX_ATTEMPTS") if Database.has_method("tr_text") else "🔒 Limite de 3 ofertas atingido para este piloto."
			lbl_status.add_theme_color_override("font_color", Color("#ef4444"))
			return

		btn_send.disabled = true
		btn_cancel.disabled = true
		progress_bar.visible = true
		progress_bar.value = 0
		lbl_status.text = Database.tr_text("NEGOTIATING_STATUS") if Database.has_method("tr_text") else "Analisando proposta..."
		lbl_status.add_theme_color_override("font_color", Color("#cbd5e1"))

		var tween = create_tween()
		tween.tween_property(progress_bar, "value", 100.0, 1.0)
		tween.finished.connect(func():
			if not is_instance_valid(card): return
			progress_bar.visible = false
			var offered_salary = float(in_sal.text.replace(",", "."))
			var offered_role = opt_role.selected

			# Margem Escondida de Aceitação (5% a 15%)
			var hidden_discount_percent = 0.05 + (float(abs(hash(d_name)) % 11) / 100.0)
			var minimum_acceptable_salary = expected_salary * (1.0 - hidden_discount_percent)

			if offered_salary < minimum_acceptable_salary:
				driver_negotiation_attempts[d_name] = current_attempts + 1
				var attempts_left = 3 - driver_negotiation_attempts[d_name]

				if attempts_left > 0:
					lbl_status.text = "❌ Proposta Recusada! Salário muito baixo. (Tentativas restantes: %d/3)" % attempts_left
				else:
					lbl_status.text = Database.tr_text("NEGOTIATION_FAIL_MAX_ATTEMPTS") if Database.has_method("tr_text") else "🔒 Limite de 3 ofertas atingido! Negociação encerrada."

				lbl_status.add_theme_color_override("font_color", Color("#ef4444"))
				btn_send.disabled = (attempts_left <= 0)
				btn_cancel.disabled = false

			elif offered_role > expected_role_index:
				driver_negotiation_attempts[d_name] = current_attempts + 1
				var attempts_left = 3 - driver_negotiation_attempts[d_name]

				lbl_status.text = "❌ Proposta Recusada! A função oferecida não agrada ao piloto. (Restantes: %d/3)" % attempts_left
				lbl_status.add_theme_color_override("font_color", Color("#ef4444"))
				btn_send.disabled = (attempts_left <= 0)
				btn_cancel.disabled = false

			else:
				# Sucesso
				lbl_status.text = Database.tr_text("NEGOTIATION_SUCCESS") if Database.has_method("tr_text") else "✅ Proposta Aceita! O piloto assinou o contrato."
				lbl_status.add_theme_color_override("font_color", Color("#10b981"))

				var hired_driver_data = driver.duplicate()
				hired_driver_data["signed_salary"] = int(snapped(offered_salary, 1.0))
				manager_selected_drivers.append(hired_driver_data)
				var new_budget = remaining_budget - int(snapped(offered_salary, 1.0))

				# Timer para fechar a janela de sobreposição e atualizar a tela do fundo
				var timer = get_tree().create_timer(0.6)
				timer.timeout.connect(func():
					if is_instance_valid(neg_modal):
						neg_modal.queue_free()
					if is_instance_valid(parent_card):
						_show_driver_recruitment_menu(parent_card, team_name, new_budget)
				)
		)
	)

	btn_hbox.add_child(btn_send)
	btn_hbox.add_child(btn_cancel)
	vbox.add_child(btn_hbox)

	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

func _create_detail_label(title: String, val: String) -> VBoxContainer:
	var vb = VBoxContainer.new()
	var l_t = Label.new()
	l_t.text = title
	l_t.add_theme_font_size_override("font_size", 11)
	l_t.add_theme_color_override("font_color", Color("#94a3b8"))
	
	var l_v = Label.new()
	l_v.text = val
	l_v.add_theme_font_size_override("font_size", 13)
	l_v.add_theme_color_override("font_color", Color("#ffffff"))

	vb.add_child(l_t)
	vb.add_child(l_v)
	return vb

# Calcula o valor de contratação entre 3.0M e 42.0M com base em OVR, Idade e ruído aleatório
func _calculate_driver_asking_price(driver: Dictionary) -> float:
	var ovr = float(driver.get("Habilidade", driver.get("Overall", driver.get("overall", 75))))
	var age = int(driver.get("Idade", driver.get("idade", 22)))

	# 1. Normalização do OVR (Escala de 60 a 99) -> Peso ~80%
	var ovr_factor = clamp((ovr - 60.0) / 39.0, 0.0, 1.0)
	
	# 2. Fator de Idade (Pico de valor entre 24 e 29 anos) -> Peso ~20%
	var age_factor: float = 0.5
	if age <= 23:
		age_factor = 0.75 # Jovem com alto potencial
	elif age <= 29:
		age_factor = 1.00 # Auge da carreira
	elif age <= 34:
		age_factor = 0.70 # Experiente
	else:
		age_factor = 0.40 # Veterano em declínio

	# 3. Média ponderada base (3M a 40M)
	var base_price = 3.0 + (ovr_factor * 29.0 * age_factor) + (ovr_factor * 8.0)
	
	# 4. Variação aleatória determinística entre 0.3M e 1.9M usando o hash do nome
	var d_name = str(driver.get("Nome", "Piloto"))
	var noise = 0.3 + (abs(hash(d_name)) % 17) * 0.1 # Gera valor fixo único por piloto entre 0.3 e 1.9

	var final_price = clamp(base_price + noise, 3.0, 42.0)
	return snapped(final_price, 0.1)

func reset_driver_negotiation_attempts() -> void:
	driver_negotiation_attempts.clear()

func _show_alert_modal(title: String, message: String) -> void:
	# Cria um modal independente por cima da tela atual
	var alert_modal = ColorRect.new()
	alert_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	alert_modal.color = Color(0, 0, 0, 0.8)
	add_child(alert_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	alert_modal.add_child(center)
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 200)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.border_width_top = 3
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(6)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var lbl_msg = Label.new()
	lbl_msg.text = message
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 13)
	lbl_msg.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_msg)
	
	var btn_ok = Button.new()
	btn_ok.text = Database.tr_text("BTN_UNDERSTOOD") if Database.has_method("tr_text") else "ENTENDIDO"
	btn_ok.custom_minimum_size.y = 38
	btn_ok.add_theme_font_size_override("font_size", 12)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.22, 0.30, 1.0)
	btn_style.set_corner_radius_all(4)
	btn_ok.add_theme_stylebox_override("normal", btn_style)
	
	# Ao fechar, apaga apenas este popup, mantendo a tabela de pilotos intacta
	btn_ok.pressed.connect(func():
		if is_instance_valid(alert_modal):
			alert_modal.queue_free()
	)
	
	vbox.add_child(btn_ok)
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)
