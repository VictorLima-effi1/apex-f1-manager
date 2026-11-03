extends Control

var content_container: PanelContainer
var current_view_node: Node = null
var nav_buttons: Dictionary = {}
var esc_modal: Control = null

var views = {
	"dashboard": preload("res://views/dashboard_view.gd"),
	"race": preload("res://views/race_view.gd"),
	"dev": preload("res://views/dev_view.gd"),
	"market": preload("res://views/market_view.gd"),
	"editor": preload("res://views/editor_view.gd"),
	"history": preload("res://views/history_view.gd")
}

# Configura o tipo de jogo selecionado na tela inicial
func start_game_mode(selected_mode: String) -> void:
	Database.game_mode = selected_mode
	
	if selected_mode == "observer":
		# No Modo Observador, limpa a equipe criada pelo jogador para manter apenas as 11 equipes oficiais
		Database.user_team = {}
		
		# Filtra a lista de equipes para remover a 12ª equipe
		var clean_teams: Array = []
		for t in Database.teams:
			if not t.get("is_custom", false) and str(t.get("Nome", "")) != "Apex Grand Prix":
				clean_teams.append(t)
		Database.teams = clean_teams
	else:
		# No Modo Manager, inicializa a 12ª equipe do jogador caso não exista
		if Database.user_team.is_empty():
			Database._create_default_user_team()
			
	# Carrega o Dashboard da temporada
	switch_view("dashboard")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#0c0d0e")
	add_theme_stylebox_override("panel", bg_style)
	
	setup_layout()
	
	var start_view = Database.current_view if Database.current_view != "" else "dashboard"
	switch_view(start_view)
	
	if Database.has_signal("language_changed"):
		Database.language_changed.connect(setup_layout)
	
	Database.language_changed.connect(_on_language_changed)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup_layout()
	switch_view("dashboard")

func _on_language_changed() -> void:
	# Reconstruir ou atualizar os textos da barra lateral
	for item in nav_buttons.keys():
		var btn = nav_buttons[item]
		match item:
			"dashboard": btn.text = "  " + Database.tr_text("NAV_DASHBOARD")
			"race": btn.text = "  " + Database.tr_text("NAV_RACE")
			"dev": btn.text = "  " + Database.tr_text("NAV_DEV")
			"market": btn.text = "  " + Database.tr_text("NAV_MARKET")
			"editor": btn.text = "  " + Database.tr_text("NAV_EDITOR")
			"history": btn.text = "  " + Database.tr_text("NAV_HISTORY")

func setup_layout() -> void:
	# Limpa filhos anteriores da sidebar ao trocar o idioma
	for c in get_children():
		c.queue_free()

	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)
	
	var sidebar = PanelContainer.new()
	sidebar.custom_minimum_size.x = 240
	var sidebar_style = StyleBoxFlat.new()
	sidebar_style.bg_color = Color("#121417")
	sidebar_style.border_width_right = 2
	sidebar_style.border_color = Color("#ef4444")
	sidebar.add_theme_stylebox_override("panel", sidebar_style)
	main_hbox.add_child(sidebar)
	
	var sidebar_vbox = VBoxContainer.new()
	sidebar_vbox.add_theme_constant_override("separation", 10)
	sidebar.add_child(sidebar_vbox)
	
	# --- LOGO DO JOGO NO LUGAR DO TEXTO ---
	var logo_texture = TextureRect.new()
	logo_texture.texture = load("res://icon.png") 
	logo_texture.expand_mode = TextureRect.EXPAND_KEEP_SIZE 
	logo_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_texture.custom_minimum_size = Vector2(160, 60)
	sidebar_vbox.add_child(logo_texture)
	
	var nav_items = [
		{"label": Database.tr_text("NAV_DASHBOARD"), "view": "dashboard"},
		{"label": Database.tr_text("NAV_RACE"), "view": "race"},
		{"label": Database.tr_text("NAV_DEV"), "view": "dev"},
		{"label": Database.tr_text("NAV_MARKET"), "view": "market"},
		{"label": Database.tr_text("NAV_EDITOR"), "view": "editor"},
		{"label": Database.tr_text("NAV_HISTORY"), "view": "history"}
	]
	
	for item in nav_items:
		var btn = Button.new()
		btn.text = "  " + item["label"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 40
		btn.add_theme_color_override("font_color", Color("#e2e8f0"))
		btn.add_theme_color_override("font_hover_color", Color("#ffffff"))
		btn.add_theme_font_size_override("font_size", 14)
		
		var view_target = item["view"]
		nav_buttons[view_target] = btn
		btn.pressed.connect(func(): switch_view(view_target))
		sidebar_vbox.add_child(btn)
	
	sidebar_vbox.add_child(HSeparator.new())

	# Botão Salvar Jogo
	var btn_save = Button.new()
	btn_save.text = "  💾 Salvar Jogo"
	btn_save.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_save.custom_minimum_size.y = 40
	btn_save.flat = true
	btn_save.add_theme_color_override("font_color", Color("#22c55e"))
	btn_save.add_theme_font_size_override("font_size", 14)
	btn_save.pressed.connect(_on_save_game_pressed)
	sidebar_vbox.add_child(btn_save)

	var btn_menu = Button.new()
	btn_menu.text = "  🚪 Menu Inicial"
	btn_menu.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_menu.custom_minimum_size.y = 40
	btn_menu.flat = true
	btn_menu.add_theme_color_override("font_color", Color("#f59e0b"))
	btn_menu.add_theme_font_size_override("font_size", 14)
	btn_menu.pressed.connect(func():
		_show_esc_pause_modal()
	)
	sidebar_vbox.add_child(btn_menu)
		
	content_container = PanelContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var margin_container = MarginContainer.new()
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_top", 15)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_bottom", 15)
	
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color("#0c0d0e")
	content_container.add_theme_stylebox_override("panel", content_style)
	
	content_container.add_child(margin_container)
	main_hbox.add_child(content_container)

