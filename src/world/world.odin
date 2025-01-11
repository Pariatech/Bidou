package world

import "core:fmt"
import "core:math/linalg/glsl"
import gl "vendor:OpenGL"

import "../billboard"
import "../camera"
import "../game"
import "../renderer"
import "../tools/wall_tool"

house_x: i32 = 12
house_z: i32 = 12

world_previously_visible_chunks_start: glsl.ivec2
world_previously_visible_chunks_end: glsl.ivec2

update :: proc() {
	aabb := camera.get_aabb()
	world_previously_visible_chunks_start = camera.visible_chunks_start
	world_previously_visible_chunks_end = camera.visible_chunks_end
	camera.visible_chunks_start.x = max(aabb.x / game.CHUNK_WIDTH - 1, 0)
	camera.visible_chunks_start.y = max(aabb.y / game.CHUNK_DEPTH - 1, 0)
	camera.visible_chunks_end.x = min(
		(aabb.x + aabb.w) / game.CHUNK_WIDTH + 1,
		game.WORLD_CHUNK_WIDTH,
	)
	camera.visible_chunks_end.y = min(
		(aabb.y + aabb.h) / game.CHUNK_DEPTH + 1,
		game.WORLD_CHUNK_DEPTH,
	)
}

init :: proc() -> bool {
	game.tile_triangle_chunk_init()

	// furniture.add({1, 0, 1}, .Chair, .South)
	// furniture.add({2, 0, 1}, .Chair, .East)
	// furniture.add({2, 0, 2}, .Chair, .North)
	// furniture.add({1, 0, 2}, .Chair, .West)

	// The house
	add_house_floor_walls(0, .Royal_Blue, .Brick)
	add_house_floor_walls(1, .Dark_Blue, .Brick)
	add_house_floor_triangles(0, .Wood_Floor_008)
	add_house_floor_triangles(1, .Wood_Floor_008)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Counter",
			{1, 0, 1},
			.South,
			.Floor,
		) or_return,
	)
	game.add_object(
		game.make_object_from_blueprint(
			"Wood Counter",
			{2, 0, 1},
			.South,
			.Floor,
		) or_return,
	)
	game.add_object(
		game.make_object_from_blueprint(
			"Wood Counter",
			{3, 0, 1},
			.South,
			.Floor,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Plank Table",
			{5, 0, 1.5},
			.South,
			.Floor,
		) or_return,
	)
	game.add_object(
		game.make_object_from_blueprint(
			"Big Wood Table",
			{8.5, 0, 1.5},
			.South,
			.Floor,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Plank Table",
			{5.5, 0, 4},
			.East,
			.Floor,
		) or_return,
	)
	game.add_object(
		game.make_object_from_blueprint(
			"Big Wood Table",
			{8.5, 0, 4.5},
			.East,
			.Floor,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Plank Table",
			{5, 0, 7.5},
			.North,
			.Floor,
		) or_return,
	)
	game.add_object(
		game.make_object_from_blueprint(
			"Big Wood Table",
			{9.5, 0, 7.5},
			.North,
			.Floor,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Plank Table",
			{5.5, 0, 10},
			.West,
			.Floor,
		) or_return,
	)
	game.add_object(
		game.make_object_from_blueprint(
			"Big Wood Table",
			{9.5, 0, 11.5},
			.West,
			.Floor,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Old Computer",
			{5, 0, 1},
			.West,
			.Table,
		) or_return,
	)

	for x in 0 ..< game.WORLD_WIDTH {
		for z in 1 ..= 3 {
			game.tile_triangle_set_tile(
				{i32(x), 0, i32(z)},
				game.tile_triangle_tile(
					game.Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}

		game.tile_triangle_set_tile(
			{i32(x), 0, 4},
			game.tile_triangle_tile(
				game.Tile_Triangle {
					texture = .Asphalt_Horizontal_Line,
					mask_texture = .Full_Mask,
				},
			),
		)
		for z in 5 ..= 7 {
			game.tile_triangle_set_tile(
				{i32(x), 0, i32(z)},
				game.tile_triangle_tile(
					game.Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}
	}

	for x in 1 ..= 7 {
		game.tile_triangle_set_tile(
			{i32(x), 0, 4},
			game.tile_triangle_tile(
				game.Tile_Triangle {
					texture = .Asphalt,
					mask_texture = .Full_Mask,
				},
			),
		)
	}

	for z in 8 ..< game.WORLD_WIDTH {
		for x in 1 ..= 3 {
			game.tile_triangle_set_tile(
				{i32(x), 0, i32(z)},
				game.tile_triangle_tile(
					game.Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}

		game.tile_triangle_set_tile(
			{4, 0, i32(z)},
			game.tile_triangle_tile(
				game.Tile_Triangle {
					texture = .Asphalt_Vertical_Line,
					mask_texture = .Full_Mask,
				},
			),
		)
		for x in 5 ..= 7 {
			game.tile_triangle_set_tile(
				{i32(x), 0, i32(z)},
				game.tile_triangle_tile(
					game.Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}
	}

	for x in 8 ..< game.WORLD_WIDTH {
		game.tile_triangle_set_tile(
			{i32(x), 0, 8},
			game.tile_triangle_tile(
				game.Tile_Triangle {
					texture = .Sidewalk,
					mask_texture = .Full_Mask,
				},
			),
		)
	}

	for z in 9 ..< game.WORLD_WIDTH {
		game.tile_triangle_set_tile(
			{8, 0, i32(z)},
			game.tile_triangle_tile(
				game.Tile_Triangle {
					texture = .Sidewalk,
					mask_texture = .Full_Mask,
				},
			),
		)
	}

	return true
}

add_house_floor_triangles :: proc(floor: i32, texture: game.Tile_Triangle_Texture) {
	tri := game.Tile_Triangle {
		texture      = texture,
		mask_texture = .Full_Mask,
	}

	for x in 0 ..< 12 {
		for z in 0 ..< 11 {
			game.tile_triangle_set_tile(
				{house_x + i32(x), floor, house_z + i32(z)},
				game.tile_triangle_tile(tri),
			)
		}
	}
}

add_house_floor_walls :: proc(
	floor: i32,
	inside_texture: game.Wall_Texture,
	outside_texture: game.Wall_Texture,
) -> bool {
	// The house's front wall
	game.set_north_south_wall(
		{house_x, floor, house_z},
		game.make_wall(
			type = .Extended_Right,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		),
	)
	for i in 0 ..< 9 {
		game.set_north_south_wall(
			{house_x, floor, house_z + i32(i) + 1},
			game.make_wall(
				type = .Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
			),
		)
	}
	game.set_north_south_wall(
		{house_x, floor, house_z + 10},
		game.make_wall(
			type = .Extended_Left,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		),
	)

	for i in 0 ..< 3 {
		game.add_object(
			game.make_object_from_blueprint(
				"Wood Window",
				 {
					f32(house_x),
					f32(floor * game.WALL_HEIGHT),
					f32(house_z + 1 + i32(i)),
				},
				.West,
				.Wall,
			) or_return,
		)
	}

	// door?
	if floor > 0 {
		game.add_object(
			game.make_object_from_blueprint(
				"Wood Window",
				 {
					f32(house_x),
					f32(floor * game.WALL_HEIGHT),
					f32(house_z + 5),
				},
				.West,
				.Wall,
			) or_return,
		)
	} else {
		game.add_object(
			game.make_object_from_blueprint(
				"Wood Door",
				 {
					f32(house_x),
					f32(floor * game.WALL_HEIGHT),
					f32(house_z + 5),
				},
				.West,
				.Wall,
			) or_return,
		)
	}

	for i in 0 ..< 3 {
		game.add_object(
			game.make_object_from_blueprint(
				"Wood Window",
				 {
					f32(house_x),
					f32(floor * game.WALL_HEIGHT),
					f32(house_z + 7 + i32(i)),
				},
				.West,
				.Wall,
			) or_return,
		)
	}

	// The house's right side wall
	game.set_east_west_wall(
		{house_x, floor, house_z},
		game.make_wall(
			type = .Extended_Left,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		),
	)

	for i in 0 ..< 10 {
		game.set_east_west_wall(
			{house_x + i32(i) + 1, floor, house_z},
			game.make_wall(
				type = .Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
			),
		)
	}

	game.set_east_west_wall(
		{house_x + 11, floor, house_z},
		game.make_wall(
			type = .Extended_Right,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		),
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Window",
			 {
				f32(house_x + 2),
				f32(floor * game.WALL_HEIGHT),
				f32(house_z),
			},
			.South,
			.Wall,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Window",
			 {
				f32(house_x + 4),
				f32(floor * game.WALL_HEIGHT),
				f32(house_z),
			},
			.South,
			.Wall,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Window",
			 {
				f32(house_x + 7),
				f32(floor * game.WALL_HEIGHT),
				f32(house_z),
			},
			.South,
			.Wall,
		) or_return,
	)

	if floor == 0 {
		game.add_object(
			game.make_object_from_blueprint(
				"Wood Door",
				 {
					f32(house_x + 9),
					f32(floor * game.WALL_HEIGHT),
					f32(house_z),
				},
				.South,
				.Wall,
			) or_return,
		)
	} else {
		game.add_object(
			game.make_object_from_blueprint(
				"Wood Window",
				 {
					f32(house_x + 9),
					f32(floor * game.WALL_HEIGHT),
					f32(house_z),
				},
				.South,
				.Wall,
			) or_return,
		)
	}

	// The house's left side wall
	game.set_east_west_wall(
		{house_x, floor, house_z + 11},
		game.make_wall(
			type = .Extended_Left,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		),
	)

	for i in 0 ..< 10 {
		game.set_east_west_wall(
			{house_x + i32(i) + 1, floor, house_z + 11},
			game.make_wall(
				type = .Side,
				textures =  {
					.Inside = outside_texture,
					.Outside = inside_texture,
				},
			),
		)
	}

	game.set_east_west_wall(
		{house_x + 11, floor, house_z + 11},
		game.make_wall(
			type = .Extended_Right,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		),
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Window",
			 {
				f32(house_x + 2),
				f32(floor * game.WALL_HEIGHT),
				f32(house_z + 11),
			},
			.South,
			.Wall,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Window",
			 {
				f32(house_x + 4),
				f32(floor * game.WALL_HEIGHT),
				f32(house_z + 11),
			},
			.South,
			.Wall,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Window",
			 {
				f32(house_x + 7),
				f32(floor * game.WALL_HEIGHT),
				f32(house_z + 11),
			},
			.South,
			.Wall,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Window",
			 {
				f32(house_x + 9),
				f32(floor * game.WALL_HEIGHT),
				f32(house_z + 11),
			},
			.South,
			.Wall,
		) or_return,
	)

	// The house's back wall

	game.set_north_south_wall(
		{house_x + 12, floor, house_z},
		game.make_wall(
			type = .Extended_Right,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		),
	)

	for i in 0 ..< 9 {
		game.set_north_south_wall(
			{house_x + 12, floor, house_z + i32(i) + 1},
			game.make_wall(
				type = .Side,
				textures =  {
					.Inside = outside_texture,
					.Outside = inside_texture,
				},
			),
		)
	}

	game.set_north_south_wall(
		{house_x + 12, floor, house_z + 10},
		game.make_wall(
			type = .Extended_Left,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		),
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Window",
			 {
				f32(house_x + 11),
				f32(floor * game.WALL_HEIGHT),
				f32(house_z + 2),
			},
			.East,
			.Wall,
		) or_return,
	)

	game.add_object(
		game.make_object_from_blueprint(
			"Wood Window",
			 {
				f32(house_x + 11),
				f32(floor * game.WALL_HEIGHT),
				f32(house_z + 8),
			},
			.East,
			.Wall,
		) or_return,
	)

	return true
}

draw :: proc() {
	renderer.uniform_object.view = camera.view
	renderer.uniform_object.proj = camera.proj


	for flr in 0 ..= game.get_floor_context().floor {
		gl.BindBuffer(gl.UNIFORM_BUFFER, renderer.ubo)

		ubo_index := gl.GetUniformBlockIndex(
			renderer.shader_program,
			"UniformBufferObject",
		)
		gl.UniformBlockBinding(renderer.shader_program, ubo_index, 2)

		// ubo_index := gl.GetUniformBlockIndex(renderer.shader_program, "ubo")
		gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, renderer.ubo)
		gl.BufferSubData(
			gl.UNIFORM_BUFFER,
			0,
			size_of(renderer.Uniform_Object),
			&renderer.uniform_object,
		)

		gl.UseProgram(renderer.shader_program)
		game.tile_triangle_draw_tiles(flr)
		game.draw_walls(flr)
		billboard.draw_billboards(flr)

		game.draw_game(flr)
		// object.draw(flr)
	}
}

update_after_rotation :: proc(rotated: camera.Rotated) {
	wall_tool.move_cursor()
	billboard.update_after_rotation()
	switch rotated {
	case .Counter_Clockwise:
		billboard.update_after_counter_clockwise_rotation()
	case .Clockwise:
		billboard.update_after_clockwise_rotation()
	}
	game.update_game_on_camera_rotation()
}
