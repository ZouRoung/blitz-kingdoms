extends Node2D

@export_group("Map Settings")
@export var map_width : int = 100
@export var map_height : int = 100
@export var tile_size : int = 16

@export_group("Ground Grass Tiles")
@export var grass_tiles : Array[Vector2i] = [
	Vector2i(0,8), Vector2i(1,8), Vector2i(2,8), Vector2i(3,8), Vector2i(4,8),
	Vector2i(5,8), Vector2i(6,8), Vector2i(7,8), Vector2i(8,8), Vector2i(9,8)
]
@export var grass_noise_frequency : float = 0.03
@export var grass_noise_octaves : int = 4

@export_group("Water Tiles")
## Atlas-Koordinaten für Wasser (0,11 bis 26,11)
@export var water_center : Vector2i = Vector2i(0,11)             # 0
@export var water_bottom_left : Vector2i = Vector2i(1,11)        # 1
@export var water_bottom_right : Vector2i = Vector2i(2,11)       # 2
@export var water_top_left : Vector2i = Vector2i(3,11)           # 3
@export var water_top_right : Vector2i = Vector2i(4,11)          # 4
@export var water_top : Vector2i = Vector2i(5,11)                # 5
@export var water_bottom : Vector2i = Vector2i(6,11)             # 6
@export var water_left : Vector2i = Vector2i(7,11)               # 7
@export var water_right : Vector2i = Vector2i(8,11)              # 8
@export var water_inner_top_left : Vector2i = Vector2i(9,11)     # 9
@export var water_inner_top_right : Vector2i = Vector2i(10,11)   # 10
@export var water_inner_bottom_left : Vector2i = Vector2i(11,11) # 11
@export var water_inner_bottom_right : Vector2i = Vector2i(12,11)# 12

## Diagonale Inner-Tiles (Wenn diagonal gegenüberliegende Ecken Land sind)
@export var water_inner_diagonal_tl_br : Vector2i = Vector2i(13,11) # 13 (Pixel Oben-Links & Unten-Rechts)

## Tiles für horizontale T-Verbindungen (Oben/Unten mit Ecke)
@export var water_top_with_bottom_left : Vector2i = Vector2i(14,11)  # 14
@export var water_top_with_bottom_right : Vector2i = Vector2i(15,11) # 15
@export var water_bottom_with_top_left : Vector2i = Vector2i(16,11)  # 16
@export var water_bottom_with_top_right : Vector2i = Vector2i(17,11) # 17

## Tiles für vertikale T-Verbindungen (Links/Rechts mit Ecke)
@export var water_left_with_top_right : Vector2i = Vector2i(18,11)   # 18
@export var water_left_with_bottom_right : Vector2i = Vector2i(19,11)# 19
@export var water_right_with_top_left : Vector2i = Vector2i(20,11)   # 20
@export var water_right_with_bottom_left : Vector2i = Vector2i(21,11)# 21

## Tiles für Ecken mit diagonalem Pixel
@export var water_bottom_left_with_top_right : Vector2i = Vector2i(22,11) # 22
@export var water_bottom_right_with_top_left : Vector2i = Vector2i(23,11) # 23
@export var water_top_left_with_bottom_right : Vector2i = Vector2i(24,11) # 24
@export var water_top_right_with_bottom_left : Vector2i = Vector2i(25,11) # 25

## NEU: Das zweite diagonale Tile
@export var water_inner_diagonal_tr_bl : Vector2i = Vector2i(26,11) # 26 (Pixel Oben-Rechts & Unten-Links)

@export_group("Water Settings")
@export var water_noise_frequency : float = 0.04
@export var water_threshold : float = 0.7
@export var min_water_cluster_size : int = 8

@export_group("Ground Details Tiles")
@export var detail_tiles : Array[Vector2i] = [
	Vector2i(0,14), Vector2i(1,14), Vector2i(2,14), Vector2i(3,14), Vector2i(4,14),
	Vector2i(5,14), Vector2i(6,14), Vector2i(7,14), Vector2i(8,14), Vector2i(9,14)
]
@export var detail_noise_threshold : float = 0.0
@export var detail_cluster_frequency : float = 0.08

