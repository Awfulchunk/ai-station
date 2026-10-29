extends RefCounted
class_name SpriteFactory
## Hand-placed pixel sprites for the deep station. Textures stay nearest-filtered.

const HULL := Color("3c5160")
const HULL_DK := Color("1a2832")
const HULL_LT := Color("8aa4b2")
const BAND := Color("e06a28")
const BAND_DK := Color("a34416")
const INK := Color("070b10")
const GLASS := Color("d5e4ea")
const WARM := Color("f0c56a")
const SEA := Color("071820")


func build() -> Dictionary:
	var station := _station()
	return {
		"water": _tex(_water()),
		"rays": _tex(_rays()),
		"station": _tex(station["image"]),
		"anchors": station["anchors"],
		"sub": _tex(_sub()),
		"kelp": _tex(_kelp_sprite()),
		"fish": [_tex(_fish_a()), _tex(_fish_b()), _tex(_fish_c()), _tex(_squid())],
		"jelly": _tex(_jelly()),
		"bubble": _tex(_bubble()),
		"glow": _tex(_glow(Color("ffe7a8"))),
		"dish": [_tex(_dish(false)), _tex(_dish(true))],
	}


func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if c.a <= 0.0:
		return
	img.set_pixel(x, y, c)


func _rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			_px(img, x, y, c)


func _stamp(img: Image, at: Vector2i, rows: Array, key: Dictionary) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or ch == " ":
				continue
			if key.has(ch):
				_px(img, at.x + x, at.y + y, key[ch])


func _water() -> Image:
	var img := Image.create(400, 180, false, Image.FORMAT_RGBA8)
	for y in 180:
		for x in 400:
			var t := clampf(float(y) / 150.0, 0.0, 1.0)
			var top := Color("0c3c52")
			var deep := Color("061018")
			var c := top.lerp(deep, t)
			var n := _hash(x, y)
			if n > 210:
				c = c.lightened(0.06)
			elif n < 30:
				c = c.darkened(0.08)
			if y < 18 and (x + y * 3) % 17 < 2:
				c = c.lerp(Color("1a6a78"), 0.35)
			var floor_y := _floor_y(x)
			if y >= floor_y:
				var sand := Color("14242a") if n % 2 == 0 else Color("1c3034")
				if y == floor_y:
					sand = Color("2a4448")
				if n > 230 and y > floor_y + 1:
					sand = Color("3a4038")
				c = sand
			if x < 10 or x > 390:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	_kelp_on(img, 18, 96, 34, Color("145c40"))
	_kelp_on(img, 36, 100, 28, Color("0e4834"))
	_kelp_on(img, 360, 94, 36, Color("145c40"))
	_kelp_on(img, 378, 98, 26, Color("0e4030"))
	_crystals(img)
	_ridge(img)
	return img


func _floor_y(x: int) -> int:
	var hump := 0
	if x > 60 and x < 340:
		var u := (float(x) - 200.0) / 140.0
		hump = int((1.0 - u * u) * 10.0)
	return 96 - hump + int(sin(float(x) * 0.17) * 2.0)


func _ridge(img: Image) -> void:
	for x in range(250, 400):
		var h := 8 + int(sin(float(x) * 0.08) * 6.0)
		for y in range(70, 70 + h):
			if img.get_pixel(x, y).a < 0.5:
				continue
			if y < _floor_y(x):
				_px(img, x, y, Color("0a1c28").darkened(0.1))


func _crystals(img: Image) -> void:
	_stamp(img, Vector2i(250, 88), ["..g..", ".ggg.", "ggggg", ".ggg."], {"g": Color("3ddc8a")})
	_stamp(img, Vector2i(308, 90), [".o.", "ooo", ".o.", "o.o"], {"o": Color("e0a040")})
	_stamp(img, Vector2i(292, 92), ["r", "r"], {"r": Color("e25b78")})


