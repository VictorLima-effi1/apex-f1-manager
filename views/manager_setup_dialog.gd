extends Control

signal setup_closed

# Referências de UI
var main_choice_panel: PanelContainer
var create_team_panel: PanelContainer
var select_team_panel: PanelContainer
var popup_dialog: AcceptDialog

# Campos do Formulário
var input_team_name: LineEdit
var input_boss_name: LineEdit
var input_country: LineEdit
var color_picker: ColorPickerButton

# Campos da Seleção de Equipe Existente
var team_option_button: OptionButton
var team_info_label: RichTextLabel

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_show_main_choice()

func _build_ui() -> void:
	# Fundo Semi-transparente
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)
	
	_build_main_choice_panel()
	_build_create_team_panel()
	_build_select_team_panel()
	_build_popup_dialog()

# --- TELA 1: ESCOLHA INICIAL (CRIAR OU EXISTENTE) ---
func _build_main_choice_panel() -> void:
	main_choice_panel = PanelContainer.new()
	main_choice_panel.anchor_left = 0.3
	main_choice_panel.anchor_top = 0.3
	main_choice_panel.anchor_right = 0.7
	main_choice_panel.anchor_bottom = 0.7
	add_child(main_choice_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	main_choice_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "MODO MANAGER - SELEÇÃO DE EQUIPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var btn_create = Button.new()
	btn_create.text = "Criar Equipe Própria"
	btn_create.custom_minimum_size = Vector2(0, 45)
	btn_create.pressed.connect(_on_create_team_pressed)
	vbox.add_child(btn_create)
	
	var btn_existing = Button.new()
	btn_existing.text = "Escolher Equipe Existente"
	btn_existing.custom_minimum_size = Vector2(0, 45)
	btn_existing.pressed.connect(_on_existing_team_pressed)
	vbox.add_child(btn_existing)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Voltar ao Menu Principal"
	btn_cancel.pressed.connect(queue_free)
	vbox.add_child(btn_cancel)

# --- TELA 2: FORMULÁRIO DE CRIAR EQUIPE ---
func _build_create_team_panel() -> void:
	create_team_panel = PanelContainer.new()
	create_team_panel.anchor_left = 0.25
	create_team_panel.anchor_top = 0.15
	create_team_panel.anchor_right = 0.75
	create_team_panel.anchor_bottom = 0.85
	create_team_panel.visible = false
	add_child(create_team_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	create_team_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "CRIAR NOVA EQUIPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Campo Nome da Equipe
	vbox.add_child(_create_label("Nome da Equipe:"))
	input_team_name = LineEdit.new()
	input_team_name.placeholder_text = "Ex: Apex Racing Team"
	vbox.add_child(input_team_name)
	
	# Campo Nome do Chefe
	vbox.add_child(_create_label("Nome do Chefe de Equipe:"))
	input_boss_name = LineEdit.new()
	input_boss_name.placeholder_text = "Ex: Seu Nome"
	vbox.add_child(input_boss_name)
	
	# Campo País Sede
	vbox.add_child(_create_label("País Sede:"))
	input_country = LineEdit.new()
	input_country.placeholder_text = "Ex: Brasil"
	vbox.add_child(input_country)
	
	# Cor Principal
	var color_hbox = HBoxContainer.new()
	color_hbox.add_child(_create_label("Cor Principal da Equipe: "))
	color_picker = ColorPickerButton.new()
	color_picker.color = Color.RED
	color_picker.custom_minimum_size = Vector2(80, 30)
	color_hbox.add_child(color_picker)
	vbox.add_child(color_hbox)
	
	var btn_submit = Button.new()
	btn_submit.text = "Confirmar Criação"
	btn_submit.custom_minimum_size = Vector2(0, 40)
	btn_submit.pressed.connect(_on_confirm_create_team)
	vbox.add_child(btn_submit)
	
	var btn_back = Button.new()
	btn_back.text = "Voltar"
	btn_back.pressed.connect(_show_main_choice)
	vbox.add_child(btn_back)

# --- TELA 3: VISUALIZAR EQUIPE EXISTENTE ---
func _build_select_team_panel() -> void:
	select_team_panel = PanelContainer.new()
	select_team_panel.anchor_left = 0.2
	select_team_panel.anchor_top = 0.1
	select_team_panel.anchor_right = 0.8
	select_team_panel.anchor_bottom = 0.9
	select_team_panel.visible = false
	add_child(select_team_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	select_team_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "SELECIONAR EQUIPE EXISTENTE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Dropdown de Equipes
	team_option_button = OptionButton.new()
	team_option_button.item_selected.connect(_on_team_selected)
	vbox.add_child(team_option_button)
	
	# Caixa de Informações (Atributos do Carro, Orçamento e Pilotos)
	team_info_label = RichTextLabel.new()
	team_info_label.bbcode_enabled = true
	team_info_label.custom_minimum_size = Vector2(0, 220)
	team_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(team_info_label)
	
	var btn_confirm = Button.new()
	btn_confirm.text = "Escolher Esta Equipe"
	btn_confirm.custom_minimum_size = Vector2(0, 40)
	btn_confirm.pressed.connect(_on_confirm_select_team)
	vbox.add_child(btn_confirm)
	
	var btn_back = Button.new()
	btn_back.text = "Voltar"
	btn_back.pressed.connect(_show_main_choice)
	vbox.add_child(btn_back)

# Pop-up de Aviso "Modo em desenvolvimento"
func _build_popup_dialog() -> void:
	popup_dialog = AcceptDialog.new()
	popup_dialog.title = "Aviso"
	popup_dialog.dialog_text = "Ainda estamos quebrando a cabeça para desenvolver esse modo de jogo, por favor, escolha o outro :("
	popup_dialog.confirmed.connect(_on_popup_confirmed)
	add_child(popup_dialog)

# --- FUNÇÕES DE NAVEGAÇÃO ENTRE TELAS ---
func _show_main_choice() -> void:
	main_choice_panel.visible = true
	create_team_panel.visible = false
	select_team_panel.visible = false

func _on_create_team_pressed() -> void:
	main_choice_panel.visible = false
	create_team_panel.visible = true

func _on_existing_team_pressed() -> void:
	main_choice_panel.visible = false
	select_team_panel.visible = true
	_populate_teams_dropdown()

# --- LÓGICA DE EXIBIÇÃO DE EQUIPE EXISTENTE ---
func _populate_teams_dropdown() -> void:
	team_option_button.clear()
	for i in range(Database.teams.size()):
		var team = Database.teams[i]
		team_option_button.add_item(team.get("Nome", "Sem Nome"), i)
	
	if Database.teams.size() > 0:
		_on_team_selected(0)

func _on_team_selected(index: int) -> void:
	if index < 0 or index >= Database.teams.size():
		return
		
	var team = Database.teams[index]
	var team_name = team.get("Nome", "Sem Nome")
	
	# Busca Pilotos vinculados a essa equipe no banco
	var drivers = []
	for driver in Database.drivers:
		if driver.get("Equipe", "") == team_name:
			drivers.append(driver)
			
	# Monta o texto em BBCode com atributos, orçamento e pilotos
	var info_text = "[b]EQUIPE:[/b] " + team_name + "\n"
	info_text += "[b]ORÇAMENTO TEMPORADA:[/b] $" + str(team.get("Orcamento", 0)) + " M\n\n"
	
	info_text += "[b]ATRIBUTOS DO CARRO:[/b]\n"
	info_text += " - Motor: " + str(team.get("Motor", 0)) + " | Aerodinâmica: " + str(team.get("Aero", 0)) + "\n"
	info_text += " - Chassi: " + str(team.get("Chassi", 0)) + " | Confiabilidade: " + str(team.get("Confiabilidade", 0)) + "%\n\n"
	
	info_text += "[b]PILOTOS:[/b]\n"
	if drivers.size() == 0:
		info_text += " - Nenhum piloto atribuído\n"
	else:
		for d in drivers:
			var d_name = d.get("Nome", "-")
			var d_overall = d.get("Habilidade", d.get("Overall", "-"))
			info_text += " - " + d_name + " (Overall: " + str(d_overall) + ")\n"
			
	team_info_label.text = info_text

# --- CONFIRMAÇÕES DE SELEÇÃO E BLOQUEIO DE AVANÇO ---
func _on_confirm_create_team() -> void:
	# Armazena os dados criados no Database
	Database.is_custom_team = true
	Database.custom_team_data = {
		"nome": input_team_name.text if not input_team_name.text.is_empty() else "Minha Equipe",
		"cor": color_picker.color,
		"chefe": input_boss_name.text if not input_boss_name.text.is_empty() else "Chefe",
		"pais": input_country.text if not input_country.text.is_empty() else "Brasil"
	}
	# Bloqueia e mostra o aviso
	popup_dialog.popup_centered()

func _on_confirm_select_team() -> void:
	var selected_idx = team_option_button.selected
	if selected_idx >= 0 and selected_idx < Database.teams.size():
		Database.is_custom_team = false
		Database.selected_manager_team = Database.teams[selected_idx]
	# Bloqueia e mostra o aviso
	popup_dialog.popup_centered()

func _on_popup_confirmed() -> void:
	# Fecha o menu do Modo Manager e permanece no menu principal
	queue_free()

func _create_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	return l
