extends Resource
class_name Weakness

var weaknessType : Enums.WEAPON_FIRE_TYPE
var weaknessLabelText : String
var hitPoints : Array[HitPoint]

func setup(difficulty : int) -> void:
	pass

func receiveHit(payload : Variant) -> bool:
	return false

func getLabelText() -> String:
	return weaknessLabelText

func isHealthBarEmpty() -> bool:
	return hitPoints.all(func(hitPoint): return !hitPoint.full)

func getFirstFullHitPoint() -> HitPoint:
	for hitPoint in hitPoints:
		if hitPoint.full:
			return hitPoint
	return null

func updateLabel() -> void:
	var newLabelText : String = ""
	for hitPoint : HitPoint in hitPoints:
		if hitPoint.full:
			newLabelText = str(newLabelText, hitPoint.toString())
	weaknessLabelText = newLabelText
