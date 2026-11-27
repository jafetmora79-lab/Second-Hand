extends RichTextEffect
class_name HopText
## Spoken lines appear letter by letter, and each letter hops up and settles as it lands, like the dialogue in The Veil.
## Used as [hop]...[/hop] in a RichTextLabel; restart() before each new line.

var bbcode := "hop"
var rate := 42.0           ## letters a second
var height := 7.0          ## how high a letter hops, in pixels
var hop_time := 0.2        ## how long one hop lasts
var _start := 0.0

func restart() -> void:
	_start = Time.get_ticks_msec() / 1000.0

## Every letter is showing (and done hopping): the line is fully typed out.
func done(letters: int) -> bool:
	return Time.get_ticks_msec() / 1000.0 - _start > float(letters) / rate + hop_time

func finish() -> void:
	_start = -1000.0

func _process_custom_fx(fx: CharFXTransform) -> bool:
	var t := Time.get_ticks_msec() / 1000.0 - _start - float(fx.relative_index) / rate
	if t < 0.0:
		fx.visible = false                                      ## not typed yet
		return true
	if t < hop_time:
		var k := t / hop_time
		fx.offset = Vector2(0.0, -sin(k * PI) * height * (1.0 - k * 0.35))
	return true
