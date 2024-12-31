package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:strings"

import "../cursor"
import "../floor"
import "../keyboard"
import "../mouse"

import "../terrain"

SQRT_2 :: 1.4142

Roof_Tool_Context :: struct {
	cursor:            Object_Draw,
	cursor_top:        Object_Draw,
	roof:              Roof,
	active:            bool,
	state:             Roof_Tool_State,
	roof_under_cursor: Maybe(Roof),
	// angle_str:  string,
}

@(private = "file")
Roof_Tool_State :: enum {
	Idle,
	Placing,
	Removing,
	Painting,
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
	ctx.roof.color = "big_square_tiles"
	ctx.roof.orientation = .Diagonal
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

	switch ctx.state {
	case .Idle:
		ctx.state = handle_roof_tool_idle()
	case .Placing:
		ctx.state = handle_roof_tool_placing()
	case .Removing:
		ctx.state = handle_roof_tool_removing()
	case .Painting:
		ctx.state = handle_roof_tool_painting()
	}

	// ctx.cursor_top.light = ctx.cursor.light
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

set_roof_tool_roof_color :: proc(color: string) {
	ctx := get_roof_tool_context()
	ctx.roof.color = color
}

set_roof_tool_state :: proc(state: Roof_Tool_State) {
	ctx := get_roof_tool_context()
	switch state {
	case .Idle:
	case .Painting:
		transition_to_paint_roof_state()
	case .Removing:
		transition_to_remove_roof_state()
	case .Placing:
	}
	ctx.state = state
}

toggle_roof_tool_state :: proc(state: Roof_Tool_State) {
	ctx := get_roof_tool_context()

	if ctx.state == state {
		transition_to_idle_roof_state()
		ctx.state = .Idle
		return
	}

	set_roof_tool_state(state)
}

is_roof_tool_state_removing :: proc() -> bool {
	return get_roof_tool_context().state == .Removing
}

is_roof_tool_state_painting :: proc() -> bool {
	return get_roof_tool_context().state == .Painting
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
ROOF_TOOL_CURSOR_WRECKING_BALL_MODEL :: "resources/roofs/Wrecking_Crane.glb"

@(private = "file")
ROOF_TOOL_CURSOR_WRECKING_BALL_TEXTURE :: "resources/roofs/Wrecking_Crane.png"

@(private = "file")
ROOF_TOOL_CURSOR_PAINT_BRUSH_MODEL :: "resources/roofs/Paint_Brush.glb"

@(private = "file")
ROOF_TOOL_CURSOR_PAINT_BRUSH_TEXTURE :: "resources/roofs/Paint_Brush.png"

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
		// if x == start.x {
		// 	type = .Start
		// }
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
		// if x == end.x - 1 {
		// 	type = .End
		// }
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

	if roof.orientation == .Diagonal {
		add_diagonal_gable_roof_walls(roof, floor)
		return
	}

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
add_diagonal_roof_nw_se_walls :: proc(
	pos: glsl.ivec3,
	offset: i32,
	height, slope_height: f32,
	slope_type: Wall_Roof_Slope_Type,
) {
	add_wall(
		pos,
		.NW_SE,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = height * SQRT_2,
			roof_slope = Wall_Roof_Slope {
				height = slope_height * SQRT_2,
				type = slope_type,
			},
		},
	)
	add_wall(
		pos - {offset, 0, offset},
		.NW_SE,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = height * SQRT_2,
			roof_slope = Wall_Roof_Slope {
				height = slope_height * SQRT_2,
				type = slope_type,
			},
		},
	)
}

@(private = "file")
add_diagonal_roof_sw_ne_walls :: proc(
	pos: glsl.ivec3,
	offset: i32,
	height, slope_height: f32,
	slope_type: Wall_Roof_Slope_Type,
) {
	add_wall(
		pos,
		.SW_NE,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = height * SQRT_2,
			roof_slope = Wall_Roof_Slope {
				height = slope_height * SQRT_2,
				type = slope_type,
			},
		},
	)
	add_wall(
		pos - {offset, 0, -offset},
		.SW_NE,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = height * SQRT_2,
			roof_slope = Wall_Roof_Slope {
				height = slope_height * SQRT_2,
				type = slope_type,
			},
		},
	)
}

