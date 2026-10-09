extends Control

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_ui()

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	add_child(main_vbox)
	
	# Header
	var title = Label.new()
	title.text = "DESENVOLVIMENTO TÉCNICO & HIERARQUIA DE MAQUINÁRIO"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ef4444"))
	main_vbox.add_child(title)
	
	# Scroll Container para a lista de equipes
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	var teams_vbox = VBoxContainer.new()
	teams_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(teams_vbox)
	
	# Copia e ordena equipes pelo poder total do carro (Car Power)
	var sorted_teams = Database.teams.duplicate()
	sorted_teams.sort_custom(func(a, b):
		var p_a = a["Motor"] + a["Aero"] + a["Chassi"]
		var p_b = b["Motor"] + b["Aero"] + b["Chassi"]
		return p_a > p_b
	)
	
	var rank = 1
	for t in sorted_teams:
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("#121417")
		p_style.content_margin_left = 12
		p_style.content_margin_right = 12
		p_style.content_margin_top = 10
		p_style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", p_style)
		
		var main_hbox = HBoxContainer.new()
		main_hbox.add_theme_constant_override("separation", 20)
		
		# Info da Equipe + Ranking
		var team_info = VBoxContainer.new()
		team_info.custom_minimum_size.x = 210
		
		var r_lbl = Label.new()
		r_lbl.text = "RANK #" + str(rank) + " NO GRID"
		r_lbl.add_theme_font_size_override("font_size", 11)
		r_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
		team_info.add_child(r_lbl)
		
		var t_name = Label.new()
		t_name.text = t["Nome"]
		t_name.add_theme_font_size_override("font_size", 17)
		t_name.add_theme_color_override("font_color", Color("#38bdf8"))
		team_info.add_child(t_name)
		
		var car_power = int(t["Motor"] + t["Aero"] + t["Chassi"])
		var tag_info = _get_performance_tag(car_power)
		
		var tag_lbl = Label.new()
		tag_lbl.text = tag_info["text"]
		tag_lbl.add_theme_color_override("font_color", tag_info["color"])
		tag_lbl.add_theme_font_size_override("font_size", 12)
		team_info.add_child(tag_lbl)
		
		var budget_lbl = Label.new()
		budget_lbl.text = "💰 Verba P&D: $" + str(t["Orcamento"]) + "M"
		budget_lbl.add_theme_color_override("font_color", Color("#22c55e"))
		team_info.add_child(budget_lbl)
		
		main_hbox.add_child(team_info)
		main_hbox.add_child(VSeparator.new())
		
		# Grid de Componentes com Barras Compactas
		var stats_grid = GridContainer.new()
		stats_grid.columns = 2
		stats_grid.add_theme_constant_override("h_separation", 15)
		stats_grid.add_theme_constant_override("v_separation", 6)
		
		stats_grid.add_child(_create_stat_label("🚀 Motor (" + str(t["Motor"]) + "):"))
		stats_grid.add_child(_create_progress_bar(t["Motor"]))
		
		stats_grid.add_child(_create_stat_label("💨 Aero (" + str(t["Aero"]) + "):"))
		stats_grid.add_child(_create_progress_bar(t["Aero"]))
		
		stats_grid.add_child(_create_stat_label("🏎️ Chassi (" + str(t["Chassi"]) + "):"))
		stats_grid.add_child(_create_progress_bar(t["Chassi"]))
		
		stats_grid.add_child(_create_stat_label("🔧 Confiabilidade (" + str(t["Confiabilidade"]) + "%):"))
		stats_grid.add_child(_create_progress_bar(t["Confiabilidade"]))
		
		main_hbox.add_child(stats_grid)
		panel.add_child(main_hbox)
		teams_vbox.add_child(panel)
		rank += 1

func _get_performance_tag(power: int) -> Dictionary:
	if power >= 273:
		return {"text": "🔥 Dominante (Top Grid)", "color": Color("#ef4444")}
	elif power >= 262:
		return {"text": "🟢 Altamente Competitivo", "color": Color("#22c55e")}
	elif power >= 250:
		return {"text": "🟡 Pelotão Intermediário", "color": Color("#eab308")}
	else:
		return {"text": "⚪ Retaguarda / Em Busca de Ritmo", "color": Color("#94a3b8")}

func _create_stat_label(txt: String) -> Label:
	var lbl = Label.new()
	lbl.text = txt
	lbl.custom_minimum_size.x = 160
	return lbl

func _create_progress_bar(val: int) -> ProgressBar:
	var pb = ProgressBar.new()
	pb.min_value = 50
	pb.max_value = 99
	pb.value = val
	pb.size_flags_horizontal = 0 # Mantém a barra fixa sem esticar pela tela
	pb.custom_minimum_size = Vector2(140, 16) # Largura e altura elegantes
	pb.show_percentage = true
	return pb
