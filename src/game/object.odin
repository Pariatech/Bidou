package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:testing"

import gl "vendor:OpenGL"
import "vendor:cgltf"
import stbi "vendor:stb/image"

import "../camera"
import c "../constants"
import "../cursor"
import "../floor"
import "../renderer"
import "../terrain"
// import "../wall"

ALL_OBJECT_TYPES :: Object_Type_Set {
	.Door,
	.Window,
	.Chair,
	.Table,
	.Counter,
	.Painting,
	.Computer,
	.Plate,
	.Couch,
}

Object_Type :: enum {
	Door,
	Window,
	Chair,
	Table,
	Painting,
	Counter,
	Computer,
	Plate,
	Couch,
	Cursor,
	// Carpet,
	// Tree,
	// Wall,
	// Wall_Top,
}

Object_Type_Set :: bit_set[Object_Type]

Object_Orientation :: enum {
	South,
	West,
	North,
	East,
}

Object_Orientation_Set :: bit_set[Object_Orientation]

ALL_OBJECT_ORIENTATIONS :: Object_Orientation_Set{.South, .West, .North, .East}

Object_Placement :: enum {
	Floor,
	Wall,
	Counter,
	Table,
}

Object_Placement_Set :: bit_set[Object_Placement]
ALL_OBJECT_PLACEMENTS :: Object_Placement_Set{.Floor, .Wall, .Counter, .Table}

Box :: struct {
	min: glsl.vec3,
	max: glsl.vec3,
}

Object_Id :: int

Object_Key :: struct {
	chunk_pos: glsl.ivec3,
	index:     int,
}

Object :: struct {
	id:            Object_Id,
	pos:           glsl.vec3,
	light:         glsl.vec3,
	model:         string,
	texture:       string,
	type:          Object_Type,
	orientation:   Object_Orientation,
	placement:     Object_Placement,
	placement_set: Object_Placement_Set,
	size:          glsl.ivec3,
	draw_id:       Object_Draw_Id,
	bounding_box:  Box,
	parent:        Maybe(Object_Id),
	children:      [dynamic]Object_Id,
	wall_mask:     Maybe(Wall_Mask_Texture),
}

Object_Chunk :: struct {
	objects:        [dynamic]Object,
	dirty:          bool,
	placement_map:  [c.CHUNK_WIDTH][c.CHUNK_DEPTH][Object_Placement][Object_Orientation]Maybe(Object_Type),
	objects_inside: [dynamic]Object_Id,
}

Object_Chunks :: [c.CHUNK_HEIGHT][c.WORLD_CHUNK_WIDTH][c.WORLD_CHUNK_DEPTH]Object_Chunk

Object_Uniform_Object :: struct {
	mvp:   glsl.mat4,
	light: glsl.vec3,
}


Objects_Context :: struct {
	chunks:  Object_Chunks,
	keys:    map[Object_Id]Object_Key,
	next_id: Object_Id,
}


init_objects :: proc() -> (ok: bool = true) {
	return true
}

delete_objects :: proc() {
	ctx := get_objects_context()

	for y in 0 ..< c.CHUNK_HEIGHT {
		for x in 0 ..< c.WORLD_CHUNK_WIDTH {
			for z in 0 ..< c.WORLD_CHUNK_DEPTH {
				chunk := &ctx.chunks[y][x][z]
				for &obj in chunk.objects {
					delete(obj.children)
				}
				delete(chunk.objects)
				delete(chunk.objects_inside)
			}
		}
	}

	delete(ctx.keys)
	// for &row in ctx.objects.chunks {
	// 	for &col in row {
	// 		for &chunk in col {
	// 			delete(chunk.objects)
	// 		}
	// 	}
	// }
}

update_objects_on_camera_rotation :: proc() {
	ctx := get_objects_context()

	for y in 0 ..< c.CHUNK_HEIGHT {
		for x in 0 ..< c.WORLD_CHUNK_WIDTH {
			for z in 0 ..< c.WORLD_CHUNK_DEPTH {
				chunk := &ctx.chunks[y][x][z]
				// for &row in ctx.chunks {
				// 	for &col in row {
				// 		for &chunk in col {
				for obj in chunk.objects {
					update_object_draw(object_draw_from_object(obj))
				}
			}
		}
	}
}

