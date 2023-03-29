extends Node

const GAME_DURATION = 60;
@onready var LobbyCharacter = preload("res://Entity/LobbyCharacter/LobbyCharacter.tscn");
@onready var PlayerScene = preload("res://Entity/FighterCharacter/FighterCharacter.tscn");
@onready var ShoeScene = preload("res://Entity/Shoe/Shoe.tscn");
@onready var PlayerSpawner = $CanvasLayer/PlayerSpawner;
@onready var WaitCharacterSpawner = $World/WaitCharacterSpawner;

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
		Network.OnGameWin.connect(_onWin);
		Network.OnSpawnShoe.connect(_onShoeFired);
		Network.OnGameLose.connect(_onLoseCondition);
		Network.OnRemoveShoe.connect(_onShoeRemove);

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
			child.queue_free();
			return;

func _onLoseCondition(id: String):
	call_deferred("onLoseDeffered", id);

func onLoseDeffered(id: String):
	gameState = GAME_STATE.PREPARING_FOR_FIGHT;
	removePlayerFromFight(id);
	Network.moveClientToEnd(id);
	var data = Network.getClient(id);
	createLobbyCharacter(data);
	addFighterIfNeeded();

func _onWin(id: String):
	gameState = GAME_STATE.PREPARING_FOR_FIGHT;
	var players = PlayerSpawner.get_children();
	for player in players:
		if (player.name != id):
			var data = Network.getClient(player.name);
			PlayerSpawner.remove_child(player);
			player.queue_free();
			createLobbyCharacter(data);
			Network.moveClientToEnd(player.name);
	addFighterIfNeeded();

func addFighterIfNeeded():
	print('attempting to add fighter');
	if gameState == GAME_STATE.PREPARING_FOR_FIGHT:
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
			if (playerInScene.name == lastClient.name):
				lastClient = Network.getPreLastClientInQueue();
				if (lastClient == null):
					return true;

		removePlayerFromWaitLobby(lastClient.name);
		var newPlayer = PlayerScene.instantiate();
		newPlayer.name = lastClient.name;
		newPlayer.displayName = lastClient.displayName;
		PlayerSpawner.add_child(newPlayer);
		print('added player to fight');

		if (PlayerSpawner.get_child_count() == 2):
			startFight();
		return true;
	return false;

func startFight():
	gameState = GAME_STATE.FIGHTING;
	startTimer();

func _onUserDisconnect(id: int):
	print('disconnected user call');
	removePlayerFromWaitLobby(str(id));

	var hasRemoved = removePlayerFromFight(str(id));
	if (hasRemoved):
		gameState = GAME_STATE.PREPARING_FOR_FIGHT;

func removePlayerFromWaitLobby(id: String) -> bool:
	var children = WaitCharacterSpawner.get_children();
	for child in children:
		if (child.name == str(id)):
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
		pass
		#$Camera/UI.updateTimeLeft(timer.time_left);

func startTimer():
	timer = get_tree().create_timer(GAME_DURATION);
	await timer.timeout;
	print('game time has run out');
	gameState = GAME_STATE.PREPARING_FOR_FIGHT;

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
