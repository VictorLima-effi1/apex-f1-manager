extends Control

var engine: RaceEngine
var player_race_strategies: Dictionary = {}
var manager_panel_container: VBoxContainer

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

var simulation_speed: float = 1.0
var simulation_running: bool = false
var race_lap_elapsed: float = 0.0
var ui_refresh_elapsed: float = 0.0
var _dbg_process_logged: bool = false

func _agent_dbg(hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	# #region agent log
	var path := "C:/Users/Limad/Desktop/Apex/apex-f1-manager/debug-2b010b.log"
	var fa := FileAccess.open(path, FileAccess.READ_WRITE)
	if fa == null:
		fa = FileAccess.open(path, FileAccess.WRITE)
	else:
		fa.seek_end()
	if fa == null:
		return
	var payload := {
		"sessionId": "2b010b",
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0),
		"location": location,
		"message": message,
		"data": data,
		"hypothesisId": hypothesis_id,
		"runId": "post-fix"
	}
	fa.store_line(JSON.stringify(payload))
	fa.close()
	# #endregion

func _ready() -> void:
	# #region agent log
	_agent_dbg("A", "race_view.gd:_ready", "Race view ready start", {
		"active_engine_null": Database.active_engine == null,
		"drivers_count": Database.drivers.size() if Database.drivers != null else -1,
		"size_flags_h": size_flags_horizontal,
		"size_flags_v": size_flags_vertical,
		"control_size": {"x": size.x, "y": size.y}
	})
	# #endregion
	if Database.active_engine == null:
		var engine_path := "res://race_engine.gd"
		if not ResourceLoader.exists(engine_path):
			engine_path = "res://views/race_engine.gd"
		var race_engine_script = load(engine_path)
		# #region agent log
		_agent_dbg("A", "race_view.gd:_ready", "Tried load race engine", {
			"path": engine_path,
			"script_null": race_engine_script == null,
			"root_exists": ResourceLoader.exists("res://race_engine.gd")
		})
		# #endregion
		if race_engine_script != null:
			engine = race_engine_script.new()
			Database.active_engine = engine
	else:
		engine = Database.active_engine

	var current_gp_idx = clamp(Database.current_gp - 1, 0, Database.tracks.size() - 1)
	var track_info = Database.tracks[current_gp_idx]

	if engine != null and (not "active_quali_drivers" in engine or engine.active_quali_drivers.is_empty()):
		if engine.has_method("setup_race"):
			engine.setup_race(track_info)

	# #region agent log
	_agent_dbg("B", "race_view.gd:_ready", "After setup_race", {
		"engine_null": engine == null,
		"quali_count": engine.active_quali_drivers.size() if engine != null else -1,
		"race_count": engine.race_drivers.size() if engine != null else -1
	})
	# #endregion

	build_ui()

	_update_ui()

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	var current_gp_idx = clamp(Database.current_gp - 1, 0, Database.tracks.size() - 1)
	var track_info = Database.tracks[current_gp_idx]

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
	btn_speed_1x.pressed.connect(func(): _set_speed_mode(1.0))
	ctrl_hbox.add_child(btn_speed_1x)

	btn_speed_2x = Button.new()
	btn_speed_2x.text = "2x"
	btn_speed_2x.pressed.connect(func(): _set_speed_mode(2.0))
	ctrl_hbox.add_child(btn_speed_2x)

	btn_speed_5x = Button.new()
	btn_speed_5x.text = "5x"
	btn_speed_5x.pressed.connect(func(): _set_speed_mode(5.0))
	ctrl_hbox.add_child(btn_speed_5x)

	btn_speed_10x = Button.new()
	btn_speed_10x.text = "10x"
	btn_speed_10x.pressed.connect(func(): _set_speed_mode(10.0))
	ctrl_hbox.add_child(btn_speed_10x)

	btn_speed_20x = Button.new()
	btn_speed_20x.text = "20x"
	btn_speed_20x.pressed.connect(func(): _set_speed_mode(20.0))
	ctrl_hbox.add_child(btn_speed_20x)

	btn_speed_skip = Button.new()
	btn_speed_skip.text = "⏭ PULAR PARA O FINAL DA SESSÃO"
	btn_speed_skip.pressed.connect(_skip_to_end_of_session)
	ctrl_hbox.add_child(btn_speed_skip)

	main_vbox.add_child(ctrl_hbox)
	
	var game_mode = "manager"
	if "game_mode" in Database:
		game_mode = str(Database.game_mode)

	var is_manager_mode = (game_mode == "manager")
	if "is_manager_mode" in Database:
		is_manager_mode = is_manager_mode or bool(Database.is_manager_mode)

	var main_hbox = HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 12)
	
	var left_panel = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 2.0
	
	left_vbox = VBoxContainer.new()
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
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
	
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	
	if is_manager_mode:
		manager_panel_container = VBoxContainer.new()
		manager_panel_container.name = "ManagerPanelContainer"
		manager_panel_container.add_theme_constant_override("separation", 6)
		right_vbox.add_child(manager_panel_container)
		_build_manager_qualifying_controls(manager_panel_container)
	
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
	
	right_vbox.add_child(tab_container)
	right_panel.add_child(right_vbox)
	main_hbox.add_child(right_panel)
	main_vbox.add_child(main_hbox)

	# #region agent log
	_agent_dbg("D", "race_view.gd:build_ui", "UI built", {
		"self_size": {"x": size.x, "y": size.y},
		"child_count": get_child_count(),
		"grid_valid": is_instance_valid(race_grid_node),
		"size_flags_h": size_flags_horizontal,
		"size_flags_v": size_flags_vertical
	})
	# #endregion
	
	_update_ui()

