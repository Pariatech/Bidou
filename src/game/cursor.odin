package game

import "base:runtime"
import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:testing"

import "vendor:glfw"

Cursor_Context :: struct {
	previous_pos:  glsl.vec2,
	pos:           glsl.vec2,
	moved:         bool,
	ray:           Cursor_Ray,
	intersect_pos: glsl.vec3,
}

Cursor_Ray :: struct {
	origin:    glsl.vec3,
	direction: glsl.vec3,
}

Wall_Intersect :: struct {
	pos:  glsl.ivec3,
	axis: Wall_Axis,
}

init_cursor :: proc() {
	glfw.SetCursorPosCallback(window().handle, pos_callback)
}

set_cursor_pos :: proc(pos: glsl.vec2) {
	glfw.SetCursorPos(window().handle, f64(pos.x), f64(pos.y))
}

update_cursor :: proc() {
	ctx := get_cursor_context()
	update_ray()
	ctx.previous_pos = ctx.pos
}

cursor_intersect_with_tile :: proc(
	x, z: f32,
	on_intersect: proc(_: glsl.vec3),
	floor: i32,
) -> bool {
	for side in Tile_Triangle_Side {
		pos := glsl.vec2{math.floor(x), math.floor(z)}

		x := int(pos.x)
		z := int(pos.y)

		heights := tile_triangle_get_terrain_tile_triangle_heights(
			side,
			x,
			z,
			1,
		)
		for &h in heights {
			h += f32(floor) * WALL_HEIGHT
		}

		if intersect_with_tile_triangle(side, heights, pos, on_intersect) {
			return true
		}
	}
	return false
}

on_cursor_tile_intersect :: proc(
	on_intersect: proc(_: glsl.vec3),
	previous_floor: i32,
	floor: i32,
) {
	ctx := get_cursor_context()
	if ctx.moved || previous_floor != floor {
		cursor_intersect_with_tiles(on_intersect, floor)
	} else {
		on_intersect(ctx.intersect_pos)
	}
}

cursor_intersect_with_tiles :: proc(
	on_intersect: proc(_: glsl.vec3),
	floor: i32,
) {
	ctx := get_cursor_context()
	dx := ctx.ray.direction.x
	dz := ctx.ray.direction.z
	origin := ctx.ray.origin
	// log.info("before:", origin)

	start_x := f32(camera().visible_chunks_start.x * CHUNK_WIDTH)
	end_x := f32(camera().visible_chunks_end.x * CHUNK_WIDTH - 1)
	if origin.x < start_x {
		origin.yz += (start_x - origin.x) / dx * ctx.ray.direction.yz
		origin.x = start_x
	} else if origin.x >= end_x {
		origin.yz += (end_x - origin.x) / dx * ctx.ray.direction.yz
		origin.x = end_x
	}

	start_z := f32(camera().visible_chunks_start.y * CHUNK_WIDTH)
	end_z := f32(camera().visible_chunks_end.y * CHUNK_WIDTH - 1)
	if origin.z < start_z {
		origin.xy += (start_z - origin.z) / dz * ctx.ray.direction.xy
		origin.z = start_z
	} else if origin.z >= end_z {
		origin.xy += (end_z - origin.z) / dz * ctx.ray.direction.xy
		origin.z = end_z
	}

	// log.info("after:", origin)

	for origin.x <= f32(end_x) &&
	    origin.z <= f32(end_z) &&
	    origin.x + 0.5 >= f32(start_x) &&
	    origin.z + 0.5 >= f32(start_z) {
		// log.info(origin)

		if cursor_intersect_with_tile(
			   origin.x + 0.5,
			   origin.z + 0.5,
			   on_intersect,
			   floor,
		   ) {
			// log.info("found!")
			break
		}

		// log.info(ctx.ray.direction)
		origin = cursor_next_intersect_with_grid(origin, ctx.ray.direction)
		// log.info("next:", origin)
	}
}

