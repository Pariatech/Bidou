package world

import "core:fmt"
import "core:math/linalg/glsl"
import gl "vendor:OpenGL"

import "../billboard"
import "../camera"
import "../constants"
import "../floor"
import "../furniture"
import "../game"
import "../renderer"
import "../tile"
import "../tools/wall_tool"
import "../wall"

house_x: i32 = 12
house_z: i32 = 12

world_previously_visible_chunks_start: glsl.ivec2
world_previously_visible_chunks_end: glsl.ivec2

update :: proc() {
	aabb := camera.get_aabb()
	world_previously_visible_chunks_start = camera.visible_chunks_start
	world_previously_visible_chunks_end = camera.visible_chunks_end
	camera.visible_chunks_start.x = max(aabb.x / constants.CHUNK_WIDTH - 1, 0)
	camera.visible_chunks_start.y = max(aabb.y / constants.CHUNK_DEPTH - 1, 0)
	camera.visible_chunks_end.x = min(
		(aabb.x + aabb.w) / constants.CHUNK_WIDTH + 1,
		constants.WORLD_CHUNK_WIDTH,
	)
	camera.visible_chunks_end.y = min(
		(aabb.y + aabb.h) / constants.CHUNK_DEPTH + 1,
		constants.WORLD_CHUNK_DEPTH,
	)
}

