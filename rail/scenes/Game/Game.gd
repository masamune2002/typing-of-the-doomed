extends Node

var player: Player = null
var wadLoader: WadRuntimeLoader = null
var wadGame: WadGame = null
var _doomFont: Font = null
var _state_vars: Dictionary = {}

func setVar(key: String, value: Variant = true) -> void:
	_state_vars[key] = value

func getVar(key: String, default: Variant = null) -> Variant:
	return _state_vars.get(key, default)

func clearVars() -> void:
	_state_vars.clear()

func setPlayer(newPlayer: Player) -> void:
	player = newPlayer
	EventBus.playerChanged.emit(player)

func setWadLoader(loader: WadRuntimeLoader) -> void:
	wadLoader = loader

func getWadLoader() -> WadRuntimeLoader:
	return wadLoader

func setWadGame(game: WadGame) -> void:
	wadGame = game

func getWadGame() -> WadGame:
	return wadGame

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
	clearVars()
	var currentScene = get_tree().current_scene
	if currentScene and currentScene.has_method("restartCurrentMap"):
		currentScene.restartCurrentMap()
	elif currentScene:
		await RenderingServer.frame_post_draw
		get_tree().reload_current_scene()

func createTimer(seconds : float):
	return get_tree().create_timer(seconds)

func fetchFont(fontName: String) -> Font:
	if wadLoader == null or wadLoader._loader == null:
		return null
	var resource_manager = wadLoader._loader.get_node_or_null("ResourceManager")
	if resource_manager == null:
		return null
	if not resource_manager.has_method("fetchBitmapFont"):
		return null
	# The addon may crash if the WAD doesn't have the expected font graphics
	# so we guard against errors here
	var font = null
	if resource_manager.has_method("fetchDoomGraphic"):
		var test_tex = resource_manager.fetchDoomGraphic("STCFN065")
		if test_tex == null:
			return null
	font = resource_manager.fetchBitmapFont(fontName)
	return font

func getDoomFont() -> Font:
	if _doomFont != null:
		return _doomFont
	# Try the DOOM font name first, fall back gracefully if WAD doesn't have it
	for font_name in ["default-grayscale", "default"]:
		_doomFont = fetchFont(font_name)
		if _doomFont != null:
			return _doomFont
	return null

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
	audio.bus = "SFX"
	get_tree().root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