# Função auxiliar para garantir que o nome da equipe nunca retorne vazio
func _get_safe_team_name(team_dict: Dictionary) -> String:
	if team_dict.has("nome") and str(team_dict["nome"]).strip_edges() != "":
		return str(team_dict["nome"])
	elif team_dict.has("Nome") and str(team_dict["Nome"]).strip_edges() != "":
		return str(team_dict["Nome"])
	return "Equipe"

func update_sidebar_active_tab(active_view: String) -> void:
	var style_active = StyleBoxFlat.new()
	style_active.bg_color = Color("#000000")
	style_active.border_color = Color("#ef4444")
	style_active.border_width_left = 4
	style_active.border_width_top = 0
	style_active.border_width_right = 0
	style_active.border_width_bottom = 0
	style_active.set_corner_radius_all(4)

	var style_inactive = StyleBoxFlat.new()
	style_inactive.bg_color = Color(0, 0, 0, 0)

	for view_name in nav_buttons.keys():
		var btn: Button = nav_buttons[view_name]
		if view_name == active_view:
			btn.add_theme_stylebox_override("normal", style_active)
			btn.add_theme_stylebox_override("hover", style_active)
			btn.add_theme_stylebox_override("pressed", style_active)
			btn.add_theme_stylebox_override("focus", style_active)
			btn.add_theme_color_override("font_color", Color("#ffffff"))
		else:
			btn.add_theme_stylebox_override("normal", style_inactive)
			btn.add_theme_stylebox_override("hover", style_inactive)
			btn.add_theme_stylebox_override("pressed", style_inactive)
			btn.add_theme_stylebox_override("focus", style_inactive)
			btn.add_theme_color_override("font_color", Color("#94a3b8"))

func switch_view(view_name: String) -> void:
	Database.current_view = view_name
	
	update_sidebar_active_tab(view_name)
	
	var margin_node = content_container.get_child(0)
	if current_view_node:
		current_view_node.queue_free()
		
	if views.has(view_name):
		current_view_node = views[view_name].new()
		if current_view_node.has_signal("request_advance_gp"):
			current_view_node.request_advance_gp.connect(_advance_gp)
		margin_node.add_child(current_view_node)
		# #region agent log
		if view_name == "race":
			var path := "C:/Users/Limad/Desktop/Apex/apex-f1-manager/debug-2b010b.log"
			var fa := FileAccess.open(path, FileAccess.READ_WRITE)
			if fa == null:
				fa = FileAccess.open(path, FileAccess.WRITE)
			else:
				fa.seek_end()
			if fa != null:
				fa.store_line(JSON.stringify({
					"sessionId": "2b010b",
					"timestamp": int(Time.get_unix_time_from_system() * 1000.0),
					"location": "main.gd:switch_view",
					"message": "Race view added to tree",
					"data": {
						"parent": str(margin_node.get_path()),
						"view_class": current_view_node.get_class(),
						"size": {"x": current_view_node.size.x, "y": current_view_node.size.y} if current_view_node is Control else {"x": -1, "y": -1}
					},
					"hypothesisId": "D",
					"runId": "pre-fix"
				}))
				fa.close()
		# #endregion

func _advance_gp() -> void:
	Database.process_ai_team_upgrades()
	if Database.current_gp >= Database.tracks.size():
		Database.end_season_and_advance_year()
	else:
		Database.current_gp += 1
		
	Database.race_finished = false
	Database.active_engine = null
	switch_view("dashboard")

