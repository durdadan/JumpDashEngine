extends Node

class_name Stage

#-------------------------------------------------
#      Constants
#-------------------------------------------------
const InstantDeathArea: Resource = preload("res://scenes/stages/assets/death_area/death_area.tscn")
const LadderArea: Resource = preload("res://scenes/stages/assets/ladder/Ladder.tscn")
const TELEPORT_IN:Resource = preload("res://scenes/players/Mega Man/animations/Animation_Teleport_In.tscn")
const TOAST = preload("res://scenes/menus/toast_message/toast_message.tscn")
const LABEL = preload("res://scenes/menus/menu-controls/TypingLabel.tscn")
const TT_UI = preload("res://scenes/HUD/time_trial_ui/time_trial_UI.tscn")
const SCORE_DISPLAY = preload("res://scenes/HUD/score_display/score_display.tscn")
# Time constants in seconds.
const START_DELAY: float = 2.0
const DEATH_DELAY: float = 1.5
const BLACK_SCREEN_DELAY: float = 0.4
const FADE_IN_DURATION: float = 0.4
const FADE_OUT_DURATION: float = 0.4
const SPECIALS_RESET_DELAY: float = 0.2
const STAGE_CLEAR_DELAY: float = 6.0
const BOSS_DIALOG_DELAY:float = 0.001

#screen_shake
const NOISE_SHAKE_SPEED:float = 25.0
const NOISE_SHAKE_STRENGTH:float = 3.0
const SHAKE_DECAY_RATE:float = 5.0
#-------------------------------------------------
#      Signals
#-------------------------------------------------
signal start_boss_animation()
signal restarted()
signal player_ready()
signal player_died()
signal stage_cleared()
signal respawn_challenge_items()
signal begin_boss_taunt()
signal begin_boss_music()
signal pre_boss_music()
#-------------------------------------------------
#      Properties
#-------------------------------------------------

# Identifiers for different areas must not be combined for a single tile type.
# Identifiers are the named representations of a tilemap object.  For example, all tiles named "ladder" will be replaced with
# climbable nodes, This makes ladders reusable and not have to place each ladder node as a seperate object throughout the levels.
export(Array, String) var instant_death_identifiers := ["acid", "lava", "spike"]
export(Array, String) var ladder_identifiers := ["ladder"]

var current_camera: Camera2D
var stage_start_pos: Vector2
var start_pos: Vector2
var start_dir: Vector2
var stage_exited: bool
var player: Player
var restarting: bool

var noise_i:float = 0.0
var shake_speed:float = 0.0
var shake_strength:float = 0.0
var shake_decay_rate:float = 0.0
var current_section
var stage_playtime:float = 0.0
var last_lever_state:int = 0
var did_boss_dialog:bool = false
#normally this would be a bool. but i dont want to convert it when it's used int he databse.
var did_pause:int = 0

#time trial variables
var count = 0
var ghost_data:Dictionary = {
	"0": Vector2(0,0)
}
var stat_saving_frame = 0
var ghost_node = null
var time_trial_id:int = 0
var is_player_ready_for_first_input:bool = false
var time_trial_first_input:bool = false
var best_time_trial_world_record:float = 999999.0

onready var _fade_effect := $"UI/FadeEffects"
onready var _health_bar := $"UI/MarginContainer/HealthBar"
onready var _weapon_bar := $"UI/MarginContainer/HealthBar/WeaponBar"
onready var _pause := $"UI/PauseMenu"
onready var _tt
#onready var _gui_game_over := $"GUI/GameOver"
onready var _gui_weapon_icon_overhead := $"UI/WeaponIconOverhead"
onready var noise = OpenSimplexNoise.new()
var did_restart:bool = true
var level_clear_trophy_name:String = ""
var f = 0
var was_level_previously_cleared:bool = false
#-------------------------------------------------
#      Processes
#-------------------------------------------------

func _init() -> void:
	pause_mode = PAUSE_MODE_STOP
	start_dir = Vector2.RIGHT
	stage_exited = false

