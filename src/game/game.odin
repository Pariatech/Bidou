package game

import "core:math/linalg/glsl"

Game_Context :: struct {
	textures:          Textures_Context,
	models:            Models_Context,
	objects:           Objects_Context,
	shaders:           Shaders_Context,
	object_tool:       Object_Tool_Context,
	object_draws:      Object_Draws,
	object_blueprints: Object_Blueprints,
	roofs:             Roofs_Context,
	roof_tool:         Roof_Tool_Context,
}

get_game_context :: #force_inline proc() -> ^Game_Context {
	return cast(^Game_Context)context.user_ptr
}

get_textures_context :: proc() -> ^Textures_Context {
	return &get_game_context().textures
}

get_objects_context :: proc() -> ^Objects_Context {
	return &get_game_context().objects
}

get_models_context :: proc() -> ^Models_Context {
	return &get_game_context().models
}

get_shaders_context :: proc() -> ^Shaders_Context {
	return &get_game_context().shaders
}

get_object_tool_context :: proc() -> ^Object_Tool_Context {
	return &get_game_context().object_tool
}

get_object_draws_context :: proc() -> ^Object_Draws {
	return &get_game_context().object_draws
}

get_roofs_context :: proc() -> ^Roofs_Context {
	return &get_game_context().roofs
}

get_roof_tool_context :: proc() -> ^Roof_Tool_Context {
	return &get_game_context().roof_tool
}

