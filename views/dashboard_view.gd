extends Control

var time_passed: float = 0.0
var sim_modal: Control = null

func _ready() -> void:
	if Database.has_signal("language_changed"):
		Database.language_changed.connect(build_ui)

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(_on_resized)
	build_ui()

func _on_resized() -> void:
	build_ui()

func _process(delta: float) -> void:
	time_passed += delta * 1.2
	queue_redraw()

func _draw() -> void:
	var screen_size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#0c0d0e"))
	
	# Bandeira Quadriculada Flutuante
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
				var alpha = 0.025 + (sin(time_passed + c * 0.4) * 0.012)
				draw_rect(Rect2(pos, Vector2(cell_w * 0.85, cell_h * 0.85)), Color(1, 1, 1, alpha))

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
	
	# Purga qualquer duplicação residual no banco de dados
	if Database.has_method("sanitize_unique_drivers"):
		Database.sanitize_unique_drivers()
		
	for c in get_children():
		c.queue_free()
			
	var canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	
	var vp_size = get_viewport_rect().size
	var avail_width = vp_size.x - 280
	var avail_height = vp_size.y - 120
	
	# Header do Dashboard
	var title_lbl = Label.new()
	title_lbl.text = Database.tr_text("DASHBOARD_TITLE") % Database.current_year
	title_lbl.position = Vector2(10, 5)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color("#ef4444"))
	canvas.add_child(title_lbl)
	
	# Carrega os pilotos únicos que disputaram ou disputam a temporada
	var active_drivers = Database.get_season_drivers() if Database.has_method("get_season_drivers") else Database.drivers
	
	# Cálculo do GP e Índice de Pista
	var max_tracks = max(1, Database.tracks.size())
	var gp_num = clampi(int(Database.current_gp), 1, max_tracks)
	var track_idx = gp_num - 1
	var track_curr = Database.tracks[track_idx] if Database.tracks.size() > 0 else {}
	
	# Cards Superiores (Exibe dinamicamente o número total exato: 22, 23, etc.)
	var stats_hbox = HBoxContainer.new()
	stats_hbox.position = Vector2(10, 38)
	stats_hbox.add_theme_constant_override("separation", 10)
	
	stats_hbox.add_child(_create_stat_card(Database.tr_text("CARD_CURRENT_GP"), "GP " + str(gp_num) + " - " + str(track_curr.get("Nome", ""))))
	stats_hbox.add_child(_create_stat_card(Database.tr_text("CARD_TEAMS"), Database.tr_text("LABEL_TEAMS_COUNT") % Database.teams.size()))
	stats_hbox.add_child(_create_stat_card(Database.tr_text("CARD_DRIVERS"), Database.tr_text("LABEL_DRIVERS_COUNT") % active_drivers.size()))
	canvas.add_child(stats_hbox)
	
	# Cálculo das 4 Colunas Proporcionais
	var margin_x = 10.0
	var margin_y = 90.0
	var gap_x = 12.0
	var gap_y = 10.0

	var col_w = (avail_width - (gap_x * 3.0)) / 4.0

	var col1_x = margin_x
	var col2_x = col1_x + col_w + gap_x
	var col3_x = col2_x + col_w + gap_x
	var col4_x = col3_x + col_w + gap_x

	# --- COLUNA 1 ---
	# 1. Campeonato de Pilotos | 2. Notícias do Paddock | 3. Evolução de Pilotos (Gráfico)
	var col1_h1 = avail_height * 0.45
	var col1_h2 = avail_height * 0.25
	var col1_h3 = avail_height * 0.28

	var drivers_win = _create_resizable_window("drivers_panel", Database.tr_text("PANEL_DRIVERS_CHAMP"), canvas)
	_build_drivers_content(drivers_win.get_content_node(), active_drivers)
	_apply_fixed_transform(drivers_win, Vector2(col1_x, margin_y), Vector2(col_w, col1_h1))

	var news_win = _create_resizable_window("news_panel", Database.tr_text("PANEL_PADDOCK_NEWS"), canvas)
	_build_news_content(news_win.get_content_node(), str(track_curr.get("Nome", "")), gp_num)
	_apply_fixed_transform(news_win, Vector2(col1_x, margin_y + col1_h1 + gap_y), Vector2(col_w, col1_h2))

	var drivers_evo_win = _create_resizable_window("drivers_evolution_panel", Database.tr_text("PANEL_DRIVERS_EVO"), canvas)
	_build_drivers_evolution_content(drivers_evo_win.get_content_node())
	_apply_fixed_transform(drivers_evo_win, Vector2(col1_x, margin_y + col1_h1 + col1_h2 + (gap_y * 2.0)), Vector2(col_w, col1_h3))

	# --- COLUNA 2 ---
	# 1. Construtores | 2. Hierarquia Técnica | 3. Estatísticas da Temporada
	var col2_h1 = avail_height * 0.38
	var col2_h2 = avail_height * 0.30
	var col2_h3 = avail_height * 0.30

	var teams_win = _create_resizable_window("teams_panel", Database.tr_text("TITLE_CONSTRUCTORS"), canvas)
	_build_teams_content(teams_win.get_content_node(), active_drivers)
	_apply_fixed_transform(teams_win, Vector2(col2_x, margin_y), Vector2(col_w, col2_h1))

	var tech_win = _create_resizable_window("tech_power_panel", Database.tr_text("PANEL_TECH_POWER"), canvas)
	_build_tech_power_content(tech_win.get_content_node())
	_apply_fixed_transform(tech_win, Vector2(col2_x, margin_y + col2_h1 + gap_y), Vector2(col_w, col2_h2))

	var stats_season_win = _create_resizable_window("stats_season_panel", Database.tr_text("PANEL_SEASON_STATS"), canvas)
	_build_season_stats_content(stats_season_win.get_content_node())
	_apply_fixed_transform(stats_season_win, Vector2(col2_x, margin_y + col2_h1 + col2_h2 + (gap_y * 2.0)), Vector2(col_w, col2_h3))

	# --- COLUNA 3 ---
	# 1. Mercado & Contratos (Ocupa a coluna inteira para caber toda a lista)
	var col3_h1 = avail_height * 0.98

	var market_win = _create_resizable_window("market_panel", Database.tr_text("PANEL_MARKET"), canvas)
	_build_market_content(market_win.get_content_node())
	_apply_fixed_transform(market_win, Vector2(col3_x, margin_y), Vector2(col_w, col3_h1))

	# --- COLUNA 4 ---
	# 1. Etapas Próximas | 2. Info do Próximo GP | 3. Simulação Acelerada
	var col4_h1 = avail_height * 0.28
	var col4_h2 = avail_height * 0.35
	var col4_h3 = avail_height * 0.33

	var cal_win = _create_resizable_window("cal_panel", Database.tr_text("PANEL_UPCOMING_GPS"), canvas)
	_build_calendar_content(cal_win.get_content_node(), track_idx)
	_apply_fixed_transform(cal_win, Vector2(col4_x, margin_y), Vector2(col_w, col4_h1))

	var track_win = _create_resizable_window("track_info_panel", Database.tr_text("PANEL_NEXT_GP_INFO"), canvas)
	_build_track_info_content(track_win.get_content_node(), track_curr)
	_apply_fixed_transform(track_win, Vector2(col4_x, margin_y + col4_h1 + gap_y), Vector2(col_w, col4_h2))

	var final_panel_title := "Finanças" if str(Database.game_mode) == "manager" else Database.tr_text("PANEL_FAST_SIM")
	var final_panel := _create_resizable_window("fast_sim_panel", final_panel_title, canvas)
	if str(Database.game_mode) != "manager":
		_build_fast_sim_content(final_panel.get_content_node())
	_apply_fixed_transform(final_panel, Vector2(col4_x, margin_y + col4_h1 + col4_h2 + (gap_y * 2.0)), Vector2(col_w, col4_h3))

