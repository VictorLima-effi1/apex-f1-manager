extends Control

var time_passed: float = 0.0

# Variáveis para armazenar o estado de ordenação das tabelas
var sort_column_active: String = "Overall"
var sort_ascending_active: bool = false

var sort_column_free: String = "Overall"
var sort_ascending_free: bool = false

func _process(delta: float) -> void:
	time_passed += delta * 1.2
	queue_redraw()

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
	build_ui()

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)
	
	# 1. Painel Superior de Gestão da Sua Equipe
	if Database.get("game_mode") == "manager" or Database.user_team != null:
		_build_my_team_contracts_panel(main_vbox)
	
	# Separar pilotos em dois grupos
	var active_drivers: Array = []
	var free_agents: Array = []
	
	for d in Database.drivers:
		var team = str(d.get("Equipe", "Free Agent"))
		if team == "Free Agent" or team.is_empty() or team == "Aposentado":
			free_agents.append(d)
		else:
			active_drivers.append(d)
			
	# Ordenação Dinâmica das Listas
	_sort_driver_list(active_drivers, sort_column_active, sort_ascending_active)
	_sort_driver_list(free_agents, sort_column_free, sort_ascending_free)

	# Container Lado a Lado para as Tabelas
	var tables_hbox = HBoxContainer.new()
	tables_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tables_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tables_hbox.add_theme_constant_override("separation", 12)
	
	# Tabela 1: Titulares
	var active_section = _build_table_section("🏎️ PILOTOS COM EQUIPE (TITULARES)", active_drivers, true)
	active_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tables_hbox.add_child(active_section)
	
	# Tabela 2: Free Agents
	var free_section = _build_table_section("📋 AGENTES LIVRES (FREE AGENTS)", free_agents, false)
	free_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tables_hbox.add_child(free_section)
	
	main_vbox.add_child(tables_hbox)
	
	# 3. Painel Inferior: Histórico de Transferências
	_build_transfer_history_panel(main_vbox)

# Lógica universal de ordenação por coluna
func _sort_driver_list(list: Array, column_name: String, ascending: bool) -> void:
	list.sort_custom(func(a, b):
		var val_a = a.get(column_name, 0)
		var val_b = b.get(column_name, 0)
		
		# Trata textos (Nome, Equipe) e números (Overall, Idade, Ritmo)
		if typeof(val_a) == TYPE_STRING:
			if ascending:
				return str(val_a).nocasecmp_to(str(val_b)) < 0
			else:
				return str(val_a).nocasecmp_to(str(val_b)) > 0
		else:
			if ascending:
				return float(val_a) < float(val_b)
			else:
				return float(val_a) > float(val_b)
	)