func _ready() -> void:
	get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT,SceneTree.STRETCH_ASPECT_KEEP,Vector2(256,224),1.0)
	set_process(false)
	set_physics_process(false)
	var skip_dialog:bool = false
	if (Config.skip_boss_dialog and Config.has_beat_game) or PlayerValues.is_in_special_game_mode:
		skip_dialog = true
		if PlayerValues.game_mode == "time_trial":
			get_tree().call_group("Checkpoints", "queue_free")
			get_tree().call_group("CD", "queue_free")
			get_tree().call_group("pickup_letter", "queue_free")
			get_tree().call_group("item_bolt", "queue_free")
			get_tree().call_group("item_treasure", "queue_free")
			get_tree().call_group("item_life","queue_free")

	did_boss_dialog = skip_dialog
	noise.seed = Physics.rng.randi()
	noise.period = 2
	LevelValues.resetValues()
	for child in get_children():
		if child is Player:
			player = child as Player
	PlayerValues.player = player


	if Engine.is_editor_hint():
		return

	_add_instant_death_areas()
	_add_ladder_areas()
	#populate the camera object immediately before connecting signals.
	get_current_camera()
	_connect_signals()
	#designate all enemies to go into spawn and respawn mode.
	get_tree().call_group("Enemies", "_replace_with_spawner")
	#_restart()
	if PlayerValues.game_mode == "time_trial":
		var tt_ui = TT_UI.instance()
		get_node("UI").add_child(tt_ui)
		_tt = tt_ui
	if _is_campaign_level() and has_node("UI"):
		get_node("UI").add_child(SCORE_DISPLAY.instance())

func _is_campaign_level() -> bool:
	var path := filename
	return path.begins_with("res://scenes/stages/levels/") \
		and path.find("/credits/") == -1

func _input(event):
	if event is InputEventMouse or event is InputEventMouseButton or event is InputEventJoypadMotion or event is InputEventMouseMotion:
		return

	if !time_trial_first_input and is_player_ready_for_first_input:
		time_trial_first_input = true
		start_timer()

func _process(delta):
	stage_playtime += delta
	shake_strength = lerp(shake_strength,0,shake_decay_rate*delta)
	current_camera.offset = get_noise_offset(delta)
	if PlayerValues.game_mode == "time_trial":
		var is_short = true
		if stage_playtime >= 60.0:
			is_short = false
		_tt.set_time(get_playtime(is_short))

	# about once every 10 seconds or so it saves stats.
	stat_saving_frame += 1
	if stat_saving_frame == 1000:
		stat_saving_frame = 0

func replay_time_trial_mode():
	PlayerValues.refill_everything()
	PlayerValues.set_time_trial_mode_defaults()
	PlayerValues.has_book_of_weapons = true
	get_tree().change_scene(PlayerValues.last_played_level)

func _physics_process(delta):
	append_time_trial_frame()
#-------------------------------------------------
#      Public Methods
#-------------------------------------------------
func append_time_trial_frame():
	count += 1
	ghost_data[String(count)] = PlayerValues.player.global_position

func save_time_trial_to_file():
	var dir = Directory.new()
	if dir.open("user://") == OK:
		dir.make_dir( ProjectSettings.get_setting("application/config/time_trial"))
	var f = File.new()
	f.open_encrypted_with_pass("user://" +  ProjectSettings.get_setting("application/config/time_trial") + "/" + get_file_name() + ".json",File.WRITE,Config.SECURITY_KEY)
	f.store_string(JSON.print(ghost_data))
	f.close()

func set_is_player_ready_for_first_input():
	is_player_ready_for_first_input = true

func get_file_name()->String:
	var level_name = get_tree().current_scene.filename
	level_name = level_name.substr(level_name.find_last("/") +1)
	level_name = level_name.substr(0 , level_name.find("."))
	level_name = level_name.replace(" ", "_").replace("-", "_")
	return level_name

func shake_screen(speed = NOISE_SHAKE_SPEED,strength = NOISE_SHAKE_STRENGTH,decay = SHAKE_DECAY_RATE):
	shake_speed = speed
	shake_strength = strength
	shake_decay_rate = decay

func stop_shaking_screen():
	shake_strength = 0.0

