extends Control

var time_passed: float = 0.0

func _process(delta: float) -> void:
	time_passed += delta * 1.2
	queue_redraw()

# Desenha o fundo escuro padrão do jogo
func _draw() -> void:
	var screen_size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#0c0d0e"))
	
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

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	Database.process_due_user_team_upgrades()
	build_ui()

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(main_vbox)
	add_child(margin)
	
	# -------------------------------------------------------------
	# PARTE SUPERIOR: DRIVER 1, DRIVER 2 E CARRO
	# -------------------------------------------------------------
	var top_hbox = HBoxContainer.new()
	top_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_hbox.size_flags_stretch_ratio = 1.0
	top_hbox.add_theme_constant_override("separation", 12)
	
	var my_drivers = Database.user_team.get("pilotos", [])
	
	# Card Driver 1
	var driver1_data = my_drivers[0] if my_drivers.size() > 0 else {}
	top_hbox.add_child(_build_driver_card("DRIVER 1", driver1_data, 0))
	
	# Card Driver 2
	var driver2_data = my_drivers[1] if my_drivers.size() > 1 else {}
	top_hbox.add_child(_build_driver_card("DRIVER 2", driver2_data, 1))
	
	# Card do Carro
	top_hbox.add_child(_build_car_card())
	
	main_vbox.add_child(top_hbox)
	
	# -------------------------------------------------------------
	# PARTE INFERIOR: P&D, PATROCÍNIOS E FINANÇAS
	# -------------------------------------------------------------
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_hbox.size_flags_stretch_ratio = 1.2
	bottom_hbox.add_theme_constant_override("separation", 12)
	
	# Módulo 1: P&D
	bottom_hbox.add_child(_build_rd_panel())
	
	# Módulo 2: Patrocínios
	bottom_hbox.add_child(_build_sponsors_panel())
	
	# Módulo 3: Finanças
	bottom_hbox.add_child(_build_finances_panel())
	
	main_vbox.add_child(bottom_hbox)

# =================================================================
# 1. CONSTRUTOR DOS CARDS DE PILOTO (DRIVER 1 & DRIVER 2)
# =================================================================
func _build_driver_card(title: String, driver_data: Dictionary, index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.add_theme_stylebox_override("panel", _get_card_style())
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	# Título da Box (Fonte ampliada de 13 para 15)
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.add_theme_font_size_override("font_size", 15)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	# Sub-Painel de Stats & Points
	var stats_panel = PanelContainer.new()
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner_style = StyleBoxFlat.new()
	inner_style.bg_color = Color("#1a1c23")
	inner_style.set_corner_radius_all(4)
	inner_style.content_margin_left = 8
	inner_style.content_margin_right = 8
	inner_style.content_margin_top = 8
	inner_style.content_margin_bottom = 8
	stats_panel.add_theme_stylebox_override("panel", inner_style)
	
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	
	if not driver_data.is_empty():
		var p_name = str(driver_data.get("Nome", "Piloto"))
		var ovr = int(driver_data.get("OVR", driver_data.get("Overall", 75)))
		var pace = int(driver_data.get("Ritmo", 75))
		var pts = int(driver_data.get("pontos", 0))
		var wins = int(driver_data.get("vitorias", 0))
		var podiums = int(driver_data.get("podios", 0))
		var contract = int(driver_data.get("contrato_anos", driver_data.get("AnosContrato", 1)))
		
		# Nome do Piloto (Fonte ampliada de 14 para 16)
		var l_name = Label.new()
		l_name.text = p_name
		l_name.add_theme_font_size_override("font_size", 16)
		l_name.add_theme_color_override("font_color", Color("#ffffff"))
		stats_vbox.add_child(l_name)
		
		# Atributos (Fonte ampliada de 11 para 13)
		var l_attr = Label.new()
		l_attr.text = "OVR: %d  |  Ritmo: %d" % [ovr, pace]
		l_attr.add_theme_font_size_override("font_size", 13)
		l_attr.add_theme_color_override("font_color", Color("#38bdf8"))
		stats_vbox.add_child(l_attr)
		
		var separator = HSeparator.new()
		stats_vbox.add_child(separator)
		
		# Título de Estatísticas (Fonte ampliada de 10 para 12)
		var l_stats_title = Label.new()
		l_stats_title.text = "Estatísticas da Temporada:"
		l_stats_title.add_theme_font_size_override("font_size", 12)
		l_stats_title.add_theme_color_override("font_color", Color("#94a3b8"))
		stats_vbox.add_child(l_stats_title)
		
		# Corpo de Estatísticas (Fonte ampliada de 11 para 13)
		var l_stats = Label.new()
		l_stats.text = "Pontos: %d pts\nVitórias: %d\nPódios: %d\nContrato: %d ano(s)" % [pts, wins, podiums, contract]
		l_stats.add_theme_font_size_override("font_size", 13)
		l_stats.add_theme_color_override("font_color", Color("#34d399"))
		stats_vbox.add_child(l_stats)
	else:
		var lbl_empty = Label.new()
		lbl_empty.text = "Sem piloto contratado"
		lbl_empty.add_theme_font_size_override("font_size", 13)
		lbl_empty.add_theme_color_override("font_color", Color("#64748b"))
		stats_vbox.add_child(lbl_empty)
		
	stats_panel.add_child(stats_vbox)
	vbox.add_child(stats_panel)
	
	# Botões: Demitir e Renovar (Fonte ampliada de 10 para 12)
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 6)
	
	var btn_fire = Button.new()
	btn_fire.text = "Demitir"
	btn_fire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_fire.add_theme_font_size_override("font_size", 12)
	btn_fire.pressed.connect(func(): _fire_driver(index))
	btn_hbox.add_child(btn_fire)
	
	var btn_renew = Button.new()
	btn_renew.text = "Renovar"
	btn_renew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_renew.add_theme_font_size_override("font_size", 12)
	btn_renew.pressed.connect(func(): _renew_driver(index))
	btn_hbox.add_child(btn_renew)
	
	vbox.add_child(btn_hbox)
	panel.add_child(vbox)
	return panel

