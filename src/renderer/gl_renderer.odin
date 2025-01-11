package renderer

import "base:runtime"
import "core:log"
import "core:math/linalg/glsl"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"
import stbi "vendor:stb/image"

import "../window"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 1
VERTEX_SHADER_PATH :: "resources/shaders/shader.vert"
FRAGMENT_SHADER_PATH :: "resources/shaders/shader.frag"

vbo, vao, ubo: u32
shader_program: u32
world_vertices: [dynamic]Vertex
world_indices: [dynamic]u32
uniform_object: Uniform_Object
framebuffer_resized: bool

Vertex :: struct {
	pos:       glsl.vec3,
	light:     glsl.vec3,
	texcoords: glsl.vec4,
	depth_map: f32,
}

Uniform_Object :: struct {
	proj, view: glsl.mat4,
}

gl_debug_callback :: proc "c" (
	source: u32,
	type: u32,
	id: u32,
	severity: u32,
	length: i32,
	message: cstring,
	userParam: rawptr,
) {
	context = runtime.default_context()
	log.debug("OpenGL Debug: ", message)
}


init :: proc() -> (ok: bool = true) {
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	gl.Enable(gl.MULTISAMPLE)
	// gl.Disable(gl.MULTISAMPLE)

	when ODIN_DEBUG && ODIN_OS != .Darwin {
		gl.Enable(gl.DEBUG_OUTPUT)
	}
	// gl.DebugMessageCallback(gl_debug_callback, nil)

	gl.Enable(gl.DEPTH_TEST)
	gl.DepthFunc(gl.LEQUAL)

	gl.Enable(gl.BLEND)
	gl.BlendEquation(gl.FUNC_ADD)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    gl.Enable(gl.CULL_FACE)
    gl.CullFace(gl.BACK)
    gl.FrontFace(gl.CCW)

	// gl.BindTexture(gl.TEXTURE_2D_ARRAY, 0)

	// gl.BindTexture(gl.TEXTURE_2D_ARRAY, 0)

	// gl.BindTexture(gl.TEXTURE_2D_ARRAY, depth_map_texture_array)
	// gl.ActiveTexture(gl.TEXTURE1)

	log.debug(gl.GetString(gl.VERSION))

	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	gl.GenBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

	gl.GenBuffers(1, &ubo)
	gl.BindBuffer(gl.UNIFORM_BUFFER, ubo)
	gl.BufferData(
		gl.UNIFORM_BUFFER,
		size_of(Uniform_Object),
		nil,
		gl.STATIC_DRAW,
	)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, ubo)

	gl.VertexAttribPointer(
		0,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		offset_of(Vertex, pos),
	)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(
		1,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		offset_of(Vertex, light),
	)
	gl.EnableVertexAttribArray(1)

	gl.VertexAttribPointer(
		2,
		4,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		offset_of(Vertex, texcoords),
	)
	gl.EnableVertexAttribArray(2)

	gl.VertexAttribPointer(
		3,
		1,
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		offset_of(Vertex, depth_map),
	)
	gl.EnableVertexAttribArray(3)

	load_shader_program(
		&shader_program,
		VERTEX_SHADER_PATH,
		FRAGMENT_SHADER_PATH,
	) or_return

	texture_sampler_loc := gl.GetUniformLocation(
		shader_program,
		"texture_sampler",
	)

	mask_sampler_loc := gl.GetUniformLocation(shader_program, "mask_sampler")

	gl.Uniform1i(texture_sampler_loc, 0)
	gl.Uniform1i(mask_sampler_loc, 1)

	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
	// gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)
	// gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	return
}

deinit :: proc() {
	gl.DeleteBuffers(1, &vao)
	gl.DeleteBuffers(1, &vbo)
	gl.DeleteBuffers(1, &ubo)
	gl.DeleteProgram(shader_program)
}

begin_draw :: proc() {
	if (framebuffer_resized) {
		width, height := glfw.GetWindowSize(window.handle)
		gl.Viewport(0, 0, width, height)
	}

	framebuffer_resized = false

	gl.ClearColor(0.0, 0.0, 0.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
}

end_draw :: proc() {
	glfw.SwapBuffers(window.handle)

	gl_error := gl.GetError()
	if (gl_error != gl.NO_ERROR) {
		log.error("error?: ", gl_error)
	}
}

draw_triangle :: proc(v0, v1, v2: Vertex) {
	index_offset := u32(len(world_vertices))
	append(&world_vertices, v0, v1, v2)
	append(
		&world_indices,
		index_offset + 0,
		index_offset + 1,
		index_offset + 2,
	)
}

draw_quad :: proc(v0, v1, v2, v3: Vertex) {
	index_offset := u32(len(world_vertices))
	append(&world_vertices, v0, v1, v2, v3)
	append(
		&world_indices,
		index_offset + 0,
		index_offset + 1,
		index_offset + 2,
		index_offset + 0,
		index_offset + 2,
		index_offset + 3,
	)
}

draw_mesh :: proc(verts: []Vertex, idxs: []u32) {
	index_offset := u32(len(world_vertices))
	append(&world_vertices, ..verts)
	for idx in idxs {
		append(&world_indices, idx + index_offset)
	}
}
