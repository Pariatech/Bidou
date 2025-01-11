package game

import "core:math"
import "core:math/linalg/glsl"
import "core:slice"

import gl "vendor:OpenGL"

import "../camera"

Object_Draw_Id :: int

Object_Draw_Key :: struct {
	chunk_pos: glsl.ivec3,
	index:     int,
}

Object_Draw :: struct {
	id:        Object_Draw_Id,
	pos:       glsl.vec3,
	transform: glsl.mat4,
	light:     glsl.vec3,
	model:     string,
	texture:   string,
}

Object_Draw_Chunk :: struct {
	draws: [dynamic]Object_Draw,
	dirty: bool,
}

Object_Draws :: struct {
	keys:    map[Object_Draw_Id]Object_Draw_Key,
	next_id: Object_Draw_Id,
	chunks:  [WORLD_HEIGHT][WORLD_CHUNK_WIDTH][WORLD_CHUNK_DEPTH]Object_Draw_Chunk,
	ubo:     u32,
	shader:  Shader,
}

OBJECT_SHADER :: Shader {
	vertex   = "resources/shaders/object.vert",
	fragment = "resources/shaders/object.frag",
}

init_object_draws :: proc() -> bool {
	ctx := get_object_draws_context()

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)


	// renderer.load_shader_program(
	// 	&shader_program,
	// 	OBJECT_VERTEX_SHADER_PATH,
	// 	OBJECT_FRAGMENT_SHADER_PATH,
	// ) or_return
	ctx.shader = OBJECT_SHADER
	init_shader(&ctx.shader) or_return

	// gl.Uniform1i(gl.GetUniformLocation(shader_program, "texture_sampler"), 0)
	set_shader_uniform(&ctx.shader, "texture_sampler", i32(0))

	gl.GenBuffers(1, &ctx.ubo)

	gl.BindVertexArray(0)
	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
	gl.UseProgram(0)

	return true
}

deinit_object_draws :: proc() {
	ctx := get_object_draws_context()

	delete(ctx.keys)
	for &row in ctx.chunks {
		for &col in row {
			for chunk in col {
				delete(chunk.draws)
			}
		}
	}
}

draw_object :: proc(object: ^Object_Draw) -> bool {
	// translate := glsl.mat4Translate(object.pos)
	// rotation_radian := f32(object.orientation) * 0.5 * math.PI
	// rotation := glsl.mat4Rotate({0, 1, 0}, rotation_radian)
	// translate * rotation
	uniform_object := Object_Uniform_Object {
		mvp   = camera.view_proj * object.transform,
		light = object.light,
	}

	gl.BufferData(
		gl.UNIFORM_BUFFER,
		size_of(Object_Uniform_Object),
		&uniform_object,
		gl.STATIC_DRAW,
	)

	gl.ActiveTexture(gl.TEXTURE0)
	bind_texture(object.texture) or_return
    defer gl.BindTexture(gl.TEXTURE_2D, 0)

	bind_model(object.model) or_return
	draw_model(object.model)

	return true
}

object_draws_sort :: proc(a: Object_Draw, b: Object_Draw) -> bool {
	switch camera.rotation {
	case .South_West:
		return(
			a.pos.x == b.pos.x && a.pos.z == b.pos.z && a.pos.y < b.pos.y ||
			a.pos.x == b.pos.x && a.pos.z > b.pos.z ||
			a.pos.x > b.pos.x \
		)
	case .South_East:
		return(
			a.pos.x == b.pos.x && a.pos.z == b.pos.z && a.pos.y < b.pos.y ||
			a.pos.x == b.pos.x && a.pos.z > b.pos.z ||
			a.pos.x < b.pos.x \
		)
	case .North_East:
		return(
			a.pos.x == b.pos.x && a.pos.z == b.pos.z && a.pos.y < b.pos.y ||
			a.pos.x == b.pos.x && a.pos.z < b.pos.z ||
			a.pos.x < b.pos.x \
		)
	case .North_West:
		return(
			a.pos.x == b.pos.x && a.pos.z == b.pos.z && a.pos.y < b.pos.y ||
			a.pos.x == b.pos.x && a.pos.z < b.pos.z ||
			a.pos.x > b.pos.x \
		)
	}
	return true
}

draw_chunk :: proc(chunk: ^Object_Draw_Chunk) -> bool {
	ctx := get_object_draws_context()

	if len(chunk.draws) == 0 {
		return true
	}

	if chunk.dirty {
		slice.sort_by(chunk.draws[:], object_draws_sort)
		for draw, i in chunk.draws {
			key := &ctx.keys[draw.id]
			key.index = i
		}
		chunk.dirty = false
	}

	for &object in chunk.draws {
		draw_object(&object) or_return
	}

	return true
}

