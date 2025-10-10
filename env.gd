extends Node3D


@export var cameras : Array[Camera3D] = [] 
var index = 0 
var mouton = preload("res://mouton.tscn")

func _ready() -> void:
	update_camera()

func update_camera():
	for i in range(cameras.size()):
		cameras[i].current = (i==index)

#func _init() -> void: 
	#for i in range(100):   
		#var m : RigidBody3D = mouton.instantiate()  
		#m.position = Vector3(randf_range(-25, 25), 1, randf_range(-25, 25))  
#
#
		#m.add_to_group("Mouton")
		#
		#add_child(m)  


func _on_button_pressed() -> void:
	index = (index+1)%cameras.size()
	update_camera() 
