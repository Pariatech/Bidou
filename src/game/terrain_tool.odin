package game

import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:math/rand"
import "vendor:glfw"


Terrain_Tool :: struct {
	cursor_pos:          glsl.vec3,
	cursor:              Object_Draw,
	intersect:           glsl.vec3,
	position:            glsl.ivec2,
	tick_timer:          f64,
	drag_start:          Maybe(glsl.ivec2),
	drag_end:            Maybe(glsl.ivec2),
	drag_clip:           bool,
	previous_brush_size: i32, // = 1
	brush_size:          i32, //  = 1
	brush_strength:      f32, // = 0.1
	mode:                Terrain_Tool_Mode, // = .Raise
	current_command:     Terrain_Tool_Command,
}

Terrain_Tool_Command :: struct {
	before: map[glsl.ivec2]f32,
	after:  map[glsl.ivec2]f32,
}

Terrain_Tool_Mode :: enum {
	Raise,
	Lower,
	Level,
	Trim,
	Smooth,
	Slope,
}

TERRAIN_TOOL_TICK_SPEED :: 0.125
TERRAIN_TOOL_LOW :: 0
TERRAIN_TOOL_HIGH :: 6
TERRAIN_TOOL_BRUSH_MIN_STRENGTH :: 0.1
TERRAIN_TOOL_BRUSH_MAX_STRENGTH :: 1.0
TERRAIN_TOOL_MIN_SLOPE :: 0.1
TERRAIN_TOOL_MAX_SLOPE :: 1.0
TERRAIN_TOOL_RANDOM_RADIUS :: 3

terrain_tool :: proc() -> ^Terrain_Tool {
    return &game().terrain_tool
}

terrain_tool_init :: proc() {
	cursor_intersect_with_tiles(terrain_tool_on_intersect, 0)
	cursor := get_cursor_context()
	terrain_tool().cursor_pos = cursor.ray.origin

	position := terrain_tool().intersect
	position.x = math.ceil(position.x) - 0.5
	position.z = math.ceil(position.z) - 0.5
	position.y =
		get_terrain_context().terrain_heights[terrain_tool().position.x][terrain_tool().position.y]

	terrain_tool().cursor.model = ROOF_TOOL_CURSOR_MODEL
	terrain_tool().cursor.texture = ROOF_TOOL_CURSOR_TEXTURE
	terrain_tool().cursor.light = {1, 1, 1}

	t := int(terrain_tool().brush_strength * 10 - 1)
	// tex := billboard.Texture_1x1(int(billboard.Texture_1x1.Shovel_1_SW) + t)
	// billboard.billboard_1x1_set(
	// 	terrain_tool_billboard,
	// 	{light = {1, 1, 1}, texture = tex, depth_map = tex},
	// )

	terrain_tool().drag_start = nil
	terrain_tool().drag_end = nil

	terrain_tool().previous_brush_size = 1
	terrain_tool().brush_size  = 1
	terrain_tool().brush_strength = 0.1
	terrain_tool().mode = .Raise

	get_floor_context().show_markers = false
}

terrain_tool_deinit :: proc() {
	terrain_tool_cleanup()
}

