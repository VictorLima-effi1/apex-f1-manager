extends Control

# Estado das Etapas:
# -1 = Seleção de Modo | 0 = Painel Unificado de Criação de Equipe | 3 = Testes de Inverno
var current_step: int = -1

# Dados da Equipe
var team_name: String = "Apex Grand Prix"
var boss_name: String = "Chefe da Equipe"
var team_color: Color = Color("#ef4444") # Cor padrão (Vermelho)
var initial_budget: int = 135
var remaining_budget: int = 135

# Seleções da Escuderia
var selected_drivers: Array = []
var selected_engine: Dictionary = {}
var selected_chassis: Dictionary = {}

# Animação do Background
var time_passed: float = 0.0

# Dados da Sessão de Testes
var testing_day: int = 1
var max_testing_days: int = 3
var test_grid_data: Array = []
var driver_configs: Array = []

# Referências Visuais
var main_card: PanelContainer
var grid_container_vbox: VBoxContainer
var driver_cards_container: HBoxContainer
var title_label: Label
var budget_label: Label

func _ready() -> void:
	# Força o elemento a ocupar 100% da janela e ficar exatamente no centro
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	_build_ui_container()
	_render_current_step()

func _process(delta: float) -> void:
	time_passed += delta
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

func _build_ui_container() -> void:
	for c in get_children():
		c.queue_free()
		
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 0
	center.offset_top = 0
	center.offset_right = 0
	center.offset_bottom = 0
	add_child(center)
	
	main_card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	style.border_width_top = 5
	style.border_color = team_color
	style.set_corner_radius_all(10)
	style.shadow_size = 35
	style.shadow_color = Color(0, 0, 0, 0.7)
	main_card.add_theme_stylebox_override("panel", style)
	
	center.add_child(main_card)

func _render_current_step() -> void:
	for c in main_card.get_children():
		c.queue_free()
		
	match current_step:
		-1: _build_mode_selection_menu()
		0: _build_team_creation_step()
		3: _build_winter_testing_step()

# =============================================================
# ETAPA -1: SELEÇÃO DE MODO DE JOGO
# =============================================================
func _build_mode_selection_menu() -> void:
	main_card.custom_minimum_size = Vector2(1150, 620)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	
	var lbl_title = Label.new()
	lbl_title.text = "🏎️ MODO MANAGER • ESCOLHA SUA JORNADA"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 26)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 30)
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Card Criar Nova Equipe
	var card_new = PanelContainer.new()
	card_new.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_new.size_flags_stretch_ratio = 1.0
	
	var st_new = StyleBoxFlat.new()
	st_new.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	st_new.set_corner_radius_all(10)
	st_new.border_width_left = 6
	st_new.border_color = Color("#2563eb")
	card_new.add_theme_stylebox_override("panel", st_new)
	
	var nm1 = MarginContainer.new()
	nm1.add_theme_constant_override("margin_left", 25)
	nm1.add_theme_constant_override("margin_right", 25)
	nm1.add_theme_constant_override("margin_top", 25)
	nm1.add_theme_constant_override("margin_bottom", 25)
	
	var nv1 = VBoxContainer.new()
	nv1.add_theme_constant_override("separation", 16)
	
	var l_n1 = Label.new()
	l_n1.text = "🛠️ CRIAR NOVA EQUIPE"
	l_n1.add_theme_font_size_override("font_size", 22)
	l_n1.add_theme_color_override("font_color", Color("#38bdf8"))
	nv1.add_child(l_n1)
	
	var l_d1 = Label.new()
	l_d1.text = "Fundação total da sua escuderia:\n\n• Escolha nome e cores oficiais\n• Gerencie o orçamento inicial de $135M\n• Selecione os 2 pilotos da temporada\n• Escolha o motor e chassi do carro"
	l_d1.add_theme_font_size_override("font_size", 18)
	l_d1.add_theme_color_override("font_color", Color("#e2e8f0"))
	l_d1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l_d1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv1.add_child(l_d1)
	
	var btn_start = Button.new()
	btn_start.text = "INICIAR CRIAÇÃO ▶"
	btn_start.custom_minimum_size.y = 50
	btn_start.add_theme_font_size_override("font_size", 18)
	btn_start.pressed.connect(func():
		current_step = 0
		_render_current_step()
	)
	nv1.add_child(btn_start)
	nm1.add_child(nv1)
	card_new.add_child(nm1)
	cards_hbox.add_child(card_new)
	
	# Card Equipe Existente
	var card_exist = PanelContainer.new()
	card_exist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_exist.size_flags_stretch_ratio = 1.0
	
	var st_ex = StyleBoxFlat.new()
	st_ex.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	st_ex.set_corner_radius_all(10)
	st_ex.border_width_left = 6
	st_ex.border_color = Color("#f59e0b")
	card_exist.add_theme_stylebox_override("panel", st_ex)
	
	var nm2 = MarginContainer.new()
	nm2.add_theme_constant_override("margin_left", 25)
	nm2.add_theme_constant_override("margin_right", 25)
	nm2.add_theme_constant_override("margin_top", 25)
	nm2.add_theme_constant_override("margin_bottom", 25)
	
	var nv2 = VBoxContainer.new()
	nv2.add_theme_constant_override("separation", 16)
	
	var l_n2 = Label.new()
	l_n2.text = "🏆 EQUIPE EXISTENTE"
	l_n2.add_theme_font_size_override("font_size", 22)
	l_n2.add_theme_color_override("font_color", Color("#fbbf24"))
	nv2.add_child(l_n2)
	
	var l_d2 = Label.new()
	l_d2.text = "Assuma o comando de uma escuderia oficial (Ferrari, Red Bull, McLaren, etc.).\n\n⚠️ FUNCIONALIDADE EM DESENVOLVIMENTO"
	l_d2.add_theme_font_size_override("font_size", 18)
	l_d2.add_theme_color_override("font_color", Color("#e2e8f0"))
	l_d2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l_d2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv2.add_child(l_d2)
	
	var btn_exist = Button.new()
	btn_exist.text = "ASSUMIR EQUIPE 🔒"
	btn_exist.custom_minimum_size.y = 50
	btn_exist.add_theme_font_size_override("font_size", 18)
	btn_exist.pressed.connect(func():
		var dialog = AcceptDialog.new()
		dialog.title = "Aviso do Sistema"
		dialog.dialog_text = "⚠️ Opção em desenvolvimento. Por favor, escolha 'Criar Nova Equipe'."
		add_child(dialog)
		dialog.popup_centered()
	)
	nv2.add_child(btn_exist)
	nm2.add_child(nv2)
	card_exist.add_child(nm2)
	cards_hbox.add_child(card_exist)
	
	vbox.add_child(cards_hbox)
	
	var btn_back = Button.new()
	btn_back.text = "VOLTAR AO MENU PRINCIPAL"
	btn_back.custom_minimum_size.y = 48
	btn_back.add_theme_font_size_override("font_size", 18)
	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://views/main_menu_view.tscn")
	)
	vbox.add_child(btn_back)
	
	margin.add_child(vbox)
	main_card.add_child(margin)

