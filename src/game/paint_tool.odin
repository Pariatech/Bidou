package game

import "core:log"
import "core:math"
import "core:math/linalg/glsl"

PAINT_TOOL_WALL_SELECTION_DISTANCE :: 4

PAINT_TOOL_WALL_SIDE_MAP :: [Wall_Axis][Camera_Rotation]Wall_Side {
	.N_S =  {
		.South_West = .Outside,
		.South_East = .Inside,
		.North_East = .Inside,
		.North_West = .Outside,
	},
	.E_W =  {
		.South_West = .Outside,
		.South_East = .Outside,
		.North_East = .Inside,
		.North_West = .Inside,
	},
	.SW_NE =  {
		.South_West = .Inside,
		.South_East = .Outside,
		.North_East = .Outside,
		.North_West = .Inside,
	},
	.NW_SE =  {
		.South_West = .Outside,
		.South_East = .Outside,
		.North_East = .Inside,
		.North_West = .Inside,
	},
}

PAINT_TOOL_NEXT_LEFT_WALL_MAP :: [Wall_Axis][Wall_Side][]Paint_Tool_Next_Wall {
	.E_W =  {
		.Inside =  {
			{type = .N_S, position = {1, 0, 0}, side = .Outside},
			{type = .SW_NE, position = {1, 0, 0}, side = .Outside},
			{type = .E_W, position = {1, 0, 0}, side = .Inside},
			{type = .NW_SE, position = {1, 0, -1}, side = .Inside},
			{type = .N_S, position = {1, 0, -1}, side = .Inside},
			{type = .E_W, position = {0, 0, 0}, side = .Outside},
		},
		.Outside =  {
			{type = .N_S, position = {0, 0, -1}, side = .Inside},
			{type = .SW_NE, position = {-1, 0, -1}, side = .Inside},
			{type = .E_W, position = {-1, 0, 0}, side = .Outside},
			{type = .NW_SE, position = {-1, 0, 0}, side = .Outside},
			{type = .N_S, position = {0, 0, 0}, side = .Outside},
			{type = .E_W, position = {0, 0, 0}, side = .Inside},
		},
	},
	.N_S =  {
		.Inside =  {
			{type = .E_W, position = {0, 0, 0}, side = .Inside},
			{type = .NW_SE, position = {0, 0, -1}, side = .Inside},
			{type = .N_S, position = {0, 0, -1}, side = .Inside},
			{type = .SW_NE, position = {-1, 0, -1}, side = .Inside},
			{type = .E_W, position = {-1, 0, 0}, side = .Outside},
			{type = .N_S, position = {0, 0, 0}, side = .Outside},
		},
		.Outside =  {
			{type = .E_W, position = {-1, 0, 1}, side = .Outside},
			{type = .NW_SE, position = {-1, 0, 1}, side = .Outside},
			{type = .N_S, position = {0, 0, 1}, side = .Outside},
			{type = .SW_NE, position = {0, 0, 1}, side = .Outside},
			{type = .E_W, position = {0, 0, 1}, side = .Inside},
			{type = .N_S, position = {0, 0, 0}, side = .Inside},
		},
	},
	.NW_SE =  {
		.Inside =  {
			{type = .SW_NE, position = {1, 0, 0}, side = .Outside},
			{type = .E_W, position = {1, 0, 0}, side = .Inside},
			{type = .NW_SE, position = {1, 0, -1}, side = .Inside},
			{type = .N_S, position = {1, 0, -1}, side = .Inside},
			{type = .SW_NE, position = {0, 0, -1}, side = .Inside},
			{type = .NW_SE, position = {0, 0, 0}, side = .Outside},
		},
		.Outside =  {
			{type = .SW_NE, position = {-1, 0, 0}, side = .Inside},
			{type = .E_W, position = {-1, 0, 1}, side = .Outside},
			{type = .NW_SE, position = {-1, 0, 1}, side = .Outside},
			{type = .N_S, position = {0, 0, 1}, side = .Outside},
			{type = .SW_NE, position = {0, 0, 1}, side = .Outside},
			{type = .NW_SE, position = {0, 0, 0}, side = .Inside},
		},
	},
	.SW_NE =  {
		.Inside =  {
			{type = .NW_SE, position = {0, 0, -1}, side = .Inside},
			{type = .N_S, position = {0, 0, -1}, side = .Inside},
			{type = .SW_NE, position = {-1, 0, -1}, side = .Inside},
			{type = .E_W, position = {-1, 0, 0}, side = .Outside},
			{type = .NW_SE, position = {-1, 0, 0}, side = .Outside},
			{type = .SW_NE, position = {0, 0, 0}, side = .Outside},
		},
		.Outside =  {
			{type = .NW_SE, position = {0, 0, 1}, side = .Outside},
			{type = .N_S, position = {1, 0, 1}, side = .Outside},
			{type = .SW_NE, position = {1, 0, 1}, side = .Outside},
			{type = .E_W, position = {1, 0, 1}, side = .Inside},
			{type = .NW_SE, position = {1, 0, 0}, side = .Inside},
			{type = .SW_NE, position = {0, 0, 0}, side = .Inside},
		},
	},
}