terrain_tool_update :: proc(delta_time: f64) {
	terrain_tool_cleanup()

	if keyboard_is_key_press(.Key_Equal) {
		if keyboard_is_key_down(.Key_Left_Shift) {
			terrain_tool_increase_brush_strength()
		} else {
			terrain_tool_increase_brush_size()
		}
		terrain_tool_mark_array_dirty(
			 {
				terrain_tool().position.x - terrain_tool().brush_size,
				terrain_tool().position.y - terrain_tool().brush_size,
			},
			 {
				terrain_tool().position.x + terrain_tool().brush_size,
				terrain_tool().position.y + terrain_tool().brush_size,
			},
		)
	} else if keyboard_is_key_press(.Key_Minus) {
		if keyboard_is_key_down(.Key_Left_Shift) {
			terrain_tool_decrease_brush_strength()
		} else {
			terrain_tool_decrease_brush_size()
		}
		terrain_tool_mark_array_dirty(
			 {
				terrain_tool().position.x - terrain_tool().brush_size - 1,
				terrain_tool().position.y - terrain_tool().brush_size - 1,
			},
			 {
				terrain_tool().position.x + terrain_tool().brush_size + 1,
				terrain_tool().position.y + terrain_tool().brush_size + 1,
			},
		)
	}

	on_cursor_tile_intersect(terrain_tool_on_intersect, 0, 0)

	position := terrain_tool().intersect
	position.x = math.ceil(position.x) - 0.5
	position.z = math.ceil(position.z) - 0.5
	previous_tool_position := terrain_tool().position
	terrain_tool().position.x = i32(position.x + 0.5)
	terrain_tool().position.y = i32(position.z + 0.5)

	if terrain_tool().position != previous_tool_position {
		terrain_tool_mark_array_dirty(
			 {
				terrain_tool().position.x - terrain_tool().brush_size,
				terrain_tool().position.y - terrain_tool().brush_size,
			},
			 {
				terrain_tool().position.x + terrain_tool().brush_size,
				terrain_tool().position.y + terrain_tool().brush_size,
			},
		)
		terrain_tool_mark_array_dirty(
			 {
				previous_tool_position.x - terrain_tool().brush_size,
				previous_tool_position.y - terrain_tool().brush_size,
			},
			 {
				previous_tool_position.x + terrain_tool().brush_size,
				previous_tool_position.y + terrain_tool().brush_size,
			},
		)
	}

	position.y =
		get_terrain_context().terrain_heights[terrain_tool().position.x][terrain_tool().position.y]
	terrain_tool().cursor.transform = glsl.mat4Translate(position)
	shift_down := keyboard_is_key_down(.Key_Left_Shift)

	if mouse_is_button_release(.Left) {
		tools_add_command(terrain_tool().current_command)
		terrain_tool().current_command = {}
	}

	if shift_down ||
	   terrain_tool().mode == .Level ||
	   terrain_tool().mode == .Trim ||
	   terrain_tool().mode == .Slope ||
	   terrain_tool().drag_start != nil {
		terrain_tool_move_points(position)
	} else if keyboard_is_key_down(.Key_Left_Control) || terrain_tool().mode == .Smooth {
		terrain_tool_smooth_brush(delta_time)
	} else {
		terrain_tool_move_point(delta_time)
	}

	if drag_start, ok := terrain_tool().drag_start.?; ok {
		start_x := min(drag_start.x, terrain_tool().position.x)
		start_z := min(drag_start.y, terrain_tool().position.y)
		end_x := max(drag_start.x, terrain_tool().position.x)
		end_z := max(drag_start.y, terrain_tool().position.y)

		for x in start_x ..< end_x {
			for z in start_z ..< end_z {
				tile_triangle_set_tile_mask_texture({x, 0, z}, .Leveling_Brush)
			}
		}
	} else {
		start_x := max(terrain_tool().position.x - terrain_tool().brush_size, 0)
		end_x := min(
			terrain_tool().position.x + terrain_tool().brush_size,
			WORLD_WIDTH,
		)
		start_z := max(terrain_tool().position.y - terrain_tool().brush_size, 0)
		end_z := min(
			terrain_tool().position.y + terrain_tool().brush_size,
			WORLD_DEPTH,
		)
		for x in start_x ..< end_x {
			for z in start_z ..< end_z {
				tile_triangle_set_tile_mask_texture({x, 0, z}, .Dotted_Grid)
			}
		}
	}

	draw_one_object(&terrain_tool().cursor)
}


terrain_tool_on_intersect :: proc(intersect: glsl.vec3) {
	terrain_tool().intersect = intersect
}

terrain_tool_mark_array_dirty :: proc(start: glsl.ivec2, end: glsl.ivec2) {
	start := start
	end := end
	start.x /= CHUNK_WIDTH
	end.x /= CHUNK_WIDTH
	start.y /= CHUNK_DEPTH
	end.y /= CHUNK_DEPTH

	start.x = max(start.x, 0)
	start.y = max(start.y, 0)
	end.x = min(end.x, WORLD_CHUNK_WIDTH - 1)
	end.y = min(end.y, WORLD_CHUNK_DEPTH - 1)

	for i in start.x ..= end.x {
		for j in start.y ..= end.y {
			for floor in 0 ..< CHUNK_HEIGHT {
				get_tile_triangles_context().chunks[floor][i][j].dirty = true
			}
		}
	}
}

