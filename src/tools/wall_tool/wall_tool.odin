package wall_tool

import "core:log"
import "core:math"
import "core:math/linalg/glsl"

import "../../billboard"
import "../../camera"
import "../../game"
import "../../keyboard"
import "../../mouse"

wall_tool_billboard: billboard.Key
wall_tool_position: glsl.ivec2
wall_tool_drag_start: glsl.ivec2
wall_tool_north_south_walls: map[glsl.ivec3]game.Wall
wall_tool_east_west_walls: map[glsl.ivec3]game.Wall
wall_tool_south_west_north_east_walls: map[glsl.ivec3]game.Wall
wall_tool_north_west_south_east_walls: map[glsl.ivec3]game.Wall

@(private)
mode: Mode

Mode :: enum {
	Build,
	Demolish,
	Rectangle,
	Demolish_Rectangle,
}

init :: proc() {
	wall_tool_billboard = {
		type = .Cursor,
	}
	billboard.billboard_1x1_set(
		wall_tool_billboard,
		{light = {1, 1, 1}, texture = .Wall_Cursor, depth_map = .Wall_Cursor},
	)
    floor := game.get_floor_context()
	game.cursor_intersect_with_tiles(on_tile_intersect, floor.floor)
	move_cursor()
	floor.show_markers = true
}

deinit :: proc() {
	billboard.billboard_1x1_remove(wall_tool_billboard)
}

update :: proc() {
	if keyboard.is_key_release(.Key_Left_Control) {
		billboard.billboard_1x1_set(
			wall_tool_billboard,
			 {
				light = {1, 1, 1},
				texture = .Wall_Cursor,
				depth_map = .Wall_Cursor,
			},
		)

		if keyboard.is_key_down(.Key_Left_Shift) {
			revert_removing_rectangle()
		} else {
			revert_removing_line()
		}
	} else if keyboard.is_key_press(.Key_Left_Control) {
		billboard.billboard_1x1_set(
			wall_tool_billboard,
			 {
				light = {1, 0, 0},
				texture = .Wall_Cursor,
				depth_map = .Wall_Cursor,
			},
		)

		if keyboard.is_key_down(.Key_Left_Shift) {
			revert_walls_rectangle()
		} else {
			revert_walls_line()
		}
	}

	if keyboard.is_key_release(.Key_Left_Shift) {
		revert_walls_rectangle()
	} else if keyboard.is_key_press(.Key_Left_Shift) {
		revert_walls_line()
	}

	if mode == .Rectangle ||
	   mode == .Demolish_Rectangle ||
	   keyboard.is_key_down(.Key_Left_Shift) {
		update_rectangle()
	} else {
		update_line()
	}
}

get_mode :: proc() -> Mode {return mode}

set_mode :: proc(m: Mode) {
	if (mode == .Demolish || mode == .Demolish_Rectangle) &&
	   (m == .Build || m == .Rectangle) {
		billboard.billboard_1x1_set(
			wall_tool_billboard,
			 {
				light = {1, 1, 1},
				texture = .Wall_Cursor,
				depth_map = .Wall_Cursor,
			},
		)
	} else if (mode == .Build || mode == .Rectangle) &&
	   (m == .Demolish || m == .Demolish_Rectangle) {
		billboard.billboard_1x1_set(
			wall_tool_billboard,
			 {
				light = {1, 0, 0},
				texture = .Wall_Cursor,
				depth_map = .Wall_Cursor,
			},
		)
	}

	if mode == .Build && m == .Rectangle {
		revert_walls_line()
	} else if mode == .Rectangle && m == .Build {
		revert_walls_rectangle()
	}

	mode = m
}

on_tile_intersect :: proc(intersect: glsl.vec3) {
	wall_tool_position.x = i32(math.ceil(intersect.x))
	wall_tool_position.y = i32(math.ceil(intersect.z))
}

update_walls_line :: proc(
	south_west_north_east_fn: proc(_: glsl.ivec3),
	north_west_south_east_fn: proc(_: glsl.ivec3),
	east_west: proc(_: glsl.ivec3),
	north_south: proc(_: glsl.ivec3),
) {
	if is_diagonal() {
		diagonal_update(south_west_north_east_fn, north_west_south_east_fn)
	} else {
		cardinal_update(east_west, north_south)
	}
}

