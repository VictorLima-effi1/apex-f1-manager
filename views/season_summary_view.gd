extends Control

var continue_callback: Callable

func open_summary(parent: Control, summary: Dictionary, on_continue: Callable) -> void:
	continue_callback = on_continue
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	parent.add_child(self)
	_build_summary(summary)

func _build_summary(summary: Dictionary) -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var viewport_size := get_viewport_rect().size
	panel.custom_minimum_size = Vector2(
		minf(850.0, maxf(320.0, viewport_size.x * 0.9)),
		minf(680.0, maxf(420.0, viewport_size.y * 0.9))
	)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#121417")
	panel_style.border_color = Color("#ef4444")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "FIM DA TEMPORADA %d" % int(summary.get("year", Database.current_year))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#facc15"))
	layout.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	var driver_champion: Dictionary = summary.get("driver_champion", {})
	var constructor_champion: Dictionary = summary.get("constructor_champion", {})
	_add_line(content, "🏆 Campeão de pilotos: %s — %d pontos" % [
		str(driver_champion.get("Nome", "Indefinido")),
		int(driver_champion.get("Pontos", 0))
	], Color("#ffffff"), 18)
	_add_line(content, "🏆 Campeã de construtores: %s — %d pontos" % [
		str(constructor_champion.get("Nome", "Indefinida")),
		int(constructor_champion.get("Pontos", 0))
	], Color("#ffffff"), 18)

	if str(Database.game_mode) == "manager":
		var manager_drivers: Array = summary.get("manager_drivers", [])
		_add_line(content, "Sua equipe: %s" % str(summary.get("manager_team", "Equipe")), Color("#38bdf8"), 15)
		if manager_drivers.is_empty():
			_add_line(content, "Não há pilotos da equipe registrados nesta temporada.", Color("#94a3b8"), 13)
		else:
			for driver in manager_drivers:
				_add_line(content, "%s — %d pts | %d vitórias | %d pódios | %d DNFs" % [
					str(driver.get("Nome", "Piloto")),
					int(driver.get("Pontos", 0)),
					int(driver.get("VitoriasAno", 0)),
					int(driver.get("PodiosAno", 0)),
					int(driver.get("DNFsAno", 0))
				], Color("#e2e8f0"), 13)

	content.add_child(HSeparator.new())
	_add_line(content, "Destaques da temporada", Color("#38bdf8"), 15)
	_add_stat_line(content, "Mais vitórias", summary.get("wins_leader", {}), "VitoriasAno")
	_add_stat_line(content, "Mais posições ganhas", summary.get("positions_leader", {}), "PosicoesGanhaAno")
	_add_stat_line(content, "Mais DNFs", summary.get("dnfs_leader", {}), "DNFsAno")

	var standings: Array = summary.get("driver_standings", [])
	if not standings.is_empty():
		content.add_child(HSeparator.new())
		_add_line(content, "Classificação final — pilotos", Color("#38bdf8"), 15)
		for i in range(standings.size()):
			var driver: Dictionary = standings[i]
			_add_line(content, "P%d  %s (%s) — %d pts" % [
				i + 1,
				str(driver.get("Nome", "Piloto")),
				str(driver.get("Equipe", "Equipe")),
				int(driver.get("Pontos", 0))
			], Color("#e2e8f0"), 12)

	var continue_button := Button.new()
	continue_button.text = "Iniciar próxima temporada"
	continue_button.custom_minimum_size.y = 42
	continue_button.pressed.connect(func():
		if continue_callback.is_valid():
			continue_callback.call()
		queue_free()
	)
	layout.add_child(continue_button)

func _add_stat_line(parent: VBoxContainer, title: String, driver_data: Variant, stat_key: String) -> void:
	var driver: Dictionary = driver_data if driver_data is Dictionary else {}
	_add_line(parent, "%s: %s — %d" % [
		title,
		str(driver.get("Nome", "—")),
		int(driver.get(stat_key, 0))
	], Color("#e2e8f0"), 12)

func _add_line(parent: VBoxContainer, text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
