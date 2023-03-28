class_name Shoe

extends Node2D

@onready var rigidBody:RigidBody2D = $RigidBody;
@export var shoeColor: Color = Color.DARK_GOLDENROD;

var isBeingFired = true;

func _ready():
	setColor(shoeColor);

func setColor(color: Color):
	$RigidBody/Shoe.modulate = color;

func getColor():
	return $RigidBody/Shoe.modulate;

func applyImpulse(impulse: Vector2):
	isBeingFired = true;
	$RigidBody/HitBox.monitorable = true;
	rigidBody.apply_impulse(impulse);

func _physics_process(delta: float) -> void:
	if (
		rigidBody.linear_velocity.x < 10 &&
		rigidBody.linear_velocity.y < 10
		):
		$RigidBody/HitBox.monitorable = false;
		isBeingFired = false;
