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
@export var forest_noise_frequency : float = 0.03  ## Niedrigere Frequenz = größere Wälder
@export var forest_threshold : float = 0.5  ## Höher = seltener Wälder
@export var forest_density : float = 0.85  ## Dichte innerhalb der Wälder

@export_group("Berry Bush Settings")
@export var berry_cluster_size : int = 3
@export var berry_cluster_chance : float = 0.7

var grass_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var resource_noise := FastNoiseLite.new()
var forest_noise := FastNoiseLite.new()

@onready var ground_tilemap : TileMapLayer = $groundTileMap
@onready var ground_details_tilemap : TileMapLayer = $groundDetailsTileMap
@onready var resource_tilemap : TileMapLayer = $resourceTileMap

func _ready():
	setup_noise()
	generate_world()

func setup_noise():
	## Boden-Untergrund Noise (für Biom-Variation kalt→warm)
	grass_noise.seed = randi()
	grass_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grass_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	grass_noise.fractal_octaves = grass_noise_octaves
	grass_noise.frequency = grass_noise_frequency
	
	## Details Noise (für Detail-Flächen mit Zentrum/Rand-Logik)
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
	ground_details_tilemap.clear()
	resource_tilemap.clear()
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
	
	## 2. Boden-Details mit Flächen-Logik (dicht innen, locker außen)
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			var detail_noise_val = detail_noise.get_noise_2d(x, y)
			
			if detail_noise_val > detail_noise_threshold:
				var detail_strength = (detail_noise_val - detail_noise_threshold) / (1.0 - detail_noise_threshold)
				detail_strength = clamp(detail_strength, 0.0, 1.0)
				var inverted_strength = 1.0 - detail_strength
				var detail_index = int(inverted_strength * detail_tiles.size())
				detail_index = clamp(detail_index, 0, detail_tiles.size() - 1)
				ground_details_tilemap.set_cell(cell, 0, detail_tiles[detail_index])
	
	## 3. Ressourcen auf separatem Layer darüber
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			
			if placed_resources.has(cell):
				continue
			
			## Prüfe ob Wald-Region
			var forest_val = forest_noise.get_noise_2d(x, y)
			if forest_val > forest_threshold:
				if randf() < forest_density:
					## Baum-Dichte basierend auf Wald-Noise-Stärke
					place_forest_tree(cell, forest_val, placed_resources)
				continue
			
			if randf() < resource_spawn_chance:
				place_random_resource(cell, placed_resources)

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
		## Einzelner Baum außerhalb von Wäldern (zufällige Dichte)
		place_single_resource(cell, tree_tiles, placed_resources)

func place_single_resource(cell: Vector2i, tile_list: Array[Vector2i], placed_resources: Dictionary):
	var index = randi() % tile_list.size()
	resource_tilemap.set_cell(cell, 0, tile_list[index])
	placed_resources[cell] = true

func place_forest_tree(cell: Vector2i, forest_strength: float, placed_resources: Dictionary):
	## Berechne Baum-Dichte basierend auf Wald-Noise-Stärke
	var density = (forest_strength - forest_threshold) / (1.0 - forest_threshold)
	density = clamp(density, 0.0, 1.0)
	
	## Verstärke die Dichte mit Power-Funktion für realistischere Verteilung
	## Je näher am Zentrum, desto schneller wird es dicht
	density = pow(density, 1.5)
	
	## Mappe auf Baum-Index mit besserer Verteilung
	var tree_index : int
	if density < 0.3:
		tree_index = 0  ## 0,0 = 1 Baum (nur am äußeren Rand)
	elif density < 0.65:
		tree_index = 1  ## 1,0 = 2 Bäume (Übergangszone)
	else:
		tree_index = 2  ## 2,0 = 3 Bäume (Zentrum und Großteil)
	
	resource_tilemap.set_cell(cell, 0, tree_tiles[tree_index])
	placed_resources[cell] = true

func place_berry_cluster(cell: Vector2i, placed_resources: Dictionary):
	for dx in range(-berry_cluster_size/2, berry_cluster_size/2 + 1):
		for dy in range(-berry_cluster_size/2, berry_cluster_size/2 + 1):
			if randf() < 0.5:
				var c = cell + Vector2i(dx, dy)
				if c.x >= 0 and c.x < map_width and c.y >= 0 and c.y < map_height:
					if not placed_resources.has(c):
						place_single_resource(c, berry_tiles, placed_resources)
