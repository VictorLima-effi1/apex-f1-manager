extends Control

var grid_driver_inputs: Array = []
var fa_driver_inputs: Array = []
var team_inputs: Array = []

var time_passed: float = 0.0

# Modais Pop-up
var create_team_dialog: ConfirmationDialog
var create_driver_dialog: ConfirmationDialog

# Campos do formulário - Criar Equipe
var input_team_name: LineEdit
var input_team_resp: SpinBox
var input_team_aero: SpinBox
var input_team_motor: SpinBox
var input_team_chassis: SpinBox

# Campos do formulário - Criar Piloto
var input_driver_name: LineEdit
var input_driver_age: SpinBox
var input_driver_ovr: SpinBox
var input_driver_pace: SpinBox
var input_driver_tire: SpinBox
var input_driver_team: OptionButton

# --- ANIMAÇÃO DE BACKGROUND ---
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
	_setup_dialogs()
	build_ui()

func _setup_dialogs() -> void:
	# --- DIÁLOGO DE CRIAR EQUIPE ---
	create_team_dialog = ConfirmationDialog.new()
	create_team_dialog.title = "➕ Criar Nova Equipe"
	create_team_dialog.size = Vector2i(320, 280)
	create_team_dialog.confirmed.connect(_on_create_team_confirmed)
	
	var vbox_t = VBoxContainer.new()
	input_team_name = _create_dialog_line_edit(vbox_t, "Nome da Equipe:", "Ex: Porsche F1")
	input_team_resp = _create_dialog_spinbox(vbox_t, "Respeito:", 10, 100, 60)
	input_team_aero = _create_dialog_spinbox(vbox_t, "Aerodinâmica:", 50, 99, 75)
	input_team_motor = _create_dialog_spinbox(vbox_t, "Motor:", 50, 99, 75)
	input_team_chassis = _create_dialog_spinbox(vbox_t, "Chassi:", 50, 99, 75)
	create_team_dialog.add_child(vbox_t)
	add_child(create_team_dialog)

	# --- DIÁLOGO DE CRIAR PILOTO ---
	create_driver_dialog = ConfirmationDialog.new()
	create_driver_dialog.title = "➕ Criar Novo Piloto"
	create_driver_dialog.size = Vector2i(320, 320)
	create_driver_dialog.confirmed.connect(_on_create_driver_confirmed)
	
	var vbox_d = VBoxContainer.new()
	input_driver_name = _create_dialog_line_edit(vbox_d, "Nome do Piloto:", "Ex: Ayrton Senna")
	input_driver_age = _create_dialog_spinbox(vbox_d, "Idade:", 16, 50, 20)
	input_driver_ovr = _create_dialog_spinbox(vbox_d, "Overall:", 50, 99, 75)
	input_driver_pace = _create_dialog_spinbox(vbox_d, "Pace/Corrida:", 50, 99, 75)
	input_driver_tire = _create_dialog_spinbox(vbox_d, "Pneus:", 50, 99, 75)
	
	var lbl_t = Label.new()
	lbl_t.text = "Equipe Inicial:"
	lbl_t.add_theme_font_size_override("font_size", 12)
	vbox_d.add_child(lbl_t)
	
	input_driver_team = OptionButton.new()
	vbox_d.add_child(input_driver_team)
	
	create_driver_dialog.add_child(vbox_d)
	add_child(create_driver_dialog)

