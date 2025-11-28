extends Node2D

@export_group("Input Settings")
@export var selection_color : Color = Color.YELLOW
@export var selection_scale : float = 1.1

var selected_unit : CharacterBody2D = null
var hovering_unit : CharacterBody2D = null

## Für visuelle Rückmeldung beim Hovern
var original_modulate : Color

func _ready():
	## Input-Events abfangen
	pass

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			var mouse_pos = get_global_mouse_position()
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				handle_left_click(mouse_pos)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				handle_right_click(mouse_pos)

func _process(delta: float):
	update_hover_detection()

## Prüfe ob Maus über einer Unit ist
func update_hover_detection():
	var mouse_pos = get_global_mouse_position()
	var unit_under_mouse = get_unit_at_position(mouse_pos)
	
	## Hover-Status ändern
	if unit_under_mouse != hovering_unit:
		if hovering_unit != null:
			unhighlight_unit(hovering_unit)
		
		hovering_unit = unit_under_mouse
		
		if hovering_unit != null:
			highlight_unit(hovering_unit)

## Finde Unit unter Mausposition
func get_unit_at_position(pos: Vector2) -> CharacterBody2D:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	
	var result = space_state.intersect_point(query, 1)
	
	if result.size() > 0:
		var collider = result[0].collider
		## Prüfe ob es eine Unit (CharacterBody2D) ist
		if collider is CharacterBody2D and collider.has_method("set_target"):
			return collider
	
	return null

## Linksklick: Unit auswählen
func handle_left_click(mouse_pos: Vector2):
	var clicked_unit = get_unit_at_position(mouse_pos)
	
	if clicked_unit != null:
		select_unit(clicked_unit)
	else:
		deselect_unit()

## Rechtsklick: Befehl an ausgewählte Unit
func handle_right_click(mouse_pos: Vector2):
	if selected_unit != null:
		selected_unit.set_target(mouse_pos)

## Unit auswählen
func select_unit(unit: CharacterBody2D):
	## Alte Auswahl abmelden
	if selected_unit != null and selected_unit != unit:
		deselect_unit()
	
	selected_unit = unit
	highlight_selected_unit(unit)

## Unit abwählen
func deselect_unit():
	if selected_unit != null:
		unhighlight_selected_unit(selected_unit)
	selected_unit = null

## Unit hervorheben (Hover)
func highlight_unit(unit: CharacterBody2D):
	var sprite_container = unit.get_node("unit")
	if sprite_container:
		sprite_container.modulate = Color.WHITE.lerp(selection_color, 0.3)

## Unit Hover entfernen
func unhighlight_unit(unit: CharacterBody2D):
	var sprite_container = unit.get_node("unit")
	if sprite_container:
		sprite_container.modulate = Color.WHITE

## Unit auswählen hervorheben (intensiver)
func highlight_selected_unit(unit: CharacterBody2D):
	var sprite_container = unit.get_node("unit")
	if sprite_container:
		sprite_container.modulate = selection_color
		sprite_container.scale = Vector2.ONE * selection_scale

## Unit Auswahl Hervorhebung entfernen
func unhighlight_selected_unit(unit: CharacterBody2D):
	var sprite_container = unit.get_node("unit")
	if sprite_container:
		sprite_container.modulate = Color.WHITE
		sprite_container.scale = Vector2.ONE
