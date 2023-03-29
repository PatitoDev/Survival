extends Node2D

var userDataScene = preload("res://Global/UserData/UserData.tscn");
var peer;
var peerCounter = 0;

@export var port = 4242;

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
	startNetwork("--server" in OS.get_cmdline_args())

func startNetwork(isServer: bool):
	peer = ENetMultiplayerPeer.new();

	if (isServer):
		print('started server');
		multiplayer.peer_connected.connect(onClientConnected);
		multiplayer.peer_disconnected.connect(onClientDisconnected);
		var error = peer.create_server(port);
		if (error):
			print('error starting server ', error);
	else:
		print('started client');
		var error = peer.create_client("localhost", port);
		if (error):
			print('error when connecting to server ', error);
	multiplayer.multiplayer_peer = peer;

# server
func onClientConnected(id: int):
	print('client connected: ', id);

func getConnectionsNode():
	return $Connections;

func onClientDisconnected(id: int):
	print('client disconnected:', id);
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
	print('executed lose condition', id);
	OnGameLose.emit(str(id));

@rpc("any_peer", "call_remote")
func notifyWin():
	if (!multiplayer.is_server()):
		return;
	var id = multiplayer.get_remote_sender_id();
	print('executed rpc call win condition', id);
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
	var id = multiplayer.get_remote_sender_id();
	print('executed rpc call to update name from', id);
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
