extends Node3D
class_name Interactable

@onready var interactableLabel: Label3D = $InteractableLabel
var typedLabel: Label3D
var debugLabel: Label3D

var active: bool = false
var alive: bool = true
var visible_to_player: bool = false
var _prev_visible_to_player: bool = false

enum InteractableType { DOOR, LIFT, FLOOR, EXIT, OTHER }

var wadNode: Node3D
var weakness: TypingWeakness
var requiredKey: String = ""  # empty = no key needed
var set_variable: String = "" # game variable to set when activated
var interactable_name: String = "" # stable id used for signal-based gating (set by spawner)
var interactable_type: InteractableType = InteractableType.DOOR
var _door_was_open: bool = false # tracks door-open transition for doorOpened signal

func _ready() -> void:
	alive = true
	active = false
	add_to_group("Interactables")
	EventBus.startEncounter.connect(activate)

	weakness = TypingWeakness.new()
	weakness.setup(0)
	interactableLabel.hide()
	interactableLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interactableLabel.modulate = DoomGame.COLOR_GOLD
	typedLabel = interactableLabel

	debugLabel = Label3D.new()
	debugLabel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	debugLabel.no_depth_test = true
	debugLabel.render_priority = 10
	debugLabel.modulate = Color(0.5, 1.0, 0.5)
	debugLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debugLabel.position = interactableLabel.position + Vector3(0, -0.3, 0)
	var wad_name = wadNode.name if wadNode != null else name
	var sector_name = wadNode.get_parent().name if wadNode != null and wadNode.get_parent() != null else get_parent().name
	debugLabel.text = wad_name + " (" + sector_name + ")"
	add_child(debugLabel)
	debugLabel.hide()

	_setFullWordLabel()

func _applyDoomFont() -> void:
	var doomFont = Game.getDoomFont()
	if doomFont != null:
		for label in [interactableLabel, typedLabel, debugLabel]:
			if label != null:
				label.font = doomFont
				label.font_size = 16
				label.pixel_size = 0.02

func activate() -> void:
	active = true
	_applyDoomFont()
	if alive and visible_to_player:
		interactableLabel.show()

func deactivate() -> void:
	active = false
	interactableLabel.hide()

func receiveFire(weaponFireType: Enums.WEAPON_FIRE_TYPE, payload: Variant) -> bool:
	if !alive or !active or !visible_to_player:
		return false
	if weaponFireType != Enums.WEAPON_FIRE_TYPE.TYPING:
		return false
	var hit = weakness.receiveHit(payload)
	_updateTypedLabel()
	if hit and weakness.isHealthBarEmpty():
		_activate_wad_node()
	return hit

func _setFullWordLabel() -> void:
	var fullWord := ""
	for hp in weakness.hitPoints:
		fullWord += hp.toString()
	interactableLabel.text = fullWord.to_upper()

func _updateTypedLabel() -> void:
	var remaining := ""
	for hp in weakness.hitPoints:
		if hp.full:
			remaining += hp.toString()
	interactableLabel.text = remaining.to_upper()

func showRemainingLabel() -> void:
	_updateTypedLabel()

func showFullLabel() -> void:
	_setFullWordLabel()

func _var_prefix() -> String:
	match interactable_type:
		InteractableType.LIFT: return "lift_"
		InteractableType.FLOOR: return "floor_"
		InteractableType.EXIT: return "exit_"
		_: return "door_"

