package main

import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"

wall_tool_billboard: Billboard_Key
wall_tool_start_billboard: Maybe(Billboard_Key)
wall_tool_position: glsl.ivec2
wall_tool_drag_start: glsl.ivec2
wall_tool_north_south_walls: map[glsl.ivec3]Wall
wall_tool_east_west_walls: map[glsl.ivec3]Wall
wall_tool_south_west_north_east_walls: map[glsl.ivec3]Wall
wall_tool_north_west_south_east_walls: map[glsl.ivec3]Wall

wall_tool_init :: proc() {
	wall_tool_billboard = {
		type = .Wall_Cursor,
	}
	billboard_1x1_set(
		wall_tool_billboard,
		{light = {1, 1, 1}, texture = .Wall_Cursor, depth_map = .Wall_Cursor},
	)
	cursor_intersect_with_tiles(wall_tool_on_tile_intersect)
	wall_tool_move_cursor()
}

wall_tool_deinit :: proc() {
	billboard_1x1_remove(wall_tool_billboard)
}

wall_tool_on_tile_intersect :: proc(intersect: glsl.vec3) {
	wall_tool_position.x = i32(math.ceil(intersect.x))
	wall_tool_position.y = i32(math.ceil(intersect.z))
	position := intersect
}

wall_tool_update_walls :: proc(
	south_west_north_east_fn: proc(_: glsl.ivec3),
	north_west_south_east_fn: proc(_: glsl.ivec3),
	east_west: proc(_: glsl.ivec3),
	north_south: proc(_: glsl.ivec3),
) {
	if wall_tool_is_diagonal() {
		wall_tool_diagonal_update(
			south_west_north_east_fn,
			north_west_south_east_fn,
		)
	} else {
		wall_tool_cardinal_update(east_west, north_south)
	}
}

wall_tool_is_diagonal :: proc() -> bool {
	l := max(
		abs(wall_tool_position.x - wall_tool_drag_start.x),
		abs(wall_tool_position.y - wall_tool_drag_start.y),
	)
	return(
		abs(wall_tool_position.y - wall_tool_drag_start.y) > l / 2 &&
		abs(wall_tool_position.x - wall_tool_drag_start.x) > l / 2 \
	)
}

wall_tool_diagonal_update :: proc(
	south_west_north_east_fn: proc(_: glsl.ivec3),
	north_west_south_east_fn: proc(_: glsl.ivec3),
) {
	if (wall_tool_position.x >= wall_tool_drag_start.x &&
		   wall_tool_position.y >= wall_tool_drag_start.y) ||
	   (wall_tool_position.x < wall_tool_drag_start.x &&
			   wall_tool_position.y < wall_tool_drag_start.y) {
		wall_tool_south_west_north_east_update(south_west_north_east_fn)
	} else {
		wall_tool_north_west_south_east_update(north_west_south_east_fn)
	}
}

wall_tool_south_west_north_east_update :: proc(fn: proc(_: glsl.ivec3)) {
	start_x := min(wall_tool_position.x, wall_tool_drag_start.x)
	end_x := max(wall_tool_position.x, wall_tool_drag_start.x)
	floor: i32 = 0
	z := wall_tool_drag_start.y

	dz: i32 = 0
	if wall_tool_position.x < wall_tool_drag_start.x {
		dz = start_x - end_x
	}
	for x, i in start_x ..< end_x {
		fn({x, floor, z + i32(i) + dz})
	}
}

wall_tool_north_west_south_east_update :: proc(fn: proc(_: glsl.ivec3)) {
	start_x := min(wall_tool_position.x, wall_tool_drag_start.x)
	end_x := max(wall_tool_position.x, wall_tool_drag_start.x)
	floor: i32 = 0
	z := wall_tool_drag_start.y

	dz: i32 = -1
	if wall_tool_position.x < wall_tool_drag_start.x {
		dz = end_x - start_x - 1
	}

	for x, i in start_x ..< end_x {
		fn({x, floor, z - i32(i) + dz})
	}
}

