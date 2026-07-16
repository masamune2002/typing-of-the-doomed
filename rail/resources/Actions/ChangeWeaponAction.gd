extends EncounterAction
class_name ChangeWeaponAction

@export var weaponScene : PackedScene
@export_range(1, 100) var speed : float = 50.0

func run(_encounterPoint : EncounterPoint) -> void:
	var player = Game.getPlayer()
	if player == null or weaponScene == null:
		push_warning("ChangeWeaponAction: player or weaponScene is null")
		finish()
		return
	var duration = 0.3 * (50.0 / max(speed, 1.0))

	# Lower current weapon if one exists
	var hasOldWeapon = player._currentWeapon != null and is_instance_valid(player._currentWeapon)
	if hasOldWeapon:
		player._playerUi.lowerWeapon(duration)
		await player._playerUi.weaponLowered

	# Swap weapon node
	var newWeapon = weaponScene.instantiate()
	if hasOldWeapon:
		newWeapon.transform = player._currentWeapon.transform
		player._currentWeapon.queue_free()
	else:
		newWeapon.transform = Transform3D(Basis(), Vector3(0.124, -0.156, -0.185))
	player._cameraRig.add_child(newWeapon)
	player._currentWeapon = newWeapon
	player._currentWeaponScene = weaponScene

	# Add to inventory if not already owned
	player.addWeapon(weaponScene)

	# Load new sprites and raise
	player.updateAmmoUi()
	player._playerUi.loadWeaponSprites(newWeapon)
	player._playerUi.raiseWeapon(duration)
	await player._playerUi.weaponRaised
	finish()
