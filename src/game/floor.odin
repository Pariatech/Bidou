package game

import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:testing"

import "../keyboard"

FLOOR_OFFSET :: 0.0004

Floor_Context :: struct {
	previous_floor:        i32,
	floor:                 i32,
	show_markers:          bool,
	previous_show_markers: bool,
}

floor_move_up :: proc() {
    ctx := get_floor_context()
	ctx.previous_floor = ctx.floor
	ctx.floor = min(ctx.floor + 1, WORLD_HEIGHT - 1)
	floor_update_markers()
}

floor_move_down :: proc() {
    ctx := get_floor_context()
	ctx.previous_floor = ctx.floor
	ctx.floor = max(ctx.floor - 1, 0)
	floor_update_markers()
}

floor_update_markers :: proc() {
    ctx := get_floor_context()
	if ctx.previous_floor != ctx.floor || ctx.previous_show_markers != ctx.show_markers {
		if ctx.previous_floor > 0 && ctx.previous_show_markers {
			for x in 0 ..< WORLD_CHUNK_WIDTH {
				for z in 0 ..< WORLD_CHUNK_DEPTH {
					chunk := &get_tile_triangles_context().chunks[ctx.previous_floor][x][z]
					chunk.dirty = true
					triangles := &chunk.triangles
					for index, triangle in triangles {
						if triangle.texture == .Floor_Marker {
							delete_key(&chunk.triangles, index)
						}
					}
				}
			}
		}

		if ctx.floor > 0 && ctx.show_markers {
			for cx in 0 ..< WORLD_CHUNK_WIDTH {
				for cz in 0 ..< WORLD_CHUNK_DEPTH {
					chunk := &get_tile_triangles_context().chunks[ctx.floor][cx][cz]
					chunk.dirty = true
					for x in 0 ..< CHUNK_WIDTH {
						for z in 0 ..< CHUNK_DEPTH {
							for side in Tile_Triangle_Side {
								key := Tile_Triangle_Key {
									x    = cx * CHUNK_WIDTH + x,
									z    = cz * CHUNK_DEPTH + z,
									side = side,
								}
								if !(key in chunk.triangles) {
									if is_tile_flat(
										   {i32(key.x), i32(key.z)},
									   ) {
										chunk.triangles[key] = Tile_Triangle{
											texture      = .Floor_Marker,
											mask_texture = .Full_Mask,
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}

floor_update :: proc() {
    ctx := get_floor_context()
	ctx.previous_floor = ctx.floor
	if keyboard.is_key_press(.Key_Page_Up) {
		floor_move_up()
	} else if keyboard.is_key_press(.Key_Page_Down) {
		floor_move_down()
	}

	floor_update_markers()
	ctx.previous_show_markers = ctx.show_markers
}

floor_at :: proc(pos: glsl.vec3) -> i32 {
	tile_height := get_tile_height(int(pos.x + 0.5), int(pos.z + 0.5))
	return i32((pos.y - tile_height) / WALL_HEIGHT)
}

floor_height_at :: proc(pos: glsl.vec3) -> f32 {
	floor := floor_at(pos)
	tile_height := get_tile_height(int(pos.x + 0.5), int(pos.z + 0.5))
	return tile_height + f32(floor) * WALL_HEIGHT
}