PAINT_TOOL_NEXT_RIGHT_WALL_MAP ::
	[Wall_Axis][Wall_Side][]Paint_Tool_Next_Wall {
		.E_W =  {
			.Inside =  {
				{type = .N_S, position = {-1, 0, 0}, side = .Inside},
				{type = .NW_SE, position = {-1, 0, 0}, side = .Inside},
				{type = .E_W, position = {-1, 0, 0}, side = .Inside},
				{type = .SW_NE, position = {-1, 0, -1}, side = .Outside},
				{type = .N_S, position = {0, 0, -1}, side = .Outside},
				{type = .E_W, position = {0, 0, 0}, side = .Outside},
			},
			.Outside =  {
				{type = .N_S, position = {1, 0, -1}, side = .Outside},
				{type = .NW_SE, position = {1, 0, -1}, side = .Outside},
				{type = .E_W, position = {1, 0, 0}, side = .Outside},
				{type = .SW_NE, position = {1, 0, 0}, side = .Inside},
				{type = .N_S, position = {1, 0, 0}, side = .Inside},
				{type = .E_W, position = {0, 0, 0}, side = .Inside},
			},
		},
		.N_S =  {
			.Inside =  {
				{type = .E_W, position = {0, 0, 1}, side = .Outside},
				{type = .SW_NE, position = {0, 0, 1}, side = .Inside},
				{type = .N_S, position = {0, 0, 1}, side = .Inside},
				{type = .NW_SE, position = {-1, 0, 1}, side = .Inside},
				{type = .E_W, position = {-1, 0, 1}, side = .Inside},
				{type = .N_S, position = {0, 0, 0}, side = .Outside},
			},
			.Outside =  {
				{type = .E_W, position = {-1, 0, 0}, side = .Inside},
				{type = .SW_NE, position = {-1, 0, -1}, side = .Outside},
				{type = .N_S, position = {0, 0, -1}, side = .Outside},
				{type = .NW_SE, position = {0, 0, -1}, side = .Outside},
				{type = .E_W, position = {0, 0, 0}, side = .Outside},
				{type = .N_S, position = {0, 0, 0}, side = .Inside},
			},
		},
		.NW_SE =  {
			.Inside =  {
				{type = .SW_NE, position = {0, 0, 1}, side = .Inside},
				{type = .N_S, position = {0, 0, 1}, side = .Inside},
				{type = .NW_SE, position = {-1, 0, 1}, side = .Inside},
				{type = .E_W, position = {-1, 0, 1}, side = .Inside},
				{type = .SW_NE, position = {-1, 0, 0}, side = .Outside},
				{type = .NW_SE, position = {0, 0, 0}, side = .Outside},
			},
			.Outside =  {
				{type = .SW_NE, position = {0, 0, -1}, side = .Outside},
				{type = .N_S, position = {1, 0, -1}, side = .Outside},
				{type = .NW_SE, position = {1, 0, -1}, side = .Outside},
				{type = .E_W, position = {1, 0, 0}, side = .Outside},
				{type = .SW_NE, position = {1, 0, 0}, side = .Inside},
				{type = .NW_SE, position = {0, 0, 0}, side = .Inside},
			},
		},
		.SW_NE =  {
			.Inside =  {
				{type = .NW_SE, position = {1, 0, 0}, side = .Outside},
				{type = .E_W, position = {1, 0, 1}, side = .Outside},
				{type = .SW_NE, position = {1, 0, 1}, side = .Inside},
				{type = .N_S, position = {1, 0, 1}, side = .Inside},
				{type = .NW_SE, position = {0, 0, 1}, side = .Inside},
				{type = .SW_NE, position = {0, 0, 0}, side = .Outside},
			},
			.Outside =  {
				{type = .NW_SE, position = {-1, 0, 0}, side = .Inside},
				{type = .E_W, position = {-1, 0, 0}, side = .Inside},
				{type = .SW_NE, position = {-1, 0, -1}, side = .Outside},
				{type = .N_S, position = {0, 0, -1}, side = .Outside},
				{type = .NW_SE, position = {0, 0, -1}, side = .Outside},
				{type = .SW_NE, position = {0, 0, 0}, side = .Inside},
			},
		},
	}

