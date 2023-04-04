extends Node

@onready var LobbyCharacter = preload("res://Entity/LobbyCharacter/LobbyCharacter.tscn");
@onready var PlayerScene = preload("res://Entity/FighterCharacter/FighterCharacter.tscn");
@onready var ShoeScene = preload("res://Entity/Shoe/Shoe.tscn");
@onready var PlayerSpawner = $CanvasLayer/PlayerSpawner;
@onready var WaitCharacterSpawner = $World/WaitCharacterSpawner;

const GAME_DURATION = 60;

enum GAME_STATE {
	FIGHTING,
	PREPARING_FOR_FIGHT
}

var gameState = GAME_STATE.PREPARING_FOR_FIGHT;

var timer = null;

func _ready():
	if multiplayer.is_server():
		Network.NewRegisteredUser.connect(_onNewUser);
		Network.DisconnectedUser.connect(_onUserDisconnect);
		Network.OnSpawnShoe.connect(_onShoeFired);
		Network.OnGameLose.connect(_onLoseCondition);
		Network.OnRemoveShoe.connect(_onShoeRemove);
		Network.OnShoeColorChange.connect(_onShoeColorChange);

func updateLeaderboard():
	$World/Leaderboard.updateLeaderboard();

# execute server
func _onNewUser(data: UserData):
	var hasCreated = addFighterIfNeeded();
	if (hasCreated):
		return;
	createLobbyCharacter(data);

func createLobbyCharacter(data: UserData):
	var character = LobbyCharacter.instantiate();
	character.name = str(data.name);
	character.displayName = data.displayName;
	WaitCharacterSpawner.add_child(character);

func _onShoeRemove(id: String):
	var children = $CanvasLayer/ShoeSpawner.get_children();
	for child in children:
		if (child.name == id):
			$CanvasLayer/ShoeSpawner.remove_child(child);
			child.queue_free();
			return;

func _onLoseCondition(id: String):
	playWinAnimation.rpc();
	lostBy = id;
	if timer != null:
		timer.timeout.disconnect(whenTimerEnds);

@rpc("any_peer", "call_local")
func playWinAnimation():
	print('received win animation play');
	$AnimationPlayer.stop();
	$AnimationPlayer.play("Win");

var lostBy = null;

func onDrawAnimationEnd():
	if (!multiplayer.is_server()):
		return;
	print('win animation end');

	print('draw end');
	var players = PlayerSpawner.get_children();
	for player in players:
		PlayerSpawner.remove_child(player);
		player.queue_free();
		Network.moveClientToEnd(player.name);
		var data = Network.getClient(player.name);
		createLobbyCharacter(data);
	cleanShoes();
	gameState = GAME_STATE.PREPARING_FOR_FIGHT;
	addFighterIfNeeded();
	addFighterIfNeeded();

func onWinAnimationEnd():
	#only run this at server
	if (!multiplayer.is_server()):
		return

	if (lostBy == null):
		return;

	gameState = GAME_STATE.PREPARING_FOR_FIGHT;
	removePlayerFromFight(lostBy);
	Network.moveClientToEnd(lostBy);

	#get winner
	var winner = null;
	var children = PlayerSpawner.get_children();
	for child in children:
		if child.name != lostBy:
			winner = child.name;
	if (winner != null):
		Network.saveWin(winner);
	var data = Network.getClient(lostBy);
	createLobbyCharacter(data);
	addFighterIfNeeded();
	cleanShoes();
	lostBy = null;
	$World/Leaderboard.updateLeaderboard.rpc();

func cleanShoes():
	var children = $CanvasLayer/ShoeSpawner.get_children();
	for child in children:
		$CanvasLayer/ShoeSpawner.remove_child(child);
		child.queue_free();

func addFighterIfNeeded():
	print('attempting to add fighter');
	if gameState != GAME_STATE.PREPARING_FOR_FIGHT:
		print('already fightinting???');
		return false;
	var players = PlayerSpawner.get_children();
	players = players.filter(func (player): return !player.is_queued_for_deletion());
	var playersToDelete = players.filter(func (player): return player.is_queued_for_deletion());
	print(players);

	if (players.size() >= 2):
		print('already have 2 players');
		return false;

	var lastClient = Network.getLastClientInQueue();
	if (lastClient == null):
		return false;

	print('is empty', players.is_empty());
	if (!players.is_empty()):
		print('not empty');
		var playerInScene = players[0];
		playerInScene.changeStateRemotely.rpc(User.PLAYER_STATE.STANDING);
		if (playerInScene.name == lastClient.name):
			lastClient = Network.getPreLastClientInQueue();
			if (lastClient == null):
				return true;

	removePlayerFromWaitLobby(lastClient.name);
	var newPlayer = PlayerScene.instantiate();
	newPlayer.name = lastClient.name;
	newPlayer.displayName = lastClient.displayName;
	newPlayer.leftShoeColor = lastClient.leftShoeColor;
	newPlayer.rightShoeColor = lastClient.rightShoeColor;
	PlayerSpawner.add_child(newPlayer);
	print('added player to fight');

	if (PlayerSpawner.get_child_count() == 2):
		startFight();
	return true;

func _onShoeColorChange(id: String, color: Color, isLeft: bool):
	var children = PlayerSpawner.get_children();
	for child in children:
		if (child.name == id):
			if (isLeft):
				child.leftShoeColor = color;
			else:
				child.rightShoeColor = color;
			return;

func startFight():
	gameState = GAME_STATE.FIGHTING;
	startTimer.rpc();
	var data = Network.getLastClientInQueue();
	if (data != null):
		$World/TurnCounter.setLabel(str(data.userQueueNumber));

func _onUserDisconnect(id: int):
	print('disconnected user call');
	removePlayerFromWaitLobby(str(id));

	var hasRemoved = removePlayerFromFight(str(id));
	if (hasRemoved):
		gameState = GAME_STATE.PREPARING_FOR_FIGHT;
		addFighterIfNeeded();

func removePlayerFromWaitLobby(id: String) -> bool:
	var children = WaitCharacterSpawner.get_children();
	for child in children:
		if (child.name == str(id)):
			WaitCharacterSpawner.remove_child(child);
			child.queue_free();
			return true;
	return false;

func removePlayerFromFight(id: String) -> bool:
	var children = PlayerSpawner.get_children();
	for child in children:
		if (child.name == str(id)):
			PlayerSpawner.remove_child(child);
			child.queue_free();
			return true;
	return false;

func _process(delta: float) -> void:
	if (timer):
		$World/Clock.time = max(floor(timer.time_left), 0);

@rpc("any_peer", "call_local")
func startTimer():
	timer = get_tree().create_timer(GAME_DURATION);
	timer.timeout.connect(whenTimerEnds);

func whenTimerEnds():
	if (!multiplayer.is_server()):
		return;

	if (lostBy != null):
		return;
	print('game time has run out');
	$AnimationPlayer.play('Draw');
	var children = PlayerSpawner.get_children();
	for child in children:
		child.changeStateRemotely.rpc(User.PLAYER_STATE.DEATH);

var shoeCounter = 0;

func _onShoeFired(spawnPosition: Vector2, color: Color, impulse: int):
	print('shoe has fired');
	var shoe = ShoeScene.instantiate();
	shoeCounter += 1;
	shoe.name = 'shoe' + str(shoeCounter);
	shoe.initialPosition = spawnPosition;
	shoe.setColor(color);
	$CanvasLayer/ShoeSpawner.add_child(shoe, true);
	shoe.applyImpulse(Vector2(impulse, 0));
