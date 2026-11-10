extends Control

# Estado das Etapas:
# -1 = Seleção de Modo | 0 = Painel Unificado de Criação de Equipe | 3 = Testes de Inverno
var current_step: int = -1

# Negociação
var last_negotiation_warning: String = ""

# Dados da Equipe
var team_name: String = "Apex Grand Prix"
var boss_name: String = "Chefe da Equipe"
var team_color: Color = Color("#ef4444") # Cor padrão (Vermelho)
var initial_budget: int = 135
var remaining_budget: int = 135

# =============================================================
# NOVAS VARIÁVEIS DE TEMPO E PILOTAGEM PARA OS TESTES
# =============================================================
var session_time_left: float = 14400.0 # 4 horas em segundos (4 * 3600)
var time_speed: float = 1.0            # Multiplicador (1x, 5x, 10x, 50x)
var is_time_paused: bool = true        # Começa pausado para o jogador se preparar
var lap_tick_timer: float = 0.0        # Cronômetro interno para disparar voltas
var timing_refresh_elapsed: float = 0.0
var day_session_finish_handled: bool = false

# =============================================================
# NOVAS VARIÁVEIS DE P&D / EVOLUÇÃO DOS TESTES DE INVERNO
# =============================================================
var total_player_laps_completed: int = 0 # Contador total de voltas do jogador
var laps_since_last_upgrade: int = 0    # Contador de controle a cada 10 voltas

# Dicionário que guarda a evolução acumulada de cada equipe no grid
var team_testing_upgrades: Dictionary = {}

# Patrocinadores
var selected_sponsors: Array = [] # Lista de até 3 patrocinadores

# Seleções da Escuderia
var selected_drivers: Array = []
var selected_engine: Dictionary = {}
var selected_chassis: Dictionary = {}
var active_modal_window: Window

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

func _close_active_modal_window() -> void:
	if not is_instance_valid(active_modal_window):
		return
	active_modal_window.hide()
	active_modal_window.queue_free()
	active_modal_window = null

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
		# 1. Alimenta o gerador de números aleatórios do Godot
		randomize()
		
		# 2. Gera novos patrocinadores com valores inéditos para este Save
		Database.available_sponsors = Database.generate_dynamic_sponsors_for_new_save()
		
		# 3. Limpa seleções antigas para a nova jornada
		selected_sponsors.clear()
		selected_drivers.clear()
		selected_engine = {}
		selected_chassis = {}
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
	main_card.custom_minimum_size = Vector2(1150, 660)
	
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
	lbl_b_disp.text = "💰 ORÇAMENTO RESTANTE: $%.1fM" % remaining_budget
	lbl_b_disp.add_theme_font_size_override("font_size", 22)
	lbl_b_disp.add_theme_color_override("font_color", Color("#10b981") if remaining_budget >= 0 else Color("#ef4444"))
	head_hbox.add_child(lbl_b_disp)
	
	vbox.add_child(head_hbox)
	
	# Grid Principal em 2 Colunas
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 16)
	
	# 1. Nome da Equipe
	var v_tname = VBoxContainer.new()
	v_tname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_tn = Label.new()
	l_tn.text = "Nome da Equipe:"
	l_tn.add_theme_font_size_override("font_size", 16)
	v_tname.add_child(l_tn)
	var in_tn = LineEdit.new()
	in_tn.text = team_name
	in_tn.custom_minimum_size.y = 42
	in_tn.add_theme_font_size_override("font_size", 16)
	in_tn.text_changed.connect(func(new_text): team_name = new_text)
	v_tname.add_child(in_tn)
	grid.add_child(v_tname)
	
	# 2. Chefe de Equipe
	var v_bname = VBoxContainer.new()
	v_bname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_bn = Label.new()
	l_bn.text = "Nome do Chefe de Equipe:"
	l_bn.add_theme_font_size_override("font_size", 16)
	v_bname.add_child(l_bn)
	var in_bn = LineEdit.new()
	in_bn.text = boss_name
	in_bn.custom_minimum_size.y = 42
	in_bn.add_theme_font_size_override("font_size", 16)
	in_bn.text_changed.connect(func(new_text): boss_name = new_text)
	v_bname.add_child(in_bn)
	grid.add_child(v_bname)
	
	# 3. Cor da Equipe
	var v_color = VBoxContainer.new()
	v_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_col = Label.new()
	l_col.text = "Cor Oficial da Escuderia:"
	l_col.add_theme_font_size_override("font_size", 16)
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
	
	# Espaço Reservado no Grid
	grid.add_child(Control.new())
	
	vbox.add_child(grid)
	
	# ---------------------------------------------------------
	# BLOCOS DE CARDS SELECIONADOS (PILOTOS, MOTOR E CHASSI)
	# ---------------------------------------------------------
	var cards_vbox = VBoxContainer.new()
	cards_vbox.add_theme_constant_override("separation", 12)
	
	# --- PAINEL DE PILOTOS TITULARES ---
	var p_drv = VBoxContainer.new()
	var l_drv_head = Label.new()
	l_drv_head.text = "Pilotos Titulares (%d/2):" % selected_drivers.size()
	l_drv_head.add_theme_font_size_override("font_size", 16)
	p_drv.add_child(l_drv_head)
	
	var drv_hbox = HBoxContainer.new()
	drv_hbox.add_theme_constant_override("separation", 12)
	
	for i in range(selected_drivers.size()):
		var d = selected_drivers[i]
		var d_name = d.get("Nome", d.get("nome", "Piloto"))
		var d_ovr = int(d.get("Habilidade", d.get("Overall", 75)))
		var d_sal = float(d.get("salario", 8.0))
		var d_yrs = int(d.get("anos_contratados", d.get("anos_pedidos", 1)))
		
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st_c = StyleBoxFlat.new()
		st_c.bg_color = Color("#1e293b")
		st_c.border_width_left = 4
		st_c.border_color = team_color
		st_c.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", st_c)
		
		var cm = MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 12)
		cm.add_theme_constant_override("margin_right", 12)
		cm.add_theme_constant_override("margin_top", 8)
		cm.add_theme_constant_override("margin_bottom", 8)
		
		var ch = HBoxContainer.new()
		var cv = VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var l_n = Label.new()
		l_n.text = "🏎️ " + d_name
		l_n.add_theme_font_size_override("font_size", 15)
		cv.add_child(l_n)
		
		var l_i = Label.new()
		l_i.text = "⚡ %d OVR  |  💰 $%.1fM/ano  |  ⏳ %d ano(s)" % [d_ovr, d_sal, d_yrs]
		l_i.add_theme_font_size_override("font_size", 12)
		l_i.add_theme_color_override("font_color", Color("#cbd5e1"))
		cv.add_child(l_i)
		ch.add_child(cv)
		
		# Botão X para Cancelar Piloto
		var btn_rm = Button.new()
		btn_rm.text = " ✕ "
		btn_rm.custom_minimum_size = Vector2(32, 32)
		btn_rm.add_theme_font_size_override("font_size", 14)
		var st_x = StyleBoxFlat.new()
		st_x.bg_color = Color("#dc2626")
		st_x.set_corner_radius_all(4)
		btn_rm.add_theme_stylebox_override("normal", st_x)
		
		var driver_ref = d
		btn_rm.pressed.connect(func():
			selected_drivers.erase(driver_ref)
			_recalculate_budget()
			_render_current_step()
		)
		ch.add_child(btn_rm)
		
		cm.add_child(ch)
		card.add_child(cm)
		drv_hbox.add_child(card)
		
	if selected_drivers.size() < 2:
		var btn_add_drv = Button.new()
		btn_add_drv.text = "👥 SELECIONAR PILOTO %d..." % (selected_drivers.size() + 1)
		btn_add_drv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_add_drv.custom_minimum_size.y = 48
		btn_add_drv.add_theme_font_size_override("font_size", 15)
		btn_add_drv.pressed.connect(_open_driver_modal)
		drv_hbox.add_child(btn_add_drv)
		
	p_drv.add_child(drv_hbox)
	cards_vbox.add_child(p_drv)
	
	# --- CARD DE PATROCINADORES OFICIAIS (0/3) ---
	var p_sp = VBoxContainer.new()
	var l_sp_head = Label.new()
	l_sp_head.text = "Patrocinadores Oficiais (%d/3):" % selected_sponsors.size()
	l_sp_head.add_theme_font_size_override("font_size", 16)
	p_sp.add_child(l_sp_head)
	
	var sp_card = PanelContainer.new()
	sp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_sp = StyleBoxFlat.new()
	st_sp.bg_color = Color("#1e293b")
	st_sp.border_width_left = 4
	st_sp.border_color = Color("#38bdf8") # Cor Azul Claro
	st_sp.set_corner_radius_all(6)
	sp_card.add_theme_stylebox_override("panel", st_sp)
	
	var sp_margin = MarginContainer.new()
	sp_margin.add_theme_constant_override("margin_left", 12)
	sp_margin.add_theme_constant_override("margin_right", 12)
	sp_margin.add_theme_constant_override("margin_top", 8)
	sp_margin.add_theme_constant_override("margin_bottom", 8)
	
	var sp_hbox = HBoxContainer.new()
	sp_hbox.add_theme_constant_override("separation", 10)
	
	var sp_vbox = VBoxContainer.new()
	sp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var l_sp_desc = Label.new()
	if selected_sponsors.is_empty():
		l_sp_desc.text = "Nenhum patrocinador assinado. Clique ao lado para contratar até 3 marcas."
		l_sp_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	else:
		var sp_names = []
		var total_advance = 0.0
		for sp in selected_sponsors:
			sp_names.append(sp["nome"])
			total_advance += sp.get("valor_temporada", 0.0)
		l_sp_desc.text = "Contratados: " + ", ".join(sp_names) + " (+$%.1fM Adiantados no Caixa)" % total_advance
		l_sp_desc.add_theme_color_override("font_color", Color("#22c55e"))
		
	l_sp_desc.add_theme_font_size_override("font_size", 13)
	sp_vbox.add_child(l_sp_desc)
	sp_hbox.add_child(sp_vbox)
	
	var btn_select_sp = Button.new()
	btn_select_sp.text = "🤝 GERENCIAR PATROCÍNIOS..."
	btn_select_sp.custom_minimum_size = Vector2(210, 40)
	btn_select_sp.pressed.connect(func():
		_open_sponsors_selection_modal()
	)
	sp_hbox.add_child(btn_select_sp)
	
	sp_margin.add_child(sp_hbox)
	sp_card.add_child(sp_margin)
	p_sp.add_child(sp_card)
	
	cards_vbox.add_child(p_sp) # Adiciona no layout vertical principal de cards
	
	# --- LINHA MOTOR E CHASSI ---
	var me_hbox = HBoxContainer.new()
	me_hbox.add_theme_constant_override("separation", 20)
	
	# Card de Motor
	var v_eng = VBoxContainer.new()
	v_eng.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_eng_h = Label.new()
	l_eng_h.text = "Unidade de Potência (Motor):"
	l_eng_h.add_theme_font_size_override("font_size", 16)
	v_eng.add_child(l_eng_h)
	
	if selected_engine.is_empty():
		var btn_eng = Button.new()
		btn_eng.text = "⚙️ SELECIONAR MOTOR..."
		btn_eng.custom_minimum_size.y = 48
		btn_eng.add_theme_font_size_override("font_size", 15)
		btn_eng.pressed.connect(_open_engine_modal)
		v_eng.add_child(btn_eng)
	else:
		var card_e = PanelContainer.new()
		var st_ce = StyleBoxFlat.new()
		st_ce.bg_color = Color("#1e293b")
		st_ce.border_width_left = 4
		st_ce.border_color = Color("#38bdf8")
		st_ce.set_corner_radius_all(6)
		card_e.add_theme_stylebox_override("panel", st_ce)
		
		var em = MarginContainer.new()
		em.add_theme_constant_override("margin_left", 12)
		em.add_theme_constant_override("margin_right", 12)
		em.add_theme_constant_override("margin_top", 8)
		em.add_theme_constant_override("margin_bottom", 8)
		
		var eh = HBoxContainer.new()
		var ev = VBoxContainer.new()
		ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var l_en = Label.new()
		l_en.text = "⚙️ " + selected_engine.get("nome", "Motor")
		l_en.add_theme_font_size_override("font_size", 15)
		ev.add_child(l_en)
		
		var l_ei = Label.new()
		l_ei.text = "Potência: %d  |  Custo: $%dM" % [selected_engine.get("potencia", 85), selected_engine.get("preco", 0)]
		l_ei.add_theme_font_size_override("font_size", 12)
		l_ei.add_theme_color_override("font_color", Color("#cbd5e1"))
		ev.add_child(l_ei)
		eh.add_child(ev)
		
		var btn_x_e = Button.new()
		btn_x_e.text = " ✕ "
		btn_x_e.custom_minimum_size = Vector2(32, 32)
		var st_xe = StyleBoxFlat.new()
		st_xe.bg_color = Color("#dc2626")
		st_xe.set_corner_radius_all(4)
		btn_x_e.add_theme_stylebox_override("normal", st_xe)
		btn_x_e.pressed.connect(func():
			selected_engine = {}
			_recalculate_budget()
			_render_current_step()
		)
		eh.add_child(btn_x_e)
		em.add_child(eh)
		card_e.add_child(em)
		v_eng.add_child(card_e)
		
	me_hbox.add_child(v_eng)
	
	# Card de Chassi
	var v_cha = VBoxContainer.new()
	v_cha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l_cha_h = Label.new()
	l_cha_h.text = "Pacote Aerodinâmico / Chassi:"
	l_cha_h.add_theme_font_size_override("font_size", 16)
	v_cha.add_child(l_cha_h)
	
	if selected_chassis.is_empty():
		var btn_cha = Button.new()
		btn_cha.text = "🏎️ SELECIONAR CHASSI..."
		btn_cha.custom_minimum_size.y = 48
		btn_cha.add_theme_font_size_override("font_size", 15)
		btn_cha.pressed.connect(_open_chassis_modal)
		v_cha.add_child(btn_cha)
	else:
		var card_c = PanelContainer.new()
		var st_cc = StyleBoxFlat.new()
		st_cc.bg_color = Color("#1e293b")
		st_cc.border_width_left = 4
		st_cc.border_color = Color("#fbbf24")
		st_cc.set_corner_radius_all(6)
		card_c.add_theme_stylebox_override("panel", st_cc)
		
		var cm_c = MarginContainer.new()
		cm_c.add_theme_constant_override("margin_left", 12)
		cm_c.add_theme_constant_override("margin_right", 12)
		cm_c.add_theme_constant_override("margin_top", 8)
		cm_c.add_theme_constant_override("margin_bottom", 8)
		
		var ch_c = HBoxContainer.new()
		var cv_c = VBoxContainer.new()
		cv_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var l_cn = Label.new()
		l_cn.text = "🏎️ " + selected_chassis.get("nome", "Chassi")
		l_cn.add_theme_font_size_override("font_size", 15)
		cv_c.add_child(l_cn)
		
		var c_aero = selected_chassis.get("aero", 85)
		var c_res = selected_chassis.get("resistencia", 85)
		var c_peso = selected_chassis.get("peso", 790.0)
		var c_prc = selected_chassis.get("preco", 15.0)
		
		var l_ci = Label.new()
		l_ci.text = "Aero: %d%%  |  Resistência: %d%%  |  Peso: %.1fkg  |  Custo: $%.1fM" % [c_aero, c_res, c_peso, c_prc]
		l_ci.add_theme_font_size_override("font_size", 12)
		l_ci.add_theme_color_override("font_color", Color("#cbd5e1"))
		cv_c.add_child(l_ci)
		ch_c.add_child(cv_c)
		
		var btn_x_c = Button.new()
		btn_x_c.text = " ✕ "
		btn_x_c.custom_minimum_size = Vector2(32, 32)
		var st_xc = StyleBoxFlat.new()
		st_xc.bg_color = Color("#dc2626")
		st_xc.set_corner_radius_all(4)
		btn_x_c.add_theme_stylebox_override("normal", st_xc)
		btn_x_c.pressed.connect(func():
			selected_chassis = {}
			_recalculate_budget()
			_render_current_step()
		)
		ch_c.add_child(btn_x_c)
		cm_c.add_child(ch_c)
		card_c.add_child(cm_c)
		v_cha.add_child(card_c)
		
	me_hbox.add_child(v_cha)
	cards_vbox.add_child(me_hbox)
	
	vbox.add_child(cards_vbox)
	
	# Espaçador Flexível
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Botões Inferiores
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 20)
	
	var btn_confirm = Button.new()
	btn_confirm.text = "🏁 FINALIZAR EQUIPE E IR PARA OS TESTES ▶"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 52
	btn_confirm.add_theme_font_size_override("font_size", 18)
	
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
		_sync_hired_drivers_to_global_database()
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
	var base_starting_budget = 100.0 # $100M orçamento base de criação
	
	# 1. Soma os patrocínios de temporada contratados
	var sponsor_bonus = 0.0
	for sp in selected_sponsors:
		sponsor_bonus += sp.get("valor_temporada", 0.0)
		
	var total_initial_funds = base_starting_budget + sponsor_bonus
	
	# 2. Subtrai os custos de contratação (Pilotos, Motor e Chassi)
	var drivers_cost = 0.0
	for d in selected_drivers:
		drivers_cost += d.get("salario", 0.0)
		
	var engine_cost = selected_engine.get("preco", 0.0)
	var chassis_cost = selected_chassis.get("preco", 0.0)
	
	remaining_budget = total_initial_funds - (drivers_cost + engine_cost + chassis_cost)

