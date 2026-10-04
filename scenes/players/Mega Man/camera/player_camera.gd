extends Camera2D
#warning-ignore-all:integer_division
#warning-ignore-all:return_value_discarded
#warning-ignore-all:narrowing_conversion
#-------------------------------------------------
#      Constants
#-------------------------------------------------
const TP_RESET_FRAMES = 30

# Custom transition offsets in x and y directions, feel free to adjust
const CUSTOM_TRANSITION_OFFSETS: Vector2 = Vector2(8.0, 0.0)
const _MINIMUM_TRANSITION_OFFSETS: Vector2 = 2.0 * Vector2.ONE # don't change
#-------------------------------------------------
#      Signals
#-------------------------------------------------
signal transition_start()
signal transition_end()
signal teleport_section_end()
#-------------------------------------------------
#      Properties
#-------------------------------------------------

#what node should the camera follow
export(NodePath) var player_target_node
# when megaman transitions through a transition line, how long should the animation be.
export(float) var transition_time := 1.0
var frame_count_after_teleport:int = 0

var active_section: Section
var _camera_target: Node2D
var _boundaries_collision_mask: int
var _switching_target: bool

onready var _base_width: int = Config.DEFAULT_WINDOW_WIDTH
onready var _base_height: int = Config.DEFAULT_WINDOW_HEIGHT

#var if player strays too far out of the camera zone they should die
#this is about 226
# onready var _death_distance: float = sqrt(pow(_base_width, 2) + pow(_base_height, 2)) / 1.5

#the highest i was able to get was 193.8
onready var _death_distance: float = 196.00

enum ScrollDir {
	NONE = 0,
	H,
	V
}
var scroll_direction: int = ScrollDir.NONE
var scroll_rate_px: int = 0
var scroll_delay_ms: int = 0
var scroll_elapsed_ms: int = 0


#-------------------------------------------------
#      Processes
#-------------------------------------------------
func _ready() -> void:
	_camera_target = get_node(player_target_node) as Node2D
	global_position =  _camera_target.global_position
	_set_multiplayer_boundaries_dimensions()
	_boundaries_collision_mask = $MultiplayerBoundaries.collision_mask

func _physics_process(_delta: float) -> void:
	var last_frame = frame_count_after_teleport
	Physics.top_tile_of_screen_view = get_camera_screen_center().y - 100
	if PlayerValues.player.global_position.distance_to(get_camera_screen_center()) > _death_distance:
		if not PlayerValues.player.is_dead and not PlayerValues.is_teleporting:
			set_physics_process(false)
			PlayerValues.player.in_pit()
	if scroll_direction and scroll_rate_px and scroll_delay_ms:
		# player is in auto-scroll section
		# FIXME: player is pushed through collision instead of dying
		# FIXME: camera starts scrolling before teleport-in after death
		scroll_elapsed_ms += _delta * 1000
		if scroll_elapsed_ms >= scroll_delay_ms:
			# reset elapsed time since last scroll
			scroll_elapsed_ms = 0
			# scroll camera
			if scroll_direction == ScrollDir.H:
				global_position.x += scroll_rate_px
			else:
				global_position.x -= scroll_rate_px
	else:
		global_position =  _camera_target.global_position
	if PlayerValues.is_teleporting and global_position == _camera_target.global_position:
		frame_count_after_teleport+= 1
		if frame_count_after_teleport >= TP_RESET_FRAMES:
			frame_count_after_teleport = 0
			PlayerValues.is_teleporting = false
	$MultiplayerBoundaries.global_position = get_camera_screen_center()
	if last_frame > 0 and frame_count_after_teleport == last_frame:
		frame_count_after_teleport = 0
#-------------------------------------------------
#      Public Methods
#-------------------------------------------------
func stop_camera():
	set_physics_process(false)

func start_camera():
	set_physics_process(true)

func teleport_section(section:Section):
	if PlayerValues.is_teleporting:

		limit_left = -10000
		limit_top = -10000
		limit_right = 10000
		limit_bottom = 10000
		set_as_toplevel(true)
	#	position = old_cam_pos
	#
	#
	#	var target_position: Vector2
	#	if direction.x != 0:
	#		target_position = Vector2(transition_pos + _base_width / 2 * direction.x, position.y)
	#	else:
	#		target_position = Vector2(position.x, transition_pos + _base_height / 2 * direction.y)

		set_active_section(section)
		update_limits()
	#	set_as_toplevel(false)
	#	global_position =  _camera_target.global_position
		emit_signal("teleport_section_end")
	#	PlayerValues.is_teleporting = false
		set_physics_process(true)

