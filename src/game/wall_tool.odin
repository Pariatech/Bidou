package game

import "core:log"
import "core:math"
import "core:math/linalg/glsl"

Wall_Tool :: struct {
	cursor:                      Object_Draw,
	position:                    glsl.ivec2,
	drag_start:                  glsl.ivec2,
	north_south_walls:           map[glsl.ivec3]Wall,
	east_west_walls:             map[glsl.ivec3]Wall,
	south_west_north_east_walls: map[glsl.ivec3]Wall,
	north_west_south_east_walls: map[glsl.ivec3]Wall,
	mode:                        Wall_Tool_Mode,
}


Wall_Tool_Mode :: enum {
	Build,
	Demolish,
	Rectangle,
	Demolish_Rectangle,
}

wall_tool :: proc() -> ^Wall_Tool {
	return &game().wall_tool
}

wall_tool_init :: proc() {
	wall_tool().cursor.model = ROOF_TOOL_CURSOR_MODEL
	wall_tool().cursor.texture = ROOF_TOOL_CURSOR_TEXTURE
	wall_tool().cursor.light = {1, 1, 1}
	floor := get_floor_context()
	cursor_intersect_with_tiles(wall_tool_on_tile_intersect, floor.floor)
	wall_tool_move_cursor()
	floor.show_markers = true
}

wall_tool_deinit :: proc() {
    delete(wall_tool().north_south_walls)
    delete(wall_tool().east_west_walls)
    delete(wall_tool().south_west_north_east_walls)
    delete(wall_tool().north_west_south_east_walls)
}

wall_tool_update :: proc() {
	if keyboard_is_key_release(.Key_Left_Control) {
		wall_tool().cursor.light = {1, 1, 1}

		if keyboard_is_key_down(.Key_Left_Shift) {
			wall_tool_revert_removing_rectangle()
		} else {
			wall_tool_revert_removing_line()
		}
	} else if keyboard_is_key_press(.Key_Left_Control) {
		wall_tool().cursor.light = {1, 0, 0}

		if keyboard_is_key_down(.Key_Left_Shift) {
			wall_tool_revert_walls_rectangle()
		} else {
			wall_tool_revert_walls_line()
		}
	}

	if keyboard_is_key_release(.Key_Left_Shift) {
		wall_tool_revert_walls_rectangle()
	} else if keyboard_is_key_press(.Key_Left_Shift) {
		wall_tool_revert_walls_line()
	}

	if wall_tool().mode == .Rectangle ||
	   wall_tool().mode == .Demolish_Rectangle ||
	   keyboard_is_key_down(.Key_Left_Shift) {
		wall_tool_update_rectangle()
	} else {
		wall_tool_update_line()
	}

	draw_one_object(&wall_tool().cursor)
}

wall_tool_get_mode :: proc() -> Wall_Tool_Mode {return wall_tool().mode}

wall_tool_set_mode :: proc(m: Wall_Tool_Mode) {
	if (wall_tool().mode == .Demolish || wall_tool().mode == .Demolish_Rectangle) &&
	   (m == .Build || m == .Rectangle) {
		wall_tool().cursor.light = {1, 1, 1}
	} else if (wall_tool().mode == .Build || wall_tool().mode == .Rectangle) &&
	   (m == .Demolish || m == .Demolish_Rectangle) {
		wall_tool().cursor.light = {1, 0, 0}
	}

	if wall_tool().mode == .Build && m == .Rectangle {
		wall_tool_revert_walls_line()
	} else if wall_tool().mode == .Rectangle && m == .Build {
		wall_tool_revert_walls_rectangle()
	}

	wall_tool().mode = m
}

wall_tool_on_tile_intersect :: proc(intersect: glsl.vec3) {
	wall_tool().position.x = i32(math.ceil(intersect.x))
	wall_tool().position.y = i32(math.ceil(intersect.z))
}

