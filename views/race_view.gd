extends Node

var engine: RaceEngine
var race_timer: Timer

@onready var top_title: Label
@onready var weather_lbl: Label
@onready var water_bar: ProgressBar
@onready var grip_bar: ProgressBar
@onready var btn_start: Button
@onready var btn_speed_1x: Button
@onready var btn_speed_2x: Button
@onready var btn_speed_5x: Button
@onready var btn_speed_10x: Button
@onready var btn_speed_20x: Button
@onready var btn_speed_skip: Button

@onready var race_grid_node: GridContainer
@onready var log_text_node: RichTextLabel
@onready var pit_log_text_node: RichTextLabel

var left_vbox: VBoxContainer
var banner_container: PanelContainer
var banner_label: Label

var timer_speed: float = 1.0
var sim_step_delta: float = 1.0
var active_modal: Control = null
var strategy = {
	"start_tire": "Macio (C5)",
	"pit_stops": [
		{"lap": 18, "tire": "Médio (C4)"},
		{"lap": 42, "tire": "Duro (C3)"}
	]
}

func _ready() -> void:
	# 1. Recupera o motor de simulação ativo ou cria uma nova instância
	if Database.active_engine == null:
		var race_engine_script = load("res://views/race_engine.gd")
		if race_engine_script != null:
			engine = race_engine_script.new()
			Database.active_engine = engine
	else:
		engine = Database.active_engine

	# 2. Garante que a corrida/classificação foi configurada com a pista atual
	if engine != null:
		var current_gp_idx = clamp(Database.current_gp - 1, 0, Database.tracks.size() - 1)
		var track_data = Database.tracks[current_gp_idx]
		
		# Se a lista de pilotos do motor estiver vazia, inicializa a sessão
		if not "active_quali_drivers" in engine or engine.active_quali_drivers.is_empty():
			if engine.has_method("setup_race"):
				engine.setup_race(track_data)

	# 3. Constrói a estrutura visual e popula a tabela com os dados
	build_ui()

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)
	
	# Verifica se é Modo Manager ou Observador
	var game_mode = Database.get("game_mode")
	var is_manager_mode = (game_mode == "manager")
	
	var main_hbox = HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 12)
	
	# Coluna Esquerda: Tabela
	var left_panel = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 2.0
	
	left_vbox = VBoxContainer.new()
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	race_grid_node = GridContainer.new()
	race_grid_node.columns = 8
	scroll.add_child(race_grid_node)
	left_vbox.add_child(scroll)
	left_panel.add_child(left_vbox)
	main_hbox.add_child(left_panel)
	
	# Coluna Direita: Incidentes e Comandos (Apenas no Modo Manager)
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var tab_events = VBoxContainer.new()
	tab_events.name = "📢 INCIDENTES & CLIMA"
	log_text_node = RichTextLabel.new()
	log_text_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_events.add_child(log_text_node)
	tab_container.add_child(tab_events)
	
	right_vbox.add_child(tab_container)
	
	# Exibe o painel de controle apenas se for Modo Manager
	if is_manager_mode:
		_build_manager_qualifying_controls(right_vbox)
		
	right_panel.add_child(right_vbox)
	main_hbox.add_child(right_panel)
	main_vbox.add_child(main_hbox)
	
	_update_ui()

# =============================================================
# PAINEL DE COMANDO DO MANAGER NA CLASSIFICAÇÃO
# =============================================================
func _build_manager_qualifying_controls(parent_container: Control) -> void:
	if not is_instance_valid(parent_container): return
	
	# Garante que não duplique o painel se a UI for redesenhada
	var existing = parent_container.find_child("ManagerQualiPanel", true, false)
	if is_instance_valid(existing):
		existing.queue_free()
		
	var selected_drivers = _get_user_drivers()
	if selected_drivers.is_empty(): return
	
	var manager_panel = PanelContainer.new()
	manager_panel.name = "ManagerQualiPanel"
	manager_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manager_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#0f172a") # Fundo escuro elegante
	st.border_width_top = 3
	st.border_color = Color("#38bdf8") # Borda de destaque azul
	st.set_corner_radius_all(6)
	manager_panel.add_theme_stylebox_override("panel", st)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	var vbox_main = VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 12)
	
	# Título do Painel
	var lbl_title = Label.new()
	lbl_title.text = "🎧 COMANDOS TÁTICOS DA EQUIPE"
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.add_theme_color_override("font_color", Color("#38bdf8"))
	vbox_main.add_child(lbl_title)
	
	vbox_main.add_child(HSeparator.new())
	
	# Cards verticais dos 2 pilotos
	for i in range(min(2, selected_drivers.size())):
		var driver_data = selected_drivers[i]
		var card = _create_single_driver_quali_card(i, driver_data)
		vbox_main.add_child(card)
		
	margin.add_child(vbox_main)
	manager_panel.add_child(margin)
	
	parent_container.add_child(manager_panel)