func get_noise_offset(delta)->Vector2:
	noise_i += delta * shake_speed
	return Vector2(
		noise.get_noise_2d(1,noise_i) *shake_strength,
		noise.get_noise_2d(100,noise_i) *shake_strength)

# Returns the first Camera2D found in the stage. Should not be used in _ready() callbacks,
# since some nodes' _ready() callbacks are called before the camera is instantiated.
func get_current_camera() -> void:
	# Search stage nodes.
	if not current_camera:
		for child in get_children():
			if child is Camera2D:
				current_camera = child
				break

	# Search player nodes if not found in stage.
	if not current_camera and player:
		for child in player.get_children():
			if child is Camera2D:
				current_camera = child
				break

	if not current_camera:
		printerr("No camera found in current stage.")

#this will be used for when you die in a method without an explosion
func play_death_sound()->void:
	$Audio/DeathSound.play()
#-------------------------------------------------
#      Private Methods
#-------------------------------------------------

func _get_configuration_warning() -> String:
	if not player:
		return "This stage has no Player. Consider adding a Player node to have a controllable character."
	if not current_camera:
		return "This stage has no camera. Consider adding a camera node to have a view on the stage."
	else:
		return ""

func _restart() -> void:
	restarting = true
	if did_restart:
		did_restart = false
		emit_signal("respawn_challenge_items")
	#get_tree().paused = true
	get_tree().call_group("Enemies", "queue_free")
	get_tree().call_group("rogue_joe_spawned","queue_free")
	Physics.reset_enemy_count()
	_set_stage_start_pos()
	emit_signal("restarted")
	emit_signal("player_ready")
	get_tree().paused = false
	# The following delay is also important for the camera to be able to update sections
	# and transition instantly on restart.
	yield(get_tree().create_timer(SPECIALS_RESET_DELAY), "timeout")
	get_tree().call_group("SpecialsReset", "on_restarted")
	for projectile in get_tree().get_nodes_in_group("BossProjectile"):
		projectile.queue_free()
	for explosion in get_tree().get_nodes_in_group("death_explosion"):
		explosion.queue_free()
	restarting = false
	$PlayerCamera.call_deferred("update_current_section")
	get_tree().call_group("BonusCheckpoints","on_restart")
	get_tree().call_group("on_screen_enemy_spawner","check_spawn_enemy")

func _register_update_cd_count_callbacks() -> void:
	for node in get_tree().get_nodes_in_group("CD"):
		if node.has_signal("collect_cd"):
			node.connect("collect_cd", self, "_update_cd_count")


func _game_over() -> void:
	get_tree().change_scene("res://scenes/menus/gameover/game_over.tscn")

func _set_stage_start_pos() -> void:
	if not player:
		return

	if start_pos:
		player.global_position = start_pos
	else:
		start_pos = player.global_position
		stage_start_pos = start_pos
	set_lever_state_to_last_state_before_restart()
	player.set_facing_direction(start_dir)

func set_lever_state_to_last_state_before_restart():
	Physics.lever_state = last_lever_state

#warning-ignore-all:return_value_discarded
func _connect_signals() -> void:
	# Connect various stage signals to children methods.

	_try_connect(self, "restarted", player, "on_restarted")
	_try_connect(self, "restarted", current_camera, "on_restarted")
	_try_connect(self, "restarted", _fade_effect, "fade_in", [FADE_IN_DURATION])
	_try_connect(self, "restarted", _health_bar, "on_restarted")