Paint_Tool_Next_Wall :: struct {
	position: glsl.ivec3,
	side:     Wall_Side,
	type:     Wall_Axis,
	wall:     Wall,
}

Paint_Tool :: struct {
	position:             glsl.ivec3,
	side:                 Tile_Triangle_Side,
	found_wall:           bool,
	found_wall_intersect: Paint_Tool_Wall_Intersect,
	found_wall_texture:   Wall_Texture,
	texture:              Wall_Texture,
	dirty:                bool,
	previous_walls:       [Wall_Axis]map[glsl.ivec3][Wall_Side]Wall_Texture,
	current_command:      Paint_Tool_Command,
}

Paint_Tool_Wall_Key :: struct {
	axis: Wall_Axis,
	pos:  glsl.ivec3,
	side: Wall_Side,
}

Paint_Tool_Command :: struct {
	before: map[Paint_Tool_Wall_Key]Wall_Texture,
	after:  map[Paint_Tool_Wall_Key]Wall_Texture,
}

Paint_Tool_Wall_Intersect :: struct {
	pos:  glsl.ivec3,
	axis: Wall_Axis,
}

paint_tool :: proc() -> ^Paint_Tool {
	return &game().paint_tool
}

paint_tool_init :: proc() {
	get_floor_context().show_markers = false
}

paint_tool_deinit :: proc() {
	// paint_tool_clear_previous_walls()
	side_map := PAINT_TOOL_WALL_SIDE_MAP
	for &axis_walls, axis in paint_tool().previous_walls {
		for pos, textures in axis_walls {
			if w, ok := get_wall(pos, axis); ok {
				w.textures = textures
				set_wall(pos, axis, w)
			}
		}
		delete(axis_walls)
	}
    delete(paint_tool().current_command.before)
    delete(paint_tool().current_command.after)
}

paint_tool_update :: proc() {
	previous_position := paint_tool().position
	previous_side := paint_tool().side

	floor := get_floor_context()
	on_cursor_tile_intersect(
		paint_tool_on_intersect,
		floor.previous_floor,
		floor.floor,
	)

	texture := paint_tool().texture
	if keyboard_is_key_down(.Key_Left_Control) {
		texture = .Drywall
	}
	delete_state_changed :=
		keyboard_is_key_press(.Key_Left_Control) ||
		keyboard_is_key_release(.Key_Left_Control)

	if mouse_is_button_release(.Left) {
		tools_add_command(paint_tool().current_command)
		paint_tool().current_command = {}
	}

	changed :=
		paint_tool().dirty ||
		previous_position != paint_tool().position ||
		previous_side != paint_tool().side ||
		delete_state_changed ||
		keyboard_is_key_press(.Key_Left_Shift) ||
		keyboard_is_key_release(.Key_Left_Shift)
	if changed {
		previous_found_wall := paint_tool().found_wall
		previous_found_wall_intersect := paint_tool().found_wall_intersect

		paint_tool().found_wall_intersect, paint_tool().found_wall =
			paint_tool_find_wall_intersect(
				paint_tool().position,
				paint_tool().side,
			)
		paint_tool_clear_previous_walls()

		if mouse_is_button_down(.Left) {
			paint_tool().found_wall_texture = texture
		} else {
			paint_tool().found_wall_texture =
				paint_tool_get_found_wall_texture()
			clear(&paint_tool().current_command.before)
			clear(&paint_tool().current_command.after)
		}

		if keyboard_is_key_down(.Key_Left_Shift) {
			paint_tool_apply_flood_fill(texture)
		}

		paint_tool_paint_wall(
			paint_tool().found_wall_intersect.pos,
			paint_tool().found_wall_intersect.axis,
			texture,
		)

		update_cutaways(true)
		if paint_tool().found_wall {
			set_wall_up(
				paint_tool().found_wall_intersect.pos,
				paint_tool().found_wall_intersect.axis,
			)
		}
	} else if paint_tool().found_wall && mouse_is_button_down(.Left) {
		for &axis_walls in paint_tool().previous_walls {
			clear(&axis_walls)
		}
		paint_tool().found_wall_texture = texture
		update_cutaways(true)
	}

	paint_tool().dirty = false
}

