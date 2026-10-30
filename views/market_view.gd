extends Control

var time_passed: float = 0.0

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

func _get_status_priority(team_name: String) -> int:
	if team_name == "Aposentado":
		return 2 # Aposentados sempre no final
	elif team_name == "Free Agent" or team_name.is_empty():
		return 1 # Agentes livres no meio
	return 0     # Titulares no topo

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)
	
	# Título da Tela
	var title = Label.new()
	title.text = "MERCADO DE PILOTOS & CONTRATOS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(title)
	
	# Scroll Container para a Tabela
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var grid = GridContainer.new()
	grid.columns = 8 # Atualizado para 8 colunas
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	
	# 1. Cabeçalhos na ordem definida
	_add_header(grid, "PILOTO", 140)
	_add_header(grid, "IDADE", 50)
	_add_header(grid, "OVERALL", 65)
	_add_header(grid, "RITMO", 55)
	_add_header(grid, "MORAL", 65)
	_add_header(grid, "EQUIPE", 110)
	_add_header(grid, "CONTRATO", 80) # Nova coluna de Contrato
	_add_header(grid, "SITUAÇÃO", 170)
	
	# Ordenar pilotos por Prioridade de Status e depois por Overall
	var sorted_drivers = Database.drivers.duplicate()
	sorted_drivers.sort_custom(func(a, b):
		var p_a = _get_status_priority(str(a.get("Equipe", "")))
		var p_b = _get_status_priority(str(b.get("Equipe", "")))
		
		if p_a != p_b:
			return p_a < p_b
			
		var ovr_a = int(a.get("Overall", 70))
		var ovr_b = int(b.get("Overall", 70))
		if ovr_a != ovr_b:
			return ovr_a > ovr_b
			
		return str(a.get("Nome", "")) < str(b.get("Nome", ""))
	)
	
	# 2. Preenchimento das Linhas
	for d in sorted_drivers:
		var d_name = d.get("Nome", "Desconhecido")
		var age = str(d.get("Idade", 25))
		var overall = str(d.get("Overall", 75))
		var pace = str(d.get("Ritmo", 75))
		var morale_val = int(d.get("Moral", 75))
		var team = d.get("Equipe", "Free Agent")
		
		# Anos de contrato restantes
		# Substitua a definição de c_years e years_str por isso:
		var c_years: int = int(d.get("AnosContrato", 0))
		var years_str: String = "-"

		if team != "Free Agent" and team != "Aposentado":
			years_str = str(c_years) + (" ano" if c_years == 1 else " anos")
	
		# Obter situação do piloto no mercado
		var situation = _get_driver_situation(d_name, team)
		
		# Célula Piloto
		_add_cell(grid, d_name, Color("#ffffff"))
		
		# Célula Idade
		_add_cell(grid, age, Color("#94a3b8"))
		
		# Célula Overall
		_add_cell(grid, overall, Color("#38bdf8"))
		
		# Célula Ritmo
		_add_cell(grid, pace, Color("#94a3b8"))
		
		# Célula Moral
		var morale_color = Color("#22c55e")
		if morale_val < 40:
			morale_color = Color("#ef4444")
		elif morale_val < 70:
			morale_color = Color("#f59e0b")
			
		_add_cell(grid, str(morale_val) + "%", morale_color)
		
		# Célula Equipe
		var team_color = Color("#ffffff") if team != "Free Agent" else Color("#64748b")
		_add_cell(grid, team, team_color)
		
		# Célula Contrato (Novo)
		var contract_color = Color("#f59e0b") if (c_years <= 1 and team != "Free Agent") else Color("#94a3b8")
		_add_cell(grid, years_str, contract_color)
		
		# Célula Situação
		_add_cell(grid, situation["text"], Color(situation["color"]))
		
	scroll.add_child(grid)
	vbox.add_child(scroll)

# Função auxiliar para buscar/gerar a situação do contrato e rumores
func _get_driver_situation(d_name: String, team: String) -> Dictionary:
	if Database.get("driver_market_data") != null and Database.driver_market_data.has(d_name):
		var data = Database.driver_market_data[d_name]
		var status_txt = data.get("status", "Contrato Regular")
		var col = "#22c55e"
		
		if "Fim de Ano" in status_txt or "Renovação" in status_txt:
			col = "#f59e0b"
		elif "Aposentadoria" in status_txt or "Livre" in status_txt:
			col = "#ef4444"
		elif "Interesse" in status_txt or "Negociação" in status_txt:
			col = "#38bdf8"
			
		return {"text": status_txt, "color": col}
		
	if team == "Free Agent":
		return {"text": "Sem Contrato (Livre)", "color": "#ef4444"}
	
	return {"text": "Contrato Seguro", "color": "#22c55e"}

func _add_header(grid: GridContainer, text: String, min_w: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#ef4444"))
	grid.add_child(lbl)

func _add_cell(grid: GridContainer, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	grid.add_child(lbl)

# Constrói o painel superior de gestão de contratos da equipe
func _build_my_team_contracts_panel(parent_container: Control) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#0f172a")
	st.border_width_top = 2
	st.border_color = Color("#38bdf8")
	st.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", st)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var lbl_title = Label.new()
	lbl_title.text = "📜 GESTÃO DE CONTRATOS DA EQUIPE"
	lbl_title.add_theme_color_override("font_color", Color("#38bdf8"))
	vbox.add_child(lbl_title)
	
	var my_drivers = Database.user_team.get("pilotos", [])
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	
	for i in range(my_drivers.size()):
		var d = my_drivers[i]
		var card = VBoxContainer.new()
		
		var l_d = Label.new()
		l_d.text = "%s (OVR: %d)" % [str(d.get("Nome", "Piloto")), int(d.get("OVR", 75))]
		card.add_child(l_d)
		
		var l_c = Label.new()
		l_c.text = "Contrato: %d Ano(s) Restante(s)" % int(d.get("contrato_anos", 1))
		l_c.add_theme_color_override("font_color", Color("#34d399"))
		card.add_child(l_c)
		
		var btn_renew = Button.new()
		btn_renew.text = "🔄 Renovar Contrato"
		btn_renew.pressed.connect(func(): _renew_driver_contract(i))
		card.add_child(btn_renew)
		
		hbox.add_child(card)
		
	vbox.add_child(hbox)
	panel.add_child(vbox)
	parent_container.add_child(panel)

# Lógica de renovação de contrato
func _renew_driver_contract(driver_index: int) -> void:
	var my_drivers = Database.user_team.get("pilotos", [])
	if driver_index < my_drivers.size():
		var current_years = int(my_drivers[driver_index].get("contrato_anos", 1))
		my_drivers[driver_index]["contrato_anos"] = current_years + 1
		build_ui()