terrain_tool_slope_move_point :: proc(x, z: i32) {
	start := terrain_tool().drag_start.?
	end := terrain_tool().position
	terrain := get_terrain_context()
	start_height := terrain.terrain_heights[start.x][start.y]
	end_height := terrain.terrain_heights[end.x][end.y]
	len := abs(end.x - start.x)
	i := abs(x - start.x)
	if abs(end.y - start.y) > abs(end.x - start.x) {
		len = abs(end.y - start.y)
		i = abs(z - start.y)
	}
	min := start_height
	dh := (end_height - start_height) / f32(len)
	height := min + f32(i) * dh

	terrain_tool_set_terrain_height(x, z, height)
}

terrain_tool_move_points :: proc(position: glsl.vec3) {
	if drag_start, ok := terrain_tool().drag_start.?; ok {
		start_x := min(drag_start.x, terrain_tool().position.x)
		start_z := min(drag_start.y, terrain_tool().position.y)
		end_x := max(drag_start.x, terrain_tool().position.x)
		end_z := max(drag_start.y, terrain_tool().position.y)

		if mouse_is_button_up(.Left) {
			if start_x != end_x || start_z != end_z {
				terrain := get_terrain_context()
				height := terrain.terrain_heights[drag_start.x][drag_start.y]

				for x in start_x ..= end_x {
					for z in start_z ..= end_z {
						if terrain_tool().mode == .Trim {
							point_height := terrain.terrain_heights[x][z]
							if point_height > height {
								terrain_tool_set_terrain_height(x, z, height)
							}
						} else if terrain_tool().mode == .Slope {
							terrain_tool_slope_move_point(x, z)
						} else {
							terrain_tool_set_terrain_height(x, z, height)
						}
					}
				}

				for x in start_x ..= end_x {
					for z in start_z ..= end_z {
						calculate_terrain_light(int(x), int(z))
					}
				}
			}

			terrain_tool().drag_start = nil

			terrain_tool_mark_array_dirty(
				 {
					start_x - terrain_tool().brush_size,
					start_z - terrain_tool().brush_size,
				},
				 {
					end_x + terrain_tool().brush_size,
					end_z + terrain_tool().brush_size,
				},
			)
		} else if terrain_tool().drag_end != terrain_tool().position {
			terrain_tool().drag_end = terrain_tool().position
		}

		terrain_tool_mark_array_dirty({start_x, start_z}, {end_x, end_z})
	} else if mouse_is_button_down(.Left) {
		terrain_tool().drag_start = terrain_tool().position
	}
}

terrain_tool_smooth_brush :: proc(delta_time: f64) {
	if mouse_is_button_down(.Left) {
		terrain_tool().tick_timer += delta_time
	} else if mouse_is_button_release(.Left) && terrain_tool().tick_timer > 0 {
		terrain_tool().tick_timer = 0
	}

	if terrain_tool().tick_timer == delta_time ||
	   terrain_tool().tick_timer >= TERRAIN_TOOL_TICK_SPEED {

		start_x := max(
			terrain_tool().position.x - terrain_tool().brush_size + 1,
			0,
		)
		start_z := max(
			terrain_tool().position.y - terrain_tool().brush_size + 1,
			0,
		)
		end_x := min(
			terrain_tool().position.x + terrain_tool().brush_size - 1,
			WORLD_WIDTH,
		)
		end_z := min(
			terrain_tool().position.y + terrain_tool().brush_size - 1,
			WORLD_DEPTH,
		)

		for x in start_x ..= end_x {
			for z in start_z ..= end_z {
				start_x := max(x - 1, 0)
				start_z := max(z - 1, 0)
				end_x := min(x + 1, WORLD_WIDTH)
				end_z := min(z + 1, WORLD_DEPTH)
				points := f32((end_x - start_x + 1) * (end_z - start_z + 1))
				average: f32 = 0

				terrain := get_terrain_context()
				for x in start_x ..= end_x {
					for z in start_z ..= end_z {
						average += terrain.terrain_heights[x][z] / points
					}
				}

				movement := average - terrain.terrain_heights[x][z]
				terrain_tool_set_terrain_height(
					x,
					z,
					terrain.terrain_heights[x][z] +
					movement * terrain_tool().brush_strength,
				)
			}
		}

		terrain_tool_calculate_lights()

		if terrain_tool().tick_timer >= TERRAIN_TOOL_TICK_SPEED {
			terrain_tool().tick_timer = math.max(
				0,
				terrain_tool().tick_timer - TERRAIN_TOOL_TICK_SPEED,
			)
		}

		terrain_tool_mark_array_dirty({start_x, start_z}, {end_x, end_z})
	}
}