func transition_section(section: Section) -> void:
	if not PlayerValues.is_teleporting:
		var rush = get_parent().get_node_or_null("RushJet")
		emit_signal("transition_start")
		get_tree().paused = true
		set_physics_process(false)
	var direction: Vector2 = section.transition_dir
	var old_cam_pos: Vector2 = get_camera_screen_center()

	limit_left = -10000
	limit_top = -10000
	limit_right = 10000
	limit_bottom = 10000

	var transition_pos: float

	if direction == Vector2.RIGHT:
		transition_pos = section.limit_left
	elif direction == Vector2.LEFT:
		transition_pos = section.limit_right
	elif direction == Vector2.UP:
		transition_pos = section.limit_bottom
	elif direction == Vector2.DOWN:
		transition_pos = section.limit_top

	set_as_toplevel(true)
	position = old_cam_pos
	$MultiplayerBoundaries.collision_mask = 0  # Prevent moving player

	if not PlayerValues.is_teleporting:
		var target_position: Vector2
		if direction.x != 0:
			target_position = Vector2(transition_pos + _base_width / 2 * direction.x, position.y)
		else:
			target_position = Vector2(position.x, transition_pos + _base_height / 2 * direction.y)

		get_tree().call_group("Enemies", "on_camera_exited")
		get_tree().call_group("enemy_projectile", "queue_free")
		get_tree().call_group("SuperArrowP1","queue_free")
		get_tree().call_group("WreckingBeamP1","queue_free")
		get_tree().call_group("spawner_created_rail_lift","queue_free")
		get_tree().call_group("spawning_sand_platform","queue_free")

		var tween: SceneTreeTween = create_tween()
		tween.set_pause_mode(SceneTreeTween.TWEEN_PAUSE_PROCESS)
		tween \
			.tween_property(self, "position", target_position, transition_time) \
			.set_trans(Tween.TRANS_LINEAR) \
			.set_ease(Tween.EASE_IN)

		var rush = get_parent().get_node_or_null("RushJet")
		if rush:
			rush.set_physics_process(false)
			rush.set_process(false)
		var player_movement: Vector2 = _get_player_target_position_offset(direction, section)

		tween \
			.parallel() \
			.tween_property(PlayerValues.player, "global_position", player_movement, transition_time) \
			.as_relative() \
			.set_trans(Tween.TRANS_LINEAR) \
			.set_ease(Tween.EASE_IN_OUT)

		if rush:
			tween \
				.parallel() \
				.tween_property(rush, "global_position", Vector2(player_movement.x, 0), transition_time) \
				.as_relative() \
				.set_trans(Tween.TRANS_LINEAR) \
				.set_ease(Tween.EASE_IN_OUT)

		yield(tween, "finished")
		if rush:
			rush.frame_count = 0
			rush.set_physics_process(true)
			rush.set_process(true)
	set_active_section(section)
	update_limits()
	set_as_toplevel(false)
	global_position =  _camera_target.global_position
	$MultiplayerBoundaries.collision_mask = _boundaries_collision_mask
	get_tree().paused = false
	emit_signal("transition_end")
#	PlayerValues.is_teleporting = false
	set_physics_process(true)

func update_limits() -> void:
	limit_left = active_section.limit_left
	limit_top = active_section.limit_top
	limit_right = active_section.limit_right
	limit_bottom = active_section.limit_bottom

func update_current_section():
	set_active_section(active_section)
	update_limits()
	set_as_toplevel(false)
	global_position =  _camera_target.global_position
#-------------------------------------------------
#      Private Methods
#-------------------------------------------------

func _set_multiplayer_boundaries_dimensions() -> void:
	var offset: int = 8
	var width: int = 4
	var off_screen_protection:float = 0.4
	var x: float = Config.DEFAULT_WINDOW_WIDTH
	var y: float = Config.DEFAULT_WINDOW_HEIGHT

	# top is the exact width of a screen.
	$MultiplayerBoundaries/CollisionShapeTop.shape.extents.x = x / 2
	$MultiplayerBoundaries/CollisionShapeTop.shape.extents.y = width
	$MultiplayerBoundaries/CollisionShapeTop.position.y = -y / 2 - 50

	#height of the left and right is larger than the entire screen so you cannot jump off the edge.
	$MultiplayerBoundaries/CollisionShapeLeft.shape.extents.x = width
	$MultiplayerBoundaries/CollisionShapeLeft.shape.extents.y = y / off_screen_protection
	$MultiplayerBoundaries/CollisionShapeLeft.position.x = -x / 2 - offset

	$MultiplayerBoundaries/CollisionShapeRight.shape.extents.x = width
	$MultiplayerBoundaries/CollisionShapeRight.shape.extents.y = y / off_screen_protection
	$MultiplayerBoundaries/CollisionShapeRight.position.x = x / 2 + offset

