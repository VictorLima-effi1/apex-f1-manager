extends Control
class_name TutorialOverlay

signal tutorial_finished

var steps: Array[Dictionary] = []
var step_index: int = 0
var target_control: Control
var description_label: Label
var hint_label: Label
var tutorial_card: PanelContainer
var typing_elapsed: float = 0.0
var typing_complete: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	set_process_input(true)
	_build_card()

func start_tutorial(tutorial_steps: Array[Dictionary]) -> void:
	steps = tutorial_steps
	step_index = 0
	_show_current_step()

func _build_card() -> void:
	tutorial_card = PanelContainer.new()
	tutorial_card.custom_minimum_size = Vector2(480, 150)
	tutorial_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#101318", 0.98)
	card_style.border_color = Color("#ef4444")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.shadow_color = Color(0, 0, 0, 0.65)
	card_style.shadow_size = 18
	tutorial_card.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 15)
	description_label.add_theme_color_override("font_color", Color("#f1f5f9"))
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(description_label)

	hint_label = Label.new()
	hint_label.text = Database.tr_text("TUTORIAL_CONTINUE_HINT") if Database.has_method("tr_text") else "Clique em qualquer lugar ou pressione Enter para continuar"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color("#94a3b8"))
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(hint_label)

	margin.add_child(content)
	tutorial_card.add_child(margin)
	add_child(tutorial_card)

func _show_current_step() -> void:
	if step_index >= steps.size():
		tutorial_finished.emit()
		queue_free()
		return

	var step: Dictionary = steps[step_index]
	target_control = step.get("target") as Control
	description_label.text = str(step.get("text", ""))
	description_label.visible_characters = 0
	typing_elapsed = 0.0
	typing_complete = false
	_position_card()
	queue_redraw()

func _refresh_target() -> void:
	if is_instance_valid(target_control):
		return
	if step_index >= steps.size():
		return
	var step: Dictionary = steps[step_index]
	var target_root: Variant = step.get("target_root")
	var target_name := str(step.get("target_name", ""))
	if target_root is Node and is_instance_valid(target_root) and not target_name.is_empty():
		target_control = target_root.find_child(target_name, true, false) as Control
		if is_instance_valid(target_control):
			_position_card()
			queue_redraw()

func _position_card() -> void:
	var viewport_size := get_viewport_rect().size
	var card_width := minf(560.0, maxf(300.0, viewport_size.x - 36.0))
	tutorial_card.custom_minimum_size = Vector2(card_width, 150.0)
	tutorial_card.size = Vector2(card_width, 150.0)
	var card_x := (viewport_size.x - card_width) * 0.5
	var target_rect := Rect2()
	if is_instance_valid(target_control) and target_control.is_visible_in_tree():
		target_rect = target_control.get_global_rect()
	var card_y := 20.0 if target_rect.position.y > viewport_size.y * 0.5 else viewport_size.y - tutorial_card.size.y - 24.0
	tutorial_card.position = Vector2(card_x, maxf(16.0, card_y))

func _process(delta: float) -> void:
	_refresh_target()
	if typing_complete or not is_instance_valid(description_label):
		return
	typing_elapsed += delta
	var visible_count := int(typing_elapsed / 0.022)
	if visible_count >= description_label.text.length():
		description_label.visible_characters = -1
		typing_complete = true
	else:
		description_label.visible_characters = visible_count

func _input(event: InputEvent) -> void:
	var should_advance := false
	if event is InputEventMouseButton and event.pressed:
		should_advance = event.button_index <= MOUSE_BUTTON_MIDDLE
	elif event is InputEventKey and event.pressed and not event.echo:
		should_advance = event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	if should_advance:
		get_viewport().set_input_as_handled()
		step_index += 1
		_show_current_step()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var highlight := Rect2()
	if is_instance_valid(target_control) and target_control.is_visible_in_tree():
		highlight = target_control.get_global_rect().grow(8.0)
		var highlight_position := Vector2(
			clampf(highlight.position.x, 0.0, viewport_size.x),
			clampf(highlight.position.y, 0.0, viewport_size.y)
		)
		var highlight_end := Vector2(
			clampf(highlight.end.x, highlight_position.x, viewport_size.x),
			clampf(highlight.end.y, highlight_position.y, viewport_size.y)
		)
		highlight = Rect2(highlight_position, highlight_end - highlight_position)

	if highlight.size.x <= 0.0 or highlight.size.y <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0, 0, 0, 0.48))
		return

	var dim_color := Color(0, 0, 0, 0.48)
	draw_rect(Rect2(0, 0, viewport_size.x, highlight.position.y), dim_color)
	draw_rect(Rect2(0, highlight.end.y, viewport_size.x, viewport_size.y - highlight.end.y), dim_color)
	draw_rect(Rect2(0, highlight.position.y, highlight.position.x, highlight.size.y), dim_color)
	draw_rect(Rect2(highlight.end.x, highlight.position.y, viewport_size.x - highlight.end.x, highlight.size.y), dim_color)
	draw_rect(highlight, Color("#ef4444"), false, 3.0)
