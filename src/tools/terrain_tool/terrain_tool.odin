package terrain_tool

import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:math/rand"
import "vendor:glfw"

import "../../game"
import "../../keyboard"

terrain_tool_cursor_pos: glsl.vec3
terrain_tool_cursor: game.Object_Draw
terrain_tool_intersect: glsl.vec3
terrain_tool_position: glsl.ivec2
terrain_tool_tick_timer: f64
terrain_tool_drag_start: Maybe(glsl.ivec2)
terrain_tool_drag_end: Maybe(glsl.ivec2)
terrain_tool_drag_clip: bool
terrain_tool_previous_brush_size: i32 = 1
terrain_tool_brush_size: i32 = 1
terrain_tool_brush_strength: f32 = 0.1
mode: Mode = .Raise
add_command: proc(_: Command)
current_command: Command

Command :: struct {
	before: map[glsl.ivec2]f32,
	after:  map[glsl.ivec2]f32,
}

Mode :: enum {
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

init :: proc() {
	game.cursor_intersect_with_tiles(on_intersect, 0)
	cursor := game.get_cursor_context()
	terrain_tool_cursor_pos = cursor.ray.origin

	position := terrain_tool_intersect
	position.x = math.ceil(position.x) - 0.5
	position.z = math.ceil(position.z) - 0.5
	position.y =
		game.get_terrain_context().terrain_heights[terrain_tool_position.x][terrain_tool_position.y]

	terrain_tool_cursor.model = game.ROOF_TOOL_CURSOR_MODEL
	terrain_tool_cursor.texture = game.ROOF_TOOL_CURSOR_TEXTURE
	terrain_tool_cursor.light = {1, 1, 1}

	t := int(terrain_tool_brush_strength * 10 - 1)
	// tex := billboard.Texture_1x1(int(billboard.Texture_1x1.Shovel_1_SW) + t)
	// billboard.billboard_1x1_set(
	// 	terrain_tool_billboard,
	// 	{light = {1, 1, 1}, texture = tex, depth_map = tex},
	// )

	terrain_tool_drag_start = nil
	terrain_tool_drag_end = nil

	game.get_floor_context().show_markers = false
}

deinit :: proc() {
	cleanup()
}

update :: proc(delta_time: f64) {
	cleanup()

	if keyboard.is_key_press(.Key_Equal) {
		if keyboard.is_key_down(.Key_Left_Shift) {
			increase_brush_strength()
		} else {
			increase_brush_size()
		}
		mark_array_dirty(
			 {
				terrain_tool_position.x - terrain_tool_brush_size,
				terrain_tool_position.y - terrain_tool_brush_size,
			},
			 {
				terrain_tool_position.x + terrain_tool_brush_size,
				terrain_tool_position.y + terrain_tool_brush_size,
			},
		)
	} else if keyboard.is_key_press(.Key_Minus) {
		if keyboard.is_key_down(.Key_Left_Shift) {
			decrease_brush_strength()
		} else {
			decrease_brush_size()
		}
		mark_array_dirty(
			 {
				terrain_tool_position.x - terrain_tool_brush_size - 1,
				terrain_tool_position.y - terrain_tool_brush_size - 1,
			},
			 {
				terrain_tool_position.x + terrain_tool_brush_size + 1,
				terrain_tool_position.y + terrain_tool_brush_size + 1,
			},
		)
	}

	game.on_cursor_tile_intersect(on_intersect, 0, 0)

	position := terrain_tool_intersect
	position.x = math.ceil(position.x) - 0.5
	position.z = math.ceil(position.z) - 0.5
	previous_tool_position := terrain_tool_position
	terrain_tool_position.x = i32(position.x + 0.5)
	terrain_tool_position.y = i32(position.z + 0.5)

	if terrain_tool_position != previous_tool_position {
		mark_array_dirty(
			 {
				terrain_tool_position.x - terrain_tool_brush_size,
				terrain_tool_position.y - terrain_tool_brush_size,
			},
			 {
				terrain_tool_position.x + terrain_tool_brush_size,
				terrain_tool_position.y + terrain_tool_brush_size,
			},
		)
		mark_array_dirty(
			 {
				previous_tool_position.x - terrain_tool_brush_size,
				previous_tool_position.y - terrain_tool_brush_size,
			},
			 {
				previous_tool_position.x + terrain_tool_brush_size,
				previous_tool_position.y + terrain_tool_brush_size,
			},
		)
	}

	position.y =
		game.get_terrain_context().terrain_heights[terrain_tool_position.x][terrain_tool_position.y]
	terrain_tool_cursor.transform = glsl.mat4Translate(position)
	shift_down := keyboard.is_key_down(.Key_Left_Shift)

	if game.mouse_is_button_release(.Left) {
		add_command(current_command)
		current_command = {}
	}

	if shift_down ||
	   mode == .Level ||
	   mode == .Trim ||
	   mode == .Slope ||
	   terrain_tool_drag_start != nil {
		move_points(position)
	} else if keyboard.is_key_down(.Key_Left_Control) || mode == .Smooth {
		smooth_brush(delta_time)
	} else {
		move_point(delta_time)
	}

	if drag_start, ok := terrain_tool_drag_start.?; ok {
		start_x := min(drag_start.x, terrain_tool_position.x)
		start_z := min(drag_start.y, terrain_tool_position.y)
		end_x := max(drag_start.x, terrain_tool_position.x)
		end_z := max(drag_start.y, terrain_tool_position.y)

		for x in start_x ..< end_x {
			for z in start_z ..< end_z {
				game.tile_triangle_set_tile_mask_texture({x, 0, z}, .Leveling_Brush)
			}
		}
	} else {
		start_x := max(terrain_tool_position.x - terrain_tool_brush_size, 0)
		end_x := min(
			terrain_tool_position.x + terrain_tool_brush_size,
			game.WORLD_WIDTH,
		)
		start_z := max(terrain_tool_position.y - terrain_tool_brush_size, 0)
		end_z := min(
			terrain_tool_position.y + terrain_tool_brush_size,
			game.WORLD_DEPTH,
		)
		for x in start_x ..< end_x {
			for z in start_z ..< end_z {
				game.tile_triangle_set_tile_mask_texture({x, 0, z}, .Dotted_Grid)
			}
		}
	}

	game.draw_one_object(&terrain_tool_cursor)
}


on_intersect :: proc(intersect: glsl.vec3) {
	terrain_tool_intersect = intersect
}

mark_array_dirty :: proc(start: glsl.ivec2, end: glsl.ivec2) {
	start := start
	end := end
	start.x /= game.CHUNK_WIDTH
	end.x /= game.CHUNK_WIDTH
	start.y /= game.CHUNK_DEPTH
	end.y /= game.CHUNK_DEPTH

	start.x = max(start.x, 0)
	start.y = max(start.y, 0)
	end.x = min(end.x, game.WORLD_CHUNK_WIDTH - 1)
	end.y = min(end.y, game.WORLD_CHUNK_DEPTH - 1)

	for i in start.x ..= end.x {
		for j in start.y ..= end.y {
			for floor in 0 ..< game.CHUNK_HEIGHT {
				game.get_tile_triangles_context().chunks[floor][i][j].dirty = true
			}
		}
	}
}

slope_move_point :: proc(x, z: i32) {
	start := terrain_tool_drag_start.?
	end := terrain_tool_position
	terrain := game.get_terrain_context()
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

	set_terrain_height(x, z, height)
}

move_points :: proc(position: glsl.vec3) {
	if drag_start, ok := terrain_tool_drag_start.?; ok {
		start_x := min(drag_start.x, terrain_tool_position.x)
		start_z := min(drag_start.y, terrain_tool_position.y)
		end_x := max(drag_start.x, terrain_tool_position.x)
		end_z := max(drag_start.y, terrain_tool_position.y)

		if game.mouse_is_button_up(.Left) {
			if start_x != end_x || start_z != end_z {
				terrain := game.get_terrain_context()
				height := terrain.terrain_heights[drag_start.x][drag_start.y]

				for x in start_x ..= end_x {
					for z in start_z ..= end_z {
						if mode == .Trim {
							point_height := terrain.terrain_heights[x][z]
							if point_height > height {
								set_terrain_height(x, z, height)
							}
						} else if mode == .Slope {
							slope_move_point(x, z)
						} else {
							set_terrain_height(x, z, height)
						}
					}
				}

				for x in start_x ..= end_x {
					for z in start_z ..= end_z {
						game.calculate_terrain_light(int(x), int(z))
					}
				}
			}

			terrain_tool_drag_start = nil

			mark_array_dirty(
				 {
					start_x - terrain_tool_brush_size,
					start_z - terrain_tool_brush_size,
				},
				 {
					end_x + terrain_tool_brush_size,
					end_z + terrain_tool_brush_size,
				},
			)
		} else if terrain_tool_drag_end != terrain_tool_position {
			terrain_tool_drag_end = terrain_tool_position
		}

		mark_array_dirty({start_x, start_z}, {end_x, end_z})
	} else if game.mouse_is_button_down(.Left) {
		terrain_tool_drag_start = terrain_tool_position
	}
}

smooth_brush :: proc(delta_time: f64) {
	if game.mouse_is_button_down(.Left) {
		terrain_tool_tick_timer += delta_time
	} else if game.mouse_is_button_release(.Left) && terrain_tool_tick_timer > 0 {
		terrain_tool_tick_timer = 0
	}

	if terrain_tool_tick_timer == delta_time ||
	   terrain_tool_tick_timer >= TERRAIN_TOOL_TICK_SPEED {

		start_x := max(
			terrain_tool_position.x - terrain_tool_brush_size + 1,
			0,
		)
		start_z := max(
			terrain_tool_position.y - terrain_tool_brush_size + 1,
			0,
		)
		end_x := min(
			terrain_tool_position.x + terrain_tool_brush_size - 1,
			game.WORLD_WIDTH,
		)
		end_z := min(
			terrain_tool_position.y + terrain_tool_brush_size - 1,
			game.WORLD_DEPTH,
		)

		for x in start_x ..= end_x {
			for z in start_z ..= end_z {
				start_x := max(x - 1, 0)
				start_z := max(z - 1, 0)
				end_x := min(x + 1, game.WORLD_WIDTH)
				end_z := min(z + 1, game.WORLD_DEPTH)
				points := f32((end_x - start_x + 1) * (end_z - start_z + 1))
				average: f32 = 0

				terrain := game.get_terrain_context()
				for x in start_x ..= end_x {
					for z in start_z ..= end_z {
						average += terrain.terrain_heights[x][z] / points
					}
				}

				movement := average - terrain.terrain_heights[x][z]
				set_terrain_height(
					x,
					z,
					terrain.terrain_heights[x][z] +
					movement * terrain_tool_brush_strength,
				)
			}
		}

		calculate_lights()

		if terrain_tool_tick_timer >= TERRAIN_TOOL_TICK_SPEED {
			terrain_tool_tick_timer = math.max(
				0,
				terrain_tool_tick_timer - TERRAIN_TOOL_TICK_SPEED,
			)
		}

		mark_array_dirty({start_x, start_z}, {end_x, end_z})
	}
}

intersect_with_wall :: proc(x, z: i32) -> bool {
	if x > 0 && z < game.WORLD_DEPTH {
		if _, ok := game.get_east_west_wall({x - 1, 0, z}); ok {
			return true
		}
		if x < game.WORLD_WIDTH {
			if _, ok := game.get_east_west_wall({x, 0, z}); ok {
				return true
			}
		}
	}

	if x < game.WORLD_WIDTH && z > 0 {
		if _, ok := game.get_north_south_wall({x, 0, z - 1}); ok {
			return true
		}
		if z < game.WORLD_DEPTH {
			if _, ok := game.get_north_south_wall({x, 0, z}); ok {
				return true
			}
		}
	}

	if x > 0 && z > 0 {
		_, ok := game.get_south_west_north_east_wall({x - 1, 0, z - 1})
		if ok {return true}
	}

	if x < game.WORLD_WIDTH && z < game.WORLD_DEPTH {
		_, ok := game.get_south_west_north_east_wall({x, 0, z})
		if ok {return true}
	}

	if x > 0 && z < game.WORLD_DEPTH {
		_, ok := game.get_south_west_north_east_wall({x - 1, 0, z})
		if ok {return true}
	}

	if x < game.WORLD_WIDTH && z > 0 {
		_, ok := game.get_south_west_north_east_wall({x, 0, z - 1})
		if ok {return true}
	}

	if x > 0 && z > 0 {
		_, ok := game.get_north_west_south_east_wall({x - 1, 0, z - 1})
		if ok {return true}
	}

	if x < game.WORLD_WIDTH && z < game.WORLD_DEPTH {
		_, ok := game.get_north_west_south_east_wall({x, 0, z})
		if ok {return true}
	}

	if x < game.WORLD_WIDTH && z > 0 {
		_, ok := game.get_north_west_south_east_wall({x, 0, z - 1})
		if ok {return true}
	}

	if x > 0 && z < game.WORLD_DEPTH {
		_, ok := game.get_north_west_south_east_wall({x - 1, 0, z})
		if ok {return true}
	}

	return false
}

intersect_with_floor :: proc(x, z: i32) -> bool {
	for y in 0 ..< game.WORLD_HEIGHT {
		start_x := math.max(x - 1, 0)
		start_z := math.max(z - 1, 0)
		end_x := math.min(x, game.WORLD_WIDTH - 1)
		end_z := math.min(z, game.WORLD_DEPTH - 1)
		for x in start_x ..= end_x {
			for z in start_z ..= end_z {
				triangles := game.tile_triangle_get_tile({x, i32(y), z})
				for side in game.Tile_Triangle_Side {
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

set_terrain_height :: proc(x, z: i32, height: f32) {
	if intersect_with_wall(x, z) {return}
	if intersect_with_floor(x, z) {return}

	terrain := game.get_terrain_context()
	if !({x, z} in current_command.before) {
		current_command.before[{x, z}] = terrain.terrain_heights[x][z]
	}
	current_command.after[{x, z}] = height

	terrain.terrain_heights[x][z] = height
}

calculate_lights :: proc() {
	start_x := max(terrain_tool_position.x - terrain_tool_brush_size, 0)
	end_x := min(
		terrain_tool_position.x + terrain_tool_brush_size,
		game.WORLD_WIDTH,
	)
	start_z := max(terrain_tool_position.y - terrain_tool_brush_size, 0)
	end_z := min(
		terrain_tool_position.y + terrain_tool_brush_size,
		game.WORLD_DEPTH,
	)
	terrain := game.get_terrain_context()
	for x in start_x ..= end_x {
		for z in start_z ..= end_z {
			game.calculate_terrain_light(int(x), int(z))
		}
	}
}

move_point :: proc(delta_time: f64) {
	movement: f32 = 0
	if game.mouse_is_button_down(.Left) && mode == .Raise {
		movement = terrain_tool_brush_strength
		terrain_tool_tick_timer += delta_time
	} else if (game.mouse_is_button_down(.Right) && mode == .Raise) ||
	   (game.mouse_is_button_down(.Left) && mode == .Lower) {
		movement = -terrain_tool_brush_strength
		terrain_tool_tick_timer += delta_time
	} else if game.mouse_is_button_release(.Left) && terrain_tool_tick_timer > 0 {
		terrain_tool_tick_timer = 0
	}

	if terrain_tool_tick_timer == delta_time ||
	   terrain_tool_tick_timer >= TERRAIN_TOOL_TICK_SPEED {
		move_point_height(
			terrain_tool_position.x,
			terrain_tool_position.y,
			movement,
		)
		adjust_points(
			int(terrain_tool_position.x),
			int(terrain_tool_position.y),
			0,
			0,
			movement,
		)
		calculate_lights()

		if terrain_tool_tick_timer >= TERRAIN_TOOL_TICK_SPEED {
			terrain_tool_tick_timer = math.max(
				0,
				terrain_tool_tick_timer - TERRAIN_TOOL_TICK_SPEED,
			)
		}

		mark_array_dirty(
			 {
				terrain_tool_position.x - terrain_tool_brush_size,
				terrain_tool_position.y - terrain_tool_brush_size,
			},
			 {
				terrain_tool_position.x + terrain_tool_brush_size,
				terrain_tool_position.y + terrain_tool_brush_size,
			},
		)
	}
}

move_point_height :: proc(x, z: i32, movement: f32) {
	terrain := game.get_terrain_context()
	height := terrain.terrain_heights[x][z]
	height += movement

	height = clamp(height, TERRAIN_TOOL_LOW, TERRAIN_TOOL_HIGH)

	set_terrain_height(x, z, height)
}

adjust_points :: proc(x, z, w, h: int, movement: f32) {
	for i in 1 ..< int(terrain_tool_brush_size) {
		start_x := max(x - i, 0) + 1
		end_x := min(max(x + i, 0), game.WORLD_WIDTH)
		start_z := max(z - i, 0)
		end_z := min(max(z + i, 0), game.WORLD_DEPTH)

		if x - i >= 0 {
			for z in start_z ..= end_z {
				move_point_height(
					i32(x - i),
					i32(z),
					movement *
					f32(terrain_tool_brush_size - i32(i)) /
					f32(terrain_tool_brush_size),
				)
			}
		}

		if x + w + i <= game.WORLD_WIDTH {
			for z in start_z ..= end_z {
				move_point_height(
					i32(x + w + i),
					i32(z),
					movement *
					f32(terrain_tool_brush_size - i32(i)) /
					f32(terrain_tool_brush_size),
				)
			}
		}

		if z - i >= 0 {
			for x in start_x ..< end_x {
				move_point_height(
					i32(x),
					i32(z - i),
					movement *
					f32(terrain_tool_brush_size - i32(i)) /
					f32(terrain_tool_brush_size),
				)
			}
		}

		if z + h + i <= game.WORLD_DEPTH {
			for x in start_x ..< end_x {
				move_point_height(
					i32(x),
					i32(z + h + i),
					movement *
					f32(terrain_tool_brush_size - i32(i)) /
					f32(terrain_tool_brush_size),
				)
			}
		}
	}
}

cleanup :: proc() {
	if drag_start, ok := terrain_tool_drag_start.?; ok {
		start_x := min(drag_start.x, terrain_tool_position.x)
		start_z := min(drag_start.y, terrain_tool_position.y)
		end_x := max(drag_start.x, terrain_tool_position.x)
		end_z := max(drag_start.y, terrain_tool_position.y)

		for x in start_x ..< end_x {
			for z in start_z ..< end_z {
				game.tile_triangle_set_tile_mask_texture({x, 0, z}, .Grid_Mask)
			}
		}

		mark_array_dirty(
			 {
				start_x - terrain_tool_previous_brush_size,
				start_z - terrain_tool_previous_brush_size,
			},
			 {
				end_x + terrain_tool_previous_brush_size,
				end_z + terrain_tool_previous_brush_size,
			},
		)
	} else {
		start_x := max(
			terrain_tool_position.x - terrain_tool_previous_brush_size,
			0,
		)
		start_z := max(
			terrain_tool_position.y - terrain_tool_previous_brush_size,
			0,
		)
		end_x := min(
			terrain_tool_position.x + terrain_tool_previous_brush_size,
			game.WORLD_WIDTH,
		)
		end_z := min(
			terrain_tool_position.y + terrain_tool_previous_brush_size,
			game.WORLD_DEPTH,
		)
		for x in start_x ..< end_x {
			for z in start_z ..< end_z {
				game.tile_triangle_set_tile_mask_texture({x, 0, z}, .Grid_Mask)
			}
		}
		mark_array_dirty(
			 {
				terrain_tool_position.x - terrain_tool_previous_brush_size,
				terrain_tool_position.y - terrain_tool_previous_brush_size,
			},
			 {
				terrain_tool_position.x + terrain_tool_previous_brush_size,
				terrain_tool_position.y + terrain_tool_previous_brush_size,
			},
		)
	}
	terrain_tool_previous_brush_size = terrain_tool_brush_size
}

increase_brush_size :: proc() {
	terrain_tool_brush_size += 1
	terrain_tool_brush_size = min(terrain_tool_brush_size, 10)
}

decrease_brush_size :: proc() {
	terrain_tool_brush_size -= 1
	terrain_tool_brush_size = max(terrain_tool_brush_size, 1)
}

increase_brush_strength :: proc() {
	terrain_tool_brush_strength += TERRAIN_TOOL_BRUSH_MIN_STRENGTH
	terrain_tool_brush_strength = min(
		terrain_tool_brush_strength,
		TERRAIN_TOOL_BRUSH_MAX_STRENGTH,
	)

	t := int(terrain_tool_brush_strength * 10 - 1)
	// tex := billboard.Texture_1x1(int(billboard.Texture_1x1.Shovel_1_SW) + t)
	// billboard.billboard_1x1_set_texture(terrain_tool_billboard, tex)
}

decrease_brush_strength :: proc() {
	terrain_tool_brush_strength -= TERRAIN_TOOL_BRUSH_MIN_STRENGTH
	terrain_tool_brush_strength = max(
		terrain_tool_brush_strength,
		TERRAIN_TOOL_BRUSH_MIN_STRENGTH,
	)

	t := int(terrain_tool_brush_strength * 10 - 1)
	// tex := billboard.Texture_1x1(int(billboard.Texture_1x1.Shovel_1_SW) + t)
	// billboard.billboard_1x1_set_texture(terrain_tool_billboard, tex)
}

apply_state :: proc(state: map[glsl.ivec2]f32) {
	start, end: glsl.ivec2
	terrain := game.get_terrain_context()
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
	end.x = min(end.x + 1, game.WORLD_WIDTH)
	end.y = min(end.y + 1, game.WORLD_DEPTH)
	for x in start.x ..= end.x {
		for z in start.y ..= end.y {
			game.calculate_terrain_light(int(x), int(z))
			if x < game.WORLD_WIDTH && z < game.WORLD_DEPTH {
				i := x / game.CHUNK_WIDTH
				j := z / game.CHUNK_DEPTH
				game.get_tile_triangles_context().chunks[0][i][j].dirty = true
			}
		}
	}
}

undo :: proc(command: Command) {
	apply_state(command.before)
}

redo :: proc(command: Command) {
	apply_state(command.after)
}