# =============================================================
# ETAPA 0: TELA UNIFICADA DE CRIAÇÃO DA EQUIPE
# =============================================================
func _build_team_creation_step() -> void:
	main_card.custom_minimum_size = Vector2(1150, 640)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_right", 35)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	
	# Cabeçalho da Tela com Orçamento Dinâmico
	var head_hbox = HBoxContainer.new()
	
	var lbl_title = Label.new()
	lbl_title.text = "🏎️ CRIAR NOVA ESCUDERIA"
	lbl_title.add_theme_font_size_override("font_size", 24)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_hbox.add_child(lbl_title)
	
	var lbl_b_disp = Label.new()
	lbl_b_disp.text = "💰 ORÇAMENTO RESTANTE: $%dM" % remaining_budget
	lbl_b_disp.add_theme_font_size_override("font_size", 22)
	lbl_b_disp.add_theme_color_override("font_color", Color("#10b981") if remaining_budget >= 0 else Color("#ef4444"))
	head_hbox.add_child(lbl_b_disp)
	
	vbox.add_child(head_hbox)
	
	# Grid de Campos de Configuração
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 16)
	
	# 1. Nome da Equipe
	var v_tname = VBoxContainer.new()
	v_tname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_tn = Label.new()
	l_tn.text = "Nome da Equipe:"
	l_tn.add_theme_font_size_override("font_size", 18)
	v_tname.add_child(l_tn)
	var in_tn = LineEdit.new()
	in_tn.text = team_name
	in_tn.custom_minimum_size.y = 42
	in_tn.add_theme_font_size_override("font_size", 18)
	in_tn.text_changed.connect(func(new_text): team_name = new_text)
	v_tname.add_child(in_tn)
	grid.add_child(v_tname)
	
	# 2. Chefe de Equipe
	var v_bname = VBoxContainer.new()
	v_bname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_bn = Label.new()
	l_bn.text = "Nome do Chefe de Equipe:"
	l_bn.add_theme_font_size_override("font_size", 18)
	v_bname.add_child(l_bn)
	var in_bn = LineEdit.new()
	in_bn.text = boss_name
	in_bn.custom_minimum_size.y = 42
	in_bn.add_theme_font_size_override("font_size", 18)
	in_bn.text_changed.connect(func(new_text): boss_name = new_text)
	v_bname.add_child(in_bn)
	grid.add_child(v_bname)
	
	# 3. Cor da Equipe
	var v_color = VBoxContainer.new()
	v_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_col = Label.new()
	l_col.text = "Cor Oficial da Escuderia:"
	l_col.add_theme_font_size_override("font_size", 18)
	v_color.add_child(l_col)
	var cp = ColorPickerButton.new()
	cp.color = team_color
	cp.custom_minimum_size.y = 42
	cp.color_changed.connect(func(new_color):
		team_color = new_color
		_update_card_border_color()
	)
	v_color.add_child(cp)
	grid.add_child(v_color)
	
	# 4. Seleção de Pilotos
	var v_drv = VBoxContainer.new()
	v_drv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_drv = Label.new()
	l_drv.text = "Pilotos Titulares (%d/2):" % selected_drivers.size()
	l_drv.add_theme_font_size_override("font_size", 18)
	v_drv.add_child(l_drv)
	var btn_drv = Button.new()
	btn_drv.custom_minimum_size.y = 42
	btn_drv.add_theme_font_size_override("font_size", 18)
	if selected_drivers.size() == 0:
		btn_drv.text = "👥 SELECIONAR PILOTOS..."
	else:
		var d_names = []
		for d in selected_drivers: d_names.append(d.get("Nome", "Piloto"))
		btn_drv.text = "👥 " + ", ".join(d_names)
	btn_drv.pressed.connect(_open_driver_modal)
	v_drv.add_child(btn_drv)
	grid.add_child(v_drv)
	
	# 5. Seleção de Motor
	var v_eng = VBoxContainer.new()
	v_eng.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_eng = Label.new()
	l_eng.text = "Unidade de Potência (Motor):"
	l_eng.add_theme_font_size_override("font_size", 18)
	v_eng.add_child(l_eng)
	var btn_eng = Button.new()
	btn_eng.custom_minimum_size.y = 42
	btn_eng.add_theme_font_size_override("font_size", 18)
	btn_eng.text = "⚙️ " + selected_engine.get("nome", "SELECIONAR MOTOR...")
	btn_eng.pressed.connect(_open_engine_modal)
	v_eng.add_child(btn_eng)
	grid.add_child(v_eng)
	
	# 6. Seleção de Chassi
	var v_cha = VBoxContainer.new()
	v_cha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_cha = Label.new()
	l_cha.text = "Pacote Aerodinâmico / Chassi:"
	l_cha.add_theme_font_size_override("font_size", 18)
	v_cha.add_child(l_cha)
	var btn_cha = Button.new()
	btn_cha.custom_minimum_size.y = 42
	btn_cha.add_theme_font_size_override("font_size", 18)
	btn_cha.text = "🏎️ " + selected_chassis.get("nome", "SELECIONAR CHASSI...")
	btn_cha.pressed.connect(_open_chassis_modal)
	v_cha.add_child(btn_cha)
	grid.add_child(v_cha)
	
	vbox.add_child(grid)
	
	# Espaçador Flexível
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Botões Inferiores de Confirmação
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 20)
	
	var btn_confirm = Button.new()
	btn_confirm.text = "🏁 FINALIZAR EQUIPE E IR PARA OS TESTES ▶"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 52
	btn_confirm.add_theme_font_size_override("font_size", 18)
	
	# Validação: Só permite prosseguir se tiver 2 pilotos, motor e chassi escolhidos
	var can_proceed = (selected_drivers.size() == 2) and (not selected_engine.is_empty()) and (not selected_chassis.is_empty())
	btn_confirm.disabled = not can_proceed
	
	btn_confirm.pressed.connect(func():
		_recalculate_budget()
		_save_team_to_database()
		
		driver_configs = [
			{"pneu": "Médio (C4)", "stint": "Ritmo de Corrida", "on_track": true, "wear": 100.0},
			{"pneu": "Macio (C5)", "stint": "Simulação de Quali", "on_track": true, "wear": 100.0}
		]
		current_step = 3
		_init_test_grid()
		_render_current_step()
	)
	btn_hbox.add_child(btn_confirm)
	
	var btn_back = Button.new()
	btn_back.text = "VOLTAR"
	btn_back.custom_minimum_size = Vector2(180, 52)
	btn_back.add_theme_font_size_override("font_size", 18)
	btn_back.pressed.connect(func():
		current_step = -1
		_render_current_step()
	)
	btn_hbox.add_child(btn_back)
	
	vbox.add_child(btn_hbox)
	margin.add_child(vbox)
	main_card.add_child(margin)

