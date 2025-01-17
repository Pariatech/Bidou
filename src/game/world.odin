package game

import "core:fmt"
import "core:math/linalg/glsl"
import gl "vendor:OpenGL"

HOUSE_X :: 12
HOUSE_Z :: 12

world_update :: proc() {
	aabb := camera_get_aabb()
	camera().visible_chunks_start.x = max(aabb.x / CHUNK_WIDTH - 1, 0)
	camera().visible_chunks_start.y = max(aabb.y / CHUNK_DEPTH - 1, 0)
	camera().visible_chunks_end.x = min(
		(aabb.x + aabb.w) / CHUNK_WIDTH + 1,
		WORLD_CHUNK_WIDTH,
	)
	camera().visible_chunks_end.y = min(
		(aabb.y + aabb.h) / CHUNK_DEPTH + 1,
		WORLD_CHUNK_DEPTH,
	)
}

world_init :: proc() -> bool {
	tile_triangle_chunk_init()

	// furniture.add({1, 0, 1}, .Chair, .South)
	// furniture.add({2, 0, 1}, .Chair, .East)
	// furniture.add({2, 0, 2}, .Chair, .North)
	// furniture.add({1, 0, 2}, .Chair, .West)

	// The house
	world_add_house_floor_walls(0, .Royal_Blue, .Brick)
	world_add_house_floor_walls(1, .Dark_Blue, .Brick)
	world_add_house_floor_triangles(0, .Wood_Floor_008)
	world_add_house_floor_triangles(1, .Wood_Floor_008)

	add_object(
		make_object_from_blueprint(
			"Wood Counter",
			{1, 0, 1},
			.South,
			.Floor,
		) or_return,
	)
	add_object(
		make_object_from_blueprint(
			"Wood Counter",
			{2, 0, 1},
			.South,
			.Floor,
		) or_return,
	)
	add_object(
		make_object_from_blueprint(
			"Wood Counter",
			{3, 0, 1},
			.South,
			.Floor,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Plank Table",
			{5, 0, 1.5},
			.South,
			.Floor,
		) or_return,
	)
	add_object(
		make_object_from_blueprint(
			"Big Wood Table",
			{8.5, 0, 1.5},
			.South,
			.Floor,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Plank Table",
			{5.5, 0, 4},
			.East,
			.Floor,
		) or_return,
	)
	add_object(
		make_object_from_blueprint(
			"Big Wood Table",
			{8.5, 0, 4.5},
			.East,
			.Floor,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Plank Table",
			{5, 0, 7.5},
			.North,
			.Floor,
		) or_return,
	)
	add_object(
		make_object_from_blueprint(
			"Big Wood Table",
			{9.5, 0, 7.5},
			.North,
			.Floor,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Plank Table",
			{5.5, 0, 10},
			.West,
			.Floor,
		) or_return,
	)
	add_object(
		make_object_from_blueprint(
			"Big Wood Table",
			{9.5, 0, 11.5},
			.West,
			.Floor,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Old Computer",
			{5, 0, 1},
			.West,
			.Table,
		) or_return,
	)

	for x in 0 ..< WORLD_WIDTH {
		for z in 1 ..= 3 {
			tile_triangle_set_tile(
				{i32(x), 0, i32(z)},
				tile_triangle_tile(
					Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}

		tile_triangle_set_tile(
			{i32(x), 0, 4},
			tile_triangle_tile(
				Tile_Triangle {
					texture = .Asphalt_Horizontal_Line,
					mask_texture = .Full_Mask,
				},
			),
		)
		for z in 5 ..= 7 {
			tile_triangle_set_tile(
				{i32(x), 0, i32(z)},
				tile_triangle_tile(
					Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}
	}

	for x in 1 ..= 7 {
		tile_triangle_set_tile(
			{i32(x), 0, 4},
			tile_triangle_tile(
				Tile_Triangle{texture = .Asphalt, mask_texture = .Full_Mask},
			),
		)
	}

	for z in 8 ..< WORLD_WIDTH {
		for x in 1 ..= 3 {
			tile_triangle_set_tile(
				{i32(x), 0, i32(z)},
				tile_triangle_tile(
					Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}

		tile_triangle_set_tile(
			{4, 0, i32(z)},
			tile_triangle_tile(
				Tile_Triangle {
					texture = .Asphalt_Vertical_Line,
					mask_texture = .Full_Mask,
				},
			),
		)
		for x in 5 ..= 7 {
			tile_triangle_set_tile(
				{i32(x), 0, i32(z)},
				tile_triangle_tile(
					Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}
	}

	for x in 8 ..< WORLD_WIDTH {
		tile_triangle_set_tile(
			{i32(x), 0, 8},
			tile_triangle_tile(
				Tile_Triangle{texture = .Sidewalk, mask_texture = .Full_Mask},
			),
		)
	}

	for z in 9 ..< WORLD_WIDTH {
		tile_triangle_set_tile(
			{8, 0, i32(z)},
			tile_triangle_tile(
				Tile_Triangle{texture = .Sidewalk, mask_texture = .Full_Mask},
			),
		)
	}

	return true
}

world_add_house_floor_triangles :: proc(
	floor: i32,
	texture: Tile_Triangle_Texture,
) {
	tri := Tile_Triangle {
		texture      = texture,
		mask_texture = .Full_Mask,
	}

	for x in 0 ..< 12 {
		for z in 0 ..< 11 {
			tile_triangle_set_tile(
				{HOUSE_X + i32(x), floor, HOUSE_Z + i32(z)},
				tile_triangle_tile(tri),
			)
		}
	}
}

world_add_house_floor_walls :: proc(
	floor: i32,
	inside_texture: Wall_Texture,
	outside_texture: Wall_Texture,
) -> bool {
	// The house's front wall
	set_north_south_wall(
		{HOUSE_X, floor, HOUSE_Z},
		make_wall(
			type = .Extended_Right,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		),
	)
	for i in 0 ..< 9 {
		set_north_south_wall(
			{HOUSE_X, floor, HOUSE_Z + i32(i) + 1},
			make_wall(
				type = .Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
			),
		)
	}
	set_north_south_wall(
		{HOUSE_X, floor, HOUSE_Z + 10},
		make_wall(
			type = .Extended_Left,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		),
	)

	for i in 0 ..< 3 {
		add_object(
			make_object_from_blueprint(
				"Wood Window",
				 {
					f32(HOUSE_X),
					f32(floor * WALL_HEIGHT),
					f32(HOUSE_Z + 1 + i32(i)),
				},
				.West,
				.Wall,
			) or_return,
		)
	}

	// door?
	if floor > 0 {
		add_object(
			make_object_from_blueprint(
				"Wood Window",
				{f32(HOUSE_X), f32(floor * WALL_HEIGHT), f32(HOUSE_Z + 5)},
				.West,
				.Wall,
			) or_return,
		)
	} else {
		add_object(
			make_object_from_blueprint(
				"Wood Door",
				{f32(HOUSE_X), f32(floor * WALL_HEIGHT), f32(HOUSE_Z + 5)},
				.West,
				.Wall,
			) or_return,
		)
	}

	for i in 0 ..< 3 {
		add_object(
			make_object_from_blueprint(
				"Wood Window",
				 {
					f32(HOUSE_X),
					f32(floor * WALL_HEIGHT),
					f32(HOUSE_Z + 7 + i32(i)),
				},
				.West,
				.Wall,
			) or_return,
		)
	}

	// The house's right side wall
	set_east_west_wall(
		{HOUSE_X, floor, HOUSE_Z},
		make_wall(
			type = .Extended_Left,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		),
	)

	for i in 0 ..< 10 {
		set_east_west_wall(
			{HOUSE_X + i32(i) + 1, floor, HOUSE_Z},
			make_wall(
				type = .Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
			),
		)
	}

	set_east_west_wall(
		{HOUSE_X + 11, floor, HOUSE_Z},
		make_wall(
			type = .Extended_Right,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		),
	)

	add_object(
		make_object_from_blueprint(
			"Wood Window",
			{f32(HOUSE_X + 2), f32(floor * WALL_HEIGHT), f32(HOUSE_Z)},
			.South,
			.Wall,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Wood Window",
			{f32(HOUSE_X + 4), f32(floor * WALL_HEIGHT), f32(HOUSE_Z)},
			.South,
			.Wall,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Wood Window",
			{f32(HOUSE_X + 7), f32(floor * WALL_HEIGHT), f32(HOUSE_Z)},
			.South,
			.Wall,
		) or_return,
	)

	if floor == 0 {
		add_object(
			make_object_from_blueprint(
				"Wood Door",
				{f32(HOUSE_X + 9), f32(floor * WALL_HEIGHT), f32(HOUSE_Z)},
				.South,
				.Wall,
			) or_return,
		)
	} else {
		add_object(
			make_object_from_blueprint(
				"Wood Window",
				{f32(HOUSE_X + 9), f32(floor * WALL_HEIGHT), f32(HOUSE_Z)},
				.South,
				.Wall,
			) or_return,
		)
	}

	// The house's left side wall
	set_east_west_wall(
		{HOUSE_X, floor, HOUSE_Z + 11},
		make_wall(
			type = .Extended_Left,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		),
	)

	for i in 0 ..< 10 {
		set_east_west_wall(
			{HOUSE_X + i32(i) + 1, floor, HOUSE_Z + 11},
			make_wall(
				type = .Side,
				textures =  {
					.Inside = outside_texture,
					.Outside = inside_texture,
				},
			),
		)
	}

	set_east_west_wall(
		{HOUSE_X + 11, floor, HOUSE_Z + 11},
		make_wall(
			type = .Extended_Right,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		),
	)

	add_object(
		make_object_from_blueprint(
			"Wood Window",
			{f32(HOUSE_X + 2), f32(floor * WALL_HEIGHT), f32(HOUSE_Z + 11)},
			.South,
			.Wall,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Wood Window",
			{f32(HOUSE_X + 4), f32(floor * WALL_HEIGHT), f32(HOUSE_Z + 11)},
			.South,
			.Wall,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Wood Window",
			{f32(HOUSE_X + 7), f32(floor * WALL_HEIGHT), f32(HOUSE_Z + 11)},
			.South,
			.Wall,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Wood Window",
			{f32(HOUSE_X + 9), f32(floor * WALL_HEIGHT), f32(HOUSE_Z + 11)},
			.South,
			.Wall,
		) or_return,
	)

	// The house's back wall

	set_north_south_wall(
		{HOUSE_X + 12, floor, HOUSE_Z},
		make_wall(
			type = .Extended_Right,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		),
	)

	for i in 0 ..< 9 {
		set_north_south_wall(
			{HOUSE_X + 12, floor, HOUSE_Z + i32(i) + 1},
			make_wall(
				type = .Side,
				textures =  {
					.Inside = outside_texture,
					.Outside = inside_texture,
				},
			),
		)
	}

	set_north_south_wall(
		{HOUSE_X + 12, floor, HOUSE_Z + 10},
		make_wall(
			type = .Extended_Left,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		),
	)

	add_object(
		make_object_from_blueprint(
			"Wood Window",
			{f32(HOUSE_X + 11), f32(floor * WALL_HEIGHT), f32(HOUSE_Z + 2)},
			.East,
			.Wall,
		) or_return,
	)

	add_object(
		make_object_from_blueprint(
			"Wood Window",
			{f32(HOUSE_X + 11), f32(floor * WALL_HEIGHT), f32(HOUSE_Z + 8)},
			.East,
			.Wall,
		) or_return,
	)

	return true
}

world_draw :: proc() {
	renderer().uniform_object.view = camera().view
	renderer().uniform_object.proj = camera().proj


	for flr in 0 ..= get_floor_context().floor {
		gl.BindBuffer(gl.UNIFORM_BUFFER, renderer().ubo)

		ubo_index := gl.GetUniformBlockIndex(
			renderer().shader_program,
			"UniformBufferObject",
		)
		gl.UniformBlockBinding(renderer().shader_program, ubo_index, 2)

		// ubo_index := gl.GetUniformBlockIndex(renderer.shader_program, "ubo")
		gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, renderer().ubo)
		gl.BufferSubData(
			gl.UNIFORM_BUFFER,
			0,
			size_of(Renderer_Uniform_Object),
			&renderer().uniform_object,
		)

		gl.UseProgram(renderer().shader_program)
		tile_triangle_draw_tiles(flr)
		draw_walls(flr)

		draw_game(flr)
		// object.draw(flr)
	}
}

world_update_after_rotation :: proc(rotated: Camera_Rotated) {
	update_game_on_camera_rotation()
}
