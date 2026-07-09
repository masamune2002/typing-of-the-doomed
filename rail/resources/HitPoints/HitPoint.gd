extends Resource
class_name HitPoint

var fireType : Enums.WEAPON_FIRE_TYPE
var full : bool = true

func match(_firePayload : Variant) -> bool:
	return true

func toString() -> String:
	return ""
