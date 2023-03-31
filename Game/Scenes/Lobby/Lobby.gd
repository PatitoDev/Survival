extends Node2D

@onready var fightBtn = $CanvasLayer/Menu/FormStack/Button;
@onready var menu = $CanvasLayer;
var playerName = '';

func _ready() -> void:
	if (multiplayer.is_server()):
		$CanvasLayer.queue_free();
		$CanvasLayer3.queue_free();
		$CanvasLayer2.queue_free();


func _on_line_edit_text_changed(new_text: String) -> void:
	playerName = new_text;
	fightBtn.disabled = !(new_text.length() > 2);

func _on_button_pressed() -> void:
	Network.setClientName.rpc(playerName);
	menu.queue_free();

func onShoePickerEnd():
	var player = Network.getClient(str(multiplayer.get_unique_id()));
	$CanvasLayer3/TicketHander.setNumber(str(player.userQueueNumber));
