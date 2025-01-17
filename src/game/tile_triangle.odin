package game

import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import gl "vendor:OpenGL"

TILE_TRIANGLE_TEXTURE_PATHS :: [Tile_Triangle_Texture]cstring {
	.Floor_Marker            = "resources/textures/floors/floor-marker.png",
	.Wood_082A               = "resources/textures/tiles/Wood082A.png",
	.Wood_Floor_008          = "resources/textures/tiles/WoodFloor008.png",
	.Wood_Floor_020          = "resources/textures/tiles/WoodFloor020.png",
	.Wood_Floor_052          = "resources/textures/tiles/WoodFloor052.png",
	.Tiles_081               = "resources/textures/tiles/Tiles081.png",
	.Tiles_014               = "resources/textures/tiles/Tiles014.png",
	.Tiles_015               = "resources/textures/tiles/Tiles015.png",
	.Tiles_050               = "resources/textures/tiles/Tiles050.png",
	.Tiles_111               = "resources/textures/tiles/Tiles111.png",
	.Tiles_131               = "resources/textures/tiles/Tiles131.png",
	.Grass_004               = "resources/textures/tiles/Grass004.png",
	.Gravel_015              = "resources/textures/tiles/Gravel015.png",
	.Asphalt                 = "resources/textures/tiles/asphalt.png",
	.Asphalt_Vertical_Line   = "resources/textures/tiles/asphalt-vertical-line.png",
	.Asphalt_Horizontal_Line = "resources/textures/tiles/asphalt-horizontal-line.png",
	.Concrete                = "resources/textures/tiles/concrete.png",
	.Sidewalk                = "resources/textures/tiles/sidewalk.png",
}

TILE_TRIANGLE_SIDE_VERTICES_MAP ::
	[Tile_Triangle_Side][3]Tile_Triangle_Vertex {
		.South =  {
			 {
				pos = {-0.5, 0.0, -0.5},
				light = {1.0, 1.0, 1.0},
				texcoords = {0.0, 0.0, 0.0, 0.0},
			},
			 {
				pos = {0.5, 0.0, -0.5},
				light = {1.0, 1.0, 1.0},
				texcoords = {1.0, 0.0, 0.0, 0.0},
			},
			 {
				pos = {0.0, 0.0, 0.0},
				light = {1.0, 1.0, 1.0},
				texcoords = {0.5, 0.5, 0.0, 0.0},
			},
		},
		.East =  {
			 {
				pos = {0.5, 0.0, -0.5},
				light = {1.0, 1.0, 1.0},
				texcoords = {1.0, 0.0, 0.0, 0.0},
			},
			 {
				pos = {0.5, 0.0, 0.5},
				light = {1.0, 1.0, 1.0},
				texcoords = {1.0, 1.0, 0.0, 0.0},
			},
			 {
				pos = {0.0, 0.0, 0.0},
				light = {1.0, 1.0, 1.0},
				texcoords = {0.5, 0.5, 0.0, 0.0},
			},
		},
		.North =  {
			 {
				pos = {0.5, 0.0, 0.5},
				light = {1.0, 1.0, 1.0},
				texcoords = {1.0, 1.0, 0.0, 0.0},
			},
			 {
				pos = {-0.5, 0.0, 0.5},
				light = {1.0, 1.0, 1.0},
				texcoords = {0.0, 1.0, 0.0, 0.0},
			},
			 {
				pos = {0.0, 0.0, 0.0},
				light = {1.0, 1.0, 1.0},
				texcoords = {0.5, 0.5, 0.0, 0.0},
			},
		},
		.West =  {
			 {
				pos = {-0.5, 0.0, 0.5},
				light = {1.0, 1.0, 1.0},
				texcoords = {0.0, 1.0, 0.0, 0.0},
			},
			 {
				pos = {-0.5, 0.0, -0.5},
				light = {1.0, 1.0, 1.0},
				texcoords = {0.0, 0.0, 0.0, 0.0},
			},
			 {
				pos = {0.0, 0.0, 0.0},
				light = {1.0, 1.0, 1.0},
				texcoords = {0.5, 0.5, 0.0, 0.0},
			},
		},
	}