func _activate_wad_node() -> void:
	if set_variable != "":
		Game.setVar(set_variable)
	if interactable_name != "":
		# Lifts: the variable means "platform is at the bottom", so it is set
		# by _checkDoorOpenedSignal when the lift physically arrives, not here.
		if !_isLift():
			Game.setVar(_var_prefix() + interactable_name, true)
		EventBus.interactableActivated.emit(interactable_name)
	alive = false
	interactableLabel.hide()
	if typedLabel != null:
		typedLabel.hide()
	var player = Game.getPlayer()
	if player != null and player._currentFireTarget == self:
		EventBus.releasePlayerTarget.emit()
	if wadNode != null and is_instance_valid(wadNode):
		var ttype = wadNode.get(WadGame.PROP_TRIGGER_TYPE)
		var is_switch = ttype == WADG.TTYPE.SWITCH1 or ttype == WADG.TTYPE.SWITCHR
		if is_switch and wadNode.has_method("bodyIn") and player != null:
			# Switch-type triggers must use bodyIn for texture toggle
			player.interactPressed = true
			wadNode.bodyIn(player)
			player.interactPressed = false
		elif wadNode.has_method("activate"):
			wadNode.activate()
		elif wadNode.has_method("bodyIn") and player != null:
			player.interactPressed = true
			wadNode.bodyIn(player)
			player.interactPressed = false
	Game.playSound(DoomGame.DOOR_OPEN)

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	# If door has closed again, re-enable the interactable with the same word
	_checkDoorOpenedSignal()
	if !alive and active:
		if _isDoorClosed():
			_resetWeakness()

	# If door was opened externally (e.g. by a switch), hide this interactable
	if alive and active and _isDoorOpen():
		alive = false
		interactableLabel.hide()
		if debugLabel != null:
			debugLabel.hide()

	if !active or !alive:
		visible_to_player = false
		return
	if not _hasRequiredKey():
		visible_to_player = false
		interactableLabel.hide()
		return
	visible_to_player = _check_line_of_sight() and _is_on_screen()
	if visible_to_player:
		_setFullWordLabel()
		_updateTypedLabel()
		interactableLabel.show()
		if debugLabel != null:
			if SettingsManager.debug_show_thing_ids:
				_applyDoomFont()
				debugLabel.show()
			else:
				debugLabel.hide()
	else:
		interactableLabel.hide()
		if typedLabel != null:
			typedLabel.hide()
		if debugLabel != null:
			debugLabel.hide()

	if _prev_visible_to_player and not visible_to_player:
		var player : Player = Game.getPlayer()
		if player != null and player._currentFireTarget == self:
			EventBus.releasePlayerTarget.emit()
	_prev_visible_to_player = visible_to_player

func _checkDoorOpenedSignal() -> void:
	if interactable_name == "" or !_isMover():
		return
	var open := _isDoorOpen()
	if open and not _door_was_open:
		Game.setVar(_var_prefix() + interactable_name, true)
		EventBus.doorOpened.emit(interactable_name)
	elif not open and _door_was_open:
		Game.setVar(_var_prefix() + interactable_name, false)
	_door_was_open = open

func _needsThinWallCheck() -> bool:
	# Doors are positioned inside the door frame and switches are positioned
	# at the linedef midpoint (i.e. on the wall surface). In both cases the
	# raycast from the player will hit the wall the interactable sits on, so
	# use the thin-wall heuristic to see through it.
	if wadNode == null or !is_instance_valid(wadNode):
		return false
	var ttype = wadNode.get("triggerType")
	return ttype == WADG.TTYPE.DOOR or ttype == WADG.TTYPE.DOOR1 or ttype == WADG.TTYPE.SWITCH1 or ttype == WADG.TTYPE.SWITCHR

func _isMover() -> bool:
	# Only actual sector movers have a door-like state machine. Trigger
	# scripts (walkTrigger/floorTrigger/...) also expose `state`, but its
	# values mean something else - reading it as a door state makes a
	# closed door look open (e.g. E1M6 sector 37's WR trigger).
	if wadNode == null or !is_instance_valid(wadNode) or wadNode.get_script() == null:
		return false
	var sp: String = wadNode.get_script().resource_path
	return sp.ends_with("door.gd") or sp.ends_with(WadGame.SCRIPT_LIFT) \
		or sp.ends_with("floor.gd") or sp.ends_with("ceiling.gd") \
		or sp.ends_with("crusher.gd")

func _isLift() -> bool:
	return wadNode != null and wadNode.get_script() != null and wadNode.get_script().resource_path.ends_with(WadGame.SCRIPT_LIFT)

func _isFloor() -> bool:
	return wadNode != null and wadNode.get_script() != null and wadNode.get_script().resource_path.ends_with("floor.gd")

func _isDoorClosed() -> bool:
	if !_isMover():
		return false
	if _isLift():
		# Closed = resting at the TOP. Read the shared height, not the
		# per-trigger-line state enum (stale when another line ran the cycle).
		var lift_info = wadNode.get("info")
		if wadNode.has_method("getCurH") and lift_info is Dictionary \
				and lift_info.has("sectorInfo") and lift_info["sectorInfo"].has("floorHeight"):
			return wadNode.getCurH() >= lift_info["sectorInfo"]["floorHeight"] - 0.01
		return wadNode.get("state") == 0
	if _isFloor():
		# floor.gd: STATE.TOP = 0 (resting position = "closed"/ready)
		return wadNode.get("state") == 0
	# Doors: read the geometry, not the state enum. A closer node (WR "close
	# wait open") initializes its state to OPEN while the door is physically
	# shut, so state lies when a sector has both opener and closer nodes.
	var curH = wadNode.get("curH")
	var bottomH = wadNode.get("bottomH")
	if curH == null or bottomH == null:
		return wadNode.get("state") == 2
	return curH <= bottomH + 0.01