terrain_tool_intersect_with_wall :: proc(x, z: i32) -> bool {
	if x > 0 && z < WORLD_DEPTH {
		if _, ok := get_east_west_wall({x - 1, 0, z}); ok {
			return true
		}
		if x < WORLD_WIDTH {
			if _, ok := get_east_west_wall({x, 0, z}); ok {
				return true
			}
		}
	}

	if x < WORLD_WIDTH && z > 0 {
		if _, ok := get_north_south_wall({x, 0, z - 1}); ok {
			return true
		}
		if z < WORLD_DEPTH {
			if _, ok := get_north_south_wall({x, 0, z}); ok {
				return true
			}
		}
	}

	if x > 0 && z > 0 {
		_, ok := get_south_west_north_east_wall({x - 1, 0, z - 1})
		if ok {return true}
	}

	if x < WORLD_WIDTH && z < WORLD_DEPTH {
		_, ok := get_south_west_north_east_wall({x, 0, z})
		if ok {return true}
	}

	if x > 0 && z < WORLD_DEPTH {
		_, ok := get_south_west_north_east_wall({x - 1, 0, z})
		if ok {return true}
	}

	if x < WORLD_WIDTH && z > 0 {
		_, ok := get_south_west_north_east_wall({x, 0, z - 1})
		if ok {return true}
	}

	if x > 0 && z > 0 {
		_, ok := get_north_west_south_east_wall({x - 1, 0, z - 1})
		if ok {return true}
	}

	if x < WORLD_WIDTH && z < WORLD_DEPTH {
		_, ok := get_north_west_south_east_wall({x, 0, z})
		if ok {return true}
	}

	if x < WORLD_WIDTH && z > 0 {
		_, ok := get_north_west_south_east_wall({x, 0, z - 1})
		if ok {return true}
	}

	if x > 0 && z < WORLD_DEPTH {
		_, ok := get_north_west_south_east_wall({x - 1, 0, z})
		if ok {return true}
	}

	return false
}

terrain_tool_intersect_with_floor :: proc(x, z: i32) -> bool {
	for y in 0 ..< WORLD_HEIGHT {
		start_x := math.max(x - 1, 0)
		start_z := math.max(z - 1, 0)
		end_x := math.min(x, WORLD_WIDTH - 1)
		end_z := math.min(z, WORLD_DEPTH - 1)
		for x in start_x ..= end_x {
			for z in start_z ..= end_z {
				triangles := tile_triangle_get_tile({x, i32(y), z})
				for side in Tile_Triangle_Side {
					if triangle, ok := triangles[side].?; ok {
						if triangle.texture != .Grass_004 {
							return true
						}
					}
				}
			}
		}
	}
	return false
}

terrain_tool_set_terrain_height :: proc(x, z: i32, height: f32) {
	if terrain_tool_intersect_with_wall(x, z) {return}
	if terrain_tool_intersect_with_floor(x, z) {return}

	terrain := get_terrain_context()
	if !({x, z} in terrain_tool().current_command.before) {
		terrain_tool().current_command.before[{x, z}] = terrain.terrain_heights[x][z]
	}
	terrain_tool().current_command.after[{x, z}] = height

	terrain.terrain_heights[x][z] = height
}

terrain_tool_calculate_lights :: proc() {
	start_x := max(terrain_tool().position.x - terrain_tool().brush_size, 0)
	end_x := min(
		terrain_tool().position.x + terrain_tool().brush_size,
		WORLD_WIDTH,
	)
	start_z := max(terrain_tool().position.y - terrain_tool().brush_size, 0)
	end_z := min(
		terrain_tool().position.y + terrain_tool().brush_size,
		WORLD_DEPTH,
	)
	terrain := get_terrain_context()
	for x in start_x ..= end_x {
		for z in start_z ..= end_z {
			calculate_terrain_light(int(x), int(z))
		}
	}
}

