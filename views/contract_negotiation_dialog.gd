extends Window

var driver: Dictionary = {}
var team_name: String = ""
var on_accepted: Callable
var requested_salary: float = 0.0
var requested_years: int = 1
var requested_status: String = "Piloto Igualitário"
var salary_input: SpinBox
var years_input: OptionButton
var status_input: OptionButton
var attempts_label: Label
var feedback_label: Label
var send_button: Button

func open_for_driver(parent: Node, target_driver: Dictionary, target_team: String, accepted_callback: Callable, renewal: bool = false) -> void:
	driver = target_driver
	team_name = target_team
	on_accepted = accepted_callback
	var overall := int(driver.get("Overall", driver.get("Habilidade", 75)))
	requested_salary = float(driver.get("salario", clampf((overall - 70.0) * 1.2 + 4.0, 2.5, 38.0)))
	requested_years = clampi(int(driver.get("anos_pedidos", driver.get("AnosContrato", 2))), 1, 3)
	requested_status = str(driver.get("status_pedido", "1º Piloto" if overall >= 88 else "Piloto Igualitário"))
	if not driver.has("tentativas_restantes"):
		driver["tentativas_restantes"] = 3
	driver["salario"] = requested_salary
	driver["anos_pedidos"] = requested_years
	driver["status_pedido"] = requested_status

	title = "🤝 RENEGOCIAR CONTRATO - " + str(driver.get("Nome", "Piloto")) if renewal else "🤝 MESA DE NEGOCIAÇÃO - " + str(driver.get("Nome", "Piloto"))
	size = Vector2i(700, 430)
	exclusive = true
	content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	close_requested.connect(queue_free)
	_build_dialog()
	parent.add_child(self)
	popup_centered()

func _build_dialog() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var requirements := Label.new()
	requirements.text = "Exigências de %s: $%.1fM/ano, %d ano(s), %s" % [
		str(driver.get("Nome", "Piloto")), requested_salary, requested_years, requested_status
	]
	requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(requirements)

	var salary_label := Label.new()
	salary_label.text = "Salário oferecido ($M por ano)"
	layout.add_child(salary_label)
	salary_input = SpinBox.new()
	salary_input.min_value = 1.0
	salary_input.max_value = 50.0
	salary_input.step = 0.1
	salary_input.value = requested_salary
	layout.add_child(salary_input)

	var years_label := Label.new()
	years_label.text = "Duração do contrato"
	layout.add_child(years_label)
	years_input = OptionButton.new()
	for years in range(1, 4):
		years_input.add_item("%d ano(s)" % years, years)
	years_input.select(requested_years - 1)
	layout.add_child(years_input)

	var status_label := Label.new()
	status_label.text = "Papel na equipe"
	layout.add_child(status_label)
	status_input = OptionButton.new()
	status_input.add_item("1º Piloto Titular", 0)
	status_input.add_item("Piloto Igualitário", 1)
	status_input.add_item("2º Piloto Titular", 2)
	status_input.select(0 if requested_status == "1º Piloto" else (2 if requested_status == "2º Piloto" else 1))
	layout.add_child(status_input)

	attempts_label = Label.new()
	feedback_label = Label.new()
	layout.add_child(attempts_label)
	layout.add_child(feedback_label)
	_update_attempts_label()

	var actions := HBoxContainer.new()
	send_button = Button.new()
	send_button.text = "Enviar proposta"
	send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_button.pressed.connect(_submit_offer)
	actions.add_child(send_button)
	var cancel_button := Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(queue_free)
	actions.add_child(cancel_button)
	layout.add_child(actions)
	add_child(margin)

func _submit_offer() -> void:
	var offered_years := years_input.get_selected_id()
	var offered_status: String = ["1º Piloto", "Piloto Igualitário", "2º Piloto"][status_input.selected]
	var minimum_salary := requested_salary * 0.92
	if status_input.selected == 0 and requested_status != "1º Piloto":
		minimum_salary *= 0.95
	if offered_years > requested_years:
		minimum_salary *= 0.97

	if salary_input.value >= minimum_salary:
		driver["salario"] = salary_input.value
		driver["AnosContrato"] = offered_years
		driver["contrato_anos"] = offered_years
		driver["status_pedido"] = offered_status
		feedback_label.text = "Proposta aceita por %s." % str(driver.get("Nome", "Piloto"))
		feedback_label.add_theme_color_override("font_color", Color("#34d399"))
		if on_accepted.is_valid():
			on_accepted.call(driver, salary_input.value, offered_years, offered_status)
		queue_free()
		return

	driver["tentativas_restantes"] = maxi(0, int(driver.get("tentativas_restantes", 3)) - 1)
	_update_attempts_label()
	feedback_label.text = "Proposta recusada. Aumente a oferta ou ajuste os termos."
	feedback_label.add_theme_color_override("font_color", Color("#f87171"))
	if int(driver["tentativas_restantes"]) <= 0:
		driver["inegociavel"] = true
		send_button.disabled = true

func _update_attempts_label() -> void:
	attempts_label.text = "Tentativas restantes: %d/3" % int(driver.get("tentativas_restantes", 3))