# Constrói o Card Individual de Controle de Cada Piloto
func _create_single_driver_quali_card(driver_index: int, driver_data: Dictionary) -> Control:
	var card = PanelContainer.new()
	card.name = "DriverCard_%d" % driver_index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var st_c = StyleBoxFlat.new()
	st_c.bg_color = Color("#1e293b")
	st_c.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", st_c)
	
	var cm = MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 10)
	cm.add_theme_constant_override("margin_right", 10)
	cm.add_theme_constant_override("margin_top", 8)
	cm.add_theme_constant_override("margin_bottom", 8)
	
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	
	# 1. Nome do Piloto e Status Atual
	var d_name = str(driver_data.get("Nome", driver_data.get("nome", "Piloto")))
	var l_name = Label.new()
	l_name.text = "🏎️ " + d_name
	l_name.add_theme_font_size_override("font_size", 13)
	cv.add_child(l_name)
	
	var current_status = _get_driver_quali_status(driver_index)
	var l_status = Label.new()
	l_status.name = "LblStatus_%d" % driver_index # Nome único por piloto
	l_status.text = "Status: " + current_status
	l_status.add_theme_font_size_override("font_size", 11)
	l_status.add_theme_color_override("font_color", Color("#34d399") if ("Pista" in current_status or "Em pista" in current_status or "Hot Lap" in current_status) else Color("#f87171"))
	cv.add_child(l_status)
	
	# Controles na mesma linha
	var ch = HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	
	# 2. Seletor de Pneu
	var opt_tire = OptionButton.new()
	opt_tire.name = "OptTire_%d" % driver_index # Nome único por piloto
	opt_tire.add_item("Macio (C5)", 0)
	opt_tire.add_item("Médio (C4)", 1)
	opt_tire.add_item("Duro (C3)", 2)
	opt_tire.add_item("Intermediário (Inter)", 3)
	opt_tire.add_item("Chuva Extrema (Wet)", 4)
	
	if engine != null and engine.water_level > 10.0:
		opt_tire.select(3)
	else:
		opt_tire.select(0)
		
	ch.add_child(opt_tire)
	
	# 3. Seletor de Ritmo
	var opt_pace = OptionButton.new()
	opt_pace.name = "OptPace_%d" % driver_index # Nome único por piloto
	opt_pace.add_item("🛡️ Conservador", 0)
	opt_pace.add_item("⚖️ Normal", 1)
	opt_pace.add_item("🔥 Ataque Máximo", 2)
	opt_pace.select(2)
	ch.add_child(opt_pace)
	
	# 4. Botão de Ação
	var btn_action = Button.new()
	btn_action.name = "BtnAction_%d" % driver_index # Nome único por piloto
	
	var is_on_track = ("Pista" in current_status or "Em pista" in current_status or "Hot Lap" in current_status or "Entrada" in current_status)
	btn_action.text = "🛑 RECOLHER" if is_on_track else "🚀 MANDAR À PISTA"
	btn_action.custom_minimum_size.x = 130
	btn_action.add_theme_font_size_override("font_size", 11)
	
	# Importante: Passamos o driver_index exato no clique do botão
	var idx = driver_index
	btn_action.pressed.connect(func():
		_on_manager_quali_action_pressed(idx, opt_tire.selected, opt_pace.selected)
	)
	ch.add_child(btn_action)
	
	cv.add_child(ch)
	cm.add_child(cv)
	card.add_child(cm)
	return card

# Lógica de acionamento de envio/recolhimento de piloto na classificação
func _on_manager_quali_action_pressed(driver_idx: int, tire_sel_idx: int, pace_sel_idx: int) -> void:
	var selected_drivers = _get_user_drivers()
	if driver_idx >= selected_drivers.size(): return
	
	var target_driver = selected_drivers[driver_idx]
	var target_name = str(target_driver.get("Nome", target_driver.get("nome", "")))
	
	var tires = ["Soft", "Medium", "Hard", "Inter", "Wet"]
	var paces = ["Conservador", "Normal", "Agressivo"]
	
	var chosen_tire = tires[tire_sel_idx] if tire_sel_idx < tires.size() else "Soft"
	var chosen_pace = paces[pace_sel_idx] if pace_sel_idx < paces.size() else "Normal"
	
	if engine != null and engine.active_quali_drivers != null:
		for d in engine.active_quali_drivers:
			var d_n = str(d.get("Nome", d.get("nome", "")))
			if d_n == target_name:
				var curr_state = str(d.get("quali_state", "Box"))
				
				if curr_state == "Box":
					# Coloca o piloto no estado de Volta de Saída / Em pista sem sinalizar recolhimento imediato
					d["quali_state"] = "Em pista"
					d["tire_compound"] = chosen_tire
					d["estilo"] = chosen_pace
					d["is_in_pit"] = false
					d["tire_wear"] = 100
					d["progress"] = 0.0
					d["force_in_lap"] = false # Impede que o motor force a volta de entrada
				else:
					# Ordena o recolhimento para os boxes na próxima oportunidade
					d["quali_state"] = "Em Entrada"
					d["force_in_lap"] = true
					d["estilo"] = chosen_pace
				break
				
	_update_manager_quali_ui_state()
	_update_ui()