#	for switch in get_tree().get_nodes_in_group("lever_switch"):
#		_try_connect(switch,"change_state",self,"set_lever_state")
	for textan_block in get_tree().get_nodes_in_group("textan_block"):
		_try_connect(self,"restarted",textan_block,"queue_free")
	for safety_block in get_tree().get_nodes_in_group("safety_block"):
		_try_connect(self,"restarted",safety_block,"reset")

	# all sections of a level should be in a "Sections" sub node
	if has_node("Sections"):
		for section in $Sections.get_children():
			_try_connect(player, "ready_to_move", section, "on_restarted")
			_try_connect(section, "transition_entered", current_camera, "transition_section")
			_try_connect(section, "transmit_section_info", self, "on_update_section")

	_try_connect(self, "player_ready", player, "on_ready")
	#_try_connect(self, "player_ready", _pause, "set_can_pause", [true])
	_try_connect(_pause,"game_paused",self,"detect_pause")
	_try_connect(player,"ready_to_move", _pause, "set_can_pause", [true])
	_try_connect(player, "ready_to_move", self, "set_is_player_ready_for_first_input")
	_try_connect(self, "player_died", _fade_effect, "fade_out", [FADE_OUT_DURATION])
	_try_connect(self, "stage_cleared", player, "on_stage_cleared")

	# Connect children signals to stage methods.
	_try_connect(player, "died", self, "_on_died")
	_try_connect(_fade_effect, "screen_faded_out", self, "_on_screen_faded_out")
	_try_connect(player, "exited", self, "_on_stage_exited")
#
#	# Connect children signals to other children methods.
	_try_connect(player, "hit_points_changed", _health_bar, "on_hit_points_changed")
	_try_connect(player, "weapon_energy_changed", _weapon_bar, "on_hit_points_changed")
	_try_connect(player, "weapon_changed", _weapon_bar, "on_weapon_changed")
	_try_connect(player, "weapon_changed_swap", _gui_weapon_icon_overhead, "on_weaopn_swapped")
	_try_connect(player,"reinit",current_camera,"reinit_weapon_wheel")
	_try_connect(player,"reinit",_pause,"instantiate")
	_try_connect(player, "died", _pause, "set_can_pause", [false])
	_try_connect(current_camera, "transition_start", _gui_weapon_icon_overhead, "_on_timeout")
	for challenge_item in get_tree().get_nodes_in_group("challenge_item"):
		_try_connect(self, "respawn_challenge_items", challenge_item,"reset")
	for force_beam in get_tree().get_nodes_in_group("force_beam"):
		_try_connect(self,"restarted",force_beam,"_on_reset")
	for treasure in get_tree().get_nodes_in_group("item_treasure"):
		_try_connect(treasure,"send_update_count",self,"_update_cd_count")

# Attempts to connect a signal if it's available
func _try_connect(source: Object, signal_name: String, target: Object, method_name: String,
		binds: Array = [], flags: int = 0) -> bool:
	var error_msg := "%s: Tried to connect %s signal of source to %s method of target." % [self.name, signal_name, method_name]
	if not source:
		printerr(error_msg, " Source does not exist.")
		return false
	if not target:
		printerr(error_msg, " Target does not exist.")
		return false
	if not target.has_method(method_name):
		printerr(error_msg, " Method on %s does not exist." % target.name)
		return false

	if not source.is_connected(signal_name, target, method_name):
		return true if source.connect(signal_name, target, method_name, binds, flags) else false
	else:
		return true

# Iterate all tile types and place instant death areas at their positions
# if their names contain one of the instant death identifiers.
func _add_instant_death_areas() -> void:
	var instant_death_areas_node := Node2D.new()
	instant_death_areas_node.name = "InstantDeathAreas"
	add_child(instant_death_areas_node)

	for tile_map in get_tree().get_nodes_in_group("TileMaps"):
		var tile_set = tile_map.tile_set
		for tile_id in tile_set.get_tiles_ids():
			for identifier in instant_death_identifiers:
				if identifier.to_lower() in tile_set.tile_get_name(tile_id).to_lower():
					for death_cell_pos in tile_map.get_used_cells_by_id(tile_id):
						var instant_death_area := InstantDeathArea.instance()
						var instant_death_area_local = \
								tile_map.map_to_world(death_cell_pos) + Physics.TILE_SIZE / 2
						var instant_death_area_global = tile_map.to_global(instant_death_area_local)
						if identifier.to_lower() == "lava":
							#lava should be moved down 1 pixel because it is not flush with the top of
							instant_death_area_global.y += 1
						instant_death_area.global_position = instant_death_area_global
						instant_death_area.tile_type = tile_set.tile_get_name(tile_id).to_lower()
						instant_death_areas_node.add_child(instant_death_area)
					break

func start_boss_dialog(boss_name):
	if did_boss_dialog:
		emit_signal("begin_boss_music")
		yield(get_tree().create_timer(0.3),"timeout")
		emit_signal("begin_boss_taunt")
		return true
	else:
		return false