# =================================================================
# 2. CONSTRUTOR DA BOX DO CARRO (ATRIBUTOS)
# =================================================================
func _build_car_card() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.3
	panel.add_theme_stylebox_override("panel", _get_card_style())
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	# Título da Box (Fonte ampliada de 13 para 15)
	var lbl_title = Label.new()
	lbl_title.text = "CARRO - DESEMPENHO E ATRIBUTOS"
	lbl_title.add_theme_font_size_override("font_size", 15)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var stats := Database.calculate_team_dev_stats(Database.user_team)
	var motor_val := float(stats.get("Motor", 80))
	var aero_val := float(stats.get("Aero", 80))
	var chassi_val := float(stats.get("Chassi", 80))
	var rel_val := float(stats.get("Confiabilidade", 80))
	var weight_val := float(stats.get("Peso", 778.0))

	_add_attribute_bar(vbox, "MOTOR", motor_val, Color("#ef4444"))
	_add_attribute_bar(vbox, "AERO", aero_val, Color("#38bdf8"))
	_add_attribute_bar(vbox, "CHASSI", chassi_val, Color("#f59e0b"))
	_add_attribute_bar(vbox, "CONFIABILIDADE", rel_val, Color("#22c55e"))
	_add_weight_attribute_bar(vbox, "⚖️ PESO", weight_val)
	
	panel.add_child(vbox)
	return panel