# Retorna o status formatado do piloto na classificação
func _get_driver_quali_status(driver_idx: int) -> String:
	var selected_drivers = _get_user_drivers()
	if driver_idx >= selected_drivers.size(): return "Box"
	
	var driver_data = selected_drivers[driver_idx]
	var driver_name = str(driver_data.get("Nome", driver_data.get("nome", "")))
	
	if engine != null and engine.active_quali_drivers != null:
		for d in engine.active_quali_drivers:
			var d_n = str(d.get("Nome", d.get("nome", "")))
			if d_n == driver_name:
				return str(d.get("quali_state", "Box"))
				
	return "Box"

# Atualiza os botões e rótulos de status de forma individualizada
func _update_manager_quali_ui_state() -> void:
	var selected_drivers = _get_user_drivers()
	
	for i in range(selected_drivers.size()):
		var st = _get_driver_quali_status(i)
		
		# Procura o botão e o texto do status correspondentes unicamente a este índice i
		var btn = find_child("BtnAction_%d" % i, true, false)
		var lbl = find_child("LblStatus_%d" % i, true, false)
		
		var is_on_track = ("Pista" in st or "Em pista" in st or "Hot Lap" in st or "Entrada" in st)
		
		if is_instance_valid(btn):
			btn.text = "🛑 RECOLHER" if is_on_track else "🚀 MANDAR À PISTA"
			
		if is_instance_valid(lbl):
			lbl.text = "Status: " + st
			lbl.add_theme_color_override("font_color", Color("#34d399") if is_on_track else Color("#f87171"))

func _set_speed_mode(speed: float, step_delta: float) -> void:
	timer_speed = speed
	sim_step_delta = step_delta
	race_timer.wait_time = speed

func _skip_to_end_of_session() -> void:
	if not engine.is_quali_done():
		engine.skip_to_end_of_quali_session()
		race_timer.stop()
		btn_start.text = "▶ CONTINUAR"
		_update_ui()
	elif not engine.is_finished():
		while not engine.is_finished():
			var res = engine.process_lap()
			if res.get("red_flag", false):
				_show_red_flag_modal()
				break
		race_timer.stop()
		btn_start.text = "🏁 CONCLUIR GP & AVANÇAR"
		_update_ui()

func _on_btn_start_pressed() -> void:
	if engine.is_finished():
		_finish_race_and_advance()
		return
		
	if race_timer.is_stopped():
		race_timer.start(timer_speed)
		btn_start.text = "⏸ PAUSAR"
	else:
		race_timer.stop()
		btn_start.text = "▶ CONTINUAR"

func _on_tick() -> void:
	if not engine.is_quali_done():
		engine.process_quali_tick(sim_step_delta)
		_update_ui()
		if not engine.is_quali_done():
			race_timer.start(timer_speed)
		else:
			btn_start.text = "▶ INICIAR CORRIDA"
	elif not engine.is_finished():
		if engine.safety_car_status != "NONE" and timer_speed < 1.0:
			_set_speed_mode(1.0, 1.0)
			
		var res = engine.process_lap()
		_update_ui()
		
		if res.get("red_flag", false):
			race_timer.stop()
			btn_start.text = "▶ CONTINUAR"
			_show_red_flag_modal()
			return

		if not engine.is_finished():
			race_timer.start(timer_speed)
		else:
			btn_start.text = "🏁 CONCLUIR GP & AVANÇAR"

func _show_red_flag_modal() -> void:
	if is_instance_valid(active_modal):
		active_modal.queue_free()
		
	active_modal = ColorRect.new()
	active_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_modal.color = Color(0, 0, 0, 0.85)
	add_child(active_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_modal.add_child(center)
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 220)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.border_width_top = 3
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(6)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	
	var lbl_title = Label.new()
	lbl_title.text = "🔴 BANDEIRA VERMELHA!"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 16)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var lbl_msg = Label.new()
	lbl_msg.text = "A corrida foi interrompida na Volta %d. Todos os carros recolheram aos boxes e as equipes estão realizando a troca de pneus para a relargada em Grid Parado." % engine.current_lap
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.add_theme_font_size_override("font_size", 12)
	lbl_msg.add_theme_color_override("font_color", Color("#cbd5e1"))
	vbox.add_child(lbl_msg)

	var btn_restart = Button.new()
	btn_restart.text = "▶ RELARGAR CORRIDA"
	btn_restart.custom_minimum_size.y = 38
	btn_restart.add_theme_font_size_override("font_size", 12)
	
	var style_btn = StyleBoxFlat.new()
	style_btn.bg_color = Color(0.8, 0.15, 0.15, 1.0)
	style_btn.set_corner_radius_all(4)
	btn_restart.add_theme_stylebox_override("normal", style_btn)
	
	btn_restart.pressed.connect(func():
		engine.resolve_red_flag_restart("")
		active_modal.queue_free()
		active_modal = null
		_update_ui()
	)
	
	vbox.add_child(btn_restart)
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

