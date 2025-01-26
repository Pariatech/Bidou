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
	x := ctx.ray.origin.x // + 0.5 * math.sign(dx)
	z := ctx.ray.origin.z // + 0.5 * math.sign(dz)


	// left_x := f32(camera().visible_chunks_start.x * CHUNK_WIDTH)
	// left_z := z + ((left_x - x) / dx) * dz

	// right_z := f32(camera().visible_chunks_start.y * CHUNK_DEPTH)
	// right_x := x + ((right_z - z) / dz) * dx

	// if right_x >= f32(camera().visible_chunks_start.x * CHUNK_WIDTH) &&
	//    right_x <= f32(camera().visible_chunks_end.x * CHUNK_WIDTH) {
	// 	x = right_x
	// 	z = right_z
	// } else if left_z >= f32(camera().visible_chunks_start.y * CHUNK_DEPTH) &&
	//    left_z <= f32(camera().visible_chunks_end.y * CHUNK_DEPTH) {
	// 	x = left_x
	// 	z = left_z
	// } else {
	// 	return
	// }

	start_x := f32(camera().visible_chunks_start.x * CHUNK_WIDTH)
	end_x := f32(camera().visible_chunks_end.x * CHUNK_WIDTH)
	if x < start_x {
		z += (start_x - x) / dx * dz
		x = start_x
	} else if x >= end_x {
		z += (end_x - x) / dx * dz
		x = end_x
	}

	start_z := f32(camera().visible_chunks_start.y * CHUNK_WIDTH)
	end_z := f32(camera().visible_chunks_end.y * CHUNK_WIDTH)
	if z < start_z {
		x += (start_z - z) / dz * dx
		z = start_z
	} else if z >= end_z {
		x += (end_z - z) / dz * dx
		z = end_z
	}

	// x += 0.5
	// z += 0.5

	// log.ifo(
	// 	glsl.vec2{x, z},
	// 	glsl.vec2{start_x, start_z},
	// 	glsl.vec2{end_x, end_z},
	// 	glsl.vec2{dx, dz},
	// )

	// direction := -glsl.normalize(
	// 	glsl.vec2{f32(math.cos(CAMERA_YAW)), f32(math.sin(CAMERA_YAW))},
	// )
	direction := glsl.normalize(ctx.ray.direction.xz)

	// log.info(x, z, direction)
	for x <= f32(end_x) &&
	    z <= f32(end_z) &&
	    x + 0.5 >= f32(start_x) &&
	    z + 0.5 >= f32(start_z) {

		// log.info(x, z, start_x, start_z, end_x, end_z, direction)
		// log.info(direction)

		// log.info(next, direction)
		// next_x := x + 1
		// next_z := z + 1

		// if x < 0 || z < 0 {continue}

		if cursor_intersect_with_tile(x + 0.5, z + 0.5, on_intersect, floor) {
            // log.info(math.floor(x + 0.5), math.floor(z + 0.5))
			break
		}

        log.info(glsl.vec2{x, z}, direction)
		next := cursor_next_intersect_with_grid({x, z}, direction)
        log.info(next)

		// if (next.x <= end_x &&
		// 	   next.x >= start_x &&
		// 	   cursor_intersect_with_tile(next.x, z, on_intersect, floor)) ||
		//    next.y <= end_z &&
		// 	   next.y >= start_z &&
		// 	   cursor_intersect_with_tile(x, next.y, on_intersect, floor) {
		// 	break
		// }

		x = next.x
		z = next.y
		// x += 1
		// z += 1
	}
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
	start: glsl.vec2,
	direction: glsl.vec2,
) -> glsl.vec2 {

	next_x :f32
	next_y :f32
    if direction.x < 0 {
        next_x = math.ceil(start.x - 1)
    } else {
        next_x = math.floor(start.x + 1)
    }

    if direction.y < 0 {
        next_y = math.ceil(start.y - 1)
    } else {
        next_y = math.floor(start.y + 1)
    }

	delta_next_x := next_x - start.x
	delta_next_y := next_y - start.y

	next_x_intersect := glsl.vec2 {
		next_x,
		start.y + delta_next_x / direction.x * direction.y,
	}
	next_y_intersect := glsl.vec2 {
		start.x + delta_next_y / direction.y * direction.x,
		next_y,
	}

	if glsl.length(next_x_intersect) <= glsl.length(next_y_intersect) {
		return next_x_intersect
	}

	return next_y_intersect
}

@(test)
cursor_next_interesect_with_grid_test :: proc(t: ^testing.T) {
    start := glsl.vec2{6.2612123, 24}
    direction := glsl.vec2{-0.44775912, 0.89415425}
    result := glsl.vec2{6, 24.521629}
    testing.expect_value(t, cursor_next_intersect_with_grid(start, direction), result)
}