func build_ui() -> void:
	for c in get_children():
		if c != create_team_dialog and c != create_driver_dialog:
			c.queue_free()
		
	grid_driver_inputs.clear()
	fa_driver_inputs.clear()
	team_inputs.clear()
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 14)
	add_child(main_vbox)
	
	# --- HEADER DA TELA ---
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	
	var title = Label.new()
	title.text = "🛠️ EDITOR DE ATRIBUTOS E BANCO DE DADOS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ef4444"))
	header_hbox.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	# BOTÕES DE AÇÃO DO HEADER
	var btn_add_driver = Button.new()
	btn_add_driver.text = "👤+ Criar Piloto"
	btn_add_driver.custom_minimum_size = Vector2(125, 36)
	btn_add_driver.add_theme_color_override("font_color", Color("#38bdf8"))
	btn_add_driver.pressed.connect(_open_create_driver_modal)
	header_hbox.add_child(btn_add_driver)
	
	var btn_add_team = Button.new()
	btn_add_team.text = "🏎️+ Criar Equipe"
	btn_add_team.custom_minimum_size = Vector2(130, 36)
	btn_add_team.add_theme_color_override("font_color", Color("#f59e0b"))
	btn_add_team.pressed.connect(_open_create_team_modal)
	header_hbox.add_child(btn_add_team)
	
	var btn_save_all = Button.new()
	btn_save_all.text = "💾 SALVAR TUDO"
	btn_save_all.custom_minimum_size = Vector2(140, 36)
	btn_save_all.add_theme_color_override("font_color", Color("#22c55e"))
	btn_save_all.pressed.connect(_on_save_all_pressed)
	header_hbox.add_child(btn_save_all)
	
	main_vbox.add_child(header_hbox)
	
	# --- LAYOUT EM 3 COLUNAS ---
	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(split_hbox)
	
	# 1. BOX PILOTOS DO GRID
	var grid_drivers: Array = []
	var fa_drivers: Array = []
	for d in Database.drivers:
		if d.get("Equipe", "Free Agent") == "Free Agent":
			fa_drivers.append(d)
		else:
			grid_drivers.append(d)
			
	_build_driver_box(split_hbox, "🏎️ PILOTOS DO GRID", grid_drivers, Color("#38bdf8"), grid_driver_inputs)
	
	# 2. BOX PILOTOS FREE AGENT
	_build_driver_box(split_hbox, "📋 FREE AGENTS", fa_drivers, Color("#a855f7"), fa_driver_inputs)
	
	# 3. BOX EQUIPES
	_build_team_box(split_hbox, "🏛️ EQUIPES & DESEMPENHO", Database.teams, Color("#f59e0b"), team_inputs)

func _build_driver_box(parent: HBoxContainer, box_title: String, driver_list: Array, theme_color: Color, input_array: Array) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color("#0f1216")
	p_style.border_width_left = 4
	p_style.border_color = theme_color
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 10
	p_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", p_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var lbl = Label.new()
	lbl.text = box_title + " (" + str(driver_list.size()) + ")"
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", theme_color)
	vbox.add_child(lbl)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	_add_header(grid, "PILOTO", 110)
	_add_header(grid, "IDADE", 45)
	_add_header(grid, "OVR", 50)
	_add_header(grid, "PACE", 50)
	_add_header(grid, "PNEU", 50)
	_add_header(grid, "EQUIPE", 100)
	
	for d in driver_list:
		var name_lbl = Label.new()
		name_lbl.text = d.get("Nome", "")
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color("#ffffff"))
		grid.add_child(name_lbl)
		
		var age_spin = SpinBox.new()
		age_spin.min_value = 16
		age_spin.max_value = 55
		age_spin.value = d.get("Idade", 25)
		grid.add_child(age_spin)
		
		var ovr_spin = SpinBox.new()
		ovr_spin.min_value = 50
		ovr_spin.max_value = 99
		ovr_spin.value = d.get("Overall", d.get("Grau", 75))
		grid.add_child(ovr_spin)
		
		var pace_spin = SpinBox.new()
		pace_spin.min_value = 50
		pace_spin.max_value = 99
		pace_spin.value = d.get("Corrida", d.get("Pace", 75))
		grid.add_child(pace_spin)
		
		var tire_spin = SpinBox.new()
		tire_spin.min_value = 50
		tire_spin.max_value = 99
		tire_spin.value = d.get("Pneus", 75)
		grid.add_child(tire_spin)
		
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
		grid.add_child(team_opt)
		
		input_array.append({
			"driver_ref": d,
			"age_node": age_spin,
			"ovr_node": ovr_spin,
			"pace_node": pace_spin,
			"tire_node": tire_spin,
			"team_node": team_opt
		})
		
	scroll.add_child(grid)
	vbox.add_child(scroll)
	panel.add_child(vbox)
	parent.add_child(panel)