paint_tool_set_texture :: proc(tex: Wall_Texture) {
	paint_tool().texture = tex
	paint_tool().dirty = true
}

paint_tool_apply_flood_fill :: proc(texture: Wall_Texture) {
	side_map := PAINT_TOOL_WALL_SIDE_MAP
	wall_side :=
		side_map[paint_tool().found_wall_intersect.axis][camera().rotation]

	paint_tool_flood_fill(
		paint_tool().found_wall_intersect.pos,
		paint_tool().found_wall_intersect.axis,
		wall_side,
		paint_tool().found_wall_texture,
		paint_tool().texture,
	)
}

paint_tool_clear_previous_walls :: proc() {
	side_map := PAINT_TOOL_WALL_SIDE_MAP
	for &axis_walls, axis in paint_tool().previous_walls {
		for pos, textures in axis_walls {
			if w, ok := get_wall(pos, axis); ok {
				w.textures = textures
				set_wall(pos, axis, w)
			}
		}
		clear(&axis_walls)
	}
}

paint_tool_get_found_wall_texture :: proc() -> Wall_Texture {
	side_map := PAINT_TOOL_WALL_SIDE_MAP

	switch paint_tool().found_wall_intersect.axis {
	case .E_W:
		if w, ok := get_east_west_wall(paint_tool().found_wall_intersect.pos);
		   ok {
			return(
				w.textures[side_map[paint_tool().found_wall_intersect.axis][camera().rotation]] \
			)
		}
	case .N_S:
		if w, ok := get_north_south_wall(
			paint_tool().found_wall_intersect.pos,
		); ok {
			return(
				w.textures[side_map[paint_tool().found_wall_intersect.axis][camera().rotation]] \
			)
		}
	case .NW_SE:
		if w, ok := get_north_west_south_east_wall(
			paint_tool().found_wall_intersect.pos,
		); ok {
			return(
				w.textures[side_map[paint_tool().found_wall_intersect.axis][camera().rotation]] \
			)
		}
	case .SW_NE:
		if w, ok := get_south_west_north_east_wall(
			paint_tool().found_wall_intersect.pos,
		); ok {
			return(
				w.textures[side_map[paint_tool().found_wall_intersect.axis][camera().rotation]] \
			)
		}
	}
	return .Drywall
}

paint_tool_update_current_command :: proc(
	position: glsl.ivec3,
	axis: Wall_Axis,
	side: Wall_Side,
	texture: Wall_Texture,
	w: Wall,
) {
	key := Paint_Tool_Wall_Key {
		axis = axis,
		pos  = position,
		side = side,
	}

	if !(key in paint_tool().current_command.before) {
		paint_tool().current_command.before[key] = w.textures[side]
		paint_tool().current_command.after[key] = texture
	}
}

