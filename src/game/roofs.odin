package game

import "core:encoding/json"
import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:os"
import "core:path/filepath"
import "core:strings"

import gl "vendor:OpenGL"

import "../camera"
import c "../constants"
import "../floor"
import "../renderer"
import "../terrain"

// @(private = "file")
ROOF_SIZE_PADDING :: glsl.vec2{0.4, 0.4}

ROOF_TEXTURES :: [?]cstring {
	"resources/textures/roofs/Eave.png",
	"resources/roofs/colors/long_tiles/128x128.png",
	// "resources/textures/roofs/RoofingTiles002.png",
	"resources/roofs/colors/long_tiles/capping_128x128.png",
}

ROOF_SHADER :: Shader {
	vertex   = "resources/shaders/roof.vert",
	fragment = "resources/shaders/roof.frag",
}

@(private = "file")
EAVE_TEXTURE :: "resources/textures/roofs/Eave.png"

Roof_Id :: int

Roof_Key :: struct {
	chunk_pos: glsl.ivec3,
	index:     int,
}

Roof_Orientation :: enum {
	Longitudinal,
	Diagonal,
}

Roof_Type :: enum {
	Half_Hip,
	Half_Gable,
	Hip,
	Gable,
}

Roof :: struct {
	id:          Roof_Id,
	offset:      f32,
	start:       glsl.vec2,
	end:         glsl.vec2,
	slope:       f32,
	light:       glsl.vec4,
	type:        Roof_Type,
	color:       string,
	orientation: Roof_Orientation,
}

Roof_Chunk :: struct {
	roofs:        [dynamic]Roof,
	dirty:        bool,
	roofs_inside: [dynamic]Roof_Id,
}

Roof_Chunks :: [c.CHUNK_HEIGHT][c.WORLD_CHUNK_WIDTH][c.WORLD_CHUNK_DEPTH]Roof_Chunk

Roof_Uniform_Object :: struct {
	mvp:   glsl.mat4,
	light: glsl.vec3,
}

Roof_Vertex :: struct {
	pos:       glsl.vec3,
	texcoords: glsl.vec3,
	color:     glsl.vec4,
}

Roof_Index :: u32

Roofs_Context :: struct {
	chunks:        Roof_Chunks,
	keys:          map[Roof_Id]Roof_Key,
	next_id:       Roof_Id,
	ubo:           u32,
	shader:        Shader,
	vao, vbo, ebo: u32,
	texture_array: Texture_Array,
	floor_offset:  i32,
	color_map:     Roof_Color_Map,
}

Roof_Color :: struct {
	key:             string,
	name:            string,
	roof_texture:    string,
	capping_texture: string,
}

Texture_Array :: struct {
	handle:            u32,
	texture_index_map: map[string]f32,
}

Roof_Color_Map :: map[string]Roof_Color

init_roofs :: proc() -> bool {
	roofs := get_roofs_context()

	init_roof_colors() or_return

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	roofs.shader = ROOF_SHADER
	init_shader(&roofs.shader) or_return

	gl.GenBuffers(1, &roofs.ubo)

	gl.GenVertexArrays(1, &roofs.vao)
	gl.BindVertexArray(roofs.vao)
	gl.GenBuffers(1, &roofs.vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, roofs.vbo)

	gl.GenBuffers(1, &roofs.ebo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, roofs.ebo)

	gl.VertexAttribPointer(
		0,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Roof_Vertex),
		offset_of(Roof_Vertex, pos),
	)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(
		1,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Roof_Vertex),
		offset_of(Roof_Vertex, texcoords),
	)
	gl.EnableVertexAttribArray(1)

	gl.VertexAttribPointer(
		2,
		4,
		gl.FLOAT,
		gl.FALSE,
		size_of(Roof_Vertex),
		offset_of(Roof_Vertex, color),
	)
	gl.EnableVertexAttribArray(2)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.GenTextures(1, &roofs.texture_array.handle)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, roofs.texture_array.handle)

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

	textures := make(
		[]cstring,
		len(roofs.texture_array.texture_index_map),
		allocator = context.temp_allocator,
	)
	for k, v in roofs.texture_array.texture_index_map {
		textures[int(v)] = strings.clone_to_cstring(
			k,
			allocator = context.temp_allocator,
		)
	}

	renderer.load_texture_2D_array(textures, 128, 128) or_return
	set_shader_uniform(&roofs.shader, "texture_sampler", i32(0))

	gl.BindVertexArray(0)
	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.UseProgram(0)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, 0)

	return true
}

deinit_roofs :: proc() {
	roofs := get_roofs_context()
	delete(roofs.keys)
	for &layer in roofs.chunks {
		for &row in layer {
			for chunk in row {
				delete(chunk.roofs)
				delete(chunk.roofs_inside)
			}
		}
	}

	for k, v in roofs.color_map {
		delete(v.key)
		delete(v.name)
		delete(v.roof_texture)
		delete(v.capping_texture)
		// delete(k)
	}
	delete(roofs.color_map)
	delete(roofs.texture_array.texture_index_map)
	// clear(&roofs.color_map)
}

draw_roofs :: proc(flr: i32) {
	roofs := get_roofs_context()
	if flr >= floor.floor + roofs.floor_offset {
		return
	}
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, roofs.texture_array.handle)
	defer gl.BindTexture(gl.TEXTURE_2D_ARRAY, 0)

	gl.BindVertexArray(roofs.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, roofs.vbo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, roofs.ebo)

	bind_shader(&roofs.shader)

	gl.BindBuffer(gl.UNIFORM_BUFFER, roofs.ubo)
	set_shader_unifrom_block_binding(&roofs.shader, "UniformBufferObject", 2)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, roofs.ubo)

	uniform_object := Roof_Uniform_Object {
		mvp = camera.view_proj,
		light = {1, 1, 1},
	}

	gl.BufferData(
		gl.UNIFORM_BUFFER,
		size_of(Roof_Uniform_Object),
		&uniform_object,
		gl.STATIC_DRAW,
	)

	roof_ids: [dynamic]Roof_Id
	defer delete(roof_ids)
	y := flr
	for x in camera.visible_chunks_start.x ..< camera.visible_chunks_end.x {
		for z in camera.visible_chunks_start.y ..< camera.visible_chunks_end.y {
			chunk := &roofs.chunks[y][x][z]
			for roof_inside_id in chunk.roofs_inside {
				existing := false

				for roof_id in roof_ids {
					if roof_inside_id == roof_id {
						existing = true
						break
					}
				}

				if !existing {
					append(&roof_ids, roof_inside_id)
				}
			}
		}
	}

	vertices: [dynamic]Roof_Vertex
	defer delete(vertices)
	indices: [dynamic]Roof_Index
	defer delete(indices)
	for roof_id in roof_ids {
		draw_roof(roof_id, &vertices, &indices)
	}

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(Roof_Vertex),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)

	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(indices) * size_of(Roof_Index),
		raw_data(indices),
		gl.STATIC_DRAW,
	)

	gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_INT, nil)
}

