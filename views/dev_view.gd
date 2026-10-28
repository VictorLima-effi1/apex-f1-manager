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
	main_vbox.add_theme_constant_override("separation", 16)
	add_child(main_vbox)
	
	# --- HEADER DA TELA ---
	var header_hbox = HBoxContainer.new()
	var title = Label.new()
	title.text = "DESENVOLVIMENTO TÉCNICO & HIERARQUIA DE MAQUINÁRIO"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ef4444"))
	header_hbox.add_child(title)
	main_vbox.add_child(header_hbox)
	
	# --- HUD DE MONITORAMENTO DO TETO ORÇAMENTÁRIO DO GRID ---
	_render_grid_budget_cap_summary(main_vbox)
	
	# --- SCROLLCONTAINER DA HIERARQUIA DE EQUIPES ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	# GRID CONTAINER DE 2 COLUNAS (COM MAIOR ESPAÇAMENTO VERTICAL/HORIZONTAL)
	var teams_grid = GridContainer.new()
	teams_grid.columns = 2
	teams_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teams_grid.add_theme_constant_override("h_separation", 18)
	teams_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(teams_grid)
	
	# 1. Identifica a posição das equipes no Construtores
	var teams_by_points = Database.teams.duplicate()
	teams_by_points.sort_custom(func(a, b): return int(a.get("Pontos", 0)) > int(b.get("Pontos", 0)))
	
	var team_points_rank: Dictionary = {}
	for idx in range(teams_by_points.size()):
		var t_name = str(teams_by_points[idx].get("Nome", ""))
		var stored_rank = int(teams_by_points[idx].get("LastSeasonRank", idx + 1))
		team_points_rank[t_name] = stored_rank

	# 2. Ordena equipes pelo Car Power para exibição
	var sorted_teams = Database.teams.duplicate()
	sorted_teams.sort_custom(func(a, b):
		var stats_a = Database.calculate_team_dev_stats(a) if Database.has_method("calculate_team_dev_stats") else a
		var stats_b = Database.calculate_team_dev_stats(b) if Database.has_method("calculate_team_dev_stats") else b
		var p_a = int(stats_a.get("Motor", 80)) + int(stats_a.get("Aero", 80)) + int(stats_a.get("Chassi", 80))
		var p_b = int(stats_b.get("Motor", 80)) + int(stats_b.get("Aero", 80)) + int(stats_b.get("Chassi", 80))
		return p_a > p_b
	)
	
	var rank = 1
	
	for t in sorted_teams:
		var team_name = str(t.get("Nome", ""))
		var spent = Database.team_season_expenses.get(team_name, 0.0)
		
		# CÁLCULO DINÂMICO DOS PARÂMETROS TÉCNICOS (MOTOR, AERO, CHASSI, CONFIABILIDADE)
		var stats = Database.calculate_team_dev_stats(t) if Database.has_method("calculate_team_dev_stats") else t
		var motor_val = int(stats.get("Motor", t.get("Motor", 80)))
		var aero_val = int(stats.get("Aero", t.get("Aero", 80)))
		var chassi_val = int(stats.get("Chassi", t.get("Chassi", 80)))
		var rel_val = int(stats.get("Confiabilidade", t.get("Confiabilidade", 80)))
		
		# Obtém o teto orçamentário personalizado da equipe ($135M a $155M)
		var max_cap = Database.get_team_budget_cap(team_name) if Database.has_method("get_team_budget_cap") else Database.COST_CAP_LIMIT
		var remaining = max(0.0, max_cap - spent)
		
		var spent_m = snapped(spent / 1_000_000.0, 0.1)
		var remaining_m = snapped(remaining / 1_000_000.0, 0.1)
		var max_cap_m = snapped(max_cap / 1_000_000.0, 0.1)
		
		# --- ESTILIZAÇÃO DO CARD ---
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var car_power = motor_val + aero_val + chassi_val
		var tag_info = _get_performance_tag(car_power)
		
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("#0f1216")
		p_style.border_width_left = 4
		p_style.border_color = tag_info["color"]
		p_style.set_corner_radius_all(6)
		p_style.content_margin_left = 14
		p_style.content_margin_right = 14
		p_style.content_margin_top = 12
		p_style.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", p_style)
		
		var main_hbox = HBoxContainer.new()
		main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_hbox.add_theme_constant_override("separation", 14)
		
		# --- BLOCO 1: RANKING, NOME E HANDICAP ---
		var team_info = VBoxContainer.new()
		team_info.custom_minimum_size.x = 210
		team_info.add_theme_constant_override("separation", 3)
		
		var r_lbl = Label.new()
		r_lbl.text = "RANK #" + str(rank) + " NO GRID"
		r_lbl.add_theme_font_size_override("font_size", 12)
		r_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
		team_info.add_child(r_lbl)
		
		var t_name = Label.new()
		t_name.text = team_name
		t_name.add_theme_font_size_override("font_size", 16)
		t_name.add_theme_color_override("font_color", Color("#ffffff"))
		team_info.add_child(t_name)
		
		var tag_lbl = Label.new()
		tag_lbl.text = tag_info["text"]
		tag_lbl.add_theme_color_override("font_color", tag_info["color"])
		tag_lbl.add_theme_font_size_override("font_size", 12)
		team_info.add_child(tag_lbl)
		
		# INDICADOR DE GANHO DE UPGRADE
		var const_rank = team_points_rank.get(team_name, 5)
		var is_top_3 = const_rank <= 3
		var dev_rate_str = "🚀 Ganho: +1~2% (Top 3)" if is_top_3 else "⚡ Ganho: +3~4% (Handicap)"
		
		var dev_lbl = Label.new()
		dev_lbl.text = dev_rate_str
		dev_lbl.add_theme_font_size_override("font_size", 12)
		dev_lbl.add_theme_color_override("font_color", Color("#f59e0b") if is_top_3 else Color("#38bdf8"))
		team_info.add_child(dev_lbl)
		
		# INDICADOR COMPLETO: GASTOS + VERBA RESTANTE + TETO
		var budget_lbl = Label.new()
		if remaining <= 0:
			budget_lbl.text = "💰 Gastou: $%sM | Teto Atingido ($0M Restantes)" % str(spent_m)
			budget_lbl.add_theme_color_override("font_color", Color("#ef4444"))
		else:
			budget_lbl.text = "💰 Gastou: $%sM | Restante: $%sM (Teto: $%sM)" % [str(spent_m), str(remaining_m), str(max_cap_m)]
			if remaining_m <= 25.0:
				budget_lbl.add_theme_color_override("font_color", Color("#f59e0b"))
			else:
				budget_lbl.add_theme_color_override("font_color", Color("#22c55e"))
				
		budget_lbl.add_theme_font_size_override("font_size", 11)
		team_info.add_child(budget_lbl)
		
		main_hbox.add_child(team_info)
		
		# Separador vertical fino
		var v_sep = VSeparator.new()
		main_hbox.add_child(v_sep)
		
		# --- BLOCO 2: BARRAS COLORIDAS DOS COMPONENTES TÉCNICOS ---
		var stats_vbox = VBoxContainer.new()
		stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_vbox.add_theme_constant_override("separation", 6)
		
		_add_component_bar(stats_vbox, "🚀 Motor", motor_val, Color("#ef4444"))
		_add_component_bar(stats_vbox, "💨 Aero", aero_val, Color("#22c55e"))
		_add_component_bar(stats_vbox, "🏎️ Chassi", chassi_val, Color("#facc15"))
		_add_component_bar(stats_vbox, "🔧 Confiab.", rel_val, Color("#a855f7"))
		
		main_hbox.add_child(stats_vbox)
		panel.add_child(main_hbox)
		teams_grid.add_child(panel)
		rank += 1

