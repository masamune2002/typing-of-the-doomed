extends Node

signal playerFireMidi(midiSwitch : Array[InputEventMIDI])
signal playerFireKey(key : String)
signal playerChanged(newPlayer : Player)
signal enemySpawned(enemy : Enemy)
signal enemyKilled(enemy : Enemy)
signal showText(text : Array[String])
signal wait()
signal stopWait()
signal restartLevel()
signal startEncounter()
signal changeFireType(newFireType : Enums.WEAPON_FIRE_TYPE)
signal releasePlayerTarget()