func _update_ui() -> void:
	# Trava de Segurança Inteligente: Tenta recuperar o motor do Database antes de desistir
	if engine == null:
		if Database.active_engine != null:
			engine = Database.active_engine
		else:
			return

	# Garante a leitura da pista atual do calendário
	var current_gp_idx = clamp(Database.current_gp - 1, 0, Database.tracks.size() - 1)
	var current_track = Database.tracks[current_gp_idx]
	
	var flag_text = "NENHUMA (Normal)"
	var flag_color = Color("#22c55e")
	
	# Verifica o status de bandeira / safety car
	if "safety_car_status" in engine:
		match engine.safety_car_status:
			"SC":
				flag_text = "🚨 SAFETY CAR (SC)"
				flag_color = Color("#ef4444")
			"VSC":
				flag_text = "🟡 VIRTUAL SAFETY CAR (VSC)"
				flag_color = Color("#f59e0b")
			"YELLOW":
				flag_text = "⚠️ BANDEIRA AMARELA"
				flag_color = Color("#facc15")
			"RED_FLAG":
				flag_text = "🔴 BANDEIRA VERMELHA"
				flag_color = Color("#ef4444")

	var weather_str = "Clima: " + engine.weather_state + " | Radar: " + engine.weather_forecast + " | Status: " + flag_text
	weather_lbl.text = weather_str
	weather_lbl.add_theme_color_override("font_color", flag_color if engine.safety_car_status != "NONE" else Color("#38bdf8"))

	# Atualiza os valores das barras dinamicamente a cada tick
	if water_bar:
		water_bar.value = engine.water_level
	if grip_bar:
		grip_bar.value = engine.track_grip

	_update_safety_banner()
	
	if not engine.is_quali_done():
		race_grid_node.columns = 8
		var limit = engine.quali_durations.get(engine.quali_phase, 1080.0)
		var remaining = max(0.0, limit - engine.quali_time_elapsed)
		var clock_str = engine.format_session_clock(remaining)
		if engine.quali_checker_flag:
			clock_str = "00:00 (⏱️ AGUARDANDO VOLTAS FINAIS)"
		top_title.text = "QUALIFICAÇÃO (" + str(engine.quali_phase) + ") - GP " + str(Database.current_gp) + " (" + str(current_track["Nome"]) + ") - Tempo Restante: " + clock_str
		_render_quali_grid()
	else:
		race_grid_node.columns = 9
		top_title.text = "GP " + str(Database.current_gp) + " (" + str(current_track["Nome"]) + ") - Volta " + str(engine.current_lap) + "/" + str(engine.total_laps)
		_render_race_grid()
		
	log_text_node.clear()
	for entry in engine.race_logs:
		log_text_node.append_text(entry + "\n")
		
	pit_log_text_node.clear()
	for pit_entry in engine.pit_logs:
		pit_log_text_node.append_text(pit_entry + "\n")

func _update_safety_banner() -> void:
	if engine == null or engine.safety_car_status == "NONE":
		banner_container.visible = false
		return

	banner_container.visible = true
	var b_style = StyleBoxFlat.new()
	b_style.set_corner_radius_all(4)

	match engine.safety_car_status:
		"SC":
			b_style.bg_color = Color(0.8, 0.15, 0.15, 0.25)
			b_style.border_color = Color("#ef4444")
			b_style.border_width_left = 6
			banner_label.text = "🚨 SAFETY CAR EM PISTA — ULTRAPASSAGENS PROIBIDAS — VELOCIDADE REDUZIDA"
			banner_label.add_theme_color_override("font_color", Color("#ef4444"))

		"VSC":
			b_style.bg_color = Color(0.9, 0.6, 0.1, 0.25)
			b_style.border_color = Color("#f59e0b")
			b_style.border_width_left = 6
			banner_label.text = "🟡 VIRTUAL SAFETY CAR (VSC) — MANTENHA O DELTA POSITIVO"
			banner_label.add_theme_color_override("font_color", Color("#f59e0b"))

		"YELLOW":
			b_style.bg_color = Color(0.9, 0.8, 0.1, 0.25)
			b_style.border_color = Color("#facc15")
			b_style.border_width_left = 6
			var sec_str = " NO SETOR " + str(engine.incident_sector) if engine.incident_sector > 0 else ""
			banner_label.text = "⚠️ BANDEIRA AMARELA" + sec_str + " — REDUZA O RITMO"
			banner_label.add_theme_color_override("font_color", Color("#facc15"))

		"RED_FLAG":
			b_style.bg_color = Color(0.9, 0.1, 0.1, 0.35)
			b_style.border_color = Color("#dc2626")
			b_style.border_width_left = 6
			banner_label.text = "🔴 BANDEIRA VERMELHA — SESSÃO INTERROMPIDA — RETORNE AOS BOXES"
			banner_label.add_theme_color_override("font_color", Color("#ef4444"))
	
	# Quando um evento de Safety Car / VSC / Bandeira Amarela é acionado:
	if Database.reduce_speed_on_sc:
		# Força a redução da velocidade da corrida para 1x
		_set_speed_mode(1.0, 1.0)
	else:
		# Se a opção estiver desativada pelo jogador, mantém a velocidade que o jogador já havia selecionado!
		pass

	banner_container.add_theme_stylebox_override("panel", b_style)