func _update_card_border_color() -> void:
	if is_instance_valid(main_card):
		var style = main_card.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = team_color

func _recalculate_budget() -> void:
	var total_spent = 0
	for d in selected_drivers:
		total_spent += d.get("salario", 8)
	total_spent += selected_engine.get("preco", 0)
	total_spent += selected_chassis.get("preco", 0)
	remaining_budget = initial_budget - total_spent

# =============================================================
# MODAIS DE SELEÇÃO (PILOTOS, MOTORES E CHASSIS)
# =============================================================

# MODAL PILOTOS
func _open_driver_modal() -> void:
	var dialog = Window.new()
	dialog.title = "🏎️ MERCADO DE PILOTOS - TABELA DE NEGOCIAÇÃO"
	dialog.size = Vector2i(1050, 640)
	dialog.exclusive = true
	
	dialog.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	dialog.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#0b0e14")
	dialog.add_child(bg)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	
	var l_head = Label.new()
	l_head.text = "📋 PILOTOS DISPONÍVEIS (SELECIONE PARA ABRIR NEGOCIAÇÃO)"
	l_head.add_theme_font_size_override("font_size", 18)
	l_head.add_theme_color_override("font_color", Color("#ef4444"))
	main_vbox.add_child(l_head)
	
	# Cabeçalho
	var th_box = PanelContainer.new()
	var st_th = StyleBoxFlat.new()
	st_th.bg_color = Color("#1e293b")
	st_th.set_corner_radius_all(6)
	th_box.add_theme_stylebox_override("panel", st_th)
	
	var th_m = MarginContainer.new()
	th_m.add_theme_constant_override("margin_left", 14)
	th_m.add_theme_constant_override("margin_right", 14)
	th_m.add_theme_constant_override("margin_top", 10)
	th_m.add_theme_constant_override("margin_bottom", 10)
	
	var th_hbox = HBoxContainer.new()
	th_hbox.add_theme_constant_override("separation", 12)
	
	_add_modal_th(th_hbox, "PILOTO", 240)
	_add_modal_th(th_hbox, "IDADE", 90)
	_add_modal_th(th_hbox, "ATRIBUTOS (OVR)", 160)
	_add_modal_th(th_hbox, "PEDIDA INICIAL", 220)
	_add_modal_th(th_hbox, "AÇÃO", 150)
	
	th_m.add_child(th_hbox)
	th_box.add_child(th_m)
	main_vbox.add_child(th_box)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var rows_vbox = VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 6)
	
	var all_drivers = (Database.drivers if "drivers" in Database else []).duplicate()
	
	all_drivers.sort_custom(func(a, b):
		var ovr_a = int(a.get("Habilidade", a.get("Overall", 75)))
		var ovr_b = int(b.get("Habilidade", b.get("Overall", 75)))
		return ovr_a > ovr_b
	)
	
	for d in all_drivers:
		var d_name = d.get("Nome", d.get("nome", "Piloto"))
		var d_age = int(d.get("Idade", d.get("idade", 25)))
		var d_ovr = int(d.get("Habilidade", d.get("Overall", 75)))
		
		# Calcula e salva o valor base de salário caso ainda não tenha sido definido
		if not d.has("salario"):
			var variacao_mercado = randf_range(-1.0, 1.78)
			d["salario"] = clamp((d_ovr - 70) * 1.2 + 4.0 + variacao_mercado, 3.0, 35.0)
		
		# Exigências padrão do piloto
		if not d.has("anos_pedidos"):
			d["anos_pedidos"] = randi_range(1, 3)
		if not d.has("status_pedido"):
			d["status_pedido"] = "1º Piloto" if d_ovr >= 88 else "Piloto Igualitário"
			
		var row = PanelContainer.new()
		var st_r = StyleBoxFlat.new()
		
		var is_selected = false
		for sel in selected_drivers:
			if sel.get("Nome", "") == d_name:
				is_selected = true
				break
				
		st_r.bg_color = Color("#1e293b") if is_selected else Color("#0f172a")
		if is_selected:
			st_r.border_width_left = 5
			st_r.border_color = Color("#10b981")
		st_r.set_corner_radius_all(4)
		row.add_theme_stylebox_override("panel", st_r)
		
		var rm = MarginContainer.new()
		rm.add_theme_constant_override("margin_left", 14)
		rm.add_theme_constant_override("margin_right", 14)
		rm.add_theme_constant_override("margin_top", 8)
		rm.add_theme_constant_override("margin_bottom", 8)
		
		var rh = HBoxContainer.new()
		rh.add_theme_constant_override("separation", 12)
		
		# Nome
		var l_n = Label.new()
		l_n.text = d_name
		l_n.custom_minimum_size.x = 240
		l_n.add_theme_font_size_override("font_size", 15)
		rh.add_child(l_n)
		
		# Idade
		var l_a = Label.new()
		l_a.text = "%d anos" % d_age
		l_a.custom_minimum_size.x = 90
		l_a.add_theme_font_size_override("font_size", 14)
		l_a.add_theme_color_override("font_color", Color("#cbd5e1"))
		rh.add_child(l_a)
		
		# OVR
		var l_o = Label.new()
		l_o.text = "⚡ %d OVR" % d_ovr
		l_o.custom_minimum_size.x = 160
		l_o.add_theme_font_size_override("font_size", 15)
		l_o.add_theme_color_override("font_color", Color("#fbbf24") if d_ovr >= 88 else Color("#38bdf8"))
		rh.add_child(l_o)
		
		# Valor
		var l_v = Label.new()
		l_v.text = "💰 $%.1fM / ano" % d["salario"]
		l_v.custom_minimum_size.x = 220
		l_v.add_theme_font_size_override("font_size", 15)
		l_v.add_theme_color_override("font_color", Color("#10b981"))
		rh.add_child(l_v)
		
		# Botão Ação
		var btn_neg = Button.new()
		btn_neg.custom_minimum_size = Vector2(150, 38)
		btn_neg.add_theme_font_size_override("font_size", 13)
		
		if is_selected:
			btn_neg.text = "CANCELAR"
			var st_c = StyleBoxFlat.new()
			st_c.bg_color = Color("#dc2626")
			st_c.set_corner_radius_all(4)
			btn_neg.add_theme_stylebox_override("normal", st_c)
			btn_neg.pressed.connect(func():
				selected_drivers.erase(d)
				_recalculate_budget()
				dialog.queue_free()
				_render_current_step()
			)
		else:
			btn_neg.text = "NEGOCIAR 🤝"
			var st_g = StyleBoxFlat.new()
			st_g.bg_color = Color("#16a34a")
			st_g.set_corner_radius_all(4)
			btn_neg.add_theme_stylebox_override("normal", st_g)
			btn_neg.pressed.connect(func():
				dialog.queue_free()
				_open_negotiation_dialog(d)
			)
			
		rh.add_child(btn_neg)
		rm.add_child(rh)
		row.add_child(rm)
		rows_vbox.add_child(row)
		
	scroll.add_child(rows_vbox)
	main_vbox.add_child(scroll)
	
	var btn_close = Button.new()
	btn_close.text = "FECHAR TABELA"
	btn_close.custom_minimum_size.y = 44
	btn_close.add_theme_font_size_override("font_size", 15)
	btn_close.pressed.connect(func(): dialog.queue_free())
	main_vbox.add_child(btn_close)
	
	margin.add_child(main_vbox)
	dialog.add_child(margin)
	add_child(dialog)
	dialog.popup_centered()

