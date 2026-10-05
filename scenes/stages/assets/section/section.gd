tool
extends Node2D
#warning-ignore-all:return_value_discarded
#warning-ignore-all:narrowing_conversion

# Area that defines a section of the stage. Triggers a camera transition when player enters.
class_name Section
#-------------------------------------------------
#      Constants
#-------------------------------------------------

#-------------------------------------------------
#      Signals
#-------------------------------------------------
signal transition_entered(transition)
signal transition_entered_by_teleporter(transition)
signal transition_exited(transition)
signal transmit_section_info(info)
signal signal_midboss_death
signal signal_midboss_despawn
#-------------------------------------------------
#      Properties
#-------------------------------------------------
# minimum, maximum, tile_size
export(int, 256, 3840, 16) var width := 256 setget _set_width
export(int, 224, 2400, 16) var height := 224 setget _set_height

var limit_left: float
var limit_top: float
var limit_right: float
var limit_bottom: float
var limits:Dictionary

var transition_dir: Vector2
var add_boss_door_offset: float

var active: bool
export(bool) var seal_on_screen_leave:= false

export(int, "None", "Horizontal", "Vertical") var scroll_direction = 0
export(int) var scroll_rate_px = 1;
export(int) var scroll_delay_ms = 32;

#-------------------------------------------------
#      Processes
#-------------------------------------------------
func _ready() -> void:
	if Engine.editor_hint:
		return

	limit_left = global_position.x
	limit_top = global_position.y
	limit_right = global_position.x + $"Area2D/CollisionShape2D".shape.extents.x * 2
	limit_bottom = global_position.y + $"Area2D/CollisionShape2D".shape.extents.y * 2

	limits = {"top":limit_top, "right":limit_right,"bottom":limit_bottom,"left":limit_left}

	$Area2D.connect("body_entered", self, "on_body_entered")
	$Area2D.connect("body_exited", self, "_on_body_exited")
#-------------------------------------------------
#      Public Methods
#-------------------------------------------------
# Returns global position of section center.
func get_section_center() -> Vector2:
	return Vector2(limit_left + limit_right / 2, limit_top + limit_bottom / 2)

func update_limits():
	limit_left = global_position.x
	limit_top = global_position.y
	limit_right = global_position.x + $"Area2D/CollisionShape2D".shape.extents.x * 2
	limit_bottom = global_position.y + $"Area2D/CollisionShape2D".shape.extents.y * 2
	limits = {"top":limit_top, "right":limit_right,"bottom":limit_bottom,"left":limit_left}

func manually_update_limits(l,t,r,b):
	limit_left = l
	limit_top = t
	limit_right = r
	limit_bottom = b
	limits = {"top":limit_top, "right":limit_right,"bottom":limit_bottom,"left":limit_left}
#-------------------------------------------------
#      Private Methods
#-------------------------------------------------

func _update_direction(previous_section: Section) -> void:
	transition_dir = Vector2.ZERO
	var is_vertical: bool = true

	if limit_left >= previous_section.limit_right or limit_right <= previous_section.limit_left:
		is_vertical = false

	if is_vertical:
		if global_position.y > previous_section.global_position.y:
			transition_dir = Vector2.DOWN
			# print("Transition Direction: DOWN")
		else:
			transition_dir = Vector2.UP
			# print("Transition Direction: UP")
	else:
		if global_position.x > previous_section.global_position.x:
			transition_dir = Vector2.RIGHT
			# print("Transition Direction: RIGHT")
		else:
			transition_dir = Vector2.LEFT
			# print("Transition Direction: LEFT")

func _set_width(value: int) -> void:
	width = value
	_update_size()

func _set_height(value: int) -> void:
	height = value
	_update_size()

func _update_size() -> void:

	var extents := Vector2(width / 2.0, height / 2.0)
	$"Area2D/CollisionShape2D".shape.extents = extents
	$"Area2D/CollisionShape2D".position = extents
	$"BlockingWall/CollisionShape2D".shape.extents = extents
	$"BlockingWall/CollisionShape2D".position = extents
	$DebugRect.update()