init_game :: proc() -> bool {
	load_object_blueprints() or_return
	init_object_draws() or_return
	init_object_tool()
	init_roofs() or_return

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


	add_roof(
		 {
			type = .Half_Hip,
			start = {-0.5, -0.5},
			end = {0.5, 1.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	// add_roof(
	// 	 {
	// 		type = .Half_Hip,
	// 		start = {1.5, -0.5},
	// 		end = {0.5, 1.5},
	// 		offset = 3,
	// 		slope = 1.0,
	// 		light = {1, 1, 1, 1},
	// 	},
	// )

	add_roof(
		 {
			type = .Half_Hip,
			start = {-0.5, 4.5},
			end = {0.5, 2.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {1.5, 4.5},
			end = {0.5, 2.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Half_Hip,
			start = {-0.5, 5.5},
			end = {1.5, 6.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {-0.5, 7.5},
			end = {1.5, 6.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Half_Hip,
			start = {1.5, 8.5},
			end = {-0.5, 9.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {1.5, 10.5},
			end = {-0.5, 9.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)


	add_roof(
		 {
			type = .Half_Hip,
			start = {2.5, -0.5},
			end = {3.5, 2.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {4.5, -0.5},
			end = {3.5, 2.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Half_Hip,
			start = {2.5, 6.5},
			end = {3.5, 3.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {4.5, 6.5},
			end = {3.5, 3.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Half_Hip,
			start = {2.5, 7.5},
			end = {5.5, 8.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {2.5, 9.5},
			end = {5.5, 8.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Half_Hip,
			start = {5.5, 10.5},
			end = {2.5, 11.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {5.5, 12.5},
			end = {2.5, 11.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)


	add_roof(
		 {
			type = .Half_Hip,
			start = {6.5, -0.5},
			end = {8.5, 2.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {10.5, -0.5},
			end = {8.5, 2.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Half_Hip,
			start = {6.5, 6.5},
			end = {8.5, 3.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {10.5, 6.5},
			end = {8.5, 3.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Half_Hip,
			start = {6.5, 7.5},
			end = {9.5, 9.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {6.5, 11.5},
			end = {9.5, 9.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Half_Hip,
			start = {9.5, 12.5},
			end = {6.5, 14.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Hip,
			start = {9.5, 16.5},
			end = {6.5, 14.5},
			offset = 3,
			slope = 1.0,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Hip,
			start = {11.5, -0.5},
			end = {13.5, 1.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Hip,
			start = {11.5, 4.5},
			end = {13.5, 2.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Hip,
			start = {16.5, -0.5},
			end = {14.5, 1.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Hip,
			start = {16.5, 4.5},
			end = {14.5, 2.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Hip,
			start = {17.5, -0.5},
			end = {19.5, 2.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Hip,
			start = {17.5, 6.5},
			end = {19.5, 3.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Hip,
			start = {22.5, -0.5},
			end = {20.5, 2.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Hip,
			start = {22.5, 6.5},
			end = {20.5, 3.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)

	add_roof(
		 {
			type = .Hip,
			start = {23.5, -0.5},
			end = {26.5, 1.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Hip,
			start = {23.5, 4.5},
			end = {26.5, 2.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Hip,
			start = {30.5, -0.5},
			end = {27.5, 1.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Hip,
			start = {30.5, 4.5},
			end = {27.5, 2.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)


	add_roof(
		 {
			type = .Half_Gable,
			start = {31.4, -0.6},
			end = {34.6, 1.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Gable,
			start = {31.4, 3.6},
			end = {34.6, 1.5},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)

	set_wall(
		{32, 1, 0},
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
		{32, 1, 1},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Left_Side},
		},
	)

	set_wall(
		{32, 1, 2},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Right_Side},
		},
	)

	set_wall(
		{32, 1, 3},
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
		{35, 1, 0},
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
		{35, 1, 1},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Left_Side},
		},
	)

	set_wall(
		{35, 1, 2},
		.N_S,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Right_Side},
		},
	)

	set_wall(
		{35, 1, 3},
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

	add_roof(
		 {
			type = .Half_Gable,
			start = {31.4, 4.4},
			end = {33.5, 7.6},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)
	add_roof(
		 {
			type = .Half_Gable,
			start = {35.6, 4.4},
			end = {33.5, 7.6},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)

	set_wall(
		{32, 1, 5},
		.E_W,
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
		{33, 1, 5},
		.E_W,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Right_Side},
		},
	)

	set_wall(
		{34, 1, 5},
		.E_W,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Left_Side},
		},
	)

	set_wall(
		{35, 1, 5},
		.E_W,
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
		{32, 1, 8},
		.E_W,
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
		{33, 1, 8},
		.E_W,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Right_Side},
		},
	)

	set_wall(
		{34, 1, 8},
		.E_W,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 1,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Left_Side},
		},
	)

	set_wall(
		{35, 1, 8},
		.E_W,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 0,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Left_Side},
		},
	)

	add_roof(
		 {
			type = .Gable,
			start = {36.4, -0.6},
			end = {39.6, 3.6},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)

	set_wall(
		{37, 1, 0},
		.E_W,
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
		{38, 1, 0},
		.E_W,
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
		{39, 1, 0},
		.E_W,
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
		{37, 1, 4},
		.E_W,
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
		{38, 1, 4},
		.E_W,
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
		{39, 1, 4},
		.E_W,
		 {
			type = .Side,
			textures = {.Inside = .Brick, .Outside = .Brick},
			mask = .Full_Mask,
			state = .Up,
			height = 0,
			roof_slope = Wall_Roof_Slope{height = 1, type = .Left_Side},
		},
	)

	add_roof(
		 {
			type = .Gable,
			start = {36.4, 4.4},
			end = {40.6, 7.6},
			offset = 3,
			slope = 1,
			light = {1, 1, 1, 1},
		},
	)

	set_wall(
		{37, 1, 5},
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
		{37, 1, 6},
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
		{37, 1, 7},
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
		{41, 1, 5},
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
		{41, 1, 6},
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
		{41, 1, 7},
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

	// add_roof({type = .Half_Hip, start = {-0.5, -0.5}, end = {1.5, 0.5}, offset = 3, slope = 1.0})

	// add_roof({type = .Half_Hip, start = {9.5, 12}, end = {11, 22}, offset = 3, slope = 1})
	// add_roof({type = .Half_Hip, start = {8.5, 15.5}, end = {10.5, 18.5}, offset = 3, slope = 1})
	// add_roof({type = .Half_Hip, start = {31, 33}, end = {32, 34}})
	//
	// add_roof({type = .Hip, start = {32, 37}, end = {41, 41}}) // 10, 5
	// add_roof({type = .Hip, start = {26, 37}, end = {30, 47}}) // 5, 11
	// add_roof({type = .Half_Gable, start = {-0.5, 2.5}, end = {1.5, 7.5}}) // pyramid

	// add_roof({type = .Corner, start = {0, 7}, end = {1, 8}}) // corner
	// add_roof({start = {0, 10}, end = {1, 13}}) // pyramid

	return true
}

deinit_game :: proc() {
	deload_object_blueprints()
	deinit_object_draws()
	deinit_object_tool()
	deinit_roofs()
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
