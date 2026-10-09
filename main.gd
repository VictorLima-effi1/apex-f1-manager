extends Control

var content_container: PanelContainer
var current_view_node: Node = null
var nav_buttons: Dictionary = {}

var views = {
	"dashboard": preload("res://views/dashboard_view.gd"),
	"race": preload("res://views/race_view.gd"),
	"dev": preload("res://views/dev_view.gd"),
	"market": preload("res://views/market_view.gd"),
	"editor": preload("res://views/editor_view.gd"),
	"history": preload("res://views/history_view.gd")
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#0c0d0e")
	add_theme_stylebox_override("panel", bg_style)
	
	setup_layout()
	
	var start_view = Database.current_view if Database.current_view != "" else "dashboard"
	switch_view(start_view)

func setup_layout() -> void:
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
	
	var logo_label = Label.new()
	logo_label.text = "APEX F1\nMANAGER"
	logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_label.add_theme_color_override("font_color", Color("f60210ff"))
	logo_label.add_theme_font_size_override("font_size", 22)
	sidebar_vbox.add_child(logo_label)
	
	sidebar_vbox.add_child(HSeparator.new())
	
	var nav_items = [
		{"label": "📊 Dashboard", "view": "dashboard"},
		{"label": "🏎️ Corrida (Race)", "view": "race"},
		{"label": "🏭 Desenvolvimento", "view": "dev"},
		{"label": "💼 Mercado & Pilotos", "view": "market"},
		{"label": "🛠️ Editor de Dados", "view": "editor"},
		{"label": "🏆 Histórico & Hall", "view": "history"}
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

	# Botão Salvar Jogo com Pop-up no Canto Inferior
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
		Database.current_view = "main_menu"
		get_tree().change_scene_to_file("res://views/main_menu_view.tscn")
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
	
func update_sidebar_active_tab(active_view: String) -> void:
	# Estilo para a aba ATIVA (Retângulo preto puro com linha vermelha na esquerda)
	var style_active = StyleBoxFlat.new()
	style_active.bg_color = Color("#000000") # Fundo preto escuro
	style_active.border_color = Color("#ef4444") # Cor da borda
	style_active.border_width_left = 4 # Apenas a borda esquerda fica visível com espessura 4
	style_active.border_width_top = 0
	style_active.border_width_right = 0
	style_active.border_width_bottom = 0
	style_active.set_corner_radius_all(4)

	# Estilo para abas INATIVAS (Transparente)
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

func _advance_gp() -> void:
	Database.process_ai_team_upgrades()
	if Database.current_gp >= Database.tracks.size():
		Database.end_season_and_advance_year()
	else:
		Database.current_gp += 1
		
	Database.race_finished = false
	Database.active_engine = null
	switch_view("dashboard")

# Ação ao Clicar em Salvar Jogo
func _on_save_game_pressed() -> void:
	var success: bool = Database.save_game() if Database.has_method("save_game") else false
	
	if success:
		_show_bottom_popup("💾 Jogo salvo com sucesso!")
	else:
		_show_bottom_popup("❌ Erro ao salvar o jogo.")

# Pop-up Animado com Animação de Slide no Canto Inferior Direito (Duração: 5 seg)
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
	
	# Posição final (canto inferior direito)
	var vp_size = get_viewport_rect().size
	var popup_size = popup.get_combined_minimum_size()
	var target_x = vp_size.x - popup_size.x - 24
	var target_y = vp_size.y - popup_size.y - 24
	
	# Posição inicial fora da tela (direita) para criar a animação de slide
	var start_x = vp_size.x + 30
	
	popup.position = Vector2(start_x, target_y)
	popup.modulate.a = 0.0
	
	# Animação em 3 etapas:
	# 1. Slide para dentro (0.35s)
	# 2. Espera na tela (5.0s)
	# 3. Fade out suave para fora (0.4s)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:x", target_x, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.25)
	
	var sequence = create_tween()
	sequence.tween_interval(5.0)
	sequence.tween_property(popup, "modulate:a", 0.0, 0.4)
	sequence.tween_callback(popup.queue_free)
