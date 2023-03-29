extends Node2D

class_name UserData;

var displayName = 'random_user';
var userQueueNumber = 0;


func _ready():
	#$MultiplayerSynchronizer.set_multiplayer_authority(name.to_int());
	pass;

func _getDisplayName():
	return  $Data.sync_displayName;

func setDisplayName(newName: String):
	$Data.syncDisplayName = newName;
