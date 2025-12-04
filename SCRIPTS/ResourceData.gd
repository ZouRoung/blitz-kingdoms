class_name ResourceData
extends Resource

## Typ der Ressource
@export var resource_type : String = ""

## Aktueller Supply-Wert
@export var current_supply : int = 0

## Maximaler Supply-Wert
@export var max_supply : int = 100

## Weltposition der Ressource
@export var world_position : Vector2i = Vector2i.ZERO

## NEU: Wer farmt hier gerade?
var current_farmer = null