func _create_resizable_window(key: String, title_text: String, parent: Control) -> ResizablePanel:
	var panel = ResizablePanel.new()
	panel.panel_key = key
	panel.title = title_text
	parent.add_child(panel)
	panel.set_title(title_text)
	return panel

func _apply_fixed_transform(panel: ResizablePanel, pos_vec: Vector2, size_vec: Vector2) -> void:
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0

	panel.custom_minimum_size = size_vec
	panel.size = size_vec
	panel.position = pos_vec

# --- CONTEÚDO DA BOX DE ESTATÍSTICAS DA TEMPORADA ---
func _build_season_stats_content(parent: Control) -> void:
	if parent == null:
		return

	for child in parent.get_children():
		child.queue_free()

	var tab_container = TabContainer.new()
	tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab_container.add_theme_font_size_override("font_size", 11)
	parent.add_child(tab_container)

	# ABA 1: RIVALIDADES
	var tab_rivalry = MarginContainer.new()
	tab_rivalry.name = "⚔️ Rivalidades"
	tab_rivalry.add_theme_constant_override("margin_left", 6)
	tab_rivalry.add_theme_constant_override("margin_top", 6)
	tab_rivalry.add_theme_constant_override("margin_right", 6)
	tab_rivalry.add_theme_constant_override("margin_bottom", 6)
	tab_container.add_child(tab_rivalry)

	_build_rivalry_tab(tab_rivalry)

	# ABA 2: PILOTOS
	var tab_drivers = MarginContainer.new()
	tab_drivers.name = "Pilotos"
	tab_drivers.add_theme_constant_override("margin_left", 6)
	tab_drivers.add_theme_constant_override("margin_top", 6)
	tab_drivers.add_theme_constant_override("margin_right", 6)
	tab_drivers.add_theme_constant_override("margin_bottom", 6)
	tab_container.add_child(tab_drivers)

	_build_driver_stats_tab(tab_drivers)

	# ABA 3: EQUIPES
	var tab_teams = MarginContainer.new()
	tab_teams.name = "Equipes"
	tab_teams.add_theme_constant_override("margin_left", 6)
	tab_teams.add_theme_constant_override("margin_top", 6)
	tab_teams.add_theme_constant_override("margin_right", 6)
	tab_teams.add_theme_constant_override("margin_bottom", 6)
	tab_container.add_child(tab_teams)

	_build_team_stats_tab(tab_teams)

func _build_rivalry_tab(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	# Disputa P1 vs P2
	var sorted_drivers = Database.drivers.duplicate()
	sorted_drivers.sort_custom(func(a, b): return int(a.get("Pontos", 0)) > int(b.get("Pontos", 0)))
	
	var p1_name = sorted_drivers[0].get("Nome", "Piloto A") if sorted_drivers.size() > 0 else "-"
	var p1_pts = sorted_drivers[0].get("Pontos", 0) if sorted_drivers.size() > 0 else 0
	var p2_name = sorted_drivers[1].get("Nome", "Piloto B") if sorted_drivers.size() > 1 else "-"
	var p2_pts = sorted_drivers[1].get("Pontos", 0) if sorted_drivers.size() > 1 else 0
	var gap = p1_pts - p2_pts

	var title_lbl = Label.new()
	title_lbl.text = "🏆 Disputa do Título"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color("#f59e0b"))
	vbox.add_child(title_lbl)

	var title_battle_lbl = Label.new()
	title_battle_lbl.text = "• %s (%dP) vs %s (%dP)\n  ➔ Diferença: %d pts" % [p1_name, p1_pts, p2_name, p2_pts, gap]
	title_battle_lbl.add_theme_font_size_override("font_size", 11)
	title_battle_lbl.add_theme_color_override("font_color", Color("#e2e8f0"))
	vbox.add_child(title_battle_lbl)

	vbox.add_child(HSeparator.new())

	# Duelo entre Construtores (P1 vs P2 Construtores)
	var sorted_teams = Database.teams.duplicate()
	sorted_teams.sort_custom(func(a, b): return int(a.get("Pontos", 0)) > int(b.get("Pontos", 0)))
	if sorted_teams.size() >= 2:
		var t1 = sorted_teams[0]
		var t2 = sorted_teams[1]
		var t_gap = int(t1.get("Pontos", 0)) - int(t2.get("Pontos", 0))

		var const_title = Label.new()
		const_title.text = "🏎️ Disputa de Construtores"
		const_title.add_theme_font_size_override("font_size", 12)
		const_title.add_theme_color_override("font_color", Color("#38bdf8"))
		vbox.add_child(const_title)

		var const_lbl = Label.new()
		const_lbl.text = "• %s (%dP) vs %s (%dP)\n  ➔ Diferença: %d pts" % [
			t1.get("Nome", "-"), t1.get("Pontos", 0),
			t2.get("Nome", "-"), t2.get("Pontos", 0),
			t_gap
		]
		const_lbl.add_theme_font_size_override("font_size", 11)
		const_lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
		vbox.add_child(const_lbl)

	scroll.add_child(vbox)
	parent.add_child(scroll)

func _build_driver_stats_tab(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)

	var active_drivers = []
	for d in Database.drivers:
		var eq = d.get("Equipe", "")
		if eq != "Free Agent" and eq != "Aposentado" and eq != "":
			active_drivers.append(d)

	active_drivers.sort_custom(func(a, b):
		var p_a = int(a.get("Pontos", 0))
		var p_b = int(b.get("Pontos", 0))
		if p_a != p_b: return p_a > p_b
		return int(a.get("VitoriasAno", 0)) > int(b.get("VitoriasAno", 0))
	)

	for i in range(active_drivers.size()):
		active_drivers[i]["_champ_pos"] = i + 1

	var best_wins = _find_best_driver_stat(active_drivers, "VitoriasAno", true)
	var best_dnfs = _find_best_driver_stat(active_drivers, "DNFsAno", false)
	var best_streak = _find_best_driver_stat(active_drivers, "SequenciaPontos", true)
	var best_gained = _find_best_driver_stat(active_drivers, "PosicoesGanhaAno", true)
	var best_lost = _find_best_driver_stat(active_drivers, "PosicoesPerdidasAno", false)

	_add_stat_row(vbox, "🥇 Mais vitórias:", _format_stat_driver(best_wins, "VitoriasAno", ""), Color("#22c55e"))
	_add_stat_row(vbox, "💥 Mais abandonos:", _format_stat_driver(best_dnfs, "DNFsAno", ""), Color("#ef4444"))
	_add_stat_row(vbox, "🔥 Sequência pontuando:", _format_stat_driver(best_streak, "SequenciaPontos", " GPs"), Color("#38bdf8"))
	_add_stat_row(vbox, "📈 Mais posições ganhas:", _format_stat_driver(best_gained, "PosicoesGanhaAno", ""), Color("#22c55e"))
	_add_stat_row(vbox, "📉 Mais posições perdidas:", _format_stat_driver(best_lost, "PosicoesPerdidasAno", ""), Color("#f59e0b"))

	scroll.add_child(vbox)
	parent.add_child(scroll)

