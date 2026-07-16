class_name PropBatch extends Node3D

const PIVOT_SCALE := 2.19
const PIVOT_Y := 1.633
const MESH_Y := 5.057
const QUAD_SIZE := Vector2(11.615, 11.415)

var _records: Dictionary = {}
var _mmis: Dictionary = {} # key -> MultiMeshInstance3D
var _dirty := false

func add_decor(tex: Texture2D, flipped: bool, texel_pos: Vector2, scale_mult: float) -> void:
	var key := tex.get_instance_id() * 2 + int(flipped)
	if not _records.has(key):
		_records[key] = {tex = tex, flipped = flipped, items = []}
	_records[key].items.append({p = texel_pos, s = scale_mult})
	_dirty = true

func clear_region(x1: float, y1: float, x2: float, y2: float) -> void:
	for key in _records:
		var kept := []
		for it in _records[key].items:
			if not (it.p.x > x1 and it.p.y > y1 and it.p.x < x2 and it.p.y < y2):
				kept.append(it)
		_records[key].items = kept
	_dirty = true

func _process(_delta: float) -> void:
	if MapData.height_img == null:
		return
	if _dirty or MapData.changed:
		_rebuild()
		_dirty = false

func _rebuild() -> void:
	for key in _records:
		var rec: Dictionary = _records[key]
		var mmi: MultiMeshInstance3D = _mmis.get(key)
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			var quad := QuadMesh.new()
			quad.size = QUAD_SIZE
			mm.mesh = quad
			mmi.multimesh = mm
			mmi.material_override = get_parent().get_prop_material(rec.tex, rec.flipped)
			if not Game.layer_is_opaque("nature"):
				mmi.transparency = Game.LAYER_FADE
			add_child(mmi)
			_mmis[key] = mmi
		var mm: MultiMesh = mmi.multimesh
		var items: Array = rec.items
		mm.instance_count = items.size()
		for i in items.size():
			var it: Dictionary = items[i]
			var s: float = PIVOT_SCALE * it.s
			var wx: float = it.p.x * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2
			var wz: float = it.p.y * MapData.WORLD_SIZE / MapData.RESOLUTION - MapData.WORLD_SIZE / 2
			var h: float = MapData.height_img.get_pixelv(it.p.round().clamp(
					Vector2.ZERO, Vector2.ONE * (MapData.RESOLUTION - 1))).r * MapData.HEIGHT_SCALE
			var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s),
					Vector3(wx, h + PIVOT_Y + s * MESH_Y, wz))
			mm.set_instance_transform(i, xf)
