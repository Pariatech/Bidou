package main

import "core:fmt"
import "core:math/linalg/glsl"
import gl "vendor:OpenGL"

WORLD_WIDTH :: 1024
WORLD_HEIGHT :: 4
WORLD_DEPTH :: 1024
WORLD_CHUNK_WIDTH :: WORLD_WIDTH / CHUNK_WIDTH
WORLD_CHUNK_DEPTH :: WORLD_DEPTH / CHUNK_DEPTH

SUN_POWER :: 1.5

sun := glsl.vec3{1, -3, 1}

house_x: i32 = 12
house_z: i32 = 12

world_chunks: [WORLD_CHUNK_WIDTH][WORLD_CHUNK_DEPTH]Chunk

world_tiles_dirty: bool
world_previously_visible_chunks_start: glsl.ivec2
world_previously_visible_chunks_end: glsl.ivec2
world_visible_chunks_start: glsl.ivec2
world_visible_chunks_end: glsl.ivec2

world_get_chunk :: proc(pos: glsl.ivec3) -> ^Chunk {
	return &world_chunks[pos.x / CHUNK_WIDTH][pos.z / CHUNK_DEPTH]
}

world_set_tile :: proc(
	pos: glsl.ivec3,
	tile: [Tile_Triangle_Side]Maybe(Tile_Triangle),
) {
	chunk_set_tile(world_get_chunk(pos), pos, tile)
}

world_set_tile_mask_texture :: proc(pos: glsl.ivec3, mask_texture: Mask) {
	chunk_set_tile_mask_texture(world_get_chunk(pos), pos, mask_texture)
}

world_set_tile_triangle :: proc(
	pos: glsl.ivec3,
	side: Tile_Triangle_Side,
	tile_triangle: Maybe(Tile_Triangle),
) {
	chunk_set_tile_triangle(world_get_chunk(pos), pos, side, tile_triangle)
}

world_iterate_all_chunks :: proc() -> Chunk_Iterator {
	return {{0, 0}, {0, 0}, {WORLD_CHUNK_WIDTH, WORLD_CHUNK_DEPTH}}
}

world_iterate_visible_chunks :: proc() -> Chunk_Iterator {
	return(
		 {
			world_visible_chunks_start,
			world_visible_chunks_start,
			world_visible_chunks_end,
		} \
	)
}

world_iterate_visible_ground_tile_triangles :: proc(
) -> Chunk_Tile_Triangle_Iterator {
	return chunk_iterate_all_ground_tile_triangle(
		world_iterate_visible_chunks(),
	)
}

world_iterate_visible_tile_triangles :: proc(
) -> Chunk_Tile_Triangle_Iterator {
	return chunk_iterate_all_tile_triangle(world_iterate_visible_chunks())
}

world_draw_tiles :: proc() {
	it := world_iterate_visible_tile_triangles()
	for tile_triangle, index in chunk_tile_triangle_iterator_next(&it) {
		side := index.side
		pos := glsl.vec2{f32(index.pos.x), f32(index.pos.z)}

		x := int(index.pos.x)
		z := int(index.pos.z)
		lights := get_terrain_tile_triangle_lights(side, x, z, 1)

		heights := get_terrain_tile_triangle_heights(side, x, z, 1)

		for i in 0 ..< 3 {
			heights[i] += f32(index.pos.y * WALL_HEIGHT)
		}

		draw_tile_triangle(tile_triangle^, side, lights, heights, pos, 1)
	}
}

world_update :: proc() {
	aabb := get_camera_aabb()
	world_previously_visible_chunks_start = world_visible_chunks_start
	world_previously_visible_chunks_end = world_visible_chunks_end
	world_visible_chunks_start.x = max(aabb.x / CHUNK_WIDTH - 1, 0)
	world_visible_chunks_start.y = max(aabb.y / CHUNK_DEPTH - 1, 0)
	world_visible_chunks_end.x = min(
		(aabb.x + aabb.w) / CHUNK_WIDTH + 1,
		WORLD_CHUNK_WIDTH,
	)
	world_visible_chunks_end.y = min(
		(aabb.y + aabb.h) / CHUNK_DEPTH + 1,
		WORLD_CHUNK_DEPTH,
	)
    world_tiles_dirty = false
}