func _build_manager_qualifying_controls(parent_container: Control) -> void:
	if not is_instance_valid(parent_container):
		return
	
	for c in parent_container.get_children():
		c.queue_free()
		
	var user_drivers = _get_user_drivers()
	if user_drivers.is_empty():
		return
	
	var manager_panel = PanelContainer.new()
	manager_panel.name = "ManagerQualiPanel"
	manager_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var st = StyleBoxFlat.new()
	st.bg_color = Color("#0f172a")
	st.border_width_top = 3
	st.border_color = Color("#38bdf8")
	st.set_corner_radius_all(6)
	manager_panel.add_theme_stylebox_override("panel", st)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	var vbox_main = VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 12)
	
	var lbl_title = Label.new()
	lbl_title.text = "🎧 COMANDOS TÁTICOS DA EQUIPE"
	lbl_title.add_theme_font_size_override("font_size", 14)
	lbl_title.add_theme_color_override("font_color", Color("#38bdf8"))
	vbox_main.add_child(lbl_title)
	vbox_main.add_child(HSeparator.new())
	
	for i in range(min(2, user_drivers.size())):
		var driver_data = user_drivers[i]
		var card = _create_single_driver_quali_card(i, driver_data)
		vbox_main.add_child(card)
		
	margin.add_child(vbox_main)
	manager_panel.add_child(margin)
	parent_container.add_child(manager_panel)

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
	
	var d_name = str(driver_data.get("Nome", driver_data.get("nome", "Piloto")))
	var l_name = Label.new()
	l_name.text = "🏎️ " + d_name
	l_name.add_theme_font_size_override("font_size", 13)
	cv.add_child(l_name)
	
	var current_status = _get_driver_quali_status(driver_index)
	var l_status = Label.new()
	l_status.name = "LblStatus_%d" % driver_index
	l_status.text = "Status: " + current_status
	l_status.add_theme_font_size_override("font_size", 11)
	l_status.add_theme_color_override("font_color", Color("#34d399") if ("Pista" in current_status or "Em pista" in current_status or "Hot Lap" in current_status) else Color("#f87171"))
	cv.add_child(l_status)
	
	var ch = HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	
	var opt_tire = OptionButton.new()
	opt_tire.name = "OptTire_%d" % driver_index
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
	
	var opt_pace = OptionButton.new()
	opt_pace.name = "OptPace_%d" % driver_index
	opt_pace.add_item("🛡️ Conservador", 0)
	opt_pace.add_item("⚖️ Normal", 1)
	opt_pace.add_item("🔥 Ataque Máximo", 2)
	opt_pace.select(2)
	ch.add_child(opt_pace)
	
	var btn_action = Button.new()
	btn_action.name = "BtnAction_%d" % driver_index
	var is_on_track = ("Pista" in current_status or "Em pista" in current_status or "Hot Lap" in current_status or "Entrada" in current_status)
	btn_action.text = "🛑 RECOLHER" if is_on_track else "🚀 MANDAR À PISTA"
	btn_action.custom_minimum_size.x = 130
	btn_action.add_theme_font_size_override("font_size", 11)
	
	var idx = driver_index
	btn_action.pressed.connect(func():
		_on_manager_quali_action_pressed(idx, opt_tire.selected, opt_pace.selected)
	)
	ch.add_child(btn_action)
	
	cv.add_child(ch)
	cm.add_child(cv)
	card.add_child(cm)
	return card

