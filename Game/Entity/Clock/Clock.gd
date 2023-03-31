extends Node2D

var time = 60;

func _physics_process(delta: float) -> void:
	$Label.text = str(time);