update_walls_rectangle :: proc(
	east_west: proc(_: glsl.ivec3),
	north_south: proc(_: glsl.ivec3),
) {
    floor := game.get_floor_context()
	start_x := min(wall_tool_position.x, wall_tool_drag_start.x)
	end_x := max(wall_tool_position.x, wall_tool_drag_start.x)
	start_z := min(wall_tool_position.y, wall_tool_drag_start.y)
	end_z := max(wall_tool_position.y, wall_tool_drag_start.y)

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

is_diagonal :: proc() -> bool {
	l := max(
		abs(wall_tool_position.x - wall_tool_drag_start.x),
		abs(wall_tool_position.y - wall_tool_drag_start.y),
	)
	return(
		abs(wall_tool_position.y - wall_tool_drag_start.y) > l / 2 &&
		abs(wall_tool_position.x - wall_tool_drag_start.x) > l / 2 \
	)
}

diagonal_update :: proc(
	south_west_north_east_fn: proc(_: glsl.ivec3),
	north_west_south_east_fn: proc(_: glsl.ivec3),
) {
	if (wall_tool_position.x >= wall_tool_drag_start.x &&
		   wall_tool_position.y >= wall_tool_drag_start.y) ||
	   (wall_tool_position.x < wall_tool_drag_start.x &&
			   wall_tool_position.y < wall_tool_drag_start.y) {
		south_west_north_east_update(south_west_north_east_fn)
	} else {
		north_west_south_east_update(north_west_south_east_fn)
	}
}

south_west_north_east_update :: proc(fn: proc(_: glsl.ivec3)) {
    floor := game.get_floor_context()
	start_x := min(wall_tool_position.x, wall_tool_drag_start.x)
	end_x := max(wall_tool_position.x, wall_tool_drag_start.x)
	z := wall_tool_drag_start.y

	dz: i32 = 0
	if wall_tool_position.x < wall_tool_drag_start.x {
		dz = start_x - end_x
	}
	for x, i in start_x ..< end_x {
		fn({x, i32(floor.floor), z + i32(i) + dz})
	}
}

north_west_south_east_update :: proc(fn: proc(_: glsl.ivec3)) {
    floor := game.get_floor_context()
	start_x := min(wall_tool_position.x, wall_tool_drag_start.x)
	end_x := max(wall_tool_position.x, wall_tool_drag_start.x)
	z := wall_tool_drag_start.y

	dz: i32 = -1
	if wall_tool_position.x < wall_tool_drag_start.x {
		dz = end_x - start_x - 1
	}

	for x, i in start_x ..< end_x {
		fn({x, i32(floor.floor), z - i32(i) + dz})
	}
}

cardinal_update :: proc(
	east_west: proc(_: glsl.ivec3),
	north_south: proc(_: glsl.ivec3),
) {
	if abs(wall_tool_position.x - wall_tool_drag_start.x) <
	   abs(wall_tool_position.y - wall_tool_drag_start.y) {
		north_south_update(north_south)
	} else {
		east_west_update(east_west)
	}
}

east_west_update :: proc(fn: proc(_: glsl.ivec3)) {
    floor := game.get_floor_context()
	start_x := min(wall_tool_position.x, wall_tool_drag_start.x)
	end_x := max(wall_tool_position.x, wall_tool_drag_start.x)
	z := wall_tool_drag_start.y
	for x in start_x ..< end_x {
		fn({x, i32(floor.floor), z})
	}
}

north_south_update :: proc(fn: proc(_: glsl.ivec3)) {
    floor := game.get_floor_context()
	start_z := min(wall_tool_position.y, wall_tool_drag_start.y)
	end_z := max(wall_tool_position.y, wall_tool_drag_start.y)
	x := wall_tool_drag_start.x
	for z in start_z ..< end_z {
		fn({x, i32(floor.floor), z})
	}
}

update_south_west_north_east_neighbors :: proc(pos: glsl.ivec3) {
	update_south_west_north_east_wall(pos + {-1, 0, -1})
	update_south_west_north_east_wall(pos + {1, 0, 1})
	update_north_west_south_east_wall(pos + {0, 0, 1})
	update_north_west_south_east_wall(pos + {0, 0, -1})
	update_north_west_south_east_wall(pos + {-1, 0, 0})
	update_north_west_south_east_wall(pos + {1, 0, 0})
}

update_north_west_south_east_neighbors :: proc(pos: glsl.ivec3) {
	update_north_west_south_east_wall(pos + {-1, 0, 1})
	update_north_west_south_east_wall(pos + {1, 0, -1})
	update_south_west_north_east_wall(pos + {0, 0, 1})
	update_south_west_north_east_wall(pos + {0, 0, -1})
	update_south_west_north_east_wall(pos + {-1, 0, 0})
	update_south_west_north_east_wall(pos + {1, 0, 0})
}

update_east_west_neighbors :: proc(pos: glsl.ivec3) {
	update_east_west_wall(pos + {-1, 0, 0})
	update_east_west_wall(pos + {1, 0, 0})
	update_north_south_wall(pos + {0, 0, -1})
	update_north_south_wall(pos + {0, 0, 0})
	update_north_south_wall(pos + {1, 0, -1})
	update_north_south_wall(pos + {1, 0, 0})
	update_north_west_south_east_wall(pos + {-1, 0, 0})
	update_north_west_south_east_wall(pos + {1, 0, -1})
	update_south_west_north_east_wall(pos + {-1, 0, -1})
	update_south_west_north_east_wall(pos + {1, 0, 0})
}

update_north_south_neighbors :: proc(pos: glsl.ivec3) {
	update_north_south_wall(pos + {0, 0, -1})
	update_north_south_wall(pos + {0, 0, 1})
	update_east_west_wall(pos + {-1, 0, 0})
	update_east_west_wall(pos + {0, 0, 0})
	update_east_west_wall(pos + {-1, 0, 1})
	update_east_west_wall(pos + {0, 0, 1})
	update_north_west_south_east_wall(pos + {-1, 0, 1})
	update_north_west_south_east_wall(pos + {0, 0, -1})
	update_south_west_north_east_wall(pos + {0, 0, 1})
	update_south_west_north_east_wall(pos + {-1, 0, -1})
}

update_south_west_north_east_wall_and_neighbors :: proc(pos: glsl.ivec3) {
	update_south_west_north_east_wall(pos)
	update_south_west_north_east_neighbors(pos)
}

update_north_west_south_east_wall_and_neighbors :: proc(pos: glsl.ivec3) {
	update_north_west_south_east_wall(pos)
	update_north_west_south_east_neighbors(pos)
}

update_east_west_wall_and_neighbors :: proc(pos: glsl.ivec3) {
	update_east_west_wall(pos)
	update_east_west_neighbors(pos)
}

update_north_south_wall_and_neighbors :: proc(pos: glsl.ivec3) {
	update_north_south_wall(pos)
	update_north_south_neighbors(pos)
}

undo_removing_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	if w, ok := wall_tool_south_west_north_east_walls[pos]; ok {
		game.set_south_west_north_east_wall(pos, w)
		update_south_west_north_east_wall_and_neighbors(pos)
	}
}

