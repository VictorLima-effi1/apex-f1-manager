extends Control

var engine: RaceEngine
var player_race_strategies: Dictionary = {}
var manager_panel_container: VBoxContainer

@onready var top_title: Label
@onready var weather_lbl: Label
@onready var water_bar: ProgressBar
@onready var grip_bar: ProgressBar
var water_value_label: Label
var grip_value_label: Label
@onready var btn_start: Button
@onready var btn_speed_1x: Button
@onready var btn_speed_2x: Button
@onready var btn_speed_5x: Button
@onready var btn_speed_10x: Button
@onready var btn_speed_30x: Button
@onready var btn_speed_skip: Button
@onready var race_grid_node: GridContainer
@onready var log_text_node: RichTextLabel
@onready var pit_log_text_node: RichTextLabel

var left_vbox: VBoxContainer
var banner_container: PanelContainer
var banner_label: Label

var simulation_speed: float = 1.0
var simulation_running: bool = false
var simulation_tick_accumulator: float = 0.0
var race_lap_elapsed: float = 0.0
var race_lap_duration: float = 0.0
var ui_refresh_elapsed: float = 0.0
var race_finish_handled: bool = false
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
	Database.process_due_user_team_upgrades()
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
	if engine != null and engine.is_quali_done() and race_lap_duration <= 0.0:
		race_lap_duration = engine._get_base_track_lap_time()

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

	var track_conditions := HBoxContainer.new()
	track_conditions.add_theme_constant_override("separation", 14)
	var water_row := _create_track_condition_bar("ÁGUA", Color("#38bdf8"))
	water_bar = water_row.get("bar")
	water_value_label = water_row.get("value")
	track_conditions.add_child(water_row.get("container"))
	var grip_row := _create_track_condition_bar("ADERÊNCIA", Color("#f97316"))
	grip_bar = grip_row.get("bar")
	grip_value_label = grip_row.get("value")
	track_conditions.add_child(grip_row.get("container"))
	main_vbox.add_child(track_conditions)

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

	btn_speed_30x = Button.new()
	btn_speed_30x.text = "30x"
	btn_speed_30x.pressed.connect(func(): _set_speed_mode(30.0))
	ctrl_hbox.add_child(btn_speed_30x)

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
	
	var tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_theme_font_size_override("font_size", 12)
	
	var tab_events = VBoxContainer.new()
	tab_events.name = "📢 INCIDENTES & CLIMA"
	log_text_node = RichTextLabel.new()
	log_text_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text_node.scroll_following = true
	tab_events.add_child(log_text_node)
	if is_manager_mode:
		manager_panel_container = VBoxContainer.new()
		manager_panel_container.name = "ManagerPanelContainer"
		manager_panel_container.size_flags_vertical = Control.SIZE_SHRINK_END
		manager_panel_container.add_theme_constant_override("separation", 6)
		tab_events.add_child(manager_panel_container)
		_build_manager_qualifying_controls(manager_panel_container)
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
	lbl_title.text = "🎧 ESTRATÉGIA DA EQUIPE"
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
	st_c.border_width_left = 1
	st_c.border_width_top = 1
	st_c.border_width_right = 1
	st_c.border_width_bottom = 1
	st_c.border_color = _get_manager_team_color().lerp(Color("#1e293b"), 0.35)
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
	
	var current_status = _get_driver_status(driver_data)
	var l_status = Label.new()
	l_status.name = "LblStatus_%d" % driver_index
	l_status.text = "Status: " + current_status
	l_status.add_theme_font_size_override("font_size", 11)
	l_status.add_theme_color_override("font_color", Color("#34d399") if ("Pista" in current_status or "Em pista" in current_status or "Hot Lap" in current_status) else Color("#f87171"))
	cv.add_child(l_status)
	var position_label := Label.new()
	position_label.name = "LblPosition_%d" % driver_index
	position_label.text = "Posição: P%d" % _get_driver_position(driver_data)
	position_label.add_theme_font_size_override("font_size", 11)
	position_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	cv.add_child(position_label)

	var is_race_session := engine != null and engine.is_quali_done()
	
	var ch = HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	
	var opt_tire = OptionButton.new()
	opt_tire.name = "OptTire_%d" % driver_index
	opt_tire.add_item("Macio (C5)", 0)
	opt_tire.add_item("Médio (C4)", 1)
	opt_tire.add_item("Duro (C3)", 2)
	opt_tire.add_item("Intermediário (Inter)", 3)
	opt_tire.add_item("Chuva Extrema (Wet)", 4)
	
	var tire_options := ["Soft", "Medium", "Hard", "Inter", "Wet"]
	var current_tire := str(driver_data.get("tire_compound", ""))
	if is_race_session:
		current_tire = str(driver_data.get("pit_requested_tire", driver_data.get("planned_pit_tire", current_tire)))
	var current_tire_index := tire_options.find(current_tire)
	if current_tire_index < 0:
		current_tire_index = 3 if engine != null and engine.water_level > 10.0 else 0
	opt_tire.select(current_tire_index)
	opt_tire.item_selected.connect(func(selected_index: int):
		if selected_index < tire_options.size():
			if is_race_session:
				driver_data["planned_pit_tire"] = tire_options[selected_index]
			else:
				driver_data["tire_compound"] = tire_options[selected_index]
	)
	ch.add_child(opt_tire)
	
	var opt_pace = OptionButton.new()
	opt_pace.name = "OptPace_%d" % driver_index
	opt_pace.add_item("🛡️ Conservador", 0)
	opt_pace.add_item("⚖️ Normal", 1)
	opt_pace.add_item("🔥 Ataque Máximo", 2)
	var current_style := str(driver_data.get("estilo", "Normal"))
	opt_pace.select(0 if current_style == "Conservador" else (2 if current_style in ["Agressivo", "Ataque Máximo"] else 1))
	opt_pace.item_selected.connect(func(selected_index: int):
		var paces := ["Conservador", "Normal", "Agressivo"]
		if selected_index < paces.size():
			driver_data["estilo"] = paces[selected_index]
	)
	ch.add_child(opt_pace)
	
	var btn_action = Button.new()
	btn_action.name = "BtnAction_%d" % driver_index
	var is_on_track = ("Pista" in current_status or "Em pista" in current_status or "Hot Lap" in current_status or "Entrada" in current_status)
	var pit_requested := bool(driver_data.get("pit_requested", false))
	var eliminated := str(driver_data.get("QualiStatus", "")).begins_with("ELIMINADO")
	if is_race_session:
		btn_action.text = "📨 BOX SOLICITADO" if pit_requested else "🛠️ CHAMAR AO BOX"
		btn_action.disabled = not is_on_track or pit_requested or engine.is_finished() or engine.current_lap >= engine.total_laps - 1
	else:
		btn_action.text = "🛑 RECOLHER" if is_on_track else "🚀 MANDAR À PISTA"
		var waiting_for_quali_release := not is_on_track and (
			engine.quali_checker_flag
			or not bool(driver_data.get("quali_retry_allowed", true))
			or float(driver_data.get("timer_state", 0.0)) > 0.0
		)
		btn_action.disabled = eliminated or waiting_for_quali_release
	btn_action.custom_minimum_size.x = 150
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
	
	if engine != null and engine.is_quali_done():
		var used_compounds: Array = target_driver.get("used_compounds", [])
		if used_compounds.size() < 2 and used_compounds.has(chosen_tire):
			var legal_compound := engine._get_ideal_compound_for_water(engine.water_level)
			if used_compounds.has(legal_compound):
				for candidate in tires:
					if not used_compounds.has(candidate):
						legal_compound = candidate
						break
			chosen_tire = legal_compound
		if engine.request_manager_pit_stop(target_name, chosen_tire, chosen_pace):
			simulation_running = true
			_update_simulation_button()
	elif engine != null and engine.active_quali_drivers != null:
		for d in engine.active_quali_drivers:
			var d_n = str(d.get("Nome", d.get("nome", "")))
			if d_n == target_name:
				var curr_state = str(d.get("quali_state", "Box"))
				if curr_state == "Box":
					if engine.quali_checker_flag or not bool(d.get("quali_retry_allowed", true)) or float(d.get("timer_state", 0.0)) > 0.0:
						return
					d["quali_state"] = "Em pista"
					d["tire_compound"] = chosen_tire
					d["estilo"] = chosen_pace
					d["is_in_pit"] = false
					d["tire_wear"] = 100.0
					d["progress"] = 0.0
					d["quali_lap_duration"] = engine._get_base_track_lap_time() * 1.08
					d["force_in_lap"] = true
				else:
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
	
	if engine != null:
		var session_drivers: Array = engine.race_drivers if engine.is_quali_done() else engine.active_quali_drivers
		for d in session_drivers:
			var d_n = str(d.get("Nome", d.get("nome", "")))
			if d_n == driver_name:
				if engine.is_quali_done():
					return str(d.get("Status", "Na Pista"))
				var quali_state := str(d.get("quali_state", "Box"))
				if quali_state == "Box" and bool(d.get("manager_controlled", false)):
					if engine.quali_checker_flag:
						return "Box (sessão encerrada)"
					if not bool(d.get("quali_retry_allowed", true)):
						return "Box (sem tempo para nova volta)"
					var wait_time := float(d.get("timer_state", 0.0))
					if wait_time > 0.0:
						return "Box (aguardando %.0f s)" % wait_time
				return quali_state
				
	return "Box"