world_pos_to_tile_pos :: proc(pos: glsl.vec3) -> (tile_pos: glsl.ivec2) {
	tile_pos.x = clamp(i32(pos.x + 0.5), 0, c.WORLD_WIDTH - 1)
	tile_pos.y = clamp(i32(pos.z + 0.5), 0, c.WORLD_DEPTH - 1)
	return
}

world_pos_to_chunk_pos :: proc(pos: glsl.vec3) -> (chunk_pos: glsl.ivec3) {
	tile_pos := world_pos_to_tile_pos(pos)
	tile_height := terrain.get_tile_height(int(tile_pos.x), int(tile_pos.y))
	chunk_pos.x = tile_pos.x / c.CHUNK_WIDTH
	chunk_pos.y = i32(pos.y - tile_height) / c.WALL_HEIGHT
	chunk_pos.z = tile_pos.y / c.CHUNK_DEPTH
	return
}

add_object_inside_chunk :: proc(obj: Object) {
	ctx := get_objects_context()

	chunk_pos := world_pos_to_chunk_pos(obj.pos)
	// chunk_min_x := i32((obj.bounding_box.min.x + 0.5) / c.CHUNK_WIDTH)
	// chunk_max_x := i32((obj.bounding_box.max.x - 0.5) / c.CHUNK_WIDTH)
	// chunk_min_z := i32((obj.bounding_box.min.z + 0.5) / c.CHUNK_DEPTH)
	// chunk_max_z := i32((obj.bounding_box.max.z - 0.5) / c.CHUNK_DEPTH)
	chunk_min_x := i32((obj.bounding_box.min.x) / c.CHUNK_WIDTH)
	chunk_max_x := i32((obj.bounding_box.max.x) / c.CHUNK_WIDTH)
	chunk_min_z := i32((obj.bounding_box.min.z) / c.CHUNK_DEPTH)
	chunk_max_z := i32((obj.bounding_box.max.z) / c.CHUNK_DEPTH)
	for x in chunk_min_x ..= chunk_max_x {
		for z in chunk_min_z ..= chunk_max_z {
			chunk := &ctx.chunks[chunk_pos.y][x][z]
			append(&chunk.objects_inside, obj.id)
		}
	}
}

remove_object_inside_chunk :: proc(obj: Object) {
	ctx := get_objects_context()

	chunk_pos := world_pos_to_chunk_pos(obj.pos)
	// chunk_min_x := i32((obj.bounding_box.min.x + 0.5) / c.CHUNK_WIDTH)
	// chunk_max_x := i32((obj.bounding_box.max.x - 0.5) / c.CHUNK_WIDTH)
	// chunk_min_z := i32((obj.bounding_box.min.z + 0.5) / c.CHUNK_DEPTH)
	// chunk_max_z := i32((obj.bounding_box.max.z - 0.5) / c.CHUNK_DEPTH)
	chunk_min_x := i32((obj.bounding_box.min.x) / c.CHUNK_WIDTH)
	chunk_max_x := i32((obj.bounding_box.max.x) / c.CHUNK_WIDTH)
	chunk_min_z := i32((obj.bounding_box.min.z) / c.CHUNK_DEPTH)
	chunk_max_z := i32((obj.bounding_box.max.z) / c.CHUNK_DEPTH)
	for x in chunk_min_x ..= chunk_max_x {
		for z in chunk_min_z ..= chunk_max_z {
			chunk := &ctx.chunks[chunk_pos.y][x][z]
			for obj_id, i in chunk.objects_inside {
				if obj_id == obj.id {
					unordered_remove(&chunk.objects_inside, i)
				}
			}
		}
	}
}

add_object_to_parent :: proc(obj: ^Object) {
	parent, ok := get_object_at(obj.pos, type_set = {.Table, .Counter})
	if !ok {
		return
	}

	obj.parent = parent.id

	append(&parent.children, obj.id)
}