wall_tool_cardinal_update :: proc(
	east_west: proc(_: glsl.ivec3),
	north_south: proc(_: glsl.ivec3),
) {
	if abs(wall_tool_position.x - wall_tool_drag_start.x) <
	   abs(wall_tool_position.y - wall_tool_drag_start.y) {
		wall_tool_north_south_update(north_south)
	} else {
		wall_tool_east_west_update(east_west)
	}
}

wall_tool_east_west_update :: proc(fn: proc(_: glsl.ivec3)) {
	start_x := min(wall_tool_position.x, wall_tool_drag_start.x)
	end_x := max(wall_tool_position.x, wall_tool_drag_start.x)
	z := wall_tool_drag_start.y
	floor: i32 = 0
	for x in start_x ..< end_x {
		fn({x, floor, z})
	}
}

wall_tool_north_south_update :: proc(fn: proc(_: glsl.ivec3)) {
	start_z := min(wall_tool_position.y, wall_tool_drag_start.y)
	end_z := max(wall_tool_position.y, wall_tool_drag_start.y)
	x := wall_tool_drag_start.x
	floor: i32 = 0
	for z in start_z ..< end_z {
		fn({x, floor, z})
	}
}

wall_tool_remove_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := wall_tool_south_west_north_east_walls[pos]; ok {
		return
	}
	world_remove_south_west_north_east_wall(pos)
}

wall_tool_remove_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := wall_tool_north_west_south_east_walls[pos]; ok {
		return
	}
	world_remove_north_west_south_east_wall(pos)
}

wall_tool_remove_east_west_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := wall_tool_east_west_walls[pos]; ok {
		return
	}
	world_remove_east_west_wall(pos)
}

wall_tool_remove_north_south_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := wall_tool_north_south_walls[pos]; ok {
		return
	}
	world_remove_north_south_wall(pos)
}