func _build_team_stats_tab(parent: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)

	var team_stats: Dictionary = {}
	for t in Database.teams:
		var t_name = str(t.get("Nome", ""))
		team_stats[t_name] = {
			"Nome": t_name, "Pontos": 0, "VitoriasAno": 0,
			"DNFsAno": 0, "SequenciaPontos": 0,
			"PosicoesGanhaAno": 0, "PosicoesPerdidasAno": 0
		}

	for d in Database.drivers:
		var eq = str(d.get("Equipe", ""))
		if team_stats.has(eq):
			team_stats[eq]["Pontos"] += int(d.get("Pontos", 0))
			team_stats[eq]["VitoriasAno"] += int(d.get("VitoriasAno", 0))
			team_stats[eq]["DNFsAno"] += int(d.get("DNFsAno", 0))
			team_stats[eq]["PosicoesGanhaAno"] += int(d.get("PosicoesGanhaAno", 0))
			team_stats[eq]["PosicoesPerdidasAno"] += int(d.get("PosicoesPerdidasAno", 0))
			var d_seq = int(d.get("SequenciaPontos", 0))
			if d_seq > team_stats[eq]["SequenciaPontos"]:
				team_stats[eq]["SequenciaPontos"] = d_seq

	var teams_list = team_stats.values()
	teams_list.sort_custom(func(a, b):
		if a["Pontos"] != b["Pontos"]: return a["Pontos"] > b["Pontos"]
		return a["VitoriasAno"] > b["VitoriasAno"]
	)

	for i in range(teams_list.size()):
		teams_list[i]["_champ_pos"] = i + 1

	var best_wins = _find_best_team_stat(teams_list, "VitoriasAno", true)
	var best_dnfs = _find_best_team_stat(teams_list, "DNFsAno", false)
	var best_streak = _find_best_team_stat(teams_list, "SequenciaPontos", true)
	var best_gained = _find_best_team_stat(teams_list, "PosicoesGanhaAno", true)
	var best_lost = _find_best_team_stat(teams_list, "PosicoesPerdidasAno", false)

	_add_stat_row(vbox, "🥇 Mais vitórias:", _format_stat_team(best_wins, "VitoriasAno", ""), Color("#22c55e"))
	_add_stat_row(vbox, "💥 Mais abandonos:", _format_stat_team(best_dnfs, "DNFsAno", ""), Color("#ef4444"))
	_add_stat_row(vbox, "🔥 Sequência pontuando:", _format_stat_team(best_streak, "SequenciaPontos", " GPs"), Color("#38bdf8"))
	_add_stat_row(vbox, "📈 Mais posições ganhas:", _format_stat_team(best_gained, "PosicoesGanhaAno", ""), Color("#22c55e"))
	_add_stat_row(vbox, "📉 Mais posições perdidas:", _format_stat_team(best_lost, "PosicoesPerdidasAno", ""), Color("#f59e0b"))

	scroll.add_child(vbox)
	parent.add_child(scroll)

func _find_best_driver_stat(drivers: Array, key: String, prefer_better_pos: bool) -> Dictionary:
	var best_driver = {}
	var max_val = 0

	for d in drivers:
		var val = int(d.get(key, 0))
		if val > max_val:
			max_val = val
			best_driver = d
		elif val == max_val and val > 0 and not best_driver.is_empty():
			var curr_pos = int(d.get("_champ_pos", 99))
			var best_pos = int(best_driver.get("_champ_pos", 99))
			if prefer_better_pos and curr_pos < best_pos:
				best_driver = d
			elif not prefer_better_pos and curr_pos > best_pos:
				best_driver = d

	return best_driver if max_val > 0 else {}

func _find_best_team_stat(teams: Array, key: String, prefer_better_pos: bool) -> Dictionary:
	var best_team = {}
	var max_val = 0

	for t in teams:
		var val = int(t.get(key, 0))
		if val > max_val:
			max_val = val
			best_team = t
		elif val == max_val and val > 0 and not best_team.is_empty():
			var curr_pos = int(t.get("_champ_pos", 99))
			var best_pos = int(best_team.get("_champ_pos", 99))
			if prefer_better_pos and curr_pos < best_pos:
				best_team = t
			elif not prefer_better_pos and curr_pos > best_pos:
				best_team = t

	return best_team if max_val > 0 else {}

func _format_stat_driver(driver: Dictionary, key: String, suffix: String) -> String:
	if driver.is_empty(): return "Nenhum ainda"
	return str(driver.get("Nome", "-")) + " (" + str(int(driver.get(key, 0))) + suffix + ")"

func _format_stat_team(team: Dictionary, key: String, suffix: String) -> String:
	if team.is_empty(): return "Nenhuma ainda"
	return str(team.get("Nome", "-")) + " (" + str(int(team.get(key, 0))) + suffix + ")"