@export_group("Resource Tiles")
@export var tree_tiles : Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]
@export var stone_tiles : Array[Vector2i] = [Vector2i(6,0), Vector2i(7,0), Vector2i(8,0)]
@export var iron_tiles : Array[Vector2i] = [Vector2i(12,0), Vector2i(13,0), Vector2i(14,0)]
@export var gold_tiles : Array[Vector2i] = [Vector2i(18,0), Vector2i(19,0), Vector2i(20,0)]
@export var berry_tiles : Array[Vector2i] = [Vector2i(24,0), Vector2i(25,0), Vector2i(26,0)]

@export_group("Resource Spawn Chances")
@export var resource_spawn_chance : float = 0.03
@export var tree_weight : float = 40.0
@export var stone_weight : float = 15.0
@export var iron_weight : float = 5.0
@export var gold_weight : float = 1.0
@export var berry_weight : float = 10.0

@export_group("Forest Settings")
@export var forest_noise_frequency : float = 0.03
@export var forest_threshold : float = 0.5
@export var forest_density : float = 0.85

@export_group("Berry Bush Settings")
@export var berry_cluster_size : int = 3
@export var berry_cluster_chance : float = 0.7

var grass_noise := FastNoiseLite.new()
var water_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var resource_noise := FastNoiseLite.new()
var forest_noise := FastNoiseLite.new()

var water_cells : Dictionary = {}

@onready var ground_tilemap : TileMapLayer = $groundTileMap
@onready var water_tilemap : TileMapLayer = $WaterTileMap
@onready var ground_details_tilemap : TileMapLayer = $groundDetailsTileMap
@onready var resource_tilemap : TileMapLayer = $resourceTileMap

var resource_data_map : Dictionary = {}

func _ready():
	setup_noise()
	generate_world()

func setup_noise():
	grass_noise.seed = randi()
	grass_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grass_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	grass_noise.fractal_octaves = grass_noise_octaves
	grass_noise.frequency = grass_noise_frequency
	
	water_noise.seed = randi()
	water_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	water_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	water_noise.fractal_octaves = 3
	water_noise.frequency = water_noise_frequency
	
	detail_noise.seed = randi()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 3
	detail_noise.frequency = detail_cluster_frequency
	
	resource_noise.seed = randi()
	resource_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	resource_noise.frequency = 0.1
	
	forest_noise.seed = randi()
	forest_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	forest_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	forest_noise.fractal_octaves = 3
	forest_noise.frequency = forest_noise_frequency

func generate_world():
	ground_tilemap.clear()
	water_tilemap.clear()
	ground_details_tilemap.clear()
	resource_tilemap.clear()
	water_cells.clear()
	var placed_resources = {}
	
	## 1. Boden
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			var grass_noise_val = grass_noise.get_noise_2d(x, y)
			var normalized_val = (grass_noise_val + 1.0) / 2.0
			var grass_index = int(normalized_val * grass_tiles.size())
			grass_index = clamp(grass_index, 0, grass_tiles.size() - 1)
			ground_tilemap.set_cell(cell, 0, grass_tiles[grass_index])
	
	## 2. Wasser Basis
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			var water_val = water_noise.get_noise_2d(x, y)
			if water_val > water_threshold:
				water_cells[cell] = true
	
	## 3. Wasser Bereinigung & Placement
	remove_small_water_clusters()
	clean_water_shapes()
	apply_water_autotiling()
	
	## 4. Details & Ressourcen
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			if water_cells.has(cell): continue
			
			var detail_noise_val = detail_noise.get_noise_2d(x, y)
			if detail_noise_val > detail_noise_threshold:
				var detail_strength = (detail_noise_val - detail_noise_threshold) / (1.0 - detail_noise_threshold)
				detail_strength = clamp(detail_strength, 0.0, 1.0)
				var inverted_strength = 1.0 - detail_strength
				var detail_index = int(inverted_strength * detail_tiles.size())
				detail_index = clamp(detail_index, 0, detail_tiles.size() - 1)
				ground_details_tilemap.set_cell(cell, 0, detail_tiles[detail_index])
	
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			if water_cells.has(cell) or placed_resources.has(cell): continue
			
			var forest_val = forest_noise.get_noise_2d(x, y)
			if forest_val > forest_threshold:
				if randf() < forest_density:
					place_forest_tree(cell, forest_val, placed_resources)
				continue
			
			if randf() < resource_spawn_chance:
				place_random_resource(cell, placed_resources)

