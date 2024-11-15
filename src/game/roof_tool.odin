package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:strings"

import "../cursor"
import "../floor"
import "../mouse"

import "../terrain"

Roof_Tool_Context :: struct {
	cursor:     Object_Draw,
	cursor_top: Object_Draw,
	roof:       Roof,
	active:     bool,
	// angle_str:  string,
}

init_roof_tool :: proc() {
	ctx := get_roof_tool_context()
	ctx.cursor.model = ROOF_TOOL_CURSOR_MODEL
	ctx.cursor.texture = ROOF_TOOL_CURSOR_TEXTURE
	ctx.cursor.light = {1, 1, 1}

	ctx.cursor_top.model = ROOF_TOOL_CURSOR_TOP_MODEL
	ctx.cursor_top.light = {1, 1, 1}
	cursor_top_map := ROOF_TOOL_CURSOR_TOP_MAP
	ctx.cursor_top.texture = cursor_top_map[ctx.roof.type]

	floor.show_markers = true

	ctx.roof.slope = 1
	// ctx.angle_str = fmt.aprint("45", "°", sep = "")

	get_roofs_context().floor_offset = 1
	ctx.active = true
}

deinit_roof_tool :: proc() {
	ctx := get_roof_tool_context()
	// delete_object_draw(ctx.cursor.id)

	floor.show_markers = false
	get_roofs_context().floor_offset = 0
	ctx.active = false

	// delete(ctx.angle_str)
}

update_roof_tool :: proc() {
	ctx := get_roof_tool_context()

	cursor.on_tile_intersect(
		roof_tool_on_intersect,
		floor.previous_floor,
		floor.floor,
	)

	ctx.cursor.transform = glsl.mat4Translate(ctx.cursor.pos)

	if mouse.is_button_press(.Left) {
		ctx.roof.start = ctx.cursor.pos.xz
		ctx.roof.end = ctx.roof.start
		ctx.roof.offset =
			f32(floor.floor) * 3 +
			terrain.get_tile_height(
				int(ctx.cursor.pos.x + 0.5),
				int(ctx.cursor.pos.y + 0.5),
			)
		ctx.roof.light = {1, 1, 1, 0.5}
		ctx.roof.id = add_roof(ctx.roof)
	} else if mouse.is_button_down(.Left) {
		ctx.roof.end = ctx.cursor.pos.xz
		update_roof(ctx.roof)
	} else if mouse.is_button_release(.Left) {
		ctx.roof.light = {1, 1, 1, 1}
		update_roof(ctx.roof)
		add_roof_walls(ctx.roof)
	}
}

draw_roof_tool :: proc() {
	ctx := get_roof_tool_context()
	if !ctx.active {return}
	draw_one_object(&ctx.cursor)

	ctx.cursor_top.transform = ctx.cursor.transform
	ctx.cursor_top.pos = ctx.cursor.pos
	draw_one_object(&ctx.cursor_top)
}

set_roof_tool_roof_type :: proc(type: Roof_Type) {
	ctx := get_roof_tool_context()
	ctx.roof.type = type
	cursor_top_map := ROOF_TOOL_CURSOR_TOP_MAP
	ctx.cursor_top.texture = cursor_top_map[type]
}

get_roof_tool_roof_angle :: proc() -> f32 {
	ctx := get_roof_tool_context()
	return math.atan(ctx.roof.slope) / math.PI * 180
}

increment_roof_tool_roof_angle :: proc() {
	ctx := get_roof_tool_context()
	angle := get_roof_tool_roof_angle()

	if angle >= 60 {
		return
	}

	angle += 15

	ctx.roof.slope = math.tan(angle / 180 * math.PI)
}

decrement_roof_tool_roof_angle :: proc() {
	ctx := get_roof_tool_context()
	angle := get_roof_tool_roof_angle()

	if angle <= 15 {
		return
	}

	angle -= 15

	ctx.roof.slope = math.tan(angle / 180 * math.PI)
}

@(private = "file")
ROOF_TOOL_CURSOR_MODEL :: "resources/roofs/roof_cursor.glb"

@(private = "file")
ROOF_TOOL_CURSOR_TEXTURE :: "resources/roofs/roof_cursor.png"

