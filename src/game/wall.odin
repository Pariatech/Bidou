package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import glsl "core:math/linalg/glsl"
import "core:strings"

import gl "vendor:OpenGL"

import "../camera"
import "../constants"
import "../renderer"
import "../terrain"
import "../utils"


Wall_Mask_Texture :: enum (u16) {
	Full_Mask,
	Door_Opening,
	Window_Opening,
}

Wall_Axis :: enum {
	N_S,
	E_W,
	SW_NE,
	NW_SE,
}

Wall_Type_Part :: enum {
	End,
	Side,
	Left_Corner,
	Right_Corner,
}

Wall_Type :: enum {
	Full,
	Extended_Left,
	Extended_Right,
	Side,
	Start,
	End,
	Extended_Start,
	Extended_End,
	Extended,
}

Wall_Texture_Position :: enum {
	Base,
	Top,
}

State :: enum {
	Up,
	Down,
	Left,
	Right,
}

Wall_Top_Mesh :: enum {
	Full,
	Side,
}

Wall_Side :: enum {
	Inside,
	Outside,
}

Wall :: struct {
	type:     Wall_Type,
	textures: [Wall_Side]Wall_Texture,
	mask:     Wall_Mask_Texture,
	state:    State,
}


Wall_Vertex :: struct {
	pos:       glsl.vec3,
	light:     glsl.vec3,
	texcoords: glsl.vec4,
}

Chunk :: struct {
	north_south:           map[glsl.ivec2]Wall,
	east_west:             map[glsl.ivec2]Wall,
	south_west_north_east: map[glsl.ivec2]Wall,
	north_west_south_east: map[glsl.ivec2]Wall,
	vao, vbo, ebo:         u32,
	dirty:                 bool,
	initialized:           bool,
	num_indices:           i32,
}

Wall_Texture :: enum (u16) {
	Wall_Top,
	Frame,
	Drywall,
	Brick,
	White,
	Royal_Blue,
	Dark_Blue,
	White_Cladding,
	Bricks_012,
	Marble_001,
	Paint_001,
	Paint_002,
	Paint_003,
	Paint_004,
	Paint_005,
	Paint_006,
	Planks_003,
	Planks_011,
	Tiles_009,
	Tiles_077,
	WoodSiding_002,
}

Wall_Index :: u32

WALL_TEXTURE_HEIGHT :: 384
WALL_TEXTURE_WIDTH :: 128

WALL_TEXTURE_PATHS :: [Wall_Texture]cstring {
	.Wall_Top       = "resources/textures/walls/wall-top.png",
	.Frame          = "resources/textures/walls/side/frame.png",
	.Drywall        = "resources/textures/walls/side/drywall.png",
	.Brick          = "resources/textures/walls/side/brick-wall.png",
	.White          = "resources/textures/walls/side/white.png",
	.Royal_Blue     = "resources/textures/walls/side/royal_blue.png",
	.Dark_Blue      = "resources/textures/walls/side/dark_blue.png",
	.White_Cladding = "resources/textures/walls/side/white_cladding.png",
	.Bricks_012     = "resources/textures/walls/side/Bricks012.png",
	.Marble_001     = "resources/textures/walls/side/Marble001.png",
	.Paint_001      = "resources/textures/walls/side/Paint001.png",
	.Paint_002      = "resources/textures/walls/side/Paint002.png",
	.Paint_003      = "resources/textures/walls/side/Paint003.png",
	.Paint_004      = "resources/textures/walls/side/Paint004.png",
	.Paint_005      = "resources/textures/walls/side/Paint005.png",
	.Paint_006      = "resources/textures/walls/side/Paint006.png",
	.Planks_003     = "resources/textures/walls/side/Planks003.png",
	.Planks_011     = "resources/textures/walls/side/Planks011.png",
	.Tiles_009      = "resources/textures/walls/side/Tiles009.png",
	.Tiles_077      = "resources/textures/walls/side/Tiles077.png",
	.WoodSiding_002 = "resources/textures/walls/side/WoodSiding002.png",
}

