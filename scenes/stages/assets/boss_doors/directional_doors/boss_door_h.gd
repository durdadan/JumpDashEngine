extends "boss_door_base.gd"


#-------------------------------------------------
#      Connections
#-------------------------------------------------

func on_entered(body: PhysicsBody2D) -> void:
	if not body is Player or (locked or temp_lock):
		return
	_player = body as Player
	Physics.is_in_pausible_state = false
	open_door()
	open()

func on_exited(body: PhysicsBody2D) -> void:
	Physics.is_in_pausible_state = true
	if not body is Player or (locked or temp_lock):
		if is_door_open():
			close()
			locked = true
			_player = null
			return
	if is_door_open():
		close()
		locked = true