wall_tool_update_walls_line :: proc(
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

wall_tool_update_walls_rectangle :: proc(
	east_west: proc(_: glsl.ivec3),
	north_south: proc(_: glsl.ivec3),
) {
	floor := get_floor_context()
	start_x := min(wall_tool().position.x, wall_tool().drag_start.x)
	end_x := max(wall_tool().position.x, wall_tool().drag_start.x)
	start_z := min(wall_tool().position.y, wall_tool().drag_start.y)
	end_z := max(wall_tool().position.y, wall_tool().drag_start.y)

	for z in start_z ..< end_z {
		north_south({start_x, i32(floor.floor), z})
	}

	if start_x != end_x {
		for z in start_z ..< end_z {
			north_south({end_x, i32(floor.floor), z})
		}
	}

	for x in start_x ..< end_x {
		east_west({x, i32(floor.floor), start_z})
	}

	if start_z != end_z {
		for x in start_x ..< end_x {
			east_west({x, i32(floor.floor), end_z})
		}
	}
}

wall_tool_is_diagonal :: proc() -> bool {
	l := max(
		abs(wall_tool().position.x - wall_tool().drag_start.x),
		abs(wall_tool().position.y - wall_tool().drag_start.y),
	)
	return(
		abs(wall_tool().position.y - wall_tool().drag_start.y) > l / 2 &&
		abs(wall_tool().position.x - wall_tool().drag_start.x) > l / 2 \
	)
}

wall_tool_diagonal_update :: proc(
	south_west_north_east_fn: proc(_: glsl.ivec3),
	north_west_south_east_fn: proc(_: glsl.ivec3),
) {
	if (wall_tool().position.x >= wall_tool().drag_start.x &&
		   wall_tool().position.y >= wall_tool().drag_start.y) ||
	   (wall_tool().position.x < wall_tool().drag_start.x &&
			   wall_tool().position.y < wall_tool().drag_start.y) {
		wall_tool_south_west_north_east_update(south_west_north_east_fn)
	} else {
		wall_tool_north_west_south_east_update(north_west_south_east_fn)
	}
}

wall_tool_south_west_north_east_update :: proc(fn: proc(_: glsl.ivec3)) {
	floor := get_floor_context()
	start_x := min(wall_tool().position.x, wall_tool().drag_start.x)
	end_x := max(wall_tool().position.x, wall_tool().drag_start.x)
	z := wall_tool().drag_start.y

	dz: i32 = 0
	if wall_tool().position.x < wall_tool().drag_start.x {
		dz = start_x - end_x
	}
	for x, i in start_x ..< end_x {
		fn({x, i32(floor.floor), z + i32(i) + dz})
	}
}

wall_tool_north_west_south_east_update :: proc(fn: proc(_: glsl.ivec3)) {
	floor := get_floor_context()
	start_x := min(wall_tool().position.x, wall_tool().drag_start.x)
	end_x := max(wall_tool().position.x, wall_tool().drag_start.x)
	z := wall_tool().drag_start.y

	dz: i32 = -1
	if wall_tool().position.x < wall_tool().drag_start.x {
		dz = end_x - start_x - 1
	}

	for x, i in start_x ..< end_x {
		fn({x, i32(floor.floor), z - i32(i) + dz})
	}
}

wall_tool_cardinal_update :: proc(
	east_west: proc(_: glsl.ivec3),
	north_south: proc(_: glsl.ivec3),
) {
	if abs(wall_tool().position.x - wall_tool().drag_start.x) <
	   abs(wall_tool().position.y - wall_tool().drag_start.y) {
		wall_tool_north_south_update(north_south)
	} else {
		wall_tool_east_west_update(east_west)
	}
}

wall_tool_east_west_update :: proc(fn: proc(_: glsl.ivec3)) {
	floor := get_floor_context()
	start_x := min(wall_tool().position.x, wall_tool().drag_start.x)
	end_x := max(wall_tool().position.x, wall_tool().drag_start.x)
	z := wall_tool().drag_start.y
	for x in start_x ..< end_x {
		fn({x, i32(floor.floor), z})
	}
}

wall_tool_north_south_update :: proc(fn: proc(_: glsl.ivec3)) {
	floor := get_floor_context()
	start_z := min(wall_tool().position.y, wall_tool().drag_start.y)
	end_z := max(wall_tool().position.y, wall_tool().drag_start.y)
	x := wall_tool().drag_start.x
	for z in start_z ..< end_z {
		fn({x, i32(floor.floor), z})
	}
}

wall_tool_update_south_west_north_east_neighbors :: proc(pos: glsl.ivec3) {
	wall_tool_update_south_west_north_east_wall(pos + {-1, 0, -1})
	wall_tool_update_south_west_north_east_wall(pos + {1, 0, 1})
	wall_tool_update_north_west_south_east_wall(pos + {0, 0, 1})
	wall_tool_update_north_west_south_east_wall(pos + {0, 0, -1})
	wall_tool_update_north_west_south_east_wall(pos + {-1, 0, 0})
	wall_tool_update_north_west_south_east_wall(pos + {1, 0, 0})
}

wall_tool_update_north_west_south_east_neighbors :: proc(pos: glsl.ivec3) {
	wall_tool_update_north_west_south_east_wall(pos + {-1, 0, 1})
	wall_tool_update_north_west_south_east_wall(pos + {1, 0, -1})
	wall_tool_update_south_west_north_east_wall(pos + {0, 0, 1})
	wall_tool_update_south_west_north_east_wall(pos + {0, 0, -1})
	wall_tool_update_south_west_north_east_wall(pos + {-1, 0, 0})
	wall_tool_update_south_west_north_east_wall(pos + {1, 0, 0})
}

wall_tool_update_east_west_neighbors :: proc(pos: glsl.ivec3) {
	wall_tool_update_east_west_wall(pos + {-1, 0, 0})
	wall_tool_update_east_west_wall(pos + {1, 0, 0})
	wall_tool_update_north_south_wall(pos + {0, 0, -1})
	wall_tool_update_north_south_wall(pos + {0, 0, 0})
	wall_tool_update_north_south_wall(pos + {1, 0, -1})
	wall_tool_update_north_south_wall(pos + {1, 0, 0})
	wall_tool_update_north_west_south_east_wall(pos + {-1, 0, 0})
	wall_tool_update_north_west_south_east_wall(pos + {1, 0, -1})
	wall_tool_update_south_west_north_east_wall(pos + {-1, 0, -1})
	wall_tool_update_south_west_north_east_wall(pos + {1, 0, 0})
}

wall_tool_update_north_south_neighbors :: proc(pos: glsl.ivec3) {
	wall_tool_update_north_south_wall(pos + {0, 0, -1})
	wall_tool_update_north_south_wall(pos + {0, 0, 1})
	wall_tool_update_east_west_wall(pos + {-1, 0, 0})
	wall_tool_update_east_west_wall(pos + {0, 0, 0})
	wall_tool_update_east_west_wall(pos + {-1, 0, 1})
	wall_tool_update_east_west_wall(pos + {0, 0, 1})
	wall_tool_update_north_west_south_east_wall(pos + {-1, 0, 1})
	wall_tool_update_north_west_south_east_wall(pos + {0, 0, -1})
	wall_tool_update_south_west_north_east_wall(pos + {0, 0, 1})
	wall_tool_update_south_west_north_east_wall(pos + {-1, 0, -1})
}

wall_tool_update_south_west_north_east_wall_and_neighbors :: proc(
	pos: glsl.ivec3,
) {
	wall_tool_update_south_west_north_east_wall(pos)
	wall_tool_update_south_west_north_east_neighbors(pos)
}

wall_tool_update_north_west_south_east_wall_and_neighbors :: proc(
	pos: glsl.ivec3,
) {
	wall_tool_update_north_west_south_east_wall(pos)
	wall_tool_update_north_west_south_east_neighbors(pos)
}

wall_tool_update_east_west_wall_and_neighbors :: proc(pos: glsl.ivec3) {
	wall_tool_update_east_west_wall(pos)
	wall_tool_update_east_west_neighbors(pos)
}

wall_tool_update_north_south_wall_and_neighbors :: proc(pos: glsl.ivec3) {
	wall_tool_update_north_south_wall(pos)
	wall_tool_update_north_south_neighbors(pos)
}

wall_tool_undo_removing_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	if w, ok := wall_tool().south_west_north_east_walls[pos]; ok {
		set_south_west_north_east_wall(pos, w)
		wall_tool_update_south_west_north_east_wall_and_neighbors(pos)
	}
}

