## res://SCRIPTS/GAME/game_handler.gd
extends Node2D

@export_group("Input Settings")
@export var selection_color : Color = Color.YELLOW
@export var valid_build_color : Color = Color(0.2, 1.0, 0.2, 0.3)
@export var invalid_build_color : Color = Color(1.0, 0.2, 0.2, 0.3)

@export_group("Debug")
@export var warrior_scene : PackedScene
@export var archer_scene : PackedScene 
@export var spawn_item_scene : PackedScene 
@export var item_drop_scene : PackedScene ## WICHTIG: Hier item_drop.tscn zuweisen!
@export var spawn_container : Node2D

@export_group("Unit Assets")
@export var portrait_warrior : Texture2D 
@export var portrait_archer : Texture2D  

## --- UI REFERENCES (TOP BAR) ---
@onready var topbar = get_parent().get_node("ui/base/topbar")
@onready var timer_label = topbar.get_node("timer")
@onready var wood_counter = topbar.get_node("woodCounter")
@onready var stone_counter = topbar.get_node("stoneCounter")
@onready var iron_counter = topbar.get_node("ironCounter")
@onready var gold_counter = topbar.get_node("goldCounter")
@onready var food_counter = topbar.get_node("foodCounter")

## --- UI REFERENCES (BOTTOM MENUS) ---
@onready var bottom_menu_root = get_parent().get_node("ui/base/bottomMenu")
@onready var menu_container = bottom_menu_root.get_node("menu")
@onready var building_menu_container = bottom_menu_root.get_node("buildingMenu")
@onready var farm_menu_container = building_menu_container.get_node("farmMenu")
@onready var war_menu_container = building_menu_container.get_node("warMenu")
## Referenz auf den Zurück-Button im Building Menü
@onready var building_menu_cancel_btn = building_menu_container.get_node("cancelMenuBtn")

## --- UI REFERENCES (SELECTED UNIT MENU) ---
@onready var selected_unit_menu = bottom_menu_root.get_node("selectedUnitMenu")
@onready var unit_portrait = selected_unit_menu.get_node("unitPortrait")
@onready var unit_name_label = selected_unit_menu.get_node("unitName")
@onready var health_text = selected_unit_menu.get_node("healthText")
@onready var health_bar = selected_unit_menu.get_node("healthbar")
@onready var exp_text = selected_unit_menu.get_node("expText")
@onready var exp_bar = selected_unit_menu.get_node("expbar")
@onready var cancel_unit_menu_btn = selected_unit_menu.get_node("cancelSelectedUnitMenu")

## Inventar Labels & Buttons
@onready var inv_wood_label = selected_unit_menu.get_node("inv/woodCounter")
@onready var inv_stone_label = selected_unit_menu.get_node("inv/stoneCounter")
@onready var inv_iron_label = selected_unit_menu.get_node("inv/ironCounter")
@onready var inv_gold_label = selected_unit_menu.get_node("inv/goldCounter")
@onready var inv_food_label = selected_unit_menu.get_node("inv/foodCounter")

@onready var btn_drop_wood = selected_unit_menu.get_node("inv/buttonDrop_wood")
@onready var btn_drop_stone = selected_unit_menu.get_node("inv/buttonDrop_stone")
@onready var btn_drop_iron = selected_unit_menu.get_node("inv/buttonDrop_iron")
@onready var btn_drop_gold = selected_unit_menu.get_node("inv/buttonDrop_gold")
@onready var btn_drop_food = selected_unit_menu.get_node("inv/buttonDrop_food")

## --- UI REFERENCES (SELECTED RESOURCE MENU) ---
@onready var selected_resource_menu = bottom_menu_root.get_node("selectedResourceMenu")
@onready var res_portrait = selected_resource_menu.get_node("unitPortrait")
@onready var res_name_label = selected_resource_menu.get_node("resourceName")
@onready var res_health_text = selected_resource_menu.get_node("healthText")
@onready var res_health_value_label = selected_resource_menu.get_node("healthValue")
@onready var res_health_bar = selected_resource_menu.get_node("healthbar")
@onready var cancel_res_menu_btn = selected_resource_menu.get_node("cancelSelectedUnitMenu")

