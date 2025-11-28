extends Node2D

@export_group("Input Settings")
@export var selection_color : Color = Color.YELLOW

@export_group("Debug")
@export var warrior_scene : PackedScene
@export var spawn_container : Node2D

var selected_unit : CharacterBody2D = null
var hovering_unit : CharacterBody2D = null

@onready var world_gen : Node2D = get_parent().get_node("worldGen")

func _ready():
	if spawn_container == null:
		var parent = get_parent()
		if parent.has_node("Units"):
			spawn_container = parent.get_node("Units")

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			var mouse_pos = get_global_mouse_position()
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				handle_left_click(mouse_pos)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				handle_right_click(mouse_pos)
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			spawn_warrior_at_mouse()

func _process(delta: float):
	update_hover_detection()

func spawn_warrior_at_mouse():
	if warrior_scene == null:
		push_error("Warrior Scene nicht im Inspector gesetzt!")
		return
	
	if spawn_container == null:
		push_error("Spawn Container nicht gefunden!")
		return
	
	var new_warrior = warrior_scene.instantiate()
	new_warrior.global_position = get_global_mouse_position()
	spawn_container.add_child(new_warrior)
	
	print("Warrior gespawnt bei: ", new_warrior.global_position)

func update_hover_detection():
	var mouse_pos = get_global_mouse_position()
	var unit_under_mouse = get_unit_at_position(mouse_pos)
	
	if unit_under_mouse != hovering_unit:
		if hovering_unit != null and hovering_unit != selected_unit:
			unhighlight_unit(hovering_unit)
		
		hovering_unit = unit_under_mouse
		
		if hovering_unit != null and hovering_unit != selected_unit:
			highlight_unit(hovering_unit)

func get_unit_at_position(pos: Vector2) -> CharacterBody2D:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	
	var result = space_state.intersect_point(query, 1)
	
	if result.size() > 0:
		var collider = result[0].collider
		if collider is CharacterBody2D and collider.has_method("set_target"):
			return collider
	
	return null

func handle_left_click(mouse_pos: Vector2):
	var resource = world_gen.get_resource_at_position(mouse_pos)
	if resource != null:
		show_resource_info(resource)
		return
	
	var clicked_unit = get_unit_at_position(mouse_pos)
	
	if clicked_unit != null:
		select_unit(clicked_unit)
	else:
		deselect_unit()

func handle_right_click(mouse_pos: Vector2):
	if selected_unit != null:
		selected_unit.set_target(mouse_pos)

func select_unit(unit: CharacterBody2D):
	if selected_unit != null and selected_unit != unit:
		deselect_unit()
	
	selected_unit = unit
	highlight_selected_unit(unit)

func deselect_unit():
	if selected_unit != null:
		unhighlight_selected_unit(selected_unit)
	selected_unit = null
	hovering_unit = null

## Hover: Nur Farbe ändern
func highlight_unit(unit: CharacterBody2D):
	var sprite_container = unit.get_node("unit")
	if sprite_container:
		sprite_container.modulate = Color.WHITE.lerp(selection_color, 0.3)

## Hover entfernen
func unhighlight_unit(unit: CharacterBody2D):
	var sprite_container = unit.get_node("unit")
	if sprite_container:
		sprite_container.modulate = Color.WHITE

## Selected: Nur Farbe, KEINE Scale-Änderung!
func highlight_selected_unit(unit: CharacterBody2D):
	var sprite_container = unit.get_node("unit")
	if sprite_container:
		sprite_container.modulate = selection_color

## Selected entfernen: Nur Farbe zurücksetzen
func unhighlight_selected_unit(unit: CharacterBody2D):
	var sprite_container = unit.get_node("unit")
	if sprite_container:
		sprite_container.modulate = Color.WHITE

func show_resource_info(res_data: ResourceData):
	print("=== RESSOURCE INFO ===")
	print("Typ: ", res_data.resource_type.capitalize())
	print("Supply: ", res_data.current_supply, " / ", res_data.max_supply)
	print("Position: ", res_data.world_position)
	print("======================")