@(private = "file")
ROOF_TOOL_CURSOR_TOP_MODEL :: "resources/roofs/roof_cursor_top.glb"

@(private = "file")
ROOF_TOOL_CURSOR_TOP_MAP :: [Roof_Type]string {
	.Half_Hip   = "resources/roofs/half_hip_roof.png",
	.Half_Gable = "resources/roofs/half_gable_roof.png",
	.Hip        = "resources/roofs/hip_roof.png",
	.Gable      = "resources/roofs/gable_roof.png",
}

@(private = "file")
roof_tool_on_intersect :: proc(intersect: glsl.vec3) {
	ctx := get_roof_tool_context()
	ctx.cursor.pos = intersect
	ctx.cursor.pos.x = math.trunc(ctx.cursor.pos.x)
	ctx.cursor.pos.z = math.trunc(ctx.cursor.pos.z)
	ctx.cursor.pos.x += 0.5
	ctx.cursor.pos.z += 0.5
}

@(private = "file")
add_roof_walls :: proc(roof: Roof) {
	switch roof.type {
	case .Hip:
	case .Gable:
		add_gable_roof_walls(roof)
	case .Half_Hip:
		add_half_hip_roof_walls(roof)
	case .Half_Gable:
		add_half_gable_roof_walls(roof)
	}
}

@(private = "file")
add_north_south_gable_roof_walls :: proc(
	roof: Roof,
	start, end, size: glsl.vec2,
	floor: i32,
) {
	ceil_half := math.ceil(size.y / 2)
	trunc_half := math.trunc(size.y / 2)
	for y, i in start.y ..< end.y - ceil_half {
		add_wall(
			{i32(start.x), floor, i32(y)},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Left_Side,
				},
			},
		)
		add_wall(
			{i32(end.x), floor, i32(y)},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Left_Side,
				},
			},
		)
	}

	if ceil_half != trunc_half {
		add_wall(
			{i32(start.x), floor, i32(start.y + trunc_half)},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (trunc_half + ROOF_SIZE_PADDING.y / 2 - 0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope / 2,
					type = .Peak,
				},
			},
		)

		add_wall(
			{i32(end.x), floor, i32(start.y + trunc_half)},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (trunc_half + ROOF_SIZE_PADDING.y / 2 - 0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope / 2,
					type = .Peak,
				},
			},
		)
	}

	for y, i in end.y - trunc_half ..< end.y {
		add_wall(
			{i32(start.x), floor, i32(y)},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (trunc_half -
					f32(i) -
					1 +
					ROOF_SIZE_PADDING.y / 2 -
					0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Right_Side,
				},
			},
		)
		add_wall(
			{i32(end.x), floor, i32(y)},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (trunc_half -
					f32(i) -
					1 +
					ROOF_SIZE_PADDING.y / 2 -
					0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Right_Side,
				},
			},
		)
	}
}

@(private = "file")
add_east_west_gable_roof_walls :: proc(
	roof: Roof,
	start, end, size: glsl.vec2,
	floor: i32,
) {
	ceil_half := math.ceil(size.x / 2)
	trunc_half := math.trunc(size.x / 2)
	for x, i in start.x ..< end.x - ceil_half {
		type := Wall_Type.Side
		if x == start.x {
			type = .Start
		}
		add_wall(
			{i32(x), floor, i32(start.y)},
			.E_W,
			 {
				type = type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Right_Side,
				},
			},
		)
		add_wall(
			{i32(x), floor, i32(end.y)},
			.E_W,
			 {
				type = type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Right_Side,
				},
			},
		)
	}

	if ceil_half != trunc_half {
		add_wall(
			{i32(start.x + trunc_half), floor, i32(start.y)},
			.E_W,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (trunc_half + ROOF_SIZE_PADDING.y / 2 - 0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope / 2,
					type = .Peak,
				},
			},
		)

		add_wall(
			{i32(start.x + trunc_half), floor, i32(end.y)},
			.E_W,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (trunc_half + ROOF_SIZE_PADDING.y / 2 - 0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope / 2,
					type = .Peak,
				},
			},
		)
	}

	for x, i in end.x - trunc_half ..< end.x {
		type := Wall_Type.Side
		if x == end.x - 1 {
			type = .End
		}
		add_wall(
			{i32(x), floor, i32(start.y)},
			.E_W,
			 {
				type = type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (trunc_half -
					f32(i) -
					1 +
					ROOF_SIZE_PADDING.y / 2 -
					0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Left_Side,
				},
			},
		)
		add_wall(
			{i32(x), floor, i32(end.y)},
			.E_W,
			 {
				type = type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = (trunc_half -
					f32(i) -
					1 +
					ROOF_SIZE_PADDING.y / 2 -
					0.01) *
				roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Left_Side,
				},
			},
		)
	}
}

