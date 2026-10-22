extends Control

var grid_driver_inputs: Array = []
var fa_driver_inputs: Array = []
var team_inputs: Array = []

var time_passed: float = 0.0

# Modais Pop-up Customizados
var modal_layer: CanvasLayer
var modal_overlay: ColorRect
var create_team_modal: PanelContainer
var create_driver_modal: PanelContainer

# Campos do formulário - Criar Equipe
var input_team_name: LineEdit
var input_team_resp: SpinBox
var input_team_aero: SpinBox
var input_team_motor: SpinBox
var input_team_chassis: SpinBox
var input_team_reliability: SpinBox

# Campos do formulário - Criar Piloto
var input_driver_name: LineEdit
var input_driver_age: SpinBox
var input_driver_ovr: SpinBox
var input_driver_pace: SpinBox
var input_driver_tire: SpinBox
var input_driver_ovt: SpinBox
var input_driver_def: SpinBox
var input_driver_wet: SpinBox
var input_driver_moral: SpinBox
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
	_setup_custom_modals()
	build_ui()

# --- CRIAÇÃO DOS MODAIS COM DESIGN CUSTOMIZADO E CANVASLAYER PARA ELEVAÇÃO ---
func _setup_custom_modals() -> void:
	# CanvasLayer com prioridade alta (100) para garantir renderização sobre qualquer elemento 2D/UI
	modal_layer = CanvasLayer.new()
	modal_layer.layer = 100
	add_child(modal_layer)

	# 1. Overlay Escuro Semi-Transparente
	modal_overlay = ColorRect.new()
	modal_overlay.color = Color(0, 0, 0, 0.65)
	modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.visible = false
	modal_layer.add_child(modal_overlay)

	# 2. Modal Criar Equipe
	create_team_modal = _create_base_modal_panel(Vector2(380, 480))
	var vbox_t = VBoxContainer.new()
	vbox_t.add_theme_constant_override("separation", 8)
	
	_add_modal_header(vbox_t, "➕ CRIAR NOVA EQUIPE", func(): _close_modal(create_team_modal))
	
	var scroll_t = ScrollContainer.new()
	scroll_t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner_t = VBoxContainer.new()
	inner_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_t.add_theme_constant_override("separation", 6)
	
	input_team_name = _create_styled_line_edit(inner_t, "Nome da Equipe:", "Ex: Porsche F1")
	input_team_resp = _create_styled_spinbox(inner_t, "Respeito:", 10, 100, 60)
	input_team_aero = _create_styled_spinbox(inner_t, "Aerodinâmica:", 50, 99, 75)
	input_team_motor = _create_styled_spinbox(inner_t, "Motor:", 50, 99, 75)
	input_team_chassis = _create_styled_spinbox(inner_t, "Chassi:", 50, 99, 75)
	input_team_reliability = _create_styled_spinbox(inner_t, "Confiabilidade:", 50, 99, 80)
	
	scroll_t.add_child(inner_t)
	vbox_t.add_child(scroll_t)
	
	_add_modal_footer_buttons(vbox_t, "Confirmar Criar Equipe", _on_create_team_confirmed, func(): _close_modal(create_team_modal))
	create_team_modal.add_child(vbox_t)
	modal_overlay.add_child(create_team_modal)

	# 3. Modal Criar Piloto
	create_driver_modal = _create_base_modal_panel(Vector2(420, 560))
	var vbox_d = VBoxContainer.new()
	vbox_d.add_theme_constant_override("separation", 8)
	
	_add_modal_header(vbox_d, "👤+ CRIAR NOVO PILOTO", func(): _close_modal(create_driver_modal))
	
	var scroll_d = ScrollContainer.new()
	scroll_d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner_d = VBoxContainer.new()
	inner_d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_d.add_theme_constant_override("separation", 6)
	
	input_driver_name = _create_styled_line_edit(inner_d, "Nome do Piloto:", "Ex: Ayrton Senna")
	input_driver_age = _create_styled_spinbox(inner_d, "Idade:", 16, 50, 20)
	input_driver_ovr = _create_styled_spinbox(inner_d, "Overall:", 50, 99, 75)
	input_driver_pace = _create_styled_spinbox(inner_d, "Pace/Corrida:", 50, 99, 75)
	input_driver_tire = _create_styled_spinbox(inner_d, "Pneus:", 50, 99, 75)
	input_driver_ovt = _create_styled_spinbox(inner_d, "Ultrapassagem (OVT):", 50, 99, 75)
	input_driver_def = _create_styled_spinbox(inner_d, "Defesa (DEF):", 50, 99, 75)
	input_driver_wet = _create_styled_spinbox(inner_d, "Habilidade Chuva (WET):", 50, 99, 75)
	input_driver_moral = _create_styled_spinbox(inner_d, "Moral (MOR):", 0, 100, 75)
	
	var lbl_t = Label.new()
	lbl_t.text = "Equipe Inicial:"
	lbl_t.add_theme_font_size_override("font_size", 12)
	lbl_t.add_theme_color_override("font_color", Color("#94a3b8"))
	inner_d.add_child(lbl_t)
	
	input_driver_team = OptionButton.new()
	input_driver_team.custom_minimum_size = Vector2(0, 32)
	inner_d.add_child(input_driver_team)
	
	scroll_d.add_child(inner_d)
	vbox_d.add_child(scroll_d)
	
	_add_modal_footer_buttons(vbox_d, "Confirmar Criar Piloto", _on_create_driver_confirmed, func(): _close_modal(create_driver_modal))
	create_driver_modal.add_child(vbox_d)
	modal_overlay.add_child(create_driver_modal)

