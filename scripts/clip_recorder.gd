class_name ClipRecorder
extends RefCounted
## Records the slow-motion replay into two Motion-JPEG .avi files (landscape + 9:16 vertical for TikTok/Shorts).
## AVI/MJPEG is written by hand: no ffmpeg needed and it opens in VLC, Windows players and video editors.

const FPS := 30
const W := 960
const H := 540
const VW := 540
const VH := 960

var frames: Array[PackedByteArray] = []
var vframes: Array[PackedByteArray] = []
var _acc := 0.0


func clear() -> void:
	frames.clear()
	vframes.clear()
	_acc = 0.0


## Call every frame while recording; grabs at most FPS frames per second.
func capture(img: Image, delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / FPS or img == null or frames.size() > FPS * 20:
		return
	_acc = 0.0
	var land := img.duplicate()
	land.resize(W, H, Image.INTERPOLATE_BILINEAR)
	frames.append(land.save_jpg_to_buffer(0.85))
	# vertical: centre crop with 9:16 aspect, scaled to 540x960
	var cw := int(img.get_height() * 9.0 / 16.0)
	var vert := img.get_region(Rect2i((img.get_width() - cw) / 2, 0, cw, img.get_height()))
	vert.resize(VW, VH, Image.INTERPOLATE_BILINEAR)
	vframes.append(vert.save_jpg_to_buffer(0.85))


## Writes both clips; returns their absolute paths (empty if nothing was captured).
func save(dir: String, stem: String) -> Array:
	if frames.is_empty():
		return []
	DirAccess.make_dir_recursive_absolute(dir)
	var a := dir.path_join(stem + ".avi")
	var b := dir.path_join(stem + "_vertical.avi")
	write_avi(a, frames, W, H, FPS)
	write_avi(b, vframes, VW, VH, FPS)
	return [ProjectSettings.globalize_path(a), ProjectSettings.globalize_path(b)]


static func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


static func _u16(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(2)
	b.encode_u16(0, v)
	return b


static func _chunk(id: String, data: PackedByteArray) -> PackedByteArray:
	var out := id.to_ascii_buffer() + _u32(data.size()) + data
	if data.size() % 2 == 1:
		out.append(0)
	return out


static func _list(kind: String, data: PackedByteArray) -> PackedByteArray:
	return "LIST".to_ascii_buffer() + _u32(data.size() + 4) + kind.to_ascii_buffer() + data


## Minimal AVI 1.0 (RIFF) with one MJPEG video stream and an idx1 index.
static func write_avi(path: String, jpgs: Array, w: int, h: int, fps: int) -> void:
	var n := jpgs.size()
	var max_size := 0
	for j in jpgs:
		max_size = maxi(max_size, j.size())
	var avih := _u32(1000000 / fps) + _u32(max_size * fps) + _u32(0) + _u32(0x10) + _u32(n) + _u32(0) + _u32(1) \
		+ _u32(max_size) + _u32(w) + _u32(h) + _u32(0) + _u32(0) + _u32(0) + _u32(0)
	var strh := "vids".to_ascii_buffer() + "MJPG".to_ascii_buffer() + _u32(0) + _u16(0) + _u16(0) + _u32(0) \
		+ _u32(1) + _u32(fps) + _u32(0) + _u32(n) + _u32(max_size) + _u32(0xFFFFFFFF) + _u32(0) \
		+ _u16(0) + _u16(0) + _u16(w) + _u16(h)
	var strf := _u32(40) + _u32(w) + _u32(h) + _u16(1) + _u16(24) + "MJPG".to_ascii_buffer() + _u32(w * h * 3) \
		+ _u32(0) + _u32(0) + _u32(0) + _u32(0)
	var hdrl := _list("hdrl", _chunk("avih", avih) + _list("strl", _chunk("strh", strh) + _chunk("strf", strf)))
	var movi_data := PackedByteArray()
	var idx := PackedByteArray()
	for j in jpgs:
		var off := movi_data.size() + 4  # offsets are relative to the "movi" fourcc
		movi_data.append_array(_chunk("00dc", j))
		idx.append_array("00dc".to_ascii_buffer() + _u32(0x10) + _u32(off) + _u32(j.size()))
	var body := "AVI ".to_ascii_buffer() + hdrl + _list("movi", movi_data) + _chunk("idx1", idx)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer("RIFF".to_ascii_buffer() + _u32(body.size()) + body)
	f.close()