terrain_tool_move_point :: proc(delta_time: f64) {
	movement: f32 = 0
	if mouse_is_button_down(.Left) && terrain_tool().mode == .Raise {
		movement = terrain_tool().brush_strength
		terrain_tool().tick_timer += delta_time
	} else if (mouse_is_button_down(.Right) && terrain_tool().mode == .Raise) ||
	   (mouse_is_button_down(.Left) && terrain_tool().mode == .Lower) {
		movement = -terrain_tool().brush_strength
		terrain_tool().tick_timer += delta_time
	} else if mouse_is_button_release(.Left) && terrain_tool().tick_timer > 0 {
		terrain_tool().tick_timer = 0
	}

	if terrain_tool().tick_timer == delta_time ||
	   terrain_tool().tick_timer >= TERRAIN_TOOL_TICK_SPEED {
		terrain_tool_move_point_height(
			terrain_tool().position.x,
			terrain_tool().position.y,
			movement,
		)
		terrain_tool_adjust_points(
			int(terrain_tool().position.x),
			int(terrain_tool().position.y),
			0,
			0,
			movement,
		)
		terrain_tool_calculate_lights()

		if terrain_tool().tick_timer >= TERRAIN_TOOL_TICK_SPEED {
			terrain_tool().tick_timer = math.max(
				0,
				terrain_tool().tick_timer - TERRAIN_TOOL_TICK_SPEED,
			)
		}

		terrain_tool_mark_array_dirty(
			 {
				terrain_tool().position.x - terrain_tool().brush_size,
				terrain_tool().position.y - terrain_tool().brush_size,
			},
			 {
				terrain_tool().position.x + terrain_tool().brush_size,
				terrain_tool().position.y + terrain_tool().brush_size,
			},
		)
	}
}

terrain_tool_move_point_height :: proc(x, z: i32, movement: f32) {
	terrain := get_terrain_context()
	height := terrain.terrain_heights[x][z]
	height += movement

	height = clamp(height, TERRAIN_TOOL_LOW, TERRAIN_TOOL_HIGH)

	terrain_tool_set_terrain_height(x, z, height)
}

terrain_tool_adjust_points :: proc(x, z, w, h: int, movement: f32) {
	for i in 1 ..< int(terrain_tool().brush_size) {
		start_x := max(x - i, 0) + 1
		end_x := min(max(x + i, 0), WORLD_WIDTH)
		start_z := max(z - i, 0)
		end_z := min(max(z + i, 0), WORLD_DEPTH)

		if x - i >= 0 {
			for z in start_z ..= end_z {
				terrain_tool_move_point_height(
					i32(x - i),
					i32(z),
					movement *
					f32(terrain_tool().brush_size - i32(i)) /
					f32(terrain_tool().brush_size),
				)
			}
		}

		if x + w + i <= WORLD_WIDTH {
			for z in start_z ..= end_z {
				terrain_tool_move_point_height(
					i32(x + w + i),
					i32(z),
					movement *
					f32(terrain_tool().brush_size - i32(i)) /
					f32(terrain_tool().brush_size),
				)
			}
		}

		if z - i >= 0 {
			for x in start_x ..< end_x {
				terrain_tool_move_point_height(
					i32(x),
					i32(z - i),
					movement *
					f32(terrain_tool().brush_size - i32(i)) /
					f32(terrain_tool().brush_size),
				)
			}
		}

		if z + h + i <= WORLD_DEPTH {
			for x in start_x ..< end_x {
				terrain_tool_move_point_height(
					i32(x),
					i32(z + h + i),
					movement *
					f32(terrain_tool().brush_size - i32(i)) /
					f32(terrain_tool().brush_size),
				)
			}
		}
	}
}

