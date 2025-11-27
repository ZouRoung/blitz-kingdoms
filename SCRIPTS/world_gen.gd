extends Node2D

@export_group("Map Settings")
@export var map_width : int = 100
@export var map_height : int = 100
@export var tile_size : int = 16

@export_group("Ground Grass Tiles")
## Atlas-Koordinaten für Boden-Untergrund (0,8 bis 9,8: grün → braun)
@export var grass_tiles : Array[Vector2i] = [
	Vector2i(0,8), Vector2i(1,8), Vector2i(2,8), Vector2i(3,8), Vector2i(4,8),
	Vector2i(5,8), Vector2i(6,8), Vector2i(7,8), Vector2i(8,8), Vector2i(9,8)
]
@export var grass_noise_frequency : float = 0.03
@export var grass_noise_octaves : int = 4

@export_group("Water Tiles")
## Atlas-Koordinaten für Wasser (0,11 bis 12,11)
@export var water_center : Vector2i = Vector2i(0,11)
@export var water_bottom_left : Vector2i = Vector2i(1,11)
@export var water_bottom_right : Vector2i = Vector2i(2,11)
@export var water_top_left : Vector2i = Vector2i(3,11)
@export var water_top_right : Vector2i = Vector2i(4,11)
@export var water_top : Vector2i = Vector2i(5,11)
@export var water_bottom : Vector2i = Vector2i(6,11)
@export var water_left : Vector2i = Vector2i(7,11)
@export var water_right : Vector2i = Vector2i(8,11)
@export var water_inner_top_left : Vector2i = Vector2i(9,11)
@export var water_inner_top_right : Vector2i = Vector2i(10,11)
@export var water_inner_bottom_left : Vector2i = Vector2i(11,11)
@export var water_inner_bottom_right : Vector2i = Vector2i(12,11)

@export_group("Water Settings")
@export var water_noise_frequency : float = 0.04
@export var water_threshold : float = 0.7
@export var min_water_cluster_size : int = 8

@export_group("Ground Details Tiles")
## Atlas-Koordinaten für Boden-Details (0,14 bis 9,14: dicht → locker)
@export var detail_tiles : Array[Vector2i] = [
	Vector2i(0,14), Vector2i(1,14), Vector2i(2,14), Vector2i(3,14), Vector2i(4,14),
	Vector2i(5,14), Vector2i(6,14), Vector2i(7,14), Vector2i(8,14), Vector2i(9,14)
]
@export var detail_noise_threshold : float = 0.0
@export var detail_cluster_frequency : float = 0.08

@export_group("Resource Tiles")
## Ressourcen: je 3 normale + 3 abgebaute Versionen
@export var tree_tiles : Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]
@export var stone_tiles : Array[Vector2i] = [Vector2i(6,0), Vector2i(7,0), Vector2i(8,0)]
@export var iron_tiles : Array[Vector2i] = [Vector2i(12,0), Vector2i(13,0), Vector2i(14,0)]
@export var gold_tiles : Array[Vector2i] = [Vector2i(18,0), Vector2i(19,0), Vector2i(20,0)]
@export var berry_tiles : Array[Vector2i] = [Vector2i(24,0), Vector2i(25,0), Vector2i(26,0)]

@export_group("Resource Spawn Chances")
## Globale Chance dass überhaupt eine Ressource spawnt
@export var resource_spawn_chance : float = 0.03
## Relative Wahrscheinlichkeiten (werden normalisiert)
@export var tree_weight : float = 40.0
@export var stone_weight : float = 15.0
@export var iron_weight : float = 5.0
@export var gold_weight : float = 1.0
@export var berry_weight : float = 10.0

@export_group("Forest Settings")
## Noise-basierte Wald-Regionen
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

func _ready():
	setup_noise()
	generate_world()

