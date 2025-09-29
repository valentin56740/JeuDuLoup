extends RigidBody3D

@export var speed: float = 20
@export var direction_change_interval: float = 2.0 # toutes les 2 sec environ

var move_dir: Vector3 = Vector3.ZERO
var timer: float = 0.0

var sx:float = 100
var sz:float = 100 

func _process(delta:float) -> void:
	# décrémente le timer
	timer -= delta
	
	if timer <= 0.0:
		# choisit une nouvelle direction aléatoire
		var angle = randf() * TAU  # angle aléatoire [0..2π] 
		move_dir = Vector3(cos(angle), 0, sin(angle)).normalized() # Vecteur directionnel du mouton 
		timer = direction_change_interval

	# applique une force dans la direction choisie
	apply_central_force(move_dir * speed)
	
	if position.x > sx/2:
		position.x =-sx/2

	if position.x < -sx/2:
		position.x = sx/2


	if position.z > sz/2:
		position.z=-sz/2

	if position.z < -sz/2:
		position.z = sz/2
		

	