# Constrói o painel compacto com cabeçalhos clicáveis
func _build_table_section(section_title: String, driver_list: Array, is_active_table: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	var st = StyleBoxFlat.new()
	# Cor idêntica aos painéis do Dashboard (Grafite bem escuro)
	st.bg_color = Color("#121316")
	st.set_corner_radius_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", st)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	var lbl_title = Label.new()
	lbl_title.text = section_title
	lbl_title.add_theme_font_size_override("font_size", 13)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444") if is_active_table else Color("#38bdf8"))
	vbox.add_child(lbl_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	_add_sortable_header(header, "PILOTO", "Nome", 100, is_active_table)
	_add_sortable_header(header, "IDADE", "Idade", 40, is_active_table)
	_add_sortable_header(header, "OVR", "Overall", 40, is_active_table)
	_add_sortable_header(header, "RITMO", "Ritmo", 40, is_active_table)
	_add_sortable_header(header, "MORAL", "Moral", 45, is_active_table)
	if is_active_table:
		_add_sortable_header(header, "EQUIPE", "Equipe", 90, true)
		_add_header_text(header, "CONTRATO", 65)
	else:
		_add_header_text(header, "SITUAÇÃO", 110)
	var can_negotiate := str(Database.game_mode) == "manager"
	if can_negotiate:
		_add_header_text(header, "AÇÃO", 92)
	rows.add_child(header)

	for d in driver_list:
		var d_name := str(d.get("Nome", "Desconhecido"))
		var age = str(d.get("Idade", 25))
		var overall = str(d.get("Overall", 75))
		var pace = str(d.get("Ritmo", 75))
		var morale_val = int(d.get("Moral", 75))
		var team := str(d.get("Equipe", "Free Agent"))
		
		var c_years: int = int(d.get("AnosContrato", 0))
		var years_str: String = "-"
		if team != "Free Agent" and team != "Aposentado":
			years_str = str(c_years) + (" ano" if c_years == 1 else " anos")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_add_market_cell(row, d_name, Color("#ffffff"), 100)
		_add_market_cell(row, age, Color("#94a3b8"), 40)
		_add_market_cell(row, overall, Color("#38bdf8"), 40)
		_add_market_cell(row, pace, Color("#94a3b8"), 40)
		
		var morale_color = Color("#22c55e")
		if morale_val < 40: morale_color = Color("#ef4444")
		elif morale_val < 70: morale_color = Color("#f59e0b")
		_add_market_cell(row, str(morale_val) + "%", morale_color, 45)
		
		if is_active_table:
			_add_market_cell(row, team, Color("#ffffff"), 90)
			var contract_color = Color("#f59e0b") if c_years <= 1 else Color("#22c55e")
			_add_market_cell(row, years_str, contract_color, 65)
		else:
			var situation = _get_driver_situation(d_name, team)
			_add_market_cell(row, situation["text"], Color(situation["color"]), 110)
		if can_negotiate:
			var action_button := Button.new()
			var is_player_driver := _is_player_team(str(d.get("Equipe", "")))
			action_button.text = "Renovar" if is_player_driver else "Negociar"
			action_button.tooltip_text = "Abrir negociação de contrato"
			action_button.custom_minimum_size = Vector2(92, 26)
			action_button.add_theme_font_size_override("font_size", 11)
			
			# Conecta o clique diretamente ao modal de negociação sem interferência de hover
			action_button.pressed.connect(func(): _on_negotiate_driver_pressed(d))
			row.add_child(action_button)
		rows.add_child(row)
			
	scroll.add_child(rows)
	vbox.add_child(scroll)
	panel.add_child(vbox)
	
	return panel

# Cria um botão de cabeçalho clicável para ordenar
func _add_sortable_header(grid: Control, text: String, column_key: String, min_w: float, is_active_table: bool) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size.x = min_w
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color("#ef4444"))
	
	btn.pressed.connect(func():
		if is_active_table:
			if sort_column_active == column_key:
				sort_ascending_active = !sort_ascending_active
			else:
				sort_column_active = column_key
				sort_ascending_active = false
		else:
			if sort_column_free == column_key:
				sort_ascending_free = !sort_ascending_free
			else:
				sort_column_free = column_key
				sort_ascending_free = false
		build_ui()
	)
	grid.add_child(btn)

func _add_header_text(grid: Control, text: String, min_w: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color("#ef4444"))
	grid.add_child(lbl)

func _add_market_cell(row: Control, text: String, color: Color, min_width: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_width
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)

func _is_player_team(team_name: String) -> bool:
	var manager_team := str(Database.user_team.get("nome", Database.user_team.get("Nome", "")))
	if manager_team.is_empty():
		manager_team = str(Database.selected_manager_team.get("Nome", Database.selected_manager_team.get("nome", "")))
	return not manager_team.is_empty() and team_name.strip_edges().to_lower() == manager_team.strip_edges().to_lower()

func _on_negotiate_driver_pressed(target_driver: Dictionary) -> void:
	var manager_team := str(Database.user_team.get("nome", Database.user_team.get("Nome", "")))
	if manager_team.is_empty():
		manager_team = str(Database.selected_manager_team.get("Nome", Database.selected_manager_team.get("nome", "")))
	if manager_team.is_empty():
		return
	if _is_player_team(str(target_driver.get("Equipe", ""))):
		_open_contract_negotiation(target_driver, manager_team, "")
		return
	var roster := Database.get_team_drivers(manager_team)
	if roster.is_empty():
		roster = Database.user_team.get("pilotos", [])
	if roster.size() >= 2:
		_show_driver_release_choice(target_driver, manager_team, roster)
	else:
		_open_contract_negotiation(target_driver, manager_team, "")

func _show_driver_release_choice(target_driver: Dictionary, manager_team: String, roster: Array) -> void:
	var dialog := Window.new()
	dialog.title = "Escolher piloto para liberar"
	dialog.size = Vector2i(430, 210)
	dialog.exclusive = true
	dialog.close_requested.connect(func(): dialog.queue_free())
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	var prompt := Label.new()
	prompt.text = "Sua equipe já tem dois pilotos. Escolha quem deixará a vaga para %s." % str(target_driver.get("Nome", "o novo piloto"))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(prompt)
	var choice := OptionButton.new()
	for index in range(roster.size()):
		choice.add_item(str(roster[index].get("Nome", "Piloto")), index)
	layout.add_child(choice)
	var actions := HBoxContainer.new()
	var confirm := Button.new()
	confirm.text = "Continuar para negociação"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(func():
		var selected_index := choice.get_selected_id()
		var release_name := str(roster[selected_index].get("Nome", "")) if selected_index >= 0 and selected_index < roster.size() else ""
		dialog.queue_free()
		_open_contract_negotiation(target_driver, manager_team, release_name)
	)
	actions.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.pressed.connect(func(): dialog.queue_free())
	actions.add_child(cancel)
	layout.add_child(actions)
	dialog.add_child(layout)
	add_child(dialog)
	dialog.popup_centered()

func _open_contract_negotiation(target_driver: Dictionary, manager_team: String, release_name: String) -> void:
	var renewal := _is_player_team(str(target_driver.get("Equipe", "")))
	var dialog_script = preload("res://views/contract_negotiation_dialog.gd")
	var dialog = dialog_script.new()
	dialog.open_for_driver(self, target_driver, manager_team, func(accepted: Dictionary, salary: float, years: int, _status: String):
		if not renewal:
			_complete_market_signing(accepted, manager_team, release_name, salary, years)
		else:
			accepted["AnosContrato"] = years
			accepted["contrato_anos"] = years
			accepted["salario"] = salary
			var database_driver := Database._get_driver_by_name(str(accepted.get("Nome", "")))
			if not database_driver.is_empty():
				database_driver["AnosContrato"] = years
				database_driver["salario"] = salary
		call_deferred("build_ui")
	, renewal)

func _complete_market_signing(driver: Dictionary, manager_team: String, release_name: String, salary: float, years: int) -> void:
	var old_team := str(driver.get("Equipe", ""))
	var roster: Array = Database.user_team.get("pilotos", [])
	if not release_name.is_empty():
		var departing := Database._get_driver_by_name(release_name)
		if not departing.is_empty():
			departing["Equipe"] = "Free Agent"
			departing["AnosContrato"] = 0
			departing["contrato_anos"] = 0
			departing["Moral"] = 50.0
		for index in range(roster.size() - 1, -1, -1):
			if str(roster[index].get("Nome", "")).to_lower() == release_name.to_lower():
				roster.remove_at(index)

	driver["Equipe"] = manager_team
	driver["AnosContrato"] = years
	driver["contrato_anos"] = years
	driver["salario"] = salary
	if not roster.any(func(existing): return str(existing.get("Nome", "")).to_lower() == str(driver.get("Nome", "")).to_lower()):
		roster.append(driver)
	Database.user_team["pilotos"] = roster
	if old_team != "Free Agent" and old_team != "Aposentado" and old_team != manager_team:
		Database._auto_fill_team_seat(old_team)
	Database.log_transfer_event("✍️ %s assinou com %s por %d ano(s)." % [str(driver.get("Nome", "Piloto")), manager_team, years], "Contratação", str(driver.get("Nome", "")), manager_team, int(driver.get("Idade", 25)), years)

# Painel Inferior: Cards de Histórico de Transferências
func _build_transfer_history_panel(parent_container: Control) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.y = 125
	
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#121316")
	st.set_corner_radius_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", st)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	var lbl_title = Label.new()
	lbl_title.text = "🔄 HISTÓRICO DE TRANSFERÊNCIAS RECENTES"
	lbl_title.add_theme_font_size_override("font_size", 12)
	lbl_title.add_theme_color_override("font_color", Color("#38bdf8"))
	vbox.add_child(lbl_title)
	
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 10)
	
	var history_list = Database.get("transfer_history")
	if history_list == null or history_list.is_empty():
		history_list = [
			{"nome": "Lewis Hamilton", "idade": 41, "anos": 2, "equipe": "Ferrari"},
			{"nome": "Carlos Sainz", "idade": 32, "anos": 2, "equipe": "Williams"},
			{"nome": "Nico Hülkenberg", "idade": 39, "anos": 1, "equipe": "Audi"}
		]
		
	for transfer in history_list:
		var card = _create_transfer_card(transfer)
		cards_hbox.add_child(card)
		
	scroll.add_child(cards_hbox)
	vbox.add_child(scroll)
	panel.add_child(vbox)
	parent_container.add_child(panel)