@(private = "file")
add_gable_roof_walls :: proc(roof: Roof) {
	t_start := roof.start + {0.5, 0.5}
	t_end := roof.end + {0.5, 0.5}
	tile_height := terrain.get_tile_height(int(t_start.x), int(t_start.y))
	floor := i32((roof.offset - tile_height) / 3)

	start := glsl.min(t_start, t_end)
	end := glsl.max(t_start, t_end)
	size := end - start

	if size.x > size.y {
		add_north_south_gable_roof_walls(roof, start, end, size, floor)
	} else {
		add_east_west_gable_roof_walls(roof, start, end, size, floor)
	}
}

@(private = "file")
add_east_west_half_hip_roof_walls :: proc(
	roof: Roof,
	start, end, t_start, t_end, size: glsl.vec2,
	floor: i32,
) {
	for dx in 0 ..< math.min(math.trunc(size.x / 2), size.y) {
		add_wall(
			{i32(start.x + dx), floor, i32(t_end.y)},
			.E_W,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = f32(dx) * roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Right_Side,
				},
			},
		)

		add_wall(
			{i32(end.x - dx - 1), floor, i32(t_end.y)},
			.E_W,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = f32(dx) * roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Left_Side,
				},
			},
		)
	}

	if math.remainder(size.x, 2) != 0 && size.x / size.y < 2 {
		add_wall(
			{i32(start.x + math.trunc(size.x / 2)), floor, i32(t_end.y)},
			.E_W,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = math.trunc(size.x / 2) * roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope / 2,
					type = .Peak,
				},
			},
		)
	}

	for dx in 0 ..< size.x - size.y * 2 {
		add_wall(
			{i32(start.x + size.y + dx), floor, i32(t_end.y)},
			.E_W,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = f32(size.y) * roof.slope,
			},
		)
	}
}

@(private = "file")
add_north_south_half_hip_roof_walls :: proc(
	roof: Roof,
	start, end, t_start, t_end, size: glsl.vec2,
	floor: i32,
) {
	for dy in 0 ..< math.min(math.trunc(size.y / 2), size.x) {
		add_wall(
			{i32(t_end.x), floor, i32(start.y + dy)},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = f32(dy) * roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Left_Side,
				},
			},
		)

		add_wall(
			{i32(t_end.x), floor, i32(end.y - dy - 1)},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = f32(dy) * roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope,
					type = .Right_Side,
				},
			},
		)
	}

	if math.remainder(size.y, 2) != 0 && size.y / size.x < 2 {
		add_wall(
			{i32(t_end.x), floor, i32(start.y + math.trunc(size.y / 2))},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = math.trunc(size.y / 2) * roof.slope,
				roof_slope = Wall_Roof_Slope {
					height = roof.slope / 2,
					type = .Peak,
				},
			},
		)
	}

	for dy in 0 ..< size.y - size.x * 2 {
		add_wall(
			{i32(t_end.x), floor, i32(start.y + size.x + dy)},
			.N_S,
			 {
				type = .Side,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = f32(size.x) * roof.slope,
			},
		)
	}
}

@(private = "file")
add_half_hip_roof_walls :: proc(roof: Roof) {
	t_start := roof.start + {0.5, 0.5}
	t_end := roof.end + {0.5, 0.5}
	tile_height := terrain.get_tile_height(int(t_start.x), int(t_start.y))
	floor := i32((roof.offset - tile_height) / 3)

	start := glsl.min(t_start, t_end)
	end := glsl.max(t_start, t_end)
	size := end - start

	if size.x > size.y {
		add_east_west_half_hip_roof_walls(
			roof,
			start,
			end,
			t_start,
			t_end,
			size,
			floor,
		)
	} else {
		add_north_south_half_hip_roof_walls(
			roof,
			start,
			end,
			t_start,
			t_end,
			size,
			floor,
		)
	}
}

