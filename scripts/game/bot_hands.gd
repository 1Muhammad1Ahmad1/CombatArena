extends SkeletonModifier3D
## Runs after the bot's animation each frame: places the rifle from the animated
## hands, then bends the left arm (two-bone IK) so the left hand sits on the
## handguard instead of floating near it.

var bot: Node


func _process_modification() -> void:
	if bot and bot.visible:
		bot._hands_modify(get_skeleton())
