extends Stage
#warning-ignore-all:return_value_discarded
#-------------------------------------------------
#      Constants
#-------------------------------------------------

#-------------------------------------------------
#      Signals
#-------------------------------------------------

#-------------------------------------------------
#      Properties
#-------------------------------------------------
onready var _music: Node
onready var bgm:AudioStreamPlayer = $Audio/BGM
#onready var _bossDoor:Node2D = $BossDoors/BossDoorRight2
#onready var _boss:KinematicBody2D = $Sections/Section15/PlugMan


# Start position will be a property of the level instead of where the player is placed on the map.
# This will makde checkpoints reference the current scene without having to store CP data in globals.
var start_position:Vector2

#-------------------------------------------------
#      Processes
#-------------------------------------------------

func _ready():
	did_boss_dialog = true
	Physics.is_in_pausible_state = false
	Physics.is_pause_enabled = false
	Physics.current_stage = self
	PlayerValues.player = player
	_music = $Audio
	connect_signals()
	_restart()

func _notification(what):
	match what:
		NOTIFICATION_INSTANCED:
			pass

func _physics_process(delta):
	append_time_trial_frame()

func _restart() -> void:
	._restart()
#-------------------------------------------------
#      Public Methods
#-------------------------------------------------

#-------------------------------------------------
#      Private Methods
#-------------------------------------------------

#-------------------------------------------------
#      Connections
#-------------------------------------------------
func connect_signals() -> void:
	._connect_signals()

	_try_connect(self, "restarted", _music, "on_restarted")
	_try_connect(_pause, "game_paused", _music, "on_game_paused")
	_try_connect(_pause, "game_resumed", _music, "on_game_resumed")
	_try_connect(player, "died", _music, "on_died")

	# Stage Boss
#	_try_connect(self, "restarted", _boss, "reset")
#	_try_connect(_boss, "boss_ready", _music, "on_boss_ready")
#	_try_connect(_boss, "boss_died", self, "_on_boss_died")
#	_try_connect(_boss, "boss_died", _music, "on_boss_died")
#	_try_connect(_boss, "boss_died", player, "on_boss_died")
#	_try_connect(_music,"stage_clear_finish_warp_out", player, "on_level_end")
#	_try_connect(_music, "stage_clear_finish_warp_out",self, "on_teleport_out")

	# Stage Boss Doors
#	_try_connect(_bossDoor, "closed", _music, "on_boss_entered")
#	_try_connect(self, "start_boss_animation", _boss, "on_boss_entered")
#	_try_connect(_bossDoor, "closed", player, "on_boss_entered")
#	_try_connect(_bossDoor, "closed", self, "emit_signal",["start_boss_animation"])

	for boss_door in get_tree().get_nodes_in_group("BossDoors"):
		_try_connect(self, "restarted", boss_door, "on_restarted")
		for checkpoint in get_tree().get_nodes_in_group("Checkpoints"):
			_try_connect(checkpoint, "checkpoint_reached", boss_door, "on_checkpoint_reached")
	_register_update_cd_count_callbacks()

func _on_boss_died():
	._on_boss_died()

func _on_screen_faded_out() -> void:
	yield(get_tree().create_timer(BLACK_SCREEN_DELAY), "timeout")
	if stage_exited:
		PlayerValues.refill_everything()
		get_tree().change_scene("res://scenes/menus/BossSelect.tscn")
	elif not stage_exited and (PlayerValues.lives >= 0 or PlayerValues.lives == -100) :
		PlayerValues.player.default_to_buster()
		_restart()
	else:
		get_tree().change_scene("res://scenes/menus/gameover/game_over.tscn")

func on_miniboss_dead():
	$Sections/Section09/up_lift_spawner.activate()


func _on_background_change_body_entered(body):
	if body is Player:
		$ParallaxBackground/sky_low.hide()
		$ParallaxBackground/city_lower.hide()
		$ParallaxBackground/clouds_lower.hide()

		$ParallaxBackground/sky_high.show()
		$ParallaxBackground/city_upper.show()
		$ParallaxBackground/clouds_upper.show()
		$ParallaxBackground/clouds_upper2.show()

func on_teleport_out():
	.on_teleport_out()


func _on_Area2D2_body_entered(body):
	if body is Player:
		$Sections/Section17.position = Vector2(2816, -896)


func _on_Area2D3_body_entered(body):
	if body is Player:
		$Sections/Section17.position = Vector2(2816, 0)