## --- UI REFERENCES (SELECTED BUILDING MENU) ---
@onready var selected_building_menu = bottom_menu_root.get_node("selectedUnitBuildingMenu")
@onready var building_spawn_btn_node = selected_building_menu.get_node("unitSpawnButton")
@onready var queue_first_slot = selected_building_menu.get_node("QueueFirstSlot")
@onready var queue_container = selected_building_menu.get_node("BoxContainerQueue/HBoxContainer")
@onready var cancel_building_menu_btn = selected_building_menu.get_node("cancelSelectedUnitBuildingMenu")

## --- WORLD REFERENCES ---
@onready var world_gen : Node2D = get_parent().get_node("worldGen")
@onready var building_tilemap : TileMapLayer = world_gen.get_node("buildingTileMap")
@onready var resource_tilemap : TileMapLayer = world_gen.get_node("resourceTileMap")
@onready var production_buildings_container : Node2D = get_parent().get_node("production_buildings")

var world_tilemap : TileMapLayer = null

## --- GAME STATE ---
var selected_unit : UnitBase = null
var hovering_unit : UnitBase = null
var selected_resource : ResourceData = null
var selected_building : UnitProductionBuilding = null 

var resources = { "wood": 1000, "stone": 1000, "iron": 1000, "gold": 1000, "food": 1000 }

## --- PLAYER TERRITORY ---
var my_base_grid_pos : Vector2i = Vector2i.ZERO
var allowed_build_rect : Rect2i

## --- TIME SYSTEM ---
var time_minutes : int = 0
var time_hours : int = 12 
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
const BUILDING_SIZE = Vector2i(1, 1)

## --- RESOURCE PORTRAITS ---
const RES_PORTRAIT_BERRY = preload("res://ASSETS/SPRITES/UI/selectedMenu/resource/resourcePotrait_berry.png")
const RES_PORTRAIT_GOLD = preload("res://ASSETS/SPRITES/UI/selectedMenu/resource/resourcePotrait_gold.png")
const RES_PORTRAIT_IRON = preload("res://ASSETS/SPRITES/UI/selectedMenu/resource/resourcePotrait_iron.png")
const RES_PORTRAIT_STONE = preload("res://ASSETS/SPRITES/UI/selectedMenu/resource/resourcePotrait_stone.png")
const RES_PORTRAIT_TREE = preload("res://ASSETS/SPRITES/UI/selectedMenu/resource/resourcePotrait_tree.png")

## --- KOSTEN & ZEIT VARIABLEN ---
@export_group("Production Costs (Base for 1 Unit)")
@export var warrior_cost_food : int = 1
@export var warrior_cost_iron : int = 1
@export var archer_cost_food : int = 1
@export var archer_cost_wood : int = 1

@export_group("Production Time (Seconds)")
@export var warrior_time_per_unit : float = 0.5 
@export var archer_time_per_unit : float = 0.4

func _ready():
	setup_ui_signals()
	connect_ui_mouse_detection(bottom_menu_root)
	update_resource_ui()
	update_time_ui()
	
	reset_all_menus()
	
	if spawn_container == null:
		var parent = get_parent()
		if parent.has_node("Units"):
			spawn_container = parent.get_node("Units")
	
	find_world_tilemap()
	await get_tree().process_frame
	init_player_spawn()

func find_world_tilemap():
	if world_gen.has_node("groundTileMap"):
		world_tilemap = world_gen.get_node("groundTileMap")
	elif world_gen.has_node("terrainTileMap"):
		world_tilemap = world_gen.get_node("terrainTileMap")
	else:
		for child in world_gen.get_children():
			if child is TileMapLayer and child != building_tilemap:
				world_tilemap = child
				break
	
	if world_gen.has_node("resourceTileMap"):
		resource_tilemap = world_gen.get_node("resourceTileMap")

func init_player_spawn():
	if world_gen.spawn_points.size() == 0:
		return
	
	var spawn_16px = world_gen.spawn_points.pick_random()
	my_base_grid_pos = spawn_16px / 2
	
	var rect_top_left = my_base_grid_pos - Vector2i(2, 2)
	var rect_size = Vector2i(5, 5) 
	allowed_build_rect = Rect2i(rect_top_left, rect_size)
	
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("focus_position_max_zoom"):
		var world_pos = building_tilemap.map_to_local(my_base_grid_pos)
		cam.focus_position_max_zoom(world_pos)