func start_timer():
	set_process(true)
	set_physics_process(true)
	if PlayerValues.game_mode == "time_trial" and ghost_node != null:
		ghost_node.set_physics_process(true)

func detect_pause():
	did_pause = 1
# Iterate all tile types and place ladder areas at their positions
# if their names contain the ladder identifier.
func _add_ladder_areas() -> void:
	var ladder_node := Node2D.new()
	ladder_node.name = "Ladders"
	if has_node("Ladders"):
		 get_node("Ladders").queue_free()
	add_child(ladder_node)

	# Collect ladder tiles from all tile maps first
	# and transform all ladder tiles' grid coordinates to global positions.
	# This is required for correctly building inter-section ladders.
	var ladder_tiles: Array = []
	for tile_map in get_tree().get_nodes_in_group("TileMaps"):
		var tile_set = tile_map.tile_set
		for tile_id in tile_set.get_tiles_ids():
			for identifier in ladder_identifiers:
				if identifier.to_lower() in tile_set.tile_get_name(tile_id).to_lower():
					var ladder_tiles_coords: Array = tile_map.get_used_cells_by_id(tile_id)
					for coord in ladder_tiles_coords:
						var ladder_tiles_local: Vector2 = tile_map.map_to_world(coord)
						var ladder_tiles_global: Vector2 = tile_map.to_global(ladder_tiles_local)
						ladder_tiles.append(ladder_tiles_global)

	while ladder_tiles.size() > 0:
		ladder_node.call_deferred("add_child",_construct_ladder(ladder_tiles))

# Returns a ladder node constructed from first set of contiguous ladder tiles
# in array of grid based ladder tile positions. Removes the used ladder
# position elements from the array.
func _construct_ladder(ladder_tiles: Array) -> Node:
	if not ladder_tiles or ladder_tiles.size() == 0:
		printerr("Cannot construct ladder. Ladder tiles array is empty or null.")
		return null

	ladder_tiles.sort_custom(self, "_sort_ladder_tiles")
	var original_x_pos = ladder_tiles[0].x
	var ladder_pos: Vector2 = ladder_tiles[0]
	ladder_pos.x += Physics.TILE_SIZE.x / 2
	var ladder_tile_count := 1

	while ladder_tiles.size() > 1:
		if (ladder_tiles[1].y == ladder_tiles[0].y + Physics.TILE_SIZE.y) and (ladder_tiles[1].x == original_x_pos):
			ladder_tile_count += 1
			ladder_tiles.remove(0)
		else:
			break
	ladder_tiles.remove(0)

	var ladder_area := LadderArea.instance()
	ladder_area.global_position = ladder_pos
	ladder_area.size_in_tiles = ladder_tile_count
	return ladder_area

# Sort tiles in ascending order, where y -> inner and x -> outer.
func _sort_ladder_tiles(item_1: Vector2, item_2: Vector2) -> bool:
	if item_1.x < item_2.x:
		return true
	elif item_1.x > item_2.x:
		return false
	else:
		if item_1.y < item_2.y:
			return true
		else:
			return false

#-------------------------------------------------
#      Connections
#-------------------------------------------------


func _on_died() -> void:
	if PlayerValues.game_mode == "time_trial":
		set_process(false)
		stage_playtime = 0.0
	stop_shaking_screen()
	yield(get_tree().create_timer(DEATH_DELAY), "timeout")
	# NOTE: needs to be after timeout else camera will jump
	current_camera.stop_scroll()
	did_restart = true
	emit_signal("player_died")

func _on_boss_died() -> void:
	Physics.is_in_pausible_state = false
	yield(get_tree().create_timer(1.0),  "timeout")
	emit_signal("stage_cleared")

func _on_stage_exited() -> void:
	stage_exited = true
	_fade_effect.fade_out(FADE_OUT_DURATION)