func _rays() -> Image:
	var img := Image.create(400, 110, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 5:
		var x0 := 150 + i * 18
		for y in 110:
			var spread := int(float(y) / 18.0)
			for dx in range(-spread, spread + 1):
				var a := 0.10 * (1.0 - float(y) / 110.0)
				_px(img, x0 + dx, y, Color(0.9, 0.85, 0.55, a))
	return img


func _station() -> Dictionary:
	var img := Image.create(248, 84, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_round_rect(img, Rect2i(16, 22, 72, 46), 5, HULL, HULL_DK, HULL_LT)
	for i in 5:
		_rect(img, Rect2i(6, 26 + i * 8, 12, 3), Color("243846"))
		_px(img, 6, 27 + i * 8, HULL_LT)
	_rect(img, Rect2i(34, 30, 14, 30), Color("062018"))
	_rect(img, Rect2i(38, 34, 6, 22), Color("39e696"))
	_rect(img, Rect2i(40, 40, 2, 8), Color("d8ffe8"))
	for y in range(30, 60, 4):
		_px(img, 34, y, Color("8fd8b0"))
		_px(img, 47, y, Color("8fd8b0"))
	_sphere(img, Vector2i(118, 42), 32)
	for x in range(88, 150):
		var y := 42
		if img.get_pixel(x, y).a > 0.5:
			_px(img, x, y, BAND if (x / 2) % 2 == 0 else BAND_DK)
			_px(img, x, y + 1, BAND_DK)
	_round_rect(img, Rect2i(148, 24, 90, 44), 4, HULL, HULL_DK, HULL_LT)
	_rect(img, Rect2i(166, 32, 62, 28), Color("080e14"))
	for x in range(166, 228, 4):
		_px(img, x, 34, Color("1c2830"))
	for x in range(150, 236):
		var stripe := Color("f2c438") if (x / 4) % 2 == 0 else INK
		_px(img, x, 66, stripe)
		_px(img, x, 67, stripe)
	_rect(img, Rect2i(86, 34, 14, 4), Color("6a808c"))
	_rect(img, Rect2i(86, 50, 14, 3), Color("6a808c"))
	_rect(img, Rect2i(142, 40, 10, 4), Color("6a808c"))
	_rect(img, Rect2i(114, 6, 6, 16), HULL_DK)
	for y in range(8, 20, 3):
		_px(img, 113, y, HULL_LT)
		_px(img, 120, y, HULL_LT)
	_rect(img, Rect2i(106, 2, 22, 7), Color("24323c"))
	_rect(img, Rect2i(108, 4, 8, 3), Color("fff1b0"))
	_rect(img, Rect2i(30, 70, 78, 4), HULL_DK)
	_rect(img, Rect2i(154, 70, 78, 4), HULL_DK)
	for x in [30, 100, 154, 224]:
		_rect(img, Rect2i(x, 70, 6, 8), BAND)
		_px(img, x + 2, 76, Color("f2c438"))
	_stamp(img, Vector2i(176, 26), [
		"##...##..##.",
		"#.#.#...#...",
		"#.#..#..###.",
		"#.#...#.#.#.",
		"##..##...#..",
	], {"#": Color("f4e2b0")})
	for bolt in [Vector2i(24, 28), Vector2i(74, 28), Vector2i(24, 58), Vector2i(156, 30), Vector2i(228, 30), Vector2i(228, 58)]:
		_px(img, bolt.x, bolt.y, HULL_LT)
		_px(img, bolt.x + 1, bolt.y, HULL_DK)
	_window(img, Vector2i(104, 38), 5)
	_window(img, Vector2i(120, 32), 4)
	_window(img, Vector2i(136, 42), 5)
	_window(img, Vector2i(118, 52), 4)
	_px(img, 206, 30, Color("f2c438"))
	_px(img, 207, 30, Color("fff1b0"))
	_px(img, 206, 31, Color("a87820"))
	_outline(img, INK)
	return {
		"image": img,
		"anchors": {
			"portholes": [
				{"id": "energy", "at": Vector2(42, 44), "color": Color("39e696")},
				{"id": "control", "at": Vector2(104, 38), "color": Color("7ee7ff")},
				{"id": "storage", "at": Vector2(120, 32), "color": Color("ffe7a8")},
				{"id": "mechanics", "at": Vector2(118, 52), "color": Color("ff9a4a")},
				{"id": "life", "at": Vector2(136, 42), "color": Color("8dffb0")},
				{"id": "sub_bay", "at": Vector2(206, 30), "color": Color("ffe14a")},
			],
			"lamp": Vector2(116, 5),
			"sub_dock": Vector2(174, 38),
			"dish": Vector2(128, 1),
			"reactor": Vector2(41, 44),
		},
	}


func _sphere(img: Image, c: Vector2i, r: int) -> void:
	for y in range(c.y - r - 1, c.y + r + 2):
		for x in range(c.x - r - 1, c.x + r + 2):
			var d := Vector2(x - c.x, y - c.y).length()
			if d > float(r):
				continue
			var col := HULL
			var nx := float(x - c.x) / float(r)
			var ny := float(y - c.y) / float(r)
			if nx < -0.2 and ny < 0.05:
				col = HULL_LT
			elif ny > 0.42 or nx > 0.55:
				col = HULL_DK
			if absi(x - c.x) % 11 == 0 or absi(y - c.y) % 9 == 0:
				col = col.darkened(0.18)
			_px(img, x, y, col)
	_px(img, c.x - 10, c.y - 14, Color("e8f4f8"))
	_px(img, c.x - 9, c.y - 14, Color("e8f4f8"))


func _window(img: Image, c: Vector2i, r: int) -> void:
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var d := Vector2(x - c.x, y - c.y).length()
			if d <= float(r) - 1.2:
				var inner := Color("c4843c")
				if x >= c.x and y <= c.y:
					inner = WARM
				if x == c.x or y == c.y:
					inner = inner.darkened(0.35)
				_px(img, x, y, inner)
			elif d <= float(r):
				_px(img, x, y, GLASS)


func _round_rect(img: Image, r: Rect2i, rad: int, fill: Color, dk: Color, lt: Color) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			if not _in_round(x, y, r, rad):
				continue
			var col := fill
			if y < r.position.y + 3:
				col = lt
			elif y > r.position.y + r.size.y - 5:
				col = dk
			if x % 9 == 0:
				col = col.darkened(0.12)
			_px(img, x, y, col)


func _in_round(x: int, y: int, r: Rect2i, rad: int) -> bool:
	var left := r.position.x
	var top := r.position.y
	var right := r.position.x + r.size.x - 1
	var bottom := r.position.y + r.size.y - 1
	var cx := x
	var cy := y
	if x < left + rad and y < top + rad:
		cx = left + rad
		cy = top + rad
	elif x > right - rad and y < top + rad:
		cx = right - rad
		cy = top + rad
	elif x < left + rad and y > bottom - rad:
		cx = left + rad
		cy = bottom - rad
	elif x > right - rad and y > bottom - rad:
		cx = right - rad
		cy = bottom - rad
	else:
		return true
	return Vector2(x - cx, y - cy).length() <= float(rad)


func _outline(img: Image, color: Color) -> void:
	var copy := img.duplicate()
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if copy.get_pixel(x, y).a > 0.4:
				continue
			var touch := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if copy.get_pixel(nx, ny).a > 0.5:
					touch = true
					break
			if touch:
				img.set_pixel(x, y, color)


func _sub() -> Image:
	var img := Image.create(44, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color("f0c83e")
	var shade := Color("c48a18")
	var hi := Color("fff0a8")
	_stamp(img, Vector2i(4, 3), [
		"...hhhhhh........",
		"..hyyyyyyy.......",
		".hyyyyyyyyyyy....",
		"hyyyyyywwwyyyyy..",
		"hyyyyyywkwwyyyyyp",
		"hyyyyyywwwyyyyy..",
		".hyyyyyyyyyyy....",
		"..ssssssss.......",
	], {
		"h": hi,
		"y": body,
		"s": shade,
		"w": Color("163044"),
		"k": Color("d8f4ff"),
		"p": Color("8a9398"),
	})
	_rect(img, Rect2i(2, 7, 4, 2), Color("e23b3b"))
	_px(img, 40, 8, Color("fff6c8"))
	_px(img, 41, 8, Color("fff6c8"))
	_outline(img, INK)
	return img


func _fish_a() -> Image:
	return _sheet([
		"..ccc....",
		".cccccc..",
		"cccceccc.",
		".ccccccf.",
		"..ccc....",
	], {"c": Color("5ec8c8"), "e": INK, "f": Color("2a8a9a")})


func _fish_b() -> Image:
	return _sheet([
		"...oo....",
		".oooooo..",
		"oooeooo..",
		".ooooof..",
		"..o.o....",
	], {"o": Color("e07a3a"), "e": INK, "f": Color("a84820")})


func _fish_c() -> Image:
	return _sheet([
		".wwww....",
		"wwweww...",
		".wwwwf...",
		"..w.w....",
	], {"w": Color("d8e4ea"), "e": INK, "f": Color("8aa0aa")})


func _squid() -> Image:
	return _sheet([
		"..mmm..",
		".mmmmm.",
		"mmmemmm",
		"m.m.m.m",
		"m.m.m.m",
	], {"m": Color("c46ad8"), "e": Color("fff0c8")})


func _jelly() -> Image:
	return _sheet([
		".jjjjj.",
		"jjjjjjj",
		".j.j.j.",
		"j..j..j",
		".j.j.j.",
	], {"j": Color("9ae0ff")})


func _bubble() -> Image:
	return _sheet([
		".b.",
		"b.b",
		".b.",
	], {"b": Color("cfe8f2")})


func _glow(c: Color) -> Image:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(6.5, 6.5)
	for y in 14:
		for x in 14:
			var d := Vector2(x, y).distance_to(center) / 7.0
			if d <= 1.0:
				var col := c
				col.a = (1.0 - d) * 0.85
				img.set_pixel(x, y, col)
	return img


func _dish(alt: bool) -> Image:
	var rows := [
		"..ddd..",
		".d...d.",
		"d....dd",
		"..ddd..",
	]
	if alt:
		rows = [
			"..ddd..",
			".dd....",
			"d....d.",
			"..ddd..",
		]
	return _sheet(rows, {"d": Color("c5d0d4")})


func _kelp_sprite() -> Image:
	var img := Image.create(18, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_kelp_on(img, 8, 38, 32, Color("1f8a52"))
	return img


func _kelp_on(img: Image, x: int, base: int, height: int, col: Color) -> void:
	var px := x
	for i in height:
		var y := base - i
		px = x + int(sin(float(i) * 0.45) * 3.0)
		_px(img, px, y, col)
		if i % 4 == 0:
			_px(img, px + 2, y, col.lightened(0.15))
			_px(img, px - 2, y - 1, col.darkened(0.1))
			_px(img, px + 3, y - 1, col)


func _sheet(rows: Array, key: Dictionary) -> Image:
	var h := rows.size()
	var w := 1
	for row in rows:
		w = maxi(w, str(row).length())
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_stamp(img, Vector2i.ZERO, rows, key)
	_outline(img, Color("05080c"))
	return img


func _hash(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return (n ^ (n >> 16)) & 255
