extends Control

var selected_year: int = 2026

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	selected_year = Database.current_year
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
	title.text = "HALL DA FAMA & HISTÓRICO DA F1"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ef4444"))
	main_vbox.add_child(title)
	
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color("#121417")
	p_style.content_margin_left = 12
	p_style.content_margin_right = 12
	p_style.content_margin_top = 10
	p_style.content_margin_bottom = 10
	
	# --- SEÇÃO 1: RECORDES GLOBAIS ---
	var stats_panel = PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", p_style)
	
	var stats_vbox = VBoxContainer.new()
	var stats_title = Label.new()
	stats_title.text = "📊 RECORDES MUNDIAIS & ESTATÍSTICAS GLOBAIS"
	stats_title.add_theme_color_override("font_color", Color("#38bdf8"))
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_vbox.add_child(stats_title)
	
	var stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 30)
	stats_grid.add_theme_constant_override("v_separation", 8)
	
	var most_wins_driver = Database.drivers[0] if Database.drivers.size() > 0 else {}
	for d in Database.drivers:
		if d.get("VitoriasCarreira", 0) > most_wins_driver.get("VitoriasCarreira", 0):
			most_wins_driver = d
			
	var most_titles_driver = Database.drivers[0] if Database.drivers.size() > 0 else {}
	for d in Database.drivers:
		if d.get("Titulos", 0) > most_titles_driver.get("Titulos", 0):
			most_titles_driver = d
			
	var d_wins_name = most_wins_driver.get("Nome", "Nenhum")
	var d_wins_cnt = str(most_wins_driver.get("VitoriasCarreira", 0)) + " Vitórias"
	var d_titles_name = most_titles_driver.get("Nome", "Nenhum")
	var d_titles_cnt = str(most_titles_driver.get("Titulos", 0)) + " Títulos"

	stats_grid.add_child(_create_stat_box("MAIOR VENCEDOR DA HISTÓRIA", d_wins_name, d_wins_cnt))
	stats_grid.add_child(_create_stat_box("MAIOR CAMPEÃO MUNDIAL", d_titles_name, d_titles_cnt))
	stats_grid.add_child(_create_stat_box("ERA ATUAL DO CAMPEONATO", "Ano " + str(Database.current_year), "GP " + str(Database.current_gp) + "/24"))
	
	stats_vbox.add_child(stats_grid)
	stats_panel.add_child(stats_vbox)
	main_vbox.add_child(stats_panel)
	
	# --- SEÇÃO 2: HALL DA FAMA ---
	var hall_panel = PanelContainer.new()
	hall_panel.add_theme_stylebox_override("panel", p_style)
	
	var hall_vbox = VBoxContainer.new()
	var hall_title = Label.new()
	hall_title.text = "👑 GALERIA DE CAMPEÕES MUNDIAIS"
	hall_title.add_theme_color_override("font_color", Color("#eab308"))
	hall_title.add_theme_font_size_override("font_size", 16)
	hall_vbox.add_child(hall_title)
	
	var hall_text = RichTextLabel.new()
	hall_text.custom_minimum_size.y = 60
	hall_text.scroll_following = true
	
	var champions = []
	if "champions_history" in Database:
		champions = Database.champions_history
		
	if champions.is_empty():
		hall_text.append_text("[color=#94a3b8]Nenhum campeão registrado no save atual. Conclua os 24 GPs da temporada.[/color]\n")
	else:
		for champ in champions:
			var c_ano = str(champ.get("ano", "-"))
			var c_piloto = str(champ.get("piloto", "-"))
			var c_equipe = str(champ.get("equipe", "-"))
			var c_pontos = str(champ.get("pontos", 0))
			hall_text.append_text("🏆 [b]Ano " + c_ano + "[/b]: " + c_piloto + " (" + c_equipe + ") - " + c_pontos + " pts\n")
			
	hall_vbox.add_child(hall_text)
	hall_panel.add_child(hall_vbox)
	main_vbox.add_child(hall_panel)
	
	# --- SEÇÃO 3: HISTÓRICO COM FILTRO ---
	var race_panel = PanelContainer.new()
	race_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	race_panel.add_theme_stylebox_override("panel", p_style)
	
	var race_vbox = VBoxContainer.new()
	
	var filter_hbox = HBoxContainer.new()
	var race_title = Label.new()
	race_title.text = "🏁 HISTÓRICO DE CORRIDAS"
	race_title.add_theme_color_override("font_color", Color("#ef4444"))
	race_title.add_theme_font_size_override("font_size", 16)
	filter_hbox.add_child(race_title)
	
	filter_hbox.add_child(VSeparator.new())
	
	var filter_lbl = Label.new()
	filter_lbl.text = "Filtrar Temporada:"
	filter_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	filter_hbox.add_child(filter_lbl)
	
	var opt = OptionButton.new()
	opt.add_item(str(Database.current_year) + " (Em andamento)", Database.current_year)
	
	if "full_season_archive" in Database:
		for y in Database.full_season_archive.keys():
			if int(y) != Database.current_year:
				opt.add_item("Temporada " + str(y), int(y))
				
	for i in range(opt.item_count):
		if opt.get_item_id(i) == selected_year:
			opt.selected = i
			break
			
	opt.item_selected.connect(func(idx):
		selected_year = opt.get_item_id(idx)
		build_ui()
	)
	filter_hbox.add_child(opt)
	race_vbox.add_child(filter_hbox)
	
	var race_scroll = ScrollContainer.new()
	race_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var race_list_vbox = VBoxContainer.new()
	race_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	race_list_vbox.add_theme_constant_override("separation", 6)
	
	var target_history = Database.race_history
	if "full_season_archive" in Database and selected_year != Database.current_year:
		target_history = Database.full_season_archive.get(selected_year, [])
		
	if target_history == null or target_history.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Nenhuma corrida concluída na temporada " + str(selected_year) + "."
		empty_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
		race_list_vbox.add_child(empty_lbl)
	else:
		for rh in target_history:
			if not (rh is Dictionary):
				continue

			var card = PanelContainer.new()
			var c_style = StyleBoxFlat.new()
			c_style.bg_color = Color("#1e2227")
			card.add_theme_stylebox_override("panel", c_style)
			
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 15)
			
			var gp_num_val = rh.get("gp_num", rh.get("gp_index", "-"))
			var track_name = rh.get("track", rh.get("Circuito", "GP"))

			var gp_lbl = Label.new()
			gp_lbl.text = "GP " + str(gp_num_val) + " - " + str(track_name)
			gp_lbl.add_theme_font_size_override("font_size", 14)
			gp_lbl.add_theme_color_override("font_color", Color("#38bdf8"))
			hbox.add_child(gp_lbl)
			
			hbox.add_child(VSeparator.new())
			
			# Suporte dual: Extrai tanto do array "podium" quanto das chaves diretas "winner", "second", "third"
			var p1 = "-"
			var p2 = "-"
			var p3 = "-"

			if rh.has("podium") and rh["podium"] is Array:
				var pod = rh["podium"]
				p1 = pod[0].get("Nome", "-") if pod.size() > 0 and pod[0] is Dictionary else "-"
				p2 = pod[1].get("Nome", "-") if pod.size() > 1 and pod[1] is Dictionary else "-"
				p3 = pod[2].get("Nome", "-") if pod.size() > 2 and pod[2] is Dictionary else "-"
			else:
				p1 = rh.get("winner", rh.get("Vencedor", "-"))
				p2 = rh.get("second", rh.get("Segundo", "-"))
				p3 = rh.get("third", rh.get("Terceiro", "-"))

			var pod_lbl = Label.new()
			pod_lbl.text = "🥇 " + str(p1) + " | 🥈 " + str(p2) + " | 🥉 " + str(p3)
			pod_lbl.add_theme_color_override("font_color", Color("#ffffff"))
			hbox.add_child(pod_lbl)
			
			card.add_child(hbox)
			race_list_vbox.add_child(card)
			
	race_scroll.add_child(race_list_vbox)
	race_vbox.add_child(race_scroll)
	race_panel.add_child(race_vbox)
	main_vbox.add_child(race_panel)

func _create_stat_box(title_txt: String, main_txt: String, sub_txt: String) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	
	var t_lbl = Label.new()
	t_lbl.text = title_txt
	t_lbl.add_theme_font_size_override("font_size", 11)
	t_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(t_lbl)
	
	var m_lbl = Label.new()
	m_lbl.text = main_txt
	m_lbl.add_theme_font_size_override("font_size", 16)
	m_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(m_lbl)
	
	var s_lbl = Label.new()
	s_lbl.text = sub_txt
	s_lbl.add_theme_font_size_override("font_size", 11)
	s_lbl.add_theme_color_override("font_color", Color("#22c55e"))
	vbox.add_child(s_lbl)
	
	return vbox
