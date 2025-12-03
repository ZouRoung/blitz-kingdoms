extends Control

@onready var unit_icon = $unit
@onready var amount_text = $unitAmountText 
@onready var progress_bar = $progressBar
@onready var cancel_btn = $cancelButton ## Referenz auf deinen Button im Screenshot

const ICON_WARRIOR = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitSpawner/unitBuildingSpawner_Warrior.png")
const ICON_ARCHER = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitSpawner/unitBuildingSpawner_Archer.png")

## Signal, wenn gelöscht werden soll (sendet den Index mit)
signal cancel_requested(index)

var my_index : int = -1

func _ready():
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel_pressed)

## Setup erhält nun auch den Index (queue_index)
func setup(unit_type: String, amount: int, queue_index: int):
	my_index = queue_index
	
	if unit_type == "Warrior":
		unit_icon.texture = ICON_WARRIOR
	elif unit_type == "Archer":
		unit_icon.texture = ICON_ARCHER
		
	if amount_text:
		amount_text.text = str(amount)
	
	## Progressbar nur sichtbar, wenn es das aktive Item ist (Index 0)
	progress_bar.visible = (queue_index == 0)
	progress_bar.value = 0

func update_progress(value: float):
	progress_bar.value = value

func _on_cancel_pressed():
	if my_index != -1:
		cancel_requested.emit(my_index)
