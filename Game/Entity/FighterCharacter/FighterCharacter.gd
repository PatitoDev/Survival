extends CharacterBody2D

class_name User

signal OnShoeFire(user: User, spawnPoint: Node2D, color: Color);

enum PLAYER_STATE {
	CROUCHING,
	ATTACKING_FLOOR,
	ATTACKING_AIR,
	STANDING,
	MOVING,
	DEFENDING,
	FALLING,
	THROW_RIGHT,
	THROW_LEFT,
	DEATH
}

enum DIRECTION {
	LEFT,
	RIGHT
}

enum PLAYER_TYPE {
	P1,
	P2
}

const SPEED = 100.0
const JUMP_VELOCITY = -400.0
var SHOE_IMPULSE_FORCE = 600;

@onready var label = $Label;
@onready var Sprite = $Sprite;
@onready var OneShoeSprite = $OneShoe;
@onready var BothShoesSprite = $BothShoes;
@onready var animationTree: AnimationTree = $AnimationTree;
@onready var stateMachine = animationTree["parameters/playback"];
@onready var syncData = $SyncData;
@onready var clientSynchronize = $SyncData/ClientPlayerDataSync;
@onready var shoeSpawnPointer = $MarkerContainer/ShowSpawnerPosition;

var playerState = PLAYER_STATE.STANDING;
var direction = DIRECTION.LEFT;
var shoes = 2;

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var displayName:String;
var playerType = PLAYER_TYPE.P1;

func _ready():
	updateLabel(displayName);
	updateState();
	updateShoes(shoes);
	clientSynchronize.set_multiplayer_authority(name.to_int());

func isPuppet():
	return clientSynchronize.get_multiplayer_authority() != multiplayer.get_unique_id();

func updateLabel(text: String):
	label.text = text;

func updateState():
	updateDirection();
	updateHurtCollision();
	$HurtBox.monitoring = (playerState != PLAYER_STATE.DEFENDING);

	match playerState:
		PLAYER_STATE.STANDING:
			stateMachine.travel("IDLE");
		PLAYER_STATE.ATTACKING_FLOOR:
			stateMachine.travel("Kick");
		PLAYER_STATE.ATTACKING_AIR:
			stateMachine.travel("AttackingDown");
		PLAYER_STATE.CROUCHING:
			stateMachine.travel("Croutch");
		PLAYER_STATE.MOVING:
			stateMachine.travel("Walk");
		PLAYER_STATE.DEFENDING:
			stateMachine.travel("Block");
		PLAYER_STATE.FALLING:
			stateMachine.travel("Falling");
		PLAYER_STATE.THROW_RIGHT:
			stateMachine.travel('ThrowRight');
		PLAYER_STATE.THROW_LEFT:
			stateMachine.travel('ThrowLeft');
		PLAYER_STATE.DEATH:
			stateMachine.travel('OnHurt');

func updateHurtCollision():
	if (playerState == PLAYER_STATE.CROUCHING):
		$HurtBox/HurtCollilsionStanding.disabled = true;
		$HurtBox/HurtCollisionCrouched.disabled = false;
	else:
		$HurtBox/HurtCollilsionStanding.disabled = false;
		$HurtBox/HurtCollisionCrouched.disabled = true;

func updateDirection():
	if (direction == DIRECTION.RIGHT):
		$KickHitBox.transform.x = Vector2(1, 0);
		$MarkerContainer.transform.x = Vector2(1, 0);
		Sprite.scale.x = 1;
		BothShoesSprite.scale.x = 1;
		OneShoeSprite.scale.x = 1;
	else:
		$KickHitBox.transform.x = Vector2(-1, 0);
		$MarkerContainer.transform.x = Vector2(-1, 0);
		Sprite.scale.x = -1;
		BothShoesSprite.scale.x = -1;
		OneShoeSprite.scale.x = -1;

func _physics_process(delta: float) -> void:
	if (isPuppet()):
		applySyncData();
		return;
	updateSyncData();

	# Handle Jump.
	var canMove = (
		playerState != PLAYER_STATE.ATTACKING_FLOOR &&
		playerState != PLAYER_STATE.CROUCHING
	);

	handleMovement(canMove);
	handleInput();

	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
		if !Input.is_action_just_pressed("attack"):
			playerState = PLAYER_STATE.FALLING;

	move_and_slide();
	updateState();