func _isDoorOpen() -> bool:
	if !_isMover():
		return false
	if _isLift():
		# A lift only counts as "open" while it rests at the BOTTOM. The rail
		# gate (L<sector>) must not release while the platform is still up,
		# lowering, or rising: a player dragged across a moving lift wedges on
		# the shaft lip. Read the shared height (parent meta via getCurH), not
		# the per-trigger-line state enum, which goes stale when another line
		# of the same sector ran the cycle.
		var lift_info = wadNode.get("info")
		if wadNode.has_method("getCurH") and lift_info is Dictionary and lift_info.has("endHeight"):
			return wadNode.getCurH() <= lift_info["endHeight"] + 0.01
		return wadNode.get("state") == 2
	if _isFloor():
		# A floor is "open" (route-passable) once it RESTS at the height it
		# moves to when activated: raise-floors (bridges, e.g. E1M4 sector 52)
		# at topH, lower-floors (e.g. E1M8 sector 10) at bottomH. The state
		# enum alone misreads a not-yet-raised bridge as open, because BOTTOM
		# is both a raiser's start and a lowerer's destination.
		if wadNode.has_method("getCurH"):
			var cur = wadNode.getCurH()
			var dir = wadNode.get("direction")
			if dir == WADG.DIR.UP:
				var top = wadNode.get("topH")
				if top != null:
					return cur >= top - 0.01
			elif dir == WADG.DIR.DOWN:
				var bottom = wadNode.get("bottomH")
				if bottom != null:
					return cur <= bottom + 0.01
		# floor.gd: STATE.GOING_DOWN = 1, STATE.BOTTOM = 2, STATE.GOING_UP = 3
		var state = wadNode.get("state")
		return state == 1 or state == 2 or state == 3
	# Doors: read the geometry, not the state enum (see _isDoorClosed).
	var curH = wadNode.get("curH")
	var bottomH = wadNode.get("bottomH")
	if curH == null or bottomH == null:
		var state = wadNode.get("state")
		return state == 0 or state == 3
	return curH > bottomH + 0.01

func _resetWeakness() -> void:
	alive = true
	weakness._currentHitPointIndex = 0
	for hitPoint in weakness.hitPoints:
		hitPoint.full = true
	weakness.updateLabel()
	_setFullWordLabel()
	if typedLabel != null:
		typedLabel.text = ""
		typedLabel.hide()

func _hasRequiredKey() -> bool:
	if requiredKey == "":
		return true
	var player = Game.getPlayer()
	if player == null:
		return false
	var wad_game = Game.getWadGame()
	var valid_keys = [requiredKey]
	if wad_game != null:
		valid_keys = wad_game.key_equivalents.get(requiredKey, [requiredKey])
	for key in valid_keys:
		if key in player._keys:
			return true
	return false

const MAX_INTERACT_DISTANCE: float = 20.0

func _is_on_screen() -> bool:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return false
	var world_pos = global_position + Vector3(0, 1.0, 0)
	if camera.is_position_behind(world_pos):
		return false
	var screen_pos = camera.unproject_position(world_pos)
	var viewport_size = get_viewport().get_visible_rect().size
	return screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y

func _check_line_of_sight() -> bool:
	var player = Game.getPlayer()
	if player == null:
		return false
	var distance = global_position.distance_to(player.global_position)
	if distance > MAX_INTERACT_DISTANCE:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var world_pos := global_position + Vector3(0, 1.0, 0)
	if camera.is_position_behind(world_pos):
		return false
	var screen_pos := camera.unproject_position(world_pos)
	var viewport_size := get_viewport().get_visible_rect().size
	if screen_pos.x < 0 or screen_pos.x > viewport_size.x or screen_pos.y < 0 or screen_pos.y > viewport_size.y:
		return false
	# Lifts are floor geometry — the player stands on them, so a wall raycast
	# doesn't apply. Distance + on-screen is sufficient.
	if _isLift():
		return true
	# Raycast to check for walls between player and interactable
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return false
	var from = player.global_position + Vector3(0, 0.85, 0)
	var to = global_position + Vector3(0, 1.0, 0)
	var pull = (from - to).normalized() * 0.3
	to += pull
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.exclude = [player.get_rid()]
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true
	if !_needsThinWallCheck():
		return false
	var reverse_query = PhysicsRayQueryParameters3D.create(to, from)
	reverse_query.collision_mask = 2
	var reverse_result = space_state.intersect_ray(reverse_query)
	if reverse_result.is_empty():
		return true
	var fwd_hit: Vector3 = result["position"]
	var rev_hit: Vector3 = reverse_result["position"]
	return fwd_hit.distance_to(rev_hit) < 0.5
