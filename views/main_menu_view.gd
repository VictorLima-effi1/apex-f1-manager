extends Control

var time_passed: float = 0.0
var title_node: Label
var subtitle_node: Label
var button_container: VBoxContainer
var active_modal: Control = null

# Variaveis para controle dos submenus do Modo Manager
var input_team_name: LineEdit = null
var input_boss_name: LineEdit = null
var input_country: LineEdit = null
var color_picker: ColorPickerButton = null
var team_option_button: OptionButton = null
var team_info_container: VBoxContainer = null

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
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
	subtitle_node.text = "SEASON MANAGEMENT SIMULATOR"
	subtitle_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_node.add_theme_font_size_override("font_size", 10)
	subtitle_node.add_theme_color_override("font_color", Color("#64748b"))
	header_vbox.add_child(subtitle_node)
	
	main_vbox.add_child(header_vbox)
	
	button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	
	_create_styled_button("🚀  NOVO JOGO", _on_btn_new_game_pressed)
	_create_styled_button("📂  CARREGAR JOGO", _on_load_game)
	_create_styled_button("⚙️  OPÇÕES", _on_options)
	_create_styled_button("❌  SAIR DO JOGO", _on_exit)
	
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

func _create_styled_button(text: String, callable: Callable) -> void:
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
	
	var lbl_title = Label.new()
	lbl_title.text = "ESCOLHA O MODO DE JOGO"
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
	
	var lbl_desc = Label.new()
	lbl_desc.text = "Passe o mouse sobre um modo de jogo para ver os detalhes."
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.add_theme_font_size_override("font_size", 13)
	lbl_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	desc_margin.add_child(lbl_desc)
	desc_card.add_child(desc_margin)
	
	var txt_obs = "Observador: Para quem quer deixar a simulação seguir de forma independente, podendo alterar apenas dados de nomes, idades e atributos de pilotos e equipes, e acompanhar o desenvolvimento automático das equipes."
	var txt_man = "Manager: Permite escolher/criar uma equipe, administrar pilotos, gastos, patrocinadores, estratégias pré-corrida, e levar a sua equipe ao auge da categoria."
	var txt_default = "Passe o mouse sobre um modo de jogo para ver os detalhes."

	var btn_obs = Button.new()
	btn_obs.text = "MODO OBSERVADOR"
	btn_obs.custom_minimum_size.y = 52
	btn_obs.add_theme_font_size_override("font_size", 15)
	
	var style_obs = StyleBoxFlat.new()
	style_obs.bg_color = Color(0.12, 0.16, 0.24, 1.0)
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
	
	var btn_man = Button.new()
	btn_man.text = "MODO MANAGER"
	btn_man.custom_minimum_size.y = 52
	btn_man.add_theme_font_size_override("font_size", 15)
	
	var style_man = StyleBoxFlat.new()
	style_man.bg_color = Color(0.12, 0.16, 0.24, 1.0)
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
	
	var btn_cancel = Button.new()
	btn_cancel.text = "VOLTAR"
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

	var lbl_title = Label.new()
	lbl_title.text = "OPÇÕES DO MODO MANAGER"
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
	l_c_title.text = "🛠️ CRIAR NOVA EQUIPE"
	l_c_title.add_theme_font_size_override("font_size", 16)
	l_c_title.add_theme_color_override("font_color", Color("#ffffff"))
	vb_c.add_child(l_c_title)
	
	var l_c_desc = Label.new()
	l_c_desc.text = "Fundação total da sua escuderia: defina o nome, cores oficiais, chefe de equipe e país de origem."
	l_c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_c_desc.add_theme_font_size_override("font_size", 12)
	l_c_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	l_c_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb_c.add_child(l_c_desc)
	
	var btn_create = Button.new()
	btn_create.text = "CRIAR EQUIPE"
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
	l_e_title.text = "🏁 EQUIPE EXISTENTE"
	l_e_title.add_theme_font_size_override("font_size", 16)
	l_e_title.add_theme_color_override("font_color", Color("#ffffff"))
	vb_e.add_child(l_e_title)
	
	var l_e_desc = Label.new()
	l_e_desc.text = "Assuma o comando de uma das equipes oficiais do campeonato e gerencie seus pilotos e orçamentos."
	l_e_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l_e_desc.add_theme_font_size_override("font_size", 12)
	l_e_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	l_e_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb_e.add_child(l_e_desc)
	
	var btn_existing = Button.new()
	btn_existing.text = "ESCOLHER EXISTENTE"
	btn_existing.custom_minimum_size.y = 44
	btn_existing.pressed.connect(func(): _show_select_existing_team_form(parent_card))
	vb_e.add_child(btn_existing)
	
	m_e.add_child(vb_e)
	card_exist.add_child(m_e)
	grid_opts.add_child(card_exist)

	vbox.add_child(grid_opts)

	var btn_back = Button.new()
	btn_back.text = "VOLTAR"
	btn_back.custom_minimum_size.y = 42
	btn_back.add_theme_font_size_override("font_size", 13)
	btn_back.pressed.connect(func(): _show_mode_selection_modal())
	vbox.add_child(btn_back)

	margin.add_child(vbox)
	parent_card.add_child(margin)

