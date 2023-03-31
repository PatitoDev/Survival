extends Node2D


@onready var fxCroutch = preload("res://Entity/FighterCharacter/Audio/fx_agachar.wav");
@onready var fxBlock = preload("res://Entity/FighterCharacter/Audio/fx_block.wav");
@onready var fxBubbleBreak = preload("res://Entity/FighterCharacter/Audio/fx_bubble_breaking_2.wav");
@onready var fxDodge = preload("res://Entity/FighterCharacter/Audio/fx_dodge_1.wav");
@onready var fxHit = preload("res://Entity/FighterCharacter/Audio/fx_hit_1.wav");

enum AUDIO {
	CROUTCH,
	BLOCK,
	BUBBLE_BREAK,
	DODGE,
	HIT
}

func playAudio(id:AUDIO):
	_playAudio.rpc(id);

@rpc('any_peer', 'call_local')
func _playAudio(id):
	match id:
		AUDIO.CROUTCH:
			$AudioStreamPlayer2D.stream = fxCroutch;
		AUDIO.BLOCK:
			$AudioStreamPlayer2D.stream = fxBlock;
		AUDIO.BUBBLE_BREAK:
			$AudioStreamPlayer2D.stream = fxBubbleBreak;
		AUDIO.DODGE:
			$AudioStreamPlayer2D.stream = fxDodge;
		AUDIO.HIT:
			$AudioStreamPlayer2D.stream = fxHit;
	$AudioStreamPlayer2D.play(0);