func _render_quali_grid() -> void:
	for c in race_grid_node.get_children():
		c.queue_free()
		
	_add_grid_header("POS", 40)
	_add_grid_header("PILOTO", 150)
	_add_grid_header("PNEU", 60)
	_add_grid_header("SITUAÇÃO", 100)
	_add_grid_header("SETORES", 80)
	_add_grid_header("MELHOR VOLTA", 100)
	_add_grid_header("ÚLTIMA VOLTA", 160)
	_add_grid_header("ZONA STATUS", 120)

	var pos = 1
	var list: Array = []
	
	var current_actives = engine.active_quali_drivers.duplicate()
	
	# Ordena considerando 0.0 ou 999.0 como tempos ainda não registrados
	current_actives.sort_custom(func(a, b):
		var time_a = float(a.get("BestQualiTime", 999.0))
		var time_b = float(b.get("BestQualiTime", 999.0))
		
		# Trata 0.0 como sem tempo registrado
		if is_zero_approx(time_a): time_a = 999.0
		if is_zero_approx(time_b): time_b = 999.0
		
		if time_a >= 900.0 and time_b >= 900.0:
			return str(a.get("Nome", "")) < str(b.get("Nome", ""))
		if time_a < 900.0 and time_b >= 900.0:
			return true
		if time_a >= 900.0 and time_b < 900.0:
			return false
		return time_a < time_b
	)
	
	for act in current_actives:
		list.append(act)
		
	for elim in engine.eliminated_drivers:
		list.append(elim)
		
	for d in list:
		var is_eliminated = str(d.get("QualiStatus", "")).begins_with("ELIMINADO")
		var is_in_danger_zone = false
		
		if not is_eliminated:
			if engine.quali_phase == "Q1" and pos >= 17:
				is_in_danger_zone = true
			elif engine.quali_phase == "Q2" and pos >= 11:
				is_in_danger_zone = true

		var row_color = Color("#f87171") if (is_in_danger_zone or is_eliminated) else Color("#ffffff")

		_add_cell("P" + str(pos), row_color)
		_add_cell(str(d.get("Nome", "")) + " (" + str(d.get("Equipe", "")) + ")", row_color)
		
		var compound = str(d.get("tire_compound", "Soft"))
		_add_cell(compound, _get_compound_color(compound))
		
		var state_text = "🛠️ Box"
		var state_color = Color("#94a3b8")
		if is_eliminated:
			state_text = str(d.get("QualiStatus", "ELIMINADO"))
			state_color = Color("#ef4444")
		else:
			match str(d.get("quali_state", "Box")):
				"Em pista":
					state_text = "🟡 Em pista"
					state_color = Color("#eab308")
				"Hot Lap":
					state_text = "⚡ Hot Lap"
					state_color = Color("#22c55e")
				"Em Entrada":
					state_text = "🔴 Em Entrada"
					state_color = Color("#f97316")
		_add_cell(state_text, state_color)
		
		var sec_colors = d.get("sector_colors", {"s1": "🟡", "s2": "🟡", "s3": "🟡"})
		var sectors_str = "%s %s %s" % [sec_colors.get("s1", "🟡"), sec_colors.get("s2", "🟡"), sec_colors.get("s3", "🟡")]
		_add_cell(sectors_str, Color("#ffffff"))
		
		# Leitura da MELHOR VOLTA (verifica BestQualiTime e best_lap)
		var best_t = float(d.get("BestQualiTime", d.get("best_lap", 999.0)))
		var best_str = "--:--.---"
		if best_t > 30.0 and best_t < 900.0:
			best_str = engine.format_time_f1(best_t)
			
		_add_cell(best_str, Color("#22c55e") if (best_t > 30.0 and best_t < 900.0) else Color("#ffffff"))
		
		# Leitura da ÚLTIMA VOLTA
		var last_t = float(d.get("LastLapTime", d.get("last_lap", 999.0)))
		var last_str = "--:--.---"
		if last_t > 30.0 and last_t < 900.0:
			last_str = engine.format_time_f1(last_t)
			
		_add_cell(last_str, Color("#ffffff"))
		
		var danger_str = "Zona de eliminação" if is_in_danger_zone else ("Eliminado" if is_eliminated else "Classificado")
		var danger_color = Color("#ef4444") if (is_in_danger_zone or is_eliminated) else Color("#22c55e")
		_add_cell(danger_str, danger_color)

		pos += 1