# =============================================================
# 2. NOVA ABA DE NEGOCIAÇÃO INDIVIDUAL DO PILOTO
# =============================================================
func _open_negotiation_dialog(driver: Dictionary) -> void:
	var dialog = Window.new()
	var d_name = driver.get("Nome", "Piloto")
	dialog.title = "🤝 MESA DE NEGOCIAÇÃO - " + d_name.to_upper()
	dialog.size = Vector2i(850, 520)
	dialog.exclusive = true
	
	dialog.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	dialog.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#0b0e14")
	dialog.add_child(bg)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	
	# Título da Mesa
	var l_title = Label.new()
	l_title.text = "PROPOSTA DE CONTRATO PARA " + d_name.to_upper()
	l_title.add_theme_font_size_override("font_size", 20)
	l_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(l_title)
	
	# Layout em 2 Colunas: Lado Esquerdo (Exigências) vs Lado Direito (Oferta da Equipe)
	var body_hbox = HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 25)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# --- LADO ESQUERDO: EXIGÊNCIAS DO PILOTO ---
	var left_card = PanelContainer.new()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_l = StyleBoxFlat.new()
	st_l.bg_color = Color("#1e293b")
	st_l.set_corner_radius_all(8)
	st_l.border_width_left = 4
	st_l.border_color = Color("#fbbf24") # Amarelo
	left_card.add_theme_stylebox_override("panel", st_l)
	
	var lm = MarginContainer.new()
	lm.add_theme_constant_override("margin_left", 18)
	lm.add_theme_constant_override("margin_right", 18)
	lm.add_theme_constant_override("margin_top", 18)
	lm.add_theme_constant_override("margin_bottom", 18)
	
	var lv = VBoxContainer.new()
	lv.add_theme_constant_override("separation", 14)
	
	var l_req_title = Label.new()
	l_req_title.text = "📋 EXIGÊNCIAS DO PILOTO"
	l_req_title.add_theme_font_size_override("font_size", 16)
	l_req_title.add_theme_color_override("font_color", Color("#fbbf24"))
	lv.add_child(l_req_title)
	
	var req_val = driver.get("salario", 10.0)
	var req_years = driver.get("anos_pedidos", 2)
	var req_status = driver.get("status_pedido", "1º Piloto")
	
	var l_r1 = Label.new()
	l_r1.text = "• Salário Desejado: $%.1fM / ano" % req_val
	l_r1.add_theme_font_size_override("font_size", 14)
	lv.add_child(l_r1)
	
	var l_r2 = Label.new()
	l_r2.text = "• Duração do Contrato: %d Ano(s)" % req_years
	l_r2.add_theme_font_size_override("font_size", 14)
	lv.add_child(l_r2)
	
	var l_r3 = Label.new()
	l_r3.text = "• Posição / Status: " + req_status
	l_r3.add_theme_font_size_override("font_size", 14)
	lv.add_child(l_r3)
	
	lm.add_child(lv)
	left_card.add_child(lm)
	body_hbox.add_child(left_card)
	
	# --- LADO DIREITO: SUA OFERTA ---
	var right_card = PanelContainer.new()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_r = StyleBoxFlat.new()
	st_r.bg_color = Color("#1e293b")
	st_r.set_corner_radius_all(8)
	st_r.border_width_left = 4
	st_r.border_color = Color("#2563eb") # Azul
	right_card.add_theme_stylebox_override("panel", st_r)
	
	var rm = MarginContainer.new()
	rm.add_theme_constant_override("margin_left", 18)
	rm.add_theme_constant_override("margin_right", 18)
	rm.add_theme_constant_override("margin_top", 18)
	rm.add_theme_constant_override("margin_bottom", 18)
	
	var rv = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 14)
	
	var l_off_title = Label.new()
	l_off_title.text = "🖊️ SUA OFERTA DA ESCUDERIA"
	l_off_title.add_theme_font_size_override("font_size", 16)
	l_off_title.add_theme_color_override("font_color", Color("#38bdf8"))
	rv.add_child(l_off_title)
	
	# Campo 1: Salário Oferecido (SpinBox)
	var v_s = VBoxContainer.new()
	var l_s = Label.new()
	l_s.text = "Salário Oferecido ($M / ano):"
	l_s.add_theme_font_size_override("font_size", 13)
	v_s.add_child(l_s)
	
	var spin_salary = SpinBox.new()
	spin_salary.min_value = 1.0
	spin_salary.max_value = 50.0
	spin_salary.step = 0.1
	spin_salary.value = req_val # Começa com a pedida dele
	spin_salary.custom_minimum_size.y = 38
	v_s.add_child(spin_salary)
	rv.add_child(v_s)
	
	# Campo 2: Anos de Contrato
	var v_y = VBoxContainer.new()
	var l_y = Label.new()
	l_y.text = "Anos de Contrato:"
	l_y.add_theme_font_size_override("font_size", 13)
	v_y.add_child(l_y)
	
	var opt_years = OptionButton.new()
	opt_years.add_item("1 Ano", 1)
	opt_years.add_item("2 Anos", 2)
	opt_years.add_item("3 Anos", 3)
	opt_years.select(req_years - 1)
	opt_years.custom_minimum_size.y = 38
	v_y.add_child(opt_years)
	rv.add_child(v_y)
	
	# Campo 3: Status na Equipe
	var v_st = VBoxContainer.new()
	var l_st = Label.new()
	l_st.text = "Status na Equipe:"
	l_st.add_theme_font_size_override("font_size", 13)
	v_st.add_child(l_st)
	
	var opt_status = OptionButton.new()
	opt_status.add_item("1º Piloto Titular", 0)
	opt_status.add_item("Piloto Igualitário", 1)
	opt_status.add_item("2º Piloto Titular", 2)
	opt_status.select(0 if req_status == "1º Piloto" else 1)
	opt_status.custom_minimum_size.y = 38
	v_st.add_child(opt_status)
	rv.add_child(v_st)
	
	rm.add_child(rv)
	right_card.add_child(rm)
	body_hbox.add_child(right_card)
	
	vbox.add_child(body_hbox)
	
	# Feedback / Resposta da Negociação
	var lbl_feedback = Label.new()
	lbl_feedback.text = ""
	lbl_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_feedback.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_feedback)
	
	# Botões Inferiores
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	
	var btn_send = Button.new()
	btn_send.text = "🤝 ENVIAR PROPOSTA"
	btn_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_send.custom_minimum_size.y = 44
	btn_send.add_theme_font_size_override("font_size", 14)
	var st_b = StyleBoxFlat.new()
	st_b.bg_color = Color("#16a34a") # Verde
	st_b.set_corner_radius_all(4)
	btn_send.add_theme_stylebox_override("normal", st_b)
	
	btn_send.pressed.connect(func():
		var offered_salary = spin_salary.value
		var offered_years = opt_years.get_selected_id()
		var offered_status_idx = opt_status.selected
		
		# Cálculo da Margem de Aceitação
		var min_acceptable_salary = req_val * 0.92 # Aceita até 8% a menos se o pacote for bom
		
		# Bônus se oferecer 1º Piloto ou mais anos de contrato
		if offered_status_idx == 0 and req_status != "1º Piloto":
			min_acceptable_salary *= 0.95 # Aceita mais 5% de desconto por ser o 1º piloto
		if offered_years > req_years:
			min_acceptable_salary *= 0.97 # Aceita mais 3% de desconto por estabilidade de contrato
			
		if offered_salary >= min_acceptable_salary:
			lbl_feedback.text = "✅ O piloto ACEITOU sua proposta de contrato!"
			lbl_feedback.add_theme_color_override("font_color", Color("#10b981"))
			
			driver["salario"] = offered_salary
			if not selected_drivers.has(driver):
				if selected_drivers.size() < 2:
					selected_drivers.append(driver)
					
			_recalculate_budget()
			
			# Aguarda 1 segundo e fecha a janela para atualizar a tela principal
			await get_tree().create_timer(1.2).timeout
			dialog.queue_free()
			_render_current_step()
		else:
			lbl_feedback.text = "❌ O piloto RECUSOU a proposta! O salário oferecido está muito abaixo das expectativas."
			lbl_feedback.add_theme_color_override("font_color", Color("#ef4444"))
	)
	btn_hbox.add_child(btn_send)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "CANCELAR"
	btn_cancel.custom_minimum_size = Vector2(160, 44)
	btn_cancel.add_theme_font_size_override("font_size", 14)
	btn_cancel.pressed.connect(func():
		dialog.queue_free()
		_open_driver_modal()
	)
	btn_hbox.add_child(btn_cancel)
	
	vbox.add_child(btn_hbox)
	margin.add_child(vbox)
	dialog.add_child(margin)
	add_child(dialog)
	dialog.popup_centered()