# Cria cada Card Individual do Histórico
func _create_transfer_card(data: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 82)
	
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#1a1c23")
	st.set_corner_radius_all(4)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", st)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	
	var l_name = Label.new()
	l_name.text = str(data.get("nome", data.get("piloto", "Piloto")))
	l_name.add_theme_font_size_override("font_size", 11)
	l_name.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(l_name)
	
	var l_info = Label.new()
	l_info.text = "Idade: %d yrs | Contrato: %d ano(s)" % [int(data.get("idade", 25)), int(data.get("anos", 1))]
	l_info.add_theme_font_size_override("font_size", 10)
	l_info.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(l_info)
	
	var l_team = Label.new()
	l_team.text = "✍️ Contratado por: %s" % str(data.get("equipe", "Equipe"))
	l_team.add_theme_font_size_override("font_size", 10)
	l_team.add_theme_color_override("font_color", Color("#34d399"))
	vbox.add_child(l_team)
	
	card.add_child(vbox)
	return card

func _get_driver_situation(d_name: String, team: String) -> Dictionary:
	if Database.get("driver_market_data") != null and Database.driver_market_data.has(d_name):
		var data = Database.driver_market_data[d_name]
		var status_txt = data.get("status", "Sem Contrato (Livre)")
		var col = "#ef4444"
		if "Interesse" in status_txt or "Negociação" in status_txt:
			col = "#38bdf8"
		return {"text": status_txt, "color": col}
		
	return {"text": "Sem Contrato (Livre)", "color": "#ef4444"}