func _on_save_game_pressed() -> void:
	var modal = SaveSlotModal.new()
	modal.open_modal(self, SaveSlotModal.Mode.SAVE, func():
		_show_bottom_popup("💾 Jogo salvo com sucesso!")
	)

func _show_bottom_popup(msg: String) -> void:
	var old_popup = get_node_or_null("SaveToastPopup")
	if old_popup:
		old_popup.queue_free()
		
	var popup = PanelContainer.new()
	popup.name = "SaveToastPopup"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	style.border_width_left = 4
	style.border_color = Color("#22c55e")
	style.set_corner_radius_all(6)
	style.shadow_size = 14
	style.shadow_color = Color(0, 0, 0, 0.5)
	popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#f8fafc"))
	margin.add_child(lbl)
	popup.add_child(margin)
	
	add_child(popup)
	
	var vp_size = get_viewport_rect().size
	var popup_size = popup.get_combined_minimum_size()
	var target_x = vp_size.x - popup_size.x - 24
	var target_y = vp_size.y - popup_size.y - 24
	var start_x = vp_size.x + 30
	
	popup.position = Vector2(start_x, target_y)
	popup.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:x", target_x, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.25)
	
	var sequence = create_tween()
	sequence.tween_interval(5.0)
	sequence.tween_property(popup, "modulate:a", 0.0, 0.4)
	sequence.tween_callback(popup.queue_free)

# --- CAPTURA E MODAL DE TECLA ESC ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(esc_modal):
			_close_esc_modal()
		else:
			_show_esc_pause_modal()

func _show_esc_pause_modal() -> void:
	_close_esc_modal()

	esc_modal = ColorRect.new()
	esc_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc_modal.color = Color(0, 0, 0, 0.8)
	add_child(esc_modal)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc_modal.add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 210)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.border_width_top = 3
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)

	var lbl_title = Label.new()
	lbl_title.text = "PAUSA / MENU"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 16)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)

	var lbl_msg = Label.new()
	lbl_msg.text = "O que deseja fazer?"
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.add_theme_font_size_override("font_size", 13)
	lbl_msg.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_msg)

	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)

	var btn_hbox_actions = HBoxContainer.new()
	btn_hbox_actions.add_theme_constant_override("separation", 12)

	# Botão 1: Voltar ao Menu
	var btn_menu = Button.new()
	btn_menu.text = "🏠 Voltar ao Menu"
	btn_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_menu.custom_minimum_size.y = 38
	btn_menu.add_theme_font_size_override("font_size", 12)

	var style_menu = StyleBoxFlat.new()
	style_menu.bg_color = Color(0.8, 0.15, 0.15, 1.0)
	style_menu.set_corner_radius_all(4)
	btn_menu.add_theme_stylebox_override("normal", style_menu)

	btn_menu.pressed.connect(func():
		_close_esc_modal()
		Database.current_view = "main_menu"
		get_tree().change_scene_to_file("res://views/main_menu_view.tscn")
	)

	# Botão 2: Ver Opções
	var btn_options = Button.new()
	btn_options.text = "⚙️ Ver Opções"
	btn_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_options.custom_minimum_size.y = 38
	btn_options.add_theme_font_size_override("font_size", 12)

	var style_options = StyleBoxFlat.new()
	style_options.bg_color = Color(0.18, 0.22, 0.30, 1.0)
	style_options.set_corner_radius_all(4)
	btn_options.add_theme_stylebox_override("normal", style_options)

	btn_options.pressed.connect(func():
		_close_esc_modal()
		var options_script = preload("res://views/options_view.gd")
		var options_node = options_script.new()
		add_child(options_node)
	)

	btn_hbox_actions.add_child(btn_menu)
	btn_hbox_actions.add_child(btn_options)
	btn_vbox.add_child(btn_hbox_actions)

	# Botão 3: Continuar Jogando
	var btn_cancel = Button.new()
	btn_cancel.text = "▶ Continuar Jogando"
	btn_cancel.custom_minimum_size.y = 32
	btn_cancel.add_theme_font_size_override("font_size", 11)

	var style_cancel = StyleBoxFlat.new()
	style_cancel.bg_color = Color(0.12, 0.15, 0.22, 0.8)
	style_cancel.set_corner_radius_all(4)
	btn_cancel.add_theme_stylebox_override("normal", style_cancel)

	btn_cancel.pressed.connect(_close_esc_modal)
	btn_vbox.add_child(btn_cancel)

	vbox.add_child(btn_vbox)
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

func _close_esc_modal() -> void:
	if is_instance_valid(esc_modal):
		esc_modal.queue_free()
		esc_modal = null
