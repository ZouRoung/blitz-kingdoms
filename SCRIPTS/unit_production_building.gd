## res://SCRIPTS/unit_production_building.gd
extends Node2D
class_name UnitProductionBuilding

var unit_type : String = "Warrior"
var production_queue : Array = []

var is_producing : bool = false
var current_production_time : float = 0.0
var current_target_time : float = 1.0 

const MAX_QUEUE_SIZE : int = 8

signal queue_changed()
signal production_finished(unit_type, amount, spawn_pos)

func _ready():
	print("UnitProductionBuilding erstellt - Typ: ", unit_type)

func _process(delta: float):
	if not is_producing:
		return
	
	current_production_time += delta
	
	if current_production_time >= current_target_time:
		finish_production()

func add_to_queue(u_type: String, amount: int, time_cost: float):
	if production_queue.size() >= MAX_QUEUE_SIZE:
		print("Warteschlange voll!")
		return
	
	var order = {
		"type": u_type,
		"amount": amount,
		"total_time": time_cost
	}
	
	production_queue.append(order)
	queue_changed.emit()
	
	if not is_producing:
		start_production()

## NEU: Entfernt Item an Index und gibt die Daten zurück (für Refund)
func remove_from_queue(index: int) -> Dictionary:
	if index < 0 or index >= production_queue.size():
		return {}
	
	var removed_order = production_queue.pop_at(index)
	
	## Wenn wir das Item löschen, das gerade produziert wird (Index 0 war)
	if index == 0:
		current_production_time = 0.0
		is_producing = false
		
		## Wenn noch was da ist, sofort mit dem nächsten starten
		if production_queue.size() > 0:
			start_production()
	
	queue_changed.emit()
	return removed_order

func start_production():
	if production_queue.size() == 0:
		is_producing = false
		return
	
	var current_order = production_queue[0]
	is_producing = true
	current_production_time = 0.0
	current_target_time = current_order["total_time"]
	
	print("Starte Produktion: ", current_order["type"])

func finish_production():
	if production_queue.size() == 0:
		is_producing = false
		return
	
	var finished_order = production_queue.pop_front()
	
	production_finished.emit(finished_order["type"], finished_order["amount"], global_position)
	queue_changed.emit()
	
	current_production_time = 0.0
	
	if production_queue.size() > 0:
		start_production()
	else:
		is_producing = false

func get_progress_percentage() -> float:
	if not is_producing or current_target_time == 0:
		return 0.0
	return (current_production_time / current_target_time) * 100.0
