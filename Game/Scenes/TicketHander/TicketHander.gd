extends Node2D


func setNumber(number: String):
	$TicketArray/TicketContainer/Label.text = number;
	$AnimationPlayer.play("ticket");

func onAnimationFinish():
	self.queue_free();
	Network.spawnUser.rpc();
