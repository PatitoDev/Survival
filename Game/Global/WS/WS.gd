extends Node

@export var url = "ws://localhost:9999";
#@export var url = "wss://api.niv3kelpato.com";
var client = WebSocketPeer.new();

signal GenericMessage(data: Dictionary);
signal OnConnection;
signal OnStateChanged(data: Dictionary);
signal OnJoinConfirmation(data: Dictionary);
signal OnHostConfirmation(data: Dictionary);
signal OnGameSync(data: Dictionary);
signal OnPing(data: Dictionary);
signal OnMatchOutcome(data: Dictionary);

var hasConnected = false;

var messageDictionary = {
	'join-confirmation': OnJoinConfirmation,
	'host-confirmation': OnHostConfirmation,
	'state-changed': OnStateChanged,
	'game-sync': OnGameSync,
	'ping': OnPing,
	'match-outcome': OnMatchOutcome
}

func _process(delta):
	client.poll()
	var state = client.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if (!hasConnected):
			onConnected();
		while client.get_available_packet_count():
			onReceivedData(client.get_packet());
	elif state == WebSocketPeer.STATE_CLOSING:
		print('closing ws');
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = client.get_close_code()
		var reason = client.get_close_reason()
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false)

func _ready():
	get_window().size = Vector2i(1920 * 1, 1080  * 1);
	var err = client.connect_to_url(url);
	if err != OK:
		print("Unable to connect");
		set_process(false);
	OnPing.connect(onPing);

func onConnected():
	hasConnected = true;
	print("Connected to ws");
	OnConnection.emit();

func onPing(data: Dictionary):
	sendEvent('pong');

func onReceivedData(payload: PackedByteArray):
	var message = payload.get_string_from_utf8()
	var data = JSON.parse_string(message);
	var type:String = data["type"];
	var event = messageDictionary.get(type);
	if (event == null):
		return;
	event.emit(data);
	GenericMessage.emit(data);

func sendEvent(type: String, content = null):
	var payload = {
		"type": type,
	};

	if (content != null):
		payload['content'] = content;

	var msg = JSON.stringify(payload);
	client.send_text(msg);

func _on_timer_timeout() -> void:
	if (hasConnected):
		sendEvent('pong');