func _render_grid_budget_cap_summary(parent: VBoxContainer) -> void:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#141820")
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	
	var total_spent = 0.0
	var teams_at_cap = 0
	
	for t in Database.teams:
		var team_name = str(t.get("Nome", ""))
		var spent = Database.team_season_expenses.get(team_name, 0.0)
		var max_cap = Database.get_team_budget_cap(team_name) if Database.has_method("get_team_budget_cap") else Database.COST_CAP_LIMIT
		
		total_spent += spent
		if spent >= max_cap:
			teams_at_cap += 1
			
	var avg_spent_m = snapped((total_spent / max(1, Database.teams.size())) / 1_000_000.0, 0.1)
	
	var lbl_cap_title = Label.new()
	lbl_cap_title.text = "📊 ESCALA DE TETO ($135M a $155M dependendo da posição do ano anterior)"
	lbl_cap_title.add_theme_font_size_override("font_size", 13)
	lbl_cap_title.add_theme_color_override("font_color", Color("#94a3b8"))
	hbox.add_child(lbl_cap_title)
	
	var lbl_avg = Label.new()
	lbl_avg.text = "• Média gasta: $%sM" % str(avg_spent_m)
	lbl_avg.add_theme_font_size_override("font_size", 13)
	lbl_avg.add_theme_color_override("font_color", Color("#38bdf8"))
	hbox.add_child(lbl_avg)
	
	var lbl_blocked = Label.new()
	lbl_blocked.text = "• Equipes com teto esgotado: %d / %d" % [teams_at_cap, Database.teams.size()]
	lbl_blocked.add_theme_font_size_override("font_size", 13)
	lbl_blocked.add_theme_color_override("font_color", Color("#ef4444") if teams_at_cap > 0 else Color("#22c55e"))
	hbox.add_child(lbl_blocked)
	
	card.add_child(hbox)
	parent.add_child(card)

func _get_performance_tag(power: int) -> Dictionary:
	if power >= 273:
		return {"text": "🔥 Dominante (Top Grid)", "color": Color("#ef4444")}
	elif power >= 262:
		return {"text": "🟢 Altamente Competitivo", "color": Color("#22c55e")}
	elif power >= 250:
		return {"text": "🟡 Pelotão Intermediário", "color": Color("#eab308")}
	else:
		return {"text": "⚪ Retaguarda", "color": Color("#94a3b8")}

func _add_component_bar(parent: VBoxContainer, label_text: String, value: int, color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 95
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
	hbox.add_child(lbl)
	
	var pbar = ProgressBar.new()
	pbar.min_value = 50
	pbar.max_value = 99
	pbar.value = value
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbar.custom_minimum_size = Vector2(90, 15)
	pbar.show_percentage = false
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(3)
	pbar.add_theme_stylebox_override("fill", fill_style)
	hbox.add_child(pbar)
	
	var val_lbl = Label.new()
	val_lbl.text = str(value) + "%"
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	hbox.add_child(val_lbl)
	
	parent.add_child(hbox)