init_world :: proc() {
	for x in 0 ..< WORLD_CHUNK_WIDTH {
		for z in 0 ..< WORLD_CHUNK_DEPTH {
			chunk_init(&world_chunks[x][z])
		}
	}

	// The house
	add_house_floor_walls(0, .Varg, .Varg)
	add_house_floor_walls(1, .Nyana, .Nyana)
	add_house_floor_triangles(2, .Wood)

	for x in 0 ..< WORLD_WIDTH {
		for z in 1 ..= 3 {
			world_set_tile(
				{i32(x), 0, i32(z)},
				chunk_tile({texture = .Asphalt, mask_texture = .Full_Mask}),
			)
		}

		world_set_tile(
			{i32(x), 0, 4},
			chunk_tile(
				 {
					texture = .Asphalt_Horizontal_Line,
					mask_texture = .Full_Mask,
				},
			),
		)
		for z in 5 ..= 7 {
			world_set_tile(
				{i32(x), 0, i32(z)},
				chunk_tile({texture = .Asphalt, mask_texture = .Full_Mask}),
			)
		}
	}

	for x in 1 ..= 7 {
		world_set_tile(
			{i32(x), 0, 4},
			chunk_tile({texture = .Asphalt, mask_texture = .Full_Mask}),
		)
	}

	for z in 8 ..< WORLD_WIDTH {
		for x in 1 ..= 3 {
			world_set_tile(
				{i32(x), 0, i32(z)},
				chunk_tile({texture = .Asphalt, mask_texture = .Full_Mask}),
			)
		}

		world_set_tile(
			{4, 0, i32(z)},
			chunk_tile(
				{texture = .Asphalt_Vertical_Line, mask_texture = .Full_Mask},
			),
		)
		for x in 5 ..= 7 {
			world_set_tile(
				{i32(x), 0, i32(z)},
				chunk_tile({texture = .Asphalt, mask_texture = .Full_Mask}),
			)
		}
	}

	for x in 8 ..< WORLD_WIDTH {
		world_set_tile(
			{i32(x), 0, 8},
			chunk_tile({texture = .Sidewalk, mask_texture = .Full_Mask}),
		)
	}

	for z in 9 ..< WORLD_WIDTH {
		world_set_tile(
			{8, 0, i32(z)},
			chunk_tile({texture = .Sidewalk, mask_texture = .Full_Mask}),
		)
	}
}

add_house_floor_triangles :: proc(floor: i32, texture: Texture) {
	tri := Tile_Triangle {
		texture      = texture,
		mask_texture = .Full_Mask,
	}

	world_set_tile_triangle({house_x + 4, floor, house_z}, .West, tri)
	world_set_tile_triangle({house_x + 4, floor, house_z}, .North, tri)

	world_set_tile_triangle({house_x, floor, house_z + 4}, .South, tri)
	world_set_tile_triangle({house_x, floor, house_z + 4}, .East, tri)

	world_set_tile_triangle({house_x, floor, house_z + 6}, .North, tri)
	world_set_tile_triangle({house_x, floor, house_z + 6}, .East, tri)

	world_set_tile_triangle({house_x + 4, floor, house_z + 10}, .South, tri)
	world_set_tile_triangle({house_x + 4, floor, house_z + 10}, .West, tri)

	for x in 0 ..< 4 {
		for z in 0 ..< 4 {
			world_set_tile(
				{house_x + i32(x), floor, house_z + i32(z)},
				chunk_tile(tri),
			)
		}
	}

	for x in 0 ..< 3 {
		for z in 0 ..< 3 {
			world_set_tile(
				{house_x + i32(x) + 1, floor, house_z + i32(z) + 4},
				chunk_tile(tri),
			)
		}
	}

	for x in 0 ..< 4 {
		for z in 0 ..< 4 {
			world_set_tile(
				{house_x + i32(x), floor, house_z + i32(z) + 7},
				chunk_tile(tri),
			)
		}
	}

	for z in 0 ..< 9 {
		world_set_tile(
			{house_x + 4, floor, house_z + i32(z) + 1},
			chunk_tile(tri),
		)
	}
}

