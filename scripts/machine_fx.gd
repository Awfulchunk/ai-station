extends Node2D
class_name MachineFx
## C overlays: steam, heat shimmer, drips, core glow, stack smoke — looping.
## Positions remapped to cutaway room layout (R01–R09).

func _ready() -> void:
	_spawn_all()

func _spawn_all() -> void:
	# R01 AI core glow — D2 center ~ (880, 330)
	_add_anim("core_glow", Vector2(880, 330), 8, 0.12, Vector2(1.8, 1.8), Color(1,1,1,0.85))
	_add_anim("core_glow", Vector2(880, 330), 8, 0.18, Vector2(1.1, 1.1), Color(0.6,0.9,1,0.5))

	# Stack smoke — red towers still in row1 silhouette
	_add_anim("smoke", Vector2(400, 140), 6, 0.15, Vector2(1.8, 2.0), Color(1,1,1,0.92))
	_add_anim("smoke", Vector2(1180, 130), 6, 0.14, Vector2(1.7, 1.9), Color(1,1,1,0.92))

	# Heat — R02 power + R04 refinery
	_add_anim("heat", Vector2(400, 320), 4, 0.1, Vector2(1.5, 1.5), Color(1,1,1,0.85))
	_add_anim("heat", Vector2(1120, 330), 4, 0.11, Vector2(1.4, 1.4), Color(1,1,1,0.8))

	# Steam — refinery / biology / intake
	_add_anim("steam", Vector2(160, 340), 6, 0.13, Vector2(1.4, 1.5), Color(1,1,1,0.85))
	_add_anim("steam", Vector2(1120, 360), 6, 0.14, Vector2(1.2, 1.3), Color(1,1,1,0.85))
	_add_anim("steam", Vector2(880, 480), 6, 0.15, Vector2(1.0, 1.1), Color(1,1,1,0.75))

	# Water drips — ocean intake / pontoon / sub dock
	_add_anim("drip", Vector2(160, 540), 5, 0.14, Vector2(1.2, 1.2), Color(1,1,1,0.8))
	_add_anim("drip", Vector2(400, 555), 5, 0.16, Vector2(1.0, 1.0), Color(1,1,1,0.92))
	_add_anim("drip", Vector2(800, 570), 5, 0.15, Vector2(1.1, 1.1), Color(1,1,1,0.9))
	_add_anim("drip", Vector2(1300, 550), 5, 0.13, Vector2(1.0, 1.0), Color(1,1,1,0.85))

	# Room lamps
	_add_anim("lamp", Vector2(400, 280), 2, 0.4, Vector2(1.4, 1.4), Color(1,1,1,0.9))
	_add_anim("lamp", Vector2(880, 280), 2, 0.45, Vector2(1.5, 1.5), Color(1,1,1,0.85))
	_add_anim("lamp", Vector2(1360, 300), 2, 0.5, Vector2(1.3, 1.3), Color(1,1,1,0.8))

func _add_anim(sheet: String, pos: Vector2, frame_count: int, speed: float, scale_v: Vector2, modulate_c: Color) -> void:
	var path := "res://assets/fx/%s.png" % sheet
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("FX missing: " + path)
		return
	var frames := SpriteFrames.new()
	frames.add_animation("loop")
	frames.set_animation_loop("loop", true)
	frames.set_animation_speed("loop", 1.0 / maxf(speed, 0.01))
	var fw := int(tex.get_width() / frame_count)
	var fh := int(tex.get_height())
	for i in frame_count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame("loop", at)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.position = pos
	spr.scale = scale_v
	spr.modulate = modulate_c
	spr.z_index = 10
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)
	spr.play("loop")