undo_removing_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	if w, ok := wall_tool_north_west_south_east_walls[pos]; ok {
		game.set_north_west_south_east_wall(pos, w)
		update_north_west_south_east_wall_and_neighbors(pos)
	}
}

undo_removing_east_west_wall :: proc(pos: glsl.ivec3) {
	if w, ok := wall_tool_east_west_walls[pos]; ok {
		game.set_east_west_wall(pos, w)
		update_east_west_wall_and_neighbors(pos)
	}
}

undo_removing_north_south_wall :: proc(pos: glsl.ivec3) {
	if w, ok := wall_tool_north_south_walls[pos]; ok {
		game.set_north_south_wall(pos, w)
		update_north_south_wall_and_neighbors(pos)
	}
}

remove_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := wall_tool_south_west_north_east_walls[pos]; ok {
		return
	}
	game.remove_south_west_north_east_wall(pos)
	update_south_west_north_east_neighbors(pos)
}

remove_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := wall_tool_north_west_south_east_walls[pos]; ok {
		return
	}
	game.remove_north_west_south_east_wall(pos)
	update_north_west_south_east_neighbors(pos)
}

remove_east_west_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := wall_tool_east_west_walls[pos]; ok {
		return
	}
	game.remove_east_west_wall(pos)
	update_east_west_neighbors(pos)
}

