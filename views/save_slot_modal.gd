extends ColorRect
class_name SaveSlotModal

enum Mode { SAVE, LOAD }
var current_mode: Mode = Mode.SAVE
var on_completed_callback: Callable

func open_modal(parent_node: Node, mode: Mode, callback: Callable = Callable()) -> void:
	current_mode = mode
	on_completed_callback = callback
	
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color(0, 0, 0, 0.85)
	
	_render_contents()
	parent_node.add_child(self)

func _render_contents() -> void:
	for c in get_children():
		c.queue_free()
		
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 460)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.border_width_top = 3
	style.border_color = Color("#ef4444")
	style.set_corner_radius_all(6)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	
	# Título traduzido
	var lbl_title = Label.new()
	if current_mode == Mode.SAVE:
		lbl_title.text = Database.tr_text("SAVE_MODAL_TITLE_SAVE") if Database.has_method("tr_text") else "💾 SALVAR JOGO - ESCOLHA O SLOT"
	else:
		lbl_title.text = Database.tr_text("SAVE_MODAL_TITLE_LOAD") if Database.has_method("tr_text") else "📂 CARREGAR JOGO - ESCOLHA O SLOT"
		
	lbl_title.add_theme_font_size_override("font_size", 16)
	lbl_title.add_theme_color_override("font_color", Color("#ef4444"))
	vbox.add_child(lbl_title)
	
	var slots_data = Database.get_all_slots_info()
	var visible_slots: Array = []
	for slot_info in slots_data:
		if current_mode == Mode.LOAD or str(slot_info["mode"]) == str(Database.game_mode):
			visible_slots.append(slot_info)

	var slots_scroll := ScrollContainer.new()
	slots_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_scroll.custom_minimum_size.y = 260
	var slots_list := VBoxContainer.new()
	slots_list.add_theme_constant_override("separation", 10)
	for slot_info in visible_slots:
		var slot_card = _build_slot_row(slot_info)
		slots_list.add_child(slot_card)
	slots_scroll.add_child(slots_list)
	vbox.add_child(slots_scroll)
		
	# Botão Voltar traduzido
	var btn_close = Button.new()
	btn_close.text = Database.tr_text("BTN_BACK") if Database.has_method("tr_text") else "VOLTAR"
	btn_close.custom_minimum_size.y = 36
	btn_close.add_theme_font_size_override("font_size", 12)
	btn_close.pressed.connect(func(): queue_free())
	vbox.add_child(btn_close)
	
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)

func _build_slot_row(slot_info: Dictionary) -> PanelContainer:
	var row = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.12, 0.15, 0.22, 0.9)
	row_style.set_corner_radius_all(4)
	row.add_theme_stylebox_override("panel", row_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_input = LineEdit.new()
	name_input.text = slot_info["name"]
	name_input.placeholder_text = Database.tr_text("SAVE_INPUT_PLACEHOLDER") if Database.has_method("tr_text") else "Nome do Save..."
	name_input.add_theme_font_size_override("font_size", 13)
	info_vbox.add_child(name_input)
	
	var details_lbl = Label.new()
	if slot_info["exists"]:
		var mode_name := "Observador" if str(slot_info["mode"]) == "observer" else "Manager"
		details_lbl.text = "Modo: %s | Ano: %d" % [mode_name, slot_info["year"]]
		details_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
	else:
		details_lbl.text = Database.tr_text("SAVE_SLOT_EMPTY") if Database.has_method("tr_text") else "Slot Vazio"
		details_lbl.add_theme_color_override("font_color", Color("#64748b"))
		
	details_lbl.add_theme_font_size_override("font_size", 11)
	info_vbox.add_child(details_lbl)
	
	hbox.add_child(info_vbox)
	
	# Botão de Excluir 🗑️
	if slot_info["exists"]:
		var btn_delete = Button.new()
		btn_delete.text = "🗑️"
		btn_delete.custom_minimum_size = Vector2(36, 36)
		btn_delete.add_theme_font_size_override("font_size", 12)
		var style_del = StyleBoxFlat.new()
		style_del.bg_color = Color(0.6, 0.1, 0.1, 0.8)
		style_del.set_corner_radius_all(4)
		btn_delete.add_theme_stylebox_override("normal", style_del)
		
		btn_delete.pressed.connect(func():
			if Database.delete_save_slot(slot_info["slot"], slot_info["mode"]):
				_render_contents()
		)
		hbox.add_child(btn_delete)

	# Botão de Ação Principal (Salvar ou Carregar)
	var btn_action = Button.new()
	btn_action.custom_minimum_size = Vector2(110, 36)
	btn_action.add_theme_font_size_override("font_size", 12)
	
	if current_mode == Mode.SAVE:
		btn_action.text = Database.tr_text("BTN_SAVE") if Database.has_method("tr_text") else "💾 SALVAR"
		btn_action.pressed.connect(func():
			if Database.save_game_slot(slot_info["slot"], name_input.text, slot_info["mode"]):
				if on_completed_callback.is_valid():
					on_completed_callback.call()
				queue_free()
		)
	else:
		btn_action.text = Database.tr_text("BTN_LOAD") if Database.has_method("tr_text") else "▶ CARREGAR"
		btn_action.disabled = not slot_info["exists"]
		btn_action.pressed.connect(func():
			if Database.load_game_slot(slot_info["slot"], slot_info["mode"]):
				if on_completed_callback.is_valid():
					on_completed_callback.call()
				queue_free()
		)
		
	hbox.add_child(btn_action)
	margin.add_child(hbox)
	row.add_child(margin)
	return row