func _on_manager_quali_action_pressed(driver_idx: int, tire_sel_idx: int, pace_sel_idx: int) -> void:
	var user_drivers = _get_user_drivers()
	if driver_idx >= user_drivers.size():
		return
	
	var target_driver = user_drivers[driver_idx]
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
					d["quali_state"] = "Em pista"
					d["tire_compound"] = chosen_tire
					d["estilo"] = chosen_pace
					d["is_in_pit"] = false
					d["tire_wear"] = 100.0
					d["progress"] = 0.0
					d["force_in_lap"] = false
				else:
					d["quali_state"] = "Em Entrada"
					d["force_in_lap"] = true
					d["estilo"] = chosen_pace
				break
				
	_update_manager_quali_ui_state()
	_update_ui()

func _get_driver_quali_status(driver_idx: int) -> String:
	var user_drivers = _get_user_drivers()
	if driver_idx >= user_drivers.size():
		return "Box"
	
	var driver_data = user_drivers[driver_idx]
	var driver_name = str(driver_data.get("Nome", driver_data.get("nome", "")))
	
	if engine != null and engine.active_quali_drivers != null:
		for d in engine.active_quali_drivers:
			var d_n = str(d.get("Nome", d.get("nome", "")))
			if d_n == driver_name:
				return str(d.get("quali_state", "Box"))
				
	return "Box"

func _update_manager_quali_ui_state() -> void:
	var user_drivers = _get_user_drivers()
	for i in range(user_drivers.size()):
		var st = _get_driver_quali_status(i)
		var btn = find_child("BtnAction_%d" % i, true, false)
		var lbl = find_child("LblStatus_%d" % i, true, false)
		var is_on_track = ("Pista" in st or "Em pista" in st or "Hot Lap" in st or "Entrada" in st)
		
		if is_instance_valid(btn):
			btn.text = "🛑 RECOLHER" if is_on_track else "🚀 MANDAR À PISTA"
		if is_instance_valid(lbl):
			lbl.text = "Status: " + st
			lbl.add_theme_color_override("font_color", Color("#34d399") if is_on_track else Color("#f87171"))

func _get_user_drivers() -> Array:
	var user_team = str(Database.user_team.get("nome", Database.user_team.get("Nome", "")))
	if user_team.is_empty() and not Database.selected_manager_team.is_empty():
		user_team = str(Database.selected_manager_team.get("Nome", Database.selected_manager_team.get("nome", "")))
	if user_team.is_empty() and "player_team" in Database:
		user_team = str(Database.player_team)
	if user_team.is_empty():
		user_team = "Ferrari"
	var drivers = []
	if engine != null and "active_quali_drivers" in engine:
		for d in engine.active_quali_drivers:
			if str(d.get("Equipe", "")) == user_team:
				drivers.append(d)
	return drivers

func _set_speed_mode(speed: float) -> void:
	simulation_speed = speed

func _skip_to_end_of_session() -> void:
	if engine != null and not engine.is_quali_done():
		engine.skip_to_end_of_quali_session()
		race_lap_elapsed = 0.0
		simulation_running = false
		_update_simulation_button()
		_update_ui()
	elif engine != null and not engine.is_finished():
		while not engine.is_finished():
			var res = engine.process_lap()
			if res.get("red_flag", false):
				_show_red_flag_modal()
				break
		simulation_running = false
		_update_simulation_button()
		_update_ui()

func _on_btn_start_pressed() -> void:
	if engine != null and engine.is_finished():
		_finish_race_and_advance()
		return

	if engine != null and engine.pending_red_flag_modal:
		engine.resolve_red_flag_restart()

	simulation_running = not simulation_running
	_update_simulation_button()

func _update_simulation_button() -> void:
	if not is_instance_valid(btn_start) or engine == null:
		return
	if engine.is_finished():
		btn_start.text = "🏁 CONCLUIR GP & AVANÇAR"
	else:
		btn_start.text = "⏸️ PAUSAR" if simulation_running else "▶ CONTINUAR"