get_roof_at :: proc(pos: glsl.vec3) -> (ptr: Roof, ok: bool) {
	roofs := get_roofs_context()
	chunk_pos := world_pos_to_chunk_pos(pos)
	chunk := &roofs.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]

	for id in chunk.roofs_inside {
		roof := get_roof_by_id(id) or_return
		start := glsl.min(roof.start, roof.end)
		end := glsl.max(roof.start, roof.end)
		if (start.x <= pos.x && pos.x <= end.x) &&
		   (start.y <= pos.z && pos.z <= end.y) {
			return roof, true
		}
	}

	return {}, false
}

get_roof_by_id :: proc(id: Roof_Id) -> (ptr: Roof, ok: bool) {
	ctx := get_roofs_context()
	key := ctx.keys[id] or_return
	chunk_pos := key.chunk_pos
	chunk := &ctx.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
	return chunk.roofs[key.index], true
}

add_roof :: proc(roof: Roof) -> Roof_Id {
	roof := roof
	roofs := get_roofs_context()
	chunk_pos := get_roof_chunk_pos(roof)
	chunk := &roofs.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
	roof.id = roofs.next_id
	roofs.next_id += 1
	roofs.keys[roof.id] = {
		chunk_pos = chunk_pos,
		index     = len(chunk.roofs),
	}
	append(&chunk.roofs, roof)

	start := glsl.min(roof.start, roof.end)
	end := glsl.max(roof.start, roof.end)
	for x := int(start.x + 0.5);
	    x < int(end.x + 0.5) + c.CHUNK_WIDTH && x < c.WORLD_WIDTH;
	    x += c.CHUNK_WIDTH {
		for z := int(start.y + 0.5);
		    z < int(end.y + 0.5) + c.CHUNK_DEPTH && z < c.WORLD_DEPTH;
		    z += c.CHUNK_DEPTH {
			cx := x / c.CHUNK_WIDTH
			cz := z / c.CHUNK_DEPTH
			append(&roofs.chunks[chunk_pos.y][cx][cz].roofs_inside, roof.id)
		}
	}
	// append(&chunk.roofs_inside, roof.id)

	return roof.id
}

remove_roof :: proc(roof: Roof) {
	ctx := get_roofs_context()
	key := &ctx.keys[roof.id]
	chunk_pos := key.chunk_pos
	chunk := &ctx.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
	chunk.dirty = true

	unordered_remove(&chunk.roofs, key.index)
	if key.index < len(chunk.roofs) {
		moved_id := chunk.roofs[key.index].id
		moved_key := &ctx.keys[moved_id]
		moved_key.index = key.index
	}

	start := glsl.min(roof.start, roof.end)
	end := glsl.max(roof.start, roof.end)
	for x := int(start.x + 0.5);
	    x < int(end.x + 0.5) + c.CHUNK_WIDTH && x < c.WORLD_WIDTH;
	    x += c.CHUNK_WIDTH {
		for z := int(start.y + 0.5);
		    z < int(end.y + 0.5) + c.CHUNK_DEPTH && z < c.WORLD_DEPTH;
		    z += c.CHUNK_DEPTH {
			cx := x / c.CHUNK_WIDTH
			cz := z / c.CHUNK_DEPTH
			current_chunk := &ctx.chunks[chunk_pos.y][cx][cz]
			for id, i in current_chunk.roofs_inside {
				if id == roof.id {
					unordered_remove(&current_chunk.roofs_inside, i)
					break
				}
			}
		}
	}

	delete_key(&ctx.keys, roof.id)
}

update_roof :: proc(roof: Roof) {
	roof := roof
	ctx := get_roofs_context()
	key := &ctx.keys[roof.id]
	chunk_pos := key.chunk_pos
	chunk := &ctx.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
	chunk.dirty = true

	snap_roof(&roof)

	old_roof := chunk.roofs[key.index]
	if old_roof.start != roof.start || old_roof.end != roof.end {
		start := glsl.min(old_roof.start, old_roof.end)
		end := glsl.max(old_roof.start, old_roof.end)

		// log.info(roof.start, roof.end, is_roof_snapable(roof))

		for x := int(start.x + 0.5);
		    x < int(end.x + 0.5) + c.CHUNK_WIDTH && x < c.WORLD_WIDTH;
		    x += c.CHUNK_WIDTH {
			for z := int(start.y + 0.5);
			    z < int(end.y + 0.5) + c.CHUNK_DEPTH && z < c.WORLD_DEPTH;
			    z += c.CHUNK_DEPTH {
				cx := x / c.CHUNK_WIDTH
				cz := z / c.CHUNK_DEPTH
				current_chunk := &ctx.chunks[chunk_pos.y][cx][cz]
				for id, i in current_chunk.roofs_inside {
					if id == roof.id {
						unordered_remove(&current_chunk.roofs_inside, i)
						break
					}
				}
			}
		}

		start = glsl.min(roof.start, roof.end)
		end = glsl.max(roof.start, roof.end)
		for x := int(start.x + 0.5);
		    x < int(end.x + 0.5) + c.CHUNK_WIDTH && x < c.WORLD_WIDTH;
		    x += c.CHUNK_WIDTH {
			for z := int(start.y + 0.5);
			    z < int(end.y + 0.5) + c.CHUNK_DEPTH && z < c.WORLD_DEPTH;
			    z += c.CHUNK_DEPTH {
				cx := x / c.CHUNK_WIDTH
				cz := z / c.CHUNK_DEPTH
				append(&ctx.chunks[chunk_pos.y][cx][cz].roofs_inside, roof.id)
			}
		}
	}
	chunk.roofs[key.index] = roof
}

// @(private = "file")
snap_roof :: proc(roof: ^Roof) {
	if roof.orientation != .Diagonal {
		return 
	}

	size := glsl.abs(roof.end - roof.start)
	max_side := math.max(size.x, size.y)
	min_side := math.min(size.x, size.y)
	size = {max_side / 2 + min_side / 2, max_side / 2 - min_side / 2}

	// log.info(size, glsl.trunc(size) == size)
	if glsl.trunc(size) == size {
	// if glsl.trunc(size) + {0.5, 0.5} == size {
		return
	}
	roof.end.x -= 1
	// return glsl.trunc(size) == size
}

@(private = "file")
get_roof_chunk_pos :: proc(roof: Roof) -> glsl.ivec3 {
	x := i32(roof.start.x + 0.5)
	z := i32(roof.start.y + 0.5)
	chunk_x := x / c.CHUNK_WIDTH

	tile_height := terrain.get_tile_height(int(x), int(z))
	chunk_y := i32((roof.offset - tile_height) / c.WALL_HEIGHT)
	chunk_z := z / c.CHUNK_DEPTH
	return {chunk_x, chunk_y, chunk_z}
}