wall_tool_update_east_west_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 || pos.z < 0 || pos.x >= WORLD_WIDTH || pos.z >= WORLD_DEPTH {
		return
	}

	wall, ok := world_get_east_west_wall(pos)
	if !ok {
		return
	}

	left_type_part := Wall_Type_Part.End
	if world_has_east_west_wall(pos + {-1, 0, 0}) {
		left_type_part = .Side
	} else {
		has_left := world_has_north_south_wall(pos + {0, 0, 0})
		has_right := world_has_north_south_wall(pos + {0, 0, -1})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := Wall_Type_Part.End
	if world_has_east_west_wall(pos + {1, 0, 0}) {
		right_type_part = .Side
	} else {
		has_left := world_has_north_south_wall(pos + {1, 0, 0})
		has_right := world_has_north_south_wall(pos + {1, 0, -1})
		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := WALL_SIDE_TYPE_MAP
	type := type_map[left_type_part][right_type_part]
	world_set_east_west_wall(pos, {type = type, textures = wall.textures})
}

wall_tool_update_north_south_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 || pos.z < 0 || pos.x >= WORLD_WIDTH || pos.z >= WORLD_DEPTH {
		return
	}

	wall, ok := world_get_north_south_wall(pos)
	if !ok {
		return
	}

	left_type_part := Wall_Type_Part.End
	if world_has_north_south_wall(pos + {0, 0, 1}) {
		left_type_part = .Side
	} else {
		has_left := world_has_east_west_wall(pos + {-1, 0, 1})
		has_right := world_has_east_west_wall(pos + {0, 0, 1})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := Wall_Type_Part.End
	if world_has_north_south_wall(pos + {0, 0, -1}) {
		right_type_part = .Side
	} else {
		has_left := world_has_east_west_wall(pos + {-1, 0, 0})
		has_right := world_has_east_west_wall(pos + {0, 0, 0})
		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := WALL_SIDE_TYPE_MAP
	type := type_map[left_type_part][right_type_part]
	world_set_north_south_wall(pos, {type = type, textures = wall.textures})
}

wall_tool_update_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 || pos.z < 0 || pos.x >= WORLD_WIDTH || pos.z >= WORLD_DEPTH {
		return
	}

	wall, ok := world_get_north_west_south_east_wall(pos)
	if !ok {
		return
	}

	left_type_part := Wall_Type_Part.End
	if world_has_north_west_south_east_wall(pos + {-1, 0, 1}) {
		left_type_part = .Side
	} else {
		has_left := world_has_south_west_north_east_wall(pos + {0, 0, 1})
		has_right := world_has_south_west_north_east_wall(pos + {-1, 0, 0})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := Wall_Type_Part.End
	if world_has_north_west_south_east_wall(pos + {1, 0, -1}) {
		right_type_part = .Side
	} else {
		has_left := world_has_south_west_north_east_wall(pos + {1, 0, 0})
		has_right := world_has_south_west_north_east_wall(pos + {0, 0, -1})
		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := WALL_SIDE_TYPE_MAP
	type := type_map[left_type_part][right_type_part]
	world_set_north_west_south_east_wall(
		pos,
		{type = type, textures = wall.textures},
	)
}

wall_tool_update_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 || pos.z < 0 || pos.x >= WORLD_WIDTH || pos.z >= WORLD_DEPTH {
		return
	}

	wall, ok := world_get_south_west_north_east_wall(pos)
	if !ok {
		return
	}

	left_type_part := Wall_Type_Part.End
	if world_has_south_west_north_east_wall(pos + {-1, 0, -1}) {
		left_type_part = .Side
	} else {
		has_left := world_has_north_west_south_east_wall(pos + {-1, 0, 0})
		has_right := world_has_north_west_south_east_wall(pos + {0, 0, -1})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := Wall_Type_Part.End
	if world_has_south_west_north_east_wall(pos + {1, 0, 1}) {
		right_type_part = .Side
	} else {
		has_left := world_has_north_west_south_east_wall(pos + {0, 0, 1})
		has_right := world_has_north_west_south_east_wall(pos + {1, 0, 0})
		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := WALL_SIDE_TYPE_MAP
	type := type_map[left_type_part][right_type_part]
	world_set_south_west_north_east_wall(
		pos,
		{type = type, textures = wall.textures},
	)
}

wall_tool_set_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := world_get_south_west_north_east_wall(pos); ok {
		wall_tool_south_west_north_east_walls[pos] = wall
		return
	}

	world_set_south_west_north_east_wall(
		pos,
		{type = .Side_Side, textures = {.Inside = .Brick, .Outside = .Brick}},
	)

	wall_tool_update_south_west_north_east_wall(pos)
	wall_tool_update_south_west_north_east_wall(pos - {1, 0, 1})
	wall_tool_update_south_west_north_east_wall(pos + {1, 0, 1})
	wall_tool_update_north_west_south_east_wall(pos + {0, 0, 1})
	wall_tool_update_north_west_south_east_wall(pos + {0, 0, -1})
	wall_tool_update_north_west_south_east_wall(pos + {-1, 0, 0})
	wall_tool_update_north_west_south_east_wall(pos + {1, 0, 0})
}

wall_tool_set_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := world_get_north_west_south_east_wall(pos); ok {
		wall_tool_north_west_south_east_walls[pos] = wall
		return
	}
	world_set_north_west_south_east_wall(
		pos,
		{type = .Side_Side, textures = {.Inside = .Brick, .Outside = .Brick}},
	)

	wall_tool_update_north_west_south_east_wall(pos)
	wall_tool_update_north_west_south_east_wall(pos + {-1, 0, 1})
	wall_tool_update_north_west_south_east_wall(pos + {1, 0, -1})
	wall_tool_update_south_west_north_east_wall(pos + {0, 0, 1})
	wall_tool_update_south_west_north_east_wall(pos + {0, 0, -1})
	wall_tool_update_south_west_north_east_wall(pos + {-1, 0, 0})
	wall_tool_update_south_west_north_east_wall(pos + {1, 0, 0})
}

wall_tool_set_east_west_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := world_get_east_west_wall(pos); ok {
		wall_tool_east_west_walls[pos] = wall
		return
	}
	world_set_east_west_wall(
		pos,
		{type = .Side_Side, textures = {.Inside = .Brick, .Outside = .Brick}},
	)

	wall_tool_update_east_west_wall(pos)
	wall_tool_update_east_west_wall(pos + {-1, 0, 0})
	wall_tool_update_east_west_wall(pos + {1, 0, 0})
	wall_tool_update_north_south_wall(pos + {0, 0, -1})
	wall_tool_update_north_south_wall(pos + {0, 0, 1})
	wall_tool_update_north_south_wall(pos + {1, 0, -1})
	wall_tool_update_north_south_wall(pos + {1, 0, 1})
}

wall_tool_set_north_south_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := world_get_north_south_wall(pos); ok {
		wall_tool_north_south_walls[pos] = wall
		return
	}
	world_set_north_south_wall(
		pos,
		{type = .Side_Side, textures = {.Inside = .Brick, .Outside = .Brick}},
	)

	wall_tool_update_north_south_wall(pos)
	wall_tool_update_north_south_wall(pos + {0, 0, -1})
	wall_tool_update_north_south_wall(pos + {0, 0, 1})
	wall_tool_update_east_west_wall(pos + {-1, 0, 0})
	wall_tool_update_east_west_wall(pos + {1, 0, 0})
	wall_tool_update_east_west_wall(pos + {-1, 0, 1})
	wall_tool_update_east_west_wall(pos + {1, 0, 1})
}