## Atualiza os textos de orçamento e a mensagem dos patrocinadores contratados
func atualizar_interface_criacao() -> void:
	_recalculate_budget()
	
	# Sincroniza a lista local com o que foi assinado no banco de dados temporário
	if Database.user_team.has("patrocinadores") and not Database.user_team["patrocinadores"].is_empty():
		selected_sponsors = Database.user_team["patrocinadores"].duplicate()
		
	# Redesenha a etapa atual para atualizar os textos de "Contratados: Marc1, Marc2..."
	_render_current_step()

# =============================================================
# MODAIS DE SELEÇÃO (PILOTOS, MOTORES E CHASSIS)
# =============================================================

# =============================================================
# 1. TABELA DE PILOTOS (COM VERIFICAÇÃO DE CHANCE DE INTERESSE)
# =============================================================
func _open_driver_modal() -> void:
	_close_active_modal_window()
	var dialog = Window.new()
	dialog.title = "🏎️ MERCADO DE PILOTOS - TABELA DE NEGOCIAÇÃO"
	dialog.size = Vector2i(1050, 660)
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
	main_vbox.add_theme_constant_override("separation", 14)
	
	# Cabeçalho da Janela
	var l_head = Label.new()
	l_head.text = "📋 PILOTOS DISPONÍVEIS PARA A TEMPORADA"
	l_head.add_theme_font_size_override("font_size", 18)
	l_head.add_theme_color_override("font_color", Color("#ef4444"))
	main_vbox.add_child(l_head)
	
	# BANNER DE AVISO DE RECUSA (Aparece em Vermelho Destaque)
	if not last_negotiation_warning.is_empty():
		var warn_box = PanelContainer.new()
		var st_w = StyleBoxFlat.new()
		st_w.bg_color = Color(0.8, 0.1, 0.1, 0.25) # Fundo vermelho transparente
		st_w.border_width_left = 4
		st_w.border_color = Color("#ef4444")
		st_w.set_corner_radius_all(4)
		warn_box.add_theme_stylebox_override("panel", st_w)
		
		var wm = MarginContainer.new()
		wm.add_theme_constant_override("margin_left", 12)
		wm.add_theme_constant_override("margin_right", 12)
		wm.add_theme_constant_override("margin_top", 8)
		wm.add_theme_constant_override("margin_bottom", 8)
		
		var l_warn = Label.new()
		l_warn.text = "⚠️ " + last_negotiation_warning
		l_warn.add_theme_font_size_override("font_size", 14)
		l_warn.add_theme_color_override("font_color", Color("#f87171"))
		wm.add_child(l_warn)
		warn_box.add_child(wm)
		main_vbox.add_child(warn_box)
	
	# Cabeçalho da Tabela
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
		
		# SORTEIO DE SALÁRIO E EXIGÊNCIAS ÚNICAS PARA ESTE SAVE
		if not d.has("salario") or d.get("salario", 0.0) == 0.0:
			# Calcula um salário base com base na habilidade (OVR)
			var base_salary = (d_ovr - 70) * 1.2 + 4.0
			
			# Variação de mercado aleatória para cada partida (-20% até +25%)
			var market_multiplier = randf_range(0.80, 1.25)
			d["salario"] = clamp(snapped(base_salary * market_multiplier, 0.1), 2.5, 38.0)
			
		if not d.has("anos_pedidos"):
			# Duração de contrato sorteada (1 a 3 anos)
			d["anos_pedidos"] = randi_range(1, 3)
		if not d.has("status_pedido"):
			d["status_pedido"] = "1º Piloto" if d_ovr >= 88 else "Piloto Igualitário"
		if not d.has("tentativas_restantes"):
			d["tentativas_restantes"] = 3
		if not d.has("inegociavel"):
			d["inegociavel"] = false
			
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
		
		# Pedida
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
		elif d["inegociavel"]:
			btn_neg.text = "🔒 INEGOCIÁVEL"
			btn_neg.disabled = true
			var st_dis = StyleBoxFlat.new()
			st_dis.bg_color = Color("#334155")
			st_dis.set_corner_radius_all(4)
			btn_neg.add_theme_stylebox_override("disabled", st_dis)
		else:
			btn_neg.text = "NEGOCIAR 🤝"
			var st_g = StyleBoxFlat.new()
			st_g.bg_color = Color("#16a34a")
			st_g.set_corner_radius_all(4)
			btn_neg.add_theme_stylebox_override("normal", st_g)
			
			btn_neg.pressed.connect(func():
				# Cálculo da Chance de Recusa
				var chance_recusa = 3.0 + ((float(d_ovr) - 70.0) / (96.0 - 70.0)) * (98.0 - 3.0)
				chance_recusa = clamp(chance_recusa, 3.0, 98.0)
				
				var sorteio = randf() * 100.0
				
				if sorteio < chance_recusa:
					# DEFINE A MENSAGEM SOLICITADA
					d["inegociavel"] = true
					last_negotiation_warning = "%s não tem interesse em negociar com uma nova equipe." % d_name
					dialog.hide()
					dialog.queue_free()
					call_deferred("_open_driver_modal")
				else:
					last_negotiation_warning = "" # Limpa qualquer aviso antigo ao abrir mesa
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
	btn_close.pressed.connect(func():
		last_negotiation_warning = "" # Limpa a mensagem ao fechar a tabela
		dialog.queue_free()
	)
	main_vbox.add_child(btn_close)
	
	margin.add_child(main_vbox)
	dialog.add_child(margin)
	add_child(dialog)
	active_modal_window = dialog
	dialog.popup_centered()

# =============================================================
# 2. MESA DE NEGOCIAÇÃO (CONTADOR DE 3 TENTATIVAS)
# =============================================================
func _open_negotiation_dialog(driver: Dictionary) -> void:
	_close_active_modal_window()
	var dialog = Window.new()
	var d_name = driver.get("Nome", "Piloto")
	dialog.title = "🤝 MESA DE NEGOCIAÇÃO - " + d_name.to_upper()
	dialog.size = Vector2i(850, 560)
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
	vbox.add_theme_constant_override("separation", 18)
	
	# Cabeçalho com Tentativas Restantes
	var head_hb = HBoxContainer.new()
	
	var l_title = Label.new()
	l_title.text = "PROPOSTA DE CONTRATO FOR " + d_name.to_upper()
	l_title.add_theme_font_size_override("font_size", 20)
	l_title.add_theme_color_override("font_color", Color("#ef4444"))
	l_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_hb.add_child(l_title)
	
	var l_att = Label.new()
	l_att.text = "⏳ Tentativas Restantes: %d/3" % driver["tentativas_restantes"]
	l_att.add_theme_font_size_override("font_size", 16)
	l_att.add_theme_color_override("font_color", Color("#fbbf24") if driver["tentativas_restantes"] > 1 else Color("#ef4444"))
	head_hb.add_child(l_att)
	
	vbox.add_child(head_hb)
	
	var body_hbox = HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 25)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Exigências do Piloto
	var left_card = PanelContainer.new()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_l = StyleBoxFlat.new()
	st_l.bg_color = Color("#1e293b")
	st_l.set_corner_radius_all(8)
	st_l.border_width_left = 4
	st_l.border_color = Color("#fbbf24")
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
	
	# Oferta da Equipe
	var right_card = PanelContainer.new()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_r = StyleBoxFlat.new()
	st_r.bg_color = Color("#1e293b")
	st_r.set_corner_radius_all(8)
	st_r.border_width_left = 4
	st_r.border_color = Color("#2563eb")
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
	
	var v_s = VBoxContainer.new()
	var l_s = Label.new()
	l_s.text = "Salário Oferecido ($M / ano):"
	l_s.add_theme_font_size_override("font_size", 13)
	v_s.add_child(l_s)
	
	var spin_salary = SpinBox.new()
	spin_salary.min_value = 1.0
	spin_salary.max_value = 50.0
	spin_salary.step = 0.1
	spin_salary.value = req_val
	spin_salary.custom_minimum_size.y = 38
	v_s.add_child(spin_salary)
	rv.add_child(v_s)
	
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
	
	var lbl_feedback = Label.new()
	lbl_feedback.text = ""
	lbl_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_feedback.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_feedback)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	
	var btn_send = Button.new()
	btn_send.text = "🤝 ENVIAR PROPOSTA"
	btn_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_send.custom_minimum_size.y = 44
	btn_send.add_theme_font_size_override("font_size", 14)
	var st_b = StyleBoxFlat.new()
	st_b.bg_color = Color("#16a34a")
	st_b.set_corner_radius_all(4)
	btn_send.add_theme_stylebox_override("normal", st_b)
	
	btn_send.pressed.connect(func():
		var offered_salary = spin_salary.value
		var offered_years = opt_years.get_selected_id()
		var offered_status_idx = opt_status.selected
		
		var min_acceptable_salary = req_val * 0.92
		if offered_status_idx == 0 and req_status != "1º Piloto":
			min_acceptable_salary *= 0.95
		if offered_years > req_years:
			min_acceptable_salary *= 0.97
			
		if offered_salary >= min_acceptable_salary:
			lbl_feedback.text = "✅ O piloto ACEITOU sua proposta de contrato!"
			lbl_feedback.add_theme_color_override("font_color", Color("#10b981"))
			
			driver["salario"] = offered_salary
			if not selected_drivers.has(driver):
				if selected_drivers.size() < 2:
					selected_drivers.append(driver)
					
			_recalculate_budget()
			await get_tree().create_timer(1.2).timeout
			dialog.queue_free()
			_render_current_step()
		else:
			# DEDUZ 1 TENTATIVA
			driver["tentativas_restantes"] -= 1
			l_att.text = "⏳ Tentativas Restantes: %d/3" % driver["tentativas_restantes"]
			
			if driver["tentativas_restantes"] <= 0:
				# TENTATIVAS AGOTADAS -> FICA INEGOCIÁVEL
				driver["inegociavel"] = true
				lbl_feedback.text = "❌ Proposta recusada! O piloto PERDEU O INTERESSE e encerrou as negociações!"
				lbl_feedback.add_theme_color_override("font_color", Color("#ef4444"))
				btn_send.disabled = true
				
				await get_tree().create_timer(2.0).timeout
				dialog.hide()
				dialog.queue_free()
				call_deferred("_open_driver_modal")
			else:
				lbl_feedback.text = "❌ Proposta recusada! Tentativas restantes: %d/3." % driver["tentativas_restantes"]
				lbl_feedback.add_theme_color_override("font_color", Color("#f59e0b"))
	)
	btn_hbox.add_child(btn_send)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "CANCELAR"
	btn_cancel.custom_minimum_size = Vector2(160, 44)
	btn_cancel.add_theme_font_size_override("font_size", 14)
	btn_cancel.pressed.connect(func():
		dialog.hide()
		dialog.queue_free()
		call_deferred("_open_driver_modal")
	)
	btn_hbox.add_child(btn_cancel)
	
	vbox.add_child(btn_hbox)
	margin.add_child(vbox)
	dialog.add_child(margin)
	add_child(dialog)
	active_modal_window = dialog
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
	_close_active_modal_window()
	var dialog = Window.new()
	dialog.title = "⚙️ MERCADO DE UNIDADES DE POTÊNCIA - F1 2026"
	dialog.size = Vector2i(1050, 660)
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
	
	# Cabeçalho
	var l_head = Label.new()
	l_head.text = "📋 FORNECEDORES DE MOTOR DISPONÍVEIS OU FABRICAÇÃO PRÓPRIA"
	l_head.add_theme_font_size_override("font_size", 18)
	l_head.add_theme_color_override("font_color", Color("#ef4444"))
	main_vbox.add_child(l_head)
	
	# Cabeçalho da Tabela
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
	
	_add_modal_th(th_hbox, "FORNECEDOR / MOTOR", 280)
	_add_modal_th(th_hbox, "POTÊNCIA", 120)
	_add_modal_th(th_hbox, "CONFIABILIDADE", 150)
	_add_modal_th(th_hbox, "CUSTO ANUAL", 200)
	_add_modal_th(th_hbox, "AÇÃO", 150)
	
	th_m.add_child(th_hbox)
	th_box.add_child(th_m)
	main_vbox.add_child(th_box)
	
	# Lista com Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var rows_vbox = VBoxContainer.new()
	rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vbox.add_theme_constant_override("separation", 6)
	
	var engines = [
		{"nome": "Red Bull Ford Powertrains", "potencia": 91, "confiabilidade": 88, "preco": 25.0},
		{"nome": "Ferrari Power Unit 066/12", "potencia": 90, "confiabilidade": 89, "preco": 22.5},
		{"nome": "Mercedes-AMG F1 M15 E Performance", "potencia": 88, "confiabilidade": 93, "preco": 20.0},
		{"nome": "Honda RBPT HRC", "potencia": 87, "confiabilidade": 90, "preco": 18.5},
		{"nome": "Audi Revolut F1 Power", "potencia": 85, "confiabilidade": 84, "preco": 15.0}
	]
	
	engines.sort_custom(func(a, b): return a["potencia"] > b["potencia"])
	
	for eng in engines:
		var row = PanelContainer.new()
		var st_r = StyleBoxFlat.new()
		
		var is_selected = (selected_engine.get("nome", "") == eng["nome"])
		st_r.bg_color = Color("#1e293b") if is_selected else Color("#0f172a")
		if is_selected:
			st_r.border_width_left = 5
			st_r.border_color = Color("#38bdf8")
		st_r.set_corner_radius_all(4)
		row.add_theme_stylebox_override("panel", st_r)
		
		var rm = MarginContainer.new()
		rm.add_theme_constant_override("margin_left", 14)
		rm.add_theme_constant_override("margin_right", 14)
		rm.add_theme_constant_override("margin_top", 8)
		rm.add_theme_constant_override("margin_bottom", 8)
		
		var rh = HBoxContainer.new()
		rh.add_theme_constant_override("separation", 12)
		
		var l_n = Label.new()
		l_n.text = eng["nome"]
		l_n.custom_minimum_size.x = 280
		l_n.add_theme_font_size_override("font_size", 15)
		rh.add_child(l_n)
		
		var l_p = Label.new()
		l_p.text = "⚡ %d HP" % eng["potencia"]
		l_p.custom_minimum_size.x = 120
		l_p.add_theme_font_size_override("font_size", 14)
		l_p.add_theme_color_override("font_color", Color("#fbbf24") if eng["potencia"] >= 90 else Color("#cbd5e1"))
		rh.add_child(l_p)
		
		var l_c = Label.new()
		l_c.text = "🛡️ %d%%" % eng["confiabilidade"]
		l_c.custom_minimum_size.x = 150
		l_c.add_theme_font_size_override("font_size", 14)
		l_c.add_theme_color_override("font_color", Color("#34d399") if eng["confiabilidade"] >= 90 else Color("#cbd5e1"))
		rh.add_child(l_c)
		
		var l_v = Label.new()
		l_v.text = "💰 $%.1fM / ano" % eng["preco"]
		l_v.custom_minimum_size.x = 200
		l_v.add_theme_font_size_override("font_size", 15)
		l_v.add_theme_color_override("font_color", Color("#10b981"))
		rh.add_child(l_v)
		
		var btn_sel = Button.new()
		btn_sel.custom_minimum_size = Vector2(150, 38)
		btn_sel.add_theme_font_size_override("font_size", 13)
		
		if is_selected:
			btn_sel.text = "SELECIONADO"
			btn_sel.disabled = true
			var st_dis = StyleBoxFlat.new()
			st_dis.bg_color = Color("#2563eb")
			st_dis.set_corner_radius_all(4)
			btn_sel.add_theme_stylebox_override("disabled", st_dis)
		else:
			btn_sel.text = "SELECIONAR ⚙️"
			var st_g = StyleBoxFlat.new()
			st_g.bg_color = Color("#16a34a")
			st_g.set_corner_radius_all(4)
			btn_sel.add_theme_stylebox_override("normal", st_g)
			
			btn_sel.pressed.connect(func():
				selected_engine = eng
				_recalculate_budget()
				dialog.queue_free()
				_render_current_step()
			)
			
		rh.add_child(btn_sel)
		rm.add_child(rh)
		row.add_child(rm)
		rows_vbox.add_child(row)
		
	scroll.add_child(rows_vbox)
	main_vbox.add_child(scroll)
	
	# RODAPÉ COM O BOTÃO LARANJA "CRIAR MOTOR PRÓPRIO"
	var foot_hbox = HBoxContainer.new()
	foot_hbox.add_theme_constant_override("separation", 16)
	
	var btn_create_custom = Button.new()
	btn_create_custom.text = "🛠️ CRIAR MOTOR PRÓPRIO (FABRICANTE)"
	btn_create_custom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_create_custom.custom_minimum_size.y = 46
	btn_create_custom.add_theme_font_size_override("font_size", 15)
	
	var st_orange = StyleBoxFlat.new()
	st_orange.bg_color = Color("#f97316") # Laranja Vibrante
	st_orange.set_corner_radius_all(6)
	btn_create_custom.add_theme_stylebox_override("normal", st_orange)
	
	btn_create_custom.pressed.connect(func():
		dialog.queue_free()
		_open_custom_engine_builder_modal()
	)
	foot_hbox.add_child(btn_create_custom)
	
	var btn_close = Button.new()
	btn_close.text = "FECHAR TABELA"
	btn_close.custom_minimum_size = Vector2(160, 46)
	btn_close.add_theme_font_size_override("font_size", 15)
	btn_close.pressed.connect(func(): dialog.queue_free())
	foot_hbox.add_child(btn_close)
	
	main_vbox.add_child(foot_hbox)
	
	margin.add_child(main_vbox)
	dialog.add_child(margin)
	add_child(dialog)
	active_modal_window = dialog
	dialog.popup_centered()