func _create_base_modal_panel(p_size: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = p_size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#111622")
	style.border_width_top = 3
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _add_modal_header(parent: VBoxContainer, title_text: String, close_callable: Callable) -> void:
	var header_hbox = HBoxContainer.new()
	
	var lbl_title = Label.new()
	lbl_title.text = title_text
	lbl_title.add_theme_font_size_override("font_size", 16)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(lbl_title)
	
	var btn_close = Button.new()
	btn_close.text = "✖"
	btn_close.custom_minimum_size = Vector2(28, 28)
	btn_close.flat = true
	btn_close.add_theme_color_override("font_color", Color("#94a3b8"))
	btn_close.pressed.connect(close_callable)
	header_hbox.add_child(btn_close)
	
	parent.add_child(header_hbox)

func _add_modal_footer_buttons(parent: VBoxContainer, confirm_text: String, confirm_callable: Callable, cancel_callable: Callable) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	var btn_confirm = Button.new()
	btn_confirm.text = confirm_text
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size = Vector2(0, 36)
	
	var style_confirm = StyleBoxFlat.new()
	style_confirm.bg_color = Color("#ef4444")
	style_confirm.set_corner_radius_all(6)
	btn_confirm.add_theme_stylebox_override("normal", style_confirm)
	btn_confirm.add_theme_color_override("font_color", Color("#ffffff"))
	btn_confirm.pressed.connect(confirm_callable)
	hbox.add_child(btn_confirm)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.custom_minimum_size = Vector2(0, 36)
	
	var style_cancel = StyleBoxFlat.new()
	style_cancel.bg_color = Color("#1e293b")
	style_cancel.set_corner_radius_all(6)
	btn_cancel.add_theme_stylebox_override("normal", style_cancel)
	btn_cancel.add_theme_color_override("font_color", Color("#94a3b8"))
	btn_cancel.pressed.connect(cancel_callable)
	hbox.add_child(btn_cancel)
	
	parent.add_child(hbox)

func _show_modal(modal: PanelContainer) -> void:
	modal_overlay.visible = true
	create_team_modal.visible = (modal == create_team_modal)
	create_driver_modal.visible = (modal == create_driver_modal)

func _close_modal(modal: PanelContainer) -> void:
	modal.visible = false
	modal_overlay.visible = false

func build_ui() -> void:
	for c in get_children():
		if c != modal_layer:
			c.queue_free()
		
	grid_driver_inputs.clear()
	fa_driver_inputs.clear()
	team_inputs.clear()
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 14)
	add_child(main_vbox)
	
	# Mão dupla: Garante que o CanvasLayer fique sempre no final da árvore de nós
	if modal_layer:
		move_child(modal_layer, -1)
	
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
	p_style.content_margin_left = 8
	p_style.content_margin_right = 8
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
	grid.columns = 10
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 6)
	
	_add_header(grid, "PILOTO", 95)
	_add_header(grid, "IDADE", 38)
	_add_header(grid, "OVR", 40)
	_add_header(grid, "PACE", 40)
	_add_header(grid, "PNEU", 40)
	_add_header(grid, "OVT", 40)
	_add_header(grid, "DEF", 40)
	_add_header(grid, "WET", 40)
	_add_header(grid, "MOR", 40)
	_add_header(grid, "EQUIPE", 85)
	
	for d in driver_list:
		var name_lbl = Label.new()
		name_lbl.text = d.get("Nome", "")
		name_lbl.add_theme_font_size_override("font_size", 11)
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
		
		var ovt_spin = SpinBox.new()
		ovt_spin.min_value = 50
		ovt_spin.max_value = 99
		ovt_spin.value = d.get("Ultrapassagem", d.get("Overall", 75))
		grid.add_child(ovt_spin)
		
		var def_spin = SpinBox.new()
		def_spin.min_value = 50
		def_spin.max_value = 99
		def_spin.value = d.get("Defesa", d.get("Overall", 75))
		grid.add_child(def_spin)
		
		var wet_spin = SpinBox.new()
		wet_spin.min_value = 50
		wet_spin.max_value = 99
		wet_spin.value = d.get("HabilidadeChuva", d.get("Overall", 75))
		grid.add_child(wet_spin)
		
		var mor_spin = SpinBox.new()
		mor_spin.min_value = 0
		mor_spin.max_value = 100
		mor_spin.value = d.get("Moral", 75)
		grid.add_child(mor_spin)
		
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
			"ovt_node": ovt_spin,
			"def_node": def_spin,
			"wet_node": wet_spin,
			"mor_node": mor_spin,
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
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	
	_add_header(grid, "EQUIPE", 95)
	_add_header(grid, "RESP", 45)
	_add_header(grid, "AERO", 45)
	_add_header(grid, "MOTOR", 45)
	_add_header(grid, "CHASSI", 45)
	_add_header(grid, "CONF", 45)
	
	for t in team_list:
		var t_name_lbl = Label.new()
		var is_active = bool(t.get("Ativa", true))
		
		if is_active:
			t_name_lbl.text = t.get("Nome", "")
			t_name_lbl.add_theme_color_override("font_color", Color("#ffffff"))
		else:
			t_name_lbl.text = t.get("Nome", "") + " ⏳"
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
		
		var rel_spin = SpinBox.new()
		rel_spin.min_value = 50
		rel_spin.max_value = 99
		rel_spin.value = t.get("Confiabilidade", 80)
		grid.add_child(rel_spin)
		
		input_array.append({
			"team_ref": t,
			"resp_node": resp_spin,
			"aero_node": aero_spin,
			"motor_node": motor_spin,
			"chassis_node": chassis_spin,
			"rel_node": rel_spin
		})
		
	scroll.add_child(grid)
	vbox.add_child(scroll)
	panel.add_child(vbox)
	parent.add_child(panel)