func _add_stat_row(container: VBoxContainer, label_text: String, value_text: String, val_color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl_title = Label.new()
	lbl_title.text = label_text + " "
	lbl_title.add_theme_font_size_override("font_size", 11)
	lbl_title.add_theme_color_override("font_color", Color("#cbd5e1"))

	var lbl_val = Label.new()
	lbl_val.text = value_text
	lbl_val.add_theme_font_size_override("font_size", 11)
	lbl_val.add_theme_color_override("font_color", val_color)

	hbox.add_child(lbl_title)
	hbox.add_child(lbl_val)
	container.add_child(hbox)

# --- PAINÉIS DE DADOS ---

func _build_drivers_content(parent: Control, active_drivers: Array) -> void:
	if parent == null: return
	for child in parent.get_children(): child.queue_free()

	if Database.has_method("sanitize_unique_drivers"):
		Database.sanitize_unique_drivers()

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	
	_add_grid_header(grid, Database.tr_text("COL_POS"), 30)
	_add_grid_header(grid, Database.tr_text("COL_DRIVER"), 120)
	_add_grid_header(grid, Database.tr_text("COL_TEAM"), 100)
	_add_grid_header(grid, Database.tr_text("COL_PTS"), 35)
	_add_grid_header(grid, Database.tr_text("COL_WINS"), 30)
	_add_grid_header(grid, Database.tr_text("COL_PODIUMS"), 30)
	_add_grid_header(grid, Database.tr_text("COL_DNFS"), 30)
	
	# Garante a filtragem rigorosa de apenas 1 entrada por piloto na tabela
	var raw_list = Database.get_season_drivers() if Database.has_method("get_season_drivers") else active_drivers
	var unique_drivers: Array = []
	var seen: Dictionary = {}
	
	for d in raw_list:
		var name_key = str(d.get("Nome", d.get("nome", ""))).strip_edges().to_lower()
		if not seen.has(name_key) and not name_key.is_empty():
			seen[name_key] = true
			unique_drivers.append(d)

	unique_drivers.sort_custom(func(a, b):
		var p_a = int(a.get("Pontos", 0))
		var p_b = int(b.get("Pontos", 0))
		if p_a != p_b: return p_a > p_b
		var v_a = int(a.get("VitoriasAno", 0))
		var v_b = int(b.get("VitoriasAno", 0))
		if v_a != v_b: return v_a > v_b
		var pod_a = int(a.get("PodiosAno", 0))
		var pod_b = int(b.get("PodiosAno", 0))
		if pod_a != pod_b: return pod_a > pod_b
		return str(a.get("Nome", "")) < str(b.get("Nome", ""))
	)
	
	var pos_idx = 1
	for d in unique_drivers:
		var team_display = str(d.get("Equipe", ""))
		var team_color = Color("#94a3b8")
		if team_display == "Free Agent":
			team_display = Database.tr_text("STATUS_FREE_AGENT_FULL")
			team_color = Color("#f59e0b")
		elif team_display == "Aposentado":
			team_display = Database.tr_text("STATUS_RETIRED")
			team_color = Color("#64748b")
			
		_add_cell(grid, str(pos_idx) + "º")
		_add_cell(grid, str(d.get("Nome", "Piloto")))
		_add_cell(grid, team_display, team_color)
		_add_cell(grid, str(int(d.get("Pontos", 0))))
		_add_cell(grid, str(int(d.get("VitoriasAno", 0))))
		_add_cell(grid, str(int(d.get("PodiosAno", 0))))
		
		var dnf_cnt = int(d.get("DNFsAno", 0))
		var dnf_color = Color("#ef4444") if dnf_cnt > 0 else Color("#94a3b8")
		_add_cell(grid, str(dnf_cnt), dnf_color)
		
		pos_idx += 1
		
	scroll.add_child(grid)
	parent.add_child(scroll)

func _build_teams_content(parent: Control, active_drivers: Array) -> void:
	if parent == null: return
	for child in parent.get_children(): child.queue_free()

	# Garante que o banco de dados do Database limpe pilotos duplicados
	if Database.has_method("sanitize_unique_drivers"):
		Database.sanitize_unique_drivers()

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	
	_add_grid_header(grid, "POS", 28)
	_add_grid_header(grid, "EQUIPE", 110)
	_add_grid_header(grid, "PTS", 45)
	_add_grid_header(grid, "VIT", 30)
	_add_grid_header(grid, "POD", 30)
	_add_grid_header(grid, "DNF", 30)
	
	var team_stats: Dictionary = {}
	for t in Database.teams:
		var t_name = str(t.get("Nome", ""))
		team_stats[t_name] = {"Nome": t_name, "Pontos": 0, "Vitorias": 0, "Podios": 0, "DNFs": 0}
		
	# TRAVA ANTI-DUPLICAÇÃO: Mantém apenas 1 instância por nome de piloto
	var unique_drivers: Array = []
	var seen_names: Dictionary = {}
	for d in active_drivers:
		var d_name = str(d.get("Nome", d.get("nome", ""))).strip_edges().to_lower()
		if not d_name.is_empty() and not seen_names.has(d_name):
			seen_names[d_name] = true
			unique_drivers.append(d)

	for d in unique_drivers:
		var eq = str(d.get("Equipe", ""))
		if team_stats.has(eq):
			team_stats[eq]["Pontos"] += int(d.get("Pontos", 0))
			team_stats[eq]["Vitorias"] += int(d.get("VitoriasAno", 0))
			team_stats[eq]["Podios"] += int(d.get("PodiosAno", 0))
			team_stats[eq]["DNFs"] += int(d.get("DNFsAno", 0))
			
	var sorted_teams = team_stats.values()
	sorted_teams.sort_custom(func(a, b):
		if a["Pontos"] != b["Pontos"]: return a["Pontos"] > b["Pontos"]
		if a["Vitorias"] != b["Vitorias"]: return a["Vitorias"] > b["Vitorias"]
		if a["Podios"] != b["Podios"]: return a["Podios"] > b["Podios"]
		return a["Nome"] < b["Nome"]
	)
	
	var t_pos = 1
	for st in sorted_teams:
		_add_cell(grid, str(t_pos) + "º")
		_add_cell(grid, str(st["Nome"]))
		_add_cell(grid, str(st["Pontos"]) + " pts")
		_add_cell(grid, str(st["Vitorias"]))
		_add_cell(grid, str(st["Podios"]))
		
		var t_dnf = int(st["DNFs"])
		var t_dnf_color = Color("#ef4444") if t_dnf > 0 else Color("#94a3b8")
		_add_cell(grid, str(t_dnf), t_dnf_color)
		
		t_pos += 1
		
	scroll.add_child(grid)
	parent.add_child(scroll)

func _build_market_content(parent: Control) -> void:
	if parent == null: return
	for child in parent.get_children(): child.queue_free()

	var tab_container = TabContainer.new()
	tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab_container.add_theme_font_size_override("font_size", 11)
	parent.add_child(tab_container)

	var tab_contracts = MarginContainer.new()
	tab_contracts.name = "Contratos"
	tab_contracts.add_theme_constant_override("margin_left", 4)
	tab_contracts.add_theme_constant_override("margin_top", 4)
	tab_contracts.add_theme_constant_override("margin_right", 4)
	tab_contracts.add_theme_constant_override("margin_bottom", 4)
	tab_container.add_child(tab_contracts)

	var scroll_c = ScrollContainer.new()
	scroll_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_contracts.add_child(scroll_c)

	var grid_c = GridContainer.new()
	grid_c.columns = 4
	grid_c.add_theme_constant_override("h_separation", 10)
	grid_c.add_theme_constant_override("v_separation", 4)
	scroll_c.add_child(grid_c)

	_add_micro_header(grid_c, Database.tr_text("COL_DRIVER"), 85)
	_add_micro_header(grid_c, Database.tr_text("COL_TEAM"), 80)
	_add_micro_header(grid_c, Database.tr_text("COL_CONTRACT"), 55)
	_add_micro_header(grid_c, Database.tr_text("COL_MORALE"), 45)

	# --- CORREÇÃO: Utiliza a lista ordenada com prioridades ---
	var sorted_drivers = _get_sorted_drivers_for_market_panel()

	for d in sorted_drivers:
		var name_str = str(d.get("Nome", ""))
		var team_str = str(d.get("Equipe", "Free Agent"))
		var c_years = int(d.get("AnosContrato", 0))
		
		var years_str = "-"
		if team_str == "Free Agent":
			years_str = Database.tr_text("STATUS_FREE")
		elif team_str != "Aposentado":
			var year_unit = Database.tr_text("YEAR_SINGLE") if c_years == 1 else Database.tr_text("YEAR_PLURAL")
			years_str = str(c_years) + " " + year_unit

		var morale_val = int(d.get("Moral", 75))

		# Célula Piloto
		var p_color = Color("#64748b") if team_str == "Aposentado" else Color("#ffffff")
		_add_micro_cell(grid_c, name_str, p_color)
		
		# Célula Equipe
		var t_color = Color("#64748b") if team_str == "Aposentado" else (Color("#38bdf8") if team_str == "Free Agent" else Color("#e2e8f0"))
		_add_micro_cell(grid_c, team_str, t_color)
		
		# Célula Contrato
		var c_color = Color("#64748b") if team_str == "Aposentado" else (Color("#f59e0b") if c_years <= 1 and team_str != "Free Agent" else Color("#94a3b8"))
		_add_micro_cell(grid_c, years_str, c_color)

		# Célula Moral
		var m_color = Color("#22c55e")
		if morale_val < 40:
			m_color = Color("#ef4444")
		elif morale_val < 70:
			m_color = Color("#f59e0b")

		_add_micro_cell(grid_c, str(morale_val) + "%", m_color)

	var tab_negotiations = MarginContainer.new()
	tab_negotiations.name = "Interesses"
	tab_negotiations.add_theme_constant_override("margin_left", 4)
	tab_negotiations.add_theme_constant_override("margin_top", 4)
	tab_negotiations.add_theme_constant_override("margin_right", 4)
	tab_negotiations.add_theme_constant_override("margin_bottom", 4)
	tab_container.add_child(tab_negotiations)

	var scroll_n = ScrollContainer.new()
	scroll_n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_n.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_negotiations.add_child(scroll_n)

	var vbox_n = VBoxContainer.new()
	vbox_n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_n.add_theme_constant_override("separation", 6)
	scroll_n.add_child(vbox_n)

	for d in Database.drivers:
		var d_name = str(d.get("Nome", ""))
		var morale = int(d.get("Moral", 75))
		var current_team = str(d.get("Equipe", "Free Agent"))
		var c_years = int(d.get("AnosContrato", 0))

		if morale < 45 or c_years <= 1 or current_team == "Free Agent":
			var rumor_lbl = Label.new()
			rumor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rumor_lbl.add_theme_font_size_override("font_size", 11)

			if current_team == "Free Agent":
				rumor_lbl.text = "• " + d_name + " (Livre): Em busca de assento."
				rumor_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
			elif morale < 40:
				rumor_lbl.text = "• " + d_name + ": Insatisfeito na " + current_team + " (Aberto a propostas)."
				rumor_lbl.add_theme_color_override("font_color", Color("#ef4444"))
			else:
				rumor_lbl.text = "• " + d_name + ": Final de contrato na " + current_team + "."
				rumor_lbl.add_theme_color_override("font_color", Color("#f59e0b"))

			vbox_n.add_child(rumor_lbl)

	var tab_history = MarginContainer.new()
	tab_history.name = "Histórico"
	tab_history.add_theme_constant_override("margin_left", 4)
	tab_history.add_theme_constant_override("margin_top", 4)
	tab_history.add_theme_constant_override("margin_right", 4)
	tab_history.add_theme_constant_override("margin_bottom", 4)
	tab_container.add_child(tab_history)

	var scroll_h = ScrollContainer.new()
	scroll_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_history.add_child(scroll_h)

	var vbox_h = VBoxContainer.new()
	vbox_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_h.add_theme_constant_override("separation", 6)
	scroll_h.add_child(vbox_h)

	# Lista de palavras-chave para identificar qualquer tipo de movimentação no mercado
	var market_keywords = [
		"contratou", "assinou", "assina", "promovido", "promoveu",
		"APOSENTADORIA", "aposentou", "DEMISSÃO", "demitido", "demite",
		"RESCISÃO", "rescindiu", "pediu demissão", "saiu da"
	]

	var history_list = Database.get("transfer_history")
	var has_items = false

	# 1. Tenta carregar do array oficial de transferências
	if history_list != null and history_list is Array and history_list.size() > 0:
		has_items = true
		for item in history_list:
			var h_lbl = Label.new()
			h_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h_lbl.add_theme_font_size_override("font_size", 11)
			
			var detail = str(item.get("detalhe", ""))
			var type_str = str(item.get("tipo", ""))
			h_lbl.text = "• [%s - GP %d] %s" % [
				str(item.get("temporada", Database.current_year)),
				int(item.get("gp_num", 1)),
				detail
			]
			
			# Destaque de cores: Vermelho para saídas/demissões/aposentadorias, Verde para contratações
			if type_str in ["Aposentadoria", "Demissão", "Rescisão"] or "DEMISSÃO" in detail or "APOSENTADORIA" in detail or "demitido" in detail or "pediu demissão" in detail:
				h_lbl.add_theme_color_override("font_color", Color("#ef4444"))
			else:
				h_lbl.add_theme_color_override("font_color", Color("#22c55e"))
				
			vbox_h.add_child(h_lbl)

	# 2. Fallback abrangente usando o news_feed
	if not has_items and Database.get("news_feed") != null:
		for news in Database.news_feed:
			var news_str = str(news)
			var matches_keyword = false
			for kw in market_keywords:
				if kw.to_lower() in news_str.to_lower():
					matches_keyword = true
					break
					
			if matches_keyword:
				has_items = true
				var h_lbl = Label.new()
				h_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				h_lbl.add_theme_font_size_override("font_size", 11)
				h_lbl.text = "• " + news_str
				
				# Cor vermelha se for demissão/aposentadoria/rescisão
				if "APOSENTADORIA" in news_str or "demitido" in news_str or "DEMISSÃO" in news_str or "pediu demissão" in news_str or "rescindiu" in news_str:
					h_lbl.add_theme_color_override("font_color", Color("#ef4444"))
				else:
					h_lbl.add_theme_color_override("font_color", Color("#22c55e"))
					
				vbox_h.add_child(h_lbl)

	if not has_items:
		var empty_lbl = Label.new()
		empty_lbl.text = "Nenhuma transferência registrada nesta temporada."
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color("#64748b"))
		vbox_h.add_child(empty_lbl)

	# 3. Mensagem padrão caso não exista nenhum evento
	if not has_items:
		var empty_lbl = Label.new()
		empty_lbl.text = "Nenhuma transferência registrada nesta temporada."
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color("#64748b"))
		vbox_h.add_child(empty_lbl)