# =============================================================
# JANELA DE CONFIGURAÇÃO DE MOTOR PRÓPRIO (POTÊNCIA vs CONFIABILIDADE vs CUSTO)
# =============================================================
func _open_custom_engine_builder_modal() -> void:
	_close_active_modal_window()
	var dialog = Window.new()
	dialog.title = "🛠️ ENGENHARIA DE MOTORES - ESCUDERIA PROPRIETÁRIA"
	dialog.size = Vector2i(850, 600)
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
	
	# Título
	var l_title = Label.new()
	l_title.text = "⚙️ PROJETAR NOVO MOTOR (" + team_name.to_upper() + " POWER)"
	l_title.add_theme_font_size_override("font_size", 20)
	l_title.add_theme_color_override("font_color", Color("#f97316"))
	vbox.add_child(l_title)
	
	var card = PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st_card = StyleBoxFlat.new()
	st_card.bg_color = Color("#1e293b")
	st_card.set_corner_radius_all(8)
	st_card.border_width_left = 5
	st_card.border_color = Color("#f97316")
	card.add_theme_stylebox_override("panel", st_card)
	
	var cm = MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 20)
	cm.add_theme_constant_override("margin_right", 20)
	cm.add_theme_constant_override("margin_top", 20)
	cm.add_theme_constant_override("margin_bottom", 20)
	
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 18)
	
	# Nome do Motor
	var v_name = VBoxContainer.new()
	var l_nm = Label.new()
	l_nm.text = "Nome Oficial do Motor:"
	l_nm.add_theme_font_size_override("font_size", 14)
	v_name.add_child(l_nm)
	
	var in_engine_name = LineEdit.new()
	in_engine_name.text = team_name + " Power V6 Turbo"
	in_engine_name.custom_minimum_size.y = 40
	in_engine_name.add_theme_font_size_override("font_size", 15)
	v_name.add_child(in_engine_name)
	cv.add_child(v_name)
	
	# VARIÁVEIS DE ESTADO INTERNO
	var last_pow: float = 88.0
	var last_rel: float = 87.0
	var is_updating: bool = false
	
	# 1. CONTROLE DE POTÊNCIA (SLIDER 1)
	var v_pow = VBoxContainer.new()
	var l_pow = Label.new()
	l_pow.add_theme_font_size_override("font_size", 15)
	v_pow.add_child(l_pow)
	
	var slider_pow = HSlider.new()
	slider_pow.min_value = 75.0
	slider_pow.max_value = 98.0
	slider_pow.step = 1.0
	slider_pow.value = last_pow
	v_pow.add_child(slider_pow)
	cv.add_child(v_pow)
	
	# 2. CONTROLE DE CONFIABILIDADE (SLIDER 2)
	var v_rel = VBoxContainer.new()
	var l_rel = Label.new()
	l_rel.add_theme_font_size_override("font_size", 15)
	v_rel.add_child(l_rel)
	
	var slider_rel = HSlider.new()
	slider_rel.min_value = 75.0
	slider_rel.max_value = 98.0
	slider_rel.step = 1.0
	slider_rel.value = last_rel
	v_rel.add_child(slider_rel)
	cv.add_child(v_rel)
	
	# Exibição do Custo
	var l_cost = Label.new()
	l_cost.add_theme_font_size_override("font_size", 16)
	l_cost.add_theme_color_override("font_color", Color("#10b981"))
	cv.add_child(l_cost)
	
	# Função para atualizar textos, cores e preço com a taxa de +5%
	var refresh_display = func():
		var p_val = slider_pow.value
		var r_val = slider_rel.value
		
		l_pow.text = "⚡ Potência: %d%%" % p_val
		l_rel.text = "🛡️ Confiabilidade: %d%%" % r_val
		
		l_pow.add_theme_color_override("font_color", Color("#fbbf24") if p_val >= 90 else Color("#ffffff"))
		l_rel.add_theme_color_override("font_color", Color("#34d399") if r_val >= 88 else Color("#f87171"))
		
		# Custo base proporcional
		var base_cost = 12.0
		var pow_cost = max(0.0, (p_val - 75.0) * 0.5)
		var rel_cost = max(0.0, (r_val - 75.0) * 0.4)
		var raw_total_cost = base_cost + pow_cost + rel_cost
		
		# -------------------------------------------------------------
		# APLICAÇÃO DO BÔNUS DE +5% DE CUSTO DE FABRICAÇÃO PRÓPRIA (P&D)
		# -------------------------------------------------------------
		var total_cost = raw_total_cost * 1.05
		
		l_cost.text = "💰 Custo Total: $%.1fM" % total_cost

	# LÓGICA DO SLIDER DE POTÊNCIA
	slider_pow.value_changed.connect(func(new_pow):
		if is_updating: return
		is_updating = true
		
		if new_pow > last_pow:
			var increase = new_pow - last_pow
			var penalty = increase * 0.5 # Proporção de 2% para 1%
			slider_rel.value = clamp(slider_rel.value - penalty, slider_rel.min_value, slider_rel.max_value)
		
		last_pow = new_pow
		last_rel = slider_rel.value
		refresh_display.call()
		is_updating = false
	)
	
	# LÓGICA DO SLIDER DE CONFIABILIDADE
	slider_rel.value_changed.connect(func(new_rel):
		if is_updating: return
		is_updating = true
		
		if new_rel > last_rel:
			var increase = new_rel - last_rel
			var penalty = increase * 0.5 # Proporção de 2% para 1%
			slider_pow.value = clamp(slider_pow.value - penalty, slider_pow.min_value, slider_pow.max_value)
		
		last_rel = new_rel
		last_pow = slider_pow.value
		refresh_display.call()
		is_updating = false
	)
	
	refresh_display.call()
	
	cm.add_child(cv)
	card.add_child(cm)
	vbox.add_child(card)
	
	# Botões Inferiores
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	
	var btn_confirm = Button.new()
	btn_confirm.text = "🛠️ FABRICAR E EQUIPAR MOTOR"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 46
	btn_confirm.add_theme_font_size_override("font_size", 15)
	var st_b = StyleBoxFlat.new()
	st_b.bg_color = Color("#16a34a")
	st_b.set_corner_radius_all(6)
	btn_confirm.add_theme_stylebox_override("normal", st_b)
	
	btn_confirm.pressed.connect(func():
		var final_pow = int(slider_pow.value)
		var final_rel = int(slider_rel.value)
		var pow_cost = max(0.0, (final_pow - 75.0) * 0.5)
		var rel_cost = max(0.0, (final_rel - 75.0) * 0.4)
		var raw_cost = 12.0 + pow_cost + rel_cost
		
		# Salva o valor com a taxa adicional de 5%
		var final_cost = raw_cost * 1.05
		
		selected_engine = {
			"nome": in_engine_name.text,
			"potencia": final_pow,
			"confiabilidade": final_rel,
			"preco": final_cost
		}
		
		_recalculate_budget()
		dialog.queue_free()
		_render_current_step()
	)
	btn_hbox.add_child(btn_confirm)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "VOLTAR"
	btn_cancel.custom_minimum_size = Vector2(160, 46)
	btn_cancel.add_theme_font_size_override("font_size", 15)
	btn_cancel.pressed.connect(func():
		dialog.queue_free()
		_open_engine_modal()
	)
	btn_hbox.add_child(btn_cancel)
	
	vbox.add_child(btn_hbox)
	margin.add_child(vbox)
	dialog.add_child(margin)
	add_child(dialog)
	active_modal_window = dialog
	dialog.popup_centered()