func _add_attribute_bar(parent: Control, attr_name: String, val: float, color: Color) -> void:
	var hbox = HBoxContainer.new()
	
	# Nome do Atributo (Fonte ampliada de 10 para 12 e largura de 130 para 150)
	var lbl = Label.new()
	lbl.text = attr_name
	lbl.custom_minimum_size.x = 150
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#ffffff"))
	hbox.add_child(lbl)
	
	var progress = ProgressBar.new()
	progress.min_value = 50.0
	progress.max_value = 99.0
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.custom_minimum_size.y = 12
	progress.show_percentage = false
	progress.value = val
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("fill", fill_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#1e293b")
	bg_style.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("background", bg_style)
	
	hbox.add_child(progress)
	
	# Valor do Atributo (Fonte ampliada de 10 para 12)
	var val_lbl = Label.new()
	val_lbl.text = "%.1f" % val
	val_lbl.custom_minimum_size.x = 40
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", color)
	hbox.add_child(val_lbl)
	
	parent.add_child(hbox)

func _add_weight_attribute_bar(parent: Control, attr_name: String, weight: float) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = attr_name
	label.custom_minimum_size.x = 150
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#ffffff"))
	hbox.add_child(label)

	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.value = clampf(100.0 - ((weight - 768.0) * 2.5), 15.0, 100.0)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.custom_minimum_size.y = 12
	progress.show_percentage = false
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#38bdf8") if weight <= 778.0 else Color("#f97316")
	fill_style.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("fill", fill_style)
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color("#1e293b")
	background_style.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("background", background_style)
	hbox.add_child(progress)

	var value_label := Label.new()
	value_label.text = "%.1f kg" % weight
	value_label.custom_minimum_size.x = 55
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", fill_style.bg_color)
	hbox.add_child(value_label)
	parent.add_child(hbox)

# =================================================================
# 3. MÓDULO DE P&D (PESQUISA & DESENVOLVIMENTO)
# =================================================================
func _build_rd_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _get_card_style())
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# Título da Box (Fonte ampliada de 13 para 15)
	var lbl_title = Label.new()
	lbl_title.text = "P. E D. (DESENVOLVIMENTO)"
	lbl_title.add_theme_font_size_override("font_size", 15)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	# Botão de Seleção (Fonte ampliada de 11 para 13)
	var btn_select = Button.new()
	btn_select.text = "🛠️ ESCOLHER MELHORIA"
	btn_select.custom_minimum_size.y = 35
	btn_select.add_theme_font_size_override("font_size", 13)
	var available_slots := false
	for slot in Database.ensure_user_team_rd_slots():
		if not slot is Dictionary or slot.is_empty():
			available_slots = true
			break
	btn_select.disabled = not available_slots or float(Database.user_team.get("orcamento", 0.0)) < Database.PLAYER_RD_COST / 1_000_000.0
	btn_select.pressed.connect(_on_select_upgrade_pressed)
	vbox.add_child(btn_select)
	
	var rd_slots := Database.ensure_user_team_rd_slots()
	var has_available_slot := false
	for slot in rd_slots:
		if not slot is Dictionary or slot.is_empty():
			has_available_slot = true
			break
	var available_cash := float(Database.user_team.get("orcamento", 0.0))
	btn_select.disabled = not has_available_slot or available_cash < Database.PLAYER_RD_COST / 1_000_000.0
	if not has_available_slot:
		btn_select.tooltip_text = "Todos os slots de desenvolvimento estão ocupados."
	elif available_cash < Database.PLAYER_RD_COST / 1_000_000.0:
		btn_select.tooltip_text = "Caixa insuficiente para iniciar uma melhoria."
	
	for i in range(3):
		var slot_data: Dictionary = rd_slots[i] if i < rd_slots.size() and rd_slots[i] is Dictionary else {}
		vbox.add_child(_create_slot_card("UPDATE %d" % (i + 1), slot_data))
		
	panel.add_child(vbox)
	return panel

func _create_slot_card(title_slot: String, data: Dictionary) -> PanelContainer:
	var slot_panel = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#1a1c23")
	st.set_corner_radius_all(4)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	slot_panel.add_theme_stylebox_override("panel", st)
	
	var vbox = VBoxContainer.new()
	
	# Rótulo do Slot (Fonte ampliada de 10 para 12)
	var l_head = Label.new()
	if data.is_empty():
		l_head.text = "%s: Slot disponível" % title_slot
	else:
		var attribute := str(data.get("atributo", "Melhoria"))
		var amount := float(data.get("valor", 0.0))
		var amount_text := "-%.2f kg" % amount if attribute == "Peso" else "+%.1f" % amount
		l_head.text = "%s: %s %s" % [title_slot, attribute, amount_text]
	l_head.add_theme_font_size_override("font_size", 12)
	l_head.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(l_head)
	
	var progress = ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 100.0
	progress.custom_minimum_size.y = 8
	progress.show_percentage = false
	progress.value = float(data.get("progresso", 0.0))
	
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("#38bdf8") if progress.value > 0 else Color("#475569")
	fill.set_corner_radius_all(2)
	progress.add_theme_stylebox_override("fill", fill)
	vbox.add_child(progress)
	var status := Label.new()
	if data.is_empty():
		status.text = "Nenhuma melhoria selecionada"
	else:
		status.text = "Pronta na etapa %d • %d | $%.1fM" % [
			int(data.get("pronta_etapa", 1)),
			int(data.get("pronta_ano", Database.current_year)),
			float(data.get("custo", 0.0))
		]
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(status)
	
	slot_panel.add_child(vbox)
	return slot_panel

