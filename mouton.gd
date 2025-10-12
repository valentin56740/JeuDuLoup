extends RigidBody3D

@export var wander_speed: float = 10.0
@export var direction_change_interval: float = 2.0
@export var flee_speed: float = 20.0
@export var safe_speed: float = 15.0 # vitesse du mode SAFE
@export var safe_distance: float = 40.0 # rayon de sécurité

@export var sang_scene : PackedScene = preload("res://sang.tscn")
@export var loup_scene : PackedScene = preload("res://loup.tscn")

var grazing: bool = false
var grazing_timer: float = 0.0
var next_graze_time: float = 0.0

@onready var animation_player = $Sheep_Model/AnimationPlayer 
@onready var sheep_model = $Sheep_Model

# Remplacement des références uniques par des listes
var dangerous_wolves: Array[RigidBody3D] = []
var close_wolves: Array[RigidBody3D] = []
var sheeps_arround: Array[RigidBody3D] = []

enum Mode { WANDER, SAFE, FLEE } # Les différents modes des moutons 
var mode = Mode.WANDER # Par défaut le mode errance

var move_dir: Vector3 = Vector3.ZERO
var timer: float = 0.0


func _ready() -> void:
	_set_next_graze_time()
	# Optionnel: réduit le drift/inertie
	# linear_damp = 1.0

func _set_next_graze_time() -> void:
	next_graze_time = randf_range(5.0, 15.0) # intervalle aléatoire entre 5 et 15s

func _physics_process(delta: float) -> void:
	match mode:
		Mode.FLEE:
			if close_wolves.size() > 0:
				flee_from_wolves(delta) # Aggression -> fuite multi-loups
			else:
				# Pas d'agression mais loups potentiellement proches
				if dangerous_wolves.size() > 0:
					mode = Mode.SAFE 
				else:
					mode = Mode.WANDER # Aucun loup autour

		Mode.SAFE:
			if close_wolves.size() > 0:
				mode = Mode.FLEE
			elif dangerous_wolves.size() > 0:
				safe_avoid_wolves(delta)
			else:
				mode = Mode.WANDER

		Mode.WANDER:
			if close_wolves.size() > 0:
				mode = Mode.FLEE
			elif dangerous_wolves.size() > 0:
				mode = Mode.SAFE
			else:
				wander(delta)

	# 🔄 Rotation fluide du modèle vers la direction de déplacement
	if linear_velocity.length() > 0.1:
		var dir = linear_velocity.normalized()
		var target_yaw = atan2(dir.x, dir.z)
		sheep_model.rotation.y = lerp_angle(sheep_model.rotation.y, target_yaw, delta * 5.0)

# -------------------------------
# DÉTECTION DES LOUPS
# -------------------------------

