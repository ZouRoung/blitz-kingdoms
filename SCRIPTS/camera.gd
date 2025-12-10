extends Camera2D

@export_group("Movement Settings")
@export var move_speed : float = 600.0
@export var edge_margin : int = 20
@export var edge_move_speed : float = 500.0

@export_group("Zoom Settings")
@export var zoom_speed : float = 0.1
@export var max_zoom : float = 9.0
@export var spawn_zoom : float = 6.0

@export_group("Map Boundaries")
@export var map_width : int = 200
@export var map_height : int = 200
@export var tile_size : int = 16

var viewport_size : Vector2
var min_zoom : float = 1.0

@onready var game_handler = get_node_or_null("/root/game/gameHandler")

func _ready():
	viewport_size = get_viewport_rect().size
	
	if game_handler == null:
		game_handler = get_tree().current_scene.find_child("gameHandler", true, false)
	
	calculate_min_zoom_and_init()

func _process(delta):
	handle_keyboard_movement(delta)
	handle_edge_scrolling(delta)
	apply_boundaries()

func _input(event):
	if event is InputEventMouseButton:
		handle_zoom(event)

func calculate_min_zoom_and_init():
	var map_width_px = map_width * tile_size
	var map_height_px = map_height * tile_size
	
	## Berechne benötigten Zoom, um graue Ränder zu vermeiden
	var zoom_x = viewport_size.x / float(map_width_px)
	var zoom_y = viewport_size.y / float(map_height_px)
	var required_zoom = max(zoom_x, zoom_y)
	
	## Min Zoom Limit setzen (mit 5% Puffer)
	min_zoom = max(required_zoom, 0.5) * 1.05
	
	## Start-Zoom wird später vom GameHandler überschrieben, falls ein Spawn existiert.
	## Hier setzen wir einen Standard-Fallback.
	var start_zoom = max(min_zoom, 2.0)
	zoom = Vector2(start_zoom, start_zoom)
	
	## Start-Position: Kartenmitte (Fallback)
	position = Vector2(map_width_px / 2.0, map_height_px / 2.0)
	
	apply_boundaries()

## NEU: Wird vom GameHandler aufgerufen, um zum Spawn zu springen
func focus_position_max_zoom(target_pos: Vector2):
	zoom = Vector2(spawn_zoom, spawn_zoom)
	position = target_pos
	apply_boundaries()

func handle_keyboard_movement(delta):
	var direction = Vector2.ZERO
	if Input.is_action_pressed("right"): direction.x += 1
	if Input.is_action_pressed("left"): direction.x -= 1
	if Input.is_action_pressed("down"): direction.y += 1
	if Input.is_action_pressed("up"): direction.y -= 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += direction * move_speed * delta

func handle_edge_scrolling(delta):
	if game_handler and game_handler.is_mouse_over_ui: return

	var mouse_pos = get_viewport().get_mouse_position()
	var direction = Vector2.ZERO
	var current_vp_size = get_viewport_rect().size

	if mouse_pos.x < edge_margin: direction.x -= 1
	elif mouse_pos.x > current_vp_size.x - edge_margin: direction.x += 1

	if mouse_pos.y < edge_margin: direction.y -= 1
	elif mouse_pos.y > current_vp_size.y - edge_margin: direction.y += 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += direction * edge_move_speed * delta

func handle_zoom(event):
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_in()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_out()

func zoom_in():
	var new_zoom = zoom + Vector2(zoom_speed, zoom_speed)
	zoom = new_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	apply_boundaries()

func zoom_out():
	var new_zoom = zoom - Vector2(zoom_speed, zoom_speed)
	zoom = new_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	apply_boundaries()

func apply_boundaries():
	var map_width_px = map_width * tile_size
	var map_height_px = map_height * tile_size
	var viewport_half = (get_viewport_rect().size / zoom) * 0.5
	
	var min_x = viewport_half.x
	var max_x = map_width_px - viewport_half.x
	var min_y = viewport_half.y
	var max_y = map_height_px - viewport_half.y
	
	if min_x > max_x: position.x = map_width_px / 2.0
	else: position.x = clamp(position.x, min_x, max_x)
		
	if min_y > max_y: position.y = map_height_px / 2.0
	else: position.y = clamp(position.y, min_y, max_y)
