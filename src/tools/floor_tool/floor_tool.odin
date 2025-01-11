package floor_tool

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg/glsl"

import "../../game"
import "../../keyboard"
import "../../mouse"

position: glsl.ivec2
side: game.Tile_Triangle_Side
drag_start: glsl.ivec3
drag_start_side: game.Tile_Triangle_Side
active_texture: game.Tile_Triangle_Texture = .Wood_Floor_008
triangle_mode: bool = false
placing: bool = false
add_command: proc(_: Command)

Tile_Triangle_Key :: struct {
	pos:  glsl.ivec3,
	side: game.Tile_Triangle_Side,
}

previous_floor_tiles: map[Tile_Triangle_Key]Maybe(game.Tile_Triangle)
new_floor_tiles: map[Tile_Triangle_Key]Maybe(game.Tile_Triangle)

Command :: struct {
	before: map[Tile_Triangle_Key]Maybe(game.Tile_Triangle),
	after:  map[Tile_Triangle_Key]Maybe(game.Tile_Triangle),
}

init :: proc() {
	triangle_mode = false
	game.get_floor_context().show_markers = true
}

deinit :: proc() {
	revert_tiles()
}

update :: proc() {
	previous_position := position
	previous_side := side
    floor := game.get_floor_context()
	game.on_cursor_tile_intersect(on_intersect, floor.previous_floor, floor.floor)

	reset :=
		previous_position != position ||
		floor.previous_floor != floor.floor ||
		previous_side != side ||
		keyboard.is_key_press(.Key_Left_Shift) ||
		keyboard.is_key_release(.Key_Left_Shift)

	previous_triangle_mode := triangle_mode
	if keyboard.is_key_down(.Key_Left_Control) &&
	   keyboard.is_key_press(.Key_F) {
		triangle_mode = !triangle_mode
	}
	if triangle_mode != previous_triangle_mode {
		reset = true
	}

	delete_mode := keyboard.is_key_down(.Key_Left_Control)
	if keyboard.is_key_press(.Key_Left_Control) ||
	   keyboard.is_key_release(.Key_Left_Control) {
		reset = true
	}

	do_revert_tiles := reset
	if do_revert_tiles {
		revert_tiles()
		clear(&new_floor_tiles)
	}

	if keyboard.is_key_down(.Key_Left_Shift) {
		placing = true
		pos := glsl.ivec3{position.x, floor.floor, position.y}
		if delete_mode {
			if floor.floor == 0 {
				flood_fill(pos, side, .Grass_004)
			} else if game.is_tile_flat(pos.xz) {
				flood_fill(pos, side, .Floor_Marker)
			}
		} else {
			flood_fill(pos, side, active_texture)
		}

		if mouse.is_button_press(.Left) {
			save_command()
			clear(&previous_floor_tiles)
		}
	} else if mouse.is_button_press(.Left) {
		placing = true
		drag_start = {position.x, floor.floor, position.y}
		drag_start_side = side
	} else if placing && mouse.is_button_down(.Left) {
		if reset {
			if triangle_mode {
				set_tile({position.x, floor.floor, position.y}, delete_mode)
			} else {
				set_tiles(delete_mode)
			}
		}
	} else if placing && mouse.is_button_release(.Left) {
		placing = false
		save_command()
		clear(&previous_floor_tiles)
	} else {
		drag_start = {position.x, floor.floor, position.y}
		if reset {
			set_tile({position.x, floor.floor, position.y}, delete_mode)
		}
	}
}

save_command :: proc() {
	command: Command
	for k, v in previous_floor_tiles {
		command.before[k] = v
	}
	for k, v in new_floor_tiles {
		command.after[k] = v
	}
	add_command(command)
}

