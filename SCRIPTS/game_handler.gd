extends Node2D

@export_group("Input Settings")
@export var selection_color : Color = Color.YELLOW
@export var valid_build_color : Color = Color(0.2, 1.0, 0.2, 0.3)
@export var invalid_build_color : Color = Color(1.0, 0.2, 0.2, 0.3)

@export_group("Debug")
@export var warrior_scene : PackedScene
@export var spawn_container : Node2D

## --- UI REFERENCES ---
@onready var topbar = get_parent().get_node("ui/base/topbar")
@onready var timer_label = topbar.get_node("timer")
@onready var wood_counter = topbar.get_node("woodCounter")
@onready var stone_counter = topbar.get_node("stoneCounter")
@onready var iron_counter = topbar.get_node("ironCounter")
@onready var gold_counter = topbar.get_node("goldCounter")
@onready var food_counter = topbar.get_node("foodCounter")

@onready var bottom_menu_root = get_parent().get_node("ui/base/bottomMenu")
@onready var menu_container = bottom_menu_root.get_node("menu")
@onready var building_menu_container = bottom_menu_root.get_node("buildingMenu")
@onready var farm_menu_container = building_menu_container.get_node("farmMenu")
@onready var war_menu_container = building_menu_container.get_node("warMenu")

@onready var world_gen : Node2D = get_parent().get_node("worldGen")
@onready var building_tilemap : TileMapLayer = world_gen.get_node("buildingTileMap")

## --- WORLD TILEMAP REFERENCE ---
var world_tilemap : TileMapLayer = null

## --- GAME STATE ---
var selected_unit : CharacterBody2D = null
var hovering_unit : CharacterBody2D = null
var resources = { "wood": 0, "stone": 0, "iron": 0, "gold": 0, "food": 0 }

## --- TIME SYSTEM ---
var time_minutes : int = 0
var time_hours : int = 8 
var time_accumulator : float = 0.0
const REAL_SECONDS_PER_GAME_15MIN = 30.0

## --- BUILDING SYSTEM ---
var is_building_mode : bool = false
var current_building_type : int = -1 
var current_building_cost = { "wood": 0, "stone": 0, "iron": 0, "gold": 0 }
var last_preview_pos : Vector2i = Vector2i(-1, -1) 
var is_mouse_over_ui : bool = false 

const BUILDING_ARCHER = 1
const BUILDING_WARRIOR = 2
const BUILDING_LUMBERJACK = 3
const BUILDING_FARM = 4
const BUILDING_SIZE = Vector2i(1, 1) ## 1x1 im 32er Grid = 32x32 Pixel

func _ready():
	setup_ui_signals()
	connect_ui_mouse_detection(bottom_menu_root)
	update_resource_ui()
	update_time_ui()
	
	menu_container.visible = true
	building_menu_container.visible = false
	
	if spawn_container == null:
		var parent = get_parent()
		if parent.has_node("Units"):
			spawn_container = parent.get_node("Units")
	
	find_world_tilemap()

func find_world_tilemap():
	## Suche nach dem TileMap mit den Bodendaten (16x16)
	## In world_gen wird es als 'groundTileMap' referenziert (siehe export var)
	## oder als Child Node hinzugefügt.
	
	if world_gen.has_node("groundTileMap"):
		world_tilemap = world_gen.get_node("groundTileMap")
	elif world_gen.has_node("terrainTileMap"):
		world_tilemap = world_gen.get_node("terrainTileMap")
	else:
		## Fallback: Erstes TileMapLayer das NICHT building ist
		for child in world_gen.get_children():
			if child is TileMapLayer and child != building_tilemap:
				world_tilemap = child
				break
	
	if world_tilemap:
		print("World TileMap gefunden: ", world_tilemap.name)
	else:
		push_error("KEIN World TileMap gefunden! Building-Checks werden fehlschlagen.")

func connect_ui_mouse_detection(node: Node):
	if node is Control:
		node.mouse_entered.connect(func(): is_mouse_over_ui = true)
		node.mouse_exited.connect(func(): is_mouse_over_ui = false)
	
	for child in node.get_children():
		connect_ui_mouse_detection(child)

