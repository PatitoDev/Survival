extends Node

signal OnMatchRestart;
signal OnGameStateChanged(state: GAME_STATE);

var playerType = PLAYER_TYPE.WAITING;

enum PLAYER_TYPE {
	HOST,
	CLIENT,
	WAITING,
}

enum GAME_STATE {
	WAITING_FOR_CLIENT,
	WAITING_FOR_HOST,
	FIGHTING,
}

var currentState = GAME_STATE.WAITING_FOR_HOST;
var playerName = "";

func _ready():
	WS.OnJoinConfirmation.connect(onJoinConfirmation);
	WS.OnHostConfirmation.connect(onHostConfirmation);
	WS.OnStateChanged.connect(_onStateChange);
	WS.OnMatchOutcome.connect(_onMatchOutcome);

func _onStateChange(data: Dictionary):
	var gameState = data['data']['state'];
	print('changed state to ', gameState);
	match gameState:
		'fighting':
			currentState = GAME_STATE.FIGHTING;
		'waiting-for-client':
			currentState = GAME_STATE.WAITING_FOR_CLIENT;
		'waiting-for-host':
			currentState = GAME_STATE.WAITING_FOR_HOST;
	OnGameStateChanged.emit(currentState);

func _onMatchOutcome(data: Dictionary):
	var hostWin = data['hostWin'];
	var clientWin = data['clientWin'];
	var hasWon = (Game.isClient() && clientWin) || (Game.isHost() && hostWin);

	if (hasWon):
		print('we have won');
		currentState = GAME_STATE.WAITING_FOR_CLIENT;
		playerType = PLAYER_TYPE.HOST;
	else:
		playerType = PLAYER_TYPE.WAITING;

		if (clientWin || hostWin):
			print('enemy has won');
			currentState = GAME_STATE.WAITING_FOR_CLIENT;
		else:
			print('none has won');
			currentState = GAME_STATE.WAITING_FOR_HOST;

	OnGameStateChanged.emit(currentState);

func win():
	WS.sendEvent('win');

func isHost():
	return playerType == PLAYER_TYPE.HOST;

func isClient():
	return playerType == PLAYER_TYPE.CLIENT;

func isViewer():
	return playerType == PLAYER_TYPE.WAITING;

func onJoinConfirmation(data: Dictionary):
	print('set player as client');
	playerType = PLAYER_TYPE.CLIENT;
	currentState = GAME_STATE.FIGHTING;
	OnGameStateChanged.emit(currentState);

func onHostConfirmation(data: Dictionary):
	print('set player as host');
	playerType = PLAYER_TYPE.HOST;
	currentState = GAME_STATE.WAITING_FOR_CLIENT;
	OnGameStateChanged.emit(currentState);