func remove_small_water_clusters():
	var visited = {}
	var clusters = []
	for cell in water_cells.keys():
		if visited.has(cell): continue
		var cluster = []
		var queue = [cell]
		while queue.size() > 0:
			var current = queue.pop_front()
			if visited.has(current): continue
			visited[current] = true
			cluster.append(current)
			var neighbors = [Vector2i(current.x+1,current.y), Vector2i(current.x-1,current.y), Vector2i(current.x,current.y+1), Vector2i(current.x,current.y-1)]
			for n in neighbors:
				if water_cells.has(n) and not visited.has(n): queue.append(n)
		clusters.append(cluster)
	
	for cluster in clusters:
		if cluster.size() < min_water_cluster_size:
			for cell in cluster: water_cells.erase(cell)

func clean_water_shapes():
	var max_iterations = 8
	var iteration = 0
	while iteration < max_iterations:
		var to_remove = []
		var changes_made = false
		for cell in water_cells.keys():
			var top = water_cells.has(Vector2i(cell.x, cell.y - 1))
			var bottom = water_cells.has(Vector2i(cell.x, cell.y + 1))
			var left = water_cells.has(Vector2i(cell.x - 1, cell.y))
			var right = water_cells.has(Vector2i(cell.x + 1, cell.y))
			
			var n_count = 0
			if top: n_count += 1
			if bottom: n_count += 1
			if left: n_count += 1
			if right: n_count += 1
			
			if n_count <= 1:
				to_remove.append(cell); changes_made = true; continue
			
			if (top or bottom) and not left and not right:
				to_remove.append(cell); changes_made = true; continue
			if (left or right) and not top and not bottom:
				to_remove.append(cell); changes_made = true; continue
				
		for c in to_remove: water_cells.erase(c)
		if not changes_made: break
		iteration += 1

