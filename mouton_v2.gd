extends RigidBody3D


# --- CONFIGURATION EXPORTS --------------------------------------------------
@export var wander_speed: float = 15.0
@export var flee_speed: float = 30.0
@export var safe_speed: float = 20.0
@export var direction_change_interval: float = 2.0
@export var sang_scene : PackedScene = preload("res://sang.tscn")
@export var loup_scene : PackedScene = preload("res://loup.tscn")


# --- ÉTAT INTERNE ----------------------------------------------------------
var grazing: bool = false
var grazing_timer: float = 0.0
var next_graze_time: float = 0.0

@onready var animation_player = $Sheep_Model/AnimationPlayer
@onready var sheep_model = $Sheep_Model
@onready var label: Label3D = $Label3D   # 🔹 le label à mettre à jour
@onready var champ_de_vision: Area3D = $"Détection"

# 🔹 Couleurs pour chaque état
const COLOR_WANDER = Color(0.8, 0.8, 0.8)   # gris clair
const COLOR_FOLLOW = Color(0.2, 0.6, 1.0)   # bleu
const COLOR_SAFE   = Color(1.0, 0.8, 0.2)   # jaune
const COLOR_FLEE   = Color(1.0, 0.2, 0.2)   # rouge

var loups_lointains: Array[RigidBody3D] = []
var loups_proches: Array[RigidBody3D] = []
var moutons_visibles : Array[RigidBody3D] = []
var moutons_proches : Array[RigidBody3D] = []
var move_dir: Vector3 = Vector3.ZERO
var timer: float = 0.0


func _ready() -> void:
	_set_next_graze_time()
	_update_label("wander", COLOR_WANDER)  # 🔹 initialise le label


func _set_next_graze_time() -> void:
	next_graze_time = randf_range(5.0, 15.0)

# 🔹 Petite fonction utilitaire pour mettre à jour le label
func _update_label(state_name: String, color: Color) -> void:
	label.text = state_name.capitalize()
	label.modulate = color


func _on_area_safe_body_entered(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var l := body as RigidBody3D
		if not loups_lointains.has(l): 
			loups_lointains.append(l)
			return	
		
	
	
	
func _on_area_safe_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var l := body as RigidBody3D
		loups_lointains.erase(l)
		return 
	
	if body.is_in_group("Mouton") and body is RigidBody3D: 
		var m := body as RigidBody3D
		moutons_proches.erase(m)
		return
		


func _on_area_danger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var l := body as RigidBody3D
		if not loups_proches.has(l): 
			loups_proches.append(l)
			return	
	if body.is_in_group("Mouton") and body is RigidBody3D: 
			var m := body as RigidBody3D
			if not moutons_proches.has(m): 
				moutons_proches.append(m)
				return	
			
func _on_area_danger_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var l := body as RigidBody3D
		loups_proches.erase(l)
		return
		

		

func _on_champ_de_vision_body_entered(body: Node3D) -> void:
	if body.is_in_group("Mouton") and body is RigidBody3D: 
		var m := body as RigidBody3D
		if not moutons_visibles.has(m) and not moutons_proches.has(m): 
			moutons_visibles.append(m)
			return
		else:
			return 
	return 

func _on_champ_de_vision_body_exited(body: Node3D) -> void:
	if body.is_in_group("Mouton") and body is RigidBody3D: 
		var m := body as RigidBody3D
		moutons_visibles.erase(m)
		return
	

func _physics_process(delta: float) -> void:
	
	if loups_proches.size() > 0: 
		flee(delta)
	elif loups_lointains.size() > 0: 
		safe(delta)
	elif moutons_visibles.size() > 0 and moutons_proches.size() < moutons_visibles.size():
		follow(delta)
	else: 
		wander(delta)		
	
	if linear_velocity.length() > 0.1:
		var dir = linear_velocity.normalized()
		var target_yaw = atan2(dir.x, dir.z)
		
		sheep_model.rotation.y = lerp_angle(sheep_model.rotation.y, target_yaw, delta * 5.0)	


func _start_grazing() -> void:
	grazing = true
	grazing_timer = randf_range(2.0, 5.0)
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Idle_Eating")


func _compute_repulsion_dir(loups: Array[RigidBody3D]) -> Vector3:
	var dir := Vector3.ZERO
	var closest: RigidBody3D = null
	var closest_d2 := INF
	var d2 = 0.0

	for l in loups:
		if not is_instance_valid(l):
			continue
		var delta := global_position - l.global_position
		d2 = max(delta.length_squared(), 0.0001)
		dir += delta / d2
		if d2 < closest_d2:
			closest_d2 = d2
			closest = l

	if dir.length_squared() < 1e-6 and closest != null:
		return (global_position - closest.global_position).normalized()

	return dir.normalized()


func wander(delta: float): 
	if grazing:
		grazing_timer -= delta
		if grazing_timer <= 0.0:
			grazing = false
			_set_next_graze_time()
		else:
			return

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
	_update_label("wander", COLOR_WANDER)   # 🔹 Label pour wander


func safe(delta: float): 
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Walk")
	_update_label("safe", COLOR_SAFE)       # 🔹 Label pour safe

	if loups_lointains.is_empty(): 
		return
	
	var base_dir := _compute_repulsion_dir(loups_lointains)
	var random_angle = randf_range(-0.5, 0.5)
	var rot = Basis(Vector3.UP, random_angle)
	var final_dir = (rot * base_dir).normalized()

	apply_central_force(final_dir * safe_speed)


func flee(delta: float): 
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Run")
	_update_label("flee", COLOR_FLEE)       # 🔹 Label pour flee

	if loups_proches.is_empty():
		return

	var flee_dir := _compute_repulsion_dir(loups_proches)
	var v := linear_velocity
	if v.length() > 0.1:
		var blended := (flee_dir * 0.7 + v.normalized() * 0.3).normalized()
		flee_dir = blended

	apply_central_force(flee_dir * flee_speed)


func follow(delta: float): 
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Walk")
	_update_label("follow", COLOR_FOLLOW)   # 🔹 Label pour follow

	if moutons_visibles.is_empty():
		return

	var closest: RigidBody3D = null
	var closest_d2 := INF

	for m in moutons_visibles:
		if not is_instance_valid(m) or moutons_proches.has(m):
			continue
		else:
			var d2 := global_position.distance_squared_to(m.global_position)
			if d2 < closest_d2:
				closest_d2 = d2
				closest = m

	if closest == null:
		return

	var dir := (closest.global_position - global_position).normalized()
	var v := linear_velocity
	if v.length() > 0.1:
		dir = (dir * 0.7 + v.normalized() * 0.3).normalized()

	apply_central_force(dir * safe_speed)