TILE_TRIANGLE_MASK_PATHS :: [Tile_Triangle_Mask]cstring {
		.Full_Mask      = "resources/textures/masks/full.png",
		.Grid_Mask      = "resources/textures/masks/grid.png",
		.Leveling_Brush = "resources/textures/masks/leveling-brush.png",
		.Dotted_Grid    = "resources/textures/masks/dotted-grid.png",
	}

Tile_Triangle_Texture :: enum (u16) {
	Floor_Marker,
	Grass_004,
	Gravel_015,
	Wood_082A,
	Wood_Floor_008,
	Wood_Floor_020,
	Wood_Floor_052,
	Tiles_081,
	Tiles_014,
	Tiles_015,
	Tiles_050,
	Tiles_111,
	Tiles_131,
	Asphalt,
	Asphalt_Vertical_Line,
	Asphalt_Horizontal_Line,
	Concrete,
	Sidewalk,
}

Tile_Triangle_Mask :: enum (u16) {
	Full_Mask,
	Grid_Mask,
	Leveling_Brush,
	Dotted_Grid,
}

Tile_Triangle_Side :: enum {
	South,
	East,
	North,
	West,
}

Tile_Triangle :: struct {
	texture:      Tile_Triangle_Texture,
	mask_texture: Tile_Triangle_Mask,
}

Tile_Triangle_Vertex :: struct {
	pos:       glsl.vec3,
	light:     glsl.vec3,
	texcoords: glsl.vec4,
}

Tile_Triangle_Key :: struct {
	x, z: int,
	side: Tile_Triangle_Side,
}

Tile_Triangle_Chunk :: struct {
	triangles:     map[Tile_Triangle_Key]Tile_Triangle,
	dirty:         bool,
	initialized:   bool,
	vao, vbo, ebo: u32,
	num_indices:   i32,
}

Tile_Triangle_Context :: struct {
	chunks:        [CHUNK_HEIGHT][WORLD_CHUNK_WIDTH][WORLD_CHUNK_DEPTH]Tile_Triangle_Chunk,
	texture_array: u32,
	mask_array:    u32,
}

tile_triangles_init :: proc() -> bool {
	tile_triangle_load_texture_array() or_return
	tile_triangle_load_mask_array() or_return
	return true
}

tile_triangles_deinit :: proc() {
	tile := get_tile_triangles_context()
	gl.DeleteTextures(1, &tile.texture_array)
	gl.DeleteTextures(1, &tile.mask_array)

	for &f in tile.chunks {
		for &r in f {
			for &c in r {
				delete(c.triangles)
			}
		}
	}
}

tile_triangle_draw_tile_triangle :: proc(
	tri: Tile_Triangle,
	side: Tile_Triangle_Side,
	lights: [3]glsl.vec3,
	heights: [3]f32,
	pos: glsl.vec2,
	size: f32,
	vertices_buffer: ^[dynamic]Tile_Triangle_Vertex,
	indices: ^[dynamic]u32,
) {
	index_offset := u32(len(vertices_buffer))

	tile_triangle_side_vertices_map := TILE_TRIANGLE_SIDE_VERTICES_MAP
	vertices := tile_triangle_side_vertices_map[side]
	for vertex, i in vertices {
		vertex := vertex
		vertex.pos *= size
		vertex.pos.x += pos.x
		vertex.pos.z += pos.y
		vertex.pos.y += heights[i]
		vertex.light = lights[i]
		vertex.texcoords.z = f32(tri.texture)
		vertex.texcoords.w = f32(tri.mask_texture)
		vertex.texcoords.xy *= size
		append(vertices_buffer, vertex)
	}

	append(indices, index_offset + 0, index_offset + 1, index_offset + 2)
}

