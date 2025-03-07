package game

import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:time"


Floor_Tool :: struct {
	position:             glsl.ivec2,
	side:                 Tile_Triangle_Side,
	drag_start:           glsl.ivec3,
	drag_start_side:      Tile_Triangle_Side,
	active_texture:       Tile_Triangle_Texture, // = .Wood_Floor_008,
	active_rotation:      Tile_Triangle_Side,
	triangle_mode:        bool, // = false,
	placing:              bool, // = false,
	previous_floor_tiles: map[Floor_Tool_Tile_Triangle_Key]Maybe(
		Tile_Triangle,
	),
	new_floor_tiles:      map[Floor_Tool_Tile_Triangle_Key]Maybe(
		Tile_Triangle,
	),
}

Floor_Tool_Tile_Triangle_Key :: struct {
	pos:  glsl.ivec3,
	side: Tile_Triangle_Side,
}

Floor_Tool_Command :: struct {
	before: map[Floor_Tool_Tile_Triangle_Key]Maybe(Tile_Triangle),
	after:  map[Floor_Tool_Tile_Triangle_Key]Maybe(Tile_Triangle),
}

Floor_Tool_Visited_Tile_Triangle :: struct {
	position: glsl.ivec3,
	side:     Tile_Triangle_Side,
}

floor_tool :: proc() -> ^Floor_Tool {
	return &game().floor_tool
}

floor_tool_init :: proc() {
	floor_tool().triangle_mode = false
	get_floor_context().show_markers = true
	floor_tool().active_texture = .Wood_Floor_008
}

floor_tool_deinit :: proc() {
	// floor_tool_revert_tiles()
	delete(floor_tool().previous_floor_tiles)
	delete(floor_tool().new_floor_tiles)
}

floor_tool_update :: proc() {
	previous_position := floor_tool().position
	previous_side := floor_tool().side
	previous_rotation := floor_tool().active_rotation
	floor := get_floor_context()
	on_cursor_tile_intersect(
		floor_tool_on_intersect,
		floor.previous_floor,
		floor.floor,
	)

	if keyboard_is_key_press(.Key_R) {
		floor_tool().active_rotation = Tile_Triangle_Side(
			(int(floor_tool().active_rotation) + 1) % len(Tile_Triangle_Side),
		)
	}

	reset :=
		previous_position != floor_tool().position ||
		floor.previous_floor != floor.floor ||
		previous_side != floor_tool().side ||
		keyboard_is_key_press(.Key_Left_Shift) ||
		keyboard_is_key_release(.Key_Left_Shift) ||
		previous_rotation != floor_tool().active_rotation

	previous_triangle_mode := floor_tool().triangle_mode
	if keyboard_is_key_down(.Key_Left_Control) &&
	   keyboard_is_key_press(.Key_F) {
		floor_tool().triangle_mode = !floor_tool().triangle_mode
	}
	if floor_tool().triangle_mode != previous_triangle_mode {
		reset = true
	}

	delete_mode := keyboard_is_key_down(.Key_Left_Control)
	if keyboard_is_key_press(.Key_Left_Control) ||
	   keyboard_is_key_release(.Key_Left_Control) {
		reset = true
	}

	do_revert_tiles := reset
	if do_revert_tiles {
		floor_tool_revert_tiles()
		clear(&floor_tool().new_floor_tiles)
	}

	if keyboard_is_key_down(.Key_Left_Shift) {
		floor_tool().placing = true
		pos := glsl.ivec3 {
			floor_tool().position.x,
			floor.floor,
			floor_tool().position.y,
		}

		start := lots_active_lot_start_pos()
		end := lots_active_lot_end_pos()
		if delete_mode {
			if floor.floor == 0 {
				floor_tool_flood_fill(
					pos,
					floor_tool().side,
					.Grass_004,
					.South,
					{start.x, 0, start.y},
					{end.x, 0, end.y},
				)
			} else if is_tile_flat(pos.xz) {
				floor_tool_flood_fill(
					pos,
					floor_tool().side,
					.Floor_Marker,
					.South,
					{start.x, 0, start.y},
					{end.x, 0, end.y},
				)
			}
		} else {
			floor_tool_flood_fill(
				pos,
				floor_tool().side,
				floor_tool().active_texture,
				floor_tool().active_rotation,
				{start.x, 0, start.y},
				{end.x, 0, end.y},
			)
		}

		if mouse_is_button_press(.Left) {
			floor_tool_save_command()
			clear(&floor_tool().previous_floor_tiles)
		}
	} else if mouse_is_button_press(.Left) {
		floor_tool().placing = true
		floor_tool().drag_start =  {
			floor_tool().position.x,
			floor.floor,
			floor_tool().position.y,
		}
		floor_tool().drag_start_side = floor_tool().side
	} else if floor_tool().placing && mouse_is_button_down(.Left) {
		if reset {
			if floor_tool().triangle_mode {
				floor_tool_set_tile(
					 {
						floor_tool().position.x,
						floor.floor,
						floor_tool().position.y,
					},
					delete_mode,
				)
			} else {
				floor_tool_set_tiles(delete_mode)
			}
		}
	} else if floor_tool().placing && mouse_is_button_release(.Left) {
		floor_tool().placing = false
		floor_tool_save_command()
		clear(&floor_tool().previous_floor_tiles)
	} else {
		floor_tool().drag_start =  {
			floor_tool().position.x,
			floor.floor,
			floor_tool().position.y,
		}
		if reset {
			floor_tool_set_tile(
				 {
					floor_tool().position.x,
					floor.floor,
					floor_tool().position.y,
				},
				delete_mode,
			)
		}
	}
}