# Função auxiliar para criar os títulos das colunas na modal
func _add_modal_th(parent: HBoxContainer, text: String, width: float) -> void:
	var l = Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("#94a3b8"))
	parent.add_child(l)

# MODAL MOTORES
func _open_engine_modal() -> void:
	var dialog = Window.new()
	dialog.title = "Seleção de Fornecedor de Motor"
	dialog.size = Vector2i(600, 400)
	dialog.exclusive = true
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	var engines = [
		{"nome": "Ferrari Power Unit", "potencia": 90, "preco": 22},
		{"nome": "Mercedes-AMG Power", "potencia": 88, "preco": 20},
		{"nome": "Red Bull Ford Powertrains", "potencia": 91, "preco": 25},
		{"nome": "Honda RBPT", "potencia": 87, "preco": 18}
	]
	
	for eng in engines:
		var btn = Button.new()
		btn.text = "%s | Potência: %d | Custo: $%dM" % [eng["nome"], eng["potencia"], eng["preco"]]
		btn.custom_minimum_size.y = 45
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func():
			selected_engine = eng
			_recalculate_budget()
			dialog.queue_free()
			_render_current_step()
		)
		vbox.add_child(btn)
		
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

# MODAL CHASSIS
func _open_chassis_modal() -> void:
	var dialog = Window.new()
	dialog.title = "Seleção de Pacote Aerodinâmico / Chassi"
	dialog.size = Vector2i(600, 400)
	dialog.exclusive = true
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	
	var chassis_list = [
		{"nome": "Chassi Aero Spec-A (Alta Carga)", "aero": 88, "preco": 20},
		{"nome": "Chassi Aero Spec-B (Baixo Arrastamento)", "aero": 85, "preco": 16},
		{"nome": "Chassi Premium Carbon-X", "aero": 91, "preco": 24}
	]
	
	for cha in chassis_list:
		var btn = Button.new()
		btn.text = "%s | Aero: %d | Custo: $%dM" % [cha["nome"], cha["aero"], cha["preco"]]
		btn.custom_minimum_size.y = 45
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func():
			selected_chassis = cha
			_recalculate_budget()
			dialog.queue_free()
			_render_current_step()
		)
		vbox.add_child(btn)
		
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func _save_team_to_database() -> void:
	var new_team = {
		"Nome": team_name,
		"Cor": team_color.to_html(),
		"Orcamento": remaining_budget,
		"Motor": selected_engine.get("potencia", 85),
		"Aero": selected_chassis.get("aero", 85),
		"Chassi": 85,
		"Confiabilidade": 85,
		"IsPlayer": true
	}
	if "teams" in Database:
		Database.teams.append(new_team)

