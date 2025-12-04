extends Control

@onready var unit_icon = $unit
@onready var amount_text = $unitAmountText 
@onready var progress_bar = $progressBar
@onready var cancel_btn = $cancelButton 
## NEU: Referenz auf den Timer Text
@onready var timer_label = $unitProgressTimer

const ICON_WARRIOR = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitSpawner/unitBuildingSpawner_Warrior.png")
const ICON_ARCHER = preload("res://ASSETS/SPRITES/UI/unitBuilding/unitSpawner/unitBuildingSpawner_Archer.png")

signal cancel_requested(index)

var my_index : int = -1

func _ready():
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel_pressed)

func setup(unit_type: String, amount: int, queue_index: int):
	my_index = queue_index
	
	if unit_type == "Warrior":
		unit_icon.texture = ICON_WARRIOR
	elif unit_type == "Archer":
		unit_icon.texture = ICON_ARCHER
		
	if amount_text:
		amount_text.text = str(amount)
	
	## Progressbar und Timer nur sichtbar, wenn es das aktive Item ist (Index 0)
	var is_active = (queue_index == 0)
	progress_bar.visible = is_active
	progress_bar.value = 0
	
	if timer_label:
		timer_label.visible = is_active
		timer_label.text = "" # Erstmal leer, wird gleich geupdated

func update_progress(value: float):
	progress_bar.value = value

func update_timer_display(time_left_sec: float):
	if not timer_label: return
	
	## Mathematik: Sekunden in Minuten und Rest-Sekunden umrechnen
	var minutes = floor(time_left_sec / 60)
	var seconds = floor(fmod(time_left_sec, 60))
	
	## Formatierung: %02d sorgt dafür, dass immer zwei Stellen angezeigt werden (z.B. 05 statt 5)
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_cancel_pressed():
	if my_index != -1:
		cancel_requested.emit(my_index)