# --- FORMULÁRIO: CRIAR EQUIPE ---
func _show_create_team_form(parent_card: PanelContainer) -> void:
	parent_card.custom_minimum_size = Vector2(850, 560)
	for c in parent_card.get_children():
		c.queue_free()

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_right", 35)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)

	var lbl_title = Label.new()
	lbl_title.text = "CRIAR SUA EQUIPE"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 15)

	var box1 = VBoxContainer.new()
	box1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l1 = Label.new()
	l1.text = "Nome da Equipe:"
	l1.add_theme_font_size_override("font_size", 13)
	l1.add_theme_color_override("font_color", Color("#cbd5e1"))
	box1.add_child(l1)
	input_team_name = LineEdit.new()
	input_team_name.placeholder_text = "Ex: Apex Grand Prix"
	input_team_name.custom_minimum_size.y = 40
	box1.add_child(input_team_name)
	grid.add_child(box1)

	var box2 = VBoxContainer.new()
	box2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l2 = Label.new()
	l2.text = "Nome do Chefe de Equipe:"
	l2.add_theme_font_size_override("font_size", 13)
	l2.add_theme_color_override("font_color", Color("#cbd5e1"))
	box2.add_child(l2)
	input_boss_name = LineEdit.new()
	input_boss_name.placeholder_text = "Ex: Seu Nome"
	input_boss_name.custom_minimum_size.y = 40
	box2.add_child(input_boss_name)
	grid.add_child(box2)

	var box3 = VBoxContainer.new()
	box3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l3 = Label.new()
	l3.text = "País Sede:"
	l3.add_theme_font_size_override("font_size", 13)
	l3.add_theme_color_override("font_color", Color("#cbd5e1"))
	box3.add_child(l3)
	input_country = LineEdit.new()
	input_country.placeholder_text = "Ex: Brasil"
	input_country.custom_minimum_size.y = 40
	box3.add_child(input_country)
	grid.add_child(box3)

	var box4 = VBoxContainer.new()
	box4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l4 = Label.new()
	l4.text = "Cor Principal da Equipe:"
	l4.add_theme_font_size_override("font_size", 13)
	l4.add_theme_color_override("font_color", Color("#cbd5e1"))
	box4.add_child(l4)
	
	color_picker = ColorPickerButton.new()
	color_picker.color = Color("#ef4444")
	color_picker.custom_minimum_size = Vector2(0, 40)
	box4.add_child(color_picker)
	grid.add_child(box4)

	vbox.add_child(grid)

	var preview_card = PanelContainer.new()
	var p_st = StyleBoxFlat.new()
	p_st.bg_color = Color(0.06, 0.08, 0.12, 0.8)
	p_st.set_corner_radius_all(6)
	preview_card.add_theme_stylebox_override("panel", p_st)
	var p_margin = MarginContainer.new()
	p_margin.add_theme_constant_override("margin_left", 15)
	p_margin.add_theme_constant_override("margin_right", 15)
	p_margin.add_theme_constant_override("margin_top", 15)
	p_margin.add_theme_constant_override("margin_bottom", 15)
	
	var p_lbl = Label.new()
	p_lbl.text = "💡 Após criar sua equipe, você iniciará com os parâmetros padrão da categoria e um orçamento inicial básico para desenvolvimento."
	p_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_lbl.add_theme_font_size_override("font_size", 12)
	p_lbl.add_theme_color_override("font_color", Color("#64748b"))
	p_margin.add_child(p_lbl)
	preview_card.add_child(p_margin)
	vbox.add_child(preview_card)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)

	var btn_confirm = Button.new()
	btn_confirm.text = "CONFIRMAR CRIAÇÃO"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 44
	btn_confirm.pressed.connect(func():
		_show_custom_modal("MODO MANAGER", "Modo em desenvolvimento")
	)
	btn_hbox.add_child(btn_confirm)

	var btn_back = Button.new()
	btn_back.text = "VOLTAR"
	btn_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_back.custom_minimum_size.y = 44
	btn_back.pressed.connect(func(): _show_manager_options_menu(parent_card))
	btn_hbox.add_child(btn_back)

	vbox.add_child(btn_hbox)

	margin.add_child(vbox)
	parent_card.add_child(margin)

