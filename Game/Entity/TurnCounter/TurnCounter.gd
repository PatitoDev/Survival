extends Node2D

var counter = '1';

func _physics_process(delta: float) -> void:
	$Label.text = counter;

func setLabel(data: String):
	counter = data;