func connect_ui_mouse_detection(node: Node):
	if node is Control:
		if not node.mouse_entered.is_connected(_on_ui_mouse_entered):
			node.mouse_entered.connect(_on_ui_mouse_entered)
		if not node.mouse_exited.is_connected(_on_ui_mouse_exited):
			node.mouse_exited.connect(_on_ui_mouse_exited)
			
	for child in node.get_children():
		connect_ui_mouse_detection(child)

func _on_ui_mouse_entered():
	is_mouse_over_ui = true

func _on_ui_mouse_exited():
	is_mouse_over_ui = false

func setup_ui_signals():
	menu_container.get_node("buildMenuBtn").pressed.connect(on_build_menu_btn_pressed)
	building_menu_container.get_node("farmMenuBtn").pressed.connect(func(): switch_building_category("farm"))
	building_menu_container.get_node("warMenuBtn").pressed.connect(func(): switch_building_category("war"))
	building_menu_cancel_btn.pressed.connect(on_building_menu_close_pressed)
	
	farm_menu_container.get_node("farmBuildingBtn").pressed.connect(func(): start_building_mode(BUILDING_FARM, {}))
	farm_menu_container.get_node("lumberjackBuildingBtn").pressed.connect(func(): start_building_mode(BUILDING_LUMBERJACK, {}))
	war_menu_container.get_node("warBuildingBtn").pressed.connect(func(): start_building_mode(BUILDING_WARRIOR, {}))
	war_menu_container.get_node("archerBuildingBtn").pressed.connect(func(): start_building_mode(BUILDING_ARCHER, {}))
	
	cancel_unit_menu_btn.pressed.connect(deselect_unit)
	cancel_res_menu_btn.pressed.connect(deselect_resource)
	cancel_building_menu_btn.pressed.connect(deselect_building)
	
	if building_spawn_btn_node.has_signal("spawn_clicked"):
		building_spawn_btn_node.spawn_clicked.connect(on_unit_spawn_requested)
		
	## Drop Buttons verbinden
	btn_drop_wood.pressed.connect(func(): on_drop_btn_pressed("wood"))
	btn_drop_stone.pressed.connect(func(): on_drop_btn_pressed("stone"))
	btn_drop_iron.pressed.connect(func(): on_drop_btn_pressed("iron"))
	btn_drop_gold.pressed.connect(func(): on_drop_btn_pressed("gold"))
	btn_drop_food.pressed.connect(func(): on_drop_btn_pressed("food"))

func _process(delta: float):
	update_hover_detection()
	process_time_system(delta)
	
	if selected_building != null and selected_building.is_producing:
		update_building_queue_ui_progress_only()
	
	## Live Update für Resource UI während Farming
	if selected_resource != null and selected_resource_menu.visible:
		update_selected_resource_ui(selected_resource)
	
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
		var top_left = local_pos - Vector2(tile_size) * 0.5
		var rect_size = Vector2(tile_size) * Vector2(BUILDING_SIZE)
		var global_top_left = building_tilemap.to_global(top_left)
		var my_local_top_left = to_local(global_top_left)
		
		var is_valid = is_buildable(last_preview_pos)
		var color = valid_build_color if is_valid else invalid_build_color
		draw_rect(Rect2(my_local_top_left, rect_size), color, true)

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
				handle_right_click_input(mouse_pos)
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_X and selected_unit != null:
			selected_unit.add_xp(50)

func handle_right_click_input(mouse_pos: Vector2):
	## 1. Wenn Baumodus aktiv -> Abbrechen, aber Menü offen lassen
	if is_building_mode:
		cancel_building_mode()
		return
		
	## 2. Wenn irgendein Menü offen ist (aber KEIN Baumodus aktiv) -> Schließen
	if building_menu_container.visible or selected_building_menu.visible:
		on_building_menu_close_pressed()
		deselect_all()
		return
		
	## 3. Normaler Rechtsklick (Einheiten bewegen)
	handle_right_click(mouse_pos)

## --- CLICK & SELECTION ---

func handle_left_click(mouse_pos: Vector2):
	var clicked_unit = get_unit_at_position(mouse_pos)
	if clicked_unit != null:
		select_unit(clicked_unit)
		return
	
	var clicked_building = get_building_at_position(mouse_pos)
	if clicked_building != null:
		select_building(clicked_building)
		return
	
	var resource = world_gen.get_resource_at_position(mouse_pos)
	if resource != null:
		select_resource(resource)
		return
	
	if building_menu_container.visible:
		return
		
	deselect_all()

