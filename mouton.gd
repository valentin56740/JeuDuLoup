extends RigidBody3D

@export var wander_speed: float = 10.0
@export var direction_change_interval: float = 2.0
@export var flee_speed: float = 20.0
@export var safe_speed: float = 15.0 # vitesse du mode SAFE
@export var safe_distance: float = 30.0 # rayon de sécurité

@export var sang_scene : PackedScene = preload("res://sang.tscn")


var grazing: bool = false
var grazing_timer: float = 0.0
var next_graze_time: float = 0.0

@onready var animation_player = $Sheep_Model/AnimationPlayer 
@onready var sheep_model = $Sheep_Model


var dangerous_wolf: RigidBody3D = null
var close_wolf: RigidBody3D = null

enum Mode { WANDER, SAFE, FLEE } # Les différents mode des moutons 
var mode = Mode.WANDER # Par défaut le mode errement 

var move_dir: Vector3 = Vector3.ZERO
var timer: float = 0.0

var sx: float = 100
var sz: float = 100

func _ready() -> void:
	_set_next_graze_time()

func _set_next_graze_time() -> void:
	next_graze_time = randf_range(5.0, 15.0) # intervalle aléatoire entre 5 et 15s


func _physics_process(delta: float) -> void:
	match mode:
		Mode.FLEE:
			if is_instance_valid(close_wolf):
				flee_from_wolf(close_wolf, delta) # Le mouton se fait agresser par un loup -> il fuit 
			else:
				# Pas d'agression mais le loup reste dans une distance dangeureuse -> Le mouton continue à s'éloigner sans paniquer
				if is_instance_valid(dangerous_wolf): mode = Mode.SAFE 
				else: Mode.WANDER # Le mouton n'est pas inquiété il peut errer tranquillement 

		Mode.SAFE:
			if is_instance_valid(close_wolf):
				mode = Mode.FLEE
			elif is_instance_valid(dangerous_wolf):
				safe_avoid_wolf(dangerous_wolf, delta)
			else:
				mode = Mode.WANDER

		Mode.WANDER:
			if is_instance_valid(close_wolf):
				mode = Mode.FLEE
			elif is_instance_valid(dangerous_wolf):
				mode = Mode.SAFE
			else:
				wander(delta)


	# 🔄 Rotation fluide du modèle vers la direction de déplacement
	if linear_velocity.length() > 0.1:
		var dir = linear_velocity.normalized()
		var target_yaw = atan2(dir.x, dir.z)
		sheep_model.rotation.y = lerp_angle(sheep_model.rotation.y, target_yaw, delta * 5.0)
		
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
		dangerous_wolf = body
		if mode == Mode.WANDER:
			mode = Mode.SAFE

func _on_area_safe_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body == dangerous_wolf:
		dangerous_wolf = null
		if mode == Mode.SAFE:
			mode = Mode.WANDER

func _on_area_danger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Loup"):
		close_wolf = body
		mode = Mode.FLEE

func _on_area_danger_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body == close_wolf:
		close_wolf = null
		mode = Mode.SAFE if is_instance_valid(dangerous_wolf) else Mode.WANDER


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

	
	

func safe_avoid_wolf(wolf: RigidBody3D, delta: float) -> void:
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Walk")
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
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Run")
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





func _on_body_entered(body: Node3D) -> void:
	print("Test1")
	
	if body.is_in_group("Mouton"):  # Vérifie si le corps est un mouton
		print("Test2")
		
		# Instancier la scène de sang
		var sang_instance = sang_scene.instantiate()  # Crée une instance de la scène de sang
		
		# Positionner la scène de sang à la position du mouton
		sang_instance.global_position = body.global_position
		
		# Ajouter l'instance de sang à la scène principale
		get_parent().add_child(sang_instance)  # L'ajoute au parent du mouton (dans la scène principale)
		
		# Supprimer le mouton
		body.queue_free()