init :: proc(using ctx: ^game.Game_Context) {
	tile.chunk_init()

	// furniture.add({1, 0, 1}, .Chair, .South)
	// furniture.add({2, 0, 1}, .Chair, .East)
	// furniture.add({2, 0, 2}, .Chair, .North)
	// furniture.add({1, 0, 2}, .Chair, .West)

	// The house
	add_house_floor_walls(ctx, 0, .Royal_Blue, .Brick)
	add_house_floor_walls(ctx, 1, .Dark_Blue, .Brick)
	add_house_floor_triangles(2, .Wood_Floor_008)

	for x in 0 ..< constants.WORLD_WIDTH {
		for z in 1 ..= 3 {
			tile.set_tile(
				{i32(x), 0, i32(z)},
				tile.tile(
					tile.Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}

		tile.set_tile(
			{i32(x), 0, 4},
			tile.tile(
				tile.Tile_Triangle {
					texture = .Asphalt_Horizontal_Line,
					mask_texture = .Full_Mask,
				},
			),
		)
		for z in 5 ..= 7 {
			tile.set_tile(
				{i32(x), 0, i32(z)},
				tile.tile(
					tile.Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}
	}

	for x in 1 ..= 7 {
		tile.set_tile(
			{i32(x), 0, 4},
			tile.tile(
				tile.Tile_Triangle {
					texture = .Asphalt,
					mask_texture = .Full_Mask,
				},
			),
		)
	}

	for z in 8 ..< constants.WORLD_WIDTH {
		for x in 1 ..= 3 {
			tile.set_tile(
				{i32(x), 0, i32(z)},
				tile.tile(
					tile.Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}

		tile.set_tile(
			{4, 0, i32(z)},
			tile.tile(
				tile.Tile_Triangle {
					texture = .Asphalt_Vertical_Line,
					mask_texture = .Full_Mask,
				},
			),
		)
		for x in 5 ..= 7 {
			tile.set_tile(
				{i32(x), 0, i32(z)},
				tile.tile(
					tile.Tile_Triangle {
						texture = .Asphalt,
						mask_texture = .Full_Mask,
					},
				),
			)
		}
	}

	for x in 8 ..< constants.WORLD_WIDTH {
		tile.set_tile(
			{i32(x), 0, 8},
			tile.tile(
				tile.Tile_Triangle {
					texture = .Sidewalk,
					mask_texture = .Full_Mask,
				},
			),
		)
	}

	for z in 9 ..< constants.WORLD_WIDTH {
		tile.set_tile(
			{8, 0, i32(z)},
			tile.tile(
				tile.Tile_Triangle {
					texture = .Sidewalk,
					mask_texture = .Full_Mask,
				},
			),
		)
	}
}

add_house_floor_triangles :: proc(floor: i32, texture: tile.Texture) {
	tri := tile.Tile_Triangle {
		texture      = texture,
		mask_texture = .Full_Mask,
	}

	tile.set_tile_triangle({house_x + 4, floor, house_z}, .West, tri)
	tile.set_tile_triangle({house_x + 4, floor, house_z}, .North, tri)

	tile.set_tile_triangle({house_x, floor, house_z + 4}, .South, tri)
	tile.set_tile_triangle({house_x, floor, house_z + 4}, .East, tri)

	tile.set_tile_triangle({house_x, floor, house_z + 6}, .North, tri)
	tile.set_tile_triangle({house_x, floor, house_z + 6}, .East, tri)

	tile.set_tile_triangle({house_x + 4, floor, house_z + 10}, .South, tri)
	tile.set_tile_triangle({house_x + 4, floor, house_z + 10}, .West, tri)

	for x in 0 ..< 4 {
		for z in 0 ..< 4 {
			tile.set_tile(
				{house_x + i32(x), floor, house_z + i32(z)},
				tile.tile(tri),
			)
		}
	}

	for x in 0 ..< 3 {
		for z in 0 ..< 3 {
			tile.set_tile(
				{house_x + i32(x) + 1, floor, house_z + i32(z) + 4},
				tile.tile(tri),
			)
		}
	}

	for x in 0 ..< 4 {
		for z in 0 ..< 4 {
			tile.set_tile(
				{house_x + i32(x), floor, house_z + i32(z) + 7},
				tile.tile(tri),
			)
		}
	}

	for z in 0 ..< 9 {
		tile.set_tile(
			{house_x + 4, floor, house_z + i32(z) + 1},
			tile.tile(tri),
		)
	}
}

add_house_floor_walls :: proc(
	using ctx: ^game.Game_Context,
	floor: i32,
	inside_texture: wall.Wall_Texture,
	outside_texture: wall.Wall_Texture,
) {
	// The house's front wall
	wall.set_north_south_wall(
		{house_x, floor, house_z},
		 {
			type = .Extended_Right,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)
	for i in 0 ..< 2 {
		wall.set_north_south_wall(
			{house_x, floor, house_z + i32(i) + 1},
			 {
				type = .Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
			},
		)
	}
	wall.set_north_south_wall(
		{house_x, floor, house_z + 3},
		 {
			type = .Extended_Left,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	wall.set_south_west_north_east_wall(
		{house_x, floor, house_z + 4},
		 {
			type = .Side,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	// door?
	mask := wall.Wall_Mask_Texture.Window_Opening
	if floor == 0 do mask = .Door_Opening
	wall.set_north_south_wall(
		{house_x + 1, floor, house_z + 5},
		 {
			type = .Extended,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
			mask = mask,
		},
	)
	if floor > 0 {
		game.add_object(
			ctx,
			 {
				f32(house_x + 1),
				f32(floor * constants.WALL_HEIGHT),
				f32(house_z + 5),
			},
			.Wood_Window,
			.West,
			.Wall,
		)
	} else {
		billboard.billboard_1x1_set(
			 {
				type = .Door,
				pos = {f32(house_x + 1), f32(floor), f32(house_z + 5)},
			},
			 {
				light = {1, 1, 1},
				texture = .Door_Wood_SE,
				depth_map = .Door_Wood_SE,
			},
		)
	}

	wall.set_north_west_south_east_wall(
		{house_x, floor, house_z + 6},
		 {
			type = .Side,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	wall.set_north_south_wall(
		{house_x, floor, house_z + 7},
		 {
			type = .Extended_Right,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	for i in 0 ..< 2 {
		wall.set_north_south_wall(
			{house_x, floor, house_z + i32(i) + 8},
			 {
				type = .Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
				mask = .Window_Opening,
			},
		)

		game.add_object(
			ctx,
			 {
				f32(house_x),
				f32(floor * constants.WALL_HEIGHT),
				f32(house_z + i32(i) + 8),
			},
			.Wood_Window,
			.West,
			.Wall,
		)
	}

	wall.set_north_south_wall(
		{house_x, floor, house_z + 10},
		 {
			type = .Extended_Left,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	// The house's right side wall
	wall.set_east_west_wall(
		{house_x, floor, house_z},
		 {
			type = .Extended_Left,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	for i in 0 ..< 2 {
		wall.set_east_west_wall(
			{house_x + i32(i) + 1, floor, house_z},
			 {
				type = .Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
				mask = .Window_Opening,
			},
		)

		game.add_object(
			ctx,
			 {
				f32(house_x + i32(i) + 1),
				f32(floor * constants.WALL_HEIGHT),
				f32(house_z),
			},
			.Wood_Window,
			.South,
			.Wall,
		)
	}

	wall.set_east_west_wall(
		{house_x + 3, floor, house_z},
		 {
			type = .Extended_Right,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	// The house's left side wall
	wall.set_east_west_wall(
		{house_x, floor, house_z + 11},
		 {
			type = .Extended_Left,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	for i in 0 ..< 2 {
		wall.set_east_west_wall(
			{house_x + i32(i) + 1, floor, house_z + 11},
			 {
				type = .Side,
				textures =  {
					.Inside = outside_texture,
					.Outside = inside_texture,
				},
				mask = .Window_Opening,
			},
		)

		game.add_object(
			ctx,
			 {
				f32(house_x + i32(i) + 1),
				f32(floor * constants.WALL_HEIGHT),
				f32(house_z + 11),
			},
			.Wood_Window,
			.South,
			.Wall,
		)
	}
	wall.set_east_west_wall(
		{house_x + 3, floor, house_z + 11},
		 {
			type = .Extended_Right,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	// The house's back wall
	wall.set_south_west_north_east_wall(
		{house_x + 4, floor, house_z},
		 {
			type = .Side,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	wall.set_north_south_wall(
		{house_x + 5, floor, house_z + 1},
		 {
			type = .Extended_Right,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	for i in 0 ..< 7 {
		wall.set_north_south_wall(
			{house_x + 5, floor, house_z + i32(i) + 2},
			 {
				type = .Side,
				textures =  {
					.Inside = outside_texture,
					.Outside = inside_texture,
				},
			},
		)
	}

	wall.set_north_south_wall(
		{house_x + 5, floor, house_z + 9},
		 {
			type = .Extended_Left,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	wall.set_north_west_south_east_wall(
		{house_x + 4, floor, house_z + 10},
		 {
			type = .Side,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)
}

draw :: proc(game: ^game.Game_Context) {
	renderer.uniform_object.view = camera.view
	renderer.uniform_object.proj = camera.proj

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


	for flr in 0 ..= floor.floor {
		gl.UseProgram(renderer.shader_program)
		tile.draw_tiles(flr)
		wall.draw_walls(game, flr)
		billboard.draw_billboards(flr)
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
	wall.update_after_rotation()
}