paint_tool_paint_wall :: proc(
	position: glsl.ivec3,
	axis: Wall_Axis,
	texture: Wall_Texture,
) {
	side_map := PAINT_TOOL_WALL_SIDE_MAP
	switch axis {
	case .E_W:
		if w, ok := get_east_west_wall(position); ok {
			paint_tool_save_old_wall(axis, position, w)
			side := side_map[axis][camera().rotation]
			paint_tool_update_current_command(position, axis, side, texture, w)
			w.textures[side] = texture
			set_east_west_wall(position, w)
		}
	case .N_S:
		if w, ok := get_north_south_wall(position); ok {
			paint_tool_save_old_wall(axis, position, w)
			side := side_map[axis][camera().rotation]
			paint_tool_update_current_command(position, axis, side, texture, w)
			w.textures[side] = texture
			set_north_south_wall(position, w)
		}
	case .NW_SE:
		if w, ok := get_north_west_south_east_wall(position); ok {
			paint_tool_save_old_wall(axis, position, w)
			side := side_map[axis][camera().rotation]
			paint_tool_update_current_command(position, axis, side, texture, w)
			w.textures[side] = texture
			set_north_west_south_east_wall(position, w)
		}
	case .SW_NE:
		if w, ok := get_south_west_north_east_wall(position); ok {
			paint_tool_save_old_wall(axis, position, w)
			side := side_map[axis][camera().rotation]
			paint_tool_update_current_command(position, axis, side, texture, w)
			w.textures[side] = texture
			set_south_west_north_east_wall(position, w)
		}
	}
}

paint_tool_on_intersect :: proc(intersect: glsl.vec3) {
	floor := get_floor_context()
	paint_tool().position.x = i32(intersect.x + 0.5)
	paint_tool().position.y = floor.floor
	paint_tool().position.z = i32(intersect.z + 0.5)

	x := intersect.x - math.floor(intersect.x + 0.5)
	z := intersect.z - math.floor(intersect.z + 0.5)

	if x >= z && x <= -z {
		paint_tool().side = .South
	} else if z >= -x && z <= x {
		paint_tool().side = .East
	} else if x >= -z && x <= z {
		paint_tool().side = .North
	} else {
		paint_tool().side = .West
	}
}

paint_tool_find_wall_intersect :: proc(
	position: glsl.ivec3,
	side: Tile_Triangle_Side,
) -> (
	Paint_Tool_Wall_Intersect,
	bool,
) {
	switch camera().rotation {
	case .South_West:
		return paint_tool_find_south_west_wall_intersect(position, side)
	case .South_East:
		return paint_tool_find_south_east_wall_intersect(position, side)
	case .North_East:
		return paint_tool_find_north_east_wall_intersect(position, side)
	case .North_West:
		return paint_tool_find_north_west_wall_intersect(position, side)
	}

	return {}, false
}

paint_tool_find_south_west_wall_intersect :: proc(
	position: glsl.ivec3,
	side: Tile_Triangle_Side,
) -> (
	Paint_Tool_Wall_Intersect,
	bool,
) {
	wall_selection_distance := i32(PAINT_TOOL_WALL_SELECTION_DISTANCE)
	if get_cutaway_context().cutaway_state == .Down {
		wall_selection_distance = 1
	}
	switch side {
	case .South:
		for i in i32(0) ..< wall_selection_distance {
			if pos :=
				   position -
				    {
						   wall_selection_distance - i,
						   0,
						   wall_selection_distance - i,
					   }; has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - i,
					   }; has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - i,
					   }; has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
		}
	case .East:
		for i in i32(0) ..< wall_selection_distance {
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - i,
					   }; has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - i,
					   }; has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
		}
	case .North:
		for i in i32(0) ..< wall_selection_distance {
			if pos :=
				   position -
				    {
						   wall_selection_distance - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
		}
	case .West:
		for i in i32(0) ..< wall_selection_distance {
			if pos := position - {wall_selection_distance - i, 0, 4 - i};
			   has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos :=
				   position -
				    {
						   wall_selection_distance - 1 - i,
						   0,
						   wall_selection_distance - 1 - i,
					   }; has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
		}
	}

	return {}, false
}