@(private = "file")
get_longitudinal_roof_face_lights :: proc(
	roof: ^Roof,
	size: glsl.vec2,
) -> [4]glsl.vec4 {
	if roof.start.x <= roof.end.x && roof.start.y <= roof.end.y {
		if size.y >= size.x {
			return(
				 {
					{1, 1, 1, 1},
					{0.8, 0.8, 0.8, 1},
					{0.6, 0.6, 0.6, 1},
					{0.4, 0.4, 0.4, 1},
				} \
			)
		}
		return(
			 {
				{0.4, 0.4, 0.4, 1},
				{1, 1, 1, 1},
				{0.8, 0.8, 0.8, 1},
				{0.6, 0.6, 0.6, 1},
			} \
		)
	} else if roof.start.x <= roof.end.x {
		if size.y < size.x {
			return(
				 {
					{1, 1, 1, 1},
					{0.8, 0.8, 0.8, 1},
					{0.6, 0.6, 0.6, 1},
					{0.4, 0.4, 0.4, 1},
				} \
			)
		}
		return(
			 {
				{0.8, 0.8, 0.8, 1},
				{0.6, 0.6, 0.6, 1},
				{0.4, 0.4, 0.4, 1},
				{1, 1, 1, 1},
			} \
		)
	} else if roof.start.y <= roof.end.y {
		if size.y >= size.x {
			return(
				 {
					{0.6, 0.6, 0.6, 1},
					{0.4, 0.4, 0.4, 1},
					{1, 1, 1, 1},
					{0.8, 0.8, 0.8, 1},
				} \
			)
		}
		return(
			 {
				{0.4, 0.4, 0.4, 1},
				{1, 1, 1, 1},
				{0.8, 0.8, 0.8, 1},
				{0.6, 0.6, 0.6, 1},
			} \
		)
	}
	if size.y >= size.x {
		return(
			 {
				{0.6, 0.6, 0.6, 1},
				{0.4, 0.4, 0.4, 1},
				{1, 1, 1, 1},
				{0.8, 0.8, 0.8, 1},
			} \
		)
	}
	return(
		 {
			{0.8, 0.8, 0.8, 1},
			{0.6, 0.6, 0.6, 1},
			{0.4, 0.4, 0.4, 1},
			{1, 1, 1, 1},
		} \
	)
}

@(private = "file")
get_longitudinal_roof_rotation :: proc(
	roof: ^Roof,
	size: glsl.vec2,
) -> glsl.mat4 {
	if roof.start.x <= roof.end.x && roof.start.y <= roof.end.y {
		if size.y >= size.x {
			return glsl.identity(glsl.mat4)
		}
		return glsl.mat4Rotate({0, 1, 0}, 0.5 * math.PI)
	} else if roof.start.x <= roof.end.x {
		if size.y >= size.x {
			return glsl.identity(glsl.mat4)
		}
		return glsl.mat4Rotate({0, 1, 0}, 1.5 * math.PI)
	} else if roof.start.y <= roof.end.y {
		if size.y >= size.x {
			return glsl.mat4Rotate({0, 1, 0}, 1.0 * math.PI)
		}
		return glsl.mat4Rotate({0, 1, 0}, 0.5 * math.PI)
	}
	if size.y >= size.x {
		return glsl.mat4Rotate({0, 1, 0}, 1.0 * math.PI)
	}
	return glsl.mat4Rotate({0, 1, 0}, 1.5 * math.PI)
}


@(private = "file")
get_diagonal_roof_rotation :: proc(roof: ^Roof, size: glsl.vec2) -> glsl.mat4 {
	if roof.end.x > roof.start.x {
		if roof.end.y > roof.start.y {
			if roof.end.y > roof.start.y + (roof.end.x - roof.start.x) {
				// log.info("1")
				return glsl.mat4Rotate({0, 1, 0}, 0.5 * math.PI)
			}
			// log.info("2")
			return glsl.mat4Rotate({0, 1, 0}, 1.5 * math.PI)
		}

		if roof.end.y > roof.start.y - (roof.end.x - roof.start.x) {
			// log.info("3")
			return glsl.mat4Rotate({0, 1, 0}, 0 * math.PI)
		}

		// log.info("4")
		return glsl.mat4Rotate({0, 1, 0}, 1 * math.PI)
	}

	if roof.end.y > roof.start.y {
		if roof.end.y > roof.start.y + (roof.start.x - roof.end.x) {
			// log.info("5")
			return glsl.mat4Rotate({0, 1, 0}, 0 * math.PI)
		}
		// log.info("6")
		return glsl.mat4Rotate({0, 1, 0}, 1 * math.PI)
	}

	if roof.end.y > roof.start.y - (roof.start.x - roof.end.x) {
		// log.info("7")
		return glsl.mat4Rotate({0, 1, 0}, 0.5 * math.PI)
	}

	// log.info("8")
	return glsl.mat4Rotate({0, 1, 0}, 1.5 * math.PI)
}

@(private = "file")
get_diagonal_roof_face_lights :: proc(
	roof: ^Roof,
	size: glsl.vec2,
) -> [4]glsl.vec4 {
	if roof.end.x > roof.start.x {
		if roof.end.y > roof.start.y {
			if roof.end.y > roof.start.y + (roof.end.x - roof.start.x) {
				return(
					 {
						{0.6, 0.6, 0.6, 1},
						{0.4, 0.4, 0.4, 1},
						{1, 1, 1, 1},
						{0.8, 0.8, 0.8, 1},
					} \
				)
			}
			return(
				 {
					{1, 1, 1, 1},
					{0.8, 0.8, 0.8, 1},
					{0.6, 0.6, 0.6, 1},
					{0.4, 0.4, 0.4, 1},
				} \
			)
		}

		if roof.end.y > roof.start.y - (roof.end.x - roof.start.x) {
			return(
				 {
					{0.4, 0.4, 0.4, 1},
					{1, 1, 1, 1},
					{0.8, 0.8, 0.8, 1},
					{0.6, 0.6, 0.6, 1},
				} \
			)
		}

		return(
			 {
				{0.8, 0.8, 0.8, 1},
				{0.6, 0.6, 0.6, 1},
				{0.4, 0.4, 0.4, 1},
				{1, 1, 1, 1},
			} \
		)
	}

	if roof.end.y > roof.start.y {
		if roof.end.y > roof.start.y + (roof.start.x - roof.end.x) {
			return(
				 {
					{0.4, 0.4, 0.4, 1},
					{1, 1, 1, 1},
					{0.8, 0.8, 0.8, 1},
					{0.6, 0.6, 0.6, 1},
				} \
			)
		}
		return(
			 {
				{0.8, 0.8, 0.8, 1},
				{0.6, 0.6, 0.6, 1},
				{0.4, 0.4, 0.4, 1},
				{1, 1, 1, 1},
			} \
		)
	}

	if roof.end.y > roof.start.y - (roof.start.x - roof.end.x) {
		return(
			 {
				{0.6, 0.6, 0.6, 1},
				{0.4, 0.4, 0.4, 1},
				{1, 1, 1, 1},
				{0.8, 0.8, 0.8, 1},
			} \
		)
	}

	return(
		 {
			{1, 1, 1, 1},
			{0.8, 0.8, 0.8, 1},
			{0.6, 0.6, 0.6, 1},
			{0.4, 0.4, 0.4, 1},
		} \
	)
}