terrain_tool_cleanup :: proc() {
	if drag_start, ok := terrain_tool().drag_start.?; ok {
		start_x := min(drag_start.x, terrain_tool().position.x)
		start_z := min(drag_start.y, terrain_tool().position.y)
		end_x := max(drag_start.x, terrain_tool().position.x)
		end_z := max(drag_start.y, terrain_tool().position.y)

		for x in start_x ..< end_x {
			for z in start_z ..< end_z {
				tile_triangle_set_tile_mask_texture({x, 0, z}, .Grid_Mask)
			}
		}

		terrain_tool_mark_array_dirty(
			 {
				start_x - terrain_tool().previous_brush_size,
				start_z - terrain_tool().previous_brush_size,
			},
			 {
				end_x + terrain_tool().previous_brush_size,
				end_z + terrain_tool().previous_brush_size,
			},
		)
	} else {
		start_x := max(
			terrain_tool().position.x - terrain_tool().previous_brush_size,
			0,
		)
		start_z := max(
			terrain_tool().position.y - terrain_tool().previous_brush_size,
			0,
		)
		end_x := min(
			terrain_tool().position.x + terrain_tool().previous_brush_size,
			WORLD_WIDTH,
		)
		end_z := min(
			terrain_tool().position.y + terrain_tool().previous_brush_size,
			WORLD_DEPTH,
		)
		for x in start_x ..< end_x {
			for z in start_z ..< end_z {
				tile_triangle_set_tile_mask_texture({x, 0, z}, .Grid_Mask)
			}
		}
		terrain_tool_mark_array_dirty(
			 {
				terrain_tool().position.x - terrain_tool().previous_brush_size,
				terrain_tool().position.y - terrain_tool().previous_brush_size,
			},
			 {
				terrain_tool().position.x + terrain_tool().previous_brush_size,
				terrain_tool().position.y + terrain_tool().previous_brush_size,
			},
		)
	}
	terrain_tool().previous_brush_size = terrain_tool().brush_size
}

terrain_tool_increase_brush_size :: proc() {
	terrain_tool().brush_size += 1
	terrain_tool().brush_size = min(terrain_tool().brush_size, 10)
}

terrain_tool_decrease_brush_size :: proc() {
	terrain_tool().brush_size -= 1
	terrain_tool().brush_size = max(terrain_tool().brush_size, 1)
}

terrain_tool_increase_brush_strength :: proc() {
	terrain_tool().brush_strength += TERRAIN_TOOL_BRUSH_MIN_STRENGTH
	terrain_tool().brush_strength = min(
		terrain_tool().brush_strength,
		TERRAIN_TOOL_BRUSH_MAX_STRENGTH,
	)

	t := int(terrain_tool().brush_strength * 10 - 1)
	// tex := billboard.Texture_1x1(int(billboard.Texture_1x1.Shovel_1_SW) + t)
	// billboard.billboard_1x1_set_texture(terrain_tool_billboard, tex)
}

terrain_tool_decrease_brush_strength :: proc() {
	terrain_tool().brush_strength -= TERRAIN_TOOL_BRUSH_MIN_STRENGTH
	terrain_tool().brush_strength = max(
		terrain_tool().brush_strength,
		TERRAIN_TOOL_BRUSH_MIN_STRENGTH,
	)

	t := int(terrain_tool().brush_strength * 10 - 1)
	// tex := billboard.Texture_1x1(int(billboard.Texture_1x1.Shovel_1_SW) + t)
	// billboard.billboard_1x1_set_texture(terrain_tool_billboard, tex)
}

terrain_tool_apply_state :: proc(state: map[glsl.ivec2]f32) {
	start, end: glsl.ivec2
	terrain := get_terrain_context()
	for k, v in state {
		x, z := k.x, k.y
		terrain.terrain_heights[x][z] = v

		start.x = min(start.x, k.x)
		start.y = min(start.y, k.y)
		end.x = max(end.x, k.x)
		end.y = max(end.y, k.y)
	}

	start.x = max(start.x - 1, 0)
	start.y = max(start.y - 1, 0)
	end.x = min(end.x + 1, WORLD_WIDTH)
	end.y = min(end.y + 1, WORLD_DEPTH)
	for x in start.x ..= end.x {
		for z in start.y ..= end.y {
			calculate_terrain_light(int(x), int(z))
			if x < WORLD_WIDTH && z < WORLD_DEPTH {
				i := x / CHUNK_WIDTH
				j := z / CHUNK_DEPTH
				get_tile_triangles_context().chunks[0][i][j].dirty = true
			}
		}
	}
}

terrain_tool_undo :: proc(command: Terrain_Tool_Command) {
	terrain_tool_apply_state(command.before)
}

terrain_tool_redo :: proc(command: Terrain_Tool_Command) {
	terrain_tool_apply_state(command.after)
}
