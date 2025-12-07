extends Control
class_name PlayerUI

@onready var dialogBox : DialogBox = $DialogBoxMarginContainer/DialogBox
@onready var youWinPanel : MarginContainer = $YouWinMarginContainer
@onready var gameOverPanel : MarginContainer = $GameOverMarginContainer
@onready var loadingContainer : MarginContainer = $LoadingMarginContainer
@onready var healthBar : HealthBar = $HealthMarginContainer/HealthBar

var _winning : bool = false
var _playerCharacter : PlayerCharacter
var _performedSetup : bool = false

func _ready() -> void:
	youWinPanel.hide()
	gameOverPanel.hide()
	loadingContainer.hide()
	dialogBox.hide()

func setup(playerCharacter : PlayerCharacter) -> void:
	_playerCharacter = playerCharacter
	_performedSetup = true

func _showLoading():
	loadingContainer.show()

func win() -> void:
	_winning = true
	youWinPanel.show()

func closeWin() -> void:
	youWinPanel.hide()
	_winning = false

func closeGameOver() -> void:
	gameOverPanel.hide()

func showDialog(dialog : Dialog) -> void:
	if !_performedSetup:
		return
	dialogBox.show()
	dialogBox.showDialog(dialog)
	if dialogBox.showingDialog:
		EventBus.wait.emit()

func receiveDamage(damagePoints : int) -> void:
	healthBar.removeHitPoints(damagePoints)

func closeDialogBox() -> void:
	dialogBox.hide()
	EventBus.stopWait.emit()

func showGameOver() -> void:
	gameOverPanel.show()