paint_tool_find_south_east_wall_intersect :: proc(
	position: glsl.ivec3,
	side: Tile_Triangle_Side,
) -> (
	Paint_Tool_Wall_Intersect,
	bool,
) {
	switch side {
	case .South:
		for i in i32(0) ..< 4 {
			if pos := position - {-4 + i, 0, 4 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position - {-4 + i, 0, 4 - i};
			   has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos := position - {-3 + i, 0, 4 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position - {-3 + i, 0, 3 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
		}
	case .West:
		for i in i32(0) ..< 4 {
			if pos := position - {-4 + i, 0, 4 - i};
			   has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos := position - {-3 + i, 0, 4 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position - {-3 + i, 0, 3 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos := position - {-3 + i, 0, 3 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
		}
	case .North:
		for i in i32(0) ..< 4 {
			if pos := position - {-4 + i, 0, 3 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos := position - {-4 + i, 0, 3 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position - {-4 + i, 0, 3 - i};
			   has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos := position - {-3 + i, 0, 3 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
		}
	case .East:
		for i in i32(0) ..< 4 {
			if pos := position - {-4 + i, 0, 4 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position - {-4 + i, 0, 3 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos := position - {-4 + i, 0, 3 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position - {-4 + i, 0, 3 - i};
			   has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
		}
	}

	return {}, false
}

paint_tool_find_north_east_wall_intersect :: proc(
	position: glsl.ivec3,
	side: Tile_Triangle_Side,
) -> (
	Paint_Tool_Wall_Intersect,
	bool,
) {
	switch side {
	case .South:
		for i in i32(0) ..< 4 {
			if pos := position + {4 - i, 0, 4 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos := position + {4 - i, 0, 3 - i};
			   has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos := position + {4 - i, 0, 3 - i}; has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos := position + {3 - i, 0, 3 - i};
			   has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
		}
	case .East:
		for i in i32(0) ..< 4 {
			if pos := position + {4 - i, 0, 4 - i};
			   has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos := position + {4 - i, 0, 4 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos := position + {4 - i, 0, 3 - i};
			   has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos := position + {4 - i, 0, 3 - i}; has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
		}
	case .North:
		for i in i32(0) ..< 4 {
			if pos := position + {4 - i, 0, 4 - i};
			   has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos := position + {4 - i, 0, 4 - i}; has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos := position + {3 - i, 0, 4 - i};
			   has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos := position + {3 - i, 0, 4 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
		}
	case .West:
		for i in i32(0) ..< 4 {
			if pos := position + {4 - i, 0, 4 - i}; has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos := position + {3 - i, 0, 4 - i};
			   has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
			if pos := position + {3 - i, 0, 4 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos := position + {3 - i, 0, 3 - i};
			   has_north_west_south_east_wall(pos) {
				return {pos, .NW_SE}, true
			}
		}
	}

	return {}, false
}

paint_tool_find_north_west_wall_intersect :: proc(
	position: glsl.ivec3,
	side: Tile_Triangle_Side,
) -> (
	Paint_Tool_Wall_Intersect,
	bool,
) {
	switch side {
	case .South:
		for i in i32(0) ..< 4 {
			if pos := position + {-4 + i, 0, 4 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos := position + {-4 + i, 0, 3 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position + {-3 + i, 0, 3 - i};
			   has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos := position + {-3 + i, 0, 3 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
		}
	case .West:
		for i in i32(0) ..< 4 {
			if pos := position + {-4 + i, 0, 4 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position + {-4 + i, 0, 4 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos := position + {-4 + i, 0, 3 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position + {-3 + i, 0, 3 - i};
			   has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
		}
	case .North:
		for i in i32(0) ..< 4 {
			if pos := position + {-4 + i, 0, 4 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position + {-3 + i, 0, 4 - i};
			   has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos := position + {-3 + i, 0, 4 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position + {-3 + i, 0, 4 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
		}
	case .East:
		for i in i32(0) ..< 4 {
			if pos := position + {-3 + i, 0, 4 - i};
			   has_north_south_wall(pos) {
				return {pos, .N_S}, true
			}
			if pos := position + {-3 + i, 0, 4 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
			if pos := position + {-3 + i, 0, 4 - i}; has_east_west_wall(pos) {
				return {pos, .E_W}, true
			}
			if pos := position + {-3 + i, 0, 3 - i};
			   has_south_west_north_east_wall(pos) {
				return {pos, .SW_NE}, true
			}
		}
	}

	return {}, false
}

paint_tool_undo :: proc(command: Paint_Tool_Command) {
	for k, v in command.before {
		if w, ok := get_wall(k.pos, k.axis); ok {
			w.textures[k.side] = v
			set_wall(k.pos, k.axis, w)
		}
	}
}

paint_tool_redo :: proc(command: Paint_Tool_Command) {
	for k, v in command.after {
		if w, ok := get_wall(k.pos, k.axis); ok {
			w.textures[k.side] = v
			set_wall(k.pos, k.axis, w)
		}
	}
}

paint_tool_flood_fill :: proc(
	position: glsl.ivec3,
	type: Wall_Axis,
	side: Wall_Side,
	previous_texture: Wall_Texture,
	texture: Wall_Texture,
) {
	if previous_texture == texture {
		return
	}
	next_wall, ok := paint_tool_get_next_left_wall(
		{position = position, side = side, type = type},
		previous_texture,
	)
	for ok {
		paint_tool_paint_next_wall(next_wall, texture)
		next_wall, ok = paint_tool_get_next_left_wall(
			next_wall,
			previous_texture,
		)
	}

	next_wall, ok = paint_tool_get_next_right_wall(
		{position = position, side = side, type = type},
		previous_texture,
	)
	for ok {
		paint_tool_paint_next_wall(next_wall, texture)
		next_wall, ok = paint_tool_get_next_right_wall(
			next_wall,
			previous_texture,
		)
	}
}

paint_tool_save_old_wall :: proc(axis: Wall_Axis, pos: glsl.ivec3, w: Wall) {
	if !(pos in paint_tool().previous_walls[axis]) {
		paint_tool().previous_walls[axis][pos] = w.textures
	}
}

paint_tool_paint_next_wall :: proc(
	next_wall: Paint_Tool_Next_Wall,
	texture: Wall_Texture,
) {
	w := next_wall.wall
	paint_tool_save_old_wall(next_wall.type, next_wall.position, w)
	paint_tool_update_current_command(
		next_wall.position,
		next_wall.type,
		next_wall.side,
		texture,
		w,
	)
	w.textures[next_wall.side] = texture
	paint_tool_set_wall_by_type(next_wall.position, next_wall.type, w)
}

paint_tool_set_wall_by_type :: proc(
	position: glsl.ivec3,
	type: Wall_Axis,
	w: Wall,
) {
	switch type {
	case .E_W:
		set_east_west_wall(position, w)
	case .N_S:
		set_north_south_wall(position, w)
	case .NW_SE:
		set_north_west_south_east_wall(position, w)
	case .SW_NE:
		set_south_west_north_east_wall(position, w)
	}
}

paint_tool_get_wall_by_type :: proc(
	position: glsl.ivec3,
	type: Wall_Axis,
) -> (
	Wall,
	bool,
) {
	switch type {
	case .E_W:
		return get_east_west_wall(position)
	case .N_S:
		return get_north_south_wall(position)
	case .NW_SE:
		return get_north_west_south_east_wall(position)
	case .SW_NE:
		return get_south_west_north_east_wall(position)
	}

	return {}, false
}

paint_tool_get_next_left_wall :: proc(
	current: Paint_Tool_Next_Wall,
	texture: Wall_Texture,
) -> (
	Paint_Tool_Next_Wall,
	bool,
) {
	return paint_tool_get_next_wall(current, texture, PAINT_TOOL_NEXT_LEFT_WALL_MAP)
}

paint_tool_get_next_right_wall :: proc(
	current: Paint_Tool_Next_Wall,
	texture: Wall_Texture,
) -> (
	Paint_Tool_Next_Wall,
	bool,
) {
	return paint_tool_get_next_wall(current, texture, PAINT_TOOL_NEXT_RIGHT_WALL_MAP)
}

paint_tool_get_next_wall :: proc(
	current: Paint_Tool_Next_Wall,
	texture: Wall_Texture,
	next_wall_map: [Wall_Axis][Wall_Side][]Paint_Tool_Next_Wall,
) -> (
	Paint_Tool_Next_Wall,
	bool,
) {
	next_wall_list := next_wall_map[current.type][current.side]

	for next_wall in next_wall_list {
		w, ok := paint_tool_get_wall_by_type(
			current.position + next_wall.position,
			next_wall.type,
		)

		if !ok {
			continue
		}

		if w.textures[next_wall.side] == texture {
			next_wall := next_wall
			next_wall.position += current.position
			next_wall.wall = w
			return next_wall, true
		}

		return {}, false
	}

	return {}, false
}