WALL_MASK_PATHS :: [Wall_Mask_Texture]cstring {
	.Full_Mask      = "resources/textures/wall-masks/full.png",
	.Door_Opening   = "resources/textures/wall-masks/door-opening.png",
	.Window_Opening = "resources/textures/wall-masks/window-opening.png",
}

WALL_TYPE_MODEL_NAME_MAP :: [Wall_Type][Wall_Side]string {
	.Start =  {
		.Outside = "Wall.Up.Start.Outside",
		.Inside = "Wall.Up.Start.Inside",
	},
	.End = {.Outside = "Wall.Up.End.Outside", .Inside = "Wall.Up.End.Inside"},
	.Extended_Left =  {
		.Outside = "Wall.Up.Extended_Left.Outside",
		.Inside = "Wall.Up.Extended_Left.Inside",
	},
	.Extended_Right =  {
		.Outside = "Wall.Up.Extended_Right.Outside",
		.Inside = "Wall.Up.Extended_Right.Inside",
	},
	.Full =  {
		.Outside = "Wall.Up.Full.Outside",
		.Inside = "Wall.Up.Full.Inside",
	},
	.Side =  {
		.Outside = "Wall.Up.Side.Outside",
		.Inside = "Wall.Up.Side.Inside",
	},
	.Extended_Start =  {
		.Outside = "Wall.Up.Extended_Start.Outside",
		.Inside = "Wall.Up.Extended_Start.Inside",
	},
	.Extended_End =  {
		.Outside = "Wall.Up.Extended_End.Outside",
		.Inside = "Wall.Up.Extended_End.Inside",
	},
	.Extended =  {
		.Outside = "Wall.Up.Extended.Outside",
		.Inside = "Wall.Up.Extended.Inside",
	},
}

WALL_TYPE_TOP_MODEL_NAME_MAP :: [Wall_Type]string {
	.Start          = "Wall.Up.Top.Extended_Left",
	.End            = "Wall.Up.Top.Extended_Right",
	.Extended_Left  = "Wall.Up.Top.Extended_Left",
	.Extended_Right = "Wall.Up.Top.Extended_Right",
	.Full           = "Wall.Up.Top.Full",
	.Side           = "Wall.Up.Top.Side",
	.Extended_Start = "Wall.Up.Top.Extended_Left",
	.Extended_End   = "Wall.Up.Top.Extended_Right",
	.Extended       = "Wall.Up.Top.Full",
}

chunks: [constants.CHUNK_HEIGHT][constants.WORLD_CHUNK_WIDTH][constants.WORLD_CHUNK_DEPTH]Chunk

WALL_SIDE_TYPE_MAP :: [Wall_Type_Part][Wall_Type_Part]Wall_Type {
	.End =  {
		.End = .Full,
		.Side = .Start,
		.Left_Corner = .Extended_Start,
		.Right_Corner = .Extended_Start,
	},
	.Side =  {
		.End = .End,
		.Side = .Side,
		.Left_Corner = .Extended_Right,
		.Right_Corner = .Extended_Right,
	},
	.Left_Corner =  {
		.End = .Extended_End,
		.Side = .Extended_Left,
		.Left_Corner = .Extended,
		.Right_Corner = .Extended,
	},
	.Right_Corner =  {
		.End = .Extended_End,
		.Side = .Extended_Left,
		.Left_Corner = .Extended,
		.Right_Corner = .Extended,
	},
}

WALL_TRANSFORM_MAP :: #partial [Wall_Axis][camera.Rotation]glsl.mat4 {
	.N_S =  {
		.South_West = {0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1},
		.South_East = {0, 0, -1, -1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1},
		.North_East = {0, 0, -1, -1, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 0, 1},
		.North_West = {0, 0, 1, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 0, 1},
	}, // .South_West = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
	.E_W =  {
		.South_West = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
		.South_East = {-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
		.North_East = {-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, -1, 0, 0, 0, 1},
		.North_West = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, -1, 0, 0, 0, 1},
	},
}


