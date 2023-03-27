extends Camera2D

var DEFAULT_POSITION = Vector2(160, 90);

var targetPosition = DEFAULT_POSITION;
var SPEED = 2;
var p1: Node2D = null;
var p2: Node2D = null;

func setPlayers(p1: Node2D = null, p2: Node2D = null):
	self.p1 = p1;
	self.p2 = p2;

func _physics_process(delta: float) -> void:
	if (p1 == null and p2 == null):
		targetPosition = DEFAULT_POSITION;

	if (p1 != null):
		targetPosition.x = p1.position.x;

	if (p1 != null and p2 != null):
		targetPosition.x = p1.position.x + ((p2.position.x - p1.position.x) / 2);


	position = position.move_toward(targetPosition, SPEED);


