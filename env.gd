extends Node3D

var mouton = preload("res://mouton.tscn")

func _init() -> void: 
	for i in range(100):   

		var m : RigidBody3D = mouton.instantiate()
		m.position = Vector3(randf_range(-25,25),1,randf_range(-25,25))
		add_child(m) 
