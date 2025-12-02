extends Control

@onready var unit_icon = $unit
@onready var queue_text = $unitQueueText
@onready var progress_bar = $progressBar

const ICON_WARRIOR = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitSpawner/unitBuildingSpawner_Warrior.png")
const ICON_ARCHER = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitSpawner/unitBuildingSpawner_Archer.png")

func setup(unit_type: String, queue_pos: int):
	if unit_type == "Warrior":
		unit_icon.texture = ICON_WARRIOR
	elif unit_type == "Archer":
		unit_icon.texture = ICON_ARCHER
		
	update_queue_position(queue_pos)
	
	## Progressbar nur sichtbar, wenn es das aktive Item ist (Position 1)
	progress_bar.visible = (queue_pos == 1)
	progress_bar.value = 0

func update_queue_position(number: int):
	queue_text.text = str(number)
	progress_bar.visible = (number == 1)

func update_progress(value: float):
	progress_bar.value = value