func setup_ui_signals():
	menu_container.get_node("buildMenuBtn").pressed.connect(on_build_menu_btn_pressed)
	building_menu_container.get_node("farmMenuBtn").pressed.connect(func(): switch_building_category("farm"))
	building_menu_container.get_node("warMenuBtn").pressed.connect(func(): switch_building_category("war"))
	building_menu_container.get_node("cancelMenuBtn").pressed.connect(on_cancel_menu_btn_pressed)
	farm_menu_container.get_node("farmBuildingBtn").pressed.connect(func(): start_building_mode(BUILDING_FARM, {}))
	farm_menu_container.get_node("lumberjackBuildingBtn").pressed.connect(func(): start_building_mode(BUILDING_LUMBERJACK, {}))
	war_menu_container.get_node("warBuildingBtn").pressed.connect(func(): start_building_mode(BUILDING_WARRIOR, {}))
	war_menu_container.get_node("archerBuildingBtn").pressed.connect(func(): start_building_mode(BUILDING_ARCHER, {}))

func _process(delta: float):
	update_hover_detection()
	process_time_system(delta)
	
	if is_building_mode:
		update_building_preview()
		queue_redraw()
	else:
		if last_preview_pos != Vector2i(-1, -1):
			last_preview_pos = Vector2i(-1, -1)
			queue_redraw()

func _draw():
	if is_building_mode and last_preview_pos != Vector2i(-1, -1) and not is_mouse_over_ui:
		var tile_size = building_tilemap.tile_set.tile_size
		var local_pos = building_tilemap.map_to_local(last_preview_pos)
		
		## Zentrierung korrigieren: map_to_local gibt die Mitte zurück
		var top_left = local_pos - Vector2(tile_size) * 0.5
		var rect_size = Vector2(tile_size) * Vector2(BUILDING_SIZE)
		
		## In Local-Space von game_handler konvertieren zum Zeichnen
		var global_top_left = building_tilemap.to_global(top_left)
		var my_local_top_left = to_local(global_top_left)
		
		var is_valid = is_buildable(last_preview_pos)
		var color = valid_build_color if is_valid else invalid_build_color
		draw_rect(Rect2(my_local_top_left, rect_size), color, true)

func start_building_mode(building_type: int, cost: Dictionary):
	if not has_resources(cost):
		print("Nicht genug Ressourcen!")
		return
		
	is_building_mode = true
	current_building_type = building_type
	current_building_cost = cost
	deselect_unit()

func cancel_building_mode():
	last_preview_pos = Vector2i(-1, -1)
	is_building_mode = false
	current_building_type = -1
	queue_redraw()

func is_buildable(building_grid_pos: Vector2i) -> bool:
	## 1. Check: Ist hier schon ein Gebäude? (im Building Grid 32x32)
	var source_id = building_tilemap.get_cell_source_id(building_grid_pos)
	if source_id != -1:
		return false
		
	## Umrechnung: Building Grid (32x32) -> World Grid (16x16)
	## Da 32 / 16 = 2, entspricht 1 Building Tile genau 2x2 World Tiles.
	## Die World-Grid Position ist also einfach Building-Grid * 2.
	var base_world_x = building_grid_pos.x * 2
	var base_world_y = building_grid_pos.y * 2
	
	## Wir prüfen jetzt den 2x2 Bereich im World-Grid (entspricht 1x1 im Building-Grid)
	for dx in range(2):
		for dy in range(2):
			var check_pos = Vector2i(base_world_x + dx, base_world_y + dy)
			
			## 2. Check: Wasser (gespeichert in world_gen dictionary)
			if world_gen.water_cells.has(check_pos):
				return false
			
			## 3. Check: Ressourcen (gespeichert in world_gen dictionary)
			if world_gen.resource_data_map.has(check_pos):
				return false
				
	return true

func update_building_preview():
	var mouse_pos = get_global_mouse_position()
	
	## Umwandlung Maus -> Building Grid (32x32)
	var local_mouse = building_tilemap.to_local(mouse_pos)
	var grid_pos = building_tilemap.local_to_map(local_mouse)
	
	if is_mouse_over_ui:
		last_preview_pos = Vector2i(-1, -1)
		return
	
	if grid_pos != last_preview_pos:
		last_preview_pos = grid_pos

func try_place_building(mouse_pos: Vector2):
	if is_mouse_over_ui:
		return

	var local_mouse = building_tilemap.to_local(mouse_pos)
	var cell_pos = building_tilemap.local_to_map(local_mouse)
	
	if not is_buildable(cell_pos):
		print("Hier kann nicht gebaut werden!")
		return
	
	if not has_resources(current_building_cost):
		print("Nicht genug Ressourcen!")
		return
	
	building_tilemap.set_cell(cell_pos, 0, Vector2i(current_building_type, 8))
	pay_resources(current_building_cost)
	
	last_preview_pos = Vector2i(-1, -1)

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			var mouse_pos = get_global_mouse_position()
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				if is_building_mode:
					try_place_building(mouse_pos)
				elif not is_mouse_over_ui:
					handle_left_click(mouse_pos)
					
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if is_building_mode:
					on_cancel_menu_btn_pressed() 
				else:
					handle_right_click(mouse_pos)
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			spawn_warrior_at_mouse()