remove_north_south_wall :: proc(pos: glsl.ivec3) {
	if wall, ok := wall_tool_north_south_walls[pos]; ok {
		return
	}
	game.remove_north_south_wall(pos)
	update_north_south_neighbors(pos)
}

update_east_west_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 ||
	   pos.z < 0 ||
	   pos.x >= game.WORLD_WIDTH ||
	   pos.z >= game.WORLD_DEPTH {
		return
	}

	w, ok := game.get_east_west_wall(pos)
	if !ok {
		return
	}

	left_type_part := game.Wall_Type_Part.End
	if game.has_east_west_wall(pos + {-1, 0, 0}) {
		left_type_part = .Side
	} else {
		has_left := game.has_north_south_wall(pos + {0, 0, 0})
		has_right := game.has_north_south_wall(pos + {0, 0, -1})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := game.Wall_Type_Part.End
	if game.has_east_west_wall(pos + {1, 0, 0}) {
		right_type_part = .Side
	} else {
		has_left := game.has_north_south_wall(pos + {1, 0, 0})
		has_right := game.has_north_south_wall(pos + {1, 0, -1})

		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := game.WALL_SIDE_TYPE_MAP
	w.type = type_map[left_type_part][right_type_part]
	game.set_east_west_wall(pos, w)
}

update_north_south_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 ||
	   pos.z < 0 ||
	   pos.x >= game.WORLD_WIDTH ||
	   pos.z >= game.WORLD_DEPTH {
		return
	}

	w, ok := game.get_north_south_wall(pos)
	if !ok {
		return
	}

	left_type_part := game.Wall_Type_Part.End
	if game.has_north_south_wall(pos + {0, 0, 1}) {
		left_type_part = .Side
	} else {
		has_left := game.has_east_west_wall(pos + {-1, 0, 1})
		has_right := game.has_east_west_wall(pos + {0, 0, 1})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := game.Wall_Type_Part.End
	if game.has_north_south_wall(pos + {0, 0, -1}) {
		right_type_part = .Side
	} else {
		has_left := game.has_east_west_wall(pos + {-1, 0, 0})
		has_right := game.has_east_west_wall(pos + {0, 0, 0})

		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := game.WALL_SIDE_TYPE_MAP
	w.type = type_map[left_type_part][right_type_part]
	game.set_north_south_wall(pos, w)
}

update_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 ||
	   pos.z < 0 ||
	   pos.x >= game.WORLD_WIDTH ||
	   pos.z >= game.WORLD_DEPTH {
		return
	}

	w, ok := game.get_north_west_south_east_wall(pos)
	if !ok {
		return
	}

	left_type_part := game.Wall_Type_Part.End
	if game.has_north_west_south_east_wall(pos + {-1, 0, 1}) ||
	   game.has_north_south_wall(pos + {0, 0, 1}) ||
	   game.has_east_west_wall(pos + {-1, 0, 1}) {
		left_type_part = .Side
	} else {
		has_left := game.has_south_west_north_east_wall(pos + {0, 0, 1})
		has_right := game.has_south_west_north_east_wall(pos + {-1, 0, 0})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := game.Wall_Type_Part.End
	if game.has_north_west_south_east_wall(pos + {1, 0, -1}) ||
	   game.has_north_south_wall(pos + {1, 0, -1}) ||
	   game.has_east_west_wall(pos + {1, 0, 0}) {
		right_type_part = .Side
	} else {
		has_left := game.has_south_west_north_east_wall(pos + {1, 0, 0})
		has_right := game.has_south_west_north_east_wall(pos + {0, 0, -1})
		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := game.WALL_SIDE_TYPE_MAP
	w.type = type_map[left_type_part][right_type_part]
	game.set_north_west_south_east_wall(pos, w)
}

update_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	if pos.x < 0 ||
	   pos.z < 0 ||
	   pos.x >= game.WORLD_WIDTH ||
	   pos.z >= game.WORLD_DEPTH {
		return
	}

	w, ok := game.get_south_west_north_east_wall(pos)
	if !ok {
		return
	}

	left_type_part := game.Wall_Type_Part.End
	if game.has_south_west_north_east_wall(pos + {-1, 0, -1}) ||
	   game.has_north_south_wall(pos + {0, 0, -1}) ||
	   game.has_east_west_wall(pos + {-1, 0, 0}) {
		left_type_part = .Side
	} else {
		has_left := game.has_north_west_south_east_wall(pos + {-1, 0, 0})
		has_right := game.has_north_west_south_east_wall(pos + {0, 0, -1})
		if has_left && has_right {
			left_type_part = .Side
		} else if has_left {
			left_type_part = .Left_Corner
		} else if has_right {
			left_type_part = .Right_Corner
		}
	}
	right_type_part := game.Wall_Type_Part.End
	if game.has_south_west_north_east_wall(pos + {1, 0, 1}) ||
	   game.has_north_south_wall(pos + {1, 0, 1}) ||
	   game.has_east_west_wall(pos + {1, 0, 1}) {
		right_type_part = .Side
	} else {
		has_left := game.has_north_west_south_east_wall(pos + {0, 0, 1})
		has_right := game.has_north_west_south_east_wall(pos + {1, 0, 0})
		if has_left && has_right {
			right_type_part = .Side
		} else if has_left {
			right_type_part = .Left_Corner
		} else if has_right {
			right_type_part = .Right_Corner
		}
	}

	type_map := game.WALL_SIDE_TYPE_MAP
	w.type = type_map[left_type_part][right_type_part]
    // log.info(w)
	// log.info(pos, w.type)
	game.set_south_west_north_east_wall(pos, w)
}

set_south_west_north_east_wall_frame :: proc(pos: glsl.ivec3) {
	set_south_west_north_east_wall(pos, .Frame)
}

set_south_west_north_east_wall_drywall :: proc(pos: glsl.ivec3) {
	set_south_west_north_east_wall(pos, .Drywall)
}

set_south_west_north_east_wall :: proc(
	pos: glsl.ivec3,
	texture: game.Wall_Texture,
) {
	if wall, ok := game.get_south_west_north_east_wall(pos); ok {
		wall_tool_south_west_north_east_walls[pos] = wall
		return
	}

	if !game.is_tile_flat(pos.xz) {
		return
	}

	game.set_south_west_north_east_wall(
		pos,
		game.make_wall(
			type = .Side,
			textures = {.Inside = texture, .Outside = texture},
		),
	)
	update_south_west_north_east_wall_and_neighbors(pos)
}

set_north_west_south_east_wall_frame :: proc(pos: glsl.ivec3) {
	set_north_west_south_east_wall(pos, .Frame)
}

set_north_west_south_east_wall_drywall :: proc(pos: glsl.ivec3) {
	set_north_west_south_east_wall(pos, .Drywall)
}

set_north_west_south_east_wall :: proc(
	pos: glsl.ivec3,
	texture: game.Wall_Texture,
) {
	if wall, ok := game.get_north_west_south_east_wall(pos); ok {
		wall_tool_north_west_south_east_walls[pos] = wall
		return
	}

	if !game.is_tile_flat(pos.xz) {
		return
	}

	game.set_north_west_south_east_wall(
		pos,
		game.make_wall(
			type = .Side,
			textures = {.Inside = texture, .Outside = texture},
		),
	)

	update_north_west_south_east_wall_and_neighbors(pos)
}

set_east_west_wall_frame :: proc(pos: glsl.ivec3) {
	set_east_west_wall(pos, .Frame)
}

set_east_west_wall_drywall :: proc(pos: glsl.ivec3) {
	set_east_west_wall(pos, .Drywall)
}

set_east_west_wall :: proc(pos: glsl.ivec3, texture: game.Wall_Texture) {
	if wall, ok := game.get_east_west_wall(pos); ok {
		wall_tool_east_west_walls[pos] = wall
		return
	}

	if !game.is_tile_flat(pos.xz) {
		return
	}

	game.set_east_west_wall(
		pos,
		game.make_wall(
			type = .Side,
			textures = {.Inside = texture, .Outside = texture},
		),
	)
	update_east_west_wall_and_neighbors(pos)
}

set_north_south_wall_frame :: proc(pos: glsl.ivec3) {
	set_north_south_wall(pos, .Frame)
}

set_north_south_wall_drywall :: proc(pos: glsl.ivec3) {
	set_north_south_wall(pos, .Drywall)
}

set_north_south_wall :: proc(pos: glsl.ivec3, texture: game.Wall_Texture) {
	if wall, ok := game.get_north_south_wall(pos); ok {
		wall_tool_north_south_walls[pos] = wall
		return
	}

	if !game.is_tile_flat(pos.xz) {
		return
	}

	game.set_north_south_wall(
		pos,
		game.make_wall(
			type = .Side,
			textures = {.Inside = texture, .Outside = texture},
		),
	)
	update_north_south_wall_and_neighbors(pos)
}

removing_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	if w, ok := game.get_south_west_north_east_wall(pos); ok {
		wall_tool_south_west_north_east_walls[pos] = w
		game.remove_south_west_north_east_wall(pos)
		update_south_west_north_east_wall_and_neighbors(pos)
	}
}

removing_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	if w, ok := game.get_north_west_south_east_wall(pos); ok {
		wall_tool_north_west_south_east_walls[pos] = w
		game.remove_north_west_south_east_wall(pos)
		update_north_west_south_east_wall_and_neighbors(pos)
	}
}

