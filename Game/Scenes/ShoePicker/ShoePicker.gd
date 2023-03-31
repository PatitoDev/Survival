extends Node2D

var leftColor;
var rightColor;

@onready var rightPicker = $HBoxContainer/RightShoeColorPicker;
@onready var leftPicker = $HBoxContainer/LeftShoeColorPicker;

func _ready():
	$Animation.play('Walk');
	leftColor = leftPicker.color;
	rightColor = rightPicker.color;

func _on_left_shoe_color_picker_color_changed(color: Color) -> void:
	$PlayerSprite/OneShoe.modulate = color;
	leftColor = color;

func _on_right_shoe_color_picker_color_changed(color: Color) -> void:
	$PlayerSprite/BothShoes.modulate = color;
	rightColor = color;

func _on_button_pressed() -> void:
	Network.setClientColors.rpc(leftColor, rightColor);
	self.queue_free();