func _on_screen_faded_out() -> void:
	yield(get_tree().create_timer(BLACK_SCREEN_DELAY), "timeout")
	Config.save_config()
	if !PlayerValues.game_mode == "time_trial":
		if stage_exited:
			PlayerValues.refill_everything()
			if PlayerValues.newly_obtained_weapon_name == "":
				get_tree().change_scene("res://scenes/menus/BossSelect.tscn")
			else:
				get_tree().change_scene("res://scenes/menus/weapon_get_active/weapon_get_active.tscn")
		elif not stage_exited and (PlayerValues.lives >= 0 or PlayerValues.lives == -100) :
			PlayerValues.player.default_to_buster()
			_restart()
		else:
			_game_over()
	elif PlayerValues.game_mode == "time_trial":
		PlayerValues.player.default_to_buster()
		PlayerValues.refill_everything()
		if stage_exited:
			#successfully cleared the stage
			pass

		#var tt = preload("res://scenes/menus/time_trial_summary/time_trial_summary.tscn").instance()
		#tt.connect("tt_replay",self,"replay_time_trial_mode")
		#get_node("UI").add_child(tt)
		#tt.set_utility_1(PlayerValues.obtained_weapons["10"])
		#tt.set_utility_2(PlayerValues.obtained_weapons["11"])
		#tt.set_upgrade(PlayerValues.equipped_upgrade)
		#tt.set_time(stage_playtime)
		#tt.slide_in()

		#yield(tt,"tt_menu")
		#get_tree().change_scene("res://scenes/menus/time_trials/time_trials.tscn")
func on_update_section(section):
	current_section = section

func set_lever_state():
	last_lever_state = Physics.lever_state


func get_playtime(is_short_form:bool = true)->String:
	var miliseconds = fmod(stage_playtime,1)*1000
	var seconds = fmod(stage_playtime,60)
	var minutes = fmod(stage_playtime, 60*60) /60
	var hours = fmod( fmod(stage_playtime,3600*60)/3600, 500)

	return "%02d:%02d:%03d" % [minutes,seconds,miliseconds] if not is_short_form else "%02d.%03d" % [seconds,miliseconds]

func on_teleport_out():
	pass

func weapon_shockwave(position:Vector2):
	var x = (position.x - current_section.position.x) /256.0
	var y = 1-(position.y - current_section.position.y) /224.0
	$UI/shockwave_shader.material.set_shader_param("center",Vector2(x,y))
	$UI/Shockwave.play("shockwave")

func on_time_trial_complete():
	pass

func get_stage_name(time_trial_id):
	var name = ""
	match time_trial_id:
		0: name = "Intro"
		1: name = "Arctic Man"
		2: name = "Beam Man"
		3: name = "Detonate Man"
		4: name = "Gladiator Man"
		5: name = "Cinder Lady"
		6: name = "Maelstrom Woman"
		7: name = "Ninja Man"
		8: name = "Tremor Man"
		9: name = "Serenade"
		10: name = "Virus 1"
		11: name = "Virus 2"
		12: name = "Virus 3"
		13: name = "Virus 4"
		14: name = "Wily 1"
		15: name = "Wily 2"
		16: name = "Wily 3"
		17: name = "Wily 4"
		18: name = "Wily 5"
		30: name = "Credits"
	return name

func submit_to_timetrial_discord_server(time:float, level_name:String):
	if time < best_time_trial_world_record:
		if level_name != "" and Config.player_name != "DEFAULT_USER":
			var _headers = ["Content-Type: application/json"];
			var star = "⭐" if !did_pause else ""
			var _payload = {
				"username": "Holocoach",
				"embeds": [
				{
				"description": star + level_name + " Personal Best by " + Config.player_name + " in " + str(int(time * 1000) / float(1000.0))
				}
			]
			};
			var json_data = JSON.print(_payload);
			var http = HTTPRequest.new()
			add_child(http)
			var err = http.request(
			"https://discord.com/api/webhooks/1487520578066714797/4AFxxaHdAJ8jx67Kqt523FSQk7UpvtBSof-ONEdJpZhG2B_TF6PKsnnrgrlz70Y-Ja2o",
			_headers,
			true,
			HTTPClient.METHOD_POST,
			json_data
			);
			if err != OK:
				print("Failed to send the request: ", err);

func get_record_time_trial(time):
	best_time_trial_world_record = time