add_object :: proc(obj: Object) -> (id: Object_Id, ok: bool = true) {
	obj := obj
	ctx := get_objects_context()
	tile_pos := world_pos_to_tile_pos(obj.pos)
	chunk_pos := world_pos_to_chunk_pos(obj.pos)

	if obj.placement == .Table || obj.placement == .Counter {
		obj.pos.y += 0.8
	}

	calculate_object_bounding_box(&obj)

	can_add_object(obj) or_return

	chunk := &ctx.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]

	id = ctx.next_id
	obj.id = id
	ctx.next_id += 1
	ctx.keys[id] = {
		chunk_pos = chunk_pos,
		index     = len(chunk.objects),
	}

	obj.children = {}

	add_object_to_parent(&obj)

	add_object_inside_chunk(obj)

	chunk.dirty = true

	update_object_placement_map(obj)

	obj.draw_id = create_object_draw(object_draw_from_object(obj))

	append(&chunk.objects, obj)

	if obj.type == .Window || obj.type == .Door {
		for x in 0 ..< obj.size.x {
			tx := x
			tz: i32 = 0
			#partial switch obj.orientation {
			case .East:
				tx = 0
				tz = x
			case .North:
				tx = -x
			case .West:
				tx = 0
				tz = -x
			}

			tpos := obj.pos + {f32(tx), 0, f32(tz)}

			tile_pos := world_pos_to_tile_pos(tpos)
			wall_pos: glsl.ivec3 = {tile_pos.x, chunk_pos.y, tile_pos.y}
			axis: Wall_Axis

			switch obj.orientation {
			case .East:
				wall_pos.x += 1
				axis = .N_S
			case .West:
				axis = .N_S
			case .South:
				axis = .E_W
			case .North:
				wall_pos.z += 1
				axis = .E_W
			}

			w, _ := get_wall(wall_pos, axis)
			w.mask = obj.wall_mask.?
			set_wall(wall_pos, axis, w)
		}
	}

	return
}

Object_Tiles_Iterator :: struct {
	object: Object,
	start:  glsl.ivec2,
	end:    glsl.ivec2,
	xz:     glsl.ivec2,
	i:      int,
}

clamp_object :: proc(object: ^Object) {
	rotated_size := object.size
	if object.orientation == .East || object.orientation == .West {
		rotated_size.xz = object.size.zx
	}

	object.pos.x =
		math.floor(object.pos.x + f32(rotated_size.x % 2) / 2) +
		f32((rotated_size.x + 1) % 2) / 2
	object.pos.z =
		math.floor(object.pos.z + f32(rotated_size.z % 2) / 2) +
		f32((rotated_size.z + 1) % 2) / 2

	if rotated_size.x != 1 {
		object.pos.x = math.clamp(
			object.pos.x,
			f32(rotated_size.x) / 2,
			c.WORLD_WIDTH - f32(rotated_size.x + 1) / 2,
		)
	}
	if rotated_size.z != 1 {
		object.pos.z = math.clamp(
			object.pos.z,
			f32(rotated_size.x) / 2,
			c.WORLD_DEPTH - f32(rotated_size.z + 1) / 2,
		)
	}
}

make_object_tiles_iterator :: proc(object: Object) -> Object_Tiles_Iterator {
	object := object
	clamp_object(&object)

	rotated_size := object.size
	if object.orientation == .East || object.orientation == .West {
		rotated_size.xz = object.size.zx
	}

	start := glsl.ivec2 {
		i32(object.pos.x) - (rotated_size.x - 1) / 2,
		i32(object.pos.z) - (rotated_size.z - 1) / 2,
	}
	end := start + rotated_size.xz
	return {object = object, start = start, end = end, xz = start}
}

next_object_tile_pos :: proc(
	it: ^Object_Tiles_Iterator,
) -> (
	glsl.vec3,
	int,
	bool,
) {
	if it.xz.y >= it.end.y {
		return {}, 0, false
	}

	xz := it.xz
	it.xz.x += 1
	if it.xz.x >= it.end.x {
		it.xz.x = it.start.x
		it.xz.y += 1
	}

	i := it.i
	it.i += 1

	return {f32(xz.x), it.object.pos.y, f32(xz.y)}, i, true
}

update_object_placement_map :: proc(obj: Object) {
	it := make_object_tiles_iterator(obj)
	for pos in next_object_tile_pos(&it) {
		tile_pos := world_pos_to_tile_pos(pos)
		chunk_pos := world_pos_to_chunk_pos(pos)
		ctx := get_objects_context()
		chunk := &ctx.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
		chunk.placement_map[tile_pos.x % c.CHUNK_WIDTH][tile_pos.y % c.CHUNK_DEPTH][obj.placement][obj.orientation] =
			obj.type
	}
}