func deselect_all():
	deselect_unit()
	deselect_resource()
	deselect_building()
	building_menu_container.visible = false
	menu_container.visible = true

func reset_all_menus():
	menu_container.visible = true
	building_menu_container.visible = false
	selected_unit_menu.visible = false
	selected_resource_menu.visible = false
	selected_building_menu.visible = false

## --- UNIT SELECTION ---

func select_unit(unit: UnitBase):
	deselect_all()
	menu_container.visible = false
	selected_unit = unit
	highlight_selected_unit(unit)
	if not unit.stats_changed.is_connected(update_selected_unit_ui):
		unit.stats_changed.connect(update_selected_unit_ui)
	
	if not unit.inventory_changed.is_connected(update_unit_inventory_ui):
		unit.inventory_changed.connect(update_unit_inventory_ui)
	
	show_selected_unit_ui(unit)

func deselect_unit():
	if selected_unit != null:
		if selected_unit.stats_changed.is_connected(update_selected_unit_ui):
			selected_unit.stats_changed.disconnect(update_selected_unit_ui)
		
		if selected_unit.inventory_changed.is_connected(update_unit_inventory_ui):
			selected_unit.inventory_changed.disconnect(update_unit_inventory_ui)
			
		unhighlight_selected_unit(selected_unit)
		selected_unit = null
	hovering_unit = null
	selected_unit_menu.visible = false
	if !building_menu_container.visible:
		menu_container.visible = true

func show_selected_unit_ui(unit: UnitBase):
	selected_unit_menu.visible = true
	update_selected_unit_ui(unit)
	update_unit_inventory_ui(unit)

func update_selected_unit_ui(unit: UnitBase):
	unit_name_label.text = unit.unit_name + " " + str(unit.unit_amount)
	health_text.text = str(int(unit.current_health)) + " / " + str(int(unit.max_health))
	exp_text.text = str(unit.current_xp) + " / " + str(unit.xp_to_next_level)
	health_bar.max_value = unit.max_health
	health_bar.value = unit.current_health
	exp_bar.max_value = unit.xp_to_next_level
	exp_bar.value = unit.current_xp
	
	if unit.portrait_texture:
		unit_portrait.texture = unit.portrait_texture

func update_unit_inventory_ui(unit: UnitBase):
	inv_wood_label.text = str(unit.inventory.get("wood", 0))
	inv_stone_label.text = str(unit.inventory.get("stone", 0))
	inv_iron_label.text = str(unit.inventory.get("iron", 0))
	inv_gold_label.text = str(unit.inventory.get("gold", 0))
	inv_food_label.text = str(unit.inventory.get("food", 0))

func on_drop_btn_pressed(type: String):
	if selected_unit != null:
		selected_unit.drop_resource(type)

func spawn_item_drop(type: String, amount: int, pos: Vector2):
	if item_drop_scene == null:
		print("FEHLER: Item Drop Scene nicht zugewiesen!")
		return
		
	var drop = item_drop_scene.instantiate()
	drop.global_position = pos
	
	var content = {}
	content[type] = amount
	
	if drop.has_method("setup"):
		drop.setup(content, pos)
		
	if spawn_container:
		spawn_container.add_child(drop)
	else:
		get_parent().add_child(drop)

## --- RESOURCE SELECTION ---

func select_resource(res_data: ResourceData):
	deselect_all()
	menu_container.visible = false
	selected_resource = res_data
	show_selected_resource_ui(res_data)

func deselect_resource():
	selected_resource = null
	selected_resource_menu.visible = false
	if !building_menu_container.visible:
		menu_container.visible = true

func show_selected_resource_ui(res_data: ResourceData):
	selected_resource_menu.visible = true
	update_selected_resource_ui(res_data)
	
	var texture_to_load = null
	match res_data.resource_type:
		"tree": texture_to_load = RES_PORTRAIT_TREE
		"stone": texture_to_load = RES_PORTRAIT_STONE
		"iron": texture_to_load = RES_PORTRAIT_IRON
		"gold": texture_to_load = RES_PORTRAIT_GOLD
		"berry": texture_to_load = RES_PORTRAIT_BERRY
	if texture_to_load:
		res_portrait.texture = texture_to_load

