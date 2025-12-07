extends Node

var player: Player = null

func setPlayer(newPlayer: Player) -> void:
	player = newPlayer
	EventBus.playerChanged.emit(player)

func getPlayer() -> Player:
	return player

func getPlayerPosition() -> Vector3:
	return player.position

func getWeaponFireType() -> Enums.WEAPON_FIRE_TYPE:
	if player == null:
		return Enums.WEAPON_FIRE_TYPE.TYPING
	return player.getCurrentFireType()

func restartLevel():
	var currentScene = get_tree().current_scene
	if currentScene:
		await RenderingServer.frame_post_draw # Wait one frame
		get_tree().reload_current_scene()

func createTimer(seconds : float):
	return get_tree().create_timer(seconds)