wall_texture_array: u32
wall_mask_array: u32

load_wall_mask_array :: proc() -> (ok: bool) {
	gl.ActiveTexture(gl.TEXTURE1)
	gl.GenTextures(1, &wall_mask_array)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, wall_mask_array)

	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.CLAMP)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.CLAMP)

	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	return renderer.load_texture_2D_array(
		WALL_MASK_PATHS,
		WALL_TEXTURE_WIDTH,
		WALL_TEXTURE_HEIGHT,
	)
}

load_wall_texture_array :: proc() -> (ok: bool = true) {
	gl.ActiveTexture(gl.TEXTURE0)
	gl.GenTextures(1, &wall_texture_array)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, wall_texture_array)

	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.REPEAT)

	gl.TexParameteri(
		gl.TEXTURE_2D_ARRAY,
		gl.TEXTURE_MIN_FILTER,
		gl.NEAREST_MIPMAP_LINEAR,
	)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	max_anisotropy: f32
	gl.GetFloatv(gl.MAX_TEXTURE_MAX_ANISOTROPY, &max_anisotropy)
	gl.TexParameterf(
		gl.TEXTURE_2D_ARRAY,
		gl.TEXTURE_MAX_ANISOTROPY,
		max_anisotropy,
	)

	return renderer.load_texture_2D_array(
		WALL_TEXTURE_PATHS,
		WALL_TEXTURE_WIDTH,
		WALL_TEXTURE_HEIGHT,
	)
}

init_wall_renderer :: proc() -> (ok: bool) {
	load_wall_texture_array() or_return
	load_wall_mask_array() or_return

	return true
}

deinit_wall_renderer :: proc() {

}

draw_wall_mesh :: proc(
	vertices: []Model_Vertex,
	indices: []Model_Index,
	model: glsl.mat4,
	texture: Wall_Texture,
	mask: Wall_Mask_Texture,
	light: glsl.vec3,
	vertex_buffer: ^[dynamic]Wall_Vertex,
	index_buffer: ^[dynamic]Wall_Index,
) {
	index_offset := u32(len(vertex_buffer))
	for i in 0 ..< len(vertices) {
		vertex: Wall_Vertex
		vertex.pos = vertices[i].pos
		vertex.texcoords.xy = vertices[i].texcoords.xy
		vertex.light = light
		vertex.texcoords.z = f32(texture)
		vertex.texcoords.w = f32(mask)
		vertex.pos = linalg.mul(model, utils.vec4(vertex.pos, 1)).xyz

		append(vertex_buffer, vertex)
	}

	for idx in indices {
		append(index_buffer, idx + index_offset)
	}
}

draw_wall :: proc(
	using game: ^Game_Context,
	pos: glsl.ivec3,
	wall: Wall,
	axis: Wall_Axis,
	vertex_buffer: ^[dynamic]Wall_Vertex,
	index_buffer: ^[dynamic]Wall_Index,
) {
	position := glsl.vec3 {
		f32(pos.x),
		f32(pos.y) * constants.WALL_HEIGHT +
		terrain.terrain_heights[pos.x][pos.z],
		f32(pos.z),
	}
	transform := glsl.mat4Translate(position)
	if axis == .N_S {
		transform *= glsl.mat4Rotate({0, 1, 0}, 0.5 * math.PI)
	}

	light := glsl.vec3{1, 1, 1}
	if axis == .N_S {
		light = glsl.vec3{0.9, 0.9, 0.9}
	}


	for texture, side in wall.textures {
		model_name_map := WALL_TYPE_MODEL_NAME_MAP
		model_name := model_name_map[wall.type][side]
		model := models.models[model_name]
		vertices := model.vertices[:]
		indices := model.indices[:]
		draw_wall_mesh(
			vertices,
			indices,
			transform,
			texture,
			wall.mask,
			light,
			vertex_buffer,
			index_buffer,
		)
	}

	model_name_map := WALL_TYPE_TOP_MODEL_NAME_MAP
	model_name := model_name_map[wall.type]
	model := models.models[model_name]
	vertices := model.vertices[:]
	indices := model.indices[:]
	draw_wall_mesh(
		vertices,
		indices,
		transform,
		.Wall_Top,
		.Full_Mask,
		light,
		vertex_buffer,
		index_buffer,
	)
}