func _get_driver_status(driver: Dictionary) -> String:
	if engine == null:
		return "Box"
	if engine.is_quali_done():
		return str(driver.get("Status", "Na Pista"))
	var quali_status := str(driver.get("QualiStatus", ""))
	if quali_status.begins_with("ELIMINADO"):
		return quali_status
	return str(driver.get("quali_state", "Box"))

func _get_driver_position(target_driver: Dictionary) -> int:
	if engine == null:
		return 0
	var target_name := str(target_driver.get("Nome", target_driver.get("nome", "")))
	if engine.is_quali_done():
		for i in range(engine.race_drivers.size()):
			if str(engine.race_drivers[i].get("Nome", "")) == target_name:
				return i + 1
		return 0
	var ranked_drivers: Array = engine.active_quali_drivers.duplicate()
	ranked_drivers.append_array(engine.eliminated_drivers)
	ranked_drivers.sort_custom(func(a, b):
		var time_a := float(a.get("BestQualiTime", 999.0))
		var time_b := float(b.get("BestQualiTime", 999.0))
		if time_a >= 900.0 and time_b >= 900.0:
			return str(a.get("Nome", "")) < str(b.get("Nome", ""))
		if time_a >= 900.0:
			return false
		if time_b >= 900.0:
			return true
		if is_equal_approx(time_a, time_b):
			return str(a.get("Nome", "")) < str(b.get("Nome", ""))
		return time_a < time_b
	)
	for i in range(ranked_drivers.size()):
		if str(ranked_drivers[i].get("Nome", "")) == target_name:
			return i + 1
	return 0

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

