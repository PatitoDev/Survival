extends Node
class_name Game

signal OnMatchRestart;
signal OnGameStateChanged(state: GAME_STATE);

enum GAME_STATE {
	FIGHTING,
	PREPARING_FOR_FIGHT
}

var gameState = GAME_STATE.PREPARING_FOR_FIGHT;

var p1Id = null;
var p2Id = null;

func _ready():
	Network.OnQueueChange.connect(onQueueChange);

func onQueueChange():
	if (p1Id != null and !Network.getClient(p1Id)):
		# player has disconnected
		p1Id = null;

	if (p2Id != null and !Network.getClient(p2Id)):
		# player has disconnected
		p2Id = null;

	if (p2Id == null and p1Id == null):
		gameState = GAME_STATE.PREPARING_FOR_FIGHT;

	if (gameState == GAME_STATE.PREPARING_FOR_FIGHT):
		var lastClient = Network.getLastClientInQueue();
		if (lastClient == null):
			return;
		if (p1Id == null):
			p1Id = lastClient.name;
			if (p1Id != null and p2Id != null):
				gameState = GAME_STATE.FIGHTING;
			return

		if (p2Id == null):
			p2Id = lastClient.name;
			if (p1Id != null and p2Id != null):
				gameState = GAME_STATE.FIGHTING;
			return
