class_name PlayerBase
extends CharacterBody3D
## Player, part 1 of 9: constants, all state (vars) and node references shared by every part.
## The parts form a chain of scripts, each extending the previous one (map: player.gd).

const WALK_SPEED := 5.25
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.5
const JUMP_VELOCITY := 6.5
const GRAVITY := 20.0
const GROUND_ACCEL := 60.0
const GROUND_FRICTION := 50.0
const AIR_ACCEL := 30.0

const SLIDE_MIN_SPEED := 6.5   # horizontal speed needed to start a slide
const SLIDE_START_SPEED := 9.5
const SLIDE_FRICTION := 7.0
const SLIDE_END_SPEED := 3.5
const SLIDE_MAX_TIME := 1.2
const SLIDE_COOLDOWN := 0.8

const RADIUS := 0.35
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const STAND_EYE := 1.65
const CROUCH_EYE := 0.95

const JUMP_BUFFER_TIME := 0.12
const LAND_SOUND_MIN_SPEED := 4.0
const STEP_STRIDE := 2.4
const MAX_PITCH := deg_to_rad(89.0)
const STICK_LOOK_SPEED := Vector2(3.2, 2.2)  # rad/s at full right-stick deflection (yaw, pitch), stick sensitivity 1
const STICK_CURVE := 2.0                      # response curve: small deflections turn slowly for fine aim

enum Mode {
	LOCAL,          # this machine's own player: gathers input, predicts
	REMOTE_SERVER,  # server-side simulation of a remote client, driven by received commands
	PUPPET,         # client-side view of another player, interpolated from server snapshots
}

## Other players are drawn slightly in the past from a buffer of their poses, so they move smoothly despite network
## jitter. The delay adapts (_buffered_pose): one 60 Hz step plus how late poses have recently been.
const INTERP_MIN_DELAY := 0.03   # s
const INTERP_MAX_DELAY := 0.2
const MAX_CMD_QUEUE := 120        # received commands kept per player (2 s); beyond that the oldest are dropped
const CMD_BUDGET_PER_TICK := 1.1  # server steps a client may take per tick (10% slack lets bursts catch up, caps speed hacks)
const CMD_BUDGET_MAX := 8.0
const CMD_REDUNDANCY := 3  # last N commands are re-sent in every packet to survive packet loss
const FLAG_JUMP := 1
const FLAG_SPRINT := 2
const FLAG_CROUCH := 4
const FLAG_FIRE := 8
const FLAG_AIM := 16
const FLAG_RELOAD := 32
const FLAG_JUMP_HELD := 256
const FLAG_MELEE := 512
const FLAG_SELECT_SHIFT := 6  # 2 bits: weapon index + 1, 0 = no switch
const STATE_CROUCHED := 1
const STATE_SLIDING := 2
const STATE_SPRINTING := 4
const STATE_ON_FLOOR := 8
const STATE_WEAPON_SHIFT := 4  # 2 bits: current weapon index
const STATE_RELOADING := 64
const STATE_ADS := 128
const STATE_MANTLING := 256
const STATE_MELEE := 512
## Hoof punch: ray directions as (yaw, pitch) offsets from the view, middle first. At the 2 m reach the outer ones are
## ~0.5 m to the side and ~0.45 m lower (a crouching or sliding target).
const MELEE_FAN: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(-0.13, 0.0), Vector2(0.0, -0.23),
		Vector2(0.26, 0.0), Vector2(-0.26, 0.0), Vector2(0.13, -0.23), Vector2(-0.13, -0.23)]
const MAX_HEALTH := 150  # kid mode: more (Settings.kid_health), up to KID_HEALTH_MAX
const KID_HEALTH_MAX := 600
const BACK_FULL_ANGLE := deg_to_rad(135.0)  # kid mode: shots from this far off the view get the full back_damage
# Health regeneration (server), as in Call of Duty: Modern Warfare III (2023) after its Season 2 patch: it starts 3 s
# after the last damage and comes back at 75 of 150 HP per second, i.e. half a normal player's health per second (empty
# to full in 2 s). Kid mode heals at the same HP per second (the same damage takes as long to heal), only starting sooner
# (Settings.kid_regen_delay).
const REGEN_DELAY := 3.0
const REGEN_PER_SECOND := MAX_HEALTH * 0.5   # HP per second, the same for everybody
const HURT_SHADER := preload("res://assets/shaders/hurt_vignette.gdshader")  # local HUD: hit flash and low health
const RECONCILE_EPS := 0.02          # m; smaller prediction errors are ignored
const HISTORY_MAX := 180             # commands kept for replay (3 s)
const CORRECTION_DECAY := 12.0       # 1/s, how fast the visual correction offset fades out
const CORRECTION_SNAP_DISTANCE := 2.0  # m; larger errors are shown instantly

