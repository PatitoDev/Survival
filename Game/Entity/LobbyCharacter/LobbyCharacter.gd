extends CharacterBody2D

class_name LobbyCharacter

@onready var synchronizer = $Networking/MultiplayerSynchronizer;
const SPEED = 75.0
const JUMP_VELOCITY = -200.0

enum DIRECTION {
	LEFT,
	RIGHT
}

enum STATE {
	WALKING,
	IDLE
}

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var displayName: String = 'RandomUser23';
var direction: DIRECTION = DIRECTION.LEFT;
var state: STATE = STATE.IDLE;

func _ready():
	$NameLabel.text = displayName;
	synchronizer.set_multiplayer_authority(name.to_int());
	if (name == str(multiplayer.get_unique_id())):
		$Camera2D.enabled = true;

func isPuppet():
	return synchronizer.get_multiplayer_authority() != multiplayer.get_unique_id();

@rpc("any_peer")
func playBoo():
	$AudioStreamPlayer2D.play();

func _physics_process(delta: float) -> void:
	if isPuppet():
		position = $Networking.syncPosition;
		direction = $Networking.syncDirection;
		applyDirection();
		applyState();
		return;

	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("attack") and !$AudioStreamPlayer2D.playing:
		playBoo.rpc();

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var directionVector := Input.get_axis("ui_left", "ui_right")
	if directionVector:
		state = STATE.WALKING;
		$AnimatedSprite2D.play("walking");
		velocity.x = directionVector * SPEED
		if (directionVector > 0):
			direction = DIRECTION.RIGHT;
		else:
			direction = DIRECTION.LEFT;
	else:
		state = STATE.IDLE;
		$AnimatedSprite2D.play("default");
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	applyDirection();

	$Networking.syncPosition = position;
	$Networking.syncVelocity = velocity;
	$Networking.syncDirection = direction;
	$Networking.syncState = state;

func applyState():
	if $Networking.syncState == STATE.IDLE:
		$AnimatedSprite2D.play("default");
	else:
		$AnimatedSprite2D.play("walking");

func applyDirection():
	$AnimatedSprite2D.flip_h = (direction == DIRECTION.LEFT);
