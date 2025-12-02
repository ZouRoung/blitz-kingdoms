## res://SCRIPTS/unit_production_building.gd
extends Node2D
class_name UnitProductionBuilding

## Unit-Typ, den dieses Gebäude produziert (z.B. "Warrior" oder "Archer")
var unit_type : String = "Warrior"

## Produktions-Warteschlange
var production_queue : Array = []

## Produktionszeit pro Unit in Sekunden
var production_time : float = 5.0

## Timer-Variablen
var is_producing : bool = false
var current_production_time : float = 0.0

## Maximale Queue-Größe
const MAX_QUEUE_SIZE : int = 8

## Signals
signal queue_changed()
signal production_finished(unit_type, spawn_pos)

func _ready():
	print("UnitProductionBuilding erstellt - Typ: ", unit_type)

func _process(delta: float):
	if not is_producing:
		return
	
	current_production_time += delta
	
	if current_production_time >= production_time:
		finish_production()

func add_to_queue():
	if production_queue.size() >= MAX_QUEUE_SIZE:
		print("Warteschlange voll!")
		return
	
	production_queue.append(unit_type)
	queue_changed.emit()
	
	if not is_producing:
		start_production()

func start_production():
	if production_queue.size() == 0:
		is_producing = false
		return
	
	is_producing = true
	current_production_time = 0.0
	print("Starte Produktion: ", unit_type)

func finish_production():
	if production_queue.size() == 0:
		is_producing = false
		return
	
	var finished_type = production_queue.pop_front()
	print("Produktion abgeschlossen: ", finished_type)
	
	production_finished.emit(finished_type, global_position)
	queue_changed.emit()
	
	current_production_time = 0.0
	
	if production_queue.size() > 0:
		start_production()
	else:
		is_producing = false

func get_progress_percentage() -> float:
	if not is_producing or production_time == 0:
		return 0.0
	return (current_production_time / production_time) * 100.0
