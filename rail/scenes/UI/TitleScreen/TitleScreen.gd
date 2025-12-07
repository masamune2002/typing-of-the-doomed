extends Control

var firstLevelScene : PackedScene = preload("res://scenes/Maps/M_Entrance/M_Entrance.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _onExitButtonPressed() -> void:
	get_tree().quit()


func _onStartGameButtonPressed() -> void:
	get_tree().change_scene_to_packed(firstLevelScene)