tile_triangle_draw_tiles :: proc(floor: i32) {
	tile_triangles := get_tile_triangles_context()
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, tile_triangles.texture_array)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, tile_triangles.mask_array)

	floor_slice := &tile_triangles.chunks[floor]
	for x in camera().visible_chunks_start.x ..< camera().visible_chunks_end.x {
		for z in camera().visible_chunks_start.y ..< camera().visible_chunks_end.y {
			tile_triangle_chunk_draw_tiles(
				&floor_slice[x][z],
				{i32(x), i32(floor), i32(z)},
			)
		}
	}
}

tile_triangle_chunk_draw_tiles :: proc(
	chunk: ^Tile_Triangle_Chunk,
	pos: glsl.ivec3,
) {
	if !chunk.initialized {
		chunk.initialized = true
		chunk.dirty = true
		gl.GenVertexArrays(1, &chunk.vao)
		gl.BindVertexArray(chunk.vao)
		gl.GenBuffers(1, &chunk.vbo)
		gl.BindBuffer(gl.ARRAY_BUFFER, chunk.vbo)

		gl.GenBuffers(1, &chunk.ebo)

		gl.VertexAttribPointer(
			0,
			3,
			gl.FLOAT,
			gl.FALSE,
			size_of(Tile_Triangle_Vertex),
			offset_of(Tile_Triangle_Vertex, pos),
		)
		gl.EnableVertexAttribArray(0)

		gl.VertexAttribPointer(
			1,
			3,
			gl.FLOAT,
			gl.FALSE,
			size_of(Tile_Triangle_Vertex),
			offset_of(Tile_Triangle_Vertex, light),
		)
		gl.EnableVertexAttribArray(1)

		gl.VertexAttribPointer(
			2,
			4,
			gl.FLOAT,
			gl.FALSE,
			size_of(Tile_Triangle_Vertex),
			offset_of(Tile_Triangle_Vertex, texcoords),
		)
		gl.EnableVertexAttribArray(2)
	}

	gl.BindVertexArray(chunk.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, chunk.vbo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, chunk.ebo)

	floor := pos.y
	if chunk.dirty {
		chunk.dirty = false
		vertices: [dynamic]Tile_Triangle_Vertex
		indices: [dynamic]u32
		defer delete(vertices)
		defer delete(indices)

		for index, tile_triangle in chunk.triangles {
			side := index.side
			pos := glsl.vec2{f32(index.x), f32(index.z)}

			x := int(index.x)
			z := int(index.z)
			lights := tile_triangle_get_terrain_tile_triangle_lights(
				side,
				x,
				z,
				1,
			)

			heights := tile_triangle_get_terrain_tile_triangle_heights(
				side,
				x,
				z,
				1,
			)

			for i in 0 ..< 3 {
				heights[i] += f32(floor * WALL_HEIGHT) + FLOOR_TILE_OFFSET
			}

			tile_triangle_draw_tile_triangle(
				tile_triangle,
				side,
				lights,
				heights,
				pos,
				1,
				&vertices,
				&indices,
			)
		}

		gl.BufferData(
			gl.ARRAY_BUFFER,
			len(vertices) * size_of(Tile_Triangle_Vertex),
			raw_data(vertices),
			gl.STATIC_DRAW,
		)

		gl.BufferData(
			gl.ELEMENT_ARRAY_BUFFER,
			len(indices) * size_of(u32),
			raw_data(indices),
			gl.STATIC_DRAW,
		)
		chunk.num_indices = i32(len(indices))
	}

	if chunk.num_indices == 0 {
		return
	}

	gl.DrawElements(gl.TRIANGLES, chunk.num_indices, gl.UNSIGNED_INT, nil)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)
}