get_object_size :: proc(model: string) -> glsl.ivec3 {
	models := get_models_context()
	object_model := models.models[model]
	return glsl.ivec3(
		linalg.array_cast(
			glsl.max(
				linalg.floor(object_model.size + {0.01, 0.01, 0.01}),
				glsl.vec3{1, 1, 1},
			),
			i32,
		),
	)
}

calculate_object_bounding_box :: proc(object: ^Object) {
	models := get_models_context()
	object_model := models.models[object.model]


	rotation: glsl.mat4
	switch object.orientation {
	case .South:
		rotation = glsl.identity(glsl.mat4)
	case .East:
		rotation = glsl.mat4Rotate({0, 1, 0}, 0.5 * glsl.PI)
	case .North:
		rotation = glsl.mat4Rotate({0, 1, 0}, 1.0 * glsl.PI)
	case .West:
		rotation = glsl.mat4Rotate({0, 1, 0}, 1.5 * glsl.PI)
	}

	t_min := glsl.vec4 {
		object_model.min.x,
		object_model.min.y,
		object_model.min.z,
		1,
	}
	t_max := glsl.vec4 {
		object_model.max.x,
		object_model.max.y,
		object_model.max.z,
		1,
	}

	t_min *= rotation
	t_max *= rotation

	min := glsl.vec3 {
		math.min(t_min.x, t_max.x),
		t_min.y,
		math.min(t_min.z, t_max.z),
	}

	max := glsl.vec3 {
		math.max(t_min.x, t_max.x),
		t_max.y,
		math.max(t_min.z, t_max.z),
	}

	min += object.pos
	max += object.pos

	object.bounding_box = {
		min = min,
		max = max,
	}
}

can_add_object :: proc(obj: Object) -> bool {
	tile_pos := world_pos_to_tile_pos(obj.pos)

	if tile_pos.x < 0 ||
	   tile_pos.x >= c.WORLD_WIDTH ||
	   tile_pos.y < 0 ||
	   tile_pos.y >= c.WORLD_DEPTH {
		return false
	}

	switch obj.placement {
	case .Wall:
		return can_add_object_on_wall(obj)
	case .Floor:
		return can_add_object_on_floor(obj)
	case .Counter:
		return can_add_object_on_counter(obj)
	case .Table:
		return can_add_object_on_table(obj)
	}

	return true
}

can_add_object_on_wall :: proc(obj: Object) -> bool {
	it := make_object_tiles_iterator(obj)
	for pos in next_object_tile_pos(&it) {
		tile_pos := world_pos_to_tile_pos(pos)
		chunk_pos := world_pos_to_chunk_pos(pos)
		switch obj.orientation {
		case .East:
			if !has_north_south_wall(
				   {tile_pos.x + 1, chunk_pos.y, tile_pos.y},
			   ) {
				return false
			}
		case .West:
			if !has_north_south_wall({tile_pos.x, chunk_pos.y, tile_pos.y}) {
				return false
			}
		case .South:
			if !has_east_west_wall({tile_pos.x, chunk_pos.y, tile_pos.y}) {
				return false
			}
		case .North:
			if !has_east_west_wall({tile_pos.x, chunk_pos.y, tile_pos.y + 1}) {
				return false
			}
		}

		if has_object_at(pos, .Wall, obj.orientation) {
			return false
		}

		if obj.type == .Window || obj.type == .Door {
			switch obj.orientation {
			case .South:
				if has_object_at(pos + {0, 0, -1}, .Wall, .North) {
					return false
				}
			case .East:
				if has_object_at(pos + {1, 0, 0}, .Wall, .West) {
					return false
				}
			case .North:
				if has_object_at(pos + {0, 0, 1}, .Wall, .South) {
					return false
				}
			case .West:
				if has_object_at(pos + {-1, 0, 0}, .Wall, .East) {
					return false
				}
			}
		}
	}

	return true
}

can_add_object_on_floor :: proc(obj: Object) -> bool {
	ctx := get_objects_context()
	it := make_object_tiles_iterator(obj)
	for pos in next_object_tile_pos(&it) {
		tile_pos := world_pos_to_tile_pos(pos)
		chunk_pos := world_pos_to_chunk_pos(pos)

		if has_object_at(pos, .Floor) {
			return false
		}

		if pos.x != f32(it.start.x) &&
		   has_north_south_wall({tile_pos.x, chunk_pos.y, tile_pos.y}) {
			return false
		}

		if pos.z != f32(it.start.y) &&
		   has_east_west_wall({tile_pos.x, chunk_pos.y, tile_pos.y}) {
			return false
		}

		if has_north_west_south_east_wall(
			   {tile_pos.x, chunk_pos.y, tile_pos.y},
		   ) ||
		   has_north_west_south_east_wall(
			   {tile_pos.x, chunk_pos.y, tile_pos.y},
		   ) {
			return false
		}

		if !terrain.is_tile_flat(tile_pos) {
			return false
		}
	}

	return true
}