floor_tool_save_command :: proc() {
	command: Floor_Tool_Command
	for k, v in floor_tool().previous_floor_tiles {
		command.before[k] = v
	}
	for k, v in floor_tool().new_floor_tiles {
		command.after[k] = v
	}
	tools_add_command(command)
}

floor_tool_set_tile_triangle :: proc(
	position: glsl.ivec3,
	side: Tile_Triangle_Side,
	tile_triangle: Maybe(Tile_Triangle),
) {
	if tile_triangle, ok := tile_triangle_get_tile_triangle(position, side);
	   ok {
		floor_tool().previous_floor_tiles[{position, side}] = tile_triangle
	} else {
		floor_tool().previous_floor_tiles[{position, side}] = nil
	}

	floor_tool().new_floor_tiles[{position, side}] = tile_triangle
	tile_triangle_set_tile_triangle(position, side, tile_triangle)
}

floor_tool_set_tile :: proc(position: glsl.ivec3, delete_mode: bool) {
	if !lots_inside_active_lot(position.xz) {
		return
	}
	floor := get_floor_context()
	active_texture := floor_tool().active_texture
	active_rotation := floor_tool().active_rotation
	tile_triangle: Maybe(Tile_Triangle) = Tile_Triangle {
		texture      = active_texture,
		mask_texture = .Grid_Mask,
		rotation     = active_rotation,
	}
	if delete_mode {
		if position.y == 0 {
			if tile_triangle, ok := &tile_triangle.?; ok {
				tile_triangle.texture = .Grass_004
				tile_triangle.rotation = .South
			}
		} else if position.y == floor.floor && is_tile_flat(position.xz) {
			if tile_triangle, ok := &tile_triangle.?; ok {
				tile_triangle.texture = .Floor_Marker
				tile_triangle.mask_texture = .Full_Mask
				tile_triangle.rotation = .South
			}
		} else {
			tile_triangle = nil
		}
	}

	if floor.floor > 0 && !is_tile_flat(position.xz) {
		return
	}

	if floor_tool().triangle_mode {
		floor_tool_set_tile_triangle(
			position,
			floor_tool().side,
			tile_triangle,
		)
	} else {
		if has_north_west_south_east_wall(position) {
			floor_tool_set_tile_triangle(
				position,
				floor_tool().side,
				tile_triangle,
			)
			next_side := floor_tool().side
			switch floor_tool().side {
			case .West:
				next_side = .South
			case .South:
				next_side = .West
			case .East:
				next_side = .North
			case .North:
				next_side = .East
			}
			floor_tool_set_tile_triangle(position, next_side, tile_triangle)
		} else if has_south_west_north_east_wall(position) {
			floor_tool_set_tile_triangle(
				position,
				floor_tool().side,
				tile_triangle,
			)
			next_side := floor_tool().side
			switch floor_tool().side {
			case .West:
				next_side = .North
			case .South:
				next_side = .East
			case .East:
				next_side = .South
			case .North:
				next_side = .West
			}
			floor_tool_set_tile_triangle(position, next_side, tile_triangle)
		} else {
			for side in Tile_Triangle_Side {
				floor_tool_set_tile_triangle(position, side, tile_triangle)
			}
		}
	}
}

