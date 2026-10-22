extends Control

var time_passed: float = 0.0
var title_node: Label
var subtitle_node: Label
var button_container: VBoxContainer
var active_modal: Control = null

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
	card.custom_minimum_size = Vector2(400, 420)
	
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

# --- NOVO FLUXO: ESCOLHA DE MODO DE JOGO ---

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
	card.custom_minimum_size = Vector2(580, 420)
	
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
	vbox.add_theme_constant_override("separation", 18)
	
	var lbl_title = Label.new()
	lbl_title.text = "ESCOLHA O MODO DE JOGO"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 20)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 12)
	
	# Painel de Descrição do Modo (Aparece ao passar o mouse)
	var desc_card = PanelContainer.new()
	desc_card.custom_minimum_size.y = 110
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	desc_style.border_width_left = 4
	desc_style.border_color = Color("#ef4444")
	desc_style.set_corner_radius_all(6)
	desc_card.add_theme_stylebox_override("panel", desc_style)
	
	var desc_margin = MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 16)
	desc_margin.add_theme_constant_override("margin_right", 16)
	desc_margin.add_theme_constant_override("margin_top", 12)
	desc_margin.add_theme_constant_override("margin_bottom", 12)
	
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

	# Opção 1: Observador
	var btn_obs = Button.new()
	btn_obs.text = "MODO OBSERVADOR"
	btn_obs.custom_minimum_size.y = 48
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
	
	# Opção 2: Manager
	var btn_man = Button.new()
	btn_man.text = "MODO MANAGER"
	btn_man.custom_minimum_size.y = 48
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
		_show_custom_modal("MODO MANAGER", "⚠️ EM DESENVOLVIMENTO\n\nEste modo permitirá escolher uma equipe do grid (ou criar a sua) e gerenciar todas as operações na temporada.")
	)
	btn_vbox.add_child(btn_man)
	
	vbox.add_child(btn_vbox)
	vbox.add_child(desc_card)
	
	# Botão Voltar
	var btn_cancel = Button.new()
	btn_cancel.text = "VOLTAR"
	btn_cancel.custom_minimum_size.y = 40
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

# Modal de Confirmação para Sair
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
	card.custom_minimum_size = Vector2(380, 190)
	
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
	lbl_title.add_theme_font_size_override("font_size", 16)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var lbl_msg = Label.new()
	lbl_msg.text = "Tem certeza de que deseja sair do Apex F1 Manager?"
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 12)
	lbl_msg.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_msg)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	
	var btn_confirm = Button.new()
	btn_confirm.text = "Sim, Sair"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 36
	btn_confirm.add_theme_font_size_override("font_size", 12)
	
	var style_confirm = StyleBoxFlat.new()
	style_confirm.bg_color = Color(0.8, 0.15, 0.15, 1.0)
	style_confirm.set_corner_radius_all(4)
	btn_confirm.add_theme_stylebox_override("normal", style_confirm)
	btn_confirm.pressed.connect(func(): get_tree().quit())
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Não, Cancelar"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.custom_minimum_size.y = 36
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
	card.custom_minimum_size = Vector2(360, 180)
	
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
	lbl_title.add_theme_font_size_override("font_size", 16)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var lbl_msg = Label.new()
	lbl_msg.text = message_text
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 12)
	lbl_msg.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_msg)
	
	var btn_close = Button.new()
	btn_close.text = "ENTENDIDO"
	btn_close.custom_minimum_size.y = 36
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
