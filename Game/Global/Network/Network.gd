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

func _ready():
	get_window().size = Vector2i(1920 * 1, 1080  * 1);

func _enter_tree():
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
		#var error = peer.create_client("localhost", port);
		var outcome = peer.create_client(url);
		if (outcome == 0):
			print('Connected to websocket server at: ', url);
		else:
			print('Unable to connect to server', url, ' with code: ', outcome);
	multiplayer.multiplayer_peer = peer;

# server
func onClientConnected(id: int):
	print('Client has connected with id: ', id);

func getConnectionsNode():
	return $Connections;

func onClientDisconnected(id: int):
	print('Client has disconnected with id:', id);
	var children = getConnectionsNode().get_children();
	for child in children:
		if (child.name == str(id)):
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
	OnQueueChange.emit();
	NewRegisteredUser.emit(newUserData);

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