func _create_track_condition_bar(title: String, fill_color: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)

	var title_label := Label.new()
	title_label.text = title
	title_label.custom_minimum_size.x = 86
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", fill_color)
	row.add_child(title_label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 16
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color("#1e293b")
	background_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background_style)
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = "0%"
	value_label.custom_minimum_size.x = 38
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color("#e2e8f0"))
	row.add_child(value_label)
	return {"container": row, "bar": bar, "value": value_label}

func _get_user_drivers() -> Array:
	var user_team = str(Database.user_team.get("nome", Database.user_team.get("Nome", "")))
	if user_team.is_empty() and not Database.selected_manager_team.is_empty():
		user_team = str(Database.selected_manager_team.get("Nome", Database.selected_manager_team.get("nome", "")))
	if user_team.is_empty() and "player_team" in Database:
		user_team = str(Database.player_team)
	if user_team.is_empty():
		user_team = "Ferrari"
	var drivers = []
	if engine != null:
		var session_drivers: Array = engine.race_drivers if engine.is_quali_done() else engine.active_quali_drivers.duplicate()
		if not engine.is_quali_done():
			session_drivers.append_array(engine.eliminated_drivers)
		for d in session_drivers:
			if str(d.get("Equipe", "")) == user_team and not drivers.any(func(existing): return str(existing.get("Nome", "")) == str(d.get("Nome", ""))):
				drivers.append(d)
	return drivers

func _get_manager_team_color() -> Color:
	var raw_color: Variant = Database.user_team.get("cor", Database.user_team.get("Cor", null))
	if raw_color == null:
		raw_color = Database.selected_manager_team.get("cor", Database.selected_manager_team.get("Cor", Color("#38bdf8")))
	if raw_color is Color:
		return raw_color
	return Color.from_string(str(raw_color), Color("#38bdf8"))

func _add_manager_driver_cell(text: String, highlight: bool = false) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.22) if highlight else Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(1)
	style.border_color = _get_manager_team_color().lerp(Color("#ffffff"), 0.12)
	style.set_corner_radius_all(3)
	style.content_margin_left = 3
	style.content_margin_right = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = 150
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#fca5a5") if highlight else Color("#ffffff"))
	panel.add_child(label)
	race_grid_node.add_child(panel)

