extends Control

var engine: RaceEngine
var race_timer: Timer

@onready var top_title: Label
@onready var weather_lbl: Label
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

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_ui()

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)
	
	var track_info = Database.tracks[Database.current_gp - 1]
	
	top_title = Label.new()
	top_title.text = "QUALIFICAÇÃO (Q1) - GP " + str(Database.current_gp) + " (" + str(track_info.get("Nome", "")) + ")"
	top_title.add_theme_font_size_override("font_size", 18)
	top_title.add_theme_color_override("font_color", Color("#ef4444"))
	main_vbox.add_child(top_title)
	
	weather_lbl = Label.new()
	weather_lbl.add_theme_font_size_override("font_size", 13)
	weather_lbl.add_theme_color_override("font_color", Color("#22c55e"))
	main_vbox.add_child(weather_lbl)
	
	var ctrl_hbox = HBoxContainer.new()
	ctrl_hbox.add_theme_constant_override("separation", 8)
	
	btn_start = Button.new()
	btn_start.text = "▶ CONTINUAR"
	btn_start.custom_minimum_size = Vector2(130, 32)
	btn_start.pressed.connect(_on_btn_start_pressed)
	ctrl_hbox.add_child(btn_start)
	
	btn_speed_1x = Button.new()
	btn_speed_1x.text = "1x (Tempo Real)"
	btn_speed_1x.pressed.connect(func(): _set_speed_mode(1.0, 1.0))
	ctrl_hbox.add_child(btn_speed_1x)
	
	btn_speed_2x = Button.new()
	btn_speed_2x.text = "2x"
	btn_speed_2x.pressed.connect(func(): _set_speed_mode(0.5, 1.0))
	ctrl_hbox.add_child(btn_speed_2x)
	
	btn_speed_5x = Button.new()
	btn_speed_5x.text = "5x"
	btn_speed_5x.pressed.connect(func(): _set_speed_mode(0.2, 1.0))
	ctrl_hbox.add_child(btn_speed_5x)
	
	btn_speed_10x = Button.new()
	btn_speed_10x.text = "10x"
	btn_speed_10x.pressed.connect(func(): _set_speed_mode(0.1, 1.0))
	ctrl_hbox.add_child(btn_speed_10x)

	btn_speed_20x = Button.new()
	btn_speed_20x.text = "20x"
	btn_speed_20x.pressed.connect(func(): _set_speed_mode(0.05, 1.0))
	ctrl_hbox.add_child(btn_speed_20x)
	
	btn_speed_skip = Button.new()
	btn_speed_skip.text = "⏭ PULAR PARA O FINAL DA SESSÃO"
	btn_speed_skip.pressed.connect(_skip_to_end_of_session)
	ctrl_hbox.add_child(btn_speed_skip)
	
	main_vbox.add_child(ctrl_hbox)
	
	var main_hbox = HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 12)
	
	var left_panel = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 2.0
	
	left_vbox = VBoxContainer.new()
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	race_grid_node = GridContainer.new()
	race_grid_node.columns = 9
	race_grid_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	race_grid_node.add_theme_constant_override("h_separation", 10)
	race_grid_node.add_theme_constant_override("v_separation", 6)
	scroll.add_child(race_grid_node)
	left_vbox.add_child(scroll)

	banner_container = PanelContainer.new()
	banner_container.visible = false
	banner_container.custom_minimum_size.y = 48

	var margin_b = MarginContainer.new()
	margin_b.add_theme_constant_override("margin_left", 12)
	margin_b.add_theme_constant_override("margin_right", 12)
	margin_b.add_theme_constant_override("margin_top", 10)
	margin_b.add_theme_constant_override("margin_bottom", 10)

	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 16)
	margin_b.add_child(banner_label)
	banner_container.add_child(margin_b)

	left_vbox.add_child(banner_container)
	left_panel.add_child(left_vbox)
	main_hbox.add_child(left_panel)
	
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_theme_font_size_override("font_size", 12)
	
	var tab_events = VBoxContainer.new()
	tab_events.name = "📢 INCIDENTES & CLIMA"
	log_text_node = RichTextLabel.new()
	log_text_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text_node.scroll_following = true
	tab_events.add_child(log_text_node)
	tab_container.add_child(tab_events)
	
	var tab_pits = VBoxContainer.new()
	tab_pits.name = "🛠️ PIT STOPS"
	pit_log_text_node = RichTextLabel.new()
	pit_log_text_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pit_log_text_node.scroll_following = true
	tab_pits.add_child(pit_log_text_node)
	tab_container.add_child(tab_pits)
	
	right_panel.add_child(tab_container)
	main_hbox.add_child(right_panel)
	main_vbox.add_child(main_hbox)
	
	if Database.active_engine == null:
		Database.active_engine = RaceEngine.new()
		Database.active_engine.setup_race(track_info)
		
	engine = Database.active_engine
	
	race_timer = Timer.new()
	race_timer.one_shot = true
	race_timer.wait_time = timer_speed
	race_timer.timeout.connect(_on_tick)
	add_child(race_timer)
	
	_update_ui()

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
	var current_track = Database.tracks[Database.current_gp - 1]
	
	var flag_text = "NENHUMA (Normal)"
	var flag_color = Color("#22c55e")
	
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

	var weather_str = "Clima: " + engine.weather_state + " (" + str(snapped(engine.water_level, 0.1)) + "% água) | Radar: " + engine.weather_forecast
	weather_lbl.text = weather_str + " | Status da Pista: " + flag_text
	weather_lbl.add_theme_color_override("font_color", flag_color if engine.safety_car_status != "NONE" else Color("#38bdf8"))

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
	current_actives.sort_custom(func(a, b):
		var time_a = float(a.get("BestQualiTime", 999.0))
		var time_b = float(b.get("BestQualiTime", 999.0))
		if time_a >= 900.0 and time_b >= 900.0:
			return str(a["Nome"]) < str(b["Nome"])
		if time_a < 900.0 and time_b >= 900.0:
			return true
		if time_a >= 900.0 and time_b < 900.0:
			return false
		if time_a == time_b:
			return str(a["Nome"]) < str(b["Nome"])
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
		_add_cell(str(d["Nome"]) + " (" + str(d["Equipe"]) + ")", row_color)
		
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
		
		var best_t = float(d.get("BestQualiTime", 999.0))
		var best_str = engine.format_time_f1(best_t) if best_t < 900.0 else "--:--.---"
		_add_cell(best_str, Color("#22c55e") if best_t < 900.0 else Color("#ffffff"))
		
		var last_t = float(d.get("LastLapTime", 999.0))
		var last_str = "--:--.---"
		if last_t < 900.0:
			last_str = engine.format_time_f1(last_t)
			if best_t < 900.0 and last_t > best_t:
				var diff = last_t - best_t
				last_str += " (+" + str(snapped(diff, 0.001)) + "s)"
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

func _finish_race_and_advance() -> void:
	var standings = engine.race_drivers.duplicate(true)
	
	for i in range(standings.size()):
		standings[i]["pos"] = i + 1
		var grid_pos = standings[i].get("grid_start_pos", i + 1)
		standings[i]["grid_pos"] = grid_pos
		
		var st_text = str(standings[i].get("Status", standings[i].get("status", ""))).to_lower()
		if st_text != "na pista" and st_text != "ok" and not st_text.is_empty():
			standings[i]["dnf"] = true
			standings[i]["abandonou"] = true

	var podium = []
	for i in range(min(3, standings.size())):
		podium.append({"Nome": standings[i].get("Nome", "-"), "Equipe": standings[i].get("Equipe", "-")})
		
	var track_curr = Database.tracks[Database.current_gp - 1]
	Database.race_history.append({
		"gp_num": Database.current_gp,
		"track": track_curr.get("Nome", ""),
		"podium": podium
	})

	# --- APLICAÇÃO OFICIAL DE PONTOS NO CAMPEONATO ---
	Database.apply_race_points(standings)

	# Atualizações de Moral, Respeito e Teto de Gastos das equipes
	Database.process_post_race_morale_and_respect(standings)
	Database.process_ai_team_upgrades()
	
	Database.active_engine = null
	
	if Database.current_gp >= Database.tracks.size():
		Database.end_season_and_advance_year()
	else:
		Database.current_gp += 1
		
	Database.current_view = "dashboard"
	get_tree().reload_current_scene()
