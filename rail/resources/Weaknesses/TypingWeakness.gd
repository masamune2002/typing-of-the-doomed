extends Weakness
class_name TypingWeakness

var targetTypedText : PackedStringArray
var _currentHitPointIndex : int

func setup(difficulty) -> void:
	weaknessType = Enums.WEAPON_FIRE_TYPE.TYPING
	targetTypedText = WORDS.WORD_LIST.pick_random().split()
	for _char in targetTypedText:
		var newHitPoint = TypingHitPoint.new()
		newHitPoint.setup(_char)
		hitPoints.append(newHitPoint)
	updateLabel()
	_currentHitPointIndex = 0

func receiveHit(payload : Variant) -> bool:
	if payload is not String && targetTypedText.size() != 0:
		return false
	var keyString : String = payload
	if _currentHitPointIndex < hitPoints.size() && hitPoints[_currentHitPointIndex].receiveHit(keyString):
		_currentHitPointIndex = _currentHitPointIndex + 1
		updateLabel()
		return true
	return false