func _set_speed_mode(speed: float) -> void:
	simulation_speed = speed

func _skip_to_end_of_session() -> void:
	if engine != null and not engine.is_quali_done():
		engine.skip_to_end_of_quali_session()
		simulation_tick_accumulator = 0.0
		race_lap_elapsed = 0.0
		simulation_running = false
		_update_simulation_button()
		_update_ui()
	elif engine != null and not engine.is_finished():
		simulation_running = false
		_update_simulation_button()
		var processed_laps := 0
		var max_laps := engine.total_laps - engine.current_lap
		while not engine.is_finished() and processed_laps < max_laps:
			var lap_before := engine.current_lap
			var res = engine.process_lap()
			if res.get("red_flag", false):
				_show_red_flag_modal()
				break
			if res.get("awaiting_manager_pit", false) or engine.current_lap == lap_before:
				break
			processed_laps += 1
			if processed_laps % 4 == 0:
				_update_ui()
				await get_tree().process_frame
		simulation_tick_accumulator = 0.0
		race_lap_elapsed = 0.0
		_update_simulation_button()
		_update_ui()

func _on_btn_start_pressed() -> void:
	if engine != null and engine.is_finished():
		_finish_race_and_advance()
		return

	if engine != null and engine.pending_red_flag_modal:
		engine.resolve_red_flag_restart()
		race_lap_elapsed = 0.0

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
	if is_instance_valid(water_bar):
		water_bar.value = engine.water_level
		water_value_label.text = "%d%%" % int(round(engine.water_level))
	if is_instance_valid(grip_bar):
		grip_bar.value = engine.track_grip
		grip_value_label.text = "%d%%" % int(round(engine.track_grip))

	_update_safety_banner()

	if not engine.is_quali_done():
		race_grid_node.columns = 9
		_update_session_clock()
		_render_quali_grid()
		# #region agent log
		_agent_dbg("B", "race_view.gd:_update_ui", "Rendered quali grid", {
			"grid_children": race_grid_node.get_child_count() if is_instance_valid(race_grid_node) else -1,
			"quali_count": engine.active_quali_drivers.size()
		})
		# #endregion
	else:
		race_grid_node.columns = 9
		_update_session_clock()
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
	if not is_instance_valid(banner_container) or not is_instance_valid(banner_label) or engine == null:
		return

	var status := str(engine.get("safety_car_status"))
	var banner_text := ""
	var banner_color := Color("#facc15")
	if engine.is_quali_done():
		match status:
			"SC":
				banner_text = "SAFETY CAR: velocidade reduzida e pelotão agrupado; desgaste dos pneus reduzido."
				banner_color = Color("#ef4444")
			"VSC":
				banner_text = "VSC: velocidade reduzida, sem agrupar o pelotão; desgaste dos pneus reduzido."
				banner_color = Color("#f59e0b")
			"YELLOW":
				banner_text = "BANDEIRA AMARELA: velocidade reduzida; ultrapassagens suspensas durante a neutralização."
			"RED_FLAG":
				banner_text = "BANDEIRA VERMELHA: corrida paralisada; confirme a retomada para reiniciar."
				banner_color = Color("#ef4444")
	elif status == "YELLOW":
		banner_text = "BANDEIRA AMARELA: velocidade reduzida; ultrapassagens suspensas durante a neutralização."

	banner_container.visible = not banner_text.is_empty()
	if not banner_text.is_empty():
		banner_label.text = banner_text
		banner_label.add_theme_color_override("font_color", banner_color)

func _update_session_clock() -> void:
	if engine == null or not is_instance_valid(top_title):
		return
	var current_gp_idx := clampi(Database.current_gp - 1, 0, Database.tracks.size() - 1)
	var track_name := str(Database.tracks[current_gp_idx].get("Nome", ""))
	if not engine.is_quali_done():
		var limit := float(engine.quali_durations.get(engine.quali_phase, 1080.0))
		var remaining := maxf(0.0, limit - engine.quali_time_elapsed)
		var clock_text := engine.format_session_clock(remaining)
		if engine.quali_checker_flag:
			clock_text = "00:00 (⏱️ AGUARDANDO VOLTAS FINAIS)"
		top_title.text = "QUALIFICAÇÃO (%s) - GP %d (%s) - Tempo Restante: %s" % [
			engine.quali_phase, Database.current_gp, track_name, clock_text
		]
	else:
		top_title.text = "GP %d (%s) - Volta %d/%d" % [
			Database.current_gp, track_name, engine.current_lap, engine.total_laps
		]