func handleInput():
	if (playerState != PLAYER_STATE.ATTACKING_FLOOR):
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			stateMachine.travel("Jumping");
		if Input.is_action_just_pressed("attack"):
			if (is_on_floor()):
				playerState = PLAYER_STATE.ATTACKING_FLOOR;
			else:
				playerState = PLAYER_STATE.ATTACKING_AIR;
		if Input.is_action_pressed("defend"):
				playerState = PLAYER_STATE.DEFENDING;
		if Input.is_action_pressed("ui_down"):
			playerState = PLAYER_STATE.CROUCHING;
		if Input.is_action_just_pressed("fireShoe"):
			if (playerState != PLAYER_STATE.THROW_LEFT and
				playerState != PLAYER_STATE.THROW_RIGHT):
					if shoes == 2:
						playerState = PLAYER_STATE.THROW_LEFT;
					elif shoes == 1:
						playerState = PLAYER_STATE.THROW_RIGHT;

func addShoe(color: Color):
	if (shoes == 1):
		BothShoesSprite.modulate = color;
	elif (shoes == 0):
		OneShoeSprite.modulate = color;
	updateShoes(shoes + 1);

func updateShoes(shoeAmount: int):
	shoes = shoeAmount;
	if (shoes == 1):
		OneShoeSprite.visible = true;
		BothShoesSprite.visible = false;
	elif (shoes == 2):
		BothShoesSprite.visible = true;
		OneShoeSprite.visible = true;
	else:
		BothShoesSprite.visible = false;
		OneShoeSprite.visible = false;

func handleMovement(canMove: bool):
	var directionVector := Input.get_axis("ui_left", "ui_right")
	if directionVector and canMove:
		playerState = PLAYER_STATE.MOVING;
		velocity.x = directionVector * SPEED
		if (directionVector > 0):
			direction = DIRECTION.RIGHT;
		else:
			direction = DIRECTION.LEFT;
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		playerState = PLAYER_STATE.STANDING;

func applySyncData():
	if (syncData.loaded):
		position = syncData.syncPosition;
		direction = syncData.syncDirection;
		playerState = syncData.syncState;
		updateShoes(syncData.syncShoes);
		BothShoesSprite.modulate = syncData.syncShoeColor1;
		OneShoeSprite.modulate = syncData.syncShoeColor2;
		updateState();

func updateSyncData():
	syncData.syncShoes = shoes;
	syncData.syncPosition = position;
	syncData.syncDirection = direction;
	syncData.syncState = playerState;
	syncData.loaded = true;
	syncData.syncShoeColor1 = BothShoesSprite.modulate;
	syncData.syncShoeColor2 = OneShoeSprite.modulate;

func _on_hurt_box_area_entered(area: Area2D) -> void:
	if (multiplayer.is_server()):
		if (area.is_in_group('shoe') and area.is_in_group('hit')):
			# its a shoe!
			print('has landed');
			Network.notifyLoseCondition(name);
			return;

	if (!isPuppet()):
		return;

	if (!area.is_in_group('hit')):
		return;

	var parent = area.get_parent();
	if ((parent is User and !parent.isPuppet())):
		Network.notifyWin.rpc();

func _on_grab_area_area_entered(area: Area2D) -> void:
	if (isPuppet()):
		return;

	if (area.is_in_group('shoe') and area.is_in_group('grab')):
		var shoe = area.get_parent().get_parent();
		if (!shoe.isBeingFired and shoes < 2):
			addShoe(shoe.getColor());
			Network.removeShoe.rpc(shoe.name);

func onLeftShoeThrow():
	if (isPuppet()):
		return;

	shoes -= 1;
	var shoeColor = $BothShoes.modulate;
	var shoeSpawnPosition = shoeSpawnPointer.global_position;
	var shoeForce = SHOE_IMPULSE_FORCE;
	if (direction == User.DIRECTION.LEFT):
		shoeForce = shoeForce * -1;
	Network.spawnShoe.rpc(shoeSpawnPosition, shoeColor, shoeForce);

func onRightShoeThrow():
	if (isPuppet()):
		return;

	shoes -= 1;
	var shoeColor = $OneShoe.modulate;
	var shoeSpawnPosition = shoeSpawnPointer.global_position;
	var shoeForce = SHOE_IMPULSE_FORCE;
	if (direction == User.DIRECTION.LEFT):
		shoeForce = shoeForce * -1;
	Network.spawnShoe.rpc(shoeSpawnPosition, shoeColor, shoeForce);
