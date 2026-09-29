extends Node
## Autoload: high score table + settings, stored with ConfigFile (user:// = app storage).

const MAX_SCORES := 5  # ponytail: menu fits 5 rows; raise with a scrolling list if needed

var path := "user://save.cfg"
var scores: Array = []  # [{name, score}], highest first
var last_name := ""
var sound_enabled := true
var music_enabled := true
var best_score: int:
	get:
		return scores[0].score if scores else 0


func _ready() -> void:
	load_file()


func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return  # first launch: keep defaults
	scores = cfg.get_value("score", "table", [])
	last_name = cfg.get_value("score", "last_name", "")
	sound_enabled = cfg.get_value("settings", "sound", true)
	music_enabled = cfg.get_value("settings", "music", true)


func save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "table", scores)
	cfg.set_value("score", "last_name", last_name)
	cfg.set_value("settings", "sound", sound_enabled)
	cfg.set_value("settings", "music", music_enabled)
	cfg.save(path)


## True if score would make it onto the table.
func qualifies(score: int) -> bool:
	return score > 0 and (scores.size() < MAX_SCORES or score > scores[-1].score)


func add_score(player_name: String, score: int) -> void:
	last_name = player_name
	scores.append({"name": player_name, "score": score})
	scores.sort_custom(func(a, b): return a.score > b.score)
	scores = scores.slice(0, MAX_SCORES)
	save_file()
