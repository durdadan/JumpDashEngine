extends State

#-------------------------------------------------
#      Constants
#-------------------------------------------------
const FLIP_X_VELOCITY = 70
const FLIP_Y_VELOCITY = -250
const SPLASH = preload("res://scenes/stages/assets/water/effects/splash.tscn")
#-------------------------------------------------
#      Signals
#-------------------------------------------------

#-------------------------------------------------
#      Properties
#-------------------------------------------------
var flip_speed : Vector2
#-------------------------------------------------
#      Processes
#-------------------------------------------------

func _ready():
	pass

func _enter():
	if $"../../Hitbox".get_global_position().x < PlayerValues.player.get_global_position().x :
		$"../../EnemyAnimations".play("flip_to_left")
		flip_speed.x = FLIP_X_VELOCITY * -1
	elif $"../../Hitbox".get_global_position().x > PlayerValues.player.get_global_position().x :
		$"../../EnemyAnimations".play("flip_to_right")
		flip_speed.x = FLIP_X_VELOCITY
	flip_speed.y = FLIP_Y_VELOCITY

func _update(delta):
	flip_speed.y = clamp(flip_speed.y + 10, -Physics.FALL_SPEED_MAX, Physics.FALL_SPEED_MAX)
	owner.move_and_slide(flip_speed, Vector2.UP)
	if owner.is_on_floor() or owner.is_on_ceiling() or owner.is_on_wall() :
		owner._die()

#-------------------------------------------------
#      Public Methods
#-------------------------------------------------

#-------------------------------------------------
#      Private Methods
#-------------------------------------------------

#-------------------------------------------------
#      Connections
#-------------------------------------------------
