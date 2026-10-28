extends SceneTree
## Diagnostic: AK-74M mesh end profiles (muzzle vs stock) for the bot rifle.

func _init() -> void:
	var inst: Node = load("res://assets/fps_ak74m/scene.gltf").instantiate()
	var mi: MeshInstance3D = inst.find_child("Object_97", true, false)
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for zr in [[-0.43, -0.33], [-0.33, -0.1], [-0.1, 0.15], [0.15, 0.4], [0.4, 0.7], [0.7, 0.86], [0.86, 0.96]]:
		var lo := 9.0; var hi := -9.0; var xl := 9.0; var xh := -9.0; var n := 0
		for p in v:
			if p.z >= zr[0] and p.z < zr[1]:
				lo = min(lo, p.y); hi = max(hi, p.y); xl = min(xl, p.x); xh = max(xh, p.x); n += 1
		print(zr, " n=", n, " y=", snapped(lo, 0.001), "..", snapped(hi, 0.001), " x=", snapped(xl, 0.001), "..", snapped(xh, 0.001))
	inst.free()
	quit()
