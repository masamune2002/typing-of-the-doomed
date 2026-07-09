extends Node3D

# Replaces the WAD addon's levelChange.gd on exit nodes.
# Empty methods are required stubs — the WAD addon's trigger system calls them.

var yeilding = false
var overlappingBodies: Array[Node] = []
var walkOverBodies: Array = []
@export var triggerType: WADG.TTYPE
@export var secret: bool = false

func _ready():
	set_physics_process(false)

func bin(_body): pass
func bout(_body): pass
func walkOverTrigger(_body): pass

func bodyIn(body):
	if "interactPressed" in body and body.interactPressed:
		EventBus.levelExitReached.emit()

func activate():
	EventBus.levelExitReached.emit()