func _show_red_flag_modal() -> void:
	pass

func _update_ui() -> void:
	# #region agent log
	_agent_dbg("C", "race_view.gd:_update_ui", "Update UI entry", {
		"engine_null": engine == null,
		"grid_valid": is_instance_valid(race_grid_node),
		"weather_valid": is_instance_valid(weather_lbl),
		"log_valid": is_instance_valid(log_text_node)
	})
	# #endregion
	if engine == null:
		if Database.active_engine != null:
			engine = Database.active_engine
		else:
			# #region agent log
			_agent_dbg("A", "race_view.gd:_update_ui", "Early return engine null", {})
			# #endregion
			return

	var current_gp_idx = clamp(Database.current_gp - 1, 0, Database.tracks.size() - 1)
	var current_track = Database.tracks[current_gp_idx]
	
	var flag_text = "NENHUMA (Normal)"
	var flag_color = Color("#22c55e")

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

	var weather_state = "☀️ Ensolarado"
	# #region agent log
	_agent_dbg("C", "race_view.gd:_update_ui", "Before engine.has weather_state", {
		"engine_class": engine.get_class() if engine != null else "null"
	})
	# #endregion
	if engine != null and "weather_state" in engine:
		weather_state = str(engine.weather_state)
	# #region agent log
	_agent_dbg("C", "race_view.gd:_update_ui", "After engine.has weather_state", {
		"weather_state": weather_state
	})
	# #endregion
	weather_lbl.text = weather_state
	weather_lbl.add_theme_color_override("font_color", flag_color if flag_text != "NENHUMA (Normal)" else Color("#38bdf8"))

	_update_safety_banner()

	if not engine.is_quali_done():
		race_grid_node.columns = 9
		var limit = engine.quali_durations.get(engine.quali_phase, 1080.0)
		var remaining = max(0.0, limit - engine.quali_time_elapsed)
		var clock_str = engine.format_session_clock(remaining)
		if engine.quali_checker_flag:
			clock_str = "00:00 (⏱️ AGUARDANDO VOLTAS FINAIS)"
		top_title.text = "QUALIFICAÇÃO (" + str(engine.quali_phase) + ") - GP " + str(Database.current_gp) + " (" + str(current_track["Nome"]) + ") - Tempo Restante: " + clock_str
		_render_quali_grid()
		# #region agent log
		_agent_dbg("B", "race_view.gd:_update_ui", "Rendered quali grid", {
			"grid_children": race_grid_node.get_child_count() if is_instance_valid(race_grid_node) else -1,
			"quali_count": engine.active_quali_drivers.size()
		})
		# #endregion
	else:
		race_grid_node.columns = 9
		top_title.text = "GP " + str(Database.current_gp) + " (" + str(current_track["Nome"]) + ") - Volta " + str(engine.current_lap) + "/" + str(engine.total_laps)
		_render_race_grid()
		# #region agent log
		_agent_dbg("B", "race_view.gd:_update_ui", "Rendered race grid", {
			"grid_children": race_grid_node.get_child_count() if is_instance_valid(race_grid_node) else -1,
			"race_count": engine.race_drivers.size()
		})
		# #endregion
		
	log_text_node.clear()
	if "race_logs" in engine:
		for entry in engine.race_logs:
			log_text_node.append_text(entry + "\n")
		
	pit_log_text_node.clear()
	if "pit_logs" in engine:
		for pit_entry in engine.pit_logs:
			pit_log_text_node.append_text(pit_entry + "\n")

	var is_mgr = true
	if "game_mode" in Database:
		is_mgr = str(Database.game_mode) == "manager"
	if "is_manager_mode" in Database:
		is_mgr = is_mgr or bool(Database.is_manager_mode)

	if is_mgr and is_instance_valid(manager_panel_container):
		_build_manager_qualifying_controls(manager_panel_container)

func _update_safety_banner() -> void:
	pass