get_chunk :: proc(pos: glsl.ivec3) -> ^Chunk {
	return(
		&chunks[pos.y][pos.x / constants.CHUNK_WIDTH][pos.z / constants.CHUNK_DEPTH] \
	)
}

set_north_south_wall :: proc(pos: glsl.ivec3, w: Wall) {
	if has_south_west_north_east_wall(pos) ||
	   has_north_west_south_east_wall(pos) ||
	   has_south_west_north_east_wall(pos + {-1, 0, 0}) ||
	   has_north_west_south_east_wall(pos + {-1, 0, 0}) {return
	}
	chunk_set_north_south_wall(get_chunk(pos), pos, w)
}

get_north_south_wall :: proc(pos: glsl.ivec3) -> (Wall, bool) {
	return chunk_get_north_south_wall(get_chunk(pos), pos)
}

set_wall :: proc(pos: glsl.ivec3, axis: Wall_Axis, w: Wall) {
	switch axis {
	case .E_W:
		set_east_west_wall(pos, w)
	case .N_S:
		set_north_south_wall(pos, w)
	case .NW_SE:
		set_north_west_south_east_wall(pos, w)
	case .SW_NE:
		set_south_west_north_east_wall(pos, w)
	}
}

get_wall :: proc(pos: glsl.ivec3, axis: Wall_Axis) -> (Wall, bool) {
	switch axis {
	case .E_W:
		return get_east_west_wall(pos)
	case .N_S:
		return get_north_south_wall(pos)
	case .NW_SE:
		return get_north_west_south_east_wall(pos)
	case .SW_NE:
		return get_south_west_north_east_wall(pos)
	}

	return {}, false
}

has_north_south_wall :: proc(pos: glsl.ivec3) -> bool {
	return(
		(pos.x >= 0 && pos.x < constants.WORLD_WIDTH) &&
		(pos.y >= 0 && pos.y < constants.WORLD_HEIGHT) &&
		(pos.z >= 0 && pos.z < constants.WORLD_DEPTH) &&
		chunk_has_north_south_wall(get_chunk(pos), pos) \
	)
}

remove_north_south_wall :: proc(pos: glsl.ivec3) {
	chunk_remove_north_south_wall(get_chunk(pos), pos)
}

set_east_west_wall :: proc(pos: glsl.ivec3, w: Wall) {
	if has_south_west_north_east_wall(pos) ||
	   has_north_west_south_east_wall(pos) ||
	   has_south_west_north_east_wall(pos + {0, 0, -1}) ||
	   has_north_west_south_east_wall(pos + {0, 0, -1}) {
		return
	}
	chunk_set_east_west_wall(get_chunk(pos), pos, w)
}

get_east_west_wall :: proc(pos: glsl.ivec3) -> (Wall, bool) {
	return chunk_get_east_west_wall(get_chunk(pos), pos)
}

has_east_west_wall :: proc(pos: glsl.ivec3) -> bool {
	return(
		(pos.x >= 0 && pos.x < constants.WORLD_WIDTH) &&
		(pos.y >= 0 && pos.y < constants.WORLD_HEIGHT) &&
		(pos.z >= 0 && pos.z < constants.WORLD_DEPTH) &&
		chunk_has_east_west_wall(get_chunk(pos), pos) \
	)
}

remove_east_west_wall :: proc(pos: glsl.ivec3) {
	chunk_remove_east_west_wall(get_chunk(pos), pos)
}

