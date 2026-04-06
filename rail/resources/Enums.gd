extends Resource
class_name Enums

enum WEAPON_FIRE_TYPE {
	MIDI,
	TYPING,
	MOUSE,
	NONE
}

enum ENEMY_STATE {
	INACTIVE,
	IDLE,
	MOVING,
	ATTACKING,
	DYING,
	DEAD
}

enum ARMOR_TYPE {
	NONE,
	GREEN,  # absorbs 1/3 of damage
	BLUE    # absorbs 1/2 of damage
}