cursor_is_intersect_with_wall :: proc(
	pos: glsl.vec3,
	floor: i32,
) -> (
	Wall_Intersect,
	bool,
) {
	x := pos.x + 0.5
	z := pos.z + 0.5
	// x := pos.x
	// z := pos.z
	tile_height := get_tile_height(int(x), int(z))
	y := (pos.y - tile_height) / WALL_HEIGHT

	// log.info(pos, y, floor)
	if i32(math.floor(y)) > floor || i32(math.floor(y)) < floor {
		return {}, false
	}

	if pos.x == math.floor(pos.x) + 0.5 {
		// log.info(pos)
		if wall, ok := get_wall({i32(x), i32(y), i32(z)}, .N_S); ok {
			return {pos = {i32(x), floor, i32(z)}, axis = .N_S}, true
		}
	} else if pos.z == math.floor(pos.z) + 0.5 {
		log.info(pos)
		if wall, ok := get_wall({i32(x), i32(y), i32(z)}, .E_W); ok {
			return {pos = {i32(x), floor, i32(z)}, axis = .E_W}, true
		}
	}

	if wall, ok := get_wall({i32(x), i32(y), i32(z)}, .NW_SE); ok {
		return {pos = {i32(x), floor, i32(z)}, axis = .NW_SE}, true
	}

	if wall, ok := get_wall({i32(x), i32(y), i32(z)}, .SW_NE); ok {
		return {pos = {i32(x), floor, i32(z)}, axis = .SW_NE}, true
	}

	return {}, false
}

cursor_get_intersect_with_wall :: proc(floor: i32) -> (Wall_Intersect, bool) {
	ctx := get_cursor_context()
	dx := ctx.ray.direction.x
	dz := ctx.ray.direction.z
	origin := ctx.ray.origin

	start_x := f32(camera().visible_chunks_start.x * CHUNK_WIDTH) - 0.5
	end_x := f32(camera().visible_chunks_end.x * CHUNK_WIDTH) - 0.5
	if origin.x < start_x {
		origin.yz += (start_x - origin.x) / dx * ctx.ray.direction.yz
		origin.x = start_x
	} else if origin.x >= end_x {
		origin.yz += (end_x - origin.x) / dx * ctx.ray.direction.yz
		origin.x = end_x
	}

	start_z := f32(camera().visible_chunks_start.y * CHUNK_WIDTH) - 0.5
	end_z := f32(camera().visible_chunks_end.y * CHUNK_WIDTH) - 0.5
	if origin.z < start_z {
		origin.xy += (start_z - origin.z) / dz * ctx.ray.direction.xy
		origin.z = start_z
	} else if origin.z >= end_z {
		origin.xy += (end_z - origin.z) / dz * ctx.ray.direction.xy
		origin.z = end_z
	}

	for origin.x <= f32(end_x) &&
	    origin.z <= f32(end_z) &&
	    origin.x >= f32(start_x) &&
	    origin.z >= f32(start_z) {

		if wall, ok := cursor_is_intersect_with_wall(origin, floor); ok {
			log.info(wall)
			return wall, ok
		}

		origin = cursor_next_intersect_with_grid(origin, ctx.ray.direction)
	}

	return {}, false
}

@(private = "file")
pos_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	context = runtime.default_context()
	context.user_ptr = glfw.GetWindowUserPointer(window)
	// context = cast(type_of(context))glfw.GetWindowUserPointer(window)

	// return cast(^Game_Context)context.user_ptr
	ctx := get_cursor_context()

	ctx.pos.x = f32(xpos)
	ctx.pos.y = f32(ypos)

	update_ray()
}

@(private = "file")
update_ray :: proc() {
	ctx := get_cursor_context()
	screen_pos: glsl.vec4
	screen_pos.x = ctx.pos.x / window().size.x
	screen_pos.y = ctx.pos.y / window().size.y

	screen_pos.x = screen_pos.x * 2 - 1
	screen_pos.y = (1 - screen_pos.y) * 2 - 1
	screen_pos.z = -1
	screen_pos.w = 1

	end_pos := screen_pos
	end_pos.z = 1

	last_origin := ctx.ray.origin
	ctx.ray.origin = (camera().inverse_view_proj * screen_pos).xyz
	ctx.moved = last_origin != ctx.ray.origin
	ctx.ray.direction =
		(camera().inverse_view_proj * end_pos).xyz - ctx.ray.origin
	ctx.ray.direction = glsl.normalize(ctx.ray.direction)
}

@(private = "file")
ray_intersect_plane :: proc(
	pos: glsl.vec3,
	normal: glsl.vec3,
) -> Maybe(glsl.vec3) {
	ctx := get_cursor_context()
	dot_product := glsl.dot(ctx.ray.direction, normal)

	if dot_product == 0 {
		return nil
	}

	t := glsl.dot(pos - ctx.ray.origin, normal) / dot_product
	if t < 0 {
		return nil
	}

	return ctx.ray.origin + t * ctx.ray.direction
}

