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

# ---- Positional enemy voices (DOOM-style mixing) -----------------------
# Vanilla DOOM mixes at most 8 sfx channels, cuts off a mobj's previous
# sound when it starts a new one, and attenuates to silence at 1200 map
# units (S_CLIPPING_DIST ~= 37.5 world units at our scale). playSoundAt
# reproduces that: positional falloff + per-origin cutoff + a voice cap
# with oldest-first eviction. Use it for anything that happens AT a place
# (enemy barks, pain, attacks); keep playSound for UI/pickup feedback.
const ENEMY_VOICE_MAX := 8
const ENEMY_SOUND_MAX_DIST := 37.5
var _positionalVoices : Dictionary = {}  # origin instance id -> AudioStreamPlayer3D

func playSoundAt(soundName: String, origin: Node3D) -> void:
	if origin == null or !is_instance_valid(origin):
		playSound(soundName)
		return
	var stream = fetchSound(soundName)
	if stream == null:
		return
	for k in _positionalVoices.keys():
		var v = _positionalVoices[k]
		if v == null or !is_instance_valid(v):
			_positionalVoices.erase(k)
	var oid := origin.get_instance_id()
	if _positionalVoices.has(oid):
		var prev = _positionalVoices[oid]
		if prev != null and is_instance_valid(prev):
			prev.queue_free()
		_positionalVoices.erase(oid)
	while _positionalVoices.size() >= ENEMY_VOICE_MAX:
		var oldest_key = _positionalVoices.keys()[0]
		var oldest = _positionalVoices[oldest_key]
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()
		_positionalVoices.erase(oldest_key)
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.bus = "SFX"
	audio.max_distance = ENEMY_SOUND_MAX_DIST
	audio.unit_size = 8.0
	get_tree().root.add_child(audio)
	audio.global_position = origin.global_position + Vector3(0, 1.0, 0)
	audio.play()
	audio.finished.connect(audio.queue_free)
	_positionalVoices[oid] = audio