removing_east_west_wall :: proc(pos: glsl.ivec3) {
	if w, ok := game.get_east_west_wall(pos); ok {
		wall_tool_east_west_walls[pos] = w
		game.remove_east_west_wall(pos)
		update_east_west_wall_and_neighbors(pos)
	}
}

removing_north_south_wall :: proc(pos: glsl.ivec3) {
	if w, ok := game.get_north_south_wall(pos); ok {
		wall_tool_north_south_walls[pos] = w
		game.remove_north_south_wall(pos)
		update_north_south_wall_and_neighbors(pos)
	}
}

revert_removing_line :: proc() {
	if mouse.is_button_down(.Left) || mouse.is_button_release(.Left) {
		update_walls_line(
			undo_removing_south_west_north_east_wall,
			undo_removing_north_west_south_east_wall,
			undo_removing_east_west_wall,
			undo_removing_north_south_wall,
		)
	}
}

removing_line :: proc() {
    floor := game.get_floor_context()

	revert_removing_line()

	previous_tool_position := wall_tool_position
	game.on_cursor_tile_intersect(
		on_tile_intersect,
		floor.previous_floor,
		floor.floor,
	)

	if previous_tool_position != wall_tool_position ||
	   floor.previous_floor != floor.floor {
		move_cursor()
	}

	if mouse.is_button_press(.Left) {
		wall_tool_drag_start = wall_tool_position
		clear(&wall_tool_south_west_north_east_walls)
		clear(&wall_tool_north_west_south_east_walls)
		clear(&wall_tool_east_west_walls)
		clear(&wall_tool_north_south_walls)
	} else if mouse.is_button_down(.Left) {
		update_walls_line(
			removing_south_west_north_east_wall,
			removing_north_west_south_east_wall,
			removing_east_west_wall,
			removing_north_south_wall,
		)
	} else if mouse.is_button_release(.Left) {
		update_walls_line(
			removing_south_west_north_east_wall,
			removing_north_west_south_east_wall,
			removing_east_west_wall,
			removing_north_south_wall,
		)
	} else {
		wall_tool_drag_start = wall_tool_position
	}

}