func _render_race_grid() -> void:
	for c in race_grid_node.get_children():
		c.queue_free()
		
	_add_grid_header("POS", 40)
	_add_grid_header("PILOTO", 150)
	_add_grid_header("PNEU / DESGASTE", 140)
	_add_grid_header("PARADAS", 70)
	_add_grid_header("STATUS", 90)
	_add_grid_header("SETORES", 80)
	_add_grid_header("GAP", 70)
	_add_grid_header("ÚLTIMA VOLTA", 100)
	_add_grid_header("POSIÇÕES GANHAS", 120)
		
	var pos = 1
	var leader_time = 0.0
	if engine.race_drivers.size() > 0:
		leader_time = float(engine.race_drivers[0].get("TempoTotal", 0.0))
		
	for d in engine.race_drivers:
		var is_pit = d.get("is_in_pit", false)
		var driver_status = str(d.get("Status", "Na Pista"))
		
		var text_color = Color("#ffffff")
		if is_pit:
			text_color = Color("#f97316")
		elif driver_status != "Na Pista":
			text_color = Color("#ef4444")
			
		_add_cell("P" + str(pos), text_color)
		_add_cell(str(d["Nome"]) + " (" + str(d["Equipe"]) + ")", text_color)
		
		var compound = str(d.get("tire_compound", "Medium"))
		var wear_val = int(d.get("tire_wear", 100))
		_add_cell(compound + " (" + str(wear_val) + "%)", _get_compound_color(compound) if not is_pit else Color("#f97316"))
		
		var pits = int(d.get("pit_stops", 0))
		_add_cell(str(pits) + " pit", text_color)
		
		if driver_status != "Na Pista":
			_add_cell("💥 Out", Color("#ef4444"))
		elif is_pit:
			_add_cell("🛠️ EM PIT", Color("#f97316"))
		else:
			_add_cell("🟢 Em pista", Color("#22c55e"))
			
		var sec_colors = d.get("sector_colors", {"s1": "🟡", "s2": "🟡", "s3": "🟡"})
		var sectors_str = "%s %s %s" % [sec_colors.get("s1", "🟡"), sec_colors.get("s2", "🟡"), sec_colors.get("s3", "🟡")]
		_add_cell(sectors_str, text_color)
		
		if driver_status != "Na Pista":
			_add_cell(driver_status, Color("#ef4444"))
		elif pos == 1:
			_add_cell("LÍDER", Color("#22c55e"))
		else:
			var diff = float(d.get("TempoTotal", 0.0)) - leader_time
			_add_cell("+" + str(snapped(diff, 0.1)) + "s", text_color)
			
		var last_t = float(d.get("LastLapTime", 999.0))
		var last_str = engine.format_time_f1(last_t) if last_t < 900.0 else "--:--.---"
		_add_cell(last_str, text_color)
		
		var start_pos = int(d.get("grid_start_pos", pos))
		var pos_diff = start_pos - pos
		var diff_str = str(pos_diff) if pos_diff <= 0 else "+" + str(pos_diff)
		var diff_color = Color("#22c55e") if pos_diff > 0 else (Color("#ef4444") if pos_diff < 0 else Color("#94a3b8"))
		_add_cell(diff_str, diff_color)

		pos += 1

