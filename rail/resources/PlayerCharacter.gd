extends Resource
class_name PlayerCharacter

@export var portrait : CompressedTexture2D
@export var name : String
@export var startingHealth : int = 100
@export var startingArmor : int = 0
@export var startingArmorType : Enums.ARMOR_TYPE = Enums.ARMOR_TYPE.NONE
@export var maxHealth : int = 200
@export var maxArmor : int = 200

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