set_north_west_south_east_wall :: proc(pos: glsl.ivec3, wall: Wall) {
	if has_north_south_wall(pos) ||
	   has_north_south_wall(pos + {1, 0, 0}) ||
	   has_east_west_wall(pos) ||
	   has_east_west_wall(pos + {0, 0, 1}) {
		return
	}
	chunk_set_north_west_south_east_wall(get_chunk(pos), pos, wall)
}

has_north_west_south_east_wall :: proc(pos: glsl.ivec3) -> bool {
	return(
		(pos.x >= 0 && pos.x < constants.WORLD_WIDTH) &&
		(pos.y >= 0 && pos.y < constants.WORLD_HEIGHT) &&
		(pos.z >= 0 && pos.z < constants.WORLD_DEPTH) &&
		chunk_has_north_west_south_east_wall(get_chunk(pos), pos) \
	)
}

get_north_west_south_east_wall :: proc(pos: glsl.ivec3) -> (Wall, bool) {
	return chunk_get_north_west_south_east_wall(get_chunk(pos), pos)
}

remove_north_west_south_east_wall :: proc(pos: glsl.ivec3) {
	chunk_remove_north_west_south_east_wall(get_chunk(pos), pos)
}

set_south_west_north_east_wall :: proc(pos: glsl.ivec3, wall: Wall) {
	if has_north_south_wall(pos) ||
	   has_north_south_wall(pos + {1, 0, 0}) ||
	   has_east_west_wall(pos) ||
	   has_east_west_wall(pos + {0, 0, 1}) {
		return
	}
	chunk_set_south_west_north_east_wall(get_chunk(pos), pos, wall)
}

has_south_west_north_east_wall :: proc(pos: glsl.ivec3) -> bool {
	return(
		(pos.x >= 0 && pos.x < constants.WORLD_WIDTH) &&
		(pos.y >= 0 && pos.y < constants.WORLD_HEIGHT) &&
		(pos.z >= 0 && pos.z < constants.WORLD_DEPTH) &&
		chunk_has_south_west_north_east_wall(get_chunk(pos), pos) \
	)
}

get_south_west_north_east_wall :: proc(pos: glsl.ivec3) -> (Wall, bool) {
	return chunk_get_south_west_north_east_wall(get_chunk(pos), pos)
}

remove_south_west_north_east_wall :: proc(pos: glsl.ivec3) {
	chunk_remove_south_west_north_east_wall(get_chunk(pos), pos)
}

chunk_set_north_south_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
	wall: Wall,
) {
	chunk.north_south[pos.xz] = wall
	chunk.dirty = true
}

chunk_has_north_south_wall :: proc(chunk: ^Chunk, pos: glsl.ivec3) -> bool {
	return pos.xz in chunk.north_south
}

chunk_get_north_south_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
) -> (
	Wall,
	bool,
) {
	return chunk.north_south[pos.xz]
}

chunk_remove_north_south_wall :: proc(chunk: ^Chunk, pos: glsl.ivec3) {
	delete_key(&chunk.north_south, glsl.ivec2(pos.xz))
	chunk.dirty = true
}

chunk_set_east_west_wall :: proc(chunk: ^Chunk, pos: glsl.ivec3, wall: Wall) {
	chunk.east_west[pos.xz] = wall
	chunk.dirty = true
}

chunk_has_east_west_wall :: proc(chunk: ^Chunk, pos: glsl.ivec3) -> bool {
	return pos.xz in chunk.east_west
}

chunk_get_east_west_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
) -> (
	Wall,
	bool,
) {
	return chunk.east_west[pos.xz]
}

chunk_remove_east_west_wall :: proc(chunk: ^Chunk, pos: glsl.ivec3) {
	delete_key(&chunk.east_west, glsl.ivec2(pos.xz))
	chunk.dirty = true
}


chunk_set_north_west_south_east_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
	wall: Wall,
) {
	chunk.north_west_south_east[pos.xz] = wall
	chunk.dirty = true
}

chunk_has_north_west_south_east_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
) -> bool {
	return pos.xz in chunk.north_west_south_east
}