func _build_calendar_content(parent: Control, current_track_idx: int) -> void:
	if parent == null: return
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	
	_add_grid_header(grid, "GP", 35)
	_add_grid_header(grid, "CIRCUITO", 130)
	_add_grid_header(grid, "STATUS", 85)
	
	var total_tracks = Database.tracks.size()
	var min_idx = max(0, current_track_idx - 1)
	var max_idx = min(total_tracks - 1, current_track_idx + 2)
	
	for i in range(min_idx, max_idx + 1):
		var gp_num = i + 1
		var track = Database.tracks[i]
		var status_text = "🗓️ Futura"
		var text_color = Color("#94a3b8")
		
		if i < current_track_idx:
			status_text = "✅ Concluída"
			text_color = Color("#22c55e")
		elif i == current_track_idx:
			status_text = "▶ ATUAL"
			text_color = Color("#ef4444")
			
		_add_cell(grid, "GP " + str(gp_num), text_color)
		_add_cell(grid, str(track.get("Nome", "")), text_color)
		_add_cell(grid, status_text, text_color)
		
	scroll.add_child(grid)
	parent.add_child(scroll)

func _build_track_info_content(parent: Control, track: Dictionary) -> void:
	if parent == null: return
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	
	var track_lbl = Label.new()
	track_lbl.text = "📍 " + str(track.get("Nome", "")) + " (" + str(track.get("Voltas", 58)) + " Voltas)"
	track_lbl.add_theme_font_size_override("font_size", 13)
	track_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(track_lbl)
	
	var chance_rain = int(float(track.get("ChanceChuva", 0.20)) * 100)
	var rain_lbl = Label.new()
	rain_lbl.text = "🌧️ Probabilidade de Chuva: " + str(chance_rain) + "%"
	rain_lbl.add_theme_font_size_override("font_size", 12)
	rain_lbl.add_theme_color_override("font_color", Color("#38bdf8") if chance_rain > 30 else Color("#94a3b8"))
	vbox.add_child(rain_lbl)
	
	var wear_lbl = Label.new()
	wear_lbl.text = "🏎️ Desgaste de Pneus estimado: Média / Alta"
	wear_lbl.add_theme_font_size_override("font_size", 12)
	wear_lbl.add_theme_color_override("font_color", Color("#f59e0b"))
	vbox.add_child(wear_lbl)
	
	var zones_count = str(track.get("ZonasDRS", track.get("drs_zones", 2)))
	var ultrapassagem_lbl = Label.new()
	ultrapassagem_lbl.text = "⚡ Zonas de Ultrapassagem: " + zones_count + " Zonas"
	ultrapassagem_lbl.add_theme_font_size_override("font_size", 12)
	ultrapassagem_lbl.add_theme_color_override("font_color", Color("#22c55e"))
	vbox.add_child(ultrapassagem_lbl)
	
	var last_winner_driver = str(track.get("UltimoVencedorPiloto", track.get("last_winner_driver", "Nenhum")))
	var last_winner_team = str(track.get("UltimoVencedorEquipe", track.get("last_winner_team", "")))
	var winner_text = last_winner_driver
	if last_winner_team != "":
		winner_text += " (" + last_winner_team + ")"
		
	var winner_lbl = Label.new()
	winner_lbl.text = "🏆 Última Vitória: " + winner_text
	winner_lbl.add_theme_font_size_override("font_size", 12)
	winner_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
	vbox.add_child(winner_lbl)
	
	parent.add_child(vbox)

