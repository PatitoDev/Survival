extends CharacterBody2D

class_name User

enum PLAYER_STATE {
	CROUCHING,
	ATTACKING,
	STANDING,
	MOVING,
	DEFENDING,
}

enum DIRECTION {
	LEFT,
	RIGHT
}

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@export var isPuppet = false;
@onready var label = $Label;
@onready var Sprite = $Sprite2D;
@onready var animationPlayer = $Animation;

var playerState = PLAYER_STATE.STANDING;
var direction = DIRECTION.LEFT;

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	updateState();

func updateLabel(text: String):
	label.text = text;

func updateState():
	Sprite.flip_h = (direction == DIRECTION.RIGHT);

	match playerState:
		PLAYER_STATE.STANDING:
			Sprite.frame = 0;
		PLAYER_STATE.ATTACKING:
			animationPlayer.play("Kick");
		PLAYER_STATE.CROUCHING:
			Sprite.frame = 1;
		PLAYER_STATE.MOVING:
			Sprite.frame = 0;
		PLAYER_STATE.DEFENDING:
			Sprite.frame = 2;

func _physics_process(delta: float) -> void:
	if (isPuppet):
		return;
	synchronizeData();
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var directionVector := Input.get_axis("ui_left", "ui_right")
	if directionVector:
		velocity.x = directionVector * SPEED
		if (directionVector > 0):
			direction = DIRECTION.RIGHT;
		else:
			direction = DIRECTION.LEFT;

	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	playerState = PLAYER_STATE.STANDING;
	if Input.is_action_just_pressed("attack"):
		playerState = PLAYER_STATE.ATTACKING;
	if Input.is_action_pressed("defend"):
		playerState = PLAYER_STATE.DEFENDING;
	if Input.is_action_pressed("ui_down"):
		playerState = PLAYER_STATE.CROUCHING;
	updateState();

func synchronizeData():
	var data = {
		"name": Game.playerName,
		"playerState": playerState,
		"direction": direction,
		"position" : {
			"x": position.x,
			"y": position.y,
		},
	}

	if (Game.isHost()):
		data.playerType = Game.PLAYER_TYPE.HOST;
	else:
		data.playerType = Game.PLAYER_TYPE.CLIENT;

	WS.sendEvent("game-sync", data);

func _on_hurt_box_area_entered(area: Area2D) -> void:
	if (!isPuppet):
		return;

	if (!area.is_in_group('hit')):
		return;
	var parent = area.get_parent();
	if (parent is User && !parent.isPuppet):
		Game.win();
