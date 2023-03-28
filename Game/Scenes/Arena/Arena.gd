extends Node

const GAME_DURATION = 60;

@onready var PlayerScene = preload("res://Entity/User/User.tscn");
@onready var ShoeScene = preload("res://Entity/Shoe/Shoe.tscn");

var p1;
var p2;
@onready var lobby = $Camera/Lobby;
@onready var PlayerSpawner = $PlayerSpawner;
@onready var Camera = $Camera;

var timer = null;

func _ready():
	WS.OnGameSync.connect(onReceivedSynchronizationData);
	Game.OnGameStateChanged.connect(updateScene);

func _process(delta: float) -> void:
	if (timer):
		pass
		#$Camera/UI.updateTimeLeft(timer.time_left);

func startTimer():
	timer = get_tree().create_timer(GAME_DURATION);
	await timer.timeout;
	print('game time has run out');
	WS.sendEvent('draw');

func updateScene(state):
	var children = PlayerSpawner.get_children();
	for child in children:
		PlayerSpawner.remove_child(child);

	if (Game.currentState == Game.GAME_STATE.WAITING_FOR_HOST):
		Camera.setPlayers();
		if (timer):
			timer.unreference();
			timer = null;
		return;

	if (Game.currentState == Game.GAME_STATE.WAITING_FOR_CLIENT):
		if (timer):
			timer.unreference();
			timer = null;
		p1 = PlayerScene.instantiate();
		PlayerSpawner.add_child(p1);
		p1.isPuppet = !Game.isHost();
		p1.position = Vector2(55, 158);
		p1.direction = User.DIRECTION.RIGHT;
		if (Game.isHost()):
			p1.updateLabel(Game.playerName);
		Camera.setPlayers(p1);
		p1.OnShoeFire.connect(onUserShoeFire);
		return;

	if (Game.currentState == Game.GAME_STATE.FIGHTING):
		p1 = PlayerScene.instantiate();
		PlayerSpawner.add_child(p1);

		p2 = PlayerScene.instantiate();
		PlayerSpawner.add_child(p2);

		p1.isPuppet = Game.isViewer();
		p2.isPuppet = true;

		if (Game.isHost() || Game.isClient()):
			p1.updateLabel(Game.playerName);

		if (Game.isHost()):
			startTimer();
			p1.position = Vector2(55, 158);
			p2.position = Vector2(274, 158);

		if (Game.isClient()):
			p1.position = Vector2(274, 158);
			p2.position = Vector2(55, 158);
		Camera.setPlayers(p1, p2);
		p1.OnShoeFire.connect(onUserShoeFire);
		p2.OnShoeFire.connect(onUserShoeFire);
		return;

func onUserShoeFire(user: User, spawnPointer: Node2D, shoeColor: Color):
	var shoe = ShoeScene.instantiate();
	shoe.position = spawnPointer.global_position;
	shoe.setColor(shoeColor);
	var shoeForce = 600;
	if (user.direction == User.DIRECTION.LEFT):
		shoeForce = shoeForce * -1;
	add_child(shoe);
	shoe.applyImpulse(Vector2(shoeForce, 0));

func onReceivedSynchronizationData(data: Dictionary):
	var playerType = data.content.playerType;
	if (Game.playerType == Game.PLAYER_TYPE.WAITING):
		if (playerType == Game.PLAYER_TYPE.HOST and p1):
			updatePuppet(p1, data.content);
		elif (playerType == Game.PLAYER_TYPE.CLIENT and p2):
			updatePuppet(p2, data.content);
		return;

	if (p2):
		updatePuppet(p2, data.content);

func updatePuppet(who: User, data: Dictionary):
	var pos = data.position;
	var direction = data.direction;
	var playerState = data.playerState;
	var playerName = data.name;

	who.updateLabel(playerName);
	who.position = Vector2(int(pos.x), int(pos.y));
	who.direction = direction;
	who.playerState = int(playerState);
	who.updateState();