# =================================================================
# 4. MÓDULO DE PATROCÍNIOS
# =================================================================
func _build_sponsors_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _get_card_style())
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# Título da Box (Fonte ampliada de 13 para 15)
	var lbl_title = Label.new()
	lbl_title.text = "PATROCÍNIOS"
	lbl_title.add_theme_font_size_override("font_size", 15)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var sponsors: Array = Database.user_team.get("patrocinadores", [])
	
	var total_per_year: float = 0.0
	
	for i in range(3):
		var sp: Dictionary = sponsors[i] if i < sponsors.size() and sponsors[i] is Dictionary else {}
		var sponsor_name := str(sp.get("nome", "Slot vazio"))
		var contract_text := _get_sponsor_contract_text(sp)
		if str(sp.get("tipo", "")) == "Temporada":
			total_per_year += float(sp.get("valor_temporada", sp.get("valor_ano", 0.0)))
		
		var card = PanelContainer.new()
		var st = StyleBoxFlat.new()
		st.bg_color = Color("#1a1c23")
		st.set_corner_radius_all(4)
		st.content_margin_left = 6
		st.content_margin_right = 6
		st.content_margin_top = 6
		st.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", st)
		
		var cvbox = VBoxContainer.new()
		
		# Nome do Patrocinador (Fonte ampliada de 10 para 12)
		var l_sname = Label.new()
		l_sname.text = "SLOT %d: %s" % [i + 1, sponsor_name]
		l_sname.add_theme_font_size_override("font_size", 12)
		l_sname.add_theme_color_override("font_color", Color("#ffffff"))
		cvbox.add_child(l_sname)
		
		# Valor Anual (Fonte ampliada de 10 para 12)
		var l_sval = Label.new()
		l_sval.text = contract_text
		l_sval.add_theme_font_size_override("font_size", 12)
		l_sval.add_theme_color_override("font_color", Color("#34d399") if not sp.is_empty() else Color("#64748b"))
		cvbox.add_child(l_sval)
		if not sp.is_empty():
			var duration := int(sp.get("contrato_anos", sp.get("duracao", 0)))
			if duration > 0:
				var duration_label := Label.new()
				duration_label.text = "Contrato: %d temporada(s)" % duration
				duration_label.add_theme_font_size_override("font_size", 10)
				duration_label.add_theme_color_override("font_color", Color("#94a3b8"))
				cvbox.add_child(duration_label)
		
		card.add_child(cvbox)
		vbox.add_child(card)
		
	# Total por Ano (Fonte ampliada de 12 para 14)
	var l_total = Label.new()
	l_total.text = "RECEITA FIXA POR TEMPORADA: +$%.1fM" % total_per_year
	l_total.add_theme_font_size_override("font_size", 14)
	l_total.add_theme_color_override("font_color", Color("#34d399"))
	vbox.add_child(l_total)
	
	panel.add_child(vbox)
	return panel