tile_triangle_get_terrain_tile_triangle_lights :: proc(
	side: Tile_Triangle_Side,
	x, z, w: int,
) -> (
	lights: [3]glsl.vec3,
) {
	lights = {{1, 1, 1}, {1, 1, 1}, {1, 1, 1}}

	terrain := get_terrain_context()
	tile_lights := [4]glsl.vec3 {
		terrain.terrain_lights[x][z],
		terrain.terrain_lights[x + w][z],
		terrain.terrain_lights[x + w][z + w],
		terrain.terrain_lights[x][z + w],
	}

	lights[2] = {0, 0, 0}
	for light in tile_lights {
		lights[2] += light
	}
	lights[2] /= 4
	switch side {
	case .South:
		lights[0] = tile_lights[0]
		lights[1] = tile_lights[1]
	case .East:
		lights[0] = tile_lights[1]
		lights[1] = tile_lights[2]
	case .North:
		lights[0] = tile_lights[2]
		lights[1] = tile_lights[3]
	case .West:
		lights[0] = tile_lights[3]
		lights[1] = tile_lights[0]
	}

	return
}

tile_triangle_get_terrain_tile_triangle_heights :: proc(
	side: Tile_Triangle_Side,
	x, z, w: int,
) -> (
	heights: [3]f32,
) {
	heights = {0, 0, 0}
	left_x := math.clamp(x, 0, WORLD_WIDTH)
	right_x := math.clamp(x + w, 0, WORLD_WIDTH)
	top_z := math.clamp(z, 0, WORLD_DEPTH)
	bottom_z := math.clamp(z + w, 0, WORLD_DEPTH)

	terrain := get_terrain_context()
	tile_heights := [4]f32 {
		terrain.terrain_heights[left_x][top_z],
		terrain.terrain_heights[right_x][top_z],
		terrain.terrain_heights[right_x][bottom_z],
		terrain.terrain_heights[left_x][bottom_z],
	}

	// log.info(tile_heights)

	heights[2] = 0
	lowest := min(
		tile_heights[0],
		tile_heights[1],
		tile_heights[2],
		tile_heights[3],
	)
	highest := max(
		tile_heights[0],
		tile_heights[1],
		tile_heights[2],
		tile_heights[3],
	)
	heights[2] = (lowest + highest) / 2

	switch side {
	case .South:
		heights[0] = tile_heights[0]
		heights[1] = tile_heights[1]
	case .East:
		heights[0] = tile_heights[1]
		heights[1] = tile_heights[2]
	case .North:
		heights[0] = tile_heights[2]
		heights[1] = tile_heights[3]
	case .West:
		heights[0] = tile_heights[3]
		heights[1] = tile_heights[0]
	}

	return
}

tile_triangle_tile :: proc(
	tile_triangle: Maybe(Tile_Triangle),
) -> [Tile_Triangle_Side]Maybe(Tile_Triangle) {
	return(
		 {
			.West = tile_triangle,
			.South = tile_triangle,
			.East = tile_triangle,
			.North = tile_triangle,
		} \
	)
}

tile_triangle_chunk_init :: proc() {
	ctx := get_tile_triangles_context()
	for cx in 0 ..< WORLD_CHUNK_WIDTH {
		for cz in 0 ..< WORLD_CHUNK_DEPTH {
			chunk := &ctx.chunks[0][cx][cz]
			for x in 0 ..< CHUNK_WIDTH {
				for z in 0 ..< CHUNK_DEPTH {
					for side in Tile_Triangle_Side {
						chunk.triangles[{x = cx * CHUNK_WIDTH + x, z = cz * CHUNK_DEPTH + z, side = side}] =
							Tile_Triangle {
								texture      = .Grass_004,
								mask_texture = .Grid_Mask,
							}
					}
				}
			}
		}
	}
}

tile_triangle_get_chunk :: proc(pos: glsl.ivec3) -> ^Tile_Triangle_Chunk {
	ctx := get_tile_triangles_context()
	x := pos.x / CHUNK_WIDTH
	z := pos.z / CHUNK_DEPTH
	return &ctx.chunks[pos.y][x][z]
}