func _build_team_box(parent: HBoxContainer, box_title: String, team_list: Array, theme_color: Color, input_array: Array) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color("#0f1216")
	p_style.border_width_left = 4
	p_style.border_color = theme_color
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 10
	p_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", p_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var lbl = Label.new()
	lbl.text = box_title + " (" + str(team_list.size()) + ")"
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", theme_color)
	vbox.add_child(lbl)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	_add_header(grid, "EQUIPE", 100)
	_add_header(grid, "RESP", 50)
	_add_header(grid, "AERO", 50)
	_add_header(grid, "MOTOR", 50)
	_add_header(grid, "CHASSI", 50)
	
	for t in team_list:
		var t_name_lbl = Label.new()
		var is_active = bool(t.get("Ativa", true))
		
		if is_active:
			t_name_lbl.text = t.get("Nome", "")
			t_name_lbl.add_theme_color_override("font_color", Color("#ffffff"))
		else:
			t_name_lbl.text = t.get("Nome", "") + " ⏳ (Ano Seg.)"
			t_name_lbl.add_theme_color_override("font_color", Color("#f59e0b"))
			
		t_name_lbl.add_theme_font_size_override("font_size", 12)
		grid.add_child(t_name_lbl)
		
		var resp_spin = SpinBox.new()
		resp_spin.min_value = 10
		resp_spin.max_value = 100
		resp_spin.value = t.get("Respeito", 50)
		grid.add_child(resp_spin)
		
		var aero_spin = SpinBox.new()
		aero_spin.min_value = 50
		aero_spin.max_value = 99
		aero_spin.value = t.get("Aero", 75)
		grid.add_child(aero_spin)
		
		var motor_spin = SpinBox.new()
		motor_spin.min_value = 50
		motor_spin.max_value = 99
		motor_spin.value = t.get("Motor", 75)
		grid.add_child(motor_spin)
		
		var chassis_spin = SpinBox.new()
		chassis_spin.min_value = 50
		chassis_spin.max_value = 99
		chassis_spin.value = t.get("Chassi", 75)
		grid.add_child(chassis_spin)
		
		input_array.append({
			"team_ref": t,
			"resp_node": resp_spin,
			"aero_node": aero_spin,
			"motor_node": motor_spin,
			"chassis_node": chassis_spin
		})
		
	scroll.add_child(grid)
	vbox.add_child(scroll)
	panel.add_child(vbox)
	parent.add_child(panel)

# --- MÉTODOS DE ABERTURA E CONFIRMAÇÃO DOS MODAIS ---
func _open_create_team_modal() -> void:
	input_team_name.text = ""
	create_team_dialog.popup_centered()

func _open_create_driver_modal() -> void:
	input_driver_name.text = ""
	input_driver_team.clear()
	input_driver_team.add_item("Free Agent")
	for t in Database.teams:
		input_driver_team.add_item(t.get("Nome", ""))
	input_driver_team.selected = 0
	create_driver_dialog.popup_centered()

func _on_create_team_confirmed() -> void:
	var t_name = input_team_name.text.strip_edges()
	if t_name.is_empty():
		return
		
	if Database.has_method("add_new_team"):
		Database.add_new_team(
			t_name,
			int(input_team_resp.value),
			int(input_team_aero.value),
			int(input_team_motor.value),
			int(input_team_chassis.value)
		)
	build_ui()

func _on_create_driver_confirmed() -> void:
	var d_name = input_driver_name.text.strip_edges()
	if d_name.is_empty():
		return
		
	var sel_team = input_driver_team.get_item_text(input_driver_team.selected)
	if Database.has_method("add_new_driver"):
		Database.add_new_driver(
			d_name,
			int(input_driver_age.value),
			int(input_driver_ovr.value),
			int(input_driver_pace.value),
			int(input_driver_tire.value),
			sel_team
		)
	build_ui()

func _on_save_all_pressed() -> void:
	var all_driver_inputs = grid_driver_inputs + fa_driver_inputs
	for item in all_driver_inputs:
		var d = item["driver_ref"]
		d["Idade"] = int(item["age_node"].value)
		d["Overall"] = int(item["ovr_node"].value)
		d["Grau"] = d["Overall"]
		d["Corrida"] = int(item["pace_node"].value)
		d["Pace"] = d["Corrida"]
		d["Pneus"] = int(item["tire_node"].value)
		
		var opt_node = item["team_node"]
		var selected_team = opt_node.get_item_text(opt_node.selected)
		d["Equipe"] = selected_team

	for item in team_inputs:
		var t = item["team_ref"]
		t["Respeito"] = int(item["resp_node"].value)
		t["Aero"] = int(item["aero_node"].value)
		t["Motor"] = int(item["motor_node"].value)
		t["Chassi"] = int(item["chassis_node"].value)

	print("✅ Todas as alterações foram salvas no Database!")
	build_ui()

func _add_header(grid: GridContainer, text: String, min_w: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	grid.add_child(lbl)

func _create_dialog_line_edit(parent: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)
	
	var le = LineEdit.new()
	le.placeholder_text = placeholder
	parent.add_child(le)
	return le

func _create_dialog_spinbox(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, default_v: float) -> SpinBox:
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(lbl)
	
	var sb = SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.value = default_v
	parent.add_child(sb)
	return sb