adding_line :: proc() {
    floor := game.get_floor_context()

	revert_walls_line()

	previous_tool_position := wall_tool_position
	game.on_cursor_tile_intersect(
		on_tile_intersect,
		floor.previous_floor,
		floor.floor,
	)

	if previous_tool_position != wall_tool_position {
		move_cursor()
	}

	if mouse.is_button_press(.Left) {
		wall_tool_drag_start = wall_tool_position
		clear(&wall_tool_south_west_north_east_walls)
		clear(&wall_tool_north_west_south_east_walls)
		clear(&wall_tool_east_west_walls)
		clear(&wall_tool_north_south_walls)
	} else if mouse.is_button_down(.Left) {
		update_walls_line(
			set_south_west_north_east_wall_frame,
			set_north_west_south_east_wall_frame,
			set_east_west_wall_frame,
			set_north_south_wall_frame,
		)
	} else if mouse.is_button_release(.Left) {
		update_walls_line(
			set_south_west_north_east_wall_drywall,
			set_north_west_south_east_wall_drywall,
			set_east_west_wall_drywall,
			set_north_south_wall_drywall,
		)
		game.update_cutaways(true)
	} else {
		wall_tool_drag_start = wall_tool_position
	}
}

update_line :: proc() {
	if mode == .Demolish || keyboard.is_key_down(.Key_Left_Control) {
		removing_line()
	} else {
		adding_line()
	}
}

