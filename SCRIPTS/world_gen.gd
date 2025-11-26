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
@export var forest_noise_frequency : float = 0.02
@export var forest_threshold : float = 0.6
@export var forest_density : float = 0.2
@export var min_forest_cluster : int = 2
@export var max_forest_cluster : int = 5

@export_group("Berry Bush Settings")
@export var berry_cluster_size : int = 3
@export var berry_cluster_chance : float = 0.7

var grass_noise := FastNoiseLite.new()
var resource_noise := FastNoiseLite.new()
var forest_noise := FastNoiseLite.new()

@onready var ground_tilemap : TileMapLayer = $groundTileMap
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
	resource_tilemap.clear()
	var placed_resources = {}
	
	## 1. Boden-Untergrund mit Biom-Variation
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			var grass_noise_val = grass_noise.get_noise_2d(x, y)
			## Konvertiere Noise (-1 bis 1) zu Index (0 bis 9)
			var normalized_val = (grass_noise_val + 1.0) / 2.0  ## 0.0 bis 1.0
			var grass_index = int(normalized_val * grass_tiles.size())
			grass_index = clamp(grass_index, 0, grass_tiles.size() - 1)
			ground_tilemap.set_cell(cell, 0, grass_tiles[grass_index])
	
	## 2. Ressourcen auf separatem Layer darüber
	for x in map_width:
		for y in map_height:
			var cell = Vector2i(x, y)
			
			## Skip wenn bereits durch Cluster platziert
			if placed_resources.has(cell):
				continue
			
			## Prüfe ob Wald-Region
			var forest_val = forest_noise.get_noise_2d(x, y)
			if forest_val > forest_threshold:
				if randf() < forest_density:
					place_forest_cluster(cell, placed_resources)
				continue
			
			## Normale Ressourcen-Platzierung
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
		place_single_resource(cell, tree_tiles, placed_resources)

func place_single_resource(cell: Vector2i, tile_list: Array[Vector2i], placed_resources: Dictionary):
	var index = randi() % tile_list.size()
	resource_tilemap.set_cell(cell, 0, tile_list[index])
	placed_resources[cell] = true

func place_forest_cluster(cell: Vector2i, placed_resources: Dictionary):
	var cluster_size = randi_range(min_forest_cluster, max_forest_cluster)
	for i in cluster_size:
		var offset = Vector2i(randi_range(-2, 2), randi_range(-2, 2))
		var c = cell + offset
		if c.x >= 0 and c.x < map_width and c.y >= 0 and c.y < map_height:
			if not placed_resources.has(c):
				place_single_resource(c, tree_tiles, placed_resources)

func place_berry_cluster(cell: Vector2i, placed_resources: Dictionary):
	for dx in range(-berry_cluster_size/2, berry_cluster_size/2 + 1):
		for dy in range(-berry_cluster_size/2, berry_cluster_size/2 + 1):
			if randf() < 0.5:
				var c = cell + Vector2i(dx, dy)
				if c.x >= 0 and c.x < map_width and c.y >= 0 and c.y < map_height:
					if not placed_resources.has(c):
						place_single_resource(c, berry_tiles, placed_resources)
