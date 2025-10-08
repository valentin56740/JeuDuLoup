extends RigidBody3D

@export var wander_speed: float = 10.0
@export var direction_change_interval: float = 2.0
@export var flee_speed: float = 20.0
@export var safe_speed: float = 15.0 # vitesse du mode SAFE
@export var safe_distance: float = 30.0 # rayon de sécurité

var loup_dangereux: RigidBody3D = null
var loup_proche: RigidBody3D = null

enum Mode { WANDER, SAFE, FLEE }
var mode = Mode.WANDER

var move_dir: Vector3 = Vector3.ZERO
var timer: float = 0.0

var sx: float = 100
var sz: float = 100

func _physics_process(delta: float) -> void:
	match mode:
		Mode.FLEE:
			if is_instance_valid(loup_proche):
				flee_from_wolf(loup_proche, delta)
			else:
				mode = Mode.SAFE if is_instance_valid(loup_dangereux) else Mode.WANDER

		Mode.SAFE:
			if is_instance_valid(loup_proche):
				mode = Mode.FLEE
			elif is_instance_valid(loup_dangereux):
				safe_avoid_wolf(loup_dangereux, delta)
			else:
				mode = Mode.WANDER

		Mode.WANDER:
			if is_instance_valid(loup_proche):
				mode = Mode.FLEE
			elif is_instance_valid(loup_dangereux):
				mode = Mode.SAFE
			else:
				wander(delta)

	# Gestion des bords
	if position.x > sx / 2:
		position.x = -sx / 2
	elif position.x < -sx / 2:
		position.x = sx / 2

	if position.z > sz / 2:
		position.z = -sz / 2
	elif position.z < -sz / 2:
		position.z = sz / 2


# -------------------------------
# DÉTECTION DES LOUPS
# -------------------------------

func _on_area_safe_body_entered(body: Node3D) -> void:
	if body.is_in_group("Loup"):
		loup_dangereux = body
		if mode == Mode.WANDER:
			mode = Mode.SAFE

func _on_area_safe_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body == loup_dangereux:
		loup_dangereux = null
		if mode == Mode.SAFE:
			mode = Mode.WANDER

func _on_area_danger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Loup"):
		loup_proche = body
		mode = Mode.FLEE

func _on_area_danger_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body == loup_proche:
		loup_proche = null
		mode = Mode.SAFE if is_instance_valid(loup_dangereux) else Mode.WANDER


# -------------------------------
# COMPORTEMENTS
# -------------------------------

func wander(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		var angle = randf() * TAU
		move_dir = Vector3(cos(angle), 0, sin(angle)).normalized()
		timer = direction_change_interval

	apply_central_force(move_dir * wander_speed)

func safe_avoid_wolf(wolf: RigidBody3D, delta: float) -> void:
	var to_wolf = (wolf.global_position - global_position)
	var dist = to_wolf.length()
	if dist > safe_distance:
		# trop loin → retour au mode wander
		mode = Mode.WANDER
		return

	var away_dir = -to_wolf.normalized()

	# ajoute un peu d’aléatoire pour que le comportement soit plus naturel
	var random_angle = randf_range(-0.5, 0.5)
	var rot = Basis(Vector3.UP, random_angle)
	var final_dir = (rot * away_dir).normalized()

	apply_central_force(final_dir * safe_speed)

func flee_from_wolf(wolf: RigidBody3D, delta: float) -> void:
	var to_wolf = (wolf.global_position - global_position).normalized()
	var wolf_dir = wolf.linear_velocity.normalized()
	var sheep_dir = move_dir.normalized()

	var dot = sheep_dir.dot(wolf_dir)
	var flee_dir: Vector3

	if dot > 0.7:
		flee_dir = sheep_dir
	elif abs(dot) < 0.3:
		flee_dir = to_wolf.cross(Vector3.UP).normalized()
	else:
		flee_dir = -to_wolf

	apply_central_force(flee_dir * flee_speed)