add_house_floor_walls :: proc(
	floor: i32,
	inside_texture: Wall_Texture,
	outside_texture: Wall_Texture,
) {
	// The house's front wall
	insert_north_south_wall(
		 {
			pos = {f32(house_x), f32(floor * WALL_HEIGHT), f32(house_z)},
			type = .Side_Right_Corner,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)
	for i in 0 ..< 2 {
		insert_north_south_wall(
			 {
				pos =  {
					f32(house_x),
					f32(floor * WALL_HEIGHT),
					f32(house_z + i32(i) + 1),
				},
				type = .Side_Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
			},
		)
	}
	insert_north_south_wall(
		 {
			pos = {f32(house_x), f32(floor * WALL_HEIGHT), f32(house_z + 3)},
			type = .Right_Corner_Side,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	insert_south_west_north_east_wall(
		 {
			pos = {f32(house_x), f32(floor * WALL_HEIGHT), f32(house_z + 4)},
			type = .Side_Side,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	// door?
	mask := Wall_Mask_Texture.Window_Opening
	if floor == 0 do mask = .Door_Opening
	insert_north_south_wall(
		 {
			pos =  {
				f32(house_x + 1),
				f32(floor * WALL_HEIGHT),
				f32(house_z + 5),
			},
			type = .Left_Corner_Left_Corner,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
			mask = mask,
		},
	)
	if floor > 0 {
		append_billboard(
			 {
				position =  {
					f32(house_x + 1),
					f32(floor * WALL_HEIGHT),
					f32(house_z + 5),
				},
				light = {1, 1, 1},
				texture = .Window_Wood_SE,
				depth_map = .Window_Wood_SE,
			},
		)
	} else {
		append_billboard(
			 {
				position = {f32(house_x + 1), f32(floor), f32(house_z + 5)},
				light = {1, 1, 1},
				texture = .Door_Wood_SE,
				depth_map = .Door_Wood_SE,
			},
		)
	}

	insert_north_west_south_east_wall(
		 {
			pos = {f32(house_x), f32(floor * WALL_HEIGHT), f32(house_z + 6)},
			type = .End_Side,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	insert_north_south_wall(
		 {
			pos = {f32(house_x), f32(floor * WALL_HEIGHT), f32(house_z + 7)},
			type = .Side_Right_Corner,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	for i in 0 ..< 2 {
		insert_north_south_wall(
			 {
				pos =  {
					f32(house_x),
					f32(floor * WALL_HEIGHT),
					f32(house_z + i32(i) + 8),
				},
				type = .Side_Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
				mask = .Window_Opening,
			},
		)
		append_billboard(
			 {
				position =  {
					f32(house_x),
					f32(floor * WALL_HEIGHT),
					f32(house_z + i32(i) + 8),
				},
				light = {1, 1, 1},
				texture = .Window_Wood_SE,
				depth_map = .Window_Wood_SE,
			},
		)
	}

	insert_north_south_wall(
		 {
			pos = {f32(house_x), f32(floor * WALL_HEIGHT), f32(house_z + 10)},
			type = .Right_Corner_Side,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	// The house's right side wall
	insert_east_west_wall(
		 {
			pos = {f32(house_x), f32(floor * WALL_HEIGHT), f32(house_z)},
			type = .Left_Corner_Side,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	for i in 0 ..< 2 {
		insert_east_west_wall(
			 {
				pos =  {
					f32(house_x + i32(i) + 1),
					f32(floor * WALL_HEIGHT),
					f32(house_z),
				},
				type = .Side_Side,
				textures =  {
					.Inside = inside_texture,
					.Outside = outside_texture,
				},
				mask = .Window_Opening,
			},
		)

		append_billboard(
			 {
				position =  {
					f32(house_x + i32(i) + 1),
					f32(floor * WALL_HEIGHT),
					f32(house_z),
				},
				light = {1, 1, 1},
				texture = .Window_Wood_SW,
				depth_map = .Window_Wood_SW,
			},
		)
	}

	insert_east_west_wall(
		 {
			pos = {f32(house_x + 3), f32(floor * WALL_HEIGHT), f32(house_z)},
			type = .Side_Left_Corner,
			textures = {.Inside = inside_texture, .Outside = outside_texture},
		},
	)

	// The house's left side wall
	insert_east_west_wall(
		 {
			pos = {f32(house_x), f32(floor * WALL_HEIGHT), f32(house_z + 11)},
			type = .Right_Corner_Side,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	for i in 0 ..< 2 {
		insert_east_west_wall(
			 {
				pos =  {
					f32(house_x + i32(i) + 1),
					f32(floor * WALL_HEIGHT),
					f32(house_z + 11),
				},
				type = .Side_Side,
				textures =  {
					.Inside = outside_texture,
					.Outside = inside_texture,
				},
				mask = .Window_Opening,
			},
		)

		append_billboard(
			 {
				position =  {
					f32(house_x + i32(i) + 1),
					f32(floor * WALL_HEIGHT),
					f32(house_z + 11),
				},
				light = {1, 1, 1},
				texture = .Window_Wood_SW,
				depth_map = .Window_Wood_SW,
			},
		)
	}
	insert_east_west_wall(
		 {
			pos =  {
				f32(house_x + 3),
				f32(floor * WALL_HEIGHT),
				f32(house_z + 11),
			},
			type = .Side_Right_Corner,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	// The house's back wall
	insert_south_west_north_east_wall(
		 {
			pos = {f32(house_x + 4), f32(floor * WALL_HEIGHT), f32(house_z)},
			type = .Side_Side,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	insert_north_south_wall(
		 {
			pos =  {
				f32(house_x + 5),
				f32(floor * WALL_HEIGHT),
				f32(house_z + 1),
			},
			type = .Side_Left_Corner,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	for i in 0 ..< 7 {
		insert_north_south_wall(
			 {
				pos =  {
					f32(house_x + 5),
					f32(floor * WALL_HEIGHT),
					f32(house_z + i32(i) + 2),
				},
				type = .Side_Side,
				textures =  {
					.Inside = outside_texture,
					.Outside = inside_texture,
				},
			},
		)
	}

	insert_north_south_wall(
		 {
			pos =  {
				f32(house_x + 5),
				f32(floor * WALL_HEIGHT),
				f32(house_z + 9),
			},
			type = .Left_Corner_Side,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)

	insert_north_west_south_east_wall(
		 {
			pos =  {
				f32(house_x + 4),
				f32(floor * WALL_HEIGHT),
				f32(house_z + 10),
			},
			type = .End_Side,
			textures = {.Inside = outside_texture, .Outside = inside_texture},
		},
	)
}

draw_world :: proc() {
	uniform_object.view = camera_view
	uniform_object.proj = camera_proj

	gl.BindBuffer(gl.UNIFORM_BUFFER, ubo)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, ubo)
	gl.BufferSubData(
		gl.UNIFORM_BUFFER,
		0,
		size_of(Uniform_Object),
		&uniform_object,
	)

	gl.UseProgram(shader_program)

	start_wall_rendering()
	draw_walls()
	draw_diagonal_walls()
	finish_wall_rendering()

	if world_previously_visible_chunks_start != world_visible_chunks_start ||
	   world_previously_visible_chunks_end != world_visible_chunks_end ||
       world_tiles_dirty {
		clear(&world_vertices)
		clear(&world_indices)
		world_draw_tiles()
		gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
		gl.BufferData(
			gl.ARRAY_BUFFER,
			len(world_vertices) * size_of(Vertex),
			raw_data(world_vertices),
			gl.STATIC_DRAW,
		)
		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	}

	gl.BindVertexArray(vao)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, texture_array)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, mask_array)

	gl.DrawElements(
		gl.TRIANGLES,
		i32(len(world_indices)),
		gl.UNSIGNED_INT,
		raw_data(world_indices),
	)
	gl.BindVertexArray(0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
}