func _build_my_team_contracts_panel(parent_container: Control) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#121316")
	st.set_corner_radius_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", st)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	var lbl_title = Label.new()
	lbl_title.text = "📜 GESTÃO DE CONTRATOS DA SUA EQUIPE"
	lbl_title.add_theme_font_size_override("font_size", 12)
	lbl_title.add_theme_color_override("font_color", Color("#38bdf8"))
	vbox.add_child(lbl_title)
	
	var my_drivers = Database.user_team.get("pilotos", [])
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	
	for i in range(my_drivers.size()):
		var d = my_drivers[i]
		var card = VBoxContainer.new()
		
		var l_d = Label.new()
		l_d.text = "%s (OVR: %d)" % [str(d.get("Nome", "Piloto")), int(d.get("OVR", d.get("Overall", 75)))]
		l_d.add_theme_font_size_override("font_size", 11)
		card.add_child(l_d)
		
		var l_c = Label.new()
		l_c.text = "Contrato: %d Ano(s) Restante(s)" % int(d.get("contrato_anos", d.get("AnosContrato", 1)))
		l_c.add_theme_font_size_override("font_size", 11)
		l_c.add_theme_color_override("font_color", Color("#34d399"))
		card.add_child(l_c)
		
		var btn_renew = Button.new()
		btn_renew.text = "🔄 Renovar Contrato"
		btn_renew.add_theme_font_size_override("font_size", 10)
		btn_renew.pressed.connect(func(): _renew_driver_contract(i))
		card.add_child(btn_renew)
		
		hbox.add_child(card)
		
	vbox.add_child(hbox)
	panel.add_child(vbox)
	parent_container.add_child(panel)

func _renew_driver_contract(driver_index: int) -> void:
	var my_drivers = Database.user_team.get("pilotos", [])
	if driver_index < my_drivers.size():
		var current_years = int(my_drivers[driver_index].get("contrato_anos", my_drivers[driver_index].get("AnosContrato", 1)))
		my_drivers[driver_index]["contrato_anos"] = current_years + 1
		my_drivers[driver_index]["AnosContrato"] = current_years + 1
		build_ui()