@(private = "file")
draw_roof :: proc(
	id: Roof_Id,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
) {
	ctx := get_roofs_context()
	key := ctx.keys[id]
	roof := &ctx.chunks[key.chunk_pos.y][key.chunk_pos.x][key.chunk_pos.z].roofs[key.index]
	size := glsl.abs(roof.end - roof.start) + ROOF_SIZE_PADDING
	if roof.orientation == .Diagonal {
		size = glsl.abs(roof.end - roof.start)
		max_side := math.max(size.x, size.y)
		min_side := math.min(size.x, size.y)
		size = {max_side / 2 + min_side / 2, max_side / 2 - min_side / 2}
		size += ROOF_SIZE_PADDING
		size *= SQRT_2
	}
	rotation: glsl.mat4
	face_lights: [4]glsl.vec4
	if roof.orientation == .Diagonal {
		rotation = get_diagonal_roof_rotation(roof, size)
		face_lights = get_diagonal_roof_face_lights(roof, size)
	} else {
		rotation = get_longitudinal_roof_rotation(roof, size)
		face_lights = get_longitudinal_roof_face_lights(roof, size)
	}

	for &light in face_lights {
		light *= roof.light
	}

	if roof.orientation == .Diagonal {
		rotation = rotation * glsl.mat4Rotate({0, 1, 0}, 0.25 * math.PI)
	}

	switch roof.type {
	case .Half_Hip:
		draw_half_hip_roof(
			roof,
			vertices,
			indices,
			size,
			rotation,
			face_lights,
		)
	case .Half_Gable:
		draw_half_gable_roof(
			roof,
			vertices,
			indices,
			size,
			rotation,
			face_lights,
		)
	case .Hip:
		draw_hip_roof(roof, vertices, indices, size, rotation, face_lights)
	case .Gable:
		draw_gable_roof(roof, vertices, indices, size, rotation, face_lights)
	}
}

@(private = "file")
draw_half_pyramid_roof :: proc(
	roof: ^Roof,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
	size: glsl.vec2,
	rotation: glsl.mat4,
	face_lights: [4]glsl.vec4,
) {
	center := roof.start + (roof.end - roof.start) / 2
	min_size := min(size.x, size.y)
	max_size := max(size.x, size.y)
	pos_offset := glsl.vec4{min_size / 2, 0, 0, 1} * rotation
	pos := center + pos_offset.xz

	ctx := get_roofs_context()
	color := ctx.color_map[roof.color]
	roof_texture := ctx.texture_array.texture_index_map[color.roof_texture]
	capping_texture :=
		ctx.texture_array.texture_index_map[color.capping_texture]

	face_rotation := rotation
	draw_roof_triangle(
		{pos.x, roof.offset, pos.y},
		{min_size, min_size, max_size / 2},
		false,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[0],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{min_size, 1, max_size},
		face_rotation,
		face_lights[0],
		vertices,
		indices,
	)

	face_rotation = rotation * glsl.mat4Rotate({0, 1, 0}, -1.0 * math.PI)
	draw_roof_triangle(
		{pos.x, roof.offset, pos.y},
		{min_size, min_size, max_size / 2},
		true,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[2],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{min_size, 1, max_size},
		face_rotation,
		face_lights[2],
		vertices,
		indices,
	)

	face_rotation = rotation * glsl.mat4Rotate({0, 1, 0}, -0.5 * math.PI)
	draw_roof_pyramid_face(
		{pos.x, roof.offset, pos.y},
		{max_size / 2, min_size, min_size},
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[1],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{max_size, 1, min_size},
		face_rotation,
		face_lights[1],
		vertices,
		indices,
	)
}