func apply_water_autotiling():
	for cell in water_cells.keys():
		var x = cell.x
		var y = cell.y
		
		# Kardinale Nachbarn
		var n_top = water_cells.has(Vector2i(x, y - 1))
		var n_bottom = water_cells.has(Vector2i(x, y + 1))
		var n_left = water_cells.has(Vector2i(x - 1, y))
		var n_right = water_cells.has(Vector2i(x + 1, y))
		
		# Diagonale Nachbarn (für Inner Corners / Einbuchtungen)
		var n_top_left = water_cells.has(Vector2i(x - 1, y - 1))
		var n_top_right = water_cells.has(Vector2i(x + 1, y - 1))
		var n_bottom_left = water_cells.has(Vector2i(x - 1, y + 1))
		var n_bottom_right = water_cells.has(Vector2i(x + 1, y + 1))
		
		var bitmask = 0
		if n_top: bitmask += 1
		if n_bottom: bitmask += 2
		if n_left: bitmask += 4
		if n_right: bitmask += 8
		
		var water_tile = water_center
		
		match bitmask:
			15: # 4 Nachbarn (Voll) -> Prüfe auf Land in den Ecken
				# 1. Priorität: Diagonale Crosses (S-Kurven)
				# 13: Land Oben-Links & Unten-Rechts
				if not n_top_left and not n_bottom_right:
					water_tile = water_inner_diagonal_tl_br
				# 26: Land Oben-Rechts & Unten-Links (NEU)
				elif not n_top_right and not n_bottom_left:
					water_tile = water_inner_diagonal_tr_bl
					
				# 2. Priorität: Einzelne Ecken
				elif not n_top_left: water_tile = water_inner_top_left # 9
				elif not n_top_right: water_tile = water_inner_top_right # 10
				elif not n_bottom_left: water_tile = water_inner_bottom_left # 11
				elif not n_bottom_right: water_tile = water_inner_bottom_right # 12
				
				# 3. Sonst: Volles Wasser
				else: water_tile = water_center # 0
			
			## T-Verbindungen (Diagonalen prüfen)
			
			14: # Top Missing (Visuell: OBERKANTE)
				if not n_bottom_left: water_tile = water_top_with_bottom_left    # 14
				elif not n_bottom_right: water_tile = water_top_with_bottom_right # 15
				else: water_tile = water_top # 5
				
			13: # Bottom Missing (Visuell: UNTERKANTE)
				if not n_top_left: water_tile = water_bottom_with_top_left      # 16
				elif not n_top_right: water_tile = water_bottom_with_top_right  # 17
				else: water_tile = water_bottom # 6
			
			11: # Right Missing (Visuell: LINKE KANTE)
				if not n_top_right: water_tile = water_left_with_top_right      # 18
				elif not n_bottom_right: water_tile = water_left_with_bottom_right # 19
				else: water_tile = water_left # 7
				
			7: # Left Missing (Visuell: RECHTE KANTE)
				if not n_top_left: water_tile = water_right_with_top_left       # 20
				elif not n_bottom_left: water_tile = water_right_with_bottom_left # 21
				else: water_tile = water_right # 8
				
			## Ecken (Diagonalen prüfen für Pixel-Variante)
			
			5: # Visuell: ECKE UNTEN-RECHTS (Wasser oben & links)
				if not n_top_left: water_tile = water_bottom_right_with_top_left # 23
				else: water_tile = water_bottom_right # 2 

			9: # Visuell: ECKE UNTEN-LINKS (Wasser oben & rechts)
				if not n_top_right: water_tile = water_bottom_left_with_top_right # 22
				else: water_tile = water_bottom_left # 1 

			6: # Visuell: ECKE OBEN-RECHTS (Wasser unten & links)
				if not n_bottom_left: water_tile = water_top_right_with_bottom_left # 25
				else: water_tile = water_top_right # 4 

			10: # Visuell: ECKE OBEN-LINKS (Wasser unten & rechts)
				if not n_bottom_right: water_tile = water_top_left_with_bottom_right # 24
				else: water_tile = water_top_left # 3 

			3: water_tile = water_center # Kanal Vertikal 
			12: water_tile = water_center # Kanal Horizontal
			
			1: water_tile = water_bottom # Endstück Oben
			2: water_tile = water_top # Endstück Unten
			4: water_tile = water_right # Endstück Links
			8: water_tile = water_left # Endstück Rechts
			
			0: water_tile = water_center # Einzeln
			
		water_tilemap.set_cell(cell, 0, water_tile)

func place_random_resource(cell: Vector2i, placed_resources: Dictionary):
	var total_weight = tree_weight + stone_weight + iron_weight + gold_weight + berry_weight
	var rand_val = randf() * total_weight
	if rand_val < gold_weight: place_single_resource(cell, gold_tiles, placed_resources)
	elif rand_val < gold_weight + iron_weight: place_single_resource(cell, iron_tiles, placed_resources)
	elif rand_val < gold_weight + iron_weight + stone_weight: place_single_resource(cell, stone_tiles, placed_resources)
	elif rand_val < gold_weight + iron_weight + stone_weight + berry_weight:
		if randf() < berry_cluster_chance: place_berry_cluster(cell, placed_resources)
		else: place_single_resource(cell, berry_tiles, placed_resources)
	else: place_single_resource(cell, tree_tiles, placed_resources)