# =============================================================
# ETAPA 3: TESTES DE INVERNO
# =============================================================
func _build_winter_testing_step() -> void:
	main_card.custom_minimum_size = Vector2(1250, 680)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)
	
	var header = PanelContainer.new()
	var st_h = StyleBoxFlat.new()
	st_h.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	st_h.border_width_left = 5
	st_h.border_color = team_color
	st_h.set_corner_radius_all(6)
	header.add_theme_stylebox_override("panel", st_h)
	
	var hm = MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 14)
	hm.add_theme_constant_override("margin_right", 14)
	hm.add_theme_constant_override("margin_top", 8)
	hm.add_theme_constant_override("margin_bottom", 8)
	
	var hh = HBoxContainer.new()
	var hv = VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	title_label = Label.new()
	title_label.text = "🏎️ TESTES DE INVERNO F1 2026 • BAHRAIN INTERNATIONAL CIRCUIT"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", team_color)
	hv.add_child(title_label)
	
	var l_sub = Label.new()
	l_sub.text = "Dia %d de %d • Pista Aberta (Bandeira Verde)" % [testing_day, max_testing_days]
	l_sub.add_theme_font_size_override("font_size", 11)
	l_sub.add_theme_color_override("font_color", Color("#94a3b8"))
	hv.add_child(l_sub)
	hh.add_child(hv)
	
	budget_label = Label.new()
	budget_label.text = "💰 Orçamento Restante: $%dM" % remaining_budget
	budget_label.add_theme_font_size_override("font_size", 16)
	budget_label.add_theme_color_override("font_color", Color("#10b981"))
	hh.add_child(budget_label)
	
	hm.add_child(hh)
	header.add_child(hm)
	main_vbox.add_child(header)
	
	var gar_card = PanelContainer.new()
	var st_g = StyleBoxFlat.new()
	st_g.bg_color = Color(0.09, 0.11, 0.16, 0.95)
	st_g.set_corner_radius_all(6)
	gar_card.add_theme_stylebox_override("panel", st_g)
	
	var gm = MarginContainer.new()
	gm.add_theme_constant_override("margin_left", 12)
	gm.add_theme_constant_override("margin_right", 12)
	gm.add_theme_constant_override("margin_top", 10)
	gm.add_theme_constant_override("margin_bottom", 10)
	
	driver_cards_container = HBoxContainer.new()
	driver_cards_container.add_theme_constant_override("separation", 14)
	gm.add_child(driver_cards_container)
	gar_card.add_child(gm)
	main_vbox.add_child(gar_card)
	
	var table_card = PanelContainer.new()
	table_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st_t = StyleBoxFlat.new()
	st_t.bg_color = Color(0.09, 0.11, 0.16, 0.95)
	st_t.set_corner_radius_all(6)
	table_card.add_theme_stylebox_override("panel", st_t)
	
	var tm = MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 10)
	tm.add_theme_constant_override("margin_right", 10)
	tm.add_theme_constant_override("margin_top", 8)
	tm.add_theme_constant_override("margin_bottom", 8)
	
	var tv = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	
	var th_box = PanelContainer.new()
	var st_th = StyleBoxFlat.new()
	st_th.bg_color = Color(0.12, 0.15, 0.22, 0.95)
	st_th.set_corner_radius_all(4)
	th_box.add_theme_stylebox_override("panel", st_th)
	
	var th_margin = MarginContainer.new()
	th_margin.add_theme_constant_override("margin_left", 8)
	th_margin.add_theme_constant_override("margin_right", 8)
	th_margin.add_theme_constant_override("margin_top", 4)
	th_margin.add_theme_constant_override("margin_bottom", 4)
	
	var th_hbox = HBoxContainer.new()
	th_hbox.add_theme_constant_override("separation", 8)
	_add_th(th_hbox, "POS", 45)
	_add_th(th_hbox, "PILOTO", 180)
	_add_th(th_hbox, "EQUIPE", 150)
	_add_th(th_hbox, "PNEU", 120)
	_add_th(th_hbox, "DESGASTE", 90)
	_add_th(th_hbox, "STATUS", 110)
	_add_th(th_hbox, "MELHOR VOLTA", 120)
	_add_th(th_hbox, "ÚLTIMA VOLTA", 120)
	th_margin.add_child(th_hbox)
	th_box.add_child(th_margin)
	tv.add_child(th_box)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_container_vbox = VBoxContainer.new()
	grid_container_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(grid_container_vbox)
	tv.add_child(scroll)
	tm.add_child(tv)
	table_card.add_child(tm)
	main_vbox.add_child(table_card)
	
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	
	var btn_sim = Button.new()
	btn_sim.text = "⚡ SIMULAR VOLTAS / AVANÇAR SESSÃO"
	btn_sim.custom_minimum_size = Vector2(300, 42)
	btn_sim.pressed.connect(_on_simulate_laps_pressed)
	footer.add_child(btn_sim)
	
	var btn_finish = Button.new()
	btn_finish.text = "🏁 FINALIZAR PRÉ-TEMPORADA & IR PARA O GP 1"
	btn_finish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_finish.custom_minimum_size.y = 42
	var st_f = StyleBoxFlat.new()
	st_f.bg_color = Color("#16a34a")
	st_f.set_corner_radius_all(4)
	btn_finish.add_theme_stylebox_override("normal", st_f)
	btn_finish.pressed.connect(func():
		Database.current_view = "dashboard"
		get_tree().change_scene_to_file("res://main.tscn")
	)
	footer.add_child(btn_finish)
	
	main_vbox.add_child(footer)
	main_card.add_child(margin)
	
	_rebuild_driver_control_boxes()
	_render_timing_table()

