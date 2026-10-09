extends Control

var driver_inputs: Array = []
var team_inputs: Array = []

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

func build_ui() -> void:
	for c in get_children():
		c.queue_free()
		
	driver_inputs.clear()
	team_inputs.clear()
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)
	
	# --- BARRA SUPERIOR COM BOTÃO SALVAR TUDO ---
	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 15)
	
	var title = Label.new()
	title.text = "🛠️ EDITOR DE ATRIBUTOS E BANCO DE DADOS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#ef4444"))
	top_bar.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	
	# Botão Único de Salvar Tudo
	var btn_save_all = Button.new()
	btn_save_all.text = "💾 SALVAR TUDO"
	btn_save_all.custom_minimum_size = Vector2(140, 35)
	btn_save_all.add_theme_color_override("font_color", Color("#22c55e"))
	btn_save_all.pressed.connect(_on_save_all_pressed)
	top_bar.add_child(btn_save_all)
	
	var btn_export = Button.new()
	btn_export.text = "📥 Exportar (JSON)"
	top_bar.add_child(btn_export)
	
	var btn_import = Button.new()
	btn_import.text = "📤 Importar (JSON)"
	top_bar.add_child(btn_import)
	
	main_vbox.add_child(top_bar)
	
	# --- LAYOUT LADO A LADO (PILOTOS / EQUIPES) ---
	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(split_hbox)
	
	# === BOX DA ESQUERDA: PILOTOS ===
	var drivers_box = VBoxContainer.new()
	drivers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drivers_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var d_title = Label.new()
	d_title.text = "🏎️ PILOTOS"
	d_title.add_theme_font_size_override("font_size", 15)
	d_title.add_theme_color_override("font_color", Color("#38bdf8"))
	drivers_box.add_child(d_title)
	
	var d_scroll = ScrollContainer.new()
	d_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var d_grid = GridContainer.new()
	d_grid.columns = 6
	d_grid.add_theme_constant_override("h_separation", 10)
	d_grid.add_theme_constant_override("v_separation", 6)
	
	_add_header(d_grid, "PILOTO", 120)
	_add_header(d_grid, "IDADE", 50)
	_add_header(d_grid, "OVERALL", 65)
	_add_header(d_grid, "PACE", 55)
	_add_header(d_grid, "PNEUS", 55)
	_add_header(d_grid, "EQUIPE", 110)
	
	for d in Database.drivers:
		var name_lbl = Label.new()
		name_lbl.text = d.get("Nome", "")
		name_lbl.add_theme_font_size_override("font_size", 12)
		d_grid.add_child(name_lbl)
		
		var age_spin = SpinBox.new()
		age_spin.min_value = 16
		age_spin.max_value = 55
		age_spin.value = d.get("Idade", 25)
		d_grid.add_child(age_spin)
		
		var ovr_spin = SpinBox.new()
		ovr_spin.min_value = 50
		ovr_spin.max_value = 99
		ovr_spin.value = d.get("Overall", 75)
		d_grid.add_child(ovr_spin)
		
		var pace_spin = SpinBox.new()
		pace_spin.min_value = 50
		pace_spin.max_value = 99
		pace_spin.value = d.get("Pace", 75)
		d_grid.add_child(pace_spin)
		
		var tire_spin = SpinBox.new()
		tire_spin.min_value = 50
		tire_spin.max_value = 99
		tire_spin.value = d.get("Pneus", 75)
		d_grid.add_child(tire_spin)
		
		var team_opt = OptionButton.new()
		team_opt.add_item("Free Agent")
		var current_team = d.get("Equipe", "Free Agent")
		var sel_idx = 0
		var idx = 1
		for t in Database.teams:
			var t_name = t.get("Nome", "")
			team_opt.add_item(t_name)
			if t_name == current_team:
				sel_idx = idx
			idx += 1
		team_opt.selected = sel_idx
		d_grid.add_child(team_opt)
		
		driver_inputs.append({
			"driver_ref": d,
			"age_node": age_spin,
			"ovr_node": ovr_spin,
			"pace_node": pace_spin,
			"tire_node": tire_spin,
			"team_node": team_opt
		})
		
	d_scroll.add_child(d_grid)
	drivers_box.add_child(d_scroll)
	split_hbox.add_child(drivers_box)
	
	# === BOX DA DIREITA: EQUIPES ===
	var teams_box = VBoxContainer.new()
	teams_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teams_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var t_title = Label.new()
	t_title.text = "🏛️ EQUIPES & DESEMPENHO"
	t_title.add_theme_font_size_override("font_size", 15)
	t_title.add_theme_color_override("font_color", Color("#f59e0b"))
	teams_box.add_child(t_title)
	
	var t_scroll = ScrollContainer.new()
	t_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var t_grid = GridContainer.new()
	t_grid.columns = 5
	t_grid.add_theme_constant_override("h_separation", 10)
	t_grid.add_theme_constant_override("v_separation", 6)
	
	_add_header(t_grid, "EQUIPE", 110)
	_add_header(t_grid, "RESPEITO", 65)
	_add_header(t_grid, "AERO", 60)
	_add_header(t_grid, "MOTOR", 60)
	_add_header(t_grid, "CHASSI", 60)
	
	for t in Database.teams:
		var t_name_lbl = Label.new()
		t_name_lbl.text = t.get("Nome", "")
		t_name_lbl.add_theme_font_size_override("font_size", 12)
		t_grid.add_child(t_name_lbl)
		
		var resp_spin = SpinBox.new()
		resp_spin.min_value = 10
		resp_spin.max_value = 100
		resp_spin.value = t.get("Respeito", 50)
		t_grid.add_child(resp_spin)
		
		var aero_spin = SpinBox.new()
		aero_spin.min_value = 50
		aero_spin.max_value = 100
		aero_spin.value = t.get("Aero", 75)
		t_grid.add_child(aero_spin)
		
		var motor_spin = SpinBox.new()
		motor_spin.min_value = 50
		motor_spin.max_value = 100
		motor_spin.value = t.get("Motor", 75)
		t_grid.add_child(motor_spin)
		
		var chassis_spin = SpinBox.new()
		chassis_spin.min_value = 50
		chassis_spin.max_value = 100
		chassis_spin.value = t.get("Chassi", 75)
		t_grid.add_child(chassis_spin)
		
		team_inputs.append({
			"team_ref": t,
			"resp_node": resp_spin,
			"aero_node": aero_spin,
			"motor_node": motor_spin,
			"chassis_node": chassis_spin
		})
		
	t_scroll.add_child(t_grid)
	teams_box.add_child(t_scroll)
	split_hbox.add_child(teams_box)

func _on_save_all_pressed() -> void:
	# Salva alterações nos pilotos
	for item in driver_inputs:
		var d = item["driver_ref"]
		d["Idade"] = int(item["age_node"].value)
		d["Overall"] = int(item["ovr_node"].value)
		d["Pace"] = int(item["pace_node"].value)
		d["Pneus"] = int(item["tire_node"].value)
		
		var opt_node = item["team_node"]
		d["Equipe"] = opt_node.get_item_text(opt_node.selected)

	# Salva alterações nas equipes
	for item in team_inputs:
		var t = item["team_ref"]
		t["Respeito"] = int(item["resp_node"].value)
		t["Aero"] = int(item["aero_node"].value)
		t["Motor"] = int(item["motor_node"].value)
		t["Chassi"] = int(item["chassis_node"].value)

	print("✅ Todas as alterações de pilotos e equipes foram salvas no Database!")

func _add_header(grid: GridContainer, text: String, min_w: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color("#ef4444"))
	grid.add_child(lbl)
