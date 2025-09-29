extends RigidBody3D
@export var force = 15

var sx:float = 50
var sz:float = 50 

func _process(delta:float) -> void:
	var fz = randf()-0.5 
	var fx = randf()-0.5 
	apply_central_force( Vector3(force,0,fx))
	
	if position.x > sx/2:
		position.x =-sx/2

	if position.x < -sx/2:
		position.x = sx/2


	if position.z > sz/2:
		position.z=-sz/2

	if position.z < -sz/2:
		position.z = sz/2
		

	