func _add_grid_header(text: String, min_w: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#ef4444"))
	race_grid_node.add_child(lbl)

func _add_cell(text: String, color: Color = Color("#ffffff")) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	race_grid_node.add_child(lbl)

func _get_compound_color(compound: String) -> Color:
	match compound.to_upper():
		"SOFT", "S": return Color("#ef4444")
		"MEDIUM", "M": return Color("#facc15")
		"HARD", "H": return Color("#ffffff")
		"INTER", "I": return Color("#22c55e")
		"WET", "W": return Color("#38bdf8")
		_: return Color("#94a3b8")

# Finaliza a corrida de forma limpa
func _finish_race_and_advance() -> void:
	if engine != null:
		var standings = engine.race_drivers.duplicate(true)
		Database.apply_race_points(standings)
		Database.record_standings_history_after_gp()
		Database.active_engine = null
	
	if Database.current_gp >= Database.tracks.size():
		Database.end_season_and_advance_year()
	else:
		Database.current_gp += 1
		
	Database.current_view = "dashboard"
	get_tree().reload_current_scene()

# Variáveis globais de suporte para a classificação e estratégias do Modo Manager
var quali_grid_data: Array = []
var player_race_strategies: Dictionary = {}

# =============================================================
# JANELA MODAL DE PLANEJAMENTO ESTRATÉGICO PRÉ-CORRIDA
# =============================================================
func _open_pre_race_strategy_modal(total_race_laps: int = 57) -> void:
	var selected_drivers = _get_user_drivers()
	# Inicializa as estruturas de estratégia padrão caso não existam
	for i in range(selected_drivers.size()):
		if not player_race_strategies.has(i):
			player_race_strategies[i] = {
				"start_tire": "Médio (C4)",
				"pit_stops": [
					{"lap": int(total_race_laps * 0.4), "tire": "Duro (C3)"}
				]
			}
			
	var dialog = Window.new()
	dialog.title = "📊 PLANEJAMENTO DE ESTRATÉGIA DE CORRIDA - MODO MANAGER"
	dialog.size = Vector2i(900, 650)
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
	
	var vbox_main = VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 15)
	
	# Cabeçalho
	var l_head = Label.new()
	l_head.text = "🏁 MONTE A ESTRATÉGIA DE PARADAS E PNEUS (%d VOLTAS TOTAL)" % total_race_laps
	l_head.add_theme_font_size_override("font_size", 16)
	l_head.add_theme_color_override("font_color", Color("#22c55e"))
	vbox_main.add_child(l_head)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var hbox_drivers = HBoxContainer.new()
	hbox_drivers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_drivers.add_theme_constant_override("separation", 20)
	
	# Constrói o editor de estratégia para o Piloto 1 e Piloto 2
	for i in range(selected_drivers.size()):
		var d_card = _build_driver_strategy_editor(i, selected_drivers[i], total_race_laps)
		hbox_drivers.add_child(d_card)
		
	scroll.add_child(hbox_drivers)
	vbox_main.add_child(scroll)
	
	# Botão de Confirmação da Estratégia
	var btn_start_race = Button.new()
	btn_start_race.text = "🏁 CONFIRMAR ESTRATÉGIAS E IR PARA O GRID DE LARGADA ▶"
	btn_start_race.custom_minimum_size.y = 50
	btn_start_race.add_theme_font_size_override("font_size", 15)
	
	var st_btn = StyleBoxFlat.new()
	st_btn.bg_color = Color("#16a34a") # Verde
	st_btn.set_corner_radius_all(4)
	btn_start_race.add_theme_stylebox_override("normal", st_btn)
	
	btn_start_race.pressed.connect(func():
		# Salva a estratégia na Database para que a corrida leia durante a simulação
		Database.user_team["race_strategies"] = player_race_strategies.duplicate(true)
		dialog.queue_free()
		_start_race_simulation() # Inicia a corrida!
	)
	
	vbox_main.add_child(btn_start_race)
	margin.add_child(vbox_main)
	dialog.add_child(margin)
	add_child(dialog)
	dialog.popup_centered()

# Constrói a coluna de montagem de estratégia por piloto
func _build_driver_strategy_editor(driver_idx: int, driver_data: Dictionary, total_laps: int) -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#1e293b")
	st.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", st)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	# Nome do Piloto
	var l_name = Label.new()
	l_name.text = "🏎️ " + str(driver_data.get("Nome", driver_data.get("nome", "Piloto")))
	l_name.add_theme_font_size_override("font_size", 15)
	l_name.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(l_name)
	
	# 1. Pneu de Largada
	var h_start = HBoxContainer.new()
	var l_start = Label.new()
	l_start.text = "Pneu de Largada: "
	l_start.add_theme_font_size_override("font_size", 12)
	h_start.add_child(l_start)
	
	var opt_start = OptionButton.new()
	opt_start.add_item("Macio (C5)", 0)
	opt_start.add_item("Médio (C4)", 1)
	opt_start.add_item("Duro (C3)", 2)
	opt_start.select(1) # Padrão: Médio
	
	opt_start.item_selected.connect(func(sel):
		var tires = ["Macio (C5)", "Médio (C4)", "Duro (C3)"]
		player_race_strategies[driver_idx]["start_tire"] = tires[sel]
	)
	h_start.add_child(opt_start)
	vbox.add_child(h_start)
	
	vbox.add_child(HSeparator.new())
	
	# 2. Container de Paradas (Pit Stops)
	var l_pits = Label.new()
	l_pits.text = "📋 Paradas Programadas (Pit Stops):"
	l_pits.add_theme_font_size_override("font_size", 13)
	l_pits.add_theme_color_override("font_color", Color("#38bdf8"))
	vbox.add_child(l_pits)
	
	var pit_list_vbox = VBoxContainer.new()
	pit_list_vbox.name = "PitListVBox"
	vbox.add_child(pit_list_vbox)
	
	# Renderiza os pit stops existentes
	_render_pit_stops_list(driver_idx, pit_list_vbox, total_laps)
	
	# 3. Botão para Adicionar Nova Parada
	var btn_add_pit = Button.new()
	btn_add_pit.text = "➕ Adicionar Parada no Box"
	btn_add_pit.pressed.connect(func():
		var current_pits: Array = player_race_strategies[driver_idx]["pit_stops"]
		if current_pits.size() < 3: # Limite de até 3 paradas na estratégia
			var last_lap = 20 if current_pits.is_empty() else int(current_pits.back()["lap"]) + 15
			current_pits.append({"lap": min(last_lap, total_laps - 2), "tire": "Duro (C3)"})
			_render_pit_stops_list(driver_idx, pit_list_vbox, total_laps)
	)
	vbox.add_child(btn_add_pit)
	
	margin.add_child(vbox)
	panel.add_child(margin)
	return panel