# MODAL CHASSIS
func _open_chassis_modal() -> void:
	# Como não existe opção de compra pronta de chassi, abre direto a fábrica
	_open_custom_chassis_builder_modal()

func _open_custom_chassis_builder_modal() -> void:
	_close_active_modal_window()
	var dialog = Window.new()
	dialog.title = "🛠️ DEPARTAMENTO DE ENGENHARIA - PROJETO DE CHASSI E AERODINÂMICA"
	dialog.size = Vector2i(900, 640)
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
	vbox.add_theme_constant_override("separation", 18)
	
	# Título
	var l_title = Label.new()
	l_title.text = "🏎️ PROJETAR NOVO CHASSI (" + team_name.to_upper() + " CHASSIS)"
	l_title.add_theme_font_size_override("font_size", 20)
	l_title.add_theme_color_override("font_color", Color("#fbbf24"))
	vbox.add_child(l_title)
	
	var card = PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st_card = StyleBoxFlat.new()
	st_card.bg_color = Color("#1e293b")
	st_card.set_corner_radius_all(8)
	st_card.border_width_left = 5
	st_card.border_color = Color("#fbbf24")
	card.add_theme_stylebox_override("panel", st_card)
	
	var cm = MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 20)
	cm.add_theme_constant_override("margin_right", 20)
	cm.add_theme_constant_override("margin_top", 20)
	cm.add_theme_constant_override("margin_bottom", 20)
	
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 16)
	
	# 1. Nome do Chassi
	var v_name = VBoxContainer.new()
	var l_nm = Label.new()
	l_nm.text = "Nome Oficial do Modelo/Chassi:"
	l_nm.add_theme_font_size_override("font_size", 14)
	v_name.add_child(l_nm)
	
	var in_chassis_name = LineEdit.new()
	in_chassis_name.text = team_name + " APX-26 Spec-A"
	in_chassis_name.custom_minimum_size.y = 40
	in_chassis_name.add_theme_font_size_override("font_size", 15)
	v_name.add_child(in_chassis_name)
	cv.add_child(v_name)
	
	var is_updating: bool = false
	
	# CONTROLE DE AERODINÂMICA (SLIDER 1)
	var v_aero = VBoxContainer.new()
	var l_aero = Label.new()
	l_aero.add_theme_font_size_override("font_size", 15)
	v_aero.add_child(l_aero)
	
	var slider_aero = HSlider.new()
	slider_aero.min_value = 75.0
	slider_aero.max_value = 98.0
	slider_aero.step = 1.0
	slider_aero.value = 86.0
	v_aero.add_child(slider_aero)
	cv.add_child(v_aero)
	
	# CONTROLE DE CONFIABILIDADE (SLIDER 2 - SUBSTITUIU RESISTÊNCIA)
	var v_rel = VBoxContainer.new()
	var l_rel = Label.new()
	l_rel.add_theme_font_size_override("font_size", 15)
	v_rel.add_child(l_rel)
	
	var slider_rel = HSlider.new()
	slider_rel.min_value = 75.0
	slider_rel.max_value = 98.0
	slider_rel.step = 1.0
	slider_rel.value = 85.0
	v_rel.add_child(slider_rel)
	cv.add_child(v_rel)
	
	# EXIBIÇÃO DO PESO CALCULADO (KG)
	var l_weight = Label.new()
	l_weight.add_theme_font_size_override("font_size", 15)
	cv.add_child(l_weight)
	
	# EXIBIÇÃO DO CUSTO CALCULADO ($M)
	var l_cost = Label.new()
	l_cost.add_theme_font_size_override("font_size", 16)
	l_cost.add_theme_color_override("font_color", Color("#10b981"))
	cv.add_child(l_cost)
	
	var refresh_chassis_stats = func():
		var aero_val = slider_aero.value
		var rel_val = slider_rel.value
		
		l_aero.text = "🌬️ Aerodinâmica (Alta Carga): %d%%" % aero_val
		l_rel.text = "🛡️ Confiabilidade Estrutural: %d%%" % rel_val
		
		l_aero.add_theme_color_override("font_color", Color("#fbbf24") if aero_val >= 90 else Color("#ffffff"))
		l_rel.add_theme_color_override("font_color", Color("#34d399") if rel_val >= 88 else Color("#cbd5e1"))
		
		# Cálculo do Peso
		var base_weight = 768.0
		var weight_from_aero = (aero_val - 75.0) * 0.1
		var weight_from_rel = (rel_val - 75.0) * 0.9
		var calculated_weight = maxf(768.0, base_weight + weight_from_aero + weight_from_rel)
		
		l_weight.text = "⚖️ Peso Total Estimado do Chassi: %.1f kg (Mínimo F1 Real: 768 kg)" % calculated_weight
		l_weight.add_theme_color_override("font_color", Color("#38bdf8") if calculated_weight <= 778.0 else Color("#fbbf24"))
		
		# Cálculo do Custo
		var base_cost = 10.0
		var aero_cost = max(0.0, (aero_val - 75.0) * 0.85)
		var rel_cost = max(0.0, (rel_val - 75.0) * 0.30)
		var total_cost = base_cost + aero_cost + rel_cost
		
		l_cost.text = "💰 Custo Total de Fabricação de Chassi: $%.1fM" % total_cost

	slider_aero.value_changed.connect(func(_val):
		if is_updating: return
		is_updating = true
		refresh_chassis_stats.call()
		is_updating = false
	)
	
	slider_rel.value_changed.connect(func(_val):
		if is_updating: return
		is_updating = true
		refresh_chassis_stats.call()
		is_updating = false
	)
	
	refresh_chassis_stats.call()
	
	cm.add_child(cv)
	card.add_child(cm)
	vbox.add_child(card)
	
	# Botões Inferiores
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	
	var btn_confirm = Button.new()
	btn_confirm.text = "🛠️ FABRICAR E EQUIPAR CHASSI"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size.y = 46
	btn_confirm.add_theme_font_size_override("font_size", 15)
	var st_b = StyleBoxFlat.new()
	st_b.bg_color = Color("#16a34a")
	st_b.set_corner_radius_all(6)
	btn_confirm.add_theme_stylebox_override("normal", st_b)
	
	btn_confirm.pressed.connect(func():
		var final_aero = int(slider_aero.value)
		var final_rel = int(slider_rel.value)
		
		var calculated_weight = maxf(768.0, 768.0 + ((final_aero - 75.0) * 0.1) + ((final_rel - 75.0) * 0.9))
		var aero_cost = max(0.0, (final_aero - 75.0) * 0.85)
		var rel_cost = max(0.0, (final_rel - 75.0) * 0.30)
		var final_cost = 10.0 + aero_cost + rel_cost
		
		selected_chassis = {
			"nome": in_chassis_name.text,
			"aero": final_aero,
			"confiabilidade": final_rel,
			"peso": calculated_weight,
			"preco": final_cost
		}
		
		_recalculate_budget()
		dialog.queue_free()
		_render_current_step()
	)
	btn_hbox.add_child(btn_confirm)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "CANCELAR"
	btn_cancel.custom_minimum_size = Vector2(160, 46)
	btn_cancel.add_theme_font_size_override("font_size", 15)
	btn_cancel.pressed.connect(func(): dialog.queue_free())
	btn_hbox.add_child(btn_cancel)
	
	vbox.add_child(btn_hbox)
	margin.add_child(vbox)
	dialog.add_child(margin)
	add_child(dialog)
	active_modal_window = dialog
	dialog.popup_centered()

func _save_team_to_database() -> void:
	Database.user_team = {
		"nome": team_name,
		"chefe": boss_name,
		"cor": team_color,
		"pilotos": selected_drivers,
		"motor": selected_engine,
		"chassi": selected_chassis,
		"patrocinadores": selected_sponsors, # Salva os 3 patrocinadores
		"aero": selected_chassis.get("aero", 85),
		"potencia": selected_engine.get("potencia", 88),
		"confiabilidade": int((selected_engine.get("confiabilidade", 85) + selected_chassis.get("confiabilidade", 85)) / 2.0),
		"peso": selected_chassis.get("peso", 778.0),
		"orcamento": remaining_budget, # Caixa Real acumulado
		"gastos_temporada": 0.0,      # Inicia zerado para o Teto de $135M
		"teto_gastos": 135.0          # Regulamento Fixo de $135M
	}

