extends Node2D

@onready var btn = $unitBuildingSpawnBtn
@onready var label = $unitNameText

## Preload Textures
const WARRIOR_NORMAL = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Warrior/unitWarriorButton_normal.png")
const WARRIOR_HOVER = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Warrior/unitWarriorButton_hover.png")
const WARRIOR_PRESSED = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Warrior/unitWarriorButton_pressed.png")

const ARCHER_NORMAL = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Archer/unitArcherButton_normal.png")
const ARCHER_HOVER = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Archer/unitArcherButton_hover.png")
const ARCHER_PRESSED = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Archer/unitArcherButton_pressed.png")

var current_unit_type : String = ""

signal spawn_clicked(unit_type)

func _ready():
	if btn:
		btn.pressed.connect(_on_btn_pressed)

func update_button(unit_type: String):
	current_unit_type = unit_type
	label.text = unit_type
	
	if unit_type == "Warrior":
		btn.texture_normal = WARRIOR_NORMAL
		btn.texture_hover = WARRIOR_HOVER
		btn.texture_pressed = WARRIOR_PRESSED
	elif unit_type == "Archer":
		btn.texture_normal = ARCHER_NORMAL
		btn.texture_hover = ARCHER_HOVER
		btn.texture_pressed = ARCHER_PRESSED

func _on_btn_pressed():
	spawn_clicked.emit(current_unit_type)
