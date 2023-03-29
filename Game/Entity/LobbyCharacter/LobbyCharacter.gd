extends CharacterBody2D

@onready var synchronizer = $Networking/MultiplayerSynchronizer;
const SPEED = 50.0
const JUMP_VELOCITY = -100.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var displayName: String = 'RandomUser23';

func _ready():
	$NameLabel.text = displayName;
	synchronizer.set_multiplayer_authority(name.to_int());
	if (name == str(multiplayer.get_unique_id())):
		$Camera2D.enabled = true;

func isPuppet():
	return synchronizer.get_multiplayer_authority() != multiplayer.get_unique_id();

func _physics_process(delta: float) -> void:
	if isPuppet():
		position = $Networking.syncPosition;
		return;

	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		$AnimatedSprite2D.play("walking");
		velocity.x = direction * SPEED
	else:
		$AnimatedSprite2D.play("default");
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	$Networking.syncPosition = position;
	$Networking.syncVelocity = velocity;