# =============================================================
# ETAPA 3: TESTES DE INVERNO
# =============================================================
func _build_winter_testing_step() -> void:
	main_card.custom_minimum_size = Vector2(1280, 700)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)
	
	# --- HEADER COM RELÓGIO REGRESSIVO DE 4H E CONTROLES ---
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
	hh.add_theme_constant_override("separation", 15)
	
	# Informação do Dia
	var hv = VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label = Label.new()
	title_label.text = "🏎️ TESTES DE INVERNO • BAHRAIN"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", team_color)
	hv.add_child(title_label)
	
	var l_sub = Label.new()
	l_sub.name = "SubTitleLabel"
	l_sub.text = "Dia %d de %d • Pista Aberta" % [testing_day, max_testing_days]
	l_sub.add_theme_font_size_override("font_size", 12)
	l_sub.add_theme_color_override("font_color", Color("#94a3b8"))
	hv.add_child(l_sub)
	hh.add_child(hv)
	
	# RELÓGIO REGRESSIVO (DECAI DE 04:00:00 ATÉ 00:00:00)
	var time_vbox = VBoxContainer.new()
	var lbl_clock_title = Label.new()
	lbl_clock_title.text = "⏱️ TEMPO RESTANTE DA SESSÃO:"
	lbl_clock_title.add_theme_font_size_override("font_size", 11)
	lbl_clock_title.add_theme_color_override("font_color", Color("#94a3b8"))
	time_vbox.add_child(lbl_clock_title)
	
	var lbl_timer = Label.new()
	lbl_timer.name = "SessionTimerLabel"
	lbl_timer.text = "04:00:00"
	lbl_timer.add_theme_font_size_override("font_size", 20)
	lbl_timer.add_theme_color_override("font_color", Color("#38bdf8"))
	time_vbox.add_child(lbl_timer)
	hh.add_child(time_vbox)
	
	# CONTROLES DE VELOCIDADE (PAUSA, 1x, 5x, 10x, 50x)
	var controls_hbox = HBoxContainer.new()
	controls_hbox.add_theme_constant_override("separation", 6)
	
	var btn_pause = Button.new()
	btn_pause.name = "BtnPause"
	btn_pause.text = "⏸️ PAUSA"
	btn_pause.custom_minimum_size = Vector2(85, 38)
	btn_pause.pressed.connect(func():
		is_time_paused = not is_time_paused
		_update_speed_buttons_ui(controls_hbox)
	)
	controls_hbox.add_child(btn_pause)
	
	var speeds = [1.0, 5.0, 10.0, 50.0]
	for spd in speeds:
		var btn_s = Button.new()
		btn_s.text = "%dx" % int(spd)
		btn_s.custom_minimum_size = Vector2(45, 38)
		btn_s.pressed.connect(func():
			time_speed = spd
			is_time_paused = false
			_update_speed_buttons_ui(controls_hbox)
		)
		controls_hbox.add_child(btn_s)
	
	var total_salarios := 0.0
	for drv in Database.user_team.get("pilotos", []):
		total_salarios += float(drv.get("salario", 0.0))
	Database.register_financial_transaction("gastos_salarios", total_salarios)

	# -------------------------------------------------------------
	# NOVO: BOTÃO PARA PULAR O DIA DE TESTES IMEDIATAMENTE
	# -------------------------------------------------------------
	var btn_skip = Button.new()
	btn_skip.text = "⏩ PULAR DIA"
	btn_skip.custom_minimum_size = Vector2(110, 38)
	var st_skip = StyleBoxFlat.new()
	st_skip.bg_color = Color("#d97706") # Laranja Escuro
	st_skip.set_corner_radius_all(4)
	btn_skip.add_theme_stylebox_override("normal", st_skip)
	
	btn_skip.pressed.connect(func():
		# Simula as voltas restantes do dia rapidamente para não perder os ganhos de P&D
		_fast_forward_remaining_day_laps()
		session_time_left = 0.0
		is_time_paused = true
		_on_day_session_finished()
	)
	controls_hbox.add_child(btn_skip)
		
	hh.add_child(controls_hbox)
	hm.add_child(hh)
	header.add_child(hm)
	main_vbox.add_child(header)
	
	# Painel de Pilotos
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
	
	# Tabela de Tempos
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
	_add_th(th_hbox, "POS", 40)
	_add_th(th_hbox, "PILOTO", 170)
	_add_th(th_hbox, "EQUIPE", 140)
	_add_th(th_hbox, "PNEU", 110)
	_add_th(th_hbox, "VOLTAS", 65) # NOVO CABEÇALHO
	_add_th(th_hbox, "DESGASTE", 85)
	_add_th(th_hbox, "STATUS", 100)
	_add_th(th_hbox, "MELHOR VOLTA", 115)
	_add_th(th_hbox, "ÚLTIMA VOLTA", 115)
	_add_th(th_hbox, "TEMPO BOX", 110) # NOVO CABEÇALHO PARA A BARRA AMARELA
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
	
	# Rodapé
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	
	var btn_finish = Button.new()
	btn_finish.text = "🏁 FINALIZAR PRÉ-TEMPORADA & IR PARA O GP 1"
	btn_finish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_finish.custom_minimum_size.y = 45
	var st_f = StyleBoxFlat.new()
	st_f.bg_color = Color("#16a34a")
	st_f.set_corner_radius_all(4)
	btn_finish.add_theme_stylebox_override("normal", st_f)
	btn_finish.pressed.connect(func():
		# APLICA AS EVOLUÇÕES E SALVA A EQUIPE ANTES DE MUDAR DE TELA
		_apply_final_testing_upgrades_to_database()
		
		Database.current_view = "dashboard"
		get_tree().change_scene_to_file("res://main.tscn")
	)
	footer.add_child(btn_finish)
	
	main_vbox.add_child(footer)
	main_card.add_child(margin)
	
	_rebuild_driver_control_boxes()
	_render_timing_table()
	_update_speed_buttons_ui(controls_hbox)

# Simula o restante das 4h instantaneamente quando o jogador clica em "PULAR DIA"
func _fast_forward_remaining_day_laps() -> void:
	if session_time_left <= 0.0: return
	
	# Simula pequenos saltos no tempo até esgotar o relógio
	while session_time_left > 0.0:
		var chunk = min(90.0, session_time_left)
		session_time_left -= chunk
		_simulate_automatic_lap_tick(chunk)

func _add_th(parent: HBoxContainer, text: String, width: float) -> void:
	var l = Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color("#94a3b8"))
	parent.add_child(l)

func _init_test_grid() -> void:
	test_grid_data.clear()
	total_player_laps_completed = 0
	laps_since_last_upgrade = 0
	team_testing_upgrades.clear()
	
	# Leitura do peso da equipe do jogador no banco de dados (Padrão: 778.0 kg)
	var player_team_weight = 778.0
	if not Database.user_team.is_empty():
		player_team_weight = float(Database.user_team.get("peso", 778.0))
	
	# 1. PILOTOS DA SUA EQUIPE
	for i in range(selected_drivers.size()):
		var d = selected_drivers[i]
		var cfg = driver_configs[i] if i < driver_configs.size() else {"pneu": "Duro (C3)", "on_track": false, "wear": 100.0, "estilo": "Normal"}
		
		if i < driver_configs.size():
			driver_configs[i]["on_track"] = false
			
		var initial_prep_time = randf_range(300.0, 1200.0)
		
		test_grid_data.append({
			"nome": d.get("Nome", d.get("nome", "Piloto %d" % (i+1))),
			"equipe": team_name,
			"pneu": cfg.get("pneu", "Duro (C3)"),
			"next_pneu": cfg.get("pneu", "Duro (C3)"),
			"estilo": cfg.get("estilo", "Normal"),
			"wear": 100.0,
			"status": "Nos Boxes",
			"best_time": 999.0,
			"last_time": 0.0,
			"is_player": true,
			"driver_idx": i,
			"ovr": float(d.get("Habilidade", d.get("Overall", 75))),
			"peso": player_team_weight, # NOVO: Registra o peso real do carro da sua equipe
			"laps": 0,
			"lap_progress": 0.0,
			"current_target_lap": 91.5,
			"pit_time_left": initial_prep_time,
			"pit_max_time": initial_prep_time
		})
		
	# 2. PILOTOS RIVAIS DA IA
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
			# Busca o peso registrado para a equipe da IA no banco de dados
			var ai_team_weight = 780.0
			if "teams" in Database:
				for t_dict in Database.teams:
					var t_n = str(t_dict.get("nome", t_dict.get("Nome", "")))
					if t_n == d_team:
						ai_team_weight = float(t_dict.get("peso", randf_range(775.0, 788.0)))
						break
			
			var ai_prep_time = randf_range(300.0, 720.0)
			test_grid_data.append({
				"nome": d_name,
				"equipe": d_team,
				"pneu": ["Duro (C3)", "Médio (C4)", "Macio (C5)"][randi() % 3],
				"next_pneu": "Duro (C3)",
				"estilo": "Normal",
				"wear": 100.0,
				"status": "Nos Boxes",
				"best_time": 999.0,
				"last_time": 0.0,
				"is_player": false,
				"driver_idx": -1,
				"ovr": float(d.get("Habilidade", d.get("Overall", 75))),
				"peso": ai_team_weight, # NOVO: Registra o peso do carro da IA
				"laps": 0,
				"lap_progress": 0.0,
				"current_target_lap": 91.5,
				"pit_time_left": ai_prep_time,
				"pit_max_time": ai_prep_time
			})

