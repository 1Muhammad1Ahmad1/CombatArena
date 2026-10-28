extends "res://tests/test_suite.gd"
## Diagnostic: can a bot see / hit a player sealed in the test cage?


func _run() -> void:
	await _frames(5)
	main.start_match(2)
	var m = await _wait_match(null)
	_freeze_bots(m, true)
	var p = m.player
	p.spawn_at(m.map.player_spawns[0][0], 0.0)
	p.health.hp = 1.0e9
	await _frames(3)
	var cage := _hide_player(m)
	await _frames(3)
	m.bots[1].bench()
	m.bots[2].bench()
	var b = m.bots[0]
	var pp: Vector3 = p.global_position
	b.global_position = pp + Vector3(0, 0.05, -8)
	b.velocity = Vector3.ZERO
	b.rotation.y = 0.0  # faces -Z... player is at +8 z -> turn around
	b.rotation.y = PI
	b.yaw_target = PI
	await _frames(3)
	var hits := [0]
	p.health.damaged.connect(func(_a, s, _h, f): hits[0] += 1; print("player hit from ", f, " by ", s.name if s else "?"))
	b.ai_enabled = true
	for i in 30:
		await _frames(6)
		print("t=%.1f can_see=%s target=%s state=%d shots=%d player=%s cage=%s" % [i * 0.1, b._can_see(p), b.target.name if b.target else "-", b.state, b.shots_fired, p.global_position, cage.global_position])
	print("hits=", hits[0])
	var eye: Vector3 = b.global_position + Vector3(0, 1.6, 0)
	for pt in p.get_target_points():
		var q := PhysicsRayQueryParameters3D.create(eye, pt, 1, [b.get_rid()])
		print("ray to ", pt, " -> ", m.get_world_3d().direct_space_state.intersect_ray(q))
	get_tree().quit(0)