func place_single_resource(cell: Vector2i, tile_list: Array[Vector2i], placed_resources: Dictionary):
	## ERST: Supply-Wert generieren
	var resource_type = get_resource_type_from_tiles(tile_list)
	var supply = get_resource_supply(resource_type)
	
	## DANN: Passenden Sprite-Index basierend auf Supply wählen
	var sprite_index = get_sprite_index_for_supply(supply)
	
	## Sprite setzen (tile_list[sprite_index] gibt das richtige Sprite zurück)
	var atlas_coord = tile_list[sprite_index]
	resource_tilemap.set_cell(cell, 0, atlas_coord)
	placed_resources[cell] = true
	
	## ResourceData erstellen mit dem generierten Supply
	var res_data = ResourceData.new()
	res_data.world_position = cell
	res_data.resource_type = resource_type
	res_data.max_supply = supply
	res_data.current_supply = supply
	
	resource_data_map[cell] = res_data

func place_forest_tree(cell: Vector2i, forest_strength: float, placed_resources: Dictionary):
	## Supply generieren
	var supply = get_resource_supply("tree")
	
	## Sprite-Index basierend auf Supply wählen
	var tree_index = get_sprite_index_for_supply(supply)
	
	## Sprite setzen
	resource_tilemap.set_cell(cell, 0, tree_tiles[tree_index])
	placed_resources[cell] = true
	
	## ResourceData mit generiertem Supply erstellen
	var res_data = ResourceData.new()
	res_data.world_position = cell
	res_data.resource_type = "tree"
	res_data.max_supply = supply
	res_data.current_supply = supply
	
	resource_data_map[cell] = res_data


func place_berry_cluster(cell: Vector2i, placed_resources: Dictionary):
	for dx in range(-berry_cluster_size/2, berry_cluster_size/2 + 1):
		for dy in range(-berry_cluster_size/2, berry_cluster_size/2 + 1):
			if randf() < 0.5:
				var c = cell + Vector2i(dx, dy)
				if c.x >= 0 and c.x < map_width and c.y >= 0 and c.y < map_height:
					if not placed_resources.has(c) and not water_cells.has(c):
						place_single_resource(c, berry_tiles, placed_resources)

func get_resource_supply(resource_type: String) -> int:
	## Mögliche Supply-Werte für alle Ressourcen
	var possible_values = [3000, 5000, 7500, 10000, 12500, 15000]
	
	## Wähle einen zufälligen Wert aus dem Array
	var random_index = randi() % possible_values.size()
	return possible_values[random_index]

func get_sprite_index_for_supply(supply: int) -> int:
	## Ab 10.000 Supply: 3 Bäume/Steine (Index 2)
	if supply >= 10000:
		return 2
	## Ab 5.000 Supply: 2 Bäume/Steine (Index 1)
	elif supply >= 5000:
		return 1
	## Unter 5.000 Supply: 1 Baum/Stein (Index 0)
	else:
		return 0


func get_resource_type_from_atlas(atlas_coord: Vector2i) -> String:
	if atlas_coord in tree_tiles: return "tree"
	if atlas_coord in stone_tiles: return "stone"
	if atlas_coord in iron_tiles: return "iron"
	if atlas_coord in gold_tiles: return "gold"
	if atlas_coord in berry_tiles: return "berry"
	return "unknown"

func get_resource_type_from_tiles(tile_list: Array[Vector2i]) -> String:
	## Prüfe, welche Liste übergeben wurde
	if tile_list == tree_tiles: return "tree"
	if tile_list == stone_tiles: return "stone"
	if tile_list == iron_tiles: return "iron"
	if tile_list == gold_tiles: return "gold"
	if tile_list == berry_tiles: return "berry"
	return "unknown"


func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			## Mausposition zu Tile-Koordinaten konvertieren
			var mouse_pos = get_global_mouse_position()
			var tile_pos = resource_tilemap.local_to_map(resource_tilemap.to_local(mouse_pos))
			
			## Prüfen, ob auf dieser Position eine Ressource existiert
			if resource_data_map.has(tile_pos):
				show_resource_info(resource_data_map[tile_pos])

func show_resource_info(res_data: ResourceData):
	print("=== RESSOURCE INFO ===")
	print("Typ: ", res_data.resource_type.capitalize())
	print("Supply: ", res_data.current_supply, " / ", res_data.max_supply)
	print("Position: ", res_data.world_position)
	print("======================")
