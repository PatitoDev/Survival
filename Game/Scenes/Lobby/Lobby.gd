extends Node2D

@onready var stateLabel = $Label;
@onready var fightBtn = $FormStack/Button;
@onready var lobbyControls = $FormStack;

func _ready() -> void:
	Game.OnGameStateChanged.connect(_onStateChange);
	WS.OnHostConfirmation.connect(_onHostConfirmation);
	WS.OnJoinConfirmation.connect(_onJoinConfirmation);

func _onStateChange(state: Game.GAME_STATE):
	match state:
		Game.GAME_STATE.FIGHTING:
			stateLabel.text = 'Spectating. Please wait for the match to end';
			changeToFightScene();
		Game.GAME_STATE.WAITING_FOR_CLIENT:
			visible = true;
			lobbyControls.visible = !Game.isHost();
			stateLabel.text = 'Waiting for client';
		Game.GAME_STATE.WAITING_FOR_HOST:
			visible = true;
			lobbyControls.visible = true;
			stateLabel.text = 'Waiting for host';

func _onHostConfirmation(data: Dictionary):
	var isSuccess = data['data'];
	lobbyControls.visible = false;
	stateLabel.text = 'Waiting for client';

func _onJoinConfirmation(data: Dictionary):
	var isSuccess = data['data'];

func changeToFightScene():
	lobbyControls.visible = false;
	if (!Game.isViewer()):
		# Game has started and we are part of it
		visible = false;

func _on_button_pressed() -> void:
	match Game.currentState:
		Game.GAME_STATE.WAITING_FOR_CLIENT:
			WS.sendEvent('join', { "name": Game.playerName });
		Game.GAME_STATE.WAITING_FOR_HOST:
			WS.sendEvent('host', { "name": Game.playerName });

func _on_line_edit_text_changed(new_text: String) -> void:
	Game.playerName = new_text;
	fightBtn.disabled = !(new_text.length() > 2);