func _rebuild_driver_control_boxes() -> void:
	if not is_instance_valid(driver_cards_container): return
	for c in driver_cards_container.get_children():
		c.queue_free()
		
	for i in range(selected_drivers.size()):
		var d = selected_drivers[i]
		if i >= driver_configs.size(): continue
		var cfg = driver_configs[i]
		
		if not cfg.has("estilo"):
			cfg["estilo"] = "Normal"
		
		var box = PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st = StyleBoxFlat.new()
		st.bg_color = Color(0.12, 0.15, 0.22, 0.95)
		st.set_corner_radius_all(6)
		st.border_width_left = 4
		st.border_color = team_color
		box.add_theme_stylebox_override("panel", st)
		
		var bm = MarginContainer.new()
		bm.add_theme_constant_override("margin_left", 12)
		bm.add_theme_constant_override("margin_right", 12)
		bm.add_theme_constant_override("margin_top", 8)
		bm.add_theme_constant_override("margin_bottom", 8)
		
		var bh = HBoxContainer.new()
		bh.add_theme_constant_override("separation", 12)
		
		# Info do Piloto
		var v_info = VBoxContainer.new()
		v_info.custom_minimum_size.x = 140
		var l_n = Label.new()
		l_n.text = "🏎️ " + str(d.get("Nome", d.get("nome", "Piloto")))
		l_n.add_theme_font_size_override("font_size", 13)
		v_info.add_child(l_n)
		
		var is_on_track = cfg.get("on_track", false)
		var l_st = Label.new()
		l_st.text = "Status: " + ("Na Pista 🟢" if is_on_track else "Nos Boxes 🔴")
		l_st.add_theme_font_size_override("font_size", 11)
		l_st.add_theme_color_override("font_color", Color("#34d399") if is_on_track else Color("#f87171"))
		v_info.add_child(l_st)
		bh.add_child(v_info)
		
		# 1. SELETOR DE PNEU (ATUALIZAÇÃO EM TEMPO REAL)
		var opt_t = OptionButton.new()
		opt_t.add_item("Duro (C3)", 0)
		opt_t.add_item("Médio (C4)", 1)
		opt_t.add_item("Macio (C5)", 2)
		var tire_str = str(cfg.get("pneu", "Duro (C3)"))
		opt_t.select(1 if "C4" in tire_str else (2 if "C5" in tire_str else 0))
		var idx = i
		
		opt_t.item_selected.connect(func(sel_idx):
			var selected_tire = ["Duro (C3)", "Médio (C4)", "Macio (C5)"][sel_idx]
			driver_configs[idx]["pneu"] = selected_tire
			
			# Atualiza diretamente no registro do carro na tabela
			for item in test_grid_data:
				if item.get("is_player", false) and int(item.get("driver_idx", -1)) == idx:
					item["next_pneu"] = selected_tire
					# Se o piloto estiver nos boxes, aplica a mudança na tabela na hora
					if str(item.get("status", "")) == "Nos Boxes":
						item["pneu"] = selected_tire
			
			_render_timing_table()
		)
		bh.add_child(opt_t)
		
		# 2. SELETOR DE RITMO / ESTILO DE PILOTAGEM
		var opt_style = OptionButton.new()
		opt_style.add_item("🛡️ Conservador", 0)
		opt_style.add_item("⚖️ Normal", 1)
		opt_style.add_item("🔥 Agressivo", 2)
		
		var current_style_idx = 1
		if cfg["estilo"] == "Conservador": current_style_idx = 0
		elif cfg["estilo"] == "Agressivo": current_style_idx = 2
		opt_style.select(current_style_idx)
		
		opt_style.item_selected.connect(func(s_idx):
			var styles = ["Conservador", "Normal", "Agressivo"]
			var selected_style = styles[s_idx]
			driver_configs[idx]["estilo"] = selected_style
			
			for item in test_grid_data:
				if item.get("is_player", false) and int(item.get("driver_idx", -1)) == idx:
					item["estilo"] = selected_style
		)
		bh.add_child(opt_style)
		
		# 3. BOTÃO DE AÇÃO (MANDAR À PISTA / RECOLHER)
		var btn_act = Button.new()
		btn_act.text = "🛑 RECOLHER" if is_on_track else "🚀 MANDAR À PISTA"
		btn_act.custom_minimum_size.x = 130
		btn_act.add_theme_font_size_override("font_size", 12)
		
		btn_act.pressed.connect(func():
			driver_configs[idx]["on_track"] = not is_on_track
			
			for item in test_grid_data:
				if item.get("is_player", false) and int(item.get("driver_idx", -1)) == idx:
					var p_status = str(item.get("status", "Nos Boxes"))
					
					if not is_on_track:
						# Garante que pneu e estilo escolhidos vão para a pista
						item["pneu"] = driver_configs[idx]["pneu"]
						item["estilo"] = driver_configs[idx]["estilo"]
						
						# Se o tempo de preparação no box já zerou, sai imediatamente
						if p_status == "Nos Boxes" and float(item.get("pit_time_left", 0.0)) <= 0.0:
							item["status"] = "Volta de Saída"
							item["wear"] = 100.0
							item["lap_progress"] = 0.0
							item["current_target_lap"] = 105.0
					else:
						# Mandou recolher
						if p_status == "Na Pista" or p_status == "Volta de Saída":
							item["status"] = "Volta de Entrada"
							item["lap_progress"] = 0.0
							item["current_target_lap"] = 100.0
							
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
		if item.get("is_player", false) and int(item.get("driver_idx", -1)) == driver_idx:
			# Agenda o pneu selecionado para a próxima troca sem alterar o estado atual na pista
			item["next_pneu"] = cfg["pneu"]
			
			# Se o piloto já estiver parado nos boxes, atualiza o pneu selecionado
			if str(item.get("status", "")) == "Nos Boxes":
				item["pneu"] = cfg["pneu"]

func _render_timing_table() -> void:
	if not is_instance_valid(grid_container_vbox): return
	for c in grid_container_vbox.get_children():
		c.queue_free()
		
	# ORDENAÇÃO ROBUSTA: Menor tempo de volta -> Desempate por Ordem Alfabética do Nome
	test_grid_data.sort_custom(func(a, b):
		var time_a = float(a.get("best_time", 999.0))
		var time_b = float(b.get("best_time", 999.0))
		
		# Se os tempos forem idênticos (ex: 999.0 no início), ordena por ordem alfabética
		if is_equal_approx(time_a, time_b):
			return str(a.get("nome", "")) < str(b.get("nome", ""))
			
		return time_a < time_b
	)
	
	for i in range(test_grid_data.size()):
		var data = test_grid_data[i]
		var row = PanelContainer.new()
		var st_r = StyleBoxFlat.new()
		st_r.bg_color = Color(0.12, 0.15, 0.22, 0.95) if data.get("is_player", false) else Color(0.08, 0.10, 0.15, 0.85)
		if data.get("is_player", false):
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
		
		# Cores dos Compostos de Pneu
		var tire_str = str(data.get("pneu", "Duro (C3)"))
		var tire_color = Color("#ffffff") # Duro (C3)
		if "C5" in tire_str: 
			tire_color = Color("#ef4444") # Macio (C5) Vermelho
		elif "C4" in tire_str: 
			tire_color = Color("#eab308") # Médio (C4) Amarelo
			
		var driver_laps = int(data.get("laps", 0))
		var status_str = str(data.get("status", "Nos Boxes"))
		
		# Cores de Destaque por Status
		var status_color = Color("#34d399") # Na Pista
		if status_str == "Nos Boxes": 
			status_color = Color("#f87171")
		elif status_str == "Volta de Entrada" or status_str == "Volta de Saída": 
			status_color = Color("#fbbf24")
		
		_add_lbl(rh, "P%d" % (i + 1), 40, team_color if data.get("is_player", false) else Color("#cbd5e1"))
		_add_lbl(rh, str(data.get("nome", "")), 160, Color("#ffffff"))
		_add_lbl(rh, str(data.get("equipe", "")), 130, Color("#94a3b8"))
		_add_lbl(rh, tire_str, 100, tire_color)
		_add_lbl(rh, "%d" % driver_laps, 60, Color("#38bdf8"))
		_add_lbl(rh, "%.0f%%" % float(data.get("wear", 100.0)), 80, Color("#34d399") if float(data.get("wear", 100.0)) > 60 else Color("#ef4444"))
		_add_lbl(rh, status_str, 110, status_color)
		_add_lbl(rh, _format_lap_time(float(data.get("best_time", 999.0))), 110, Color("#fbbf24") if float(data.get("best_time", 999.0)) < 990.0 else Color("#64748b"))
		_add_lbl(rh, _format_lap_time(float(data.get("last_time", 0.0))), 110, Color("#cbd5e1") if float(data.get("last_time", 0.0)) > 0 else Color("#64748b"))
		
		# Renderização da Barra Amarela Regressiva do Pit Stop
		var pit_left = float(data.get("pit_time_left", 0.0))
		var pit_max = max(1.0, float(data.get("pit_max_time", 35.0)))
		
		if status_str == "Nos Boxes" and pit_left > 0.0:
			var pbar = ProgressBar.new()
			pbar.custom_minimum_size = Vector2(110, 18)
			pbar.min_value = 0
			pbar.max_value = pit_max
			pbar.value = pit_left
			pbar.show_percentage = false
			
			var st_fill = StyleBoxFlat.new()
			st_fill.bg_color = Color("#eab308")
			st_fill.set_corner_radius_all(3)
			pbar.add_theme_stylebox_override("fill", st_fill)
			
			var st_bg = StyleBoxFlat.new()
			st_bg.bg_color = Color("#1e293b")
			st_bg.set_corner_radius_all(3)
			pbar.add_theme_stylebox_override("background", st_bg)
			
			var lbl_pit = Label.new()
			lbl_pit.text = "🔧 %.1fs" % pit_left
			lbl_pit.set_anchors_preset(Control.PRESET_FULL_RECT)
			lbl_pit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_pit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl_pit.add_theme_font_size_override("font_size", 10)
			lbl_pit.add_theme_color_override("font_color", Color("#000000"))
			
			pbar.add_child(lbl_pit)
			rh.add_child(pbar)
		else:
			_add_lbl(rh, " -- ", 110, Color("#64748b"))
		
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

# --- CARD DE SELEÇÃO DE PATROCINADORES (0/3) ---
	var sp_card = PanelContainer.new()
	sp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st_sp = StyleBoxFlat.new()
	st_sp.bg_color = Color("#1e293b")
	st_sp.set_corner_radius_all(6)
	st_sp.border_width_left = 4
	st_sp.border_color = Color("#38bdf8") # Azul Claro
	sp_card.add_theme_stylebox_override("panel", st_sp)
	
	var sp_margin = MarginContainer.new()
	sp_margin.add_theme_constant_override("margin_left", 12)
	sp_margin.add_theme_constant_override("margin_right", 12)
	sp_margin.add_theme_constant_override("margin_top", 10)
	sp_margin.add_theme_constant_override("margin_bottom", 10)
	
	var sp_hbox = HBoxContainer.new()
	sp_hbox.add_theme_constant_override("separation", 10)
	
	var sp_vbox = VBoxContainer.new()
	sp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var l_sp_title = Label.new()
	l_sp_title.text = "🤝 Patrocinadores Oficiais (%d/3 Selecionados):" % selected_sponsors.size()
	l_sp_title.add_theme_font_size_override("font_size", 14)
	sp_vbox.add_child(l_sp_title)
	
	var l_sp_desc = Label.new()
	if selected_sponsors.is_empty():
		l_sp_desc.text = "Nenhum patrocinador assinado. Clique ao lado para contratar até 3 marcas."
		l_sp_desc.add_theme_color_override("font_color", Color("#94a3b8"))
	else:
		var sp_names = []
		var total_advance = 0.0
		for sp in selected_sponsors:
			sp_names.append(sp["nome"])
			total_advance += sp["valor_temporada"]
		l_sp_desc.text = "Contratados: " + ", ".join(sp_names) + " (+$%.1fM Adiantados no Caixa)" % total_advance
		l_sp_desc.add_theme_color_override("font_color", Color("#22c55e"))
		
	l_sp_desc.add_theme_font_size_override("font_size", 12)
	sp_vbox.add_child(l_sp_desc)
	sp_hbox.add_child(sp_vbox)
	
	var btn_select_sp = Button.new()
	btn_select_sp.text = "🤝 GERENCIAR PATROCÍNIOS..."
	btn_select_sp.custom_minimum_size = Vector2(210, 40)
	btn_select_sp.pressed.connect(func():
		_open_sponsors_selection_modal()
	)
	sp_hbox.add_child(btn_select_sp)
	
	sp_margin.add_child(sp_hbox)
	sp_card.add_child(sp_margin)
	sp_vbox.add_child(sp_card) # Adiciona no layout principal

func _open_sponsors_selection_modal() -> void:
	_close_active_modal_window()
	var dialog = Window.new()
	dialog.title = "🤝 CENTRAL DE NEGOCIAÇÕES E PATROCÍNIOS"
	dialog.size = Vector2i(980, 650)
	dialog.exclusive = true
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#0b0e14")
	dialog.add_child(bg)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var l_title = Label.new()
	l_title.text = "🏢 PATROCINADORES DISPONÍVEIS PARA O SEU NIVEL DE REPUTAÇÃO"
	l_title.add_theme_font_size_override("font_size", 16)
	l_title.add_theme_color_override("font_color", Color("#fbbf24"))
	vbox.add_child(l_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 10)
	
	var user_sponsors: Array = Database.user_team.get("patrocinadores", selected_sponsors)
	
	for sp in Database.available_sponsors:
		var item_card = PanelContainer.new()
		var st_i = StyleBoxFlat.new()
		st_i.bg_color = Color("#1e293b")
		st_i.set_corner_radius_all(6)
		
		# Verifica se já está assinado
		var is_selected = false
		for active_sp in user_sponsors:
			if active_sp is Dictionary and active_sp.get("id") == sp["id"]:
				is_selected = true
				break
				
		if is_selected:
			st_i.border_width_left = 5
			st_i.border_color = Color("#22c55e") # Verde se assinado
		else:
			if sp["tipo"] == "Master":
				st_i.border_width_left = 5
				st_i.border_color = Color("#ef4444") # Vermelho Master
			elif sp["tipo"] == "Principal":
				st_i.border_width_left = 5
				st_i.border_color = Color("#38bdf8") # Azul Principal
			else:
				st_i.border_width_left = 5
				st_i.border_color = Color("#94a3b8") # Cinza Secundário
				
		item_card.add_theme_stylebox_override("panel", st_i)
		
		var im = MarginContainer.new()
		im.add_theme_constant_override("margin_left", 12)
		im.add_theme_constant_override("margin_right", 12)
		im.add_theme_constant_override("margin_top", 10)
		im.add_theme_constant_override("margin_bottom", 10)
		
		var ihbox = HBoxContainer.new()
		ihbox.add_theme_constant_override("separation", 12)
		
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var l_sp_name = Label.new()
		l_sp_name.text = "🏢 %s [%s] — %s" % [str(sp["nome"]), str(sp["tipo"]).to_upper(), str(sp["categoria"])]
		l_sp_name.add_theme_font_size_override("font_size", 14)
		l_sp_name.add_theme_color_override("font_color", Color("#ffffff"))
		info_vbox.add_child(l_sp_name)
		
		var l_sp_desc = Label.new()
		l_sp_desc.text = "%s | Meta por GP: %s" % [str(sp["desc"]), str(sp["meta_gp"])]
		l_sp_desc.add_theme_font_size_override("font_size", 11)
		l_sp_desc.add_theme_color_override("font_color", Color("#94a3b8"))
		info_vbox.add_child(l_sp_desc)
		
		# Exibição financeira detalhada
		var l_pay = Label.new()
		l_pay.text = "💰 Adiantado: $%.1fM  |  🏁 Por GP: $%.1fM  |  🏆 Por Ponto: $%.2fM" % [
			sp["valor_temporada"], sp["valor_corrida"], sp["valor_ponto"]
		]
		l_pay.add_theme_font_size_override("font_size", 12)
		l_pay.add_theme_color_override("font_color", Color("#10b981"))
		info_vbox.add_child(l_pay)
		
		ihbox.add_child(info_vbox)
		
		# Botão de Ação / Negociação
		var btn_action = Button.new()
		btn_action.custom_minimum_size = Vector2(150, 36)
		btn_action.add_theme_font_size_override("font_size", 12)
		
		if is_selected:
			btn_action.text = "✖ RESCINDIR"
			btn_action.add_theme_color_override("font_color", Color("#ef4444"))
			btn_action.pressed.connect(func():
				_cancel_sponsor_contract(sp, dialog)
			)
		else:
			btn_action.text = "🤝 NEGOCIAR"
			btn_action.pressed.connect(func():
				_open_sponsor_negotiation_dialog(sp, dialog)
			)
			
		ihbox.add_child(btn_action)
		im.add_child(ihbox)
		item_card.add_child(im)
		list_vbox.add_child(item_card)
		
	scroll.add_child(list_vbox)
	vbox.add_child(scroll)
	
	var btn_close = Button.new()
	btn_close.text = "CONCLUIR E SALVAR SELEÇÃO"
	btn_close.custom_minimum_size.y = 40
	btn_close.pressed.connect(func():
		dialog.queue_free()
		atualizar_interface_criacao()
	)
	vbox.add_child(btn_close)
	
	margin.add_child(vbox)
	dialog.add_child(margin)
	add_child(dialog)
	dialog.popup_centered()

# =============================================================
# DIÁLOGO DE CONTRA-PROPOSTA E ASSINATURA
# =============================================================
func _open_sponsor_negotiation_dialog(sponsor: Dictionary, parent_modal: Window) -> void:
	var neg_dialog = Window.new()
	neg_dialog.title = "🤝 NEGOCIAÇÃO: " + str(sponsor["nome"])
	neg_dialog.size = Vector2i(500, 380)
	neg_dialog.exclusive = true
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var lbl_info = Label.new()
	lbl_info.text = "Defina os termos do contrato de patrocínio:"
	lbl_info.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl_info)
	
	# Seleção de Duração
	var dur_hbox = HBoxContainer.new()
	var lbl_dur = Label.new()
	lbl_dur.text = "Duração do Contrato:"
	lbl_dur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dur_hbox.add_child(lbl_dur)
	
	var opt_years = OptionButton.new()
	opt_years.add_item("1 Temporada", 1)
	opt_years.add_item("2 Temporadas", 2)
	opt_years.add_item("3 Temporadas", 3)
	opt_years.select(sponsor.get("contrato_anos", 1) - 1)
	dur_hbox.add_child(opt_years)
	vbox.add_child(dur_hbox)
	
	# Resumo da Oferta
	var lbl_summary = Label.new()
	lbl_summary.text = "Adiantamento: $%.1fM\nReceita por GP: $%.1fM\nBônus p/ Ponto: $%.2fM\nMulta por Rescisão: $%.1fM" % [
		sponsor["valor_temporada"], sponsor["valor_corrida"], sponsor["valor_ponto"], sponsor["multa_rescisao"]
	]
	lbl_summary.add_theme_font_size_override("font_size", 12)
	lbl_summary.add_theme_color_override("font_color", Color("#38bdf8"))
	vbox.add_child(lbl_summary)
	
	var btn_sign = Button.new()
	btn_sign.text = "✍️ ASSINAR CONTRATO"
	btn_sign.custom_minimum_size.y = 40
	btn_sign.pressed.connect(func():
		var chosen_years = opt_years.get_selected_id()
		var sp_copy = sponsor.duplicate()
		sp_copy["contrato_anos"] = chosen_years
		sp_copy["anos_restantes"] = chosen_years
		
		var ja_assinado = false
		for sel in selected_sponsors:
			if sel.get("id") == sp_copy.get("id"):
				ja_assinado = true
				break
				
		if not ja_assinado and selected_sponsors.size() < 3:
			selected_sponsors.append(sp_copy)
			
			# Extrai o valor adiantado diretamente do dicionário do patrocinador
			var valor_adiantado: float = float(sp_copy.get("valor_temporada", 0.0))
			
			# Registra o ganho no histórico financeiro da equipe no banco de dados
			Database.register_financial_transaction("patrocinios_acumulados", valor_adiantado)
			
			print("✅ Patrocínio %s assinado por %d temporada(s)! Adiantamento: $%.1fM" % [sp_copy["nome"], chosen_years, valor_adiantado])
			
		neg_dialog.queue_free()
		parent_modal.queue_free()
		_open_sponsors_selection_modal()
	)
	vbox.add_child(btn_sign)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.pressed.connect(func(): neg_dialog.queue_free())
	vbox.add_child(btn_cancel)
	
	margin.add_child(vbox)
	neg_dialog.add_child(margin)
	add_child(neg_dialog)
	neg_dialog.popup_centered()
	
