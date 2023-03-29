class_name Shoe

extends Node2D

@onready var initialPosition;
@onready var rigidBody:RigidBody2D = $RigidBody;
@export var shoeColor: Color = Color.DARK_GOLDENROD;
@onready var syncData = $RigidBody/SyncData;

var isBeingFired = true;

func _ready():
	if (initialPosition != null):
		setPosition(initialPosition);
	setColor(shoeColor);

	if (!multiplayer.is_server()):
		$RigidBody.freeze = true;
		$RigidBody/HitBox.monitorable = false;

func setColor(color: Color):
	$RigidBody/Shoe.modulate = color;
	shoeColor = color;

func getColor():
	return $RigidBody/Shoe.modulate;

func applyImpulse(impulse: Vector2):
	isBeingFired = true;
	$RigidBody/HitBox.monitorable = true;
	rigidBody.apply_impulse(impulse);

func setPosition(pos: Vector2):
	$RigidBody.freeze = true;
	rigidBody.position = pos;
	$RigidBody.freeze = false;

func _physics_process(delta: float) -> void:
	if (!multiplayer.is_server()):
		applySyncData();
		return;

	if (
		rigidBody.linear_velocity.x > 50 or
		rigidBody.linear_velocity.y > 50
		):
		$RigidBody/HitBox.monitorable = true;
		isBeingFired = true;
	else:
		$RigidBody/HitBox.monitorable = false;
		isBeingFired = false;
	updateSyncData();

func applySyncData():
	if (!syncData.hasLoaded):
		return
	rigidBody.global_position = syncData.syncPosition;
	setColor(syncData.color);
	rigidBody.rotation = syncData.syncRotation;
	isBeingFired = syncData.syncIsBeingFired;

func updateSyncData():
	syncData.syncPosition = rigidBody.global_position;
	syncData.color = shoeColor;
	syncData.syncRotation = rigidBody.rotation;
	syncData.syncIsBeingFired = isBeingFired;
	syncData.hasLoaded = true;
