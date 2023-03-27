class_name Shoe

extends Node2D


func applyImpulse(impulse: Vector2):
	$RigidBody.apply_impulse(impulse);