set_tile_triangle :: proc(
	position: glsl.ivec3,
	side: game.Tile_Triangle_Side,
	tile_triangle: Maybe(game.Tile_Triangle),
) {
	if tile_triangle, ok := game.tile_triangle_get_tile_triangle(position, side); ok {
		previous_floor_tiles[{position, side}] = tile_triangle
	} else {
		previous_floor_tiles[{position, side}] = nil
	}

	new_floor_tiles[{position, side}] = tile_triangle
	game.tile_triangle_set_tile_triangle(position, side, tile_triangle)
}

set_tile :: proc(position: glsl.ivec3, delete_mode: bool) {
    floor := game.get_floor_context()
	active_texture := active_texture
	tile_triangle: Maybe(game.Tile_Triangle) = game.Tile_Triangle {
		texture      = active_texture,
		mask_texture = .Grid_Mask,
	}
	if delete_mode {
		if position.y == 0 {
			if tile_triangle, ok := &tile_triangle.?; ok {
				tile_triangle.texture = .Grass_004
			}
		} else if position.y == floor.floor &&
		   game.is_tile_flat(position.xz) {
			if tile_triangle, ok := &tile_triangle.?; ok {
				tile_triangle.texture = .Floor_Marker
				tile_triangle.mask_texture = .Full_Mask
			}
		} else {
			tile_triangle = nil
		}
	}

	if floor.floor > 0 && !game.is_tile_flat(position.xz) {
		return
	}

	if triangle_mode {
		set_tile_triangle(position, side, tile_triangle)
	} else {
		if game.has_north_west_south_east_wall(position) {
			set_tile_triangle(position, side, tile_triangle)
			next_side := side
			switch side {
			case .West:
				next_side = .South
			case .South:
				next_side = .West
			case .East:
				next_side = .North
			case .North:
				next_side = .East
			}
			set_tile_triangle(position, next_side, tile_triangle)
		} else if game.has_south_west_north_east_wall(position) {
			set_tile_triangle(position, side, tile_triangle)
			next_side := side
			switch side {
			case .West:
				next_side = .North
			case .South:
				next_side = .East
			case .East:
				next_side = .South
			case .North:
				next_side = .West
			}
			set_tile_triangle(position, next_side, tile_triangle)
		} else {
			for side in game.Tile_Triangle_Side {
				set_tile_triangle(position, side, tile_triangle)
			}
		}
	}
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

revert_tiles :: proc() {
    floor := game.get_floor_context()
	for k, v in previous_floor_tiles {
		if k.pos.y != floor.floor && v.?.texture == .Floor_Marker {
		    game.tile_triangle_set_tile_triangle(k.pos, k.side, nil)
		} else {
		    game.tile_triangle_set_tile_triangle(k.pos, k.side, v)
        }
	}

	clear(&previous_floor_tiles)
	clear(&new_floor_tiles)
}

set_tiles :: proc(delete_mode: bool) {
    floor := game.get_floor_context()
	start := glsl.ivec3{}
	end := glsl.ivec3{}
	start.x = min(drag_start.x, position.x)
	end.x = max(drag_start.x, position.x)
	start.y = min(drag_start.y, floor.floor)
	end.y = max(drag_start.y, floor.floor)
	start.z = min(drag_start.z, position.y)
	end.z = max(drag_start.z, position.y)

	log.info(drag_start)
	for floor in start.y ..= end.y {
		pos := drag_start
		pos.y = floor
		if delete_mode {
			if floor == 0 {
				flood_fill(pos, side, .Grass_004, start, end, true)
			} else if game.is_tile_flat(start.xz) {
				flood_fill(pos, side, .Floor_Marker, start, end, true)
			}
		} else {
			flood_fill(pos, side, active_texture, start, end, true)
		}
	}
}

undo :: proc(command: Command) {
	for k, v in command.before {
		game.tile_triangle_set_tile_triangle(k.pos, k.side, v)
	}
}

redo :: proc(command: Command) {
	for k, v in command.after {
		game.tile_triangle_set_tile_triangle(k.pos, k.side, v)
	}
}