wall_tool_undo_removing_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	if w, ok := wall_tool().north_west_south_east_walls[pos]; ok {
		set_north_west_south_east_wall(pos, w)
		wall_tool_update_north_west_south_east_wall_and_neighbors(pos)
	}
}

wall_tool_undo_removing_east_west_wall :: proc(pos: glsl.ivec3) {
	if w, ok := wall_tool().east_west_walls[pos]; ok {
		set_east_west_wall(pos, w)
		wall_tool_update_east_west_wall_and_neighbors(pos)
	}
}

wall_tool_undo_removing_north_south_wall :: proc(pos: glsl.ivec3) {
	if w, ok := wall_tool().north_south_walls[pos]; ok {
		set_north_south_wall(pos, w)
		wall_tool_update_north_south_wall_and_neighbors(pos)
	}
}

wall_tool_remove_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
    if !lots_wall_inside_active_lot(pos.xz, .SW_NE) {
        return
    }

	if wall, ok := wall_tool().south_west_north_east_walls[pos]; ok {
		return
	}
	remove_south_west_north_east_wall(pos)
	wall_tool_update_south_west_north_east_neighbors(pos)
}

wall_tool_remove_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
    if !lots_wall_inside_active_lot(pos.xz, .NW_SE) {
        return
    }

	if wall, ok := wall_tool().north_west_south_east_walls[pos]; ok {
		return
	}
	remove_north_west_south_east_wall(pos)
	wall_tool_update_north_west_south_east_neighbors(pos)
}