func setup_noise():
	## Boden-Untergrund Noise
	grass_noise.seed = randi()
	grass_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grass_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	grass_noise.fractal_octaves = grass_noise_octaves
	grass_noise.frequency = grass_noise_frequency
	
	## Wasser-Regionen Noise (Seen/Teiche)
	water_noise.seed = randi()
	water_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	water_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	water_noise.fractal_octaves = 3
	water_noise.frequency = water_noise_frequency
	
	## Details Noise
	detail_noise.seed = randi()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 3
	detail_noise.frequency = detail_cluster_frequency
	
	## Ressourcen-Verteilung Noise
	resource_noise.seed = randi()
	resource_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	resource_noise.frequency = 0.1
	
	## Wald-Regionen Noise
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
	
	## 1. Boden-Untergrund mit Biom-Variation
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			var grass_noise_val = grass_noise.get_noise_2d(x, y)
			var normalized_val = (grass_noise_val + 1.0) / 2.0
			var grass_index = int(normalized_val * grass_tiles.size())
			grass_index = clamp(grass_index, 0, grass_tiles.size() - 1)
			ground_tilemap.set_cell(cell, 0, grass_tiles[grass_index])
	
	## 2. Wasser-Regionen identifizieren
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			var water_val = water_noise.get_noise_2d(x, y)
			
			if water_val > water_threshold:
				water_cells[cell] = true
	
	## 3. Entferne kleine/isolierte Wasser-Cluster
	remove_small_water_clusters()
	
	## 4. Bereinige Wasser-Formen
	clean_water_shapes()
	
	## 5. Wasser-Tiles mit korrektem Autotiling
	apply_water_autotiling()
	
	## 6. Boden-Details (nicht auf Wasser)
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			
			if water_cells.has(cell):
				continue
			
			var detail_noise_val = detail_noise.get_noise_2d(x, y)
			if detail_noise_val > detail_noise_threshold:
				var detail_strength = (detail_noise_val - detail_noise_threshold) / (1.0 - detail_noise_threshold)
				detail_strength = clamp(detail_strength, 0.0, 1.0)
				var inverted_strength = 1.0 - detail_strength
				var detail_index = int(inverted_strength * detail_tiles.size())
				detail_index = clamp(detail_index, 0, detail_tiles.size() - 1)
				ground_details_tilemap.set_cell(cell, 0, detail_tiles[detail_index])
	
	## 7. Ressourcen (nicht auf Wasser)
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			
			if water_cells.has(cell) or placed_resources.has(cell):
				continue
			
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
		if visited.has(cell):
			continue
		
		var cluster = []
		var queue = [cell]
		
		while queue.size() > 0:
			var current = queue.pop_front()
			
			if visited.has(current):
				continue
			
			visited[current] = true
			cluster.append(current)
			
			var neighbors = [
				Vector2i(current.x + 1, current.y),
				Vector2i(current.x - 1, current.y),
				Vector2i(current.x, current.y + 1),
				Vector2i(current.x, current.y - 1)
			]
			
			for neighbor in neighbors:
				if water_cells.has(neighbor) and not visited.has(neighbor):
					queue.append(neighbor)
		
		clusters.append(cluster)
	
	for cluster in clusters:
		if cluster.size() < min_water_cluster_size:
			for cell in cluster:
				water_cells.erase(cell)

func clean_water_shapes():
	var max_iterations = 5
	var iteration = 0
	
	while iteration < max_iterations:
		var to_remove = []
		var changes_made = false
		
		for cell in water_cells.keys():
			var x = cell.x
			var y = cell.y
			
			var top = water_cells.has(Vector2i(x, y - 1))
			var bottom = water_cells.has(Vector2i(x, y + 1))
			var left = water_cells.has(Vector2i(x - 1, y))
			var right = water_cells.has(Vector2i(x + 1, y))
			
			var neighbor_count = 0
			if top: neighbor_count += 1
			if bottom: neighbor_count += 1
			if left: neighbor_count += 1
			if right: neighbor_count += 1
			
			## Entferne isolierte Tiles (0 oder 1 Nachbar)
			if neighbor_count <= 1:
				to_remove.append(cell)
				changes_made = true
				continue
			
			## Entferne schmale Kreuze
			var vertical_only = (top or bottom) and not left and not right
			var horizontal_only = (left or right) and not top and not bottom
			
			if vertical_only or horizontal_only:
				to_remove.append(cell)
				changes_made = true
				continue
		
		for cell in to_remove:
			water_cells.erase(cell)
		
		if not changes_made:
			break
		
		iteration += 1