func _add_th(parent: HBoxContainer, text: String, width: float) -> void:
	var l = Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color("#94a3b8"))
	parent.add_child(l)

func _init_test_grid() -> void:
	test_grid_data.clear()
	
	for i in range(selected_drivers.size()):
		var d = selected_drivers[i]
		var cfg = driver_configs[i] if i < driver_configs.size() else {"pneu": "Duro (C3)", "on_track": true, "wear": 100.0}
		test_grid_data.append({
			"nome": d.get("Nome", d.get("nome", "Piloto %d" % (i+1))),
			"equipe": team_name,
			"pneu": cfg.get("pneu", "Duro (C3)"),
			"wear": cfg.get("wear", 100.0),
			"status": "Na Pista" if cfg.get("on_track", true) else "Nos Boxes",
			"best_time": 999.0,
			"last_time": 0.0,
			"is_player": true,
			"driver_idx": i,
			"ovr": float(d.get("Habilidade", d.get("Overall", 75)))
		})
		
	var all_db = Database.drivers if "drivers" in Database else []
	for d in all_db:
		var d_name = d.get("Nome", d.get("nome", ""))
		var d_team = d.get("Equipe", d.get("equipe", "Free Agent"))
		
		var already = false
		for p in test_grid_data:
			if p["nome"] == d_name:
				already = true
				break
				
		if not already and d_team != team_name and d_team != "" and d_team != "Free Agent":
			test_grid_data.append({
				"nome": d_name,
				"equipe": d_team,
				"pneu": ["Duro (C3)", "Médio (C4)", "Macio (C5)"][randi() % 3],
				"wear": randf_range(70.0, 100.0),
				"status": "Na Pista" if randf() > 0.3 else "Nos Boxes",
				"best_time": 999.0,
				"last_time": 0.0,
				"is_player": false,
				"driver_idx": -1,
				"ovr": float(d.get("Habilidade", d.get("Overall", 75)))
			})

