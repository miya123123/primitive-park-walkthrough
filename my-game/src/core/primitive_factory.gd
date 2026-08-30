extends RefCounted

## Builds the small set of primitive meshes used by the amusement park.

const ALLOWED_MESH_TYPES: Array = [
	"BoxMesh",
	"CylinderMesh",
	"SphereMesh",
	"CapsuleMesh"
]

## Creates a colored box and optionally a matching static collision shape.
static func create_box(parent: Node3D, size: Vector3, position: Vector3, color: Color, with_collision: bool = false, node_name: StringName = &"Box", rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	return _finish_mesh(parent, mesh, position, rotation, color, shape if with_collision else null, node_name)

## Creates a colored cylinder and optionally a matching static collision shape.
static func create_cylinder(parent: Node3D, radius: float, height: float, position: Vector3, color: Color, with_collision: bool = false, node_name: StringName = &"Cylinder", rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return _finish_mesh(parent, mesh, position, rotation, color, shape if with_collision else null, node_name)

## Creates a conical CylinderMesh for canopies and decorative roofs.
static func create_cone(parent: Node3D, bottom_radius: float, height: float, position: Vector3, color: Color, with_collision: bool = false, node_name: StringName = &"Cone") -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 20
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = bottom_radius
	shape.height = height
	return _finish_mesh(parent, mesh, position, Vector3.ZERO, color, shape if with_collision else null, node_name)

## Creates a colored sphere and optionally a matching static collision shape.
static func create_sphere(parent: Node3D, radius: float, position: Vector3, color: Color, with_collision: bool = false, node_name: StringName = &"Sphere") -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	return _finish_mesh(parent, mesh, position, Vector3.ZERO, color, shape if with_collision else null, node_name)

## Creates a colored capsule and optionally a matching static collision shape.
static func create_capsule(parent: Node3D, radius: float, height: float, position: Vector3, color: Color, with_collision: bool = false, node_name: StringName = &"Capsule") -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 6
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	return _finish_mesh(parent, mesh, position, Vector3.ZERO, color, shape if with_collision else null, node_name)

## Creates a long box between two local-space points.
static func create_box_between(parent: Node3D, start: Vector3, end: Vector3, width: float, height: float, color: Color, with_collision: bool = false, node_name: StringName = &"Beam") -> MeshInstance3D:
	var length: float = start.distance_to(end)
	var midpoint: Vector3 = start.lerp(end, 0.5)
	var beam: MeshInstance3D = create_box(parent, Vector3(width, height, maxf(length, 0.05)), midpoint, color, with_collision, node_name)
	if length > 0.05:
		beam.look_at(parent.to_global(end), Vector3.UP)
	return beam

## Reports whether a mesh type is allowed by the primitive-only art rule.
static func is_allowed_mesh(mesh: Mesh) -> bool:
	return mesh != null and ALLOWED_MESH_TYPES.has(String(mesh.get_class()))

static func _finish_mesh(parent: Node3D, mesh: Mesh, position: Vector3, rotation: Vector3, color: Color, shape: Shape3D, node_name: StringName) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation = rotation
	instance.mesh = mesh
	instance.material_override = _create_material(color)
	parent.add_child(instance)
	if shape != null:
		_attach_collision(instance, shape)
	return instance

static func _create_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	material.metallic = 0.0
	return material

static func _attach_collision(instance: MeshInstance3D, shape: Shape3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "StaticCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	instance.add_child(body)