can_add_object_on_table :: proc(obj: Object) -> bool {
	if !has_object_at(obj.pos, .Floor, nil, {.Table}) {
		return false
	}

	return !has_object_at(obj.pos, .Table)
}

can_add_object_on_counter :: proc(obj: Object) -> bool {
	if !has_object_at(obj.pos, .Floor, nil, {.Counter}) {
		return false
	}

	return !has_object_at(obj.pos, .Counter)
}

get_object_at :: proc(
	pos: glsl.vec3,
	placement_set: Object_Placement_Set = ALL_OBJECT_PLACEMENTS,
	orientation_set: Object_Orientation_Set = ALL_OBJECT_ORIENTATIONS,
	type_set: Object_Type_Set = ALL_OBJECT_TYPES,
) -> (
	^Object,
	bool,
) {
	objects := get_objects_context()
	chunk_pos := world_pos_to_chunk_pos(pos)
	tile_pos := world_pos_to_tile_pos(pos)
	chunk := &objects.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
	for obj_inside_id in chunk.objects_inside {
		obj_inside, _ := get_object_by_id(obj_inside_id)
		if obj_inside.bounding_box.min.x <= pos.x &&
		   obj_inside.bounding_box.min.z <= pos.z &&
		   pos.x < obj_inside.bounding_box.max.x &&
		   pos.z < obj_inside.bounding_box.max.z &&
		   obj_inside.placement in placement_set &&
		   obj_inside.orientation in orientation_set &&
		   obj_inside.type in type_set {
			return obj_inside, true
		}
	}

	return {}, false
}

has_object_at :: proc(
	pos: glsl.vec3,
	placement: Object_Placement,
	orientation: Object_Orientation = nil,
	type_set: Object_Type_Set = ALL_OBJECT_TYPES,
) -> bool {
	objects := get_objects_context()
	chunk_pos := world_pos_to_chunk_pos(pos)
	tile_pos := world_pos_to_tile_pos(pos)
	chunk := &objects.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]

	orientations :=
		chunk.placement_map[tile_pos.x % c.CHUNK_WIDTH][tile_pos.y % c.CHUNK_DEPTH][placement]

	if orientation == nil {
		for orientation in orientations {
			if type, ok := orientation.?; ok {
				if type in type_set {
					return true
				}
			}
		}
	} else {
		if type, ok := orientations[orientation].?; ok {
			if type in type_set {
				return true
			}
		}
	}
	// for k, v in chunk.objects {
	// 	if world_pos_to_tile_pos(k.pos) == tile_pos &&
	// 	   k.placement == placement {
	// 		return true
	// 	}
	// }

	return false
}

Ray_2D :: struct {
	origin:    glsl.vec2,
	direction: glsl.vec2,
}

Rect :: struct {
	min: glsl.vec2,
	max: glsl.vec2,
}

Ray_Walker_2D :: struct {
	ray:          Ray_2D,
	current_tile: glsl.vec2,
	step:         glsl.vec2,
	t_max:        glsl.vec2,
	t_delta:      glsl.vec2,
	tile_size:    f32,
	rect:         Rect,
}

intersect_ray_with_rect :: proc(ray: Ray_2D, rect: Rect) -> (glsl.vec2, bool) {
	t_min := f32(0.0)
	t_max := math.inf_f32(1)

	for axis in 0 ..= 1 {
		origin := ray.origin[axis]
		direction := ray.direction[axis]
		min_bound := rect.min[axis]
		max_bound := rect.max[axis]

		if direction != 0 {
			t0 := (min_bound - origin) / direction
			t1 := (max_bound - origin) / direction

			if t0 > t1 {
				t0, t1 = t1, t0
			}

			t_min = math.max(t_min, t0)
			t_max = math.min(t_max, t1)

			if t_max < t_min {
				return {}, false // No intersection
			}
		} else if origin < min_bound || origin > max_bound {
			return {}, false // Parallel and outside
		}
	}

	return ray.origin + ray.direction * t_min, true
}