func _rebuild_driver_control_boxes() -> void:
	if not is_instance_valid(driver_cards_container): return
	for c in driver_cards_container.get_children():
		c.queue_free()
		
	for i in range(selected_drivers.size()):
		var d = selected_drivers[i]
		if i >= driver_configs.size(): continue
		var cfg = driver_configs[i]
		
		var box = PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st = StyleBoxFlat.new()
		st.bg_color = Color(0.12, 0.15, 0.22, 0.95)
		st.set_corner_radius_all(4)
		st.border_width_left = 3
		st.border_color = team_color
		box.add_theme_stylebox_override("panel", st)
		
		var bm = MarginContainer.new()
		bm.add_theme_constant_override("margin_left", 10)
		bm.add_theme_constant_override("margin_right", 10)
		bm.add_theme_constant_override("margin_top", 6)
		bm.add_theme_constant_override("margin_bottom", 6)
		
		var bh = HBoxContainer.new()
		bh.add_theme_constant_override("separation", 10)
		
		var v_info = VBoxContainer.new()
		v_info.custom_minimum_size.x = 150
		var l_n = Label.new()
		l_n.text = "🏎️ " + str(d.get("Nome", "Piloto"))
		l_n.add_theme_font_size_override("font_size", 12)
		v_info.add_child(l_n)
		
		var l_st = Label.new()
		l_st.text = "Status: " + ("Na Pista 🟢" if cfg["on_track"] else "Nos Boxes 🔴")
		l_st.add_theme_font_size_override("font_size", 10)
		l_st.add_theme_color_override("font_color", Color("#34d399") if cfg["on_track"] else Color("#f87171"))
		v_info.add_child(l_st)
		bh.add_child(v_info)
		
		var opt_t = OptionButton.new()
		opt_t.add_item("Duro (C3)", 0)
		opt_t.add_item("Médio (C4)", 1)
		opt_t.add_item("Macio (C5)", 2)
		opt_t.select(1)
		var idx = i
		opt_t.item_selected.connect(func(sel_idx):
			driver_configs[idx]["pneu"] = ["Duro (C3)", "Médio (C4)", "Macio (C5)"][sel_idx]
			_sync_player_driver_to_grid(idx)
			_render_timing_table()
		)
		bh.add_child(opt_t)
		
		var btn_act = Button.new()
		btn_act.text = "🛑 RECOLHER BOXES" if cfg["on_track"] else "🚀 ENVIAR À PISTA"
		btn_act.add_theme_font_size_override("font_size", 11)
		btn_act.pressed.connect(func():
			driver_configs[idx]["on_track"] = not driver_configs[idx]["on_track"]
			if driver_configs[idx]["on_track"]:
				driver_configs[idx]["wear"] = 100.0
			_sync_player_driver_to_grid(idx)
			_rebuild_driver_control_boxes()
			_render_timing_table()
		)
		bh.add_child(btn_act)
		
		bm.add_child(bh)
		box.add_child(bm)
		driver_cards_container.add_child(box)

func _sync_player_driver_to_grid(driver_idx: int) -> void:
	if driver_idx >= driver_configs.size(): return
	var cfg = driver_configs[driver_idx]
	for item in test_grid_data:
		if item["is_player"] and item["driver_idx"] == driver_idx:
			item["pneu"] = cfg["pneu"]
			item["status"] = "Na Pista" if cfg["on_track"] else "Nos Boxes"
			item["wear"] = cfg["wear"]

func _render_timing_table() -> void:
	if not is_instance_valid(grid_container_vbox): return
	for c in grid_container_vbox.get_children():
		c.queue_free()
		
	test_grid_data.sort_custom(func(a, b): return a["best_time"] < b["best_time"])
	
	for i in range(test_grid_data.size()):
		var data = test_grid_data[i]
		var row = PanelContainer.new()
		var st_r = StyleBoxFlat.new()
		st_r.bg_color = Color(0.12, 0.15, 0.22, 0.95) if data["is_player"] else Color(0.08, 0.10, 0.15, 0.85)
		if data["is_player"]:
			st_r.border_width_left = 3
			st_r.border_color = team_color
		st_r.set_corner_radius_all(3)
		row.add_theme_stylebox_override("panel", st_r)
		
		var rm = MarginContainer.new()
		rm.add_theme_constant_override("margin_left", 8)
		rm.add_theme_constant_override("margin_right", 8)
		rm.add_theme_constant_override("margin_top", 4)
		rm.add_theme_constant_override("margin_bottom", 4)
		
		var rh = HBoxContainer.new()
		rh.add_theme_constant_override("separation", 8)
		
		_add_lbl(rh, "P%d" % (i + 1), 45, team_color if data["is_player"] else Color("#cbd5e1"))
		_add_lbl(rh, data["nome"], 180, Color("#ffffff"))
		_add_lbl(rh, data["equipe"], 150, Color("#94a3b8"))
		_add_lbl(rh, data["pneu"], 120, Color("#facc15") if "C5" in data["pneu"] else Color("#ffffff"))
		_add_lbl(rh, "%.0f%%" % data["wear"], 90, Color("#34d399") if data["wear"] > 60 else Color("#ef4444"))
		_add_lbl(rh, data["status"], 110, Color("#34d399") if data["status"] == "Na Pista" else Color("#f87171"))
		_add_lbl(rh, _format_lap_time(data["best_time"]), 120, Color("#fbbf24") if data["best_time"] < 990.0 else Color("#64748b"))
		_add_lbl(rh, _format_lap_time(data["last_time"]), 120, Color("#cbd5e1") if data["last_time"] > 0 else Color("#64748b"))
		
		rm.add_child(rh)
		row.add_child(rm)
		grid_container_vbox.add_child(row)

func _add_lbl(parent: HBoxContainer, text: String, width: float, color: Color) -> void:
	var l = Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)

func _format_lap_time(seconds: float) -> String:
	if seconds >= 990.0 or seconds <= 0:
		return " --:--.--- "
	var mins = int(seconds / 60.0)
	var secs = seconds - (mins * 60.0)
	return "%d:%06.3f" % [mins, secs]

func _on_simulate_laps_pressed() -> void:
	for item in test_grid_data:
		if item["status"] == "Na Pista":
			item["wear"] = clamp(item["wear"] - randf_range(3.0, 6.0), 5.0, 100.0)
			var base_lap = 91.5 - ((item["ovr"] - 75.0) * 0.08)
			if "C5" in item["pneu"]: base_lap -= 0.6
			elif "C3" in item["pneu"]: base_lap += 0.5
			
			var lap_time = base_lap + randf_range(-0.3, 0.7) + ((100.0 - item["wear"]) * 0.02)
			item["last_time"] = lap_time
			if lap_time < item["best_time"]:
				item["best_time"] = lap_time
				
			if item["wear"] <= 10.0:
				item["status"] = "Nos Boxes"
				if item["is_player"] and item["driver_idx"] < driver_configs.size():
					driver_configs[item["driver_idx"]]["on_track"] = false
					_rebuild_driver_control_boxes()
					
	_render_timing_table()