@(private = "file")
add_east_west_half_gable_roof_walls :: proc(
	roof: Roof,
	start, end, t_start, t_end, size: glsl.vec2,
	floor: i32,
) {
	for x in start.x ..< end.x {
		wall_type := Wall_Type.Side
		if x == start.x {
			wall_type = .Extended_Left
		} else if x == end.x - 1 {
			wall_type = .Extended_Right
		}

		add_wall(
			{i32(x), floor, i32(t_end.y)},
			.E_W,
			 {
				type = wall_type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = size.y * roof.slope,
			},
		)
	}

	type := Wall_Roof_Slope_Type.Left_Side
	if t_end.y < t_start.y {
		type = .Right_Side
	}
	for y, i in start.y ..< end.y {
		height := f32(i)
		if t_end.y < t_start.y {
			height = size.y - f32(i) - 1
		}

		left_type := Wall_Type.Side
		right_type := Wall_Type.Side
		if y == t_end.y - 1 {
			left_type = .Extended_Left
			right_type = .Extended_Left
		} else if y == t_end.y {
			left_type = .Extended_Right
			right_type = .Extended_Right
		}

		add_wall(
			{i32(start.x), floor, i32(y)},
			.N_S,
			 {
				type = left_type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = height * roof.slope,
				roof_slope = Wall_Roof_Slope{height = roof.slope, type = type},
			},
		)

		add_wall(
			{i32(end.x), floor, i32(y)},
			.N_S,
			 {
				type = right_type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = height * roof.slope,
				roof_slope = Wall_Roof_Slope{height = roof.slope, type = type},
			},
		)
	}
}

@(private = "file")
add_north_south_half_gable_roof_walls :: proc(
	roof: Roof,
	start, end, t_start, t_end, size: glsl.vec2,
	floor: i32,
) {
	for y in start.y ..< end.y {
		wall_type := Wall_Type.Side
		if y == start.y {
			wall_type = .Extended_Right
		} else if y == end.y - 1 {
			wall_type = .Extended_Left
		}

		add_wall(
			{i32(t_end.x), floor, i32(y)},
			.N_S,
			 {
				type = wall_type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = size.x * roof.slope,
			},
		)
	}

	type := Wall_Roof_Slope_Type.Right_Side
	if t_end.x < t_start.x {
		type = .Left_Side
	}
	for x, i in start.x ..< end.x {
		height := f32(i)
		if t_end.x < t_start.x {
			height = size.x - f32(i) - 1
		}

		left_type := Wall_Type.Side
		right_type := Wall_Type.Side
		if x == t_end.x - 1 {
			left_type = .Extended_Right
			right_type = .Extended_Right
		} else if x == t_end.x {
			left_type = .Extended_Left
			right_type = .Extended_Left
		}

		add_wall(
			{i32(x), floor, i32(start.y)},
			.E_W,
			 {
				type = left_type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = height * roof.slope,
				roof_slope = Wall_Roof_Slope{height = roof.slope, type = type},
			},
		)

		add_wall(
			{i32(x), floor, i32(end.y)},
			.E_W,
			 {
				type = right_type,
				textures = {.Inside = .Brick, .Outside = .Brick},
				mask = .Full_Mask,
				state = .Up,
				height = height * roof.slope,
				roof_slope = Wall_Roof_Slope{height = roof.slope, type = type},
			},
		)
	}

}

@(private = "file")
add_half_gable_roof_walls :: proc(roof: Roof) {
	t_start := roof.start + {0.5, 0.5}
	t_end := roof.end + {0.5, 0.5}
	tile_height := terrain.get_tile_height(int(t_start.x), int(t_start.y))
	floor := i32((roof.offset - tile_height) / 3)

	start := glsl.min(t_start, t_end)
	end := glsl.max(t_start, t_end)
	size := end - start

	if size.x > size.y {
		add_east_west_half_gable_roof_walls(
			roof,
			start,
			end,
			t_start,
			t_end,
			size,
			floor,
		)
	} else {
		add_north_south_half_gable_roof_walls(
			roof,
			start,
			end,
			t_start,
			t_end,
			size,
			floor,
		)
	}
}