wall_tool_update :: proc() {
	if mouse_is_button_down(.Left) {
		wall_tool_update_walls(
			wall_tool_remove_south_west_north_east_wall,
			wall_tool_remove_north_west_south_east_wall,
			wall_tool_remove_east_west_wall,
			wall_tool_remove_north_south_wall,
		)
	}

	previous_tool_position := wall_tool_position
	cursor_on_tile_intersect(wall_tool_on_tile_intersect)

	if previous_tool_position != wall_tool_position {
		wall_tool_move_cursor()
	}

	if mouse_is_button_press(.Left) {
		wall_tool_drag_start = wall_tool_position
		clear(&wall_tool_south_west_north_east_walls)
		clear(&wall_tool_north_west_south_east_walls)
		clear(&wall_tool_east_west_walls)
		clear(&wall_tool_north_south_walls)
	} else if mouse_is_button_down(.Left) {
		wall_tool_update_drag_start_billboard()
		wall_tool_update_walls(
			wall_tool_set_south_west_north_east_wall,
			wall_tool_set_north_west_south_east_wall,
			wall_tool_set_east_west_wall,
			wall_tool_set_north_south_wall,
		)
	} else {
		wall_tool_remove_drag_start_billboard()
		wall_tool_drag_start = wall_tool_position
	}
}

wall_tool_update_drag_start_billboard :: proc() {
	if wall_tool_start_billboard == nil &&
	   wall_tool_drag_start != wall_tool_position {
		wall_tool_start_billboard = Billboard_Key {
			pos =  {
				f32(wall_tool_drag_start.x),
				terrain_heights[wall_tool_drag_start.x][wall_tool_drag_start.y],
				f32(wall_tool_drag_start.y),
			},
			type = .Wall_Cursor,
		}
		billboard_1x1_set(
			wall_tool_start_billboard.?,
			 {
				light = {1, 1, 1},
				texture = .Wall_Cursor,
				depth_map = .Wall_Cursor,
			},
		)
	} else if wall_tool_start_billboard != nil &&
	   wall_tool_drag_start == wall_tool_position {
		wall_tool_start_billboard = nil
	}
}

wall_tool_remove_drag_start_billboard :: proc() {
	if wall_tool_start_billboard != nil &&
	   wall_tool_drag_start != wall_tool_position {
		billboard_1x1_remove(wall_tool_start_billboard.?)
		wall_tool_start_billboard = nil
	}
}

wall_tool_move_cursor :: proc() {
	position: glsl.vec3
	position.y = terrain_heights[wall_tool_position.x][wall_tool_position.y]

	switch camera_rotation {
	case .South_West:
		position.x = f32(wall_tool_position.x)
		position.z = f32(wall_tool_position.y)
	case .South_East:
		position.x = f32(wall_tool_position.x - 1)
		position.z = f32(wall_tool_position.y)
	case .North_East:
		position.x = f32(wall_tool_position.x - 1)
		position.z = f32(wall_tool_position.y - 1)
	case .North_West:
		position.x = f32(wall_tool_position.x)
		position.z = f32(wall_tool_position.y - 1)
	}

	billboard_1x1_move(&wall_tool_billboard, position)
}