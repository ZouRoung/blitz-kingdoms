extends Node2D
class_name ItemDrop

@export var pickup_radius : float = 20.0

## Speichert, was drin ist
var content : Dictionary = {}

@onready var anim_player = $ani
@onready var sprite = $Node/basic/Sprite2D

func _ready():
	$ani.play("drop")

func setup(resources: Dictionary, pos: Vector2):
	content = resources.duplicate()
	global_position = pos

func pick_up():
	queue_free()

func get_content() -> Dictionary:
	return content