func update_selected_resource_ui(res_data: ResourceData):
	res_name_label.text = res_data.resource_type.capitalize()
	res_health_bar.max_value = res_data.max_supply
	res_health_bar.value = res_data.current_supply
	res_health_value_label.text = str(res_data.current_supply) + "/" + str(res_data.max_supply)

## --- BUILDING SELECTION ---

func get_building_at_position(pos: Vector2) -> UnitProductionBuilding:
	if production_buildings_container == null: return null
	var min_dist = 24.0
	for building in production_buildings_container.get_children():
		if building is UnitProductionBuilding:
			if building.global_position.distance_to(pos) < min_dist:
				return building
	return null

func select_building(building: UnitProductionBuilding):
	deselect_all()
	menu_container.visible = false
	selected_building = building
	selected_building_menu.visible = true
	
	if building_spawn_btn_node.has_method("update_button"):
		building_spawn_btn_node.update_button(building.unit_type)
	
	if not building.queue_changed.is_connected(update_building_queue_ui):
		building.queue_changed.connect(update_building_queue_ui)
		
	update_building_queue_ui()

func deselect_building():
	if selected_building != null:
		if selected_building.queue_changed.is_connected(update_building_queue_ui):
			selected_building.queue_changed.disconnect(update_building_queue_ui)
		selected_building = null
	selected_building_menu.visible = false
	if !building_menu_container.visible:
		menu_container.visible = true

## --- BUILDING QUEUE & COSTS ---

func get_unit_cost(type: String, amount: int) -> Dictionary:
	var cost = {}
	if type == "Warrior":
		cost["food"] = warrior_cost_food * amount
		cost["iron"] = warrior_cost_iron * amount
	elif type == "Archer":
		cost["food"] = archer_cost_food * amount
		cost["wood"] = archer_cost_wood * amount
	return cost

func get_unit_production_time(type: String, amount: int) -> float:
	if type == "Warrior":
		return warrior_time_per_unit * amount
	elif type == "Archer":
		return archer_time_per_unit * amount
	return 1.0

func on_unit_spawn_requested(unit_type, amount):
	print("Spawn Anfrage: ", unit_type, " Menge: ", amount)
	
	if selected_building == null:
		return
		
	var cost = get_unit_cost(unit_type, amount)
	
	if not has_resources(cost):
		print("Nicht genug Ressourcen für ", amount, " ", unit_type)
		return
		
	var time_cost = get_unit_production_time(unit_type, amount)
	
	pay_resources(cost)
	selected_building.add_to_queue(unit_type, amount, time_cost)

func _on_queue_item_cancel_requested(index):
	if selected_building == null: return
	
	var removed_order = selected_building.remove_from_queue(index)
	
	if removed_order.is_empty():
		return
		
	var refund_cost = get_unit_cost(removed_order["type"], removed_order["amount"])
	
	for type in refund_cost:
		add_resource(type, refund_cost[type])
		
	print("Auftrag storniert. Refund: ", refund_cost)

func update_building_queue_ui():
	if selected_building == null: return
	
	for child in queue_first_slot.get_children(): child.queue_free()
	for child in queue_container.get_children(): child.queue_free()
	
	var queue = selected_building.production_queue
	
	for i in range(queue.size()):
		var order = queue[i]
		var u_type = order["type"]
		var u_amount = order["amount"]
		
		if spawn_item_scene:
			var item = spawn_item_scene.instantiate()
			
			if item.has_signal("cancel_requested"):
				item.cancel_requested.connect(_on_queue_item_cancel_requested)
			
			connect_ui_mouse_detection(item)
			
			if i == 0:
				queue_first_slot.add_child(item)
				if item.has_method("setup"):
					item.setup(u_type, u_amount, i) 
				if item.has_method("update_progress"):
					item.update_progress(selected_building.get_progress_percentage())
				if item.has_method("update_timer_display"):
					item.update_timer_display(selected_building.get_time_left())
					
			else:
				queue_container.add_child(item)
				if item.has_method("setup"):
					item.setup(u_type, u_amount, i) 
		else:
			print("FEHLER: spawn_item_scene im Inspector nicht zugewiesen!")

func update_building_queue_ui_progress_only():
	if queue_first_slot.get_child_count() > 0:
		var item = queue_first_slot.get_child(0)
		if item.has_method("update_progress"):
			item.update_progress(selected_building.get_progress_percentage())
		if item.has_method("update_timer_display"):
			item.update_timer_display(selected_building.get_time_left())