@(private = "file")
draw_half_hip_side_roof :: proc(
	roof: ^Roof,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
	size: glsl.vec2,
	rotation: glsl.mat4,
	face_lights: [4]glsl.vec4,
) {
	center := roof.start + (roof.end - roof.start) / 2
	min_size := min(size.x, size.y)
	max_size := max(size.x, size.y)

	left_pos_offset :=
		glsl.vec4{min_size / 2, 0, (max_size - min_size * 2) / 2, 1} * rotation
	left_pos := center + left_pos_offset.xz
	right_pos_offset :=
		glsl.vec4{min_size / 2, 0, -(max_size - min_size * 2) / 2, 1} *
		rotation
	right_pos := center + right_pos_offset.xz
	middle_pos_offset := glsl.vec4{min_size / 2, 0, 0, 1} * rotation
	middle_pos := center + middle_pos_offset.xz

	ctx := get_roofs_context()
	color := ctx.color_map[roof.color]
	roof_texture := ctx.texture_array.texture_index_map[color.roof_texture]
	capping_texture :=
		ctx.texture_array.texture_index_map[color.capping_texture]

	face_rotation := rotation
	draw_roof_triangle(
		{right_pos.x, roof.offset, right_pos.y},
		{min_size, min_size, min_size},
		false,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[0],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{min_size, 1, max_size},
		face_rotation,
		face_lights[0],
		vertices,
		indices,
	)

	face_rotation = rotation * glsl.mat4Rotate({0, 1, 0}, -0.5 * math.PI)
	draw_roof_triangle(
		{right_pos.x, roof.offset, right_pos.y},
		{min_size, min_size, min_size},
		true,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[1],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_rectangle(
		{middle_pos.x, roof.offset, middle_pos.y},
		{max_size - min_size * 2, min_size, min_size},
		false,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[1],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_triangle(
		{left_pos.x, roof.offset, left_pos.y},
		{min_size, min_size, min_size},
		false,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[1],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{max_size, 1, min_size},
		face_rotation,
		face_lights[1],
		vertices,
		indices,
	)

	face_rotation = rotation * glsl.mat4Rotate({0, 1, 0}, -1.0 * math.PI)
	draw_roof_triangle(
		{left_pos.x, roof.offset, left_pos.y},
		{min_size, min_size, min_size},
		true,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[2],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{min_size, 1, max_size},
		face_rotation,
		face_lights[2],
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset + min_size, center.y},
		{max_size - min_size * 2, 1, min_size},
		rotation * glsl.mat4Rotate({0, 1, 0}, math.PI / 2),
		face_lights[3],
		vertices,
		indices,
	)

	left_gable_pos_offset :=
		glsl.vec4{0, 0, (max_size - min_size) / 2, 1} * rotation
	left_gable_pos := center + left_gable_pos_offset.xz
	draw_roof_gable_eave(
		{left_gable_pos.x, roof.offset, left_gable_pos.y},
		{min_size, min_size * roof.slope, min_size},
		rotation * glsl.mat4Rotate({0, 1, 0}, math.PI / 2),
		face_lights[3],
		true,
		// roof.slope,
		1,
		vertices,
		indices,
	)

	right_gable_pos_offset :=
		glsl.vec4{0, 0, -(max_size - min_size) / 2, 1} * rotation
	right_gable_pos := center + right_gable_pos_offset.xz
	draw_roof_gable_eave(
		{right_gable_pos.x, roof.offset, right_gable_pos.y},
		{min_size, min_size * roof.slope, min_size},
		rotation * glsl.mat4Rotate({0, 1, 0}, math.PI / 2),
		face_lights[3],
		false,
		// roof.slope,
		1,
		vertices,
		indices,
	)
}

@(private = "file")
draw_half_hip_end_roof :: proc(
	roof: ^Roof,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
	size: glsl.vec2,
	rotation: glsl.mat4,
	face_lights: [4]glsl.vec4,
) {
	center := roof.start + (roof.end - roof.start) / 2
	min_size := min(size.x, size.y)
	max_size := max(size.x, size.y)

	// left_pos_offset := glsl.vec4{min_size / 2, 0, (max_size - min_size * 2) / 2, 1} * rotation
	peak_offset := (max_size - min_size) / 2
	peak_pos_offset := glsl.vec4{peak_offset, 0, 0, 1} * rotation
	peak_pos := center + peak_pos_offset.xz
	edge_size := min_size / 2 - peak_offset
	edge_offset := min_size / 4 + peak_offset / 2
	edge_pos_offset := glsl.vec4{edge_offset, 0, 0, 1} * rotation
	edge_pos := center + edge_pos_offset.xz

	ctx := get_roofs_context()
	color := ctx.color_map[roof.color]
	roof_texture := ctx.texture_array.texture_index_map[color.roof_texture]
	capping_texture :=
		ctx.texture_array.texture_index_map[color.capping_texture]

	face_rotation := rotation
	draw_roof_triangle(
		{peak_pos.x, roof.offset, peak_pos.y},
		{min_size / 2 + peak_offset, max_size / 2, max_size / 2},
		false,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[0],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_rectangle(
		{edge_pos.x, roof.offset, edge_pos.y},
		{edge_size, max_size / 2, max_size / 2},
		false,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[0],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{min_size, 1, max_size},
		face_rotation,
		face_lights[0],
		vertices,
		indices,
	)

	face_rotation = rotation * glsl.mat4Rotate({0, 1, 0}, -0.5 * math.PI)
	draw_roof_pyramid_face(
		{peak_pos.x, roof.offset, peak_pos.y},
		{max_size / 2, max_size / 2, min_size / 2 + peak_offset},
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[1],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{max_size, 1, min_size},
		face_rotation,
		face_lights[1],
		vertices,
		indices,
	)

	face_rotation = rotation * glsl.mat4Rotate({0, 1, 0}, -1.0 * math.PI)
	draw_roof_triangle(
		{peak_pos.x, roof.offset, peak_pos.y},
		{min_size / 2 + peak_offset, max_size / 2, max_size / 2},
		true,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[2],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_rectangle(
		{edge_pos.x, roof.offset, edge_pos.y},
		{edge_size, max_size / 2, max_size / 2},
		false,
		face_rotation,
		roof_texture,
		capping_texture,
		face_lights[2],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{min_size, 1, max_size},
		face_rotation,
		face_lights[2],
		vertices,
		indices,
	)

	left_gable_pos_offset := glsl.vec4{0, 0, max_size / 4, 1} * rotation
	left_gable_pos := center + left_gable_pos_offset.xz
	draw_roof_gable_eave(
		{left_gable_pos.x, roof.offset, left_gable_pos.y},
		{max_size / 2, max_size / 2 * roof.slope, min_size},
		rotation * glsl.mat4Rotate({0, 1, 0}, math.PI / 2),
		face_lights[3],
		true,
		// roof.slope,
		1,
		vertices,
		indices,
	)

	right_gable_pos_offset := glsl.vec4{0, 0, -max_size / 4, 1} * rotation
	right_gable_pos := center + right_gable_pos_offset.xz
	draw_roof_gable_eave(
		{right_gable_pos.x, roof.offset, right_gable_pos.y},
		{max_size / 2, max_size / 2 * roof.slope, min_size},
		rotation * glsl.mat4Rotate({0, 1, 0}, math.PI / 2),
		face_lights[3],
		false,
		// roof.slope,
		1,
		vertices,
		indices,
	)
}

@(private = "file")
draw_half_hip_roof :: proc(
	roof: ^Roof,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
	size: glsl.vec2,
	rotation: glsl.mat4,
	face_lights: [4]glsl.vec4,
) {
	ratio := max(size.x, size.y) / min(size.x, size.y)
	if ratio > 2 {
		draw_half_hip_side_roof(
			roof,
			vertices,
			indices,
			size,
			rotation,
			face_lights,
		)
	} else if ratio == 2 {
		draw_half_pyramid_roof(
			roof,
			vertices,
			indices,
			size,
			rotation,
			face_lights,
		)
	} else {
		draw_half_hip_end_roof(
			roof,
			vertices,
			indices,
			size,
			rotation,
			face_lights,
		)
	}
}

@(private = "file")
draw_pyramid_hip_roof :: proc(
	roof: ^Roof,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
	size: glsl.vec2,
	rotation: glsl.mat4,
	face_lights: [4]glsl.vec4,
) {
	height := size.x / 2
	center := roof.start + (roof.end - roof.start) / 2

	ctx := get_roofs_context()
	color := ctx.color_map[roof.color]
	roof_texture := ctx.texture_array.texture_index_map[color.roof_texture]
	capping_texture :=
		ctx.texture_array.texture_index_map[color.capping_texture]

	for i in 0 ..< 4 {
		side_rotation :=
			rotation * glsl.mat4Rotate({0, 1, 0}, f32(i) * (-math.PI / 2))
		pos := center

		face_size := size / 2
		draw_roof_pyramid_face(
			{pos.x, roof.offset, pos.y},
			{face_size.x, height, face_size.y},
			side_rotation,
			roof_texture,
			capping_texture,
			face_lights[i % 4],
			roof.slope,
			vertices,
			indices,
		)

		draw_roof_eave(
			{pos.x, roof.offset, pos.y},
			{size.x, 1, size.y},
			side_rotation,
			face_lights[i % 4],
			vertices,
			indices,
		)

	}
}

@(private = "file")
draw_trapezoid_hip_roof :: proc(
	roof: ^Roof,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
	size: glsl.vec2,
	rotation: glsl.mat4,
	face_lights: [4]glsl.vec4,
) {

	min_size := min(size.y, size.x)
	max_size := max(size.y, size.x)
	height := min(size.x, size.y) / 2
	center := roof.start + (roof.end - roof.start) / 2

	ctx := get_roofs_context()
	color := ctx.color_map[roof.color]
	roof_texture := ctx.texture_array.texture_index_map[color.roof_texture]
	capping_texture :=
		ctx.texture_array.texture_index_map[color.capping_texture]

	for i in 0 ..< 2 {
		side_rotation :=
			rotation * glsl.mat4Rotate({0, 1, 0}, f32(i * 2) * (-math.PI / 2))
		pos_offset := glsl.vec4{0, 0, -(max_size - min_size) / 2, 1}
		pos_offset *= side_rotation
		pos := center + pos_offset.xz

		face_size := glsl.vec2{min_size, min_size} * 0.5
		draw_roof_pyramid_face(
			{pos.x, roof.offset, pos.y},
			{face_size.x, height, face_size.y},
			side_rotation,
			roof_texture,
			capping_texture,
			face_lights[i * 2 % 4],
			roof.slope,
			vertices,
			indices,
		)

		draw_roof_eave(
			{pos.x, roof.offset, pos.y},
			{min_size, 1, min_size},
			side_rotation,
			face_lights[i * 2 % 4],
			vertices,
			indices,
		)
	}

	for i in 0 ..< 2 {
		side_rotation :=
			rotation *
			glsl.mat4Rotate({0, 1, 0}, f32(i * 2 + 1) * (-math.PI / 2))

		draw_roof_hip_face(
			{center.x, roof.offset, center.y},
			{max_size, height, min_size},
			side_rotation,
			roof_texture,
			capping_texture,
			face_lights[(i * 2 + 1) % 4],
			roof.slope,
			vertices,
			indices,
		)

		draw_roof_eave(
			{center.x, roof.offset, center.y},
			{max_size, 1, min_size},
			side_rotation,
			face_lights[(i * 2 + 1) % 4],
			vertices,
			indices,
		)
	}
}

@(private = "file")
draw_hip_roof :: proc(
	roof: ^Roof,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
	size: glsl.vec2,
	rotation: glsl.mat4,
	face_lights: [4]glsl.vec4,
) {
	ratio := max(size.x, size.y) / min(size.x, size.y)
	if ratio == 1 {
		draw_pyramid_hip_roof(
			roof,
			vertices,
			indices,
			size,
			rotation,
			face_lights,
		)
	} else {
		draw_trapezoid_hip_roof(
			roof,
			vertices,
			indices,
			size,
			rotation,
			face_lights,
		)
	}
}

@(private = "file")
draw_half_gable_roof :: proc(
	roof: ^Roof,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
	size: glsl.vec2,
	rotation: glsl.mat4,
	face_lights: [4]glsl.vec4,
) {
	min_size := min(size.y, size.x)
	max_size := max(size.y, size.x)
	height := min(size.x, size.y) / 2
	center := roof.start + (roof.end - roof.start) / 2

	side_rotation := rotation * glsl.mat4Rotate({0, 1, 0}, -math.PI / 2)
	pos_offset := glsl.vec4{0, 0, min_size / 2, 1}
	pos_offset *= side_rotation
	pos := center + pos_offset.xz

	ctx := get_roofs_context()
	color := ctx.color_map[roof.color]
	roof_texture := ctx.texture_array.texture_index_map[color.roof_texture]
	capping_texture :=
		ctx.texture_array.texture_index_map[color.capping_texture]

	draw_roof_rectangle(
		{pos.x, roof.offset, pos.y},
		{max_size, min_size, min_size},
		true,
		side_rotation,
		roof_texture,
		capping_texture,
		face_lights[1],
		roof.slope,
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset, center.y},
		{max_size, 1, min_size},
		side_rotation,
		face_lights[1],
		vertices,
		indices,
	)

	draw_roof_eave(
		{center.x, roof.offset + min_size * roof.slope, center.y},
		{max_size, 1, min_size},
		side_rotation * glsl.mat4Rotate({0, 1, 0}, math.PI),
		face_lights[3],
		vertices,
		indices,
	)

	draw_roof_gable_eave(
		{center.x, roof.offset, center.y},
		{min_size, min_size * roof.slope, max_size},
		side_rotation * glsl.mat4Rotate({0, 1, 0}, math.PI / 2),
		face_lights[0],
		false,
		// roof.slope,
		1,
		vertices,
		indices,
	)

	draw_roof_gable_eave(
		{center.x, roof.offset, center.y},
		{min_size, min_size * roof.slope, max_size},
		side_rotation * glsl.mat4Rotate({0, 1, 0}, -math.PI / 2),
		face_lights[2],
		true,
		// roof.slope,
		1,
		vertices,
		indices,
	)
}

@(private = "file")
draw_gable_roof :: proc(
	roof: ^Roof,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
	size: glsl.vec2,
	rotation: glsl.mat4,
	face_lights: [4]glsl.vec4,
) {
	min_size := min(size.y, size.x)
	max_size := max(size.y, size.x)
	height := min(size.x, size.y) / 2
	center := roof.start + (roof.end - roof.start) / 2

	ctx := get_roofs_context()
	color := ctx.color_map[roof.color]
	roof_texture := ctx.texture_array.texture_index_map[color.roof_texture]
	capping_texture :=
		ctx.texture_array.texture_index_map[color.capping_texture]

	for i in 0 ..< 2 {
		side_rotation :=
			rotation *
			glsl.mat4Rotate({0, 1, 0}, f32((i * 2) + 1) * -math.PI / 2)

		draw_roof_rectangle(
			{center.x, roof.offset, center.y},
			{max_size, min_size / 2, min_size / 2},
			true,
			side_rotation,
			roof_texture,
			capping_texture,
			face_lights[(i * 2 + 1) % 4],
			roof.slope,
			vertices,
			indices,
		)

		draw_roof_eave(
			{center.x, roof.offset, center.y},
			{max_size, 1, min_size},
			side_rotation,
			face_lights[(i * 2 + 1) % 4],
			vertices,
			indices,
		)

		pos_offset := glsl.vec4{0, 0, -min_size / 4, 1} * side_rotation
		pos := center + pos_offset.xz
		draw_roof_gable_eave(
			{pos.x, roof.offset, pos.y},
			{min_size / 2, min_size / 2 * roof.slope, max_size},
			side_rotation * glsl.mat4Rotate({0, 1, 0}, math.PI / 2),
			face_lights[i * 2],
			false,
			// roof.slope,
			1,
			vertices,
			indices,
		)

		draw_roof_gable_eave(
			{pos.x, roof.offset, pos.y},
			{min_size / 2, min_size / 2 * roof.slope, max_size},
			side_rotation * glsl.mat4Rotate({0, 1, 0}, -math.PI / 2),
			face_lights[(i * 2 + 2) % 4],
			true,
			// roof.slope,
			1,
			vertices,
			indices,
		)
	}
}

@(private = "file")
ROOF_CAPPING_SIZE :: 0.1

@(private = "file")
draw_roof_triangle :: proc(
	pos: glsl.vec3,
	size: glsl.vec3,
	mirrored: bool,
	rotation: glsl.mat4,
	roof_texture: f32,
	capping_texture: f32,
	light: glsl.vec4,
	slope: f32,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
) {
	triangle_indices := [?]Roof_Index{0, 1, 2}

	triangle_vertices := [?]Roof_Vertex {
		{pos = {-1, 0, -1}, texcoords = {1, 1, roof_texture}, color = light},
		{pos = {0, 0, -1}, texcoords = {0, 1, roof_texture}, color = light},
		{pos = {0, 1, 0}, texcoords = {0, 0, roof_texture}, color = light},
	}

	capping_vertices := [?]Roof_Vertex {
		 {
			pos = {-1, 0, -1},
			texcoords = {0, 1, capping_texture},
			color = light,
		},
		{pos = {0, 1, 0}, texcoords = {0, 0, capping_texture}, color = light},
	}

	capping_indices := [?]Roof_Index{0, 2, 3, 0, 3, 1}

	mirror := glsl.identity(glsl.mat4)
	if mirrored {
		mirror = glsl.mat4Scale({-1, 1, 1})
		triangle_indices = {2, 1, 0}
		capping_indices = {1, 3, 0, 3, 2, 0}
	}

	transform := mirror * rotation

	index_offset := u32(len(vertices))
	for &vertex in triangle_vertices {
		vertex.pos *= size - ROOF_CAPPING_SIZE
		vertex.pos.y *= slope
		vertex.pos.z -= ROOF_CAPPING_SIZE
		pos4 := glsl.vec4{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}
		vertex.pos = (pos4 * transform).xyz
		vertex.pos += pos
		vertex.texcoords.xy *= size.xy
		vertex.color = light
		append(vertices, vertex)
	}

	for index in triangle_indices {
		append(indices, index + index_offset)
	}

	long_length := glsl.length(
		capping_vertices[0].pos * size - capping_vertices[1].pos * size,
	)
	short_length := glsl.length(
		capping_vertices[0].pos * (size - ROOF_CAPPING_SIZE) -
		capping_vertices[1].pos * (size - ROOF_CAPPING_SIZE),
	)

	index_offset = u32(len(vertices))
	capping_vertices[0].texcoords.xy = {0, 1}
	capping_vertices[1].texcoords.xy = {1, 1}
	for vertex in capping_vertices {
		vertex := vertex
		vertex.pos *= size
		vertex.pos.y *= slope
		pos4 := glsl.vec4{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}
		vertex.pos = (pos4 * transform).xyz
		vertex.pos += pos
		vertex.texcoords.x *= long_length
		vertex.color = light
		append(vertices, vertex)
	}
	length_ratio := (1 - short_length / long_length) / 2

	capping_vertices[0].texcoords.xy = {length_ratio, 0}
	capping_vertices[1].texcoords.xy = {1 - length_ratio, 0}
	for vertex in capping_vertices {
		vertex := vertex
		vertex.pos *= size - ROOF_CAPPING_SIZE
		vertex.pos.y *= slope
		vertex.pos.z -= ROOF_CAPPING_SIZE
		pos4 := glsl.vec4{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}
		vertex.pos = (pos4 * transform).xyz
		vertex.pos += pos
		vertex.texcoords.x *= long_length
		vertex.color = light
		append(vertices, vertex)
	}

	for index in capping_indices {
		append(indices, index + index_offset)
	}
}

@(private = "file")
draw_roof_rectangle :: proc(
	pos: glsl.vec3,
	size: glsl.vec3,
	mirrored: bool,
	rotation: glsl.mat4,
	roof_texture: f32,
	capping_texture: f32,
	light: glsl.vec4,
	slope: f32,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
) {
	rectangle_indices := [?]Roof_Index{0, 1, 2, 0, 2, 3}

	rectangle_vertices := [?]Roof_Vertex {
		{pos = {-0.5, 0, -1}, texcoords = {1, 1, roof_texture}, color = light},
		{pos = {0.5, 0, -1}, texcoords = {0, 1, roof_texture}, color = light},
		{pos = {0.5, 1, 0}, texcoords = {0, 0, roof_texture}, color = light},
		{pos = {-0.5, 1, 0}, texcoords = {1, 0, roof_texture}, color = light},
	}

	capping_vertices := [?]Roof_Vertex {
		 {
			pos = {-0.5, 1, 0},
			texcoords = {0, 1, capping_texture},
			color = light,
		},
		 {
			pos = {0.5, 1, 0},
			texcoords = {1, 1, capping_texture},
			color = light,
		},
	}

	capping_indices := [?]Roof_Index{0, 2, 3, 0, 3, 1}

	mirror := glsl.identity(glsl.mat4)
	if mirrored {
		mirror = glsl.mat4Scale({-1, 1, 1})
		rectangle_indices = {3, 2, 0, 2, 1, 0}
		capping_indices = {1, 3, 0, 3, 2, 0}
	}

	transform := mirror * rotation

	index_offset := u32(len(vertices))
	for &vertex in rectangle_vertices {
		vertex.pos.zy *= size.zy - ROOF_CAPPING_SIZE
		vertex.pos.x *= size.x
		vertex.pos.y *= slope
		vertex.pos.z -= ROOF_CAPPING_SIZE
		pos4 := glsl.vec4{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}
		vertex.pos = (pos4 * transform).xyz
		vertex.pos += pos
		vertex.texcoords.xy *= size.xy
		vertex.color = light
		append(vertices, vertex)
	}

	for index in rectangle_indices {
		append(indices, index + index_offset)
	}

	index_offset = u32(len(vertices))
	capping_vertices[0].texcoords.y = 1
	capping_vertices[1].texcoords.y = 1
	for vertex in capping_vertices {
		vertex := vertex
		vertex.pos *= size
		vertex.pos.y *= slope
		pos4 := glsl.vec4{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}
		vertex.pos = (pos4 * transform).xyz
		vertex.pos += pos
		vertex.texcoords.x *= size.x
		vertex.color = light
		append(vertices, vertex)
	}

	capping_vertices[0].texcoords.y = 0
	capping_vertices[1].texcoords.y = 0
	for vertex in capping_vertices {
		vertex := vertex
		vertex.pos.zy *= size.zy - ROOF_CAPPING_SIZE
		vertex.pos.x *= size.x
		vertex.pos.y *= slope
		vertex.pos.z -= ROOF_CAPPING_SIZE
		pos4 := glsl.vec4{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}
		vertex.pos = (pos4 * transform).xyz
		vertex.pos += pos
		vertex.texcoords.x *= size.x
		vertex.color = light
		append(vertices, vertex)
	}

	for index in capping_indices {
		append(indices, index + index_offset)
	}
}


@(private = "file")
EAVE_VERTICES :: [?]Roof_Vertex {
	{pos = {-0.5, -0.2, -0.5}, texcoords = {0, 1, 0}, color = {1, 1, 1, 1}},
	{pos = {0.5, -0.2, -0.5}, texcoords = {1, 1, 0}, color = {1, 1, 1, 1}},
	{pos = {0.5, 0, -0.5}, texcoords = {0, 0, 0}, color = {1, 1, 1, 1}},
	{pos = {-0.5, 0, -0.5}, texcoords = {1, 0, 0}, color = {1, 1, 1, 1}},
}

@(private = "file")
EAVE_INDICES :: [?]Roof_Index{0, 1, 2, 0, 2, 3}

@(private = "file")
draw_roof_eave :: proc(
	pos: glsl.vec3,
	size: glsl.vec3,
	rotation: glsl.mat4,
	light: glsl.vec4,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
) {
	index_offset := u32(len(vertices))
	eave_vertices := EAVE_VERTICES
	eave_indices := EAVE_INDICES

	for &vertex in eave_vertices {
		vertex.pos *= size
		pos4 := glsl.vec4{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}
		vertex.pos = (pos4 * rotation).xyz
		vertex.texcoords.x *= size.x
		vertex.pos += pos
		vertex.color = light
		append(vertices, vertex)
	}

	for index in eave_indices {
		append(indices, index + index_offset)
	}
}

@(private = "file")
draw_roof_gable_eave :: proc(
	pos: glsl.vec3,
	size: glsl.vec3,
	rotation: glsl.mat4,
	light: glsl.vec4,
	mirror: bool,
	slope: f32,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
) {
	index_offset := u32(len(vertices))
	eave_vertices := EAVE_VERTICES
	eave_indices := EAVE_INDICES

	eave_vertices[0].pos.y *= slope
	eave_vertices[1].pos.y *= slope

	if mirror {
		eave_vertices[0].pos.y += size.y
		eave_vertices[3].pos.y += size.y
	} else {
		eave_vertices[1].pos.y += size.y
		eave_vertices[2].pos.y += size.y
	}

	for &vertex in eave_vertices {
		vertex.pos.xz *= size.xz
		pos4 := glsl.vec4{vertex.pos.x, vertex.pos.y, vertex.pos.z, 1}
		vertex.pos = (pos4 * rotation).xyz
		vertex.texcoords.x *= size.x
		vertex.pos += pos
		vertex.color = light
		append(vertices, vertex)
	}

	for index in eave_indices {
		append(indices, index + index_offset)
	}
}

@(private = "file")
draw_roof_pyramid_face :: proc(
	pos: glsl.vec3,
	size: glsl.vec3,
	rotation: glsl.mat4,
	roof_texture: f32,
	capping_texture: f32,
	light: glsl.vec4,
	slope: f32,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
) {
	draw_roof_triangle(
		pos,
		size,
		false,
		rotation,
		roof_texture,
		capping_texture,
		light,
		slope,
		vertices,
		indices,
	)
	draw_roof_triangle(
		pos,
		size,
		true,
		rotation,
		roof_texture,
		capping_texture,
		light,
		slope,
		vertices,
		indices,
	)
}

@(private = "file")
draw_roof_hip_face :: proc(
	pos: glsl.vec3,
	size: glsl.vec3,
	rotation: glsl.mat4,
	roof_texture: f32,
	capping_texture: f32,
	light: glsl.vec4,
	slope: f32,
	vertices: ^[dynamic]Roof_Vertex,
	indices: ^[dynamic]Roof_Index,
) {
	min_size := min(size.z, size.x)
	max_size := max(size.z, size.x)

	face_size := glsl.vec2{min_size, min_size} * 0.5

	pos_offset := glsl.vec4{-(max_size - min_size) / 2, 0, 0, 1}
	pos_offset *= rotation
	face_pos := pos + pos_offset.xyz
	draw_roof_triangle(
		face_pos,
		{face_size.x, size.y, face_size.y},
		false,
		rotation,
		roof_texture,
		capping_texture,
		light,
		slope,
		vertices,
		indices,
	)

	pos_offset = glsl.vec4{(max_size - min_size) / 2, 0, 0, 1}
	pos_offset *= rotation
	face_pos = pos + pos_offset.xyz
	draw_roof_triangle(
		face_pos,
		{face_size.x, size.y, face_size.y},
		true,
		rotation,
		roof_texture,
		capping_texture,
		light,
		slope,
		vertices,
		indices,
	)

	face_size = glsl.vec2{max_size - min_size, min_size / 2}
	draw_roof_rectangle(
		pos,
		{face_size.x, size.y, face_size.y},
		true,
		rotation,
		roof_texture,
		capping_texture,
		light,
		slope,
		vertices,
		indices,
	)
}


@(private = "file")
ROOF_COLORS_DIR :: "resources/roofs/colors/"

@(private = "file")
init_roof_colors :: proc() -> bool {
	roofs := get_roofs_context()

	read_roof_colors_dir(ROOF_COLORS_DIR) or_return

	roofs.texture_array.texture_index_map[EAVE_TEXTURE] = 0

	for k, v in roofs.color_map {
		if !(v.roof_texture in roofs.texture_array.texture_index_map) {
			i := len(roofs.texture_array.texture_index_map)
			roofs.texture_array.texture_index_map[v.roof_texture] = f32(i)
		}

		if !(v.capping_texture in roofs.texture_array.texture_index_map) {
			i := len(roofs.texture_array.texture_index_map)
			roofs.texture_array.texture_index_map[v.capping_texture] = f32(i)
		}
	}

	return true
}

@(private = "file")
read_roof_colors_dir :: proc(path: string) -> bool {
	dir, err := os.open(path)
	defer os.close(dir)
	if err != nil {
		log.fatal("Failed to open", path)
		return false
	}

	if !os.is_dir(dir) {
		log.fatal(path, "is not a dir!")
		return false
	}

	file_infos, err1 := os.read_dir(dir, 0, allocator = context.temp_allocator)
	// defer delete(file_infos)
	if err1 != nil {
		log.fatal("Failed to read", path)
	}

	for file_info in file_infos {
		// defer delete(file_info.fullpath)
		if file_info.is_dir {
			read_roof_colors_dir(file_info.fullpath) or_return
		} else if filepath.ext(file_info.name) == ".json" {
			read_roof_color_json(file_info.fullpath) or_return
		}
	}
	return true
}

@(private = "file")
read_roof_color_json :: proc(pathname: string) -> bool {
	data := os.read_entire_file_from_filename(
		pathname,
		allocator = context.temp_allocator,
	) or_return

	roof_color: Roof_Color

	err := json.unmarshal(
		data,
		&roof_color,
		allocator = context.temp_allocator,
	)
	if err != nil {
		return false
	}

	dir := filepath.dir(pathname, allocator = context.temp_allocator)
	roof_texture := roof_color.roof_texture
	if !strings.starts_with(roof_texture, "resources/") {
		roof_texture = filepath.join(
			{dir, roof_color.roof_texture},
			allocator = context.temp_allocator,
		)
	}
	capping_texture := roof_color.capping_texture
	if !strings.starts_with(capping_texture, "resources/") {
		capping_texture = filepath.join(
			{dir, roof_color.capping_texture},
			allocator = context.temp_allocator,
		)
	}

	roof_color.roof_texture = strings.clone(roof_texture)
	roof_color.capping_texture = strings.clone(capping_texture)
	roof_color.key = strings.clone(roof_color.key)
	roof_color.name = strings.clone(roof_color.name)
	log.info(roof_color)

	ctx := get_roofs_context()
	ctx.color_map[roof_color.key] = roof_color
	return true
}
