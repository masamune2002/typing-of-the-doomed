extends Weakness
class_name TypingWeakness

var targetTypedText : PackedStringArray
var _currentHitPointIndex : int

func setup(difficulty, custom_words: Array = []) -> void:
	weaknessType = Enums.WEAPON_FIRE_TYPE.TYPING
	var word: String
	if custom_words.size() > 0:
		word = custom_words.pick_random()
	else:
		word = WORDS.get_word(difficulty)
	targetTypedText = word.split()
	for _char in targetTypedText:
		var newHitPoint = TypingHitPoint.new()
		newHitPoint.setup(_char)
		hitPoints.append(newHitPoint)
	updateLabel()
	_currentHitPointIndex = 0
	_skipSpaces()

func receiveHit(payload : Variant) -> bool:
	if payload is not String && targetTypedText.size() != 0:
		return false
	var keyString : String = payload
	if _currentHitPointIndex < hitPoints.size() && hitPoints[_currentHitPointIndex].receiveHit(keyString):
		_currentHitPointIndex = _currentHitPointIndex + 1
		_skipSpaces()
		updateLabel()
		return true
	return false

## Spaces in multi-word phrases are never typed — they complete
## automatically as the surrounding letters land.
func _skipSpaces() -> void:
	while _currentHitPointIndex < hitPoints.size() \
			and hitPoints[_currentHitPointIndex].toString() == " ":
		hitPoints[_currentHitPointIndex].full = false
		_currentHitPointIndex += 1