func apply_water_autotiling():
	for cell in water_cells.keys():
		var x = cell.x
		var y = cell.y
		
		## Prüfe alle 8 Nachbarn
		var top = water_cells.has(Vector2i(x, y - 1))
		var bottom = water_cells.has(Vector2i(x, y + 1))
		var left = water_cells.has(Vector2i(x - 1, y))
		var right = water_cells.has(Vector2i(x + 1, y))
		var top_left = water_cells.has(Vector2i(x - 1, y - 1))
		var top_right = water_cells.has(Vector2i(x + 1, y - 1))
		var bottom_left = water_cells.has(Vector2i(x - 1, y + 1))
		var bottom_right = water_cells.has(Vector2i(x + 1, y + 1))
		
		var water_tile : Vector2i = water_center
		
		## PRIORITÄT 1: Außen-Ecken (Rand des Wassers, 2 benachbarte Seiten haben Wasser)
		if not top and not left and bottom and right:
			water_tile = water_top_left  ## Ecke oben-links
		elif not top and not right and bottom and left:
			water_tile = water_top_right  ## Ecke oben-rechts
		elif not bottom and not left and top and right:
			water_tile = water_bottom_left  ## Ecke unten-links
		elif not bottom and not right and top and left:
			water_tile = water_bottom_right  ## Ecke unten-rechts
		
		## PRIORITÄT 2: Einfache Kanten (1 angrenzende Seite)
		elif not top and bottom and not left and not right:
			water_tile = water_top  ## Kante oben
		elif not bottom and top and not left and not right:
			water_tile = water_bottom  ## Kante unten
		elif not left and right and not top and not bottom:
			water_tile = water_left  ## Kante links
		elif not right and left and not top and not bottom:
			water_tile = water_right  ## Kante rechts
		
		## PRIORITÄT 3: Inner-Ecken (alle 4 Seiten Wasser, aber Diagonale fehlt)
		elif top and bottom and left and right:
			## Alle 4 Seiten haben Wasser - prüfe Diagonalen für inner-Ecken
			if not top_left and top_right and bottom_left and bottom_right:
				water_tile = water_inner_top_left  ## Nur oben-links Diagonale fehlt
			elif not top_right and top_left and bottom_left and bottom_right:
				water_tile = water_inner_top_right  ## Nur oben-rechts Diagonale fehlt
			elif not bottom_left and top_left and top_right and bottom_right:
				water_tile = water_inner_bottom_left  ## Nur unten-links Diagonale fehlt
			elif not bottom_right and top_left and top_right and bottom_left:
				water_tile = water_inner_bottom_right  ## Nur unten-rechts Diagonale fehlt
			## Mehrere Diagonalen fehlen - wähle erste fehlende
			elif not top_left:
				water_tile = water_inner_top_left
			elif not top_right:
				water_tile = water_inner_top_right
			elif not bottom_left:
				water_tile = water_inner_bottom_left
			elif not bottom_right:
				water_tile = water_inner_bottom_right
			else:
				water_tile = water_center  ## Alle Diagonalen vorhanden
		
		## PRIORITÄT 4: T-Förmige Tiles (3 Seiten haben Wasser)
		elif top and left and right and not bottom:
			## T-Form nach unten offen
			if not top_left:
				water_tile = water_inner_top_left
			elif not top_right:
				water_tile = water_inner_top_right
			else:
				water_tile = water_bottom
		elif bottom and left and right and not top:
			## T-Form nach oben offen
			if not bottom_left:
				water_tile = water_inner_bottom_left
			elif not bottom_right:
				water_tile = water_inner_bottom_right
			else:
				water_tile = water_top
		elif top and bottom and left and not right:
			## T-Form nach rechts offen
			if not top_left:
				water_tile = water_inner_top_left
			elif not bottom_left:
				water_tile = water_inner_bottom_left
			else:
				water_tile = water_right
		elif top and bottom and right and not left:
			## T-Form nach links offen
			if not top_right:
				water_tile = water_inner_top_right
			elif not bottom_right:
				water_tile = water_inner_bottom_right
			else:
				water_tile = water_left
		
		## PRIORITÄT 5: Durchgänge (2 gegenüberliegende Seiten)
		elif top and bottom and not left and not right:
			water_tile = water_center  ## Vertikaler Durchgang
		elif left and right and not top and not bottom:
			water_tile = water_center  ## Horizontaler Durchgang
		
		## FALLBACK: Zentrum
		else:
			water_tile = water_center
		
		water_tilemap.set_cell(cell, 0, water_tile)

func place_random_resource(cell: Vector2i, placed_resources: Dictionary):
	var total_weight = tree_weight + stone_weight + iron_weight + gold_weight + berry_weight
	var rand_val = randf() * total_weight
	
	if rand_val < gold_weight:
		place_single_resource(cell, gold_tiles, placed_resources)
	elif rand_val < gold_weight + iron_weight:
		place_single_resource(cell, iron_tiles, placed_resources)
	elif rand_val < gold_weight + iron_weight + stone_weight:
		place_single_resource(cell, stone_tiles, placed_resources)
	elif rand_val < gold_weight + iron_weight + stone_weight + berry_weight:
		if randf() < berry_cluster_chance:
			place_berry_cluster(cell, placed_resources)
		else:
			place_single_resource(cell, berry_tiles, placed_resources)
	else:
		place_single_resource(cell, tree_tiles, placed_resources)

func place_single_resource(cell: Vector2i, tile_list: Array[Vector2i], placed_resources: Dictionary):
	var index = randi() % tile_list.size()
	resource_tilemap.set_cell(cell, 0, tile_list[index])
	placed_resources[cell] = true

func place_forest_tree(cell: Vector2i, forest_strength: float, placed_resources: Dictionary):
	var density = (forest_strength - forest_threshold) / (1.0 - forest_threshold)
	density = clamp(density, 0.0, 1.0)
	density = pow(density, 1.5)
	
	var tree_index : int
	if density < 0.3:
		tree_index = 0
	elif density < 0.65:
		tree_index = 1
	else:
		tree_index = 2
	
	resource_tilemap.set_cell(cell, 0, tree_tiles[tree_index])
	placed_resources[cell] = true

func place_berry_cluster(cell: Vector2i, placed_resources: Dictionary):
	for dx in range(-berry_cluster_size/2, berry_cluster_size/2 + 1):
		for dy in range(-berry_cluster_size/2, berry_cluster_size/2 + 1):
			if randf() < 0.5:
				var c = cell + Vector2i(dx, dy)
				if c.x >= 0 and c.x < map_width and c.y >= 0 and c.y < map_height:
					if not placed_resources.has(c) and not water_cells.has(c):
						place_single_resource(c, berry_tiles, placed_resources)