# --- VISUALIZADOR COM OPTIONBUTTON CUSTOMIZADO ---
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

	var lbl_title = Label.new()
	lbl_title.text = "SELEÇÃO DE EQUIPE EXISTENTE"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)

	# Seletor com Estilização Customizada
	var sel_hbox = HBoxContainer.new()
	var l_sel = Label.new()
	l_sel.text = "Escolha a Equipe: "
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

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)

	var btn_confirm = Button.new()
	btn_confirm.text = "SELECIONAR ESTA EQUIPE"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 44
	btn_confirm.pressed.connect(func():
		_show_custom_modal("MODO MANAGER", "Modo em desenvolvimento")
	)
	btn_hbox.add_child(btn_confirm)

	var btn_back = Button.new()
	btn_back.text = "VOLTAR"
	btn_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_back.custom_minimum_size.y = 44
	btn_back.pressed.connect(func(): _show_manager_options_menu(parent_card))
	btn_hbox.add_child(btn_back)

	vbox.add_child(btn_hbox)

	margin.add_child(vbox)
	parent_card.add_child(margin)

# Função para estilizar o OptionButton e seu Menu Popup (Corrigida para Godot 4)
func _apply_custom_option_button_styles(opt_btn: OptionButton) -> void:
	var st_norm = StyleBoxFlat.new()
	st_norm.bg_color = Color(0.09, 0.12, 0.18, 1.0)
	st_norm.set_border_width_all(1) # CORRIGIDO: usa a função set_border_width_all
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
	popup_style.set_border_width_all(1) # CORRIGIDO: usa a função set_border_width_all
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
	lbl_car_title.text = "🏎️ DESEMPENHO DO CARRO"
	lbl_car_title.add_theme_font_size_override("font_size", 14)
	lbl_car_title.add_theme_color_override("font_color", Color("#60a5fa"))
	vb_car.add_child(lbl_car_title)

	var motor_val = team.get("Motor", team.get("motor", 0))
	var aero_val = team.get("Aero", team.get("aero", 0))
	var chassi_val = team.get("Chassi", team.get("chassi", 0))
	var conf_val = team.get("Confiabilidade", team.get("confiabilidade", 0))

	vb_car.add_child(_create_attribute_bar("Motor:", motor_val))
	vb_car.add_child(_create_attribute_bar("Aerodinâmica:", aero_val))
	vb_car.add_child(_create_attribute_bar("Chassi:", chassi_val))
	vb_car.add_child(_create_attribute_bar("Confiabilidade:", conf_val, "%"))

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
	lbl_b_title.text = "💰 ORÇAMENTO DISPONÍVEL"
	lbl_b_title.add_theme_font_size_override("font_size", 12)
	lbl_b_title.add_theme_color_override("font_color", Color("#34d399"))
	vb_b.add_child(lbl_b_title)

	var budget = team.get("Orcamento", team.get("orcamento", team.get("Budget", 0)))
	var lbl_b_val = Label.new()
	lbl_b_val.text = "$" + str(budget) + " Milhões"
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
	lbl_d_title.text = "👤 PILOTOS TITULARES"
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
		l_empty.text = "Nenhum piloto vinculado a esta equipe."
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
	lbl_title.text = "SAIR DO JOGO"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var lbl_msg = Label.new()
	lbl_msg.text = "Tem certeza de que deseja sair do Apex F1 Manager?"
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 13)
	lbl_msg.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_msg)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	
	var btn_confirm = Button.new()
	btn_confirm.text = "Sim, Sair"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 38
	btn_confirm.add_theme_font_size_override("font_size", 12)
	
	var style_confirm = StyleBoxFlat.new()
	style_confirm.bg_color = Color(0.8, 0.15, 0.15, 1.0)
	style_confirm.set_corner_radius_all(4)
	btn_confirm.add_theme_stylebox_override("normal", style_confirm)
	btn_confirm.pressed.connect(func(): get_tree().quit())
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Não, Cancelar"
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

# Modal Genérico
func _show_custom_modal(title_text: String, message_text: String) -> void:
	if is_instance_valid(active_modal):
		active_modal.queue_free()
		
	active_modal = ColorRect.new()
	active_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_modal.color = Color(0, 0, 0, 0.75)
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
	lbl_title.text = title_text
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var lbl_msg = Label.new()
	lbl_msg.text = message_text
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 13)
	lbl_msg.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_msg)
	
	var btn_close = Button.new()
	btn_close.text = "ENTENDIDO"
	btn_close.custom_minimum_size.y = 38
	btn_close.add_theme_font_size_override("font_size", 12)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.22, 0.30, 1.0)
	btn_style.set_corner_radius_all(4)
	btn_close.add_theme_stylebox_override("normal", btn_style)
	
	btn_close.pressed.connect(func():
		if is_instance_valid(active_modal):
			active_modal.queue_free()
			active_modal = null
	)
	vbox.add_child(btn_close)
	
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			print("🤖 Gerando relatório de telemetria para a IA...")
			Database.run_automated_test_season_and_export_telemetry()
