extends Node2D

@onready var btn = $unitBuildingSpawnBtn
@onready var label = $unitNameText
## Achte auf die Schreibweise im Screenshot: "troopAmoutSlider" (ohne n)
@onready var slider = $troopAmoutSlider 
@onready var amount_text = $troopAmountText

## Preload Textures
const WARRIOR_NORMAL = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Warrior/unitWarriorButton_normal.png")
const WARRIOR_HOVER = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Warrior/unitWarriorButton_hover.png")
const WARRIOR_PRESSED = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Warrior/unitWarriorButton_pressed.png")

const ARCHER_NORMAL = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Archer/unitArcherButton_normal.png")
const ARCHER_HOVER = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Archer/unitArcherButton_hover.png")
const ARCHER_PRESSED = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitButtons/Archer/unitArcherButton_pressed.png")

var current_unit_type : String = ""
var current_amount : int = 10

## Signal sendet nun Typ UND Menge
signal spawn_clicked(unit_type, amount)

func _ready():
	if btn:
		btn.pressed.connect(_on_btn_pressed)
	
	if slider:
		## Slider Konfiguration (falls nicht im Editor gesetzt)
		slider.min_value = 10
		slider.max_value = 500
		slider.step = 10
		slider.value = 10
		slider.value_changed.connect(_on_slider_changed)
		
	update_amount_text()

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

func _on_slider_changed(value: float):
	current_amount = int(value)
	update_amount_text()

func update_amount_text():
	if amount_text:
		amount_text.text = str(current_amount)

func _on_btn_pressed():
	## Sende Typ und die ausgewählte Menge
	spawn_clicked.emit(current_unit_type, current_amount)
