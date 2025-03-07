package game

import "core:math/linalg/glsl"

Game_Context :: struct {
	textures:          Textures_Context,
	models:            Models_Context,
	objects:           Objects_Context,
	shaders:           Shaders_Context,
	object_draws:      Object_Draws,
	object_blueprints: Object_Blueprints,
	roofs:             Roofs_Context,
	cutaway:           Cutaway_Context,
	walls:             Walls_Context,
	cursor:            Cursor_Context,
	terrain:           Terrain_Context,
	floor:             Floor_Context,
	tile_triangles:    Tile_Triangle_Context,
	mouse:             Mouse,
	camera:            Camera,
	keyboard:          Keyboard,
	window:            Window,
	renderer:          Renderer,
	lots:              Lots,
	// ---------- Tools ---------
	tools:             Tools,
	object_tool:       Object_Tool_Context,
	roof_tool:         Roof_Tool_Context,
	wall_tool:         Wall_Tool,
	paint_tool:        Paint_Tool,
	terrain_tool:      Terrain_Tool,
	floor_tool:        Floor_Tool,
}

game :: proc() -> ^Game_Context {
	return cast(^Game_Context)context.user_ptr
}

get_textures_context :: proc() -> ^Textures_Context {
	return &game().textures
}

get_objects_context :: proc() -> ^Objects_Context {
	return &game().objects
}

get_models_context :: proc() -> ^Models_Context {
	return &game().models
}

get_shaders_context :: proc() -> ^Shaders_Context {
	return &game().shaders
}

get_object_tool_context :: proc() -> ^Object_Tool_Context {
	return &game().object_tool
}

get_object_draws_context :: proc() -> ^Object_Draws {
	return &game().object_draws
}

get_roofs_context :: proc() -> ^Roofs_Context {
	return &game().roofs
}

get_roof_tool_context :: proc() -> ^Roof_Tool_Context {
	return &game().roof_tool
}

get_cutaway_context :: proc() -> ^Cutaway_Context {
	return &game().cutaway
}

get_walls_context :: proc() -> ^Walls_Context {
	return &game().walls
}

get_cursor_context :: proc() -> ^Cursor_Context {
	return &game().cursor
}

get_terrain_context :: proc() -> ^Terrain_Context {
	return &game().terrain
}

get_floor_context :: proc() -> ^Floor_Context {
	return &game().floor
}

get_tile_triangles_context :: proc() -> ^Tile_Triangle_Context {
	return &game().tile_triangles
}

init_game :: proc() -> bool {
	if (!renderer_init()) do return false

	init_wall_renderer() or_return
	keyboard_init()
	mouse_init()
	init_cursor()
	init_terrain()
	load_models() or_return
	init_objects() or_return

    lots_init()

	init_cutaways()

	floor_tool_init()
	terrain_tool_init()
    init_object_tool()
	load_object_blueprints() or_return
	init_object_draws() or_return
	init_roofs() or_return
	tile_triangles_init() or_return
	camera_init() or_return

	// add_roof({type = .Half_Hip, start = {0, 0}, end = {0, 1}})
	// add_roof({type = .Half_Hip, start = {0, 3}, end = {0, 5}})
	// add_roof({type = .Half_Hip, start = {0, 7}, end = {1, 8}})
	// add_roof({type = .Half_Hip, start = {0, 10}, end = {3, 14}})
	// add_roof({type = .Half_Hip, start = {0, 16}, end = {2, 17}})
	// add_roof({type = .Half_Hip, start = {0, 19}, end = {2, 26}})
	// add_roof({type = .Half_Hip, start = {0, 28}, end = {2, 33}})
	// add_roof({type = .Hip, start = {3, 0}, end = {6, 3}})
	//

	add_roof(
		 {
			type = .Hip,
			start = {-4, -4},
			end = {-3, -3},
			offset = 0,
			slope = 1,
			light = {1, 1, 1, 1},
			color = "big_square_tiles",
		},
	)

	add_roof(
		 {
			type = .Hip,
			start = {11.4, 11.4},
			end = {23.6, 22.6},
			offset = 6,
			slope = 1,
			light = {1, 1, 1, 1},
			color = "hexagon_tiles",
		},
	)

	add_roof(
		 {
			type = .Gable,
			start = {11.4, 15.4},
			end = {15.6, 18.6},
			offset = 6,
			slope = 1,
			light = {1, 1, 1, 1},
			color = "big_square_tiles",
		},
	)

	set_wall(
		{12, 2, 16},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 0,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Left_Side},
		},
	)

	set_wall(
		{12, 2, 17},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 0.5, type = .Peak},
		},
	)

	set_wall(
		{12, 2, 18},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 0,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Right_Side},
		},
	)

	set_wall(
		{16, 2, 16},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 0,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Left_Side},
		},
	)

	set_wall(
		{16, 2, 17},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 0.5, type = .Peak},
		},
	)

	set_wall(
		{16, 2, 18},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 0,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Right_Side},
		},
	)

    world_init()

	return true
}

deinit_game :: proc() {
    renderer_deinit()
    keyboard_deinit()
    mouse_deinit()
    tools_deinit()
    delete_textures()
	deinit_object_draws()
	deinit_object_tool()
	deinit_roofs()
	deinit_walls()
	tile_triangles_deinit()
	floor_tool_deinit()
	paint_tool_deinit()
	lots_deinit()
    delete_objects()
    deload_object_blueprints()
}

draw_game :: proc(floor: i32) -> bool {
	draw_roof_tool()
	draw_roofs(floor)
	draw_objects(floor) or_return

	return true
}

update_game_on_camera_rotation :: proc() {
	update_objects_on_camera_rotation()
}