func _render_quali_grid() -> void:
	for c in race_grid_node.get_children():
		race_grid_node.remove_child(c)
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
	
	var active_sorted: Array = current_actives.duplicate()
	var elimination_zone_names: Dictionary = {}
	if engine.quali_phase in ["Q1", "Q2"]:
		for i in range(maxi(0, active_sorted.size() - 6), active_sorted.size()):
			elimination_zone_names[str(active_sorted[i].get("Nome", ""))] = true

	for d in list:
		var is_eliminated = str(d.get("QualiStatus", "")).begins_with("ELIMINADO")
		var is_in_danger_zone := not is_eliminated and elimination_zone_names.has(str(d.get("Nome", "")))

		var row_color = Color("#f87171") if (is_in_danger_zone or is_eliminated) else Color("#ffffff")

		_add_cell("P" + str(pos), row_color, is_in_danger_zone or is_eliminated)
		var driver_name := str(d.get("Nome", ""))
		if _is_manager_team_driver(d):
			_add_manager_driver_cell(driver_name, is_in_danger_zone or is_eliminated)
		else:
			_add_cell(driver_name, row_color, is_in_danger_zone or is_eliminated)
		_add_cell(str(d.get("Equipe", "")), row_color, is_in_danger_zone or is_eliminated)
		
		var compound = str(d.get("tire_compound", "Soft"))
		_add_cell(compound, _get_compound_color(compound), is_in_danger_zone or is_eliminated)
		
		var state_text = str(d.get("quali_state", "Box"))
		_add_cell(state_text, Color("#94a3b8") if state_text == "Box" else Color("#eab308"), is_in_danger_zone or is_eliminated)
		
		var sec_colors = d.get("sector_colors", {"s1": "⬜", "s2": "⬜", "s3": "⬜"})
		var sectors_str = "%s %s %s" % [sec_colors.get("s1", "⬜"), sec_colors.get("s2", "⬜"), sec_colors.get("s3", "⬜")]
		_add_cell(sectors_str, Color("#ffffff"), is_in_danger_zone or is_eliminated)
		
		var best_t = float(d.get("BestQualiTime", 999.0))
		var best_str = engine.format_time_f1(best_t) if best_t < 900.0 else "--:--.---"
		_add_cell(best_str, Color("#22c55e") if best_t < 900.0 else Color("#ffffff"), is_in_danger_zone or is_eliminated)
		
		var last_t = float(d.get("LastLapTime", 999.0))
		var last_str = engine.format_time_f1(last_t) if last_t < 900.0 else "--:--.---"
		_add_cell(last_str, Color("#ffffff"), is_in_danger_zone or is_eliminated)
		
		var danger_str = "⚠️ Zona de Eliminação" if is_in_danger_zone else (str(d.get("QualiStatus", "Classificado")) if is_eliminated else "Classificado")
		var danger_color = Color("#ef4444") if (is_in_danger_zone or is_eliminated) else Color("#22c55e")
		_add_cell(danger_str, danger_color, is_in_danger_zone or is_eliminated)

		pos += 1

func _render_race_grid() -> void:
	for c in race_grid_node.get_children():
		race_grid_node.remove_child(c)
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
		var race_driver_name := str(d["Nome"]) + " (" + str(d["Equipe"]) + ")"
		if _is_manager_team_driver(d):
			_add_manager_driver_cell(race_driver_name)
		else:
			_add_cell(race_driver_name, text_color)
		
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
			
		var sec_colors = d.get("sector_colors", {"s1": "⬜", "s2": "⬜", "s3": "⬜"})
		var sectors_str = "%s %s %s" % [sec_colors.get("s1", "⬜"), sec_colors.get("s2", "⬜"), sec_colors.get("s3", "⬜")]
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

func _add_cell(text: String, color: Color = Color("#ffffff"), highlight: bool = false) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	if highlight:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.55, 0.1, 0.1, 0.24)
		style.set_corner_radius_all(2)
		panel.add_theme_stylebox_override("panel", style)
		panel.add_child(lbl)
		race_grid_node.add_child(panel)
	else:
		race_grid_node.add_child(lbl)