func _build_tech_power_content(parent: Control) -> void:
	if parent == null: return
	for child in parent.get_children(): child.queue_free()

	var tab_container = TabContainer.new()
	tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	tab_container.add_theme_font_size_override("font_size", 11)
	parent.add_child(tab_container)

	# ABA 1: RANKING DO GRID (POWER INDEX)
	var tab_grid = MarginContainer.new()
	tab_grid.name = "Ranking do Grid"
	tab_grid.add_theme_constant_override("margin_left", 6)
	tab_grid.add_theme_constant_override("margin_top", 6)
	tab_grid.add_theme_constant_override("margin_right", 6)
	tab_grid.add_theme_constant_override("margin_bottom", 6)
	tab_container.add_child(tab_grid)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 5)

	_add_grid_header(grid, "POS", 30)
	_add_grid_header(grid, "EQUIPE", 120)
	_add_grid_header(grid, "POWER INDEX", 90)

	var teams_power = []
	for t in Database.teams:
		var t_name = str(t.get("Nome", ""))
		var p_info = Database.get_team_power_index(t_name)
		var p_val = float(p_info.get("overall", 0.0)) if p_info is Dictionary else 0.0
		teams_power.append({"Nome": t_name, "Power": p_val})

	teams_power.sort_custom(func(a, b): return a["Power"] > b["Power"])

	var rank = 1
	for tp in teams_power:
		_add_cell(grid, str(rank) + "º", Color("#ffffff"))
		_add_cell(grid, str(tp["Nome"]), Color("#ffffff"))
		_add_cell(grid, str(snapped(tp["Power"], 0.1)) + " Pts", Color("#38bdf8"))
		rank += 1

	scroll.add_child(grid)
	tab_grid.add_child(scroll)

	# ABA 2: LÍDERES POR QUESITO TÉCNICO
	var tab_top = MarginContainer.new()
	tab_top.name = "Líderes do Grid"
	tab_top.add_theme_constant_override("margin_left", 6)
	tab_top.add_theme_constant_override("margin_top", 6)
	tab_top.add_theme_constant_override("margin_right", 6)
	tab_top.add_theme_constant_override("margin_bottom", 6)
	tab_container.add_child(tab_top)

	var scroll_top = ScrollContainer.new()
	scroll_top.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox_top = VBoxContainer.new()
	vbox_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_top.add_theme_constant_override("separation", 6)

	# Busca as equipes líderes por quesito considerando pontos no campeonato como desempate
	var best_engine = _find_best_team_by_stat("Motor")
	var best_aero = _find_best_team_by_stat("Aero")
	var best_chassis = _find_best_team_by_stat("Chassi")
	var best_reliability = _find_best_team_by_stat("Confiabilidade")
	var best_overall = _find_best_team_by_overall()

	_add_leader_stat_bar(vbox_top, "Melhor Motor", best_engine, "Motor", Color("#ef4444"))
	_add_leader_stat_bar(vbox_top, "Melhor Aerodinâmica", best_aero, "Aero", Color("#22c55e"))
	_add_leader_stat_bar(vbox_top, "Melhor Chassi", best_chassis, "Chassi", Color("#facc15"))
	_add_leader_stat_bar(vbox_top, "Melhor Confiabilidade", best_reliability, "Confiabilidade", Color("#a855f7"))
	_add_leader_stat_bar(vbox_top, "Melhor Carro (Overall)", best_overall, "Overall", Color("#38bdf8"))

	scroll_top.add_child(vbox_top)
	tab_top.add_child(scroll_top)


# --- FUNÇÕES AUXILIARES DE CÁLCULO E EXIBIÇÃO DE LÍDERES ---

func _find_best_team_by_stat(stat_key: String) -> Dictionary:
	var best_team: Dictionary = {}
	var max_val: float = -1.0
	
	for t in Database.teams:
		var val = float(t.get(stat_key, 0.0))
		var pts = int(t.get("Pontos", 0))
		
		if val > max_val:
			max_val = val
			best_team = t
		elif val == max_val and not best_team.is_empty():
			# Critério de desempate: maior quantidade de pontos no campeonato
			var best_pts = int(best_team.get("Pontos", 0))
			if pts > best_pts:
				best_team = t
				
	return best_team

func _find_best_team_by_overall() -> Dictionary:
	var best_team: Dictionary = {}
	var max_val: float = -1.0
	
	for t in Database.teams:
		var t_name = str(t.get("Nome", ""))
		var p_info = Database.get_team_power_index(t_name)
		var val = float(p_info.get("overall", 0.0)) if p_info is Dictionary else 0.0
		var pts = int(t.get("Pontos", 0))
		
		if val > max_val:
			max_val = val
			best_team = t
		elif val == max_val and not best_team.is_empty():
			var best_pts = int(best_team.get("Pontos", 0))
			if pts > best_pts:
				best_team = t
				
	return best_team

func _add_leader_stat_bar(parent: VBoxContainer, label_title: String, team: Dictionary, stat_key: String, color: Color) -> void:
	if team.is_empty():
		return

	var team_name = str(team.get("Nome", "-"))
	var stat_val: float = 0.0
	
	if stat_key == "Overall":
		var p_info = Database.get_team_power_index(team_name)
		stat_val = float(p_info.get("overall", 0.0))
	else:
		stat_val = float(team.get(stat_key, 0.0))

	var vbox_item = VBoxContainer.new()
	vbox_item.add_theme_constant_override("separation", 2)

	# Título do Quesito + Nome da Equipe Líder
	var lbl_info = Label.new()
	lbl_info.text = "%s: %s" % [label_title, team_name]
	lbl_info.add_theme_font_size_override("font_size", 13)
	lbl_info.add_theme_color_override("font_color", Color("#e2e8f0"))
	vbox_item.add_child(lbl_info)

	var hbox = HBoxContainer.new()

	var pbar = ProgressBar.new()
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbar.custom_minimum_size.y = 12
	pbar.min_value = 50
	pbar.max_value = 100
	pbar.value = stat_val
	pbar.show_percentage = false

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(3)
	pbar.add_theme_stylebox_override("fill", fill_style)

	hbox.add_child(pbar)

	var val_lbl = Label.new()
	val_lbl.text = " " + str(int(stat_val))
	val_lbl.custom_minimum_size.x = 24
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	hbox.add_child(val_lbl)

	vbox_item.add_child(hbox)
	parent.add_child(vbox_item)

func _add_stat_bar(parent: VBoxContainer, label_text: String, value: float, color: Color) -> void:
	var hbox = HBoxContainer.new()

	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 120
	lbl.add_theme_font_size_override("font_size", 10)
	hbox.add_child(lbl)

	var pbar = ProgressBar.new()
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbar.custom_minimum_size.y = 12
	pbar.min_value = 50
	pbar.max_value = 100
	pbar.value = value
	pbar.show_percentage = false

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(3)
	pbar.add_theme_stylebox_override("fill", fill_style)

	hbox.add_child(pbar)

	var val_lbl = Label.new()
	val_lbl.text = " " + str(int(value))
	val_lbl.add_theme_font_size_override("font_size", 10)
	hbox.add_child(val_lbl)

	parent.add_child(hbox)

func _build_news_content(parent: Control, track_name: String, gp_num: int) -> void:
	if parent == null: return
	for child in parent.get_children(): child.queue_free()

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)

	if Database.news_feed.size() == 0:
		var news_content = RichTextLabel.new()
		news_content.custom_minimum_size.y = 80
		news_content.add_theme_font_size_override("normal_font_size", 12)
		news_content.append_text("• Paddock movimentado para as preparações do GP " + str(gp_num) + " em " + track_name + ".\n")
		news_content.append_text("• Equipes finalizando ajustes técnicos e estratégias de pneus para a sessão de qualificação.\n")
		news_content.append_text("• Expectativas altas do público e da imprensa sobre a disputa de ritmo entre as equipes.")
		vbox.add_child(news_content)
	else:
		for item in Database.news_feed:
			var lbl = Label.new()
			lbl.text = "• " + str(item)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
			vbox.add_child(lbl)

	scroll.add_child(vbox)
	parent.add_child(scroll)

func _build_fast_sim_content(parent: Control) -> void:
	if parent == null: return
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)

	var hbox_controls = HBoxContainer.new()
	hbox_controls.add_theme_constant_override("separation", 8)

	var opt_type = OptionButton.new()
	opt_type.add_item("Corridas (GP)", 0)
	opt_type.add_item("Temporadas", 1)
	opt_type.custom_minimum_size.x = 110
	hbox_controls.add_child(opt_type)

	var spin_amount = SpinBox.new()
	spin_amount.min_value = 1
	spin_amount.max_value = 24
	spin_amount.value = 1
	spin_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_controls.add_child(spin_amount)

	vbox.add_child(hbox_controls)

	opt_type.item_selected.connect(func(index):
		if index == 0:
			spin_amount.max_value = 24
			spin_amount.value = clamp(spin_amount.value, 1, 24)
		else:
			spin_amount.max_value = 4
			spin_amount.value = clamp(spin_amount.value, 1, 4)
	)

	var btn_simulate = Button.new()
	btn_simulate.text = "▶ SIMULAR EM LOTE"
	btn_simulate.custom_minimum_size.y = 30
	btn_simulate.add_theme_color_override("font_color", Color("#ffffff"))
	
	btn_simulate.pressed.connect(func():
		var is_season_mode = (opt_type.selected == 1)
		var amount = int(spin_amount.value)
		_confirm_and_run_fast_simulation(is_season_mode, amount)
	)
	vbox.add_child(btn_simulate)

	parent.add_child(vbox)

