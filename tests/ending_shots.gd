extends SceneTree
## The three endings, as the player sees them on rent day's close. Run windowed; shots go to tools/shots/ending_*.png.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func run() -> void:
	for case: Array in [["place", 980, 82], ["open", 720, 55], ["last", 410, 60]]:
		var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
		g.seed_override = 5
		g.cinematics = false
		root.add_child(g)
		await wait(1.0)
		g.skip_tutorial()
		g.queue.clear()
		g.day = g.RENT_DAY
		g.money = case[1]
		g.standing = case[2]
		g.week_profit = 455
		g.day_log = {"bought": 1, "sold": 4, "spent": 85, "earned": 610, "profit": 240, "robbed": 0}
		g._end_day()
		await wait(1.2)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://tools/shots/ending_%s.png" % case[0])
		print(case[0], " -> ", g.ending)
		g.queue_free()
		await wait(0.3)
	quit()