func _is_manager_team_driver(driver: Dictionary) -> bool:
	if str(Database.game_mode) != "manager":
		return false
	var team_name := str(Database.user_team.get("nome", Database.user_team.get("Nome", "")))
	if team_name.is_empty():
		team_name = str(Database.selected_manager_team.get("Nome", Database.selected_manager_team.get("nome", "")))
	if team_name.is_empty():
		team_name = "Ferrari"
	return str(driver.get("Equipe", "")).strip_edges().to_lower() == team_name.strip_edges().to_lower()

func _get_compound_color(compound: String) -> Color:
	match compound.to_upper():
		"SOFT", "S": return Color("#ef4444")
		"MEDIUM", "M": return Color("#facc15")
		"HARD", "H": return Color("#ffffff")
		"INTER", "I": return Color("#22c55e")
		"WET", "W": return Color("#38bdf8")
		_: return Color("#94a3b8")

func _finish_race_and_advance() -> void:
	if race_finish_handled:
		return
	race_finish_handled = true
	if is_instance_valid(btn_start):
		btn_start.disabled = true
	if engine != null:
		var standings = engine.race_drivers.duplicate(true)
		Database.record_completed_race(standings)
		Database.process_post_race_morale_and_respect(standings)
		Database.process_ai_team_upgrades()
		Database.process_mid_season_renewals()
		Database.active_engine = null
		
	if Database.current_gp >= Database.tracks.size():
		var summary_view = preload("res://views/season_summary_view.gd").new()
		summary_view.open_summary(self, Database.get_season_summary(), func():
			Database.end_season_and_advance_year()
			_continue_to_next_season()
		)
	else:
		Database.current_gp += 1
		Database.race_finished = false
		_return_to_dashboard()

func _continue_to_next_season() -> void:
	Database.active_engine = null
	Database.current_view = "dashboard"
	var main_scene := get_tree().current_scene
	if is_instance_valid(main_scene) and main_scene.has_method("switch_view"):
		main_scene.call_deferred("switch_view", "dashboard")
	else:
		_change_to_main_menu_scene()

func _return_to_dashboard() -> void:
	simulation_running = false
	Database.active_engine = null
	Database.current_view = "dashboard"
	var main_scene := get_tree().current_scene
	if is_instance_valid(main_scene) and main_scene.has_method("switch_view"):
		main_scene.call_deferred("switch_view", "dashboard")
	else:
		var scene_error := get_tree().change_scene_to_file("res://main.tscn")
		if scene_error != OK:
			push_error("Não foi possível voltar ao dashboard. Erro: %d" % scene_error)

func _change_to_main_menu_scene() -> void:
	var scene_error := get_tree().change_scene_to_file("res://views/main_menu_view.tscn")
	if scene_error != OK:
		push_error("Não foi possível voltar ao menu principal. Erro: %d" % scene_error)

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

	var refresh_ui_immediately := false
	simulation_tick_accumulator += delta * simulation_speed
	if simulation_tick_accumulator >= 1.0:
		simulation_tick_accumulator -= 1.0
		if not engine.is_quali_done():
			engine.process_quali_tick(1.0)
			if engine.is_quali_done():
				race_lap_elapsed = 0.0
				race_lap_duration = engine._get_base_track_lap_time()
		else:
			engine.race_elapsed_time += 1.0
			race_lap_elapsed += 1.0
			if race_lap_duration <= 0.0:
				race_lap_duration = engine._get_base_track_lap_time()
			if race_lap_elapsed >= race_lap_duration and not engine.is_finished():
				race_lap_elapsed -= race_lap_duration
				var result := engine.process_lap()
				var leader_lap_time := 0.0
				for driver in engine.race_drivers:
					if str(driver.get("Status", "")) == "Na Pista":
						leader_lap_time = float(driver.get("LastLapTime", 0.0))
						break
				if leader_lap_time > 0.0:
					race_lap_duration = leader_lap_time
				if result.get("red_flag", false):
					simulation_running = false
					_show_red_flag_modal()
					refresh_ui_immediately = true
				elif result.get("awaiting_manager_pit", false):
					simulation_running = false
					refresh_ui_immediately = true

		if engine.is_finished():
			simulation_running = false
			refresh_ui_immediately = true
		_update_session_clock()

	if refresh_ui_immediately:
		_update_simulation_button()
		_update_ui()
		return

	ui_refresh_elapsed += delta
	if ui_refresh_elapsed >= 0.25:
		ui_refresh_elapsed = 0.0
		_update_simulation_button()
		_update_ui()