func set_active_section(value: Section) -> void:
	if active_section:
		active_section.active = false

		if not value:
			active_section = null
			return

	active_section = value
	active_section.active = true
	update_limits()

func _get_player_target_position_offset(transition_direction: Vector2, target_section: Section) -> Vector2:
	var player_collision: CollisionShape2D = Physics.get_collision(PlayerValues.player)
	assert(player_collision.shape is RectangleShape2D)
	# Step 1: find out global position where we should stop after the transition finishes. Oferall offset
	# is a sum of player's collision extents, boss door width and some custom offsets could be set.
	# Here we add at least 2 pixels to offset as a temporary workaround to avoid a bug that may occur
	# when the player starts moving in opposite direction right after the transition and section areas
	# might not detect the player left it and won't trigger transition to the previous screen
	var transition_axis = int(transition_direction.y != 0.0)
	var collision_extent: float = player_collision.shape.extents[transition_axis]
	var transition_offset: float = collision_extent + target_section.add_boss_door_offset + \
		max(_get_custom_transition_offsets(transition_axis, collision_extent),
			_MINIMUM_TRANSITION_OFFSETS[transition_axis])
	var axis_multiplier: float = 2.0 * transition_axis - 1.0
	var trim_margin: int = round(fmod(TAU + axis_multiplier * transition_direction.angle(), TAU) / (PI / 2.0))
	var trimmed_section_rect: Rect2 = Rect2(
		target_section.global_position, Vector2(target_section.width, target_section.height))\
			.grow_margin(trim_margin, -transition_offset)
	var target_position_value: float = \
		(trimmed_section_rect.position if trim_margin < 2 else trimmed_section_rect.end)[transition_axis]
	var target_player_collision_position: Vector2 = player_collision.global_position
	target_player_collision_position[transition_axis] = target_position_value
	# Step 2: Find out player's target global position based on player's collision target position
	var player_collision_global_transform: Transform2D = player_collision.global_transform
	player_collision_global_transform.origin = target_player_collision_position
	var target_player_position: Vector2 = \
		(player_collision_global_transform * player_collision.transform.affine_inverse()).origin
	# Step 3: The resultiing movement vector will be a a direction vector from current player's position
	# to the target position. We multiply it with direction vector just to avoid possible float error in
	# direction normal to transition axis that may accur when we substract vectors
	target_section.add_boss_door_offset = false
	return (target_player_position - PlayerValues.player.global_position) * transition_direction.abs()

# Change this function's content if you feel like you want to override default offset calculation behavior.
# @param transition_axis axis along which the player is transitioning, either Vector2.AXIS_X or Vector2.AXIS_Y
# @param collision_extent player's collision extent along transitioning axis
func _get_custom_transition_offsets(transition_axis: int, _collision_extent: float) -> float:
	return CUSTOM_TRANSITION_OFFSETS[transition_axis]

#-------------------------------------------------
#      Connections
#-------------------------------------------------
func on_restarted() -> void:
	if not is_connected("transition_start", PlayerValues.player, "on_camera_transition_start"):
		connect("transition_start", PlayerValues.player, "on_camera_transition_start")
	if not is_connected("transition_end", PlayerValues.player, "on_camera_transition_end"):
		connect("transition_end", PlayerValues.player, "on_camera_transition_end")
	if not is_connected("teleport_section_end",PlayerValues.player, "on_camera_transition_end"):
		connect("teleport_section_end",PlayerValues.player, "on_camera_transition_end")

	global_position = _camera_target.global_position
	set_physics_process(true)

func reinit_weapon_wheel():
	$Weapon_Wheel.initialize_weapon_wheel()

func set_scroll(dir: int, rate_px: int, delay_ms: int):
	if dir < ScrollDir.NONE or dir > ScrollDir.V:
		printerr("Invalid scroll direction: %s" % dir)
		return

	scroll_direction = dir
	scroll_rate_px = rate_px
	scroll_delay_ms = delay_ms

func stop_scroll():
	set_scroll(0, 0, 0)
