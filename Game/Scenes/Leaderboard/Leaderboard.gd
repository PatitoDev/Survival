extends Node2D

@rpc("any_peer", "call_local")
func updateLeaderboard():
	var t = get_tree().create_timer(1);
	await t.timeout;
	var data = Network.ranking;
	print(data);
	var first = data['first'];
	if (first != null):
		$FirstPlace.text = str(first.score) + "W " +  first.playerName;
	var second = data['second'];
	if (second != null):
		$SecondPlace.text = str(second.score) + "W " + second.playerName;
	var third = data['third'];
	if (third != null):
		$ThirdPlace.text = str(third.score) + "W " + third.playerName;
