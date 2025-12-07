extends Control
class_name HealthBar

@export var maxHealth : int
@export var hitPointTexture : Texture2D
@export var hitPointSize : int

@onready var hitPointsContainer = $MarginContainer/HitPointsContainer

var currentHealth
var hitPointTextures : Array[CenterContainer] = []

func _ready() -> void:
	currentHealth = maxHealth
	custom_minimum_size = Vector2(hitPointSize * maxHealth + 20, hitPointSize + 10)

	for i : int in currentHealth:
		var centerContainer : CenterContainer = CenterContainer.new()
		var textureRect : TextureRect = TextureRect.new()
		textureRect.texture = hitPointTexture
		textureRect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		textureRect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		textureRect.custom_minimum_size = Vector2(hitPointSize, hitPointSize)
		textureRect.size = Vector2(hitPointSize, hitPointSize)
		hitPointTextures.append(centerContainer)
		centerContainer.add_child(textureRect)
		hitPointsContainer.add_child(centerContainer)

func removeHitPoints(damage : int) -> void:
	for i : int in damage:
		var textureContainer : CenterContainer = hitPointTextures.pop_back()
		if textureContainer != null:
			remove_child(textureContainer)
			textureContainer.queue_free()
