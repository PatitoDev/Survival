extends Node2D

var userDataScene = preload("res://Global/UserData/UserData.tscn");
var peer;
var peerCounter = 0;

var settings = {
	'prd': {
		'url': 'wss://api.niv3kelpato.com/sur',
		'port': 8080
	},
	'dev': {
		'url': 'ws://localhost:7272',
		'port': 7272
	}
};

signal OnGameLose(id: String);
signal OnGameWin(id: String);
signal OnQueueChange(Dictionary);
signal NewRegisteredUser(userData: UserData);
signal DisconnectedUser(id: int);
signal OnSpawnShoe(spawnPosition: Vector2, color: Color, impulse: int);
signal OnRemoveShoe(id: String);
signal OnShoeColorChange(id: String, color: Color, isLeft: bool);

func _ready():
	get_window().size = Vector2i(1920 * 1, 1080  * 1);
	var isServer = "--server" in OS.get_cmdline_args();
	if (isServer):
		loadScore();

func _enter_tree():
	start();

func start():
	var isPrd = "--prd" in OS.get_cmdline_args();
	var isServer = "--server" in OS.get_cmdline_args();
	isPrd = true;

	var settingsData = settings['dev'];
	if (isPrd):
		settingsData = settings['prd'];

	startNetwork(isServer, settingsData['port'], settingsData['url']);


func startNetwork(isServer: bool, port: int, url: String):
	#peer = ENetMultiplayerPeer.new();
	peer = WebSocketMultiplayerPeer.new();

	if (isServer):
		multiplayer.peer_connected.connect(onClientConnected);
		multiplayer.peer_disconnected.connect(onClientDisconnected);
		var outcome = peer.create_server(port);
		if (outcome == 0):
			print('Started server on port ', port);
		else:
			print('Error starting server. Code: ', outcome);
	else:
		multiplayer.connected_to_server.connect(onConnectionToTheServer);
		multiplayer.connection_failed.connect(onConnectionToServerFailed);
		multiplayer.server_disconnected.connect(onConnectionToTheServerLost);
		#var error = peer.create_client("localhost", port);
		var outcome = peer.create_client(url);
		if (outcome == 0):
			print('Trying to connect to server: ', url);
		else:
			print('Unable to connect to server', url, ' with code: ', outcome);
	multiplayer.multiplayer_peer = peer;

func onConnectionToTheServerLost():
	print('lost connection');
	$CanvasLayer.visible = true;
	$CanvasLayer/Label.text = "Lost connection to server D:";
	$CanvasLayer/Label2.text = "";

func onConnectionToTheServer():
	$CanvasLayer.visible = false;
	print('successfully connected to server');

func onConnectionToServerFailed():
	$CanvasLayer.visible = true;
	var timer = get_tree().create_timer(5);
	await timer.timeout;
	start();

# server
func onClientConnected(id: int):
	print('Client has connected with id: ', id);

func getConnectionsNode():
	return $Connections;

func onClientDisconnected(id: int):
	print('Client has disconnected with id:', id);
	var connectionNode = getConnectionsNode();
	var children = connectionNode.get_children();
	for child in children:
		if (child.name == str(id)):
			connectionNode.remove_child(child);
			child.queue_free();
	DisconnectedUser.emit(id);

func getPreLastClientInQueue():
	var values = getConnectionsNode().get_children();
	if (values.size() < 2):
		return null;
	values.sort_custom(func (a, b): return a.userQueueNumber < b.userQueueNumber);
	return values[1];

func getLastClientInQueue():
	var values = getConnectionsNode().get_children();
	if (values.size() < 1):
		return null;
	values.sort_custom(func (a, b): return a.userQueueNumber < b.userQueueNumber);
	return values[0];

func getClient(id: String):
	var children = getConnectionsNode().get_children();
	for child in children:
		if (child.name == id):
			return child;

func getClients():
	return getConnectionsNode().get_children();

func notifyLoseCondition(id: String):
	if (!multiplayer.is_server()):
		return;
	OnGameLose.emit(str(id));

@rpc("any_peer", "call_remote")
func updateShoe(color: Color, isLeft: bool):
	if (!multiplayer.is_server()):
		return

	var id = multiplayer.get_remote_sender_id();
	var data = getClient(str(id));
	if (data == null):
		return;
	if (isLeft):
		data.leftShoeColor = color;
	else:
		data.rightShoeColor = color;
	OnShoeColorChange.emit(str(id), color, isLeft);

var _score = {
};
var ranking = {
	'first': null,
	'second': null,
	'third': null
};

const SAVE_FILE_PATH = "user://score.save";

func saveWin(id: String):
	var player = getClient(id);
	if (player == null):
		return;

	var playerId = player.displayName + "_user";
	if (_score.get(playerId) == null):
		_score[playerId] = {
			'score': 1,
			'playerName': player.displayName
		};
	else:
		_score[playerId]['score'] += 1;
	updateRanking();
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE);
	var toSave = JSON.stringify(_score);
	file.store_string(toSave);
	file.close();

func loadScore():
	if FileAccess.file_exists(SAVE_FILE_PATH):
		print("save file found")
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		var loadedFile: Variant = file.get_as_text();
		file.close();
		var data = JSON.parse_string(loadedFile);
		print(data);
		_score = data;
		updateRanking();
	else:
		print("save file not found")
		_score = {};

func updateRanking():
	var data = _score.values();
	data.sort_custom(func (a,b): return a.score > b.score);
	print('sorted ', data);
	var first = data.pop_front();
	if (first != null):
		ranking['first'] = first;
	var second = data.pop_front();
	if (second != null):
		ranking['second'] = second;
	var third = data.pop_front();
	if (third != null):
		ranking['third'] = third;

@rpc("any_peer", "call_remote")
func notifyWin():
	if (!multiplayer.is_server()):
		return;
	var id = multiplayer.get_remote_sender_id();
	OnGameWin.emit(str(id));

@rpc("any_peer", "call_remote")
func removeShoe(shoeName: String):
	if (!multiplayer.is_server()):
		return;
	OnRemoveShoe.emit(shoeName);

# call from client using rpc
@rpc("any_peer", "call_remote")
func setClientName(displayName: String):
	if (!multiplayer.is_server()):
		return;
	print('New registered user: ', displayName);
	var id = multiplayer.get_remote_sender_id();
	peerCounter += 1;
	var newUserData = userDataScene.instantiate();
	newUserData.name = str(id);
	newUserData.userQueueNumber = peerCounter;
	newUserData.displayName = displayName;
	getConnectionsNode().add_child(newUserData);

@rpc("any_peer", "call_remote")
func setClientColors(left: Color, right:Color):
	if (!multiplayer.is_server()):
		return;
	print('User picked color: ', left, right);
	var id = multiplayer.get_remote_sender_id();
	var data = getClient(str(id));
	if (data == null):
		return;
	data.leftShoeColor = left;
	data.rightShoeColor = right;

@rpc("any_peer", "call_remote")
func spawnUser():
	if (!multiplayer.is_server()):
		return;
	var id = multiplayer.get_remote_sender_id();
	var data = getClient(str(id));
	if (data == null):
		return;
	OnQueueChange.emit();
	NewRegisteredUser.emit(data);

@rpc("any_peer", "call_remote")
func spawnShoe(spawnPosition: Vector2, color: Color, impulse: int):
	if (!multiplayer.is_server()):
		return;
	OnSpawnShoe.emit(spawnPosition, color, impulse);

func moveClientToEnd(id: String):
	var client = getClient(id);
	if (client == null):
		return;
	peerCounter  += 1;
	client.userQueueNumber = peerCounter;