## Server only: a hoof punch landed on a player or target at `pos` (NetWorld relays it for the cosmetics).
signal server_melee(player: Player, pos: Vector3)
## Server only: a shot was fired. `hits` = [{player_id, zone, pos}] (NetWorld relays it; damage is applied separately).
signal server_shot(player: Player, weapon: int, origin: Vector3, ends: PackedVector3Array, hits: Array)

var control: Mode = Mode.LOCAL
var peer_id := 1
var player_name := "Игрок"
var is_local: bool:
	get:
		return control == Mode.LOCAL

var look_yaw := 0.0
var _sprint_latched := false  # gamepad sprint (Y / L3) stays on until the player stops moving forward
var _pad_look := false  # the gamepad was used last (not the mouse): aim assist is on
var _next_oink := 0.0     # s (ticks clock) when F may oink again
var _aim_assist := AimAssist.new()
var look_pitch := 0.0

var is_sliding := false
var is_crouched := false
var _puppet_velocity := Vector3.ZERO  # puppets: smoothed velocity of the displayed movement
var aiming := false  # sights raised (ADS over half way); puppets take it from the snapshot flags
var is_sprinting := false
var is_mantling := false
var gaps_filled := 0   # debug (server): lost commands replaced by a repeat of the previous one
var cmds_dropped := 0  # debug (server): commands discarded because the queue overflowed
var queue_peak := 0
var mantle_count := 0  # debug: vaults started (counted on replays too)

var _slide_dir := Vector3.ZERO
var _slide_speed := 0.0
var _slide_time := 0.0
var _slide_cooldown := 0.0
var _prev_crouch := false
var _prev_on_floor := true
var _prev_vy := 0.0
var _step_distance := 0.0
var _jump_buffer := 0.0
var _jumped_this_step := false
var _shape := CapsuleShape3D.new()
var _eye_height := STAND_EYE
var _prev_pos := Vector3.ZERO  # body position at the previous physics tick (camera interpolation)
var _curr_pos := Vector3.ZERO
var _prev_yaw := 0.0            # body yaw at the previous / current physics tick (host: smooth remote players)
var _curr_yaw := 0.0
var _seq_offset := INF          # other player: local clock minus their 60 Hz step clock, smoothed (_buffer_pose)
var _jitter := 0.0              # other player: how far recent poses were off that clock (s, slowly forgotten)
var _interp_delay := 0.06       # other player: how far in the past they are drawn right now (s)
var shown_tick := 0.0           # other player: server tick of the pose drawn this frame (0 = none yet)
var _cmd_seq := 0
var _sent_cmds: Array = []        # last CMD_REDUNDANCY encoded commands (client -> server)
var _cmd_queue: Array = []        # received encoded commands (server)
var _last_received_seq := 0
var _last_cmd := PlayerCmd.new()  # server: previously applied command (used to fill gaps)
var _step_budget := 0.0
var _acked_seq := 0               # server: seq of the last command applied
var _snapshots: Array = []        # other player: buffered poses [{t, pos, yaw, pitch, tick}] (_buffer_pose)
var last_server_state: Array = [] # local: most recent snapshot entry for this player
var recon_count := 0              # debug: number of reconciliations so far
var last_error := 0.0             # debug: size of the last prediction error (m)
var rtt_ms := 0.0                 # debug: round trip estimate from command ack times

var _history: Array = []          # client: [{seq, cmd, pos, t}] for commands not yet acknowledged
var _pending_state: Array = []    # client: latest server state for this player, applied next physics tick
var _replaying := false