# --- MÉTODOS DE ABERTURA E CONFIRMAÇÃO DOS MODAIS ---
func _open_create_team_modal() -> void:
	input_team_name.text = ""
	_show_modal(create_team_modal)

func _open_create_driver_modal() -> void:
	input_driver_name.text = ""
	input_driver_team.clear()
	input_driver_team.add_item("Free Agent")
	for t in Database.teams:
		input_driver_team.add_item(t.get("Nome", ""))
	input_driver_team.selected = 0
	_show_modal(create_driver_modal)

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
		var new_team = Database._get_team_by_name(t_name)
		if not new_team.is_empty():
			new_team["Confiabilidade"] = int(input_team_reliability.value)
			
	_close_modal(create_team_modal)
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
			int(input_driver_wet.value),
			int(input_driver_ovt.value),
			int(input_driver_def.value),
			sel_team
		)
		var new_driver = Database._get_driver_by_name(d_name)
		if not new_driver.is_empty():
			new_driver["Moral"] = float(input_driver_moral.value)
			
	_close_modal(create_driver_modal)
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
		d["Ultrapassagem"] = int(item["ovt_node"].value)
		d["Defesa"] = int(item["def_node"].value)
		d["HabilidadeChuva"] = int(item["wet_node"].value)
		d["Moral"] = float(item["mor_node"].value)
		
		var opt_node = item["team_node"]
		var selected_team = opt_node.get_item_text(opt_node.selected)
		d["Equipe"] = selected_team

	for item in team_inputs:
		var t = item["team_ref"]
		t["Respeito"] = int(item["resp_node"].value)
		t["Aero"] = int(item["aero_node"].value)
		t["Motor"] = int(item["motor_node"].value)
		t["Chassi"] = int(item["chassis_node"].value)
		t["Confiabilidade"] = int(item["rel_node"].value)

	Database.save_game()
	if Database.has_method("add_news_event"):
		Database.add_news_event("💾 ALTERAÇÕES SALVAS: Atributos de pilotos e equipes atualizados!")
	print("✅ Todas as alterações foram salvas no Database!")
	build_ui()

func _add_header(grid: GridContainer, text: String, min_w: float) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	grid.add_child(lbl)

func _create_styled_line_edit(parent: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	parent.add_child(lbl)
	
	var le = LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(0, 32)
	parent.add_child(le)
	return le

func _create_styled_spinbox(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, default_v: float) -> SpinBox:
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	parent.add_child(lbl)
	
	var sb = SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.value = default_v
	sb.custom_minimum_size = Vector2(0, 32)
	parent.add_child(sb)
	return sb
