extends "boss_door_base.gd"


func _physics_process(delta):
	for body in $Area2D.get_overlapping_bodies():
		if body is Player:
			if (locked or temp_lock):
				return
			else:
				set_physics_process(false)
				_player = body as Player
				_player.boss_door_transition = true
				open_door()
				open()


#-------------------------------------------------
#      Connections
#-------------------------------------------------
func on_restarted() -> void:
	.on_restarted()
	if _reset_lock:
#		locked = false
#		temp_lock = false
		set_physics_process(true)

func on_entered(body: PhysicsBody2D) -> void:
	if not body is Player or (locked or temp_lock):
		return
	_player = body as Player
	_player.boss_door_transition = true
	Physics.is_in_pausible_state = false
	open_door()
	open()

func on_exited(body: PhysicsBody2D) -> void:
	Physics.is_in_pausible_state = true
	if temp_lock:
		if is_door_open():
			close()
			locked = true
	else:
		if not body is Player or (locked):
			return
		_player.boss_door_transition = false
		_player = null
		if is_door_open():
			close()
			locked = true