# =============================================================
# RESCISÃO DE CONTRATO COM MULTA
# =============================================================
func _cancel_sponsor_contract(sponsor: Dictionary, parent_modal: Window) -> void:
	for i in range(selected_sponsors.size()):
		var active_sp = selected_sponsors[i]
		if active_sp is Dictionary and active_sp.get("id") == sponsor.get("id"):
			selected_sponsors.remove_at(i)
			print("🗑️ Patrocínio %s removido da seleção de pré-temporada." % sponsor.get("nome", "Patrocinador"))
			break
			
	parent_modal.queue_free()
	_recalculate_budget()
	_open_sponsors_selection_modal()

func _process(delta: float) -> void:
	time_passed += delta
	queue_redraw()
	
	if current_step == 3 and not is_time_paused and session_time_left > 0.0:
		var simulated_delta = delta * time_speed
		session_time_left = max(0.0, session_time_left - simulated_delta)
		
		_update_timer_label_display()
		
		# Avança o progresso real dos carros na pista
		_simulate_automatic_lap_tick(simulated_delta)
		timing_refresh_elapsed += delta
		if timing_refresh_elapsed >= 0.25:
			timing_refresh_elapsed = 0.0
			_render_timing_table()
			
		if session_time_left <= 0.0:
			is_time_paused = true
			_on_day_session_finished()

# Formatador do Relógio Regressivo (04:00:00)
func _update_timer_label_display() -> void:
	var lbl = main_card.find_child("SessionTimerLabel", true, false) as Label
	if is_instance_valid(lbl):
		var hrs = int(session_time_left / 3600.0)
		var mins = int((int(session_time_left) % 3600) / 60.0)
		var secs = int(session_time_left) % 60
		lbl.text = "%02d:%02d:%02d" % [hrs, mins, secs]

# Atualiza as cores dos botões de velocidade (Pausa, 1x, 5x, 10x, 50x)
func _update_speed_buttons_ui(container: Control) -> void:
	var btn_pause = container.find_child("BtnPause", true, false) as Button
	if is_instance_valid(btn_pause):
		btn_pause.text = "▶️ PLAY" if is_time_paused else "⏸️ PAUSA"

# Simula 1 volta automática considerando o Estilo de Pilotagem
func _simulate_automatic_lap_tick(delta_simulated: float) -> void:
	var state_changed: bool = false
	
	for item in test_grid_data:
		var current_status = str(item.get("status", "Nos Boxes"))
		
		# 1. ESTADO: NOS BOXES
		if current_status == "Nos Boxes":
			var pit_time = float(item.get("pit_time_left", 0.0))
			if pit_time > 0.0:
				pit_time = max(0.0, pit_time - delta_simulated)
				item["pit_time_left"] = pit_time

			# Carros de IA saem assim que termina o tempo de box; os do jogador aguardam o comando.
			if pit_time <= 0.0:
				var should_release = not bool(item.get("is_player", false))
				if item.get("is_player", false):
					var p_idx = int(item.get("driver_idx", -1))
					if p_idx >= 0 and p_idx < driver_configs.size():
						should_release = bool(driver_configs[p_idx].get("on_track", false))

				if should_release:
					item["status"] = "Volta de Saída"
					item["wear"] = 100.0

					if item.get("is_player", false):
						var p_idx = int(item.get("driver_idx", -1))
						if p_idx >= 0 and p_idx < driver_configs.size():
							item["pneu"] = driver_configs[p_idx].get("pneu", "Duro (C3)")
							item["estilo"] = driver_configs[p_idx].get("estilo", "Normal")
					else:
						item["pneu"] = ["Duro (C3)", "Médio (C4)", "Macio (C5)"][randi() % 3]

					item["lap_progress"] = 0.0
					item["current_target_lap"] = 105.0
					state_changed = true

		# 2. ESTADO: VOLTA DE SAÍDA (OUT-LAP)
		elif current_status == "Volta de Saída":
			item["lap_progress"] = float(item.get("lap_progress", 0.0)) + delta_simulated
			if float(item["lap_progress"]) >= float(item.get("current_target_lap", 105.0)):
				item["status"] = "Na Pista"
				item["lap_progress"] = 0.0
				item["current_target_lap"] = 91.5
				state_changed = true
				
				if item.get("is_player", false):
					var p_idx = int(item.get("driver_idx", -1))
					if p_idx >= 0 and p_idx < driver_configs.size():
						driver_configs[p_idx]["on_track"] = true

		# 3. ESTADO: VOLTA DE ENTRADA (IN-LAP)
		elif current_status == "Volta de Entrada":
			item["lap_progress"] = float(item.get("lap_progress", 0.0)) + delta_simulated
			if float(item["lap_progress"]) >= float(item.get("current_target_lap", 100.0)):
				# Tempo de parada nos boxes entre 5 e 20 minutos (300s a 1200s)
				var stop_duration = randf_range(300.0, 1200.0)
				item["status"] = "Nos Boxes"
				item["pit_time_left"] = stop_duration
				item["pit_max_time"] = stop_duration
				item["lap_progress"] = 0.0
				state_changed = true

		# 4. ESTADO: NA PISTA
		elif current_status == "Na Pista":
			item["lap_progress"] = float(item.get("lap_progress", 0.0)) + delta_simulated
			var target_time = float(item.get("current_target_lap", 91.5))
			
			if float(item["lap_progress"]) >= target_time:
				item["lap_progress"] -= target_time
				item["laps"] = int(item.get("laps", 0)) + 1
				
				var style_mod = 1.0
				var wear_rate = randf_range(2.5, 4.5)
				
				if item.get("is_player", false):
					var p_idx = int(item.get("driver_idx", -1))
					if p_idx >= 0 and p_idx < driver_configs.size():
						var driver_style = driver_configs[p_idx].get("estilo", "Normal")
						if driver_style == "Conservador":
							style_mod = 1.006
							wear_rate *= 0.6
						elif driver_style == "Agressivo":
							style_mod = 0.994
							wear_rate *= 1.6
							
					total_player_laps_completed += 1
					laps_since_last_upgrade += 1
					if laps_since_last_upgrade >= 15:
						laps_since_last_upgrade -= 15
						_apply_random_testing_upgrade(team_name)
				else:
					if randf() < 0.15:
						_apply_random_testing_upgrade(str(item.get("equipe", "")))
				
				item["wear"] = clamp(float(item.get("wear", 100.0)) - wear_rate, 0.0, 100.0)
				
				# =============================================================
				# CÁLCULO FÍSICO DO TEMPO DE VOLTA (HABILIDADE + PNEU + PESO)
				# =============================================================
				# 1. Habilidade do Piloto (Overall)
				var ovr_val = float(item.get("ovr", 75.0))
				var base_lap = 91.5 - ((ovr_val - 75.0) * 0.08)
				
				# 2. Composto do Pneu
				var tire_str = str(item.get("pneu", ""))
				if "C5" in tire_str: base_lap -= 0.6
				elif "C3" in tire_str: base_lap += 0.5
				
				# 3. IMPACTO DO PESO DO CARRO
				# Cada quilo acima do mínimo de 768.0 kg reduz o tempo em 0.03 segundos
				var car_weight = float(item.get("peso", 778.0))
				var weight_penalty = max(0.0, (car_weight - 768.0) * 0.03)
				base_lap += weight_penalty
				
				# 4. Cálculo final com desgaste de pneu e estilo de pilotagem
				var completed_lap_time = (base_lap + randf_range(-0.2, 0.5) + ((100.0 - float(item["wear"])) * 0.02)) * style_mod
				item["last_time"] = completed_lap_time
				item["current_target_lap"] = completed_lap_time
				
				if completed_lap_time < float(item.get("best_time", 999.0)):
					item["best_time"] = completed_lap_time
					
				if float(item["wear"]) <= 15.0:
					item["status"] = "Volta de Entrada"
					item["lap_progress"] = 0.0
					item["current_target_lap"] = 100.0
					state_changed = true
					
					if item.get("is_player", false):
						var p_idx = int(item.get("driver_idx", -1))
						if p_idx >= 0 and p_idx < driver_configs.size():
							driver_configs[p_idx]["on_track"] = false

	if state_changed:
		_rebuild_driver_control_boxes()
		