func _on_area_safe_body_entered(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var w := body as RigidBody3D
		if not dangerous_wolves.has(w):
			dangerous_wolves.append(w)
		if mode == Mode.WANDER:
			mode = Mode.SAFE
	
	if body.is_in_group("Mouton") and body is RigidBody3D:
		var m := body as RigidBody3D
		if not sheeps_arround.has(m):
			sheeps_arround.append(m)
		if mode == Mode.WANDER:
			mode = Mode.SAFE
	

func _on_area_safe_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var w := body as RigidBody3D
		dangerous_wolves.erase(w)
		# Si on n'est plus en danger "lointain" et pas d'agression, retour à WANDER
		if mode == Mode.SAFE and dangerous_wolves.is_empty() and sheeps_arround.is_empty():
			mode = Mode.WANDER
			
	if body.is_in_group("Mouton") and body is RigidBody3D:
		var m := body as RigidBody3D
		sheeps_arround.erase(m)
		if mode == Mode.SAFE and dangerous_wolves.is_empty() and sheeps_arround.is_empty():
			mode = Mode.WANDER

func _on_area_danger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var w := body as RigidBody3D
		if not close_wolves.has(w):
			close_wolves.append(w)
		mode = Mode.FLEE
	
	if body.is_in_group("Mouton") and body is RigidBody3D:
		var m := body as RigidBody3D
		sheeps_arround.erase(m)



func _on_area_danger_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var w := body as RigidBody3D
		close_wolves.erase(w)
		# S'il n'y a plus de loup dans la zone DANGER, bascule selon la zone SAFE
		if close_wolves.is_empty():
			mode = Mode.SAFE if dangerous_wolves.size() > 0 else Mode.WANDER

# -------------------------------
# COMPORTEMENTS
# -------------------------------

func wander(delta: float) -> void:
	if grazing:
		grazing_timer -= delta
		if grazing_timer <= 0.0:
			grazing = false
			_set_next_graze_time()
		else:
			return # reste immobile pendant le broutage

	# Si pas en train de brouter, compte jusqu'au prochain broutage
	next_graze_time -= delta
	if next_graze_time <= 0.0:
		_start_grazing()
		return
	
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Walk")
	timer -= delta
	if timer <= 0.0:
		var angle = randf() * TAU
		move_dir = Vector3(cos(angle), 0, sin(angle)).normalized()
		timer = direction_change_interval

	apply_central_force(move_dir * wander_speed)
	
func _start_grazing() -> void:
	grazing = true
	grazing_timer = randf_range(2.0, 5.0) # durée de broutage
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Idle_Eating")

# Helper: direction de répulsion résultante contre une liste de loups.
# Somme des vecteurs "loin de chaque loup", pondérée par 1/d² (les plus proches pèsent plus).
# Fallback si neutralisation: direction opposée au loup le plus proche.
func _compute_repulsion_dir(wolves: Array[RigidBody3D]) -> Vector3:
	var dir := Vector3.ZERO
	var closest: RigidBody3D = null
	var closest_d2 := INF
	var d2 = 0.0 
	
	for w in wolves:
		if not is_instance_valid(w):
			continue
		var delta := global_position - w.global_position
		d2 = max(delta.length_squared(), 0.0001)
		dir += delta / d2 # équivalent à direction * (1/d^2)
		if d2 < closest_d2:
			closest_d2 = d2
			closest = w

	# Fallback si directions s'annulent (loups opposés)
	if dir.length_squared() < 1e-6 and closest != null:
		return (global_position - closest.global_position).normalized()

	return dir.normalized()

func safe_avoid_wolves(delta: float) -> void:
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Walk")

	if dangerous_wolves.is_empty() and sheeps_arround.is_empty():
		mode = Mode.WANDER
		return
	
	if dangerous_wolves.is_empty() and not sheeps_arround.is_empty(): 
		var dir : Vector3
		var closest_dist = INF 
		for m in sheeps_arround:
			var dist = global_position - m.global_position
			if dist.length() < closest_dist: 
				closest_dist = dist.length()
				dir = dist 
		

		apply_central_force(dir.normalized() * safe_speed)
	else: 
	
		var base_dir := _compute_repulsion_dir(dangerous_wolves)

		# Ajoute un peu d’aléatoire pour rendre le comportement plus naturel
		var random_angle = randf_range(-0.5, 0.5)
		var rot = Basis(Vector3.UP, random_angle)
		var final_dir = (rot * base_dir).normalized()

		apply_central_force(final_dir * safe_speed)

func flee_from_wolves(delta: float) -> void:
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Run")

	if close_wolves.is_empty():
		mode = Mode.SAFE if dangerous_wolves.size() > 0 else Mode.WANDER
		return

	var flee_dir := _compute_repulsion_dir(close_wolves)

	var v := linear_velocity
	
	if v.length() > 0.1:
		var blended := (flee_dir * 0.7 + v.normalized() * 0.3).normalized()
		flee_dir = blended

	apply_central_force(flee_dir * flee_speed)
