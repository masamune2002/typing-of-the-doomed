extends EncounterCondition
class_name NearbyEnemiesClearedCondition

## Enemies within this distance of the player must be killed to proceed.
@export var max_distance: float = 20.0

func check(encounterPoint: EncounterPoint) -> bool:
	var player = Game.getPlayer()
	if player == null:
		return true

	var camera := player.get_viewport().get_camera_3d()
	if camera == null:
		return true

	for node in player.get_tree().get_nodes_in_group("Enemies"):
		if node is Enemy:
			var enemy: Enemy = node
			if enemy.alive and not enemy.dying:
				if enemy.global_position.distance_to(player.global_position) <= max_distance:
					if _is_on_screen(camera, enemy.global_position + Vector3(0, 1.0, 0)):
						return false
	return true

func _is_on_screen(camera: Camera3D, world_pos: Vector3) -> bool:
	if camera.is_position_behind(world_pos):
		return false
	var screen_pos := camera.unproject_position(world_pos)
	var viewport_size := camera.get_viewport().get_visible_rect().size
	return screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y