# Ação acionada quando o tempo de 4 horas se encerra
func _on_day_session_finished() -> void:
	if day_session_finish_handled:
		return
	day_session_finish_handled = true
	if testing_day < max_testing_days:
		# Avança para o próximo dia
		testing_day += 1
		session_time_left = 14400.0 # Reseta para 4 horas
		# 1ª MUDANÇA: Mude para 'true' para o novo dia começar pausado (melhor para o jogador)
		is_time_paused = true 
		day_session_finish_handled = false
		timing_refresh_elapsed = 0.0
		_reset_test_grid_for_new_day()
		_close_active_modal_window()
		# Isso garante que a UI velha seja destruída (queue_free) antes da nova ser criada!
		_render_current_step() 
		
		_update_timer_label_display()
	else:
		# Chegou ao Fim do 3º Dia -> EXIBE O RELATÓRIO DE EVOLUÇÃO
		_open_testing_results_modal()

func _reset_test_grid_for_new_day() -> void:
	for item in test_grid_data:
		item["status"] = "Nos Boxes"
		item["wear"] = 100.0
		item["pit_time_left"] = 0.0
		item["pit_max_time"] = 0.0
		item["lap_progress"] = 0.0
		item["current_target_lap"] = 91.5
		if bool(item.get("is_player", false)):
			var driver_idx := int(item.get("driver_idx", -1))
			if driver_idx >= 0 and driver_idx < driver_configs.size():
				driver_configs[driver_idx]["on_track"] = false

# Sorteia um parâmetro para evoluir a equipe durante os testes.
func _apply_random_testing_upgrade(target_team_name: String) -> void:
	if not team_testing_upgrades.has(target_team_name):
		team_testing_upgrades[target_team_name] = {"Motor": 0.0, "Aero": 0.0, "Chassi": 0.0, "Confiabilidade": 0.0, "Peso": 0.0}
		
	var attributes = ["Motor", "Aero", "Chassi", "Confiabilidade"]
	var chosen_attr: String = "Peso" if randf() < 0.35 else attributes[randi() % attributes.size()]
	var upgrade_amount := 0.1
	var team_weight := 778.0
	if chosen_attr == "Peso":
		if target_team_name == team_name:
			team_weight = float(Database.user_team.get("peso", 778.0))
		else:
			var target_team := Database._get_team_by_name(target_team_name)
			if not target_team.is_empty():
				team_weight = float(target_team.get("peso", target_team.get("Peso", 778.0)))
		var already_reduced := float(team_testing_upgrades[target_team_name].get("Peso", 0.0))
		var remaining_weight := maxf(0.0, team_weight - 768.0 - already_reduced)
		upgrade_amount = randf_range(0.05, minf(0.6, remaining_weight)) if remaining_weight >= 0.05 else 0.0
	team_testing_upgrades[target_team_name][chosen_attr] += upgrade_amount

	if chosen_attr == "Peso":
		var new_weight := maxf(768.0, team_weight - float(team_testing_upgrades[target_team_name]["Peso"]))
		for item in test_grid_data:
			if str(item.get("equipe", "")) == target_team_name:
				item["peso"] = new_weight

# =============================================================
# JANELA DE RELATÓRIO FINAL DE EVOLUÇÃO DE P&D DA PRÉ-TEMPORADA
# =============================================================
func _open_testing_results_modal() -> void:
	_close_active_modal_window()
	var dialog = Window.new()
	dialog.title = "📊 RELATÓRIO DE EVOLUÇÃO TÉCNICA - TESTES DE INVERNO"
	dialog.size = Vector2i(850, 620)
	dialog.exclusive = true
	
	dialog.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	dialog.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#0b0e14")
	dialog.add_child(bg)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	
	var l_title = Label.new()
	l_title.text = "📈 RESULTADO DE EVOLUÇÃO DOS CARROS APÓS 3 DIAS DE TESTE"
	l_title.add_theme_font_size_override("font_size", 18)
	l_title.add_theme_color_override("font_color", Color("#22c55e"))
	vbox.add_child(l_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 8)
	
	# Percorre todas as equipes e exibe no formato solicitado
	for t_name in team_testing_upgrades.keys():
		var upg = team_testing_upgrades[t_name]
		
		var card = PanelContainer.new()
		var st_c = StyleBoxFlat.new()
		st_c.bg_color = Color("#1e293b") if t_name == team_name else Color("#0f172a")
		if t_name == team_name:
			st_c.border_width_left = 4
			st_c.border_color = Color("#38bdf8") # Azul para o jogador
		st_c.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", st_c)
		
		var cm = MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 14)
		cm.add_theme_constant_override("margin_right", 14)
		cm.add_theme_constant_override("margin_top", 10)
		cm.add_theme_constant_override("margin_bottom", 10)
		
		var cv = VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		
		# Nome da Equipe
		var l_name = Label.new()
		l_name.text = "🏎️ " + t_name + ":"
		l_name.add_theme_font_size_override("font_size", 16)
		l_name.add_theme_color_override("font_color", Color("#ffffff"))
		cv.add_child(l_name)
		
		# Estatísticas de Evolução Formatadas Exatamente como Solicitado
		var stats_txt = "   Motor: +%.1f   |   Aero: +%.1f   |   Chassi: +%.1f   |   Confiab: +%.1f   |   Peso: -%.2fkg" % [
			upg["Motor"], upg["Aero"], upg["Chassi"], upg["Confiabilidade"], upg["Peso"]
		]
		
		var l_stats = Label.new()
		l_stats.text = stats_txt
		l_stats.add_theme_font_size_override("font_size", 13)
		l_stats.add_theme_color_override("font_color", Color("#38bdf8") if t_name == team_name else Color("#cbd5e1"))
		cv.add_child(l_stats)
		
		cm.add_child(cv)
		card.add_child(cm)
		list_vbox.add_child(card)
		
	scroll.add_child(list_vbox)
	vbox.add_child(scroll)
	
	# Botão Prosseguir para a Temporada
	var btn_proceed = Button.new()
	btn_proceed.text = "🏁 IR PARA O GP 1 DA TEMPORADA ▶"
	btn_proceed.custom_minimum_size.y = 48
	btn_proceed.add_theme_font_size_override("font_size", 16)
	var st_b = StyleBoxFlat.new()
	st_b.bg_color = Color("#16a34a")
	st_b.set_corner_radius_all(4)
	btn_proceed.add_theme_stylebox_override("normal", st_b)
	
	btn_proceed.pressed.connect(func():
		dialog.hide()
		dialog.queue_free()
		
		# APLICA AS EVOLUÇÕES E SALVA A EQUIPE ANTES DE MUDAR DE TELA
		_apply_final_testing_upgrades_to_database()
		
		Database.current_view = "dashboard"
		call_deferred("_change_to_main_game_scene")
	)
	vbox.add_child(btn_proceed)
	
	margin.add_child(vbox)
	dialog.add_child(margin)
	add_child(dialog)
	active_modal_window = dialog
	dialog.popup_centered()

func _change_to_main_game_scene() -> void:
	var scene_error := get_tree().change_scene_to_file("res://main.tscn")
	if scene_error != OK:
		push_error("Não foi possível abrir o dashboard após a pré-temporada. Erro: %d" % scene_error)

# =============================================================
# SALVA A EQUIPE DO JOGADOR E APLICAR O P&D FINAL NA DATABASE
# =============================================================
func _apply_final_testing_upgrades_to_database() -> void:
	# 1. Configura e padroniza os dados da equipe do jogador
	_save_team_to_database()
	
	if not Database.user_team.is_empty():
		# Padroniza as chaves de nome para evitar incompatibilidade na interface
		var user_team_name = Database.user_team.get("nome", Database.user_team.get("Nome", team_name))
		Database.user_team["nome"] = user_team_name
		Database.user_team["Nome"] = user_team_name
		
		# Inicializa pontuações de campeonato da equipe
		Database.user_team["pts"] = Database.user_team.get("pts", 0)
		Database.user_team["vit"] = Database.user_team.get("vit", 0)
		Database.user_team["pod"] = Database.user_team.get("pod", 0)
		Database.user_team["dnf"] = Database.user_team.get("dnf", 0)
		
		# Insere/Atualiza a equipe na lista global de equipes do campeonato (Database.teams)
		if "teams" in Database:
			var found = false
			for idx in range(Database.teams.size()):
				var t_item = Database.teams[idx]
				var curr_name = t_item.get("nome", t_item.get("Nome", ""))
				if curr_name == user_team_name:
					found = true
					Database.teams[idx] = Database.user_team.duplicate(true)
					break
			
			if not found:
				Database.teams.append(Database.user_team.duplicate(true))

	# 2. Sincroniza os pilotos contratados na lista global
	_sync_hired_drivers_to_global_database()

	# 3. Aplica os pontos de P&D de forma segura para todas as equipes
	if "teams" in Database:
		for t_name in team_testing_upgrades.keys():
			var upg = team_testing_upgrades[t_name]
			
			for team_dict in Database.teams:
				var name_in_db = team_dict.get("nome", team_dict.get("Nome", ""))
				if name_in_db == t_name:
					_apply_upgrades_to_team_dict(team_dict, upg)
					break
					
			if not Database.user_team.is_empty():
				var u_name = Database.user_team.get("nome", Database.user_team.get("Nome", ""))
				if u_name == t_name:
					_apply_upgrades_to_team_dict(Database.user_team, upg)


# Aplica os bônus em um dicionário de equipe tratando os tipos com segurança
func _apply_upgrades_to_team_dict(team_dict: Dictionary, upg: Dictionary) -> void:
	_safe_add_team_attribute(team_dict, "potencia", float(upg.get("Motor", 0.0)))
	_safe_add_team_attribute(team_dict, "aero", float(upg.get("Aero", 0.0)))
	_safe_add_team_attribute(team_dict, "chassi", float(upg.get("Chassi", 0.0)))
	_safe_add_team_attribute(team_dict, "confiabilidade", float(upg.get("Confiabilidade", 0.0)))
	# Para o peso, a evolução de P&D reduz o peso do carro
	_safe_add_team_attribute(team_dict, "peso", -float(upg.get("Peso", 0.0)), true)


# Função auxiliar que evita o erro "Invalid operands 'Dictionary' and 'float'"
func _safe_add_team_attribute(team_dict: Dictionary, attr_name: String, amount: float, is_weight: bool = false) -> void:
	if is_zero_approx(amount): return
	
	if team_dict.has(attr_name):
		var current_val = team_dict[attr_name]
		
		# Se for número (float ou int), soma diretamente
		if typeof(current_val) == TYPE_FLOAT or typeof(current_val) == TYPE_INT:
			if is_weight:
				team_dict[attr_name] = max(768.0, float(current_val) + amount)
			else:
				team_dict[attr_name] = float(current_val) + amount
				
		# Se for Dicionário (como o objeto do Chassi projetado)
		elif typeof(current_val) == TYPE_DICTIONARY:
			var sub_dict = current_val as Dictionary
			if sub_dict.has(attr_name):
				if is_weight:
					sub_dict[attr_name] = max(768.0, float(sub_dict[attr_name]) + amount)
				else:
					sub_dict[attr_name] = float(sub_dict[attr_name]) + amount
			elif sub_dict.has("qualidade"):
				sub_dict["qualidade"] = float(sub_dict["qualidade"]) + amount
			elif sub_dict.has("desempenho"):
				sub_dict["desempenho"] = float(sub_dict["desempenho"]) + amount
				
			# Salva um valor numérico direto na raiz para rápida consulta dos sistemas de corrida
			var flat_key = attr_name + "_val"
			var current_flat = float(team_dict.get(flat_key, 85.0))
			team_dict[flat_key] = max(768.0, current_flat + amount) if is_weight else current_flat + amount
	else:
		# Se a chave não existir no dicionário, inicializa com o valor base
		if is_weight:
			team_dict[attr_name] = max(768.0, 778.0 + amount)
		else:
			team_dict[attr_name] = 85.0 + amount


# Vincula a nova equipe aos pilotos contratados na lista global de pilotos
func _sync_hired_drivers_to_global_database() -> void:
	if not "drivers" in Database: return
	var hired_names: Array[String] = []
	for d in selected_drivers:
		hired_names.append(str(d.get("Nome", d.get("nome", ""))))
	var teams_to_replenish: Dictionary = {}
	for driver_dict in Database.drivers:
		var d_name = str(driver_dict.get("Nome", driver_dict.get("nome", "")))
		if d_name in hired_names:
			var previous_team := str(driver_dict.get("Equipe", driver_dict.get("equipe", ""))).strip_edges()
			if not previous_team.is_empty() and previous_team != "Free Agent" and previous_team != team_name:
				teams_to_replenish[previous_team] = true
			driver_dict["Equipe"] = team_name
			driver_dict["equipe"] = team_name
	for previous_team in teams_to_replenish.keys():
		Database._auto_fill_team_seat(str(previous_team))
