extends Node
## Local players keep audio state independent from the global audio server.
const MUSIC = preload("res://assets/audio/music/coin_rush.ogg")
const EFFECTS := {
	"drop": preload("res://assets/audio/sfx/drop.wav"),
	"land": preload("res://assets/audio/sfx/land.wav"),
	"exchange": preload("res://assets/audio/sfx/exchange.wav"),
	"chain": preload("res://assets/audio/sfx/chain.wav"),
	"cashout": preload("res://assets/audio/sfx/cashout.wav"),
	"game_over": preload("res://assets/audio/sfx/game_over.wav"),
	"ui": preload("res://assets/audio/sfx/ui.wav"),
	"start": preload("res://assets/audio/sfx/start.wav"),
}
const LEVELS := {"drop": -13.0, "land": -17.0, "exchange": -6.0,
	"chain": -6.0, "cashout": -5.0, "game_over": -5.0, "ui": -14.0, "start": -12.0}
# Major pentatonic: each exchange steps upward, regardless of denomination.
const CHAIN_SEMITONES := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var muted := false
var suspended := false
var next_voice := 0
var landing_cooldown := 0.0
var result_mode := false
var music_level := -10.0
var music_tween: Tween

func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.name = "Music"
	add_child(music)
	var stream := MUSIC.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	music.stream = stream
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	set_muted(muted)

func _process(delta: float) -> void:
	if not suspended:
		landing_cooldown = maxf(0, landing_cooldown - delta)

func restart() -> void:
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	result_mode = false
	_set_music_level(-10.0)
	stop_effects()
	set_suspended(false)
	landing_cooldown = 0
	# Retrying resumes the existing timeline, including from pause or results.
	if music.stream and not music.playing:
		music.play(0)

func stop_effects() -> void:
	for voice in voices:
		voice.stop()

func set_muted(value: bool) -> void:
	muted = value
	# Keep the music timeline running while muted so unmuting feels continuous.
	_set_music_level(music_level)
	if muted:
		stop_effects()

func set_suspended(value: bool) -> void:
	suspended = value
	music.stream_paused = value
	for voice in voices:
		voice.stream_paused = value

func play_effect(event: String, pitch: float = 1.0) -> void:
	if muted or suspended:
		return
	# Reserve the last voice for cash-out and game-over so impacts cannot cut them off.
	var important := event == "cashout" or event == "game_over"
	var slot := voices.size() - 1 if important else next_voice
	if not important:
		next_voice = (next_voice + 1) % (voices.size() - 1)
	var voice := voices[slot]
	voice.stop()
	voice.stream = EFFECTS[event]
	voice.pitch_scale = pitch
	voice.volume_db = LEVELS[event]
	voice.play()

func landing(tier: int) -> void:
	if landing_cooldown > 0 or muted or suspended:
		return
	landing_cooldown = 0.07
	play_effect("land", 1.15 - tier * 0.06)

func exchange(tier: int, chain: int) -> void:
	var step: int = CHAIN_SEMITONES[clampi(chain - 1, 0, CHAIN_SEMITONES.size() - 1)]
	var pitch := pow(2.0, step / 12.0)
	if tier == 5:
		play_effect("cashout", pitch)
	elif chain > 1:
		play_effect("chain", pitch)
	else:
		play_effect("exchange", pitch)

func game_over() -> void:
	result_mode = true
	set_suspended(false)
	stop_effects()
	play_effect("game_over")
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	music_tween = create_tween()
	music_tween.tween_method(_set_music_level, music_level, -13.0, 0.4)

func _set_music_level(level: float) -> void:
	music_level = level
	music.volume_db = -80.0 if muted else level