floor_tool_on_intersect :: proc(intersect: glsl.vec3) {
	floor_tool().position.x = i32(intersect.x + 0.5)
	floor_tool().position.y = i32(intersect.z + 0.5)

	x := intersect.x - math.floor(intersect.x + 0.5)
	z := intersect.z - math.floor(intersect.z + 0.5)

	if x >= z && x <= -z {
		floor_tool().side = .South
	} else if z >= -x && z <= x {
		floor_tool().side = .East
	} else if x >= -z && x <= z {
		floor_tool().side = .North
	} else {
		floor_tool().side = .West
	}
}

floor_tool_revert_tiles :: proc() {
	floor := get_floor_context()
	for k, v in floor_tool().previous_floor_tiles {
		if k.pos.y != floor.floor && v.?.texture == .Floor_Marker {
			tile_triangle_set_tile_triangle(k.pos, k.side, nil)
		} else {
			tile_triangle_set_tile_triangle(k.pos, k.side, v)
		}
	}

	clear(&floor_tool().previous_floor_tiles)
	clear(&floor_tool().new_floor_tiles)
}

floor_tool_set_tiles :: proc(delete_mode: bool) {
	floor := get_floor_context()
	start := glsl.ivec3{}
	end := glsl.ivec3{}
	start.x = min(floor_tool().drag_start.x, floor_tool().position.x)
	end.x = max(floor_tool().drag_start.x, floor_tool().position.x)
	start.y = min(floor_tool().drag_start.y, floor.floor)
	end.y = max(floor_tool().drag_start.y, floor.floor)
	start.z = min(floor_tool().drag_start.z, floor_tool().position.y)
	end.z = max(floor_tool().drag_start.z, floor_tool().position.y)

	start.xz = glsl.max(start.xz, lots_active_lot_start_pos())
	end.xz = glsl.min(end.xz, lots_active_lot_end_pos() - {1, 1})

	drag_start := floor_tool().drag_start
	drag_start.xz = glsl.max(drag_start.xz, lots_active_lot_start_pos())
	drag_start.xz = glsl.min(drag_start.xz, lots_active_lot_end_pos() - {1, 1})

	for floor in start.y ..= end.y {
		pos := drag_start
		pos.y = floor
		if delete_mode {
			if floor == 0 {
				floor_tool_flood_fill(
					pos,
					floor_tool().side,
					.Grass_004,
					.South,
					start,
					end,
					true,
				)
			} else if is_tile_flat(start.xz) {
				floor_tool_flood_fill(
					pos,
					floor_tool().side,
					.Floor_Marker,
					.South,
					start,
					end,
					true,
				)
			}
		} else {
			floor_tool_flood_fill(
				pos,
				floor_tool().side,
				floor_tool().active_texture,
				floor_tool().active_rotation,
				start,
				end,
				true,
			)
		}
	}
}

floor_tool_undo :: proc(command: Floor_Tool_Command) {
	for k, v in command.before {
		tile_triangle_set_tile_triangle(k.pos, k.side, v)
	}
}

floor_tool_redo :: proc(command: Floor_Tool_Command) {
	for k, v in command.after {
		tile_triangle_set_tile_triangle(k.pos, k.side, v)
	}
}

floor_tool_flood_fill :: proc(
	position: glsl.ivec3,
	side: Tile_Triangle_Side,
	texture: Tile_Triangle_Texture,
	rotation: Tile_Triangle_Side,
	start: glsl.ivec3,
	end: glsl.ivec3,
	ignore_texture_check: bool = false,
) {
	tile_triangle, ok := tile_triangle_get_tile_triangle(position, side)
	if !ok {return}
	original_texture := tile_triangle.texture
	original_rotation := tile_triangle.rotation
	if original_texture == texture && original_rotation == rotation {return}

	visited_queue: [dynamic]Floor_Tool_Visited_Tile_Triangle
	defer delete(visited_queue)

	visited := Floor_Tool_Visited_Tile_Triangle{position, side}

	floor_tool_set_texture(visited, texture, rotation)

	append(&visited_queue, visited)

	for len(visited_queue) > 0 {
		visited = pop(&visited_queue)
		from := visited
		switch visited.side {
		case .South:
			next_visited := visited
			next_visited.side = .East
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .West
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .North
			next_visited.position -= {0, 0, 1}
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
		case .East:
			next_visited := visited
			next_visited.side = .North
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .South
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .West
			next_visited.position += {1, 0, 0}
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
		case .North:
			next_visited := visited
			next_visited.side = .East
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .West
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .South
			next_visited.position += {0, 0, 1}
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
		case .West:
			next_visited := visited
			next_visited.side = .South
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .North
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .East
			next_visited.position -= {1, 0, 0}
			floor_tool_process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				original_rotation,
				rotation,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
		}
	}
}

