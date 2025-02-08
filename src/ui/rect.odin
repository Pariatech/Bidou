package ui

import "core:log"
import "core:math/linalg/glsl"

import gl "vendor:OpenGL"

import "../game"

RECT_VERTEX_SHADER :: "resources/shaders/ui/rect.vert"
RECT_FRAGMENT_SHADER :: "resources/shaders/ui/rect.frag"

RECT_QUAD_VERTICES := [?]Rect_Vertex {
	{pos = {-1, -1}, color = {1, 1, 1, 1}},
	{pos = {1, -1}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, color = {1, 1, 1, 1}},
	{pos = {-1, -1}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, color = {1, 1, 1, 1}},
	{pos = {-1, 1}, color = {1, 1, 1, 1}},
}

Rect_Vertex :: struct {
	pos:                 glsl.vec2,
	start:               glsl.vec2,
	end:                 glsl.vec2,
	color:               glsl.vec4,
	left_border_width:   f32,
	right_border_width:  f32,
	top_border_width:    f32,
	bottom_border_width: f32,
}

Rect_Renderer :: struct {
	vbo, vao: u32,
	shader:   u32,
}

Rect :: struct {
	x, y, w, h:          f32,
	color:               glsl.vec4,
	left_border_width:   f32,
	right_border_width:  f32,
	top_border_width:    f32,
	bottom_border_width: f32,
}

Rect_Draw_Call :: Rect

init_rect_renderer :: proc(using ctx: ^Context) -> (ok: bool = false) {
	using ctx.rect_renderer

	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)
	defer gl.BindVertexArray(0)

	gl.GenBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(RECT_QUAD_VERTICES) * size_of(Rect_Vertex),
		nil,
		gl.STATIC_DRAW,
	)

	shader = game.load_shader_program(
		RECT_VERTEX_SHADER,
		RECT_FRAGMENT_SHADER,
	) or_return
	defer gl.UseProgram(0)

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(
		0,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Rect_Vertex),
		offset_of(Rect_Vertex, pos),
	)

	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(
		1,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Rect_Vertex),
		offset_of(Rect_Vertex, start),
	)

	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(
		2,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Rect_Vertex),
		offset_of(Rect_Vertex, end),
	)

	gl.EnableVertexAttribArray(3)
	gl.VertexAttribPointer(
		3,
		4,
		gl.FLOAT,
		gl.FALSE,
		size_of(Rect_Vertex),
		offset_of(Rect_Vertex, color),
	)

	gl.EnableVertexAttribArray(4)
	gl.VertexAttribPointer(
		4,
		1,
		gl.FLOAT,
		gl.FALSE,
		size_of(Rect_Vertex),
		offset_of(Rect_Vertex, left_border_width),
	)

	gl.EnableVertexAttribArray(5)
	gl.VertexAttribPointer(
		5,
		1,
		gl.FLOAT,
		gl.FALSE,
		size_of(Rect_Vertex),
		offset_of(Rect_Vertex, right_border_width),
	)

	gl.EnableVertexAttribArray(6)
	gl.VertexAttribPointer(
		6,
		1,
		gl.FLOAT,
		gl.FALSE,
		size_of(Rect_Vertex),
		offset_of(Rect_Vertex, top_border_width),
	)

	gl.EnableVertexAttribArray(7)
	gl.VertexAttribPointer(
		7,
		1,
		gl.FLOAT,
		gl.FALSE,
		size_of(Rect_Vertex),
		offset_of(Rect_Vertex, bottom_border_width),
	)

	return true
}

draw_rect :: proc(using ctx: ^Context, rect: Rect) {
	using rect_renderer

	gl.Disable(gl.DEPTH_TEST)
	defer gl.Enable(gl.DEPTH_TEST)

	gl.BindVertexArray(vao)
	defer gl.BindVertexArray(0)

	gl.UseProgram(shader)
	defer gl.UseProgram(0)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	vertices := RECT_QUAD_VERTICES

	vertices[0].pos = to_screen_pos({rect.x, rect.y})
	vertices[1].pos = to_screen_pos({rect.x + rect.w, rect.y})
	vertices[2].pos = to_screen_pos({rect.x + rect.w, rect.y + rect.h})
	vertices[3] = vertices[0]
	vertices[4] = vertices[2]
	vertices[5].pos = to_screen_pos({rect.x, rect.y + rect.h})

	// log.info(rect)
	for &v in vertices {
		v.start = {rect.x, rect.y} * game.window().scale * game.window().dpi
		v.end = ({rect.x, rect.y} + {rect.w, rect.h}) * game.window().scale * game.window().dpi
		v.color = rect.color
		v.left_border_width = rect.left_border_width * game.window().scale.x
		v.right_border_width = rect.right_border_width * game.window().scale.x
		v.top_border_width = rect.top_border_width * game.window().scale.y
		v.bottom_border_width = rect.bottom_border_width * game.window().scale.y
	}

	gl.BufferSubData(
		gl.ARRAY_BUFFER,
		0,
		len(vertices) * size_of(Rect_Vertex),
		raw_data(&vertices),
	)

    // start := vertices[0].pos
    // size := vertices[2].pos - start
    // gl.Viewport(start.x, start.y, size.x, size.y)
	gl.DrawArrays(gl.TRIANGLES, 0, i32(len(vertices)))
}

rect :: proc(using ctx: ^Context, rect: Rect) {
	append(&draw_calls, rect)
}