@(private = "file")
ray_intersect_triangle :: proc(triangle: [3]glsl.vec3) -> Maybe(glsl.vec3) {
	ctx := get_cursor_context()
	EPSILON :: 0.000001

	edge1, edge2, h, s, q: glsl.vec3
	a, f, u, v: f32

	edge1.x = triangle[1].x - triangle[0].x
	edge1.y = triangle[1].y - triangle[0].y
	edge1.z = triangle[1].z - triangle[0].z

	edge2.x = triangle[2].x - triangle[0].x
	edge2.y = triangle[2].y - triangle[0].y
	edge2.z = triangle[2].z - triangle[0].z

	h = glsl.cross(ctx.ray.direction, edge2)
	a = glsl.dot(edge1, h)

	if a > -EPSILON && a < EPSILON {
		return nil
	}

	f = 1 / a
	s.x = ctx.ray.origin.x - triangle[0].x
	s.y = ctx.ray.origin.y - triangle[0].y
	s.z = ctx.ray.origin.z - triangle[0].z

	u = f * glsl.dot(s, h)
	if u < 0 || u > 1 {
		return nil
	}

	q = glsl.cross(s, edge1)
	v = f * glsl.dot(ctx.ray.direction, q)
	if v < 0 || u + v > 1 {
		return nil
	}

	t := f * glsl.dot(edge2, q)
	if t > EPSILON {
		return(
			glsl.vec3 {
				ctx.ray.origin.x + ctx.ray.direction.x * t,
				ctx.ray.origin.y + ctx.ray.direction.y * t,
				ctx.ray.origin.z + ctx.ray.direction.z * t,
			} \
		)
	}

	return nil
}

@(private = "file")
intersect_with_tile_triangle :: proc(
	side: Tile_Triangle_Side,
	heights: [3]f32,
	pos: glsl.vec2,
	on_intersect: proc(_: glsl.vec3),
) -> bool {
	ctx := get_cursor_context()

	triangle: [3]glsl.vec3

	tile_triangle_side_vertices_map := TILE_TRIANGLE_SIDE_VERTICES_MAP
	vertices := tile_triangle_side_vertices_map[side]
	for vertex, i in vertices {
		triangle[i] = vertex.pos
		triangle[i].x += pos.x
		triangle[i].z += pos.y
		triangle[i].y += heights[i]
	}

	intersect, ok := ray_intersect_triangle(triangle).?
	if ok {
		ctx.intersect_pos = intersect
		on_intersect(intersect)
	}

	return ok
}

@(private = "file")
cursor_next_intersect_with_grid :: proc(
	start: glsl.vec3,
	direction: glsl.vec3,
) -> glsl.vec3 {

	next_x: f32
	next_z: f32
	if direction.x < 0 {
		next_x = math.ceil(start.x - 1.5) + 0.5
	} else {
		next_x = math.floor(start.x + 0.5) + 0.5
	}

	// log.info(next_x)
	if direction.z < 0 {
		next_z = math.ceil(start.z - 1.5) + 0.5
	} else {
		next_z = math.floor(start.z + 0.5) + 0.5
	}
	// log.info(next_z)

	delta_next_x := next_x - start.x
	delta_next_z := next_z - start.z

	ratio_x := delta_next_x / direction.x
	ratio_z := delta_next_z / direction.z
	// log.info(ratio_x, ratio_z)

	if ratio_x < ratio_z {
		return(
			 {
				next_x,
				start.y + ratio_x * direction.y,
				start.z + ratio_x * direction.z,
			} \
		)
	}

	return glsl.vec3 {
		start.x + ratio_z * direction.x,
		start.y + ratio_z * direction.y,
		next_z,
	}
}

@(test)
cursor_next_interesect_with_grid_test :: proc(t: ^testing.T) {
	start := glsl.vec3{6.2612123, 0, 24.5}
	direction := glsl.vec3{-0.44775912, 0, 0.89415425}
	result := glsl.vec3{5.7604495, 0, 25.5}
	testing.expect_value(
		t,
		cursor_next_intersect_with_grid(start, direction),
		result,
	)

    start = result
	result = {5.5, 0, 26.0201056}
	testing.expect_value(
		t,
		cursor_next_intersect_with_grid(start, direction),
		result,
	)

	start = {8.826623, 6.6925793, 63.5}
	direction = {0.38777074, -0.5, -0.77436024}
	result = {9.32738571, 6.046885, 62.5}
	testing.expect_value(
		t,
		cursor_next_intersect_with_grid(start, direction),
		result,
	)
	// direction.z *= -1
}