floor_tool_process_next_visited :: proc(
	from: Floor_Tool_Visited_Tile_Triangle,
	to: Floor_Tool_Visited_Tile_Triangle,
	original_texture: Tile_Triangle_Texture,
	texture: Tile_Triangle_Texture,
	original_rotation: Tile_Triangle_Side,
	rotation: Tile_Triangle_Side,
	visited_queue: ^[dynamic]Floor_Tool_Visited_Tile_Triangle,
	start: glsl.ivec3,
	end: glsl.ivec3,
	ignore_texture_check: bool,
) {
	if ignore_texture_check {
		if (Floor_Tool_Tile_Triangle_Key{pos = to.position, side = to.side} in
			   floor_tool().previous_floor_tiles) {
			return
		}
	}
	if floor_tool_can_texture(
		   from,
		   to,
		   original_texture,
		   original_rotation,
		   start,
		   end,
		   ignore_texture_check,
	   ) {
		floor_tool_set_texture(to, texture, rotation)
		append(visited_queue, to)
	}
}

floor_tool_set_texture :: proc(
	visited: Floor_Tool_Visited_Tile_Triangle,
	texture: Tile_Triangle_Texture,
	rotation: Tile_Triangle_Side,
) {
	mask_texture: Tile_Triangle_Mask = .Grid_Mask
	if texture == .Floor_Marker {
		mask_texture = .Grid_Mask
	}
	floor_tool_set_tile_triangle(
		visited.position,
		visited.side,
		Tile_Triangle {
			texture = texture,
			mask_texture = mask_texture,
			rotation = rotation,
		},
	)
}

floor_tool_can_texture :: proc(
	from: Floor_Tool_Visited_Tile_Triangle,
	to: Floor_Tool_Visited_Tile_Triangle,
	texture: Tile_Triangle_Texture,
	rotation: Tile_Triangle_Side,
	start: glsl.ivec3,
	end: glsl.ivec3,
	ignore_texture_check: bool,
) -> bool {
	if to.position.x < 0 ||
	   to.position.z < 0 ||
	   to.position.x >= WORLD_WIDTH ||
	   to.position.z >= WORLD_DEPTH ||
	   (to.position.y > 0 && !is_tile_flat(to.position.xz)) ||
	   to.position.x < start.x ||
	   to.position.z < start.z ||
	   to.position.x > end.x ||
	   to.position.z > end.z {
		return false
	}

	switch from.side {
	case .South:
		switch to.side {
		case .South:
		case .East:
			_, ok := get_north_west_south_east_wall(to.position)
			if ok {
				return false
			}
		case .North:
			_, ok := get_east_west_wall(from.position)
			if ok {
				return false
			}
		case .West:
			_, ok := get_south_west_north_east_wall(to.position)
			if ok {
				return false
			}
		}
	case .East:
		switch to.side {
		case .South:
			_, ok := get_north_west_south_east_wall(to.position)
			if ok {
				return false
			}
		case .East:
		case .North:
			_, ok := get_south_west_north_east_wall(to.position)
			if ok {
				return false
			}
		case .West:
			_, ok := get_north_south_wall(to.position)
			if ok {
				return false
			}
		}
	case .North:
		switch to.side {
		case .South:
			_, ok := get_east_west_wall(to.position)
			if ok {
				return false
			}
		case .East:
			_, ok := get_south_west_north_east_wall(to.position)
			if ok {
				return false
			}
		case .North:
		case .West:
			_, ok := get_north_west_south_east_wall(from.position)
			if ok {
				return false
			}
		}
	case .West:
		switch to.side {
		case .South:
			_, ok := get_south_west_north_east_wall(to.position)
			if ok {
				return false
			}
		case .East:
			_, ok := get_north_south_wall(from.position)
			if ok {
				return false
			}
		case .North:
			_, ok := get_north_west_south_east_wall(to.position)
			if ok {
				return false
			}
		case .West:
		}
	}

	tile_triangle, ok := tile_triangle_get_tile_triangle(to.position, to.side)

	return(
		!ok ||
		ignore_texture_check ||
		(tile_triangle.texture == texture &&
				tile_triangle.rotation == rotation) \
	)
	// return !ok || (!ignore_texture_check && tile_triangle.texture == texture)
}