draw_objects :: proc(floor: i32) -> bool {
	ctx := get_object_draws_context()

	gl.BindBuffer(gl.UNIFORM_BUFFER, ctx.ubo)
	set_shader_unifrom_block_binding(&ctx.shader, "UniformBufferObject", 2)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, ctx.ubo)

	// gl.Enable(gl.BLEND)
	// gl.BlendEquation(gl.FUNC_ADD)
	// gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	// gl.Disable(gl.MULTISAMPLE)

	bind_shader(&ctx.shader)
	// gl.UseProgram(shader_program)

	// for floor in 0 ..= floor.floor {
		it := camera.make_visible_chunk_iterator()
		for pos in it->next() {
			draw_chunk(&ctx.chunks[floor][pos.x][pos.y]) or_return
		}
	// }

	return true
}

draw_one_object :: proc(object: ^Object_Draw) -> bool {
	ctx := get_object_draws_context()

	gl.BindBuffer(gl.UNIFORM_BUFFER, ctx.ubo)
	set_shader_unifrom_block_binding(&ctx.shader, "UniformBufferObject", 2)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, ctx.ubo)

	bind_shader(&ctx.shader)

	draw_object(object) or_return

    return true
}

create_object_draw :: proc(draw: Object_Draw) -> Object_Draw_Id {
	draw := draw
	ctx := get_object_draws_context()
	draw.id = ctx.next_id
	ctx.next_id += 1

	chunk_pos := world_pos_to_chunk_pos(draw.pos)
	chunk := &ctx.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
	chunk.dirty = true

	index := len(chunk.draws)
	append(&chunk.draws, draw)

	ctx.keys[draw.id] = {chunk_pos, index}

	return draw.id
}

update_object_draw :: proc(update: Object_Draw) {
	ctx := get_object_draws_context()
	key := &ctx.keys[update.id]
	chunk_pos := key.chunk_pos
	chunk := &ctx.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
	chunk.dirty = true

	existing := &chunk.draws[key.index]
	if existing.pos != update.pos {
		update_chunk_pos := world_pos_to_chunk_pos(update.pos)
		if update_chunk_pos != chunk_pos {
			// move object across chunks if needed
			unordered_remove(&chunk.draws, key.index)
			if key.index < len(chunk.draws) {
				draw := chunk.draws[key.index]
				moved_key := &ctx.keys[draw.id]
				moved_key.index = key.index
			}

			chunk := &ctx.chunks[update_chunk_pos.y][update_chunk_pos.x][update_chunk_pos.z]
			chunk.dirty = true

			key.chunk_pos = update_chunk_pos
			key.index = len(chunk.draws)
			append(&chunk.draws, update)
			return
		}
	}

	existing^ = update
}

delete_object_draw :: proc(id: Object_Draw_Id) {
	ctx := get_object_draws_context()
	key := &ctx.keys[id]
	chunk_pos := key.chunk_pos
	chunk := &ctx.chunks[chunk_pos.y][chunk_pos.x][chunk_pos.z]
	chunk.dirty = true

	unordered_remove(&chunk.draws, key.index)
	if key.index < len(chunk.draws) {
		draw := chunk.draws[key.index]
		moved_key := &ctx.keys[draw.id]
		moved_key.index = key.index
	}
}

object_draw_from_object :: proc(
	obj: Object,
	cursor: bool = false,
) -> Object_Draw {
	draw: Object_Draw
	switch obj.orientation {
	case .South, .North:
		switch camera.rotation {
		case .South_West:
			draw.pos = obj.pos + {f32(obj.size.x) / 2, 0, f32(obj.size.z) / 2}
		case .South_East:
			draw.pos = obj.pos + {-f32(obj.size.x) / 2, 0, f32(obj.size.z) / 2}
		case .North_East:
			draw.pos = obj.pos + {-f32(obj.size.x), 0, -f32(obj.size.z) / 2}
		case .North_West:
			draw.pos = obj.pos + {f32(obj.size.x), 0, -f32(obj.size.z) / 2}
		}
	case .East, .West:
		switch camera.rotation {
		case .South_West:
			draw.pos = obj.pos + {f32(obj.size.z) / 2, 0, f32(obj.size.x) / 2}
		case .South_East:
			draw.pos = obj.pos + {-f32(obj.size.z) / 2, 0, f32(obj.size.x) / 2}
		case .North_East:
			draw.pos = obj.pos + {-f32(obj.size.z), 0, -f32(obj.size.x) / 2}
		case .North_West:
			draw.pos = obj.pos + {f32(obj.size.z), 0, -f32(obj.size.x) / 2}
		}
	}

	translate := glsl.mat4Translate(obj.pos)
	rotation_radian := f32(obj.orientation) * 0.5 * math.PI
	rotation := glsl.mat4Rotate({0, 1, 0}, rotation_radian)
	draw.transform = translate * rotation

	draw.model = obj.model
	draw.texture = obj.texture
	draw.light = obj.light
	draw.id = obj.draw_id

	return draw
}