adding_rectangle :: proc() {
    floor := game.get_floor_context()
	revert_walls_rectangle()

	previous_tool_position := wall_tool_position
	game.on_cursor_tile_intersect(
		on_tile_intersect,
		floor.previous_floor,
		floor.floor,
	)

	if previous_tool_position != wall_tool_position {
		move_cursor()
	}

	if mouse.is_button_press(.Left) {
		wall_tool_drag_start = wall_tool_position
		clear(&wall_tool_south_west_north_east_walls)
		clear(&wall_tool_north_west_south_east_walls)
		clear(&wall_tool_east_west_walls)
		clear(&wall_tool_north_south_walls)
	} else if mouse.is_button_down(.Left) {
		update_walls_rectangle(
			set_east_west_wall_frame,
			set_north_south_wall_frame,
		)
	} else if mouse.is_button_release(.Left) {
		update_walls_rectangle(
			set_east_west_wall_drywall,
			set_north_south_wall_drywall,
		)
	} else {
		wall_tool_drag_start = wall_tool_position
	}
}

revert_removing_rectangle :: proc() {
	if mouse.is_button_down(.Left) || mouse.is_button_release(.Left) {
		update_walls_rectangle(
			undo_removing_east_west_wall,
			undo_removing_north_south_wall,
		)
	}
}

removing_rectangle :: proc() {
    floor := game.get_floor_context()

	revert_removing_rectangle()

	previous_tool_position := wall_tool_position
	game.on_cursor_tile_intersect(
		on_tile_intersect,
		floor.previous_floor,
		floor.floor,
	)

	if previous_tool_position != wall_tool_position {
		move_cursor()
	}

	if mouse.is_button_press(.Left) {
		wall_tool_drag_start = wall_tool_position
		clear(&wall_tool_south_west_north_east_walls)
		clear(&wall_tool_north_west_south_east_walls)
		clear(&wall_tool_east_west_walls)
		clear(&wall_tool_north_south_walls)
	} else if mouse.is_button_down(.Left) {
		update_walls_rectangle(
			removing_east_west_wall,
			removing_north_south_wall,
		)
	} else if mouse.is_button_release(.Left) {
		update_walls_rectangle(
			removing_east_west_wall,
			removing_north_south_wall,
		)
	} else {
		wall_tool_drag_start = wall_tool_position
	}
}

update_rectangle :: proc() {
	if mode == .Demolish_Rectangle ||
	   keyboard.is_key_down(.Key_Left_Control) ||
	   (mode == .Demolish && keyboard.is_key_down(.Key_Left_Shift)) {
		removing_rectangle()
	} else {
		adding_rectangle()
	}
}

revert_walls_rectangle :: proc() {
	if mouse.is_button_down(.Left) || mouse.is_button_release(.Left) {
		update_walls_rectangle(remove_east_west_wall, remove_north_south_wall)
	}
}

revert_walls_line :: proc() {
	if mouse.is_button_down(.Left) || mouse.is_button_release(.Left) {
		update_walls_line(
			remove_south_west_north_east_wall,
			remove_north_west_south_east_wall,
			remove_east_west_wall,
			remove_north_south_wall,
		)
	}
}

move_cursor :: proc() {
    terrain := game.get_terrain_context()
    floor := game.get_floor_context()

	position: glsl.vec3
	position.y =
		terrain.terrain_heights[wall_tool_position.x][wall_tool_position.y]
	position.y += f32(floor.floor) * game.WALL_HEIGHT

	switch camera.rotation {
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

	billboard.billboard_1x1_move(&wall_tool_billboard, position)
}
