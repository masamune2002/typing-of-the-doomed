extends Sprite3D

var _frames : Array[Texture2D] = []
var _frame_idx : int = 0
var _timer : float = 0.0
const FRAME_DURATION = 8.0 / 35.0

func setup(f): _frames = f

func _process(delta):
	if _frames.size() < 2: return
	_timer += delta
	if _timer >= FRAME_DURATION:
		_timer = 0.0
		_frame_idx = (_frame_idx + 1) % _frames.size()
		texture = _frames[_frame_idx]