# =================================================================
# 5. MÓDULO DE FINANÇAS
# =================================================================
func _build_finances_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _get_card_style())
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# Título da Box (Fonte ampliada de 13 para 15)
	var lbl_title = Label.new()
	lbl_title.text = "FINANÇAS DA TEMPORADA"
	lbl_title.add_theme_font_size_override("font_size", 15)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var fin_vbox = VBoxContainer.new()
	fin_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fin_vbox.add_theme_constant_override("separation", 4)
	
	# Extrato com fontes ampliadas de 10 para 12
	_add_finance_entry(fin_vbox, "🟢 Patrocínios Acumulados", "+$26.0M", Color("#34d399"))
	_add_finance_entry(fin_vbox, "🔴 Melhorias (P&D Desenvolvido)", "-$8.5M", Color("#ef4444"))
	_add_finance_entry(fin_vbox, "🔴 Quebras & Reparos (DNFs)", "-$2.1M", Color("#ef4444"))
	_add_finance_entry(fin_vbox, "🔴 Salários da Equipe", "-$5.0M", Color("#ef4444"))
	
	scroll.add_child(fin_vbox)
	vbox.add_child(scroll)
	
	var current_cash := float(Database.user_team.get("orcamento", Database.user_team.get("budget", 0.0)))
	
	var cash_panel = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#1a1c23")
	st.border_width_left = 3
	st.border_color = Color("#34d399")
	st.set_corner_radius_all(4)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	cash_panel.add_theme_stylebox_override("panel", st)
	
	var cash_hbox = HBoxContainer.new()
	
	# Rótulo do Caixa (Fonte ampliada de 11 para 13)
	var l_caixa_tag = Label.new()
	l_caixa_tag.text = "CAIXA DISPONÍVEL:"
	l_caixa_tag.add_theme_font_size_override("font_size", 13)
	l_caixa_tag.add_theme_color_override("font_color", Color("#ffffff"))
	cash_hbox.add_child(l_caixa_tag)
	
	# Valor do Caixa (Fonte ampliada de 12 para 15)
	var l_caixa_val = Label.new()
	l_caixa_val.text = " $%.1fM" % current_cash
	l_caixa_val.add_theme_font_size_override("font_size", 15)
	l_caixa_val.add_theme_color_override("font_color", Color("#34d399"))
	cash_hbox.add_child(l_caixa_val)
	
	cash_panel.add_child(cash_hbox)
	vbox.add_child(cash_panel)

	var capital_button := Button.new()
	if Database.can_inject_team_capital():
		capital_button.text = "💰 INJEÇÃO DE CAPITAL ($10M–$50M)"
		capital_button.pressed.connect(_open_capital_injection)
	else:
		var available_year := int(Database.user_team.get("injecao_capital_ano", Database.current_year)) + 3
		capital_button.text = "Injeção de Capital — disponível na temporada %d" % available_year
		capital_button.disabled = true
	capital_button.custom_minimum_size.y = 36
	vbox.add_child(capital_button)
	
	panel.add_child(vbox)
	return panel

