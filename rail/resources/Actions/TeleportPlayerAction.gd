extends EncounterAction
class_name TeleportPlayerAction

## Teleports the player to a WAD teleport destination (thing type 14)
## matched by sector tag — the same landing spot the WAD's own walk-over
## teleporter lines use. Scripted instead of riding the rail across the
## WR lines: a mid-ride teleport strands the rail follow point behind.

@export var destination_tag : int = 0
## Fallback landing spot (e.g. a RailMarker) — geometry_only WAD loading
## never spawns the WAD's teleport destination things.
@export var fallback_marker : NodePath
@export var sound : String = "DSTELEPT"

func run(encounterPoint : EncounterPoint) -> void:
	var player = Game.getPlayer()
	if player == null:
		finish()
		return
	var dest : Node3D = null
	var dests = encounterPoint.get_tree().get_nodes_in_group("destination:%d" % destination_tag)
	if not dests.is_empty():
		dest = dests[0] as Node3D
	elif fallback_marker != NodePath():
		dest = encounterPoint.get_node_or_null(fallback_marker) as Node3D
	if dest == null:
		push_warning("TeleportPlayerAction: no teleport destination with tag %d" % destination_tag)
		finish()
		return
	if player._moving:
		player.stopCameraMove(null)
	# Vanilla spawns the teleport fog at both ends of the trip
	TeleportFog.spawnAt(encounterPoint.get_tree(), player.global_position - Vector3(0, 1.0, 0))
	player.velocity = Vector3.ZERO
	player.global_position = dest.global_position + Vector3(0, 1.0, 0)
	var yaw : float = dest.global_rotation_degrees.y
	player._cameraRig.rotation_degrees.y = yaw
	player._rotH = yaw
	TeleportFog.spawnAt(encounterPoint.get_tree(), dest.global_position)
	if sound != "":
		Game.playSound(sound)
	finish()