chunk_get_north_west_south_east_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
) -> (
	Wall,
	bool,
) {
	return chunk.north_west_south_east[pos.xz]
}

chunk_remove_north_west_south_east_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
) {
	delete_key(&chunk.north_west_south_east, glsl.ivec2(pos.xz))
	chunk.dirty = true
}

chunk_set_south_west_north_east_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
	wall: Wall,
) {
	chunk.south_west_north_east[pos.xz] = wall
	chunk.dirty = true
}

chunk_has_south_west_north_east_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
) -> bool {
	return pos.xz in chunk.south_west_north_east
}

chunk_get_south_west_north_east_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
) -> (
	Wall,
	bool,
) {
	return chunk.south_west_north_east[pos.xz]
}

chunk_remove_south_west_north_east_wall :: proc(
	chunk: ^Chunk,
	pos: glsl.ivec3,
) {
	delete_key(&chunk.south_west_north_east, glsl.ivec2(pos.xz))
	chunk.dirty = true
}

chunk_draw_walls :: proc(
	game: ^Game_Context,
	chunk: ^Chunk,
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
			size_of(Wall_Vertex),
			offset_of(Wall_Vertex, pos),
		)
		gl.EnableVertexAttribArray(0)

		gl.VertexAttribPointer(
			1,
			3,
			gl.FLOAT,
			gl.FALSE,
			size_of(Wall_Vertex),
			offset_of(Wall_Vertex, light),
		)
		gl.EnableVertexAttribArray(1)

		gl.VertexAttribPointer(
			2,
			4,
			gl.FLOAT,
			gl.FALSE,
			size_of(Wall_Vertex),
			offset_of(Wall_Vertex, texcoords),
		)
		gl.EnableVertexAttribArray(2)
	}

	gl.BindVertexArray(chunk.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, chunk.vbo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, chunk.ebo)

	if chunk.dirty {
		chunk.dirty = false

		vertices: [dynamic]Wall_Vertex
		indices: [dynamic]Wall_Index
		defer delete(vertices)
		defer delete(indices)

		for wall_pos, w in chunk.east_west {
			draw_wall(
				game,
				{wall_pos.x, pos.y, wall_pos.y},
				w,
				.E_W,
				&vertices,
				&indices,
			)
		}

		for wall_pos, w in chunk.north_south {
			draw_wall(
				game,
				{wall_pos.x, pos.y, wall_pos.y},
				w,
				.N_S,
				&vertices,
				&indices,
			)
		}

		for wall_pos, w in chunk.south_west_north_east {
			draw_diagonal_wall(
				game,
				{wall_pos.x, pos.y, wall_pos.y},
				w,
				.SW_NE,
				&vertices,
				&indices,
			)
		}

		for wall_pos, w in chunk.north_west_south_east {
			draw_diagonal_wall(
				game,
				{wall_pos.x, pos.y, wall_pos.y},
				w,
				.NW_SE,
				&vertices,
				&indices,
			)
		}

		gl.BufferData(
			gl.ARRAY_BUFFER,
			len(vertices) * size_of(Wall_Vertex),
			raw_data(vertices),
			gl.STATIC_DRAW,
		)

		gl.BufferData(
			gl.ELEMENT_ARRAY_BUFFER,
			len(indices) * size_of(Wall_Index),
			raw_data(indices),
			gl.STATIC_DRAW,
		)
		chunk.num_indices = i32(len(indices))
	}

	gl.DrawElements(gl.TRIANGLES, chunk.num_indices, gl.UNSIGNED_INT, nil)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)
}


draw_walls :: proc(game: ^Game_Context, floor: i32) {
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, wall_texture_array)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, wall_mask_array)

	for x in camera.visible_chunks_start.x ..< camera.visible_chunks_end.x {
		for z in camera.visible_chunks_start.y ..< camera.visible_chunks_end.y {
			chunk := &chunks[floor][x][z]
			chunk_draw_walls(game, chunk, {x, i32(floor), z})
		}
	}
}

update_after_rotation :: proc() {
}