func _add_finance_entry(parent: Control, label_txt: String, val_txt: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	
	var lbl = Label.new()
	lbl.text = label_txt
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	hbox.add_child(lbl)
	
	var val = Label.new()
	val.text = val_txt
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", color)
	hbox.add_child(val)
	
	parent.add_child(hbox)

func _get_sponsor_contract_text(sponsor: Dictionary) -> String:
	if sponsor.is_empty():
		return "Sem contrato"
	var sponsor_type := str(sponsor.get("tipo", ""))
	match sponsor_type:
		"Temporada":
			var amount := float(sponsor.get("valor_temporada", sponsor.get("valor_ano", 0.0)))
			return "$%.1fM por temporada (adiantado)" % amount
		"Por Corrida":
			return "$%.1fM por GP" % float(sponsor.get("valor_corrida", 0.0))
		"Por Ponto":
			return "$%.2fM por ponto marcado" % float(sponsor.get("valor_ponto", 0.0))
		_:
			if sponsor.has("valor_ano"):
				return "$%.1fM por temporada" % float(sponsor.get("valor_ano", 0.0))
			return str(sponsor.get("desc", "Contrato ativo"))

# =================================================================
# FUNÇÕES AUXILIARES E EVENTOS
# =================================================================
func _get_card_style() -> StyleBoxFlat:
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#121316")
	st.set_corner_radius_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	return st

func _fire_driver(index: int) -> void:
	var my_drivers = Database.user_team.get("pilotos", [])
	if index < my_drivers.size():
		my_drivers[index]["Equipe"] = "Free Agent"
		my_drivers.remove_at(index)
		build_ui()

func _renew_driver(index: int) -> void:
	var my_drivers = Database.user_team.get("pilotos", [])
	if index < my_drivers.size():
		var c = int(my_drivers[index].get("contrato_anos", 1))
		my_drivers[index]["contrato_anos"] = c + 1
		build_ui()

func _on_select_upgrade_pressed() -> void:
	var slots := Database.ensure_user_team_rd_slots()
	for slot in slots:
		if not slot is Dictionary or slot.is_empty():
			_open_upgrade_selection()
			return

func _open_upgrade_selection() -> void:
	var dialog := Window.new()
	dialog.title = "🛠️ Escolher melhoria"
	dialog.size = Vector2i(640, 500)
	dialog.exclusive = true
	dialog.close_requested.connect(func(): dialog.queue_free())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var info := Label.new()
	info.text = "Selecione uma melhoria. Cada projeto custa $%.1fM e leva 3 etapas." % (Database.PLAYER_RD_COST / 1_000_000.0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(info)

	var tracks_per_season := maxi(1, Database.tracks.size())
	var ready_absolute_gp := Database.current_gp + 3
	var ready_year := Database.current_year + int((ready_absolute_gp - 1) / tracks_per_season)
	var ready_gp := ((ready_absolute_gp - 1) % tracks_per_season) + 1
	var ready_label := Label.new()
	ready_label.text = "Previsão: etapa %d de %d." % [ready_gp, ready_year]
	ready_label.add_theme_color_override("font_color", Color("#38bdf8"))
	layout.add_child(ready_label)

	var options := [
		{"atributo": "Motor", "valor": 1.0, "texto": "Motor +1.0"},
		{"atributo": "Aero", "valor": 1.0, "texto": "Aerodinâmica +1.0"},
		{"atributo": "Chassi", "valor": 1.0, "texto": "Chassi +1.0"},
		{"atributo": "Confiabilidade", "valor": 1.0, "texto": "Confiabilidade +1.0"},
		{"atributo": "Peso", "valor": 0.3, "texto": "Redução de peso: −0.30 kg"}
	]
	for option in options:
		var selection := (option as Dictionary).duplicate()
		var button := Button.new()
		button.text = "%s  |  $%.1fM  |  pronta na etapa %d" % [
			str(selection["texto"]),
			Database.PLAYER_RD_COST / 1_000_000.0,
			ready_gp
		]
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = float(Database.user_team.get("orcamento", 0.0)) < Database.PLAYER_RD_COST / 1_000_000.0
		var team_stats := Database.calculate_team_dev_stats(Database.user_team)
		if str(selection["atributo"]) == "Peso":
			button.disabled = button.disabled or float(team_stats.get("Peso", 778.0)) <= 768.0
		elif int(team_stats.get(str(selection["atributo"]), 80)) >= 99:
			button.disabled = true
		button.pressed.connect(func(): _start_team_upgrade(selection, dialog))
		layout.add_child(button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.custom_minimum_size.y = 36
	cancel_button.pressed.connect(func(): dialog.queue_free())
	layout.add_child(cancel_button)
	dialog.add_child(margin)
	add_child(dialog)
	dialog.popup_centered()

func _start_team_upgrade(option: Dictionary, dialog: Window) -> void:
	if not Database.schedule_user_team_upgrade(str(option.get("atributo", "")), float(option.get("valor", 0.0))):
		push_warning("Não foi possível iniciar a melhoria: verifique os slots disponíveis e o caixa da equipe.")
		return
	dialog.queue_free()
	build_ui()

func _open_capital_injection() -> void:
	if not Database.can_inject_team_capital():
		return
	var dialog := Window.new()
	dialog.title = "💰 Injeção de Capital"
	dialog.size = Vector2i(460, 260)
	dialog.exclusive = true
	dialog.close_requested.connect(func(): dialog.queue_free())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var description := Label.new()
	description.text = "Escolha um aporte entre $10M e $50M. A próxima injeção ficará disponível após três temporadas."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)

	var amount_input := SpinBox.new()
	amount_input.min_value = 10.0
	amount_input.max_value = 50.0
	amount_input.step = 1.0
	amount_input.value = 10.0
	amount_input.suffix = "M"
	layout.add_child(amount_input)

	var action_row := HBoxContainer.new()
	var confirm_button := Button.new()
	confirm_button.text = "Injetar capital"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(func():
		if not Database.inject_team_capital(amount_input.value):
			push_warning("A injeção não foi realizada. Verifique o valor e a disponibilidade do recurso.")
			return
		dialog.queue_free()
		build_ui()
	)
	action_row.add_child(confirm_button)
	var cancel_button := Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(func(): dialog.queue_free())
	action_row.add_child(cancel_button)
	layout.add_child(action_row)

	dialog.add_child(margin)
	add_child(dialog)
	dialog.popup_centered()