wall_tool_remove_east_west_wall :: proc(pos: glsl.ivec3) {
    if !lots_wall_inside_active_lot(pos.xz, .E_W) {
        return
    }

	if wall, ok := wall_tool().east_west_walls[pos]; ok {
		return
	}
	remove_east_west_wall(pos)
	wall_tool_update_east_west_neighbors(pos)
}

wall_tool_remove_north_south_wall :: proc(pos: glsl.ivec3) {
    if !lots_wall_inside_active_lot(pos.xz, .N_S) {
        return
    }

	if wall, ok := wall_tool().north_south_walls[pos]; ok {
		return
	}
	remove_north_south_wall(pos)
	wall_tool_update_north_south_neighbors(pos)
}

wall_tool_update_east_west_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 ||
	   pos.z < 0 ||
	   pos.x >= WORLD_WIDTH ||
	   pos.z >= WORLD_DEPTH {
		return
	}

	w, ok := get_east_west_wall(pos)
	if !ok {
		return
	}

	left_type_part := Wall_Type_Part.End
	if has_east_west_wall(pos + {-1, 0, 0}) {
		left_type_part = .Side
	} else {
		has_left := has_north_south_wall(pos + {0, 0, 0})
		has_right := has_north_south_wall(pos + {0, 0, -1})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := Wall_Type_Part.End
	if has_east_west_wall(pos + {1, 0, 0}) {
		right_type_part = .Side
	} else {
		has_left := has_north_south_wall(pos + {1, 0, 0})
		has_right := has_north_south_wall(pos + {1, 0, -1})

		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := WALL_SIDE_TYPE_MAP
	w.type = type_map[left_type_part][right_type_part]
	set_east_west_wall(pos, w)
}

wall_tool_update_north_south_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 ||
	   pos.z < 0 ||
	   pos.x >= WORLD_WIDTH ||
	   pos.z >= WORLD_DEPTH {
		return
	}

	w, ok := get_north_south_wall(pos)
	if !ok {
		return
	}

	left_type_part := Wall_Type_Part.End
	if has_north_south_wall(pos + {0, 0, 1}) {
		left_type_part = .Side
	} else {
		has_left := has_east_west_wall(pos + {-1, 0, 1})
		has_right := has_east_west_wall(pos + {0, 0, 1})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := Wall_Type_Part.End
	if has_north_south_wall(pos + {0, 0, -1}) {
		right_type_part = .Side
	} else {
		has_left := has_east_west_wall(pos + {-1, 0, 0})
		has_right := has_east_west_wall(pos + {0, 0, 0})

		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := WALL_SIDE_TYPE_MAP
	w.type = type_map[left_type_part][right_type_part]
	set_north_south_wall(pos, w)
}

wall_tool_update_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 ||
	   pos.z < 0 ||
	   pos.x >= WORLD_WIDTH ||
	   pos.z >= WORLD_DEPTH {
		return
	}

	w, ok := get_north_west_south_east_wall(pos)
	if !ok {
		return
	}

	left_type_part := Wall_Type_Part.End
	if has_north_west_south_east_wall(pos + {-1, 0, 1}) ||
	   has_north_south_wall(pos + {0, 0, 1}) ||
	   has_east_west_wall(pos + {-1, 0, 1}) {
		left_type_part = .Side
	} else {
		has_left := has_south_west_north_east_wall(pos + {0, 0, 1})
		has_right := has_south_west_north_east_wall(pos + {-1, 0, 0})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := Wall_Type_Part.End
	if has_north_west_south_east_wall(pos + {1, 0, -1}) ||
	   has_north_south_wall(pos + {1, 0, -1}) ||
	   has_east_west_wall(pos + {1, 0, 0}) {
		right_type_part = .Side
	} else {
		has_left := has_south_west_north_east_wall(pos + {1, 0, 0})
		has_right := has_south_west_north_east_wall(pos + {0, 0, -1})
		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := WALL_SIDE_TYPE_MAP
	w.type = type_map[left_type_part][right_type_part]
	set_north_west_south_east_wall(pos, w)
}

wall_tool_update_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 ||
	   pos.z < 0 ||
	   pos.x >= WORLD_WIDTH ||
	   pos.z >= WORLD_DEPTH {
		return
	}

	w, ok := get_south_west_north_east_wall(pos)
	if !ok {
		return
	}

	left_type_part := Wall_Type_Part.End
	if has_south_west_north_east_wall(pos + {-1, 0, -1}) ||
	   has_north_south_wall(pos + {0, 0, -1}) ||
	   has_east_west_wall(pos + {-1, 0, 0}) {
		left_type_part = .Side
	} else {
		has_left := has_north_west_south_east_wall(pos + {-1, 0, 0})
		has_right := has_north_west_south_east_wall(pos + {0, 0, -1})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := Wall_Type_Part.End
	if has_south_west_north_east_wall(pos + {1, 0, 1}) ||
	   has_north_south_wall(pos + {1, 0, 1}) ||
	   has_east_west_wall(pos + {1, 0, 1}) {
		right_type_part = .Side
	} else {
		has_left := has_north_west_south_east_wall(pos + {0, 0, 1})
		has_right := has_north_west_south_east_wall(pos + {1, 0, 0})
		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := WALL_SIDE_TYPE_MAP
	w.type = type_map[left_type_part][right_type_part]
	// log.info(w)
	// log.info(pos, w.type)
	set_south_west_north_east_wall(pos, w)
}

wall_tool_set_south_west_north_east_wall_frame :: proc(pos: glsl.ivec3) {
	wall_tool_set_south_west_north_east_wall(pos, .Frame)
}

wall_tool_set_south_west_north_east_wall_drywall :: proc(pos: glsl.ivec3) {
	wall_tool_set_south_west_north_east_wall(pos, .Drywall)
}

wall_tool_set_south_west_north_east_wall :: proc(
	pos: glsl.ivec3,
	texture: Wall_Texture,
) {
    if !lots_wall_inside_active_lot(pos.xz, .SW_NE) {
        return
    }

	if wall, ok := get_south_west_north_east_wall(pos); ok {
		wall_tool().south_west_north_east_walls[pos] = wall
		return
	}

	if !is_tile_flat(pos.xz) {
		return
	}

	set_south_west_north_east_wall(
		pos,
		make_wall(
			type = .Side,
			textures = {.Inside = texture, .Outside = texture},
		),
	)
	wall_tool_update_south_west_north_east_wall_and_neighbors(pos)
}

wall_tool_set_north_west_south_east_wall_frame :: proc(pos: glsl.ivec3) {
	wall_tool_set_north_west_south_east_wall(pos, .Frame)
}

wall_tool_set_north_west_south_east_wall_drywall :: proc(pos: glsl.ivec3) {
	wall_tool_set_north_west_south_east_wall(pos, .Drywall)
}

wall_tool_set_north_west_south_east_wall :: proc(
	pos: glsl.ivec3,
	texture: Wall_Texture,
) {
    if !lots_wall_inside_active_lot(pos.xz, .NW_SE) {
        return
    }

	if wall, ok := get_north_west_south_east_wall(pos); ok {
		wall_tool().north_west_south_east_walls[pos] = wall
		return
	}

	if !is_tile_flat(pos.xz) {
		return
	}

	set_north_west_south_east_wall(
		pos,
		make_wall(
			type = .Side,
			textures = {.Inside = texture, .Outside = texture},
		),
	)

	wall_tool_update_north_west_south_east_wall_and_neighbors(pos)
}

wall_tool_set_east_west_wall_frame :: proc(pos: glsl.ivec3) {
	wall_tool_set_east_west_wall(pos, .Frame)
}

wall_tool_set_east_west_wall_drywall :: proc(pos: glsl.ivec3) {
	wall_tool_set_east_west_wall(pos, .Drywall)
}

wall_tool_set_east_west_wall :: proc(
	pos: glsl.ivec3,
	texture: Wall_Texture,
) {
    if !lots_wall_inside_active_lot(pos.xz, .E_W) {
        return
    }

	if wall, ok := get_east_west_wall(pos); ok {
		wall_tool().east_west_walls[pos] = wall
		return
	}

	if !is_tile_flat(pos.xz) {
		return
	}

	set_east_west_wall(
		pos,
		make_wall(
			type = .Side,
			textures = {.Inside = texture, .Outside = texture},
		),
	)
	wall_tool_update_east_west_wall_and_neighbors(pos)
}

wall_tool_set_north_south_wall_frame :: proc(pos: glsl.ivec3) {
	wall_tool_set_north_south_wall(pos, .Frame)
}

wall_tool_set_north_south_wall_drywall :: proc(pos: glsl.ivec3) {
	wall_tool_set_north_south_wall(pos, .Drywall)
}

wall_tool_set_north_south_wall :: proc(
	pos: glsl.ivec3,
	texture: Wall_Texture,
) {
    if !lots_wall_inside_active_lot(pos.xz, .N_S) {
        return
    }

	if wall, ok := get_north_south_wall(pos); ok {
		wall_tool().north_south_walls[pos] = wall
		return
	}

	if !is_tile_flat(pos.xz) {
		return
	}

	set_north_south_wall(
		pos,
		make_wall(
			type = .Side,
			textures = {.Inside = texture, .Outside = texture},
		),
	)
	wall_tool_update_north_south_wall_and_neighbors(pos)
}

wall_tool_removing_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
    if !lots_wall_inside_active_lot(pos.xz, .SW_NE) {
        return
    }

	if w, ok := get_south_west_north_east_wall(pos); ok {
		wall_tool().south_west_north_east_walls[pos] = w
		remove_south_west_north_east_wall(pos)
		wall_tool_update_south_west_north_east_wall_and_neighbors(pos)
	}
}

wall_tool_removing_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
    if !lots_wall_inside_active_lot(pos.xz, .NW_SE) {
        return
    }

	if w, ok := get_north_west_south_east_wall(pos); ok {
		wall_tool().north_west_south_east_walls[pos] = w
		remove_north_west_south_east_wall(pos)
		wall_tool_update_north_west_south_east_wall_and_neighbors(pos)
	}
}

wall_tool_removing_east_west_wall :: proc(pos: glsl.ivec3) {
    if !lots_wall_inside_active_lot(pos.xz, .E_W) {
        return
    }

	if w, ok := get_east_west_wall(pos); ok {
		wall_tool().east_west_walls[pos] = w
		remove_east_west_wall(pos)
		wall_tool_update_east_west_wall_and_neighbors(pos)
	}
}

wall_tool_removing_north_south_wall :: proc(pos: glsl.ivec3) {
    if !lots_wall_inside_active_lot(pos.xz, .N_S) {
        return
    }

	if w, ok := get_north_south_wall(pos); ok {
		wall_tool().north_south_walls[pos] = w
		remove_north_south_wall(pos)
		wall_tool_update_north_south_wall_and_neighbors(pos)
	}
}

wall_tool_revert_removing_line :: proc() {
	if mouse_is_button_down(.Left) ||
	   mouse_is_button_release(.Left) {
		wall_tool_update_walls_line(
			wall_tool_undo_removing_south_west_north_east_wall,
			wall_tool_undo_removing_north_west_south_east_wall,
			wall_tool_undo_removing_east_west_wall,
			wall_tool_undo_removing_north_south_wall,
		)
	}
}

wall_tool_removing_line :: proc() {
	floor := get_floor_context()

	wall_tool_revert_removing_line()

	previous_tool_position := wall_tool().position
	on_cursor_tile_intersect(
		wall_tool_on_tile_intersect,
		floor.previous_floor,
		floor.floor,
	)

	if previous_tool_position != wall_tool().position ||
	   floor.previous_floor != floor.floor {
		wall_tool_move_cursor()
	}

	if mouse_is_button_press(.Left) {
		wall_tool().drag_start = wall_tool().position
		clear(&wall_tool().south_west_north_east_walls)
		clear(&wall_tool().north_west_south_east_walls)
		clear(&wall_tool().east_west_walls)
		clear(&wall_tool().north_south_walls)
	} else if mouse_is_button_down(.Left) {
		wall_tool_update_walls_line(
			wall_tool_removing_south_west_north_east_wall,
			wall_tool_removing_north_west_south_east_wall,
			wall_tool_removing_east_west_wall,
			wall_tool_removing_north_south_wall,
		)
	} else if mouse_is_button_release(.Left) {
		wall_tool_update_walls_line(
			wall_tool_removing_south_west_north_east_wall,
			wall_tool_removing_north_west_south_east_wall,
			wall_tool_removing_east_west_wall,
			wall_tool_removing_north_south_wall,
		)
	} else {
		wall_tool().drag_start = wall_tool().position
	}

}

wall_tool_adding_line :: proc() {
	floor := get_floor_context()

	wall_tool_revert_walls_line()

	previous_tool_position := wall_tool().position
	on_cursor_tile_intersect(
		wall_tool_on_tile_intersect,
		floor.previous_floor,
		floor.floor,
	)

	if previous_tool_position != wall_tool().position {
		wall_tool_move_cursor()
	}

	if mouse_is_button_press(.Left) {
		wall_tool().drag_start = wall_tool().position
		clear(&wall_tool().south_west_north_east_walls)
		clear(&wall_tool().north_west_south_east_walls)
		clear(&wall_tool().east_west_walls)
		clear(&wall_tool().north_south_walls)
	} else if mouse_is_button_down(.Left) {
		wall_tool_update_walls_line(
			wall_tool_set_south_west_north_east_wall_frame,
			wall_tool_set_north_west_south_east_wall_frame,
			wall_tool_set_east_west_wall_frame,
			wall_tool_set_north_south_wall_frame,
		)
	} else if mouse_is_button_release(.Left) {
		wall_tool_update_walls_line(
			wall_tool_set_south_west_north_east_wall_drywall,
			wall_tool_set_north_west_south_east_wall_drywall,
			wall_tool_set_east_west_wall_drywall,
			wall_tool_set_north_south_wall_drywall,
		)
		update_cutaways(true)
	} else {
		wall_tool().drag_start = wall_tool().position
	}
}

wall_tool_update_line :: proc() {
	if wall_tool().mode == .Demolish || keyboard_is_key_down(.Key_Left_Control) {
		wall_tool_removing_line()
	} else {
		wall_tool_adding_line()
	}
}

wall_tool_adding_rectangle :: proc() {
	floor := get_floor_context()
	wall_tool_revert_walls_rectangle()

	previous_tool_position := wall_tool().position
	on_cursor_tile_intersect(
		wall_tool_on_tile_intersect,
		floor.previous_floor,
		floor.floor,
	)

	if previous_tool_position != wall_tool().position {
		wall_tool_move_cursor()
	}

	if mouse_is_button_press(.Left) {
		wall_tool().drag_start = wall_tool().position
		clear(&wall_tool().south_west_north_east_walls)
		clear(&wall_tool().north_west_south_east_walls)
		clear(&wall_tool().east_west_walls)
		clear(&wall_tool().north_south_walls)
	} else if mouse_is_button_down(.Left) {
		wall_tool_update_walls_rectangle(
			wall_tool_set_east_west_wall_frame,
			wall_tool_set_north_south_wall_frame,
		)
	} else if mouse_is_button_release(.Left) {
		wall_tool_update_walls_rectangle(
			wall_tool_set_east_west_wall_drywall,
			wall_tool_set_north_south_wall_drywall,
		)
	} else {
		wall_tool().drag_start = wall_tool().position
	}
}

wall_tool_revert_removing_rectangle :: proc() {
	if mouse_is_button_down(.Left) ||
	   mouse_is_button_release(.Left) {
		wall_tool_update_walls_rectangle(
			wall_tool_undo_removing_east_west_wall,
			wall_tool_undo_removing_north_south_wall,
		)
	}
}

wall_tool_removing_rectangle :: proc() {
	floor := get_floor_context()

	wall_tool_revert_removing_rectangle()

	previous_tool_position := wall_tool().position
	on_cursor_tile_intersect(
		wall_tool_on_tile_intersect,
		floor.previous_floor,
		floor.floor,
	)

	if previous_tool_position != wall_tool().position {
		wall_tool_move_cursor()
	}

	if mouse_is_button_press(.Left) {
		wall_tool().drag_start = wall_tool().position
		clear(&wall_tool().south_west_north_east_walls)
		clear(&wall_tool().north_west_south_east_walls)
		clear(&wall_tool().east_west_walls)
		clear(&wall_tool().north_south_walls)
	} else if mouse_is_button_down(.Left) {
		wall_tool_update_walls_rectangle(
			wall_tool_removing_east_west_wall,
			wall_tool_removing_north_south_wall,
		)
	} else if mouse_is_button_release(.Left) {
		wall_tool_update_walls_rectangle(
			wall_tool_removing_east_west_wall,
			wall_tool_removing_north_south_wall,
		)
	} else {
		wall_tool().drag_start = wall_tool().position
	}
}

wall_tool_update_rectangle :: proc() {
	if wall_tool().mode == .Demolish_Rectangle ||
	   keyboard_is_key_down(.Key_Left_Control) ||
	   (wall_tool().mode == .Demolish && keyboard_is_key_down(.Key_Left_Shift)) {
		wall_tool_removing_rectangle()
	} else {
		wall_tool_adding_rectangle()
	}
}

wall_tool_revert_walls_rectangle :: proc() {
	if mouse_is_button_down(.Left) ||
	   mouse_is_button_release(.Left) {
		wall_tool_update_walls_rectangle(
			wall_tool_remove_east_west_wall,
			wall_tool_remove_north_south_wall,
		)
	}
}

wall_tool_revert_walls_line :: proc() {
	if mouse_is_button_down(.Left) || mouse_is_button_release(.Left) {
		wall_tool_update_walls_line(
			wall_tool_remove_south_west_north_east_wall,
			wall_tool_remove_north_west_south_east_wall,
			wall_tool_remove_east_west_wall,
			wall_tool_remove_north_south_wall,
		)
	}
}

wall_tool_move_cursor :: proc() {
	terrain := get_terrain_context()
	floor := get_floor_context()

	position: glsl.vec3
	position.y =
		terrain.terrain_heights[wall_tool().position.x][wall_tool().position.y]

	position.y += f32(floor.floor) * WALL_HEIGHT

	position.x = f32(wall_tool().position.x) - 0.5
	position.z = f32(wall_tool().position.y) - 0.5

	wall_tool().cursor.transform = glsl.mat4Translate(position)
}
