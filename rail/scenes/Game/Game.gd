extends Node

var player: Player = null
var wadLoader: WadRuntimeLoader = null
var _doomFont: Font = null

func setPlayer(newPlayer: Player) -> void:
	player = newPlayer
	EventBus.playerChanged.emit(player)

func setWadLoader(loader: WadRuntimeLoader) -> void:
	wadLoader = loader

func getWadLoader() -> WadRuntimeLoader:
	return wadLoader

func fetchSprite(spriteName: String) -> Texture2D:
	if wadLoader == null or wadLoader._loader == null:
		return null
	return wadLoader._loader.get_node("ResourceManager").fetchDoomGraphic(spriteName)

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

func fetchFont(fontName: String) -> Font:
	if wadLoader == null or wadLoader._loader == null:
		return null
	var resource_manager = wadLoader._loader.get_node_or_null("ResourceManager")
	if resource_manager == null:
		return null
	return resource_manager.fetchBitmapFont(fontName)

func getDoomFont() -> Font:
	if _doomFont != null:
		return _doomFont
	_doomFont = fetchFont("default-grayscale")
	return _doomFont

func fetchSound(soundName: String) -> AudioStream:
	if wadLoader == null or wadLoader._loader == null:
		return null
	var resource_manager = wadLoader._loader.get_node_or_null("ResourceManager")
	if resource_manager == null:
		return null
	return resource_manager.fetchSound(soundName)

func playSound(soundName: String) -> void:
	var stream = fetchSound(soundName)
	if stream == null:
		return
	var audio = AudioStreamPlayer.new()
	audio.stream = stream
	get_tree().root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
