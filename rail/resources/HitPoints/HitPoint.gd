extends Resource
class_name HitPoint

var fireType : Enums.WEAPON_FIRE_TYPE
var full : bool = true

func match(firePayload : Variant) -> bool:
	return true

func toString() -> String:
	return ""