# --- MODAL ESTILIZADO E LÓGICA DE SIMULAÇÃO ---

func _confirm_and_run_fast_simulation(by_season: bool, amount: int) -> void:
	_show_fast_sim_modal(by_season, amount)

func _show_fast_sim_modal(by_season: bool, amount: int) -> void:
	_close_sim_modal()

	sim_modal = ColorRect.new()
	sim_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	sim_modal.color = Color(0, 0, 0, 0.8)
	add_child(sim_modal)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	sim_modal.add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 220)

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
	vbox.add_theme_constant_override("separation", 14)

	var lbl_title = Label.new()
	lbl_title.text = "CONFIRMAR SIMULAÇÃO ACELERADA"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 15)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)

	var lbl_msg = Label.new()
	if by_season:
		lbl_msg.text = "Tem certeza de que deseja simular automaticamente %d temporada(s) completa(s)?" % amount
	else:
		lbl_msg.text = "Tem certeza de que deseja simular automaticamente %d corrida(s) (GP)?" % amount

	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 12)
	lbl_msg.add_theme_color_override("font_color", Color("#e2e8f0"))
	vbox.add_child(lbl_msg)

	var lbl_sub = Label.new()
	lbl_sub.text = "Essa ação irá processar os resultados e atualizações de forma acelerada."
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sub.add_theme_font_size_override("font_size", 11)
	lbl_sub.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(lbl_sub)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)

	var btn_confirm = Button.new()
	btn_confirm.text = "⚡ Sim, Simular"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 38
	btn_confirm.add_theme_font_size_override("font_size", 12)

	var style_confirm = StyleBoxFlat.new()
	style_confirm.bg_color = Color(0.8, 0.15, 0.15, 1.0)
	style_confirm.set_corner_radius_all(4)
	btn_confirm.add_theme_stylebox_override("normal", style_confirm)

	btn_confirm.pressed.connect(func():
		_close_sim_modal()
		_run_fast_simulation(by_season, amount)
	)

	var btn_cancel = Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.custom_minimum_size.y = 38
	btn_cancel.add_theme_font_size_override("font_size", 12)

	var style_cancel = StyleBoxFlat.new()
	style_cancel.bg_color = Color(0.18, 0.22, 0.30, 1.0)
	style_cancel.set_corner_radius_all(4)
	btn_cancel.add_theme_stylebox_override("normal", style_cancel)

	btn_cancel.pressed.connect(_close_sim_modal)

	btn_hbox.add_child(btn_confirm)
	btn_hbox.add_child(btn_cancel)
	vbox.add_child(btn_hbox)

	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

func _close_sim_modal() -> void:
	if is_instance_valid(sim_modal):
		sim_modal.queue_free()
		sim_modal = null

func _run_fast_simulation(by_season: bool, amount: int) -> void:
	if by_season:
		for s in range(amount):
			while Database.current_gp <= Database.tracks.size():
				Database.simulate_current_gp_fast()
				await get_tree().process_frame
			await _show_season_summary_and_wait()
	else:
		for g in range(amount):
			Database.simulate_current_gp_fast()
			if Database.current_gp > Database.tracks.size():
				await _show_season_summary_and_wait()
			await get_tree().process_frame

	build_ui()

func _show_season_summary_and_wait() -> void:
	var summary_view = preload("res://views/season_summary_view.gd").new()
	var continued := false
	summary_view.open_summary(self, Database.get_season_summary(), func():
		Database.end_season_and_advance_year()
		continued = true
	)
	while not continued:
		await get_tree().process_frame

# --- UTILITÁRIOS DA UI ---