func on_production_finished(unit_type, amount, spawn_pos):
	spawn_unit(unit_type, amount, spawn_pos)

func spawn_unit(type, amount, pos):
	var new_unit = null
	if type == "Warrior" and warrior_scene:
		new_unit = warrior_scene.instantiate()
	elif type == "Archer" and archer_scene:
		new_unit = archer_scene.instantiate()
	else:
		print("FEHLER beim Spawnen: Unit Type '", type, "' unbekannt oder Scene fehlt!")
	
	if new_unit:
		new_unit.global_position = pos
		spawn_container.add_child(new_unit)
		
		new_unit.unit_name = type 
		
		if type == "Warrior":
			new_unit.portrait_texture = portrait_warrior
		elif type == "Archer":
			new_unit.portrait_texture = portrait_archer
		
		if new_unit.has_method("init_amount"):
			new_unit.init_amount(amount)
			
		## WICHTIG: Signale permanent verbinden!
		if not new_unit.arrived_at_base.is_connected(_on_unit_arrived_at_base):
			new_unit.arrived_at_base.connect(_on_unit_arrived_at_base)
		
		if not new_unit.arrived_at_pickup.is_connected(_on_unit_arrived_at_pickup):
			new_unit.arrived_at_pickup.connect(_on_unit_arrived_at_pickup)
			
		print("Unit gespawnt: ", type, " x", amount)

## --- BUILDING PLACEMENT ---

func start_building_mode(building_type: int, cost: Dictionary):
	if not has_resources(cost):
		print("Nicht genug Ressourcen!")
		return
	is_building_mode = true
	current_building_type = building_type
	current_building_cost = cost
	deselect_all()
	building_menu_container.visible = true
	menu_container.visible = false

func cancel_building_mode():
	last_preview_pos = Vector2i(-1, -1)
	is_building_mode = false
	current_building_type = -1
	queue_redraw()

func on_building_menu_close_pressed():
	cancel_building_mode()
	building_menu_container.visible = false
	selected_unit_menu.visible = false
	selected_resource_menu.visible = false
	selected_building_menu.visible = false
	menu_container.visible = true 

func is_buildable(building_grid_pos: Vector2i) -> bool:
	if not allowed_build_rect.has_point(building_grid_pos):
		return false
	if building_grid_pos == my_base_grid_pos:
		return false

	var base_world_x = building_grid_pos.x * 2
	var base_world_y = building_grid_pos.y * 2
	for dx in range(2):
		for dy in range(2):
			var check_pos = Vector2i(base_world_x + dx, base_world_y + dy)
			if world_gen.water_cells.has(check_pos): return false
			if world_gen.resource_data_map.has(check_pos): return false
	
	if building_tilemap.get_cell_source_id(building_grid_pos) != -1: return false
	return true

func update_building_preview():
	var mouse_pos = get_global_mouse_position()
	var local_mouse = building_tilemap.to_local(mouse_pos)
	var grid_pos = building_tilemap.local_to_map(local_mouse)
	if is_mouse_over_ui:
		last_preview_pos = Vector2i(-1, -1)
		return
	if grid_pos != last_preview_pos:
		last_preview_pos = grid_pos

func try_place_building(mouse_pos: Vector2):
	if is_mouse_over_ui: return
	var local_mouse = building_tilemap.to_local(mouse_pos)
	var cell_pos = building_tilemap.local_to_map(local_mouse)
	
	if not is_buildable(cell_pos): return
	if not has_resources(current_building_cost): return
	
	building_tilemap.set_cell(cell_pos, 0, Vector2i(current_building_type, 8))
	
	if current_building_type == BUILDING_WARRIOR or current_building_type == BUILDING_ARCHER:
		var building_script = load("res://SCRIPTS/unit_production_building.gd")
		var prod_building = building_script.new()
		
		prod_building.global_position = building_tilemap.map_to_local(cell_pos)
		
		if current_building_type == BUILDING_WARRIOR:
			prod_building.unit_type = "Warrior"
		elif current_building_type == BUILDING_ARCHER:
			prod_building.unit_type = "Archer"
		
		if production_buildings_container:
			production_buildings_container.add_child(prod_building)
			prod_building.production_finished.connect(on_production_finished)
			print("Building spawned & Connected: ", prod_building.unit_type)
	
	pay_resources(current_building_cost)
	last_preview_pos = Vector2i(-1, -1)