init_ray_walker :: proc(
	ray: Ray_2D,
	tile_size: f32,
	rect: Rect,
) -> (
	walker: Ray_Walker_2D,
	ok: bool = true,
) {
	ray := ray
	ray.direction = glsl.normalize(ray.direction)
	walker.ray = ray
	walker.tile_size = tile_size
	walker.rect = rect
	if ray.origin.x < rect.min.x ||
	   ray.origin.x > rect.max.x ||
	   ray.origin.y < rect.min.y ||
	   ray.origin.y > rect.max.y {
		walker.ray.origin = intersect_ray_with_rect(ray, rect) or_return
	} else {
		walker.ray = ray
	}

	walker.current_tile = glsl.vec2 {
		math.trunc(walker.ray.origin.x / tile_size),
		math.trunc(walker.ray.origin.y / tile_size),
	}


	walker.step = glsl.vec2 {
		walker.ray.direction.x > 0 ? 1 : -1,
		walker.ray.direction.y > 0 ? 1 : -1,
	}

	walker.t_max = glsl.vec2 {
		((walker.current_tile.x + (walker.step.x > 0 ? 1 : 0)) * tile_size -
			ray.origin.x) /
		ray.direction.x,
		((walker.current_tile.y + (walker.step.y > 0 ? 1 : 0)) * tile_size -
			ray.origin.y) /
		ray.direction.y,
	}

	walker.t_delta = glsl.vec2 {
		tile_size / math.abs(walker.ray.direction.x),
		tile_size / math.abs(walker.ray.direction.y),
	}

	return
}

ray_walker_next :: proc(
	ray_walker: ^Ray_Walker_2D,
) -> (
	current_tile: glsl.vec2,
	ok: bool = true,
) {
	current_pos := glsl.vec2 {
		ray_walker.current_tile.x * ray_walker.tile_size,
		ray_walker.current_tile.y * ray_walker.tile_size,
	}

	current_tile = ray_walker.current_tile
	if current_pos.x < ray_walker.rect.min.x ||
	   current_pos.x >= ray_walker.rect.max.x ||
	   current_pos.y < ray_walker.rect.min.y ||
	   current_pos.y >= ray_walker.rect.max.y {
		return current_tile, false
	}

	if ray_walker.t_max.x < ray_walker.t_max.y {
		ray_walker.current_tile.x += ray_walker.step.x
		ray_walker.t_max.x += ray_walker.t_delta.x
	} else {
		ray_walker.current_tile.y += ray_walker.step.y
		ray_walker.t_max.y += ray_walker.t_delta.y
	}

	return
}

ray_intersect_box :: proc(ray: cursor.Ray, box: Box) -> bool {
	t_min, t_max := math.inf_f32(-1), math.inf_f32(1)

	for axis in 0 ..= 2 {
		inv_dir := 1.0 / ray.direction[axis]
		t0 := (box.min[axis] - ray.origin[axis]) * inv_dir
		t1 := (box.max[axis] - ray.origin[axis]) * inv_dir

		if t0 > t1 {
			t0, t1 = t1, t0
		}

		t_min = math.max(t_min, t0)
		t_max = math.min(t_max, t1)

		if t_max < t_min {
			return false
		}
	}

	return true
}

get_object_by_id :: proc(id: Object_Id) -> (obj: ^Object, ok: bool = true) {
	objects := get_objects_context()
	key := objects.keys[id] or_return

	chunk := objects.chunks[key.chunk_pos.y][key.chunk_pos.x][key.chunk_pos.z]
	return &chunk.objects[key.index], true
}

rotate_object :: proc(object: ^Object) {
	object.orientation = Object_Orientation(
		(int(object.orientation) + 1) % len(Object_Orientation),
	)
	calculate_object_bounding_box(object)
}