@(private = "file")
add_diagonal_gable_roof_walls :: proc(roof: Roof, floor: i32) {
	roof := roof
	snap_roof(&roof)
	if (roof.end.x > roof.start.x && roof.end.y > roof.start.y) ||
	   (roof.end.x <= roof.start.x && roof.end.y <= roof.start.y) {
		c0 := roof.end.y + roof.end.x
		c1 := roof.start.y - roof.start.x
		ix := math.ceil((c0 - c1) / 2)
		offset := i32(ix - roof.start.x - 0.5)

		if roof.end.y > roof.start.y + (roof.end.x - roof.start.x) {
			width := ix - (roof.end.x + 0.5)
			trunc_half := math.trunc(width / 2)
			ceil_half := math.ceil(width / 2)

			for x, i in (roof.end.x + 0.5) ..< ix - math.ceil(width / 2) {
				add_diagonal_roof_nw_se_walls(
					{i32(x), floor, i32(roof.end.y) - i32(i)},
					offset,
					(f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) * roof.slope,
					roof.slope,
					.Right_Side,
				)
			}

			if ceil_half != trunc_half {
				add_diagonal_roof_nw_se_walls(
					 {
						i32(roof.end.x + 0.5 + trunc_half),
						floor,
						i32(roof.end.y - trunc_half),
					},
					offset,
					(trunc_half + ROOF_SIZE_PADDING.y / 2 - 0.01) * roof.slope,
					roof.slope / 2,
					.Peak,
				)
			}

			for x, i in (roof.end.x + 0.5) + ceil_half ..< ix {
				add_diagonal_roof_nw_se_walls(
					{i32(x), floor, i32(roof.end.y) - i32(i) - i32(ceil_half)},
					offset,
					(trunc_half -
						f32(i) -
						1 +
						ROOF_SIZE_PADDING.y / 2 -
						0.01) *
					roof.slope,
					roof.slope,
					.Left_Side,
				)
			}
		} else {
			width := (roof.end.x + 0.5) - ix
			trunc_half := math.trunc(width / 2)
			ceil_half := math.ceil(width / 2)

			for x, i in ix ..< (roof.end.x + 0.5) - ceil_half {
				add_diagonal_roof_nw_se_walls(
					{i32(x), floor, i32(roof.end.y + width) - i32(i)},
					offset,
					(f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) * roof.slope,
					roof.slope,
					.Right_Side,
				)
			}

			if ceil_half != trunc_half {
				add_diagonal_roof_nw_se_walls(
					 {
						i32(roof.end.x + 0.5 - ceil_half),
						floor,
						i32(roof.end.y + ceil_half),
					},
					offset,
					(trunc_half + ROOF_SIZE_PADDING.y / 2 - 0.01) * roof.slope,
					roof.slope / 2,
					.Peak,
				)
			}

			for x, i in ix + ceil_half ..< (roof.end.x + 0.5) {
				add_diagonal_roof_nw_se_walls(
					 {
						i32(x),
						floor,
						i32(roof.end.y) - i32(i) + i32(trunc_half),
					},
					offset,
					(trunc_half -
						f32(i) -
						1 +
						ROOF_SIZE_PADDING.y / 2 -
						0.01) *
					roof.slope,
					roof.slope,
					.Left_Side,
				)
			}
		}
	} else {
		c0 := roof.end.y - roof.end.x
		c1 := roof.start.y + roof.start.x
		ix := math.ceil((-c0 + c1) / 2)
		offset := i32(ix - roof.start.x - 0.5)

		if roof.end.y > roof.start.y - (roof.end.x - roof.start.x) {
			width := (roof.end.x + 0.5) - ix
			trunc_half := math.trunc(width / 2)
			ceil_half := math.ceil(width / 2)
			log.info(width, trunc_half, ceil_half)

			for x, i in ix ..< (roof.end.x + 0.5) - ceil_half {
				add_diagonal_roof_sw_ne_walls(
					{i32(x), floor, i32(roof.end.y + 0.5 - width) + i32(i)},
					offset,
					(f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) * roof.slope,
					roof.slope,
					.Right_Side,
				)
			}

			if ceil_half != trunc_half {
				add_diagonal_roof_sw_ne_walls(
					 {
						i32(ix + trunc_half),
						floor,
						i32(roof.end.y - trunc_half),
					},
					offset,
					(trunc_half + ROOF_SIZE_PADDING.y / 2 - 0.01) * roof.slope,
					roof.slope / 2,
					.Peak,
				)
			}

			for x, i in ix + ceil_half ..< (roof.end.x + 0.5) {
				add_diagonal_roof_sw_ne_walls(
					 {
						i32(x),
						floor,
						i32(roof.end.y + 0.5 - trunc_half) + i32(i),
					},
					offset,
					(trunc_half -
						f32(i) -
						1 +
						ROOF_SIZE_PADDING.y / 2 -
						0.01) *
					roof.slope,
					roof.slope,
					.Left_Side,
				)
			}
		} else {
			width := ix - (roof.end.x + 0.5)
			trunc_half := math.trunc(width / 2)
			ceil_half := math.ceil(width / 2)

			for x, i in (roof.end.x + 0.5) ..< ix - math.ceil(width / 2) {
				add_diagonal_roof_sw_ne_walls(
					{i32(x), floor, i32(roof.end.y + 0.5) + i32(i)},
					offset,
					(f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) * roof.slope,
					roof.slope,
					.Right_Side,
				)
			}

			if ceil_half != trunc_half {
				add_diagonal_roof_sw_ne_walls(
					 {
						i32(roof.end.x + 0.5 + trunc_half),
						floor,
						i32(roof.end.y + 0.5 + trunc_half),
					},
					offset,
					(trunc_half + ROOF_SIZE_PADDING.y / 2 - 0.01) * roof.slope,
					roof.slope / 2,
					.Peak,
				)
			}

			for x, i in (roof.end.x + 0.5) + ceil_half ..< ix {
				add_diagonal_roof_sw_ne_walls(
					 {
						i32(x),
						floor,
						i32(roof.end.y + 0.5) + i32(i) + i32(ceil_half),
					},
					offset,
					(trunc_half -
						f32(i) -
						1 +
						ROOF_SIZE_PADDING.y / 2 -
						0.01) *
					roof.slope,
					roof.slope,
					.Left_Side,
				)
			}
		}
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
add_diagonal_half_hip_roof_walls :: proc(roof: Roof, floor: i32) {
	roof := roof
	snap_roof(&roof)

	c0 := roof.end.y + roof.end.x
	c1 := roof.end.y - roof.end.x
	c2 := roof.start.y + roof.start.x
	c3 := roof.start.y - roof.start.x

	x1 := math.ceil((c0 - c3) / 2)
	x3 := math.ceil((c2 - c1) / 2)

	xy0 := glsl.ivec2{i32(roof.end.x + 0.5), i32(roof.end.y + 0.5)}
	xy1 := glsl.ivec2{i32(x1), i32(x1 + c3)}
	xy2 := glsl.ivec2{i32(roof.start.x + 0.5), i32(roof.start.y + 0.5)}
	xy3 := glsl.ivec2{i32(x3), i32(x3 + c1)}

	log.info(xy0, xy1, xy2, xy3)

	if (roof.end.x > roof.start.x && roof.end.y > roof.start.y) ||
	   (roof.end.x <= roof.start.x && roof.end.y <= roof.start.y) {
		c0 := roof.end.y + roof.end.x
		c1 := roof.start.y - roof.start.x
		ix := math.ceil((c0 - c1) / 2)
		offset := i32(ix - roof.start.x - 0.5)

		min_x := min(xy3.x, xy0.x)
		max_x := max(xy3.x, xy0.x)
		y := min(xy3.y, xy0.y)
		width := max_x - min_x
		depth := abs(min(xy1.x, xy2.x) - min_x)
		side_width := min(i32(width / 2), depth)
		for x, i in min_x ..< min_x + side_width {
			add_wall(
				{x, floor, y + i32(i)},
				.SW_NE,
				 {
					type = .Side,
					textures = {.Inside = .Brick, .Outside = .Brick},
					mask = .Full_Mask,
					state = .Up,
					height = (f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) *
					roof.slope * SQRT_2,
					roof_slope = Wall_Roof_Slope {
						height = roof.slope * SQRT_2,
						type = .Right_Side,
					},
				},
			)
		}
		if depth > side_width {
			if width - side_width * 2 == 1 {
				add_wall(
					{min_x + side_width, floor, y + side_width},
					.SW_NE,
					 {
						type = .Side,
						textures = {.Inside = .Brick, .Outside = .Brick},
						mask = .Full_Mask,
						state = .Up,
						height = ((f32(side_width) +
								ROOF_SIZE_PADDING.y / 2 -
								0.01) *
							roof.slope * SQRT_2),
						roof_slope = Wall_Roof_Slope {
							height = roof.slope / 2 * SQRT_2,
							type = .Peak,
						},
					},
				)
			}
		} else {
			for x, i in min_x + side_width ..< max_x - side_width {
				add_wall(
					{x, floor, y + side_width + i32(i)},
					.SW_NE,
					 {
						type = .Side,
						textures = {.Inside = .Brick, .Outside = .Brick},
						mask = .Full_Mask,
						state = .Up,
						height = ((f32(side_width) +
								ROOF_SIZE_PADDING.y / 2 -
								0.01) *
							roof.slope * SQRT_2),
					},
				)
			}
		}
		for x, i in max_x - side_width ..< max_x {
			add_wall(
				{x, floor, y + max_x - min_x - side_width + i32(i)},
				.SW_NE,
				 {
					type = .Side,
					textures = {.Inside = .Brick, .Outside = .Brick},
					mask = .Full_Mask,
					state = .Up,
					height = (f32(side_width - i32(i) - 1) +
						ROOF_SIZE_PADDING.y / 2 -
						0.01) *
					roof.slope * SQRT_2,
					roof_slope = Wall_Roof_Slope {
						height = roof.slope * SQRT_2,
						type = .Left_Side,
					},
				},
			)
		}
	} else {
		c0 := roof.end.y + roof.end.x
		c1 := roof.start.y - roof.start.x
		ix := math.ceil((c0 - c1) / 2)
		offset := i32(ix - roof.start.x - 0.5)

		min_x := min(xy0.x, xy1.x)
		max_x := max(xy0.x, xy1.x)
		y := max(xy0.y, xy1.y) - 1
		width := max_x - min_x
        log.info(width)
		depth := abs(min(xy2.x, xy3.x) - min_x)
		side_width := min(i32(width / 2), depth)
        log.info(min_x, min_x + side_width)
		for x, i in min_x ..< min_x + side_width {
			add_wall(
				{x, floor, y - i32(i)},
				.NW_SE,
				 {
					type = .Side,
					textures = {.Inside = .Brick, .Outside = .Brick},
					mask = .Full_Mask,
					state = .Up,
					height = (f32(i) + ROOF_SIZE_PADDING.y / 2 - 0.01) *
					roof.slope * SQRT_2,
					roof_slope = Wall_Roof_Slope {
						height = roof.slope * SQRT_2,
						type = .Right_Side,
					},
				},
			)
		}
		if depth > side_width {
			if width - side_width * 2 == 1 {
				add_wall(
					{min_x + side_width, floor, y - side_width},
					.NW_SE,
					 {
						type = .Side,
						textures = {.Inside = .Brick, .Outside = .Brick},
						mask = .Full_Mask,
						state = .Up,
						height = ((f32(side_width) +
								ROOF_SIZE_PADDING.y / 2 -
								0.01) *
							roof.slope * SQRT_2),
						roof_slope = Wall_Roof_Slope {
							height = roof.slope / 2 * SQRT_2,
							type = .Peak,
						},
					},
				)
			}
		} else {
			for x, i in min_x + side_width ..< max_x - side_width {
				add_wall(
					{x, floor, y - side_width - i32(i)},
					.NW_SE,
					 {
						type = .Side,
						textures = {.Inside = .Brick, .Outside = .Brick},
						mask = .Full_Mask,
						state = .Up,
						height = ((f32(side_width) +
								ROOF_SIZE_PADDING.y / 2 -
								0.02) *
							roof.slope * SQRT_2),
					},
				)
			}
		}
		for x, i in max_x - side_width ..< max_x {
			add_wall(
				{x, floor, y - width + side_width - i32(i)},
				.NW_SE,
				 {
					type = .Side,
					textures = {.Inside = .Brick, .Outside = .Brick},
					mask = .Full_Mask,
					state = .Up,
					height = (f32(side_width - i32(i) - 1) +
						ROOF_SIZE_PADDING.y / 2 -
						0.01) *
					roof.slope * SQRT_2,
					roof_slope = Wall_Roof_Slope {
						height = roof.slope * SQRT_2,
						type = .Left_Side,
					},
				},
			)
		}
	}
}

@(private = "file")
add_half_hip_roof_walls :: proc(roof: Roof) {
	t_start := roof.start + {0.5, 0.5}
	t_end := roof.end + {0.5, 0.5}
	tile_height := terrain.get_tile_height(int(t_start.x), int(t_start.y))
	floor := i32((roof.offset - tile_height) / 3)

	if roof.orientation == .Diagonal {
		add_diagonal_half_hip_roof_walls(roof, floor)
	} else {
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

@(private = "file")
handle_roof_tool_idle :: proc() -> Roof_Tool_State {
	ctx := get_roof_tool_context()

	if keyboard.is_key_down(.Key_Left_Control) {
		transition_to_remove_roof_state()

		return .Removing
	}

	if keyboard.is_key_press(.Key_Left_Shift) {
		transition_to_paint_roof_state()

		return .Painting
	}

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

		return .Placing
	}

	return ctx.state
}

@(private = "file")
handle_roof_tool_placing :: proc() -> Roof_Tool_State {
	ctx := get_roof_tool_context()

	if keyboard.is_key_down(.Key_Left_Control) {
		transition_to_remove_roof_state()
		remove_roof(ctx.roof)
		return .Removing
	}

	if mouse.is_button_release(.Left) {
		ctx.roof.light = {1, 1, 1, 1}
		update_roof(ctx.roof)
		add_roof_walls(ctx.roof)
		return .Idle
	}

	ctx.roof.end = ctx.cursor.pos.xz
	update_roof(ctx.roof)
	return ctx.state
}

@(private = "file")
handle_roof_tool_removing :: proc() -> Roof_Tool_State {
	ctx := get_roof_tool_context()

	if roof, ok := ctx.roof_under_cursor.?; ok {
		roof.light = {1, 1, 1, 1}
		update_roof(roof)
	}

	if keyboard.is_key_release(.Key_Left_Control) ||
	   keyboard.is_key_press(.Key_Escape) {
		transition_to_idle_roof_state()
		return .Idle
	}

	if keyboard.is_key_press(.Key_Left_Shift) {
		transition_to_paint_roof_state()
		return .Painting
	}

	roofs := get_roofs_context()

	pos :=
		glsl.floor(ctx.cursor.pos + glsl.vec3{0.5, 0, 0.5}) -
		glsl.vec3{0.5, 0, 0.5}
	if roof, ok := get_roof_at(pos); ok {
		if mouse.is_button_press(.Left) {
			ctx.roof_under_cursor = nil
			remove_roof_walls(roof)
			remove_roof(roof)
		} else {
			roof.light = {1, 0, 0, 1}
			ctx.roof_under_cursor = roof
			update_roof(roof)
		}
	} else {
		ctx.roof_under_cursor = nil
	}

	return ctx.state
}

@(private = "file")
handle_roof_tool_painting :: proc() -> Roof_Tool_State {
	ctx := get_roof_tool_context()

	if roof, ok := ctx.roof_under_cursor.?; ok {
		update_roof(roof)
	}

	if keyboard.is_key_release(.Key_Left_Shift) ||
	   keyboard.is_key_press(.Key_Escape) {
		transition_to_idle_roof_state()
		return .Idle
	}

	roofs := get_roofs_context()

	pos :=
		glsl.floor(ctx.cursor.pos + glsl.vec3{0.5, 0, 0.5}) -
		glsl.vec3{0.5, 0, 0.5}
	if roof, ok := get_roof_at(pos); ok {
		if mouse.is_button_press(.Left) {
			ctx.roof_under_cursor = nil
		} else {
			if roof_under_cursor, ok := ctx.roof_under_cursor.?; ok {
				if roof.color == ctx.roof.color {
					roof.color = roof_under_cursor.color
				}
			}
			ctx.roof_under_cursor = roof
		}
		roof.color = ctx.roof.color
		update_roof(roof)
	} else {
		ctx.roof_under_cursor = nil
	}

	return ctx.state
}

@(private = "file")
remove_roof_walls :: proc(roof: Roof) {
	switch roof.type {
	case .Hip:
	case .Gable:
		remove_gable_roof_walls(roof)
	case .Half_Hip:
		remove_half_hip_roof_walls(roof)
	case .Half_Gable:
		remove_half_gable_roof_walls(roof)
	}
}

@(private = "file")
remove_north_south_gable_roof_walls :: proc(
	roof: Roof,
	start, end, size: glsl.vec2,
	floor: i32,
) {
	ceil_half := math.ceil(size.y / 2)
	trunc_half := math.trunc(size.y / 2)
	for y, i in start.y ..< end.y - ceil_half {
		remove_wall({i32(start.x), floor, i32(y)}, .N_S)
		remove_wall({i32(end.x), floor, i32(y)}, .N_S)
	}

	if ceil_half != trunc_half {
		remove_wall({i32(start.x), floor, i32(start.y + trunc_half)}, .N_S)
		remove_wall({i32(end.x), floor, i32(start.y + trunc_half)}, .N_S)
	}

	for y, i in end.y - trunc_half ..< end.y {
		remove_wall({i32(start.x), floor, i32(y)}, .N_S)
		remove_wall({i32(end.x), floor, i32(y)}, .N_S)
	}
}

@(private = "file")
remove_east_west_gable_roof_walls :: proc(
	roof: Roof,
	start, end, size: glsl.vec2,
	floor: i32,
) {
	ceil_half := math.ceil(size.x / 2)
	trunc_half := math.trunc(size.x / 2)
	for x, i in start.x ..< end.x - ceil_half {
		remove_wall({i32(x), floor, i32(start.y)}, .E_W)
		remove_wall({i32(x), floor, i32(end.y)}, .E_W)
	}

	if ceil_half != trunc_half {
		remove_wall({i32(start.x + trunc_half), floor, i32(start.y)}, .E_W)

		remove_wall({i32(start.x + trunc_half), floor, i32(end.y)}, .E_W)
	}

	for x, i in end.x - trunc_half ..< end.x {
		remove_wall({i32(x), floor, i32(start.y)}, .E_W)
		remove_wall({i32(x), floor, i32(end.y)}, .E_W)
	}
}

@(private = "file")
remove_gable_roof_walls :: proc(roof: Roof) {
	t_start := roof.start + {0.5, 0.5}
	t_end := roof.end + {0.5, 0.5}
	tile_height := terrain.get_tile_height(int(t_start.x), int(t_start.y))
	floor := i32((roof.offset - tile_height) / 3)

	start := glsl.min(t_start, t_end)
	end := glsl.max(t_start, t_end)
	size := end - start

	if size.x > size.y {
		remove_north_south_gable_roof_walls(roof, start, end, size, floor)
	} else {
		remove_east_west_gable_roof_walls(roof, start, end, size, floor)
	}
}

@(private = "file")
remove_east_west_half_hip_roof_walls :: proc(
	roof: Roof,
	start, end, t_start, t_end, size: glsl.vec2,
	floor: i32,
) {
	for dx in 0 ..< math.min(math.trunc(size.x / 2), size.y) {
		remove_wall({i32(start.x + dx), floor, i32(t_end.y)}, .E_W)
		remove_wall({i32(end.x - dx - 1), floor, i32(t_end.y)}, .E_W)
	}

	if math.remainder(size.x, 2) != 0 && size.x / size.y < 2 {
		remove_wall(
			{i32(start.x + math.trunc(size.x / 2)), floor, i32(t_end.y)},
			.E_W,
		)
	}

	for dx in 0 ..< size.x - size.y * 2 {
		remove_wall({i32(start.x + size.y + dx), floor, i32(t_end.y)}, .E_W)
	}
}

@(private = "file")
remove_north_south_half_hip_roof_walls :: proc(
	roof: Roof,
	start, end, t_start, t_end, size: glsl.vec2,
	floor: i32,
) {
	for dy in 0 ..< math.min(math.trunc(size.y / 2), size.x) {
		remove_wall({i32(t_end.x), floor, i32(start.y + dy)}, .N_S)
		remove_wall({i32(t_end.x), floor, i32(end.y - dy - 1)}, .N_S)
	}

	if math.remainder(size.y, 2) != 0 && size.y / size.x < 2 {
		remove_wall(
			{i32(t_end.x), floor, i32(start.y + math.trunc(size.y / 2))},
			.N_S,
		)
	}

	for dy in 0 ..< size.y - size.x * 2 {
		remove_wall({i32(t_end.x), floor, i32(start.y + size.x + dy)}, .N_S)
	}
}

@(private = "file")
remove_half_hip_roof_walls :: proc(roof: Roof) {
	t_start := roof.start + {0.5, 0.5}
	t_end := roof.end + {0.5, 0.5}
	tile_height := terrain.get_tile_height(int(t_start.x), int(t_start.y))
	floor := i32((roof.offset - tile_height) / 3)

	start := glsl.min(t_start, t_end)
	end := glsl.max(t_start, t_end)
	size := end - start

	if size.x > size.y {
		remove_east_west_half_hip_roof_walls(
			roof,
			start,
			end,
			t_start,
			t_end,
			size,
			floor,
		)
	} else {
		remove_north_south_half_hip_roof_walls(
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
remove_east_west_half_gable_roof_walls :: proc(
	roof: Roof,
	start, end, t_start, t_end, size: glsl.vec2,
	floor: i32,
) {
	for x in start.x ..< end.x {
		remove_wall({i32(x), floor, i32(t_end.y)}, .E_W)
	}

	for y, i in start.y ..< end.y {
		remove_wall({i32(start.x), floor, i32(y)}, .N_S)
		remove_wall({i32(end.x), floor, i32(y)}, .N_S)
	}
}

@(private = "file")
remove_north_south_half_gable_roof_walls :: proc(
	roof: Roof,
	start, end, t_start, t_end, size: glsl.vec2,
	floor: i32,
) {
	for y in start.y ..< end.y {
		remove_wall({i32(t_end.x), floor, i32(y)}, .N_S)
	}

	for x, i in start.x ..< end.x {
		remove_wall({i32(x), floor, i32(start.y)}, .E_W)
		remove_wall({i32(x), floor, i32(end.y)}, .E_W)
	}
}

@(private = "file")
remove_half_gable_roof_walls :: proc(roof: Roof) {
	t_start := roof.start + {0.5, 0.5}
	t_end := roof.end + {0.5, 0.5}
	tile_height := terrain.get_tile_height(int(t_start.x), int(t_start.y))
	floor := i32((roof.offset - tile_height) / 3)

	start := glsl.min(t_start, t_end)
	end := glsl.max(t_start, t_end)
	size := end - start

	if size.x > size.y {
		remove_east_west_half_gable_roof_walls(
			roof,
			start,
			end,
			t_start,
			t_end,
			size,
			floor,
		)
	} else {
		remove_north_south_half_gable_roof_walls(
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
transition_to_remove_roof_state :: proc() {
	ctx := get_roof_tool_context()
	ctx.cursor.light = {1, 0, 0}
	ctx.cursor_top.model = ROOF_TOOL_CURSOR_WRECKING_BALL_MODEL
	ctx.cursor_top.texture = ROOF_TOOL_CURSOR_WRECKING_BALL_TEXTURE
}

@(private = "file")
transition_to_idle_roof_state :: proc() {
	ctx := get_roof_tool_context()
	ctx.cursor.light = {1, 1, 1}
	ctx.cursor_top.model = ROOF_TOOL_CURSOR_TOP_MODEL
	top_map := ROOF_TOOL_CURSOR_TOP_MAP
	ctx.cursor_top.texture = top_map[ctx.roof.type]
}

@(private = "file")
transition_to_paint_roof_state :: proc() {
	ctx := get_roof_tool_context()
	ctx.cursor.light = {1, 1, 1}
	ctx.cursor_top.model = ROOF_TOOL_CURSOR_PAINT_BRUSH_MODEL
	ctx.cursor_top.texture = ROOF_TOOL_CURSOR_PAINT_BRUSH_TEXTURE
}
