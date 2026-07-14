extends EncounterAction
class_name TeleportPlayerAction

## Teleports the player to a WAD teleport destination (thing type 14)
## matched by sector tag — the same landing spot the WAD's own walk-over
## teleporter lines use. Scripted instead of riding the rail across the
## WR lines: a mid-ride teleport strands the rail follow point behind.

@export var destination_tag : int = 0
@export var sound : String = "DSTELEPT"

func run(encounterPoint : EncounterPoint) -> void:
	var player = Game.getPlayer()
	if player == null:
		finish()
		return
	var dests = encounterPoint.get_tree().get_nodes_in_group("destination:%d" % destination_tag)
	if dests.is_empty():
		push_warning("TeleportPlayerAction: no teleport destination with tag %d" % destination_tag)
		finish()
		return
	var dest := dests[0] as Node3D
	if player._moving:
		player.stopCameraMove(null)
	player.velocity = Vector3.ZERO
	player.global_position = dest.global_position + Vector3(0, 1.0, 0)
	var yaw : float = dest.global_rotation_degrees.y
	player._cameraRig.rotation_degrees.y = yaw
	player._rotH = yaw
	if sound != "":
		Game.playSound(sound)
	finish()