delete_object_by_id :: proc(id: Object_Id) -> (ok: bool = true) {
	objects := get_objects_context()
	key := objects.keys[id] or_return

	chunk := &objects.chunks[key.chunk_pos.y][key.chunk_pos.x][key.chunk_pos.z]
	object := chunk.objects[key.index]

	it := make_object_tiles_iterator(object)
	for pos in next_object_tile_pos(&it) {
		chunk_pos := world_pos_to_chunk_pos(pos)
		tile_pos := world_pos_to_tile_pos(pos)
		chunk := &objects.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
		chunk.placement_map[tile_pos.x % c.CHUNK_WIDTH][tile_pos.y % c.CHUNK_DEPTH][object.placement][object.orientation] =
			nil
	}

	remove_object_inside_chunk(object)

	delete_object_draw(object.draw_id)

	for child in object.children {
		delete_object_by_id(child)
	}

	if parent_id, ok := object.parent.?; ok {
		parent, _ := get_object_by_id(parent_id)
		for child_id, i in parent.children {
			if child_id == id {
				unordered_remove(&parent.children, i)
				break
			}
		}
	}

	delete(object.children)

	unordered_remove(&chunk.objects, key.index)

	if key.index < len(chunk.objects) {
		moved_id := chunk.objects[key.index].id
		objects.keys[moved_id] = {key.chunk_pos, key.index}
	}

	return
}

get_object_under_cursor :: proc() -> (object_id: Object_Id, ok: bool = true) {
	objects := get_objects_context()
	ray := Ray_2D {
		origin    = cursor.ray.origin.xz,
		direction = cursor.ray.direction.xz,
	}

	rect: Rect
	rect.min.x = f32(camera.visible_chunks_start.x) * c.CHUNK_WIDTH
	rect.min.y = f32(camera.visible_chunks_start.y) * c.CHUNK_DEPTH
	rect.max.x = f32(camera.visible_chunks_end.x) * c.CHUNK_WIDTH
	rect.max.y = f32(camera.visible_chunks_end.y) * c.CHUNK_DEPTH

	chunk_ray_walker := init_ray_walker(ray, c.CHUNK_WIDTH, rect) or_return

	object_under_placement: Object_Placement
	object_under_id: Maybe(Object_Id)
	for pos in ray_walker_next(&chunk_ray_walker) {
		chunk := &objects.chunks[floor.floor][i32(pos.x)][i32(pos.y)]
		for id, i in chunk.objects_inside {
			if obj, ok := get_object_by_id(id); ok {
				if ray_intersect_box(cursor.ray, obj.bounding_box) {
					object_under_id = id
					if obj.placement != .Floor {
						return object_under_id.?, true
					}
				}
			}
		}
	}

	object_id = object_under_id.? or_return
	return
}

@(test)
can_add_object_on_floor_test :: proc(t: ^testing.T) {
	// game := new(Game_Context)
	// context.user_ptr = game
	//
	// load_models()
	// defer free_models()
	//
	// defer delete_objects()
	//
	// pos := glsl.vec3{1, 0, 1}
	// add_object(
	// 	 {
	// 		pos = pos,
	// 		model = WOOD_COUNTER_MODEL,
	// 		orientation = .South,
	// 		placement = .Floor,
	// 	},
	// )
	// r := can_add_object(pos, WOOD_COUNTER_MODEL, .Table, .South, .Floor)
	// testing.expect_value(t, r, false)
	//
	// pos = {2, 0, 1}
	// r = can_add_object(pos, WOOD_COUNTER_MODEL, .Table, .South, .Floor)
	// testing.expect_value(t, r, true)
	//
	// pos = {1, 0, 1}
	// r = can_add_object(pos, WOOD_TABLE_8PLACES_MODEL, .Table, .South, .Floor)
	// testing.expect_value(t, r, false)
	// add_object(&game, {2, 0, 1}, .Wood_Counter, .South, .Floor)
	// add_object(&game, {3, 0, 1}, .Wood_Counter, .South, .Floor)
	//
	// add_object(&game, {5, 0, 1}, .Plank_Table_6Places, .South, .Floor)
	// add_object(&game, {8, 0, 1}, .Wood_Table_8Places, .South, .Floor)
	//
	// add_object(&game, {5, 0, 4}, .Plank_Table_6Places, .East, .Floor)
	// add_object(&game, {8, 0, 4}, .Wood_Table_8Places, .East, .Floor)
	//
	// add_object(&game, {5, 0, 7}, .Plank_Table_6Places, .North, .Floor)
	// add_object(&game, {8, 0, 7}, .Wood_Table_8Places, .North, .Floor)
	//
	// add_object(&game, {5, 0, 10}, .Plank_Table_6Places, .West, .Floor)
	// add_object(&game, {8, 0, 10}, .Wood_Table_8Places, .West, .Floor)
}