func _render_quali_grid() -> void:
	for c in race_grid_node.get_children():
		c.queue_free()

	_add_grid_header("POS", 40)
	_add_grid_header("PILOTO", 140)
	_add_grid_header("EQUIPE", 100)
	_add_grid_header("PNEU", 60)
	_add_grid_header("STATUS", 90)
	_add_grid_header("SETORES", 80)
	_add_grid_header("MELHOR VOLTA", 100)
	_add_grid_header("ÚLTIMA VOLTA", 90)
	_add_grid_header("SITUAÇÃO", 110)

	var pos = 1
	var list: Array = []
	var current_actives = engine.active_quali_drivers.duplicate()
	
	current_actives.sort_custom(func(a, b):
		var time_a = float(a.get("BestQualiTime", 999.0))
		var time_b = float(b.get("BestQualiTime", 999.0))
		if time_a >= 900.0 and time_b >= 900.0:
			return str(a.get("Nome", "")) < str(b.get("Nome", ""))
		if time_a < 900.0 and time_b >= 900.0:
			return true
		if time_a >= 900.0 and time_b < 900.0:
			return false
		if is_equal_approx(time_a, time_b):
			return str(a.get("Nome", "")) < str(b.get("Nome", ""))
		return time_a < time_b
	)

	for act in current_actives:
		list.append(act)
	for elim in engine.eliminated_drivers:
		list.append(elim)
	
	var total_active_count = list.size()
	for d in list:
		var is_eliminated = str(d.get("QualiStatus", "")).begins_with("ELIMINADO")
		var is_in_danger_zone = false
		
		if not is_eliminated and engine.quali_phase in ["Q1", "Q2"] and pos > (total_active_count - 6):
			is_in_danger_zone = true

		var row_color = Color("#f87171") if (is_in_danger_zone or is_eliminated) else Color("#ffffff")

		_add_cell("P" + str(pos), row_color)
		_add_cell(str(d.get("Nome", "")), row_color)
		_add_cell(str(d.get("Equipe", "")), row_color)
		
		var compound = str(d.get("tire_compound", "Soft"))
		_add_cell(compound, _get_compound_color(compound))
		
		var state_text = str(d.get("quali_state", "Box"))
		_add_cell(state_text, Color("#94a3b8") if state_text == "Box" else Color("#eab308"))
		
		var sec_colors = d.get("sector_colors", {"s1": "🟡", "s2": "🟡", "s3": "🟡"})
		var sectors_str = "%s %s %s" % [sec_colors.get("s1", "🟡"), sec_colors.get("s2", "🟡"), sec_colors.get("s3", "🟡")]
		_add_cell(sectors_str, Color("#ffffff"))
		
		var best_t = float(d.get("BestQualiTime", 999.0))
		var best_str = engine.format_time_f1(best_t) if best_t < 900.0 else "--:--.---"
		_add_cell(best_str, Color("#22c55e") if best_t < 900.0 else Color("#ffffff"))
		
		var last_t = float(d.get("LastLapTime", 999.0))
		var last_str = engine.format_time_f1(last_t) if last_t < 900.0 else "--:--.---"
		_add_cell(last_str, Color("#ffffff"))
		
		var danger_str = "⚠️ Zona de Eliminação" if is_in_danger_zone else (str(d.get("QualiStatus", "Classificado")) if is_eliminated else "Classificado")
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

func _process(delta: float) -> void:
	if not _dbg_process_logged:
		_dbg_process_logged = true
		# #region agent log
		_agent_dbg("D", "race_view.gd:_process", "First process layout", {
			"control_size": {"x": size.x, "y": size.y},
			"grid_size": {"x": race_grid_node.size.x, "y": race_grid_node.size.y} if is_instance_valid(race_grid_node) else {"x": -1, "y": -1},
			"grid_children": race_grid_node.get_child_count() if is_instance_valid(race_grid_node) else -1,
			"visible": visible
		})
		# #endregion
	if engine == null:
		return
	if not simulation_running:
		return

	var simulation_delta := delta * simulation_speed
	if not engine.is_quali_done():
		engine.process_quali_tick(simulation_delta)
		if engine.is_quali_done():
			race_lap_elapsed = 0.0
	else:
		race_lap_elapsed += simulation_delta
		var lap_duration: float = maxf(1.0, engine._get_base_track_lap_time())
		while race_lap_elapsed >= lap_duration and not engine.is_finished():
			race_lap_elapsed -= lap_duration
			var result := engine.process_lap()
			if result.get("red_flag", false):
				simulation_running = false
				_show_red_flag_modal()
				break

	if engine.is_finished():
		simulation_running = false

	ui_refresh_elapsed += delta
	if ui_refresh_elapsed >= 1.0 or not simulation_running:
		ui_refresh_elapsed = 0.0
		_update_simulation_button()
		_update_ui()