# Renderiza as linhas de seleção de cada pit stop
func _render_pit_stops_list(driver_idx: int, container: VBoxContainer, total_laps: int) -> void:
	for c in container.get_children():
		c.queue_free()
		
	var pit_stops: Array = player_race_strategies[driver_idx]["pit_stops"]
	
	for p_idx in range(pit_stops.size()):
		var stop_data = pit_stops[p_idx]
		
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		
		var lbl_stop = Label.new()
		lbl_stop.text = "Pit %d: Volta" % (p_idx + 1)
		lbl_stop.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl_stop)
		
		# SpinBox para escolher a volta da parada
		var spin_lap = SpinBox.new()
		spin_lap.min_value = 1
		spin_lap.max_value = total_laps - 1
		spin_lap.value = float(stop_data["lap"])
		spin_lap.value_changed.connect(func(val):
			stop_data["lap"] = int(val)
		)
		row.add_child(spin_lap)
		
		# Seletor do Pneu a ser colocado na parada
		var opt_tire = OptionButton.new()
		opt_tire.add_item("Macio (C5)", 0)
		opt_tire.add_item("Médio (C4)", 1)
		opt_tire.add_item("Duro (C3)", 2)
		
		var t_str = str(stop_data["tire"])
		opt_tire.select(1 if "C4" in t_str else (2 if "C3" in t_str else 0))
		opt_tire.item_selected.connect(func(sel):
			var tires = ["Macio (C5)", "Médio (C4)", "Duro (C3)"]
			stop_data["tire"] = tires[sel]
		)
		row.add_child(opt_tire)
		
		# Botão para Remover esta Parada
		var btn_del = Button.new()
		btn_del.text = "❌"
		btn_del.pressed.connect(func():
			pit_stops.remove_at(p_idx)
			_render_pit_stops_list(driver_idx, container, total_laps)
		)
		row.add_child(btn_del)
		
		container.add_child(row)

# Busca os pilotos da equipe do jogador de forma ultra-resiliente
func _get_user_drivers() -> Array:
	var user_drivers: Array = []
	
	# 1. Tenta buscar da lista direta em Database.user_team
	if not Database.user_team.is_empty():
		if Database.user_team.has("pilotos") and typeof(Database.user_team["pilotos"]) == TYPE_ARRAY and not Database.user_team["pilotos"].is_empty():
			return Database.user_team["pilotos"]
		if Database.user_team.has("selected_drivers") and typeof(Database.user_team["selected_drivers"]) == TYPE_ARRAY and not Database.user_team["selected_drivers"].is_empty():
			return Database.user_team["selected_drivers"]
			
	# 2. Busca na lista global Database.drivers comparando com o nome da sua equipe
	var my_team_name = ""
	if not Database.user_team.is_empty():
		my_team_name = str(Database.user_team.get("nome", Database.user_team.get("Nome", "")))
		
	if "drivers" in Database and Database.drivers != null:
		for d in Database.drivers:
			var d_team = str(d.get("Equipe", d.get("equipe", "")))
			if my_team_name != "" and d_team == my_team_name:
				user_drivers.append(d)
			elif d.get("is_player", false):
				user_drivers.append(d)
				
	# 3. Se ainda não encontrou, pega os 2 primeiros pilotos marcados no grid da sessão
	if user_drivers.is_empty() and "drivers" in Database and Database.drivers != null:
		if Database.drivers.size() >= 2:
			return [Database.drivers[0], Database.drivers[1]]
			
	return user_drivers

# Inicia a simulação oficial da corrida após confirmar a estratégia
func _start_race_simulation() -> void:
	# Define o estado da sessão no banco de dados
	Database.current_session = "race"
	
	# Se houver um painel/função de inicialização de interface, recalcula o layout
	if has_method("build_ui"):
		call("build_ui")
	elif has_method("_build_ui"):
		call("_build_ui")
	elif has_method("_init_race_session"):
		call("_init_race_session")

func _process(delta: float) -> void:
	if engine == null:
		return
		
	if not "race_drivers" in engine or engine.race_drivers.is_empty():
		return