var weapons := WeaponSim.new()
var world: NetWorld
var health := MAX_HEALTH
var max_health := MAX_HEALTH  # kid mode (set_toughness) + build (set_build)
var regen_delay := REGEN_DELAY  # kid mode + build
var base_max_health := MAX_HEALTH    # kid mode's, before the build
var base_regen_delay := REGEN_DELAY  # kid mode's, before the build
## The build this life is played with (PartDB part ids, SLOTS order) and its numbers (PartDB.mods). Applied at
## (re)spawn on every machine at once (NetWorld._apply_respawn), so prediction and the server agree.
var build: Array = PartDB.default_build()
var mods: Dictionary = PartDB.DEFAULT_MODS.duplicate()
var wanted_build: Array = PartDB.default_build()  # server: what the player picked for the next life
var back_damage := 1.0          # kid mode: damage multiplier for shots from behind (damage_mult_from)
var alive := true
var spawn_protect := 0      # server: ticks of invulnerability left after a respawn
var _regen_wait := 0.0      # server: seconds until health starts coming back
var _regen_carry := 0.0     # server: fraction of a health point regenerated but not yet added
var killed_by := ""         # local HUD: who killed us
var death_time_left := 0.0  # local HUD: respawn countdown
var shots_total := 0   # server stats (for tests / netlog)
var hits_total := 0
var head_hits_total := 0
var _shown_pitch := 0.0  # host: aim pitch of a remote player as drawn (_buffered_pose)
var _view: WeaponView
var _arms: FirstPersonArms
var _crosshair: Crosshair
var _ammo_hud: HudAmmo
var _health_hud: HudHealth
var _damage_dirs: DamageIndicator
var _hurt_rect: ColorRect  # HURT_SHADER vignette
var _death_label: Label
var _hurt_alpha := 0.0
var _last_health := MAX_HEALTH
var _debug_timer := 0.0
var _stance_crouched := false
var _sprint_blend := 0.0
var _view_recoil := Vector2.ZERO
var _look_delta := Vector2.ZERO
var _turn_rate := 0.0  # rad/s the stick (and aim assist) turns the view, smoothed; F3 only
var _prev_look := Vector2.ZERO
var _retract := 0.0
# First-person camera effects (_update_camera_fx; cosmetic: shots go where the look angles point, not the camera).
var _cam_roll := 0.0             # death tilt / slide lean
var _death_drift := Vector3.ZERO    # local, dead beside the train: how far the view has ridden away with the ground...
var _death_drift_v := Vector3.ZERO  # ...and how fast (catches up with the ground like the body does)
var _cam_land := 0.0             # landing dip (m) and its spring velocity
var _cam_land_v := 0.0
var _land_impact := 0.0          # fall speed of a landing not yet shown (set by the simulation)
var _bob_amount := 0.0
var _bob_side := 1.0             # which foot the current step is on
var _punch := Vector2.ZERO       # damage jolt: x = pitch, y = roll (rad)
var _punch_v := Vector2.ZERO
var _mantle_view := 0.0          # vaulting: gun lowered, hands on the ledge, view pitched down
var _ledge_set := false
var _dust_t := 0.0               # to the next slide dust puff (s)
var _mantle_tick := 0
var _mantle_total := 0
var _mantle_rise := 0
var _mantle_cooldown := 0
var _floor_y := 0.0  # height of the last ground we stood on (limits how high jump + vault can reach)
var _mantle_from := Vector3.ZERO
var _mantle_up := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_dir := Vector3.ZERO
var _probe_shape := CapsuleShape3D.new()
var _probe_crouch_shape := CapsuleShape3D.new()
var _mantle_low := false  # the vault being started ends crouched (set by _try_start_mantle, used the same tick)
var _vault_note := ""        # local debug: why the last vault attempt failed
var _vault_note_until := 0
var _puppet_on_floor := true
var _puppet_sliding := false
var _puppet_reloading := false
var _puppet_meleeing := false
var _puppet_last_pos := Vector3.ZERO
var _correction := Vector3.ZERO   # visual offset hiding a position correction, decays to zero

@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _hud: CanvasLayer = $HUD
@onready var _debug: Label = $HUD/Debug
var _debug_shown := false  # F3
@onready var _visual: PlayerVisual = $Visual


func _sfx(id: String, volume_db: float = 0.0) -> void:
	if _replaying:
		return
	Audio.play(id, null if is_local else global_position, volume_db)
