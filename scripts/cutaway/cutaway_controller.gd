extends Node
class_name CutawayController
## Pack §4 — toggle hides ONLY FrontWall; Interior stays visible.

@export var cutaway_enabled: bool = true

@onready var front_wall: Node2D = $"../FrontWall"
@onready var interior: Node2D = $"../Interior"

func _ready() -> void:
	apply_cutaway()

func apply_cutaway() -> void:
	if interior:
		interior.visible = true
	if front_wall:
		front_wall.visible = not cutaway_enabled
	print("CutawayController cutaway_enabled=", cutaway_enabled,
		" front_wall.visible=", front_wall.visible if front_wall else null)

func toggle_cutaway() -> void:
	cutaway_enabled = not cutaway_enabled
	apply_cutaway()

func set_cutaway(enabled: bool) -> void:
	cutaway_enabled = enabled
	apply_cutaway()