tile_triangle_get_tile_triangle :: proc(
	pos: glsl.ivec3,
	side: Tile_Triangle_Side,
) -> (
	Tile_Triangle,
	bool,
) {
	chunk := tile_triangle_get_chunk(pos)
	return chunk.triangles[{x = int(pos.x), z = int(pos.z), side = side}]
}

tile_triangle_set_tile_triangle :: proc(
	pos: glsl.ivec3,
	side: Tile_Triangle_Side,
	tile_triangle: Maybe(Tile_Triangle),
) {
	key := Tile_Triangle_Key {
			x    = int(pos.x),
			z    = int(pos.z),
			side = side,
		}
	chunk := tile_triangle_get_chunk(pos)
	if tile_triangle != nil {
		chunk.triangles[key] = tile_triangle.?
	} else {
		delete_key(&chunk.triangles, key)
	}
	chunk.dirty = true
}

tile_triangle_get_tile :: proc(
	pos: glsl.ivec3,
) -> [Tile_Triangle_Side]Maybe(Tile_Triangle) {
	chunk := tile_triangle_get_chunk(pos)
	result := [Tile_Triangle_Side]Maybe(Tile_Triangle){}

	for side in Tile_Triangle_Side {
		key := Tile_Triangle_Key {
				x    = int(pos.x),
				z    = int(pos.z),
				side = side,
			}
		tri, ok := chunk.triangles[key]
		if ok {
			result[side] = tri
		}
	}

	return result
}

tile_triangle_set_tile :: proc(
	pos: glsl.ivec3,
	tile: [Tile_Triangle_Side]Maybe(Tile_Triangle),
) {
	chunk := tile_triangle_get_chunk(pos)
	for tri, side in tile {
		tile_triangle_set_tile_triangle(pos, side, tri)
	}
}

tile_triangle_set_tile_mask_texture :: proc(
	pos: glsl.ivec3,
	mask_texture: Tile_Triangle_Mask,
) {
	chunk := tile_triangle_get_chunk(pos)
	for side in Tile_Triangle_Side {
		tri, ok := tile_triangle_get_tile_triangle(pos, side)
		if ok {
			tri.mask_texture = mask_texture
			tile_triangle_set_tile_triangle(pos, side, tri)
		}
	}
}

tile_triangle_set_tile_texture :: proc(
	pos: glsl.ivec3,
	texture: Tile_Triangle_Texture,
) {
	chunk := get_chunk(pos)
	for side in Tile_Triangle_Side {
		tri, ok := tile_triangle_get_tile_triangle(pos, side)
		if ok {
			tri.texture = texture
			tile_triangle_set_tile_triangle(pos, side, tri)
		}
	}
}

tile_triangle_load_mask_array :: proc() -> (ok: bool) {
	tile_triangles := get_tile_triangles_context()
	gl.ActiveTexture(gl.TEXTURE1)
	gl.GenTextures(1, &tile_triangles.mask_array)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, tile_triangles.mask_array)

	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.REPEAT)

	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	return texture_array_load(TILE_TRIANGLE_MASK_PATHS)
}

tile_triangle_load_texture_array :: proc() -> (ok: bool = true) {
	tile_triangles := get_tile_triangles_context()
	gl.ActiveTexture(gl.TEXTURE0)
	gl.GenTextures(1, &tile_triangles.texture_array)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, tile_triangles.texture_array)

	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.REPEAT)

	gl.TexParameteri(
		gl.TEXTURE_2D_ARRAY,
		gl.TEXTURE_MIN_FILTER,
		gl.LINEAR_MIPMAP_LINEAR,
	)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	max_anisotropy: f32
	gl.GetFloatv(gl.MAX_TEXTURE_MAX_ANISOTROPY, &max_anisotropy)
	gl.TexParameterf(
		gl.TEXTURE_2D_ARRAY,
		gl.TEXTURE_MAX_ANISOTROPY,
		max_anisotropy,
	)

	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	return texture_array_load(TILE_TRIANGLE_TEXTURE_PATHS)
}