#-------------------------------------------------
#      Connections
#-------------------------------------------------
func on_body_entered(body: Node) -> void:
	if body is Player:
		if PlayerValues.is_teleporting:
			if !PlayerValues.is_in_special_game_mode and !PlayerValues.is_in_refights:
				return
			else:
				update_limits()
				var cam: Camera2D = Physics.current_stage.current_camera

				cam.set_active_section(self)
				emit_signal("transition_entered_by_teleporter", self)
				emit_signal("transmit_section_info",self)
				return
		if not body is Player or active: #revert to is Player
			return

		for node in get_tree().get_nodes_in_group("TremorPulseP1"):
			node.force_kill()

		if $BlockingWall.get_collision_layer_bit(Bitmask.stage):
			return

		var cam: Camera2D = Physics.current_stage.current_camera
		if not cam.active_section or Physics.current_stage.restarting:
			emit_signal("transmit_section_info",self)
			cam.set_active_section(self)
			return
		else:
			_update_direction(cam.active_section)

		if transition_dir == Vector2.ZERO:
			return

		#revert to use body.
		if transition_dir == Vector2.UP and (not PlayerValues.player.is_climbing and not PlayerValues.player.boss_door_transition and not PlayerValues.player.is_upside_down):
			return

		if transition_dir == Vector2.DOWN and PlayerValues.player.is_upside_down and (not PlayerValues.player.is_climbing and not PlayerValues.player.boss_door_transition):
			return

		add_boss_door_offset = false

		if scroll_direction and scroll_rate_px and scroll_delay_ms:
			cam.set_scroll(scroll_direction, scroll_rate_px, scroll_delay_ms)

		emit_signal("transition_entered", self)
		emit_signal("transmit_section_info",self)

func on_body_entered_for_boss_doors(body: Node, boss_door: Node2D) -> void:
	if not body is Player or active: #revert to is Player
		return

	if $BlockingWall.get_collision_layer_bit(Bitmask.stage):
		return

	var cam: Camera2D = Physics.current_stage.current_camera
	if not cam.active_section or Physics.current_stage.restarting:
		emit_signal("transmit_section_info",self)
		cam.set_active_section(self)
		return
	else:
		_update_direction(cam.active_section)

	if transition_dir == Vector2.ZERO:
		return

	#revert to use body.
	if transition_dir == Vector2.UP and (not body.is_climbing and not body.boss_door_transition and not PlayerValues.player.is_upside_down):
		return

	add_boss_door_offset = _calculate_boss_door_offset(boss_door)
	emit_signal("transition_entered", self)
	emit_signal("transmit_section_info",self)

func _calculate_boss_door_offset(boss_door: Node2D) -> float:
	var sprite: Sprite = boss_door.find_node("*Sprite")
	var self_rect: Rect2 = Rect2(global_position, Vector2(width, height))
	var boss_door_rect: Rect2 = sprite.global_transform.xform(sprite.get_rect())
	var merge_rect: Rect2 = self_rect.merge(boss_door_rect)
	var self_rect_vec: Vector2 = self_rect.end - self_rect.position
	var merge_rect_vec: Vector2 = merge_rect.end - merge_rect.position
	var result: float = (merge_rect_vec - self_rect_vec).length()
	return result

func _on_body_exited(body: Node) -> void:
	if self != Physics.current_stage.current_section:
		if not body is Player:
			return

		if seal_on_screen_leave:
			$BlockingWall.set_collision_layer_bit(Bitmask.stage, true)

		if scroll_direction:
			Physics.current_stage.current_camera.stop_scroll()

		emit_signal("transition_exited", self)

	#when you die set all of the blocking walls to free.
func on_restarted() -> void:
	if seal_on_screen_leave:
		$BlockingWall.set_collision_layer_bit(Bitmask.stage, false)

	if scroll_direction and scroll_rate_px and scroll_delay_ms:
		Physics.current_stage.current_camera.set_scroll(scroll_direction, scroll_rate_px, scroll_delay_ms)

func _on_midboss_death():
	emit_signal("signal_midboss_death")

func _on_midboss_despawn():
	emit_signal("signal_midboss_despawn")
