package game

import "base:runtime"
import "core:log"
import "core:math/linalg/glsl"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"
import stbi "vendor:stb/image"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 1
RENDERER_VERTEX_SHADER_PATH :: "resources/shaders/shader.vert"
RENDERER_FRAGMENT_SHADER_PATH :: "resources/shaders/shader.frag"

Renderer :: struct {
	vbo, vao, ubo:       u32,
	shader_program:      u32,
	uniform_object:      Renderer_Uniform_Object,
	framebuffer_resized: bool,
}

Renderer_Vertex :: struct {
	pos:       glsl.vec3,
	light:     glsl.vec3,
	texcoords: glsl.vec4,
}

Renderer_Uniform_Object :: struct {
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

renderer :: proc() -> ^Renderer {
    return &game().renderer
}

renderer_init :: proc() -> (ok: bool = true) {
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

	gl.GenVertexArrays(1, &renderer().vao)
	gl.BindVertexArray(renderer().vao)

	gl.GenBuffers(1, &renderer().vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, renderer().vbo)

	gl.GenBuffers(1, &renderer().ubo)
	gl.BindBuffer(gl.UNIFORM_BUFFER, renderer().ubo)
	gl.BufferData(
		gl.UNIFORM_BUFFER,
		size_of(Renderer_Uniform_Object),
		nil,
		gl.STATIC_DRAW,
	)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, renderer().ubo)

	gl.VertexAttribPointer(
		0,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Renderer_Vertex),
		offset_of(Renderer_Vertex, pos),
	)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(
		1,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Renderer_Vertex),
		offset_of(Renderer_Vertex, light),
	)
	gl.EnableVertexAttribArray(1)

	gl.VertexAttribPointer(
		2,
		4,
		gl.FLOAT,
		gl.FALSE,
		size_of(Renderer_Vertex),
		offset_of(Renderer_Vertex, texcoords),
	)
	gl.EnableVertexAttribArray(2)

	// gl.VertexAttribPointer(
	// 	3,
	// 	1,
	// 	gl.FLOAT,
	// 	gl.FALSE,
	// 	size_of(Renderer_Vertex),
	// 	offset_of(Renderer_Vertex, depth_map),
	// )
	// gl.EnableVertexAttribArray(3)

	renderer().shader_program = load_shader_program(
		RENDERER_VERTEX_SHADER_PATH,
		RENDERER_FRAGMENT_SHADER_PATH,
	) or_return

    gl.UseProgram(renderer().shader_program)

	texture_sampler_loc := gl.GetUniformLocation(
		renderer().shader_program,
		"texture_sampler",
	)

	mask_sampler_loc := gl.GetUniformLocation(renderer().shader_program, "mask_sampler")

	gl.Uniform1i(texture_sampler_loc, 0)
	gl.Uniform1i(mask_sampler_loc, 1)

	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
	// gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)
	// gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	return
}

renderer_deinit :: proc() {
	gl.DeleteBuffers(1, &renderer().vao)
	gl.DeleteBuffers(1, &renderer().vbo)
	gl.DeleteBuffers(1, &renderer().ubo)
	gl.DeleteProgram(renderer().shader_program)
}

renderer_begin_draw :: proc() {
	if (renderer().framebuffer_resized) {
		width, height := glfw.GetWindowSize(window().handle)
		gl.Viewport(0, 0, width, height)
	}

	renderer().framebuffer_resized = false

	gl.ClearColor(0.0, 0.0, 0.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
}

renderer_end_draw :: proc() {
	glfw.SwapBuffers(window().handle)

	gl_error := gl.GetError()
	if (gl_error != gl.NO_ERROR) {
		log.error("error?: ", gl_error)
	}
}
