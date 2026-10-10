extends Node2D


#-------------------------------------------------
#      Signals
#-------------------------------------------------
signal closed()

#-------------------------------------------------
#      Properties
#-------------------------------------------------
export var lightest_color:Color = Color("ffffff")
export var mid_color:Color = Color("bcbcbc")
export var darkest_color:Color = Color("787878")

var temp_lock = false
var locked := false setget locked_collision
var _section_1: Section
var _section_2: Section
var _player: Player
var _reset_lock := true
var is_animating = false


func _ready():
	if Engine.editor_hint:
		$arrow.show()
	else:
		$arrow.hide()
	$Sprite.material.set_shader_param("replace_0", lightest_color)
	$Sprite.material.set_shader_param("replace_1", mid_color)
	$Sprite.material.set_shader_param("replace_2", darkest_color)
	add_to_group("BossDoors")


#-------------------------------------------------
#      Public Methods
#-------------------------------------------------

func locked_collision(value: bool):
	locked = value
	if value:
		$locked_shape/CollisionShape2D.set_deferred("disabled", false)
	else:
		$locked_shape/CollisionShape2D.set_deferred("disabled", true)

func open():
	get_tree().paused = true
	$"Sprite/AnimationPlayer".play("Open_and_Close")
	$AudioStreamPlayer.play()
	open_door()

func close():
	emit_signal("closed")
	$"Sprite/AnimationPlayer".play_backwards("Open_and_Close")
	$AudioStreamPlayer.play()
	close_door()

func open_door():
	$StaticBody2D.set_collision_layer_bit(Bitmask.stage, false)

func close_door():
	$StaticBody2D.set_collision_layer_bit(Bitmask.stage, true)

func is_door_open() -> bool:
	return !$StaticBody2D.get_collision_layer_bit(Bitmask.stage)


#-------------------------------------------------
#      Connections
#-------------------------------------------------

func on_restarted():
	if _reset_lock:
		locked = false
		temp_lock = false

func on_checkpoint_reached():
	if locked:
		_reset_lock = false

func on_section_entered(section: Node2D):
	if section.owner is Section:
		if not _section_1:
			_section_1 = section.owner as Section
		elif not _section_2:
			_section_2 = section.owner as Section

func on_entered(body: PhysicsBody2D):
	assert(false, "Implementing classes must define method `on_entered`")

func on_exited(body: PhysicsBody2D):
	assert(false, "Implementing classes must define method `on_exited`")

func on_animation_finished(anim_name: String) -> void:
	if _player and is_door_open():
		if not _player.is_dead:
			if _section_1.active:
				_section_2.on_body_entered_for_boss_doors(_player, self)
			else:
				_section_1.on_body_entered_for_boss_doors(_player, self)

func on_locking_enemy_dead():
	temp_lock = false
	$Area2D/CollisionShape2D.set_deferred("disabled",true)
	yield(get_tree(),"idle_frame")
	$Area2D/CollisionShape2D.set_deferred("disabled",false)
