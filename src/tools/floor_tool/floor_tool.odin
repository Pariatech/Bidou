package floor_tool

import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"

import "../../cursor"
import "../../floor"
import "../../keyboard"
import "../../mouse"
import "../../tile"

previous_tiles: map[glsl.ivec3][tile.Tile_Triangle_Side]Maybe(
	tile.Tile_Triangle,
)
position: glsl.ivec2
side: tile.Tile_Triangle_Side
drag_start: glsl.ivec3
drag_start_side: tile.Tile_Triangle_Side
active_texture: tile.Texture = .Wood
triangle_mode: bool = false

revert_tile :: proc(position: glsl.ivec3) {
	previous_tile := previous_tiles[position]
	if floor.previous_floor != floor.floor {
		for side in tile.Tile_Triangle_Side {
			if tri, ok := previous_tile[side].?; ok {
				if tri.texture == .Floor_Marker {
					tile.set_tile_triangle(position, side, nil)
				} else {
					tile.set_tile_triangle(position, side, tri)
				}
			} else {
				tile.set_tile_triangle(position, side, nil)
			}
		}
	} else {
		tile.set_tile(position, previous_tile)
	}
}

set_tile :: proc(position: glsl.ivec3, delete_mode: bool) {
	copy_tile(position)

	active_texture := active_texture
	tile_triangle: Maybe(tile.Tile_Triangle) = tile.Tile_Triangle {
		texture      = active_texture,
		mask_texture = .Grid_Mask,
	}
	if delete_mode {
		if position.y == 0 {
			if tile_triangle, ok := &tile_triangle.?; ok {
				tile_triangle.texture = .Grass
			}
		} else if position.y == floor.floor {
			if tile_triangle, ok := &tile_triangle.?; ok {
				tile_triangle.texture = .Floor_Marker
				tile_triangle.mask_texture = .Full_Mask
			}
		} else {
			tile_triangle = nil
		}
	}

	if triangle_mode {
		tile.set_tile_triangle(position, side, tile_triangle)
	} else {
		tile.set_tile(position, tile.tile(tile_triangle))
	}
}

copy_tile :: proc(position: glsl.ivec3) {
	previous_tiles[position] = tile.get_tile(position)
}

init :: proc() {
	if len(previous_tiles) == 0 {
		copy_tile({position.x, floor.floor, position.y})
	} else {
		revert_tiles(position)
	}
	triangle_mode = false
}

deinit :: proc() {
	revert_tiles(position)
}

on_intersect :: proc(intersect: glsl.vec3) {
	position.x = i32(intersect.x + 0.5)
	position.y = i32(intersect.z + 0.5)

	x := intersect.x - math.floor(intersect.x + 0.5)
	z := intersect.z - math.floor(intersect.z + 0.5)

	if x >= z && x <= -z {
		side = .South
	} else if z >= -x && z <= x {
		side = .East
	} else if x >= -z && x <= z {
		side = .North
	} else {
		side = .West
	}
}

revert_tiles :: proc(position: glsl.ivec2) {
	start_x := min(drag_start.x, position.x)
	end_x := max(drag_start.x, position.x)
	start_y := min(drag_start.y, floor.previous_floor)
	end_y := max(drag_start.y, floor.previous_floor)
	start_z := min(drag_start.z, position.y)
	end_z := max(drag_start.z, position.y)

	for x in start_x ..= end_x {
		for y in start_y ..= end_y {
			for z in start_z ..= end_z {
				revert_tile({x, y, z})
			}
		}
	}
}

set_diagonal_tiles :: proc() {

}

set_tiles :: proc(delete_mode: bool) {
	start_x := min(drag_start.x, position.x)
	end_x := max(drag_start.x, position.x)
	start_y := min(drag_start.y, floor.floor)
	end_y := max(drag_start.y, floor.floor)
	start_z := min(drag_start.z, position.y)
	end_z := max(drag_start.z, position.y)

	for x in start_x ..= end_x {
		for y in start_y ..= end_y {
			for z in start_z ..= end_z {
				set_tile({x, y, z}, delete_mode)
			}
		}
	}
}

update :: proc() {
	previous_position := position
	previous_side := side
	cursor.on_tile_intersect(on_intersect, floor.previous_floor, floor.floor)

	reset :=
		previous_position != position || floor.previous_floor != floor.floor
	if keyboard.is_key_press(.Key_1) {
		active_texture = .Wood
		reset = true
	} else if keyboard.is_key_press(.Key_2) {
		active_texture = .Gravel
		reset = true
	}

	previous_triangle_mode := triangle_mode
	if keyboard.is_key_down(.Key_Left_Control) &&
	   keyboard.is_key_press(.Key_F) {
		triangle_mode = true
	}
	if triangle_mode != previous_triangle_mode {
		reset = true
	}
	if triangle_mode && previous_side != side {
		reset = true
	}

	delete_mode := keyboard.is_key_down(.Key_Left_Control)
	if keyboard.is_key_press(.Key_Left_Control) ||
	   keyboard.is_key_release(.Key_Left_Control) {
		reset = true
	}

	if keyboard.is_key_down(.Key_Left_Shift) && mouse.is_button_press(.Left) {
		pos := glsl.ivec3{position.x, floor.floor, position.y}
		revert_tile(pos)
		flood_fill(pos, side, active_texture)
		set_tile(pos, delete_mode)
	} else if mouse.is_button_press(.Left) {
		drag_start = {position.x, floor.floor, position.y}
		drag_start_side = side
	} else if mouse.is_button_down(.Left) {
		if reset {
			if triangle_mode {
				set_tile({position.x, floor.floor, position.y}, delete_mode)
			} else {
				revert_tiles(previous_position)
				clear(&previous_tiles)
				set_tiles(delete_mode)
			}
		}
	} else if mouse.is_button_release(.Left) {
		clear(&previous_tiles)
		copy_tile({position.x, floor.floor, position.y})
	} else {
		drag_start = {position.x, floor.floor, position.y}
		if reset {
			revert_tile(
				 {
					previous_position.x,
					floor.previous_floor,
					previous_position.y,
				},
			)
			clear(&previous_tiles)
			set_tile({position.x, floor.floor, position.y}, delete_mode)
		}
	}
}