func on_build_menu_btn_pressed():
	menu_container.visible = false
	building_menu_container.visible = true
	switch_building_category("farm") 

func on_cancel_menu_btn_pressed():
	cancel_building_mode()
	building_menu_container.visible = false
	menu_container.visible = true

func process_time_system(delta: float):
	time_accumulator += delta
	if time_accumulator >= REAL_SECONDS_PER_GAME_15MIN:
		time_accumulator -= REAL_SECONDS_PER_GAME_15MIN
		advance_time_15_min()

func advance_time_15_min():
	time_minutes += 15
	if time_minutes >= 60:
		time_minutes = 0
		time_hours += 1
		if time_hours >= 24:
			time_hours = 0
	update_time_ui()

func update_time_ui():
	var minute_str = str(time_minutes).pad_zeros(2)
	var hour_str = str(time_hours).pad_zeros(2)
	timer_label.text = hour_str + ":" + minute_str

func switch_building_category(category: String):
	farm_menu_container.visible = (category == "farm")
	war_menu_container.visible = (category == "war")

func add_resource(type: String, amount: int):
	if resources.has(type):
		resources[type] += amount
		update_resource_ui()

func has_resources(cost: Dictionary) -> bool:
	for type in cost:
		if resources.get(type, 0) < cost[type]:
			return false
	return true

func pay_resources(cost: Dictionary):
	for type in cost:
		resources[type] -= cost[type]
	update_resource_ui()

func update_resource_ui():
	wood_counter.text = str(resources["wood"])
	stone_counter.text = str(resources["stone"])
	iron_counter.text = str(resources["iron"])
	gold_counter.text = str(resources["gold"])
	food_counter.text = str(resources["food"])

func spawn_warrior_at_mouse():
	if warrior_scene == null: push_error("Warrior Scene fehlt!"); return
	if spawn_container == null: push_error("Spawn Container fehlt!"); return
	var new_warrior = warrior_scene.instantiate()
	new_warrior.global_position = get_global_mouse_position()
	spawn_container.add_child(new_warrior)

func update_hover_detection():
	if is_building_mode: return
	var mouse_pos = get_global_mouse_position()
	var unit_under_mouse = get_unit_at_position(mouse_pos)
	if unit_under_mouse != hovering_unit:
		if hovering_unit != null and hovering_unit != selected_unit: unhighlight_unit(hovering_unit)
		hovering_unit = unit_under_mouse
		if hovering_unit != null and hovering_unit != selected_unit: highlight_unit(hovering_unit)

func get_unit_at_position(pos: Vector2) -> CharacterBody2D:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	var result = space_state.intersect_point(query, 1)
	if result.size() > 0:
		var collider = result[0].collider
		if collider is CharacterBody2D and collider.has_method("set_target"): return collider
	return null

func handle_left_click(mouse_pos: Vector2):
	var resource = world_gen.get_resource_at_position(mouse_pos)
	if resource != null: show_resource_info(resource); return
	var clicked_unit = get_unit_at_position(mouse_pos)
	if clicked_unit != null: select_unit(clicked_unit)
	else: deselect_unit()

func handle_right_click(mouse_pos: Vector2):
	if selected_unit != null: selected_unit.set_target(mouse_pos)

func select_unit(unit: CharacterBody2D):
	if selected_unit != null and selected_unit != unit: deselect_unit()
	selected_unit = unit
	highlight_selected_unit(unit)

func deselect_unit():
	if selected_unit != null: unhighlight_selected_unit(selected_unit)
	selected_unit = null
	hovering_unit = null

func highlight_unit(unit: CharacterBody2D):
	var sprite = unit.get_node("unit")
	if sprite: sprite.modulate = Color.WHITE.lerp(selection_color, 0.3)

func unhighlight_unit(unit: CharacterBody2D):
	var sprite = unit.get_node("unit")
	if sprite: sprite.modulate = Color.WHITE

func highlight_selected_unit(unit: CharacterBody2D):
	var sprite = unit.get_node("unit")
	if sprite: sprite.modulate = selection_color

func unhighlight_selected_unit(unit: CharacterBody2D):
	var sprite = unit.get_node("unit")
	if sprite: sprite.modulate = Color.WHITE

func show_resource_info(res_data: ResourceData):
	print("Type:", res_data.resource_type, "Supply:", res_data.current_supply)
