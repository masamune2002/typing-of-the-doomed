extends HitPoint
class_name TypingHitPoint

var stringToMatch : String = ""

func setup(text : String) -> void:
	stringToMatch = text

func receiveHit(payload : Variant) -> bool:
	if payload is not String:
		return false
	var keyString : String = payload
	if keyString.to_lower() == stringToMatch:
		full = false
		return true
	return false

func toString() -> String:
	return stringToMatch