func _create_stat_card(title: String, val: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(160, 38)
	var vbox = VBoxContainer.new()
	
	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.add_theme_font_size_override("font_size", 10)
	t_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(t_lbl)
	
	var v_lbl = Label.new()
	v_lbl.text = val
	v_lbl.add_theme_font_size_override("font_size", 14)
	v_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(v_lbl)
	
	card.add_child(vbox)
	return card

func _add_grid_header(grid: GridContainer, text: String, min_w: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#ef4444"))
	grid.add_child(lbl)

func _add_cell(grid: GridContainer, text: String, color: Color = Color("#ffffff")) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	grid.add_child(lbl)

func _add_micro_header(grid: GridContainer, text: String, min_w: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#ef4444"))
	grid.add_child(lbl)

func _add_micro_cell(grid: GridContainer, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	grid.add_child(lbl)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		build_ui()

func _get_sorted_drivers_for_market_panel() -> Array:
	var list = Database.drivers.duplicate()
	
	list.sort_custom(func(a, b):
		var p_a = _get_status_priority(str(a.get("Equipe", "")))
		var p_b = _get_status_priority(str(b.get("Equipe", "")))
		
		# 1. Agrupa por Status (Titular < Free Agent < Aposentado)
		if p_a != p_b:
			return p_a < p_b
			
		# 2. Se pertencerem ao mesmo grupo, ordena pelo maior Overall
		var ovr_a = int(a.get("Overall", a.get("Grau", 0)))
		var ovr_b = int(b.get("Overall", b.get("Grau", 0)))
		if ovr_a != ovr_b:
			return ovr_a > ovr_b
			
		return str(a.get("Nome", "")) < str(b.get("Nome", ""))
	)
	
	return list

func _get_status_priority(team_name: String) -> int:
	if team_name == "Aposentado":
		return 2 # Aposentados ficam obrigatoriamente no final
	elif team_name == "Free Agent" or team_name.is_empty():
		return 1 # Agentes livres ficam no meio
	return 0     # Titulares contratados no topo


func _populate_market_contract_box(grid_container: GridContainer) -> void:
	# Limpa itens anteriores se necessário
	for child in grid_container.get_children():
		child.queue_free()
		
	var sorted_drivers = _get_sorted_drivers_for_market_panel()
	
	for d in sorted_drivers:
		var team_name = str(d.get("Equipe", "Free Agent"))
		var contract_years = int(d.get("AnosContrato", 0))
		var morale = float(d.get("Moral", 75.0))
		
		# Label Piloto
		var lbl_name = Label.new()
		lbl_name.text = str(d.get("Nome", "Piloto"))
		grid_container.add_child(lbl_name)
		
		# Label Equipe
		var lbl_team = Label.new()
		lbl_team.text = team_name
		if team_name == "Aposentado":
			lbl_team.add_theme_color_override("font_color", Color("#64748b")) # Cinza
		elif team_name == "Free Agent":
			lbl_team.add_theme_color_override("font_color", Color("#38bdf8")) # Azul Claro
		else:
			lbl_team.add_theme_color_override("font_color", Color("#e2e8f0"))
		grid_container.add_child(lbl_team)
		
		# Label Contrato
		var lbl_contract = Label.new()
		if team_name == "Aposentado":
			lbl_contract.text = "-"
			lbl_contract.add_theme_color_override("font_color", Color("#64748b"))
		elif team_name == "Free Agent":
			lbl_contract.text = "Livre"
			lbl_contract.add_theme_color_override("font_color", Color("#38bdf8"))
		else:
			lbl_contract.text = str(contract_years) + (" ano" if contract_years == 1 else " anos")
			if contract_years == 1:
				lbl_contract.add_theme_color_override("font_color", Color("#eab308")) # Amarelo alertando último ano
			else:
				lbl_contract.add_theme_color_override("font_color", Color("#22c55e")) # Verde
		grid_container.add_child(lbl_contract)
		
		# Label Moral %
		var lbl_morale = Label.new()
		lbl_morale.text = str(snapped(morale, 1)) + "%"
		if morale >= 75.0:
			lbl_morale.add_theme_color_override("font_color", Color("#22c55e"))
		elif morale >= 40.0:
			lbl_morale.add_theme_color_override("font_color", Color("#eab308"))
		else:
			lbl_morale.add_theme_color_override("font_color", Color("#ef4444")) # Vermelho moral baixa
		grid_container.add_child(lbl_morale)

# --- CLASSE DO GRÁFICO DE EVOLUÇÃO DE PILOTOS ---
class DriversEvolutionChart extends Control:
	var hover_driver_info: String = ""
	var hover_pos: Vector2 = Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_check_hover(event.position)

	func _check_hover(mouse_p: Vector2) -> void:
		var rect_size = get_rect().size
		var margin_left = 42.0
		var margin_right = 30.0
		var margin_top = 22.0
		var margin_bottom = 28.0

		var plot_w = rect_size.x - margin_left - margin_right
		var plot_h = rect_size.y - margin_top - margin_bottom

		var total_tracks = Database.tracks.size() if Database.get("tracks") != null else 24
		var current_gp = clampi(int(Database.current_gp), 1, total_tracks)
		var max_visible_gps = max(10, current_gp - 1)
		var max_position_scale = 22.0

		var closest_info = ""
		var min_dist = 20.0

		for d in Database.drivers:
			var eq = str(d.get("Equipe", ""))
			if eq == "Free Agent" or eq == "Aposentado" or eq.is_empty():
				continue

			var history = d.get("HistoricoPosicoes", [])
			if history is Array and history.size() > 0:
				for i in range(history.size()):
					var champ_pos = clampi(int(history[i]), 1, 22)
					var norm_x = float(i) / float(max(1, max_visible_gps - 1))
					var norm_y = float(champ_pos - 1) / float(max_position_scale - 1.0)

					var px = margin_left + (norm_x * plot_w)
					var py = margin_top + (norm_y * plot_h)
					var point_pos = Vector2(px, py)

					var dist = mouse_p.distance_to(point_pos)
					if dist < min_dist:
						min_dist = dist
						closest_info = str(d.get("Nome", "Piloto")) + " (" + eq + ")\nGP " + str(i + 1) + ": " + str(champ_pos) + "º no Campeonato"

		if hover_driver_info != closest_info:
			hover_driver_info = closest_info
			hover_pos = mouse_p
			queue_redraw()

	func _draw() -> void:
		var rect_size = get_rect().size
		if rect_size.x <= 20 or rect_size.y <= 20:
			return

		draw_rect(Rect2(Vector2.ZERO, rect_size), Color("#101113"))

		var margin_left = 42.0
		var margin_right = 30.0
		var margin_top = 22.0
		var margin_bottom = 28.0

		var plot_w = rect_size.x - margin_left - margin_right
		var plot_h = rect_size.y - margin_top - margin_bottom

		# Eixo Y: Tabela de Posições (1º ao 22º)
		var grid_positions = [1, 5, 10, 15, 20, 22]
		var max_position_scale = 22.0

		for pos in grid_positions:
			var norm_y = float(pos - 1) / float(max_position_scale - 1.0)
			var y = margin_top + (norm_y * plot_h)
			draw_line(Vector2(margin_left, y), Vector2(rect_size.x - margin_right, y), Color(1, 1, 1, 0.08), 1.0)
			draw_string(ThemeDB.fallback_font, Vector2(6, y + 4), str(pos) + "º", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffffff"))

		# Eixo X: Marcadores dos GPs
		var total_tracks = Database.tracks.size() if Database.get("tracks") != null else 24
		var completed_gps = max(1, Database.current_gp - 1)
		var max_visible_gps = max(10, completed_gps)

		for i in range(max_visible_gps):
			var norm_x = float(i) / float(max(1, max_visible_gps - 1))
			var x = margin_left + (norm_x * plot_w)
			draw_line(Vector2(x, margin_top), Vector2(x, margin_top + plot_h), Color(1, 1, 1, 0.05), 1.0)
			draw_string(ThemeDB.fallback_font, Vector2(x - 10, rect_size.y - 6), "GP" + str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#cbd5e1"))

		# Cores das Equipes
		var colors = [
			Color("#3671c6"), Color("#e8002d"), Color("#ff8000"), Color("#6cd3bf"),
			Color("#229971"), Color("#0093cc"), Color("#64c4ff"), Color("#6692ff"),
			Color("#b6babd"), Color("#f50500"), Color("#f59e0b"), Color("#a855f7")
		]

		var d_idx = 0
		for d in Database.drivers:
			var eq = str(d.get("Equipe", ""))
			if eq == "Free Agent" or eq == "Aposentado" or eq.is_empty():
				continue

			var d_name = str(d.get("Nome", ""))
			var is_hovered = hover_driver_info.begins_with(d_name)
			var line_color = colors[d_idx % colors.size()]
			var line_alpha = 1.0 if is_hovered or hover_driver_info.is_empty() else 0.15
			var line_width = 3.5 if is_hovered else 1.8
			
			d_idx += 1
			var history = d.get("HistoricoPosicoes", [])

			if history is Array and history.size() > 0:
				var points = PackedVector2Array()
				for i in range(history.size()):
					var champ_pos = clampi(int(history[i]), 1, 22)
					var norm_x = float(i) / float(max(1, max_visible_gps - 1))
					var norm_y = float(champ_pos - 1) / float(max_position_scale - 1.0)

					var px = margin_left + (norm_x * plot_w)
					var py = margin_top + (norm_y * plot_h)
					points.append(Vector2(px, py))

				var draw_color = Color(line_color.r, line_color.g, line_color.b, line_alpha)
				if points.size() > 1:
					for i in range(points.size() - 1):
						draw_line(points[i], points[i + 1], draw_color, line_width, true)
						draw_circle(points[i], line_width + 0.8, draw_color)
					draw_circle(points[points.size() - 1], line_width + 1.2, draw_color)
				elif points.size() == 1:
					draw_circle(points[0], line_width + 1.2, draw_color)

		# Renderização da Tooltip de Destaque
		if not hover_driver_info.is_empty():
			var lines = hover_driver_info.split("\n")
			var max_line_len = 0
			for l in lines:
				if l.length() > max_line_len:
					max_line_len = l.length()

			var box_w = max_line_len * 7.2 + 20.0
			var box_h = lines.size() * 16.0 + 12.0
			var box_pos = hover_pos + Vector2(14, -box_h - 6)

			if box_pos.x + box_w > rect_size.x - 5:
				box_pos.x = hover_pos.x - box_w - 10.0
			if box_pos.x < margin_left + 5:
				box_pos.x = margin_left + 5.0

			if box_pos.y < 5:
				box_pos.y = hover_pos.y + 15.0

			draw_rect(Rect2(box_pos, Vector2(box_w, box_h)), Color("#0f172a"), true, -1, true)
			draw_rect(Rect2(box_pos, Vector2(box_w, box_h)), Color("#38bdf8"), false, 1.2)

			var y_off = box_pos.y + 16.0
			for l in lines:
				draw_string(ThemeDB.fallback_font, Vector2(box_pos.x + 10, y_off), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#ffffff"))
				y_off += 15.0

func _build_drivers_evolution_content(parent: Control) -> void:
	if parent == null: return
	for child in parent.get_children():
		child.queue_free()

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var total_tracks = Database.tracks.size() if Database.get("tracks") != null else 24
	var current_gp = clampi(int(Database.current_gp), 1, total_tracks)
	var min_width = max(550, current_gp * 50)

	var chart = DriversEvolutionChart.new()
	chart.custom_minimum_size = Vector2(min_width, 180)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL

	scroll.add_child(chart)
	parent.add_child(scroll)
