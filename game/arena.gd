## 训练场地。全程序化生成，不依赖任何美术资源。
##
## 视觉刻意做得朴素：地面网格提供距离与横移的参考，除此之外没有任何装饰。
## 训练场里多余的视觉元素只会干扰对靶机运动的判读。
class_name Arena
extends Node3D

const HALF := 40.0
const WALL_HEIGHT := 10.0
const GRID_STEP := 2.0

const _FLOOR_COLOR := Color(0.10, 0.11, 0.13)
const _GRID_COLOR := Color(0.22, 0.25, 0.30)
const _WALL_COLOR := Color(0.14, 0.15, 0.18)


func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_grid()
	_build_walls()
	_build_light()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.60, 0.72)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# 靶机是自发光的，开辉光才能让它在暗背景里足够醒目。
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1

	var node := WorldEnvironment.new()
	node.environment = env
	add_child(node)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF * 2.0, HALF * 2.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _FLOOR_COLOR
	mat.roughness = 0.95

	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	add_child(mi)


# 用 ImmediateMesh 画线网格，省掉一张贴图，也便于随时改网格间距。
func _build_grid() -> void:
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _GRID_COLOR
	mat.vertex_color_use_as_albedo = true

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var steps := int(HALF * 2.0 / GRID_STEP)
	for i in steps + 1:
		var p := -HALF + i * GRID_STEP
		mesh.surface_add_vertex(Vector3(p, 0.02, -HALF))
		mesh.surface_add_vertex(Vector3(p, 0.02, HALF))
		mesh.surface_add_vertex(Vector3(-HALF, 0.02, p))
		mesh.surface_add_vertex(Vector3(HALF, 0.02, p))
	mesh.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)


func _build_walls() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _WALL_COLOR
	mat.roughness = 0.9

	var offsets := [
		Vector3(0.0, WALL_HEIGHT * 0.5, -HALF),
		Vector3(0.0, WALL_HEIGHT * 0.5, HALF),
		Vector3(-HALF, WALL_HEIGHT * 0.5, 0.0),
		Vector3(HALF, WALL_HEIGHT * 0.5, 0.0),
	]
	var sizes := [
		Vector3(HALF * 2.0, WALL_HEIGHT, 0.5),
		Vector3(HALF * 2.0, WALL_HEIGHT, 0.5),
		Vector3(0.5, WALL_HEIGHT, HALF * 2.0),
		Vector3(0.5, WALL_HEIGHT, HALF * 2.0),
	]
	for i in offsets.size():
		var box := BoxMesh.new()
		box.size = sizes[i]
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.position = offsets[i]
		add_child(mi)


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 0.8
	light.shadow_enabled = true
	add_child(light)