func on_build_menu_btn_pressed():
	menu_container.visible = false
	building_menu_container.visible = true
	selected_unit_menu.visible = false
	selected_resource_menu.visible = false
	switch_building_category("farm") 

func on_cancel_menu_btn_pressed():
	cancel_building_mode()

## --- HELPERS & MOVEMENT ---

func handle_right_click(mouse_pos: Vector2):
	if selected_unit != null:
		## 1. Item Drop?
		var drop = get_item_drop_at_position(mouse_pos)
		if drop != null:
			collect_item_drop(selected_unit, drop)
			return
			
		## 2. Ressource?
		var resource = world_gen.get_resource_at_position(mouse_pos)
		if resource != null:
			var target_pos = Vector2.ZERO
			if resource_tilemap:
				target_pos = resource_tilemap.to_global(resource_tilemap.map_to_local(resource.world_position))
			else:
				var x = (resource.world_position.x * 16) + 8
				var y = (resource.world_position.y * 16) + 8
				target_pos = Vector2(x, y)
				
			selected_unit.set_target(target_pos)
			selected_unit.set_farm_target(resource)
			return
			
		## 3. Basis?
		var local_mouse = building_tilemap.to_local(mouse_pos)
		var grid_pos_32 = building_tilemap.local_to_map(local_mouse)
		
		## FIX: Strenger Vergleich mit 0.1 (exakt draufklicken)
		if Vector2(grid_pos_32) == Vector2(my_base_grid_pos):
			return_resources_to_base(selected_unit)
			return
			
		## 4. Normal Move
		selected_unit.set_target(mouse_pos)

func get_unit_at_position(pos: Vector2) -> UnitBase:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	var result = space_state.intersect_point(query, 1)
	if result.size() > 0:
		var collider = result[0].collider
		if collider is UnitBase: return collider
	return null

func get_item_drop_at_position(pos: Vector2) -> Node2D:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	var result = space_state.intersect_point(query, 1)
	
	if result.size() > 0:
		var collider = result[0].collider
		if collider is ItemDrop or collider.has_method("pick_up"):
			return collider
			
	return null

func collect_item_drop(unit: UnitBase, drop: Node2D):
	unit.set_target(drop.global_position)
	unit.set_pickup_target(drop)

func _perform_pickup(unit: UnitBase, drop: Node2D):
	if drop == null: return
	var content = drop.get_content()
	for type in content:
		unit.add_resource_from_drop(type, content[type])
	drop.pick_up()

func _on_unit_arrived_at_pickup(unit: UnitBase, drop_item):
	if drop_item != null:
		_perform_pickup(unit, drop_item)

func return_resources_to_base(unit: UnitBase):
	var base_pos = building_tilemap.to_global(building_tilemap.map_to_local(my_base_grid_pos))
	unit.set_target(base_pos)
	unit.is_delivering_resources = true

func _on_unit_arrived_at_base(unit: UnitBase):
	var dropped = unit.clear_inventory()
	for type in dropped:
		add_resource(type, dropped[type])
	print("Resourcen abgeliefert: ", dropped)

func update_hover_detection():
	if is_building_mode: return
	var mouse_pos = get_global_mouse_position()
	var unit_under_mouse = get_unit_at_position(mouse_pos)
	if unit_under_mouse != hovering_unit:
		if hovering_unit != null and hovering_unit != selected_unit: unhighlight_unit(hovering_unit)
		hovering_unit = unit_under_mouse
		if hovering_unit != null and hovering_unit != selected_unit: highlight_unit(hovering_unit)

func highlight_unit(unit: UnitBase):
	var sprite = unit.get_node("unit")
	if sprite: sprite.modulate = Color.WHITE.lerp(selection_color, 0.3)

func unhighlight_unit(unit: UnitBase):
	var sprite = unit.get_node("unit")
	if sprite: sprite.modulate = Color.WHITE

func highlight_selected_unit(unit: UnitBase):
	var sprite = unit.get_node("unit")
	if sprite: sprite.modulate = selection_color

func unhighlight_selected_unit(unit: UnitBase):
	var sprite = unit.get_node("unit")
	if sprite: sprite.modulate = Color.WHITE

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
	new_warrior.init_amount(10) ## Debug-Spawn mit 10
	new_warrior.unit_name = "Warrior"
	new_warrior.portrait_texture = portrait_warrior
