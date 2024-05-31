package ui

import "core:log"
import "core:math/linalg/glsl"

import gl "vendor:OpenGL"

import "../camera"
import "../cursor"
import "../mouse"
import "../renderer"

SCROLL_BAR_TEXTURES :: []cstring{"resources/icons/scrollbar_bg.png"}

Scroll_Bar_Texture :: enum (int) {
	Background,
}

Scroll_Bar_Renderer :: struct {
	vbo, vao:      u32,
	shader:        u32,
	texture_size:  glsl.ivec2,
	texture_array: u32,
}

Scroll_Bar :: struct {
	pos:     glsl.vec2,
	size:    glsl.vec2,
	color:   glsl.vec4,
	percent: f32,
	offset:  f32,
}

init_scroll_bar_renderer :: proc(using ctx: ^Context) -> (ok: bool = false) {
	using scroll_bar_renderer
	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)
	defer gl.BindVertexArray(0)

	gl.GenBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(ICON_QUAD_VERTICES) * size_of(Icon_Vertex),
		nil,
		gl.STATIC_DRAW,
	)

	renderer.load_shader_program(
		&shader,
		ICON_VERTEX_SHADER,
		ICON_FRAGMENT_SHADER,
	) or_return
	defer gl.UseProgram(0)

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(
		0,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Icon_Vertex),
		offset_of(Icon_Vertex, pos),
	)

	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(
		1,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Icon_Vertex),
		offset_of(Icon_Vertex, start),
	)

	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(
		2,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Icon_Vertex),
		offset_of(Icon_Vertex, end),
	)

	gl.EnableVertexAttribArray(3)
	gl.VertexAttribPointer(
		3,
		4,
		gl.FLOAT,
		gl.FALSE,
		size_of(Icon_Vertex),
		offset_of(Icon_Vertex, color),
	)

	gl.EnableVertexAttribArray(4)
	gl.VertexAttribPointer(
		4,
		3,
		gl.FLOAT,
		gl.FALSE,
		size_of(Icon_Vertex),
		offset_of(Icon_Vertex, texcoord),
	)

	init_icon_texture_array(&texture_array, SCROLL_BAR_TEXTURES) or_return

	return true
}

scroll_bar :: proc(
	using ctx: ^Context,
	pos: glsl.vec2,
	size: glsl.vec2,
	percent: f32,
	offset: ^f32,
	dragging: ^bool,
	color: glsl.vec4 = ROYAL_BLUE,
) {
	if mouse.is_button_press(.Left) &&
	   cursor.pos.x >= pos.x &&
	   cursor.pos.x < pos.x + size.x &&
	   cursor.pos.y >= pos.y + offset^ &&
	   cursor.pos.y < pos.y + offset^ + size.y * percent {
		dragging^ = true
        mouse.capture(.Left)
	} else if dragging^ && mouse.is_button_release(.Left) {
		dragging^ = false
	} else if mouse.is_button_down(.Left) &&
	   cursor.pos.x >= pos.x &&
	   cursor.pos.x < pos.x + size.x &&
	   cursor.pos.y >= pos.y &&
	   cursor.pos.y < pos.y + size.y {
		offset^ = cursor.pos.y - pos.y
		offset^ = clamp(offset^, 0, size.y * (1 - percent))
		dragging^ = true
        mouse.capture(.Left)
	} 
 //    else if cursor.pos.x >= pos.x &&
	//    cursor.pos.x < pos.x + size.x &&
	//    cursor.pos.y >= pos.y &&
	//    cursor.pos.y < pos.y + size.y {
	// 	offset^ -= (camera.scroll.y / percent) * 4
	// 	offset^ = clamp(offset^, 0, size.y * (1 - percent))
 //        camera.scroll.y = 0
	// }
	//
	if dragging^ && cursor.previous_pos != cursor.pos {
		offset^ += cursor.pos.y - cursor.previous_pos.y
		offset^ = clamp(offset^, 0, size.y * (1 - percent))
		log.info(offset^)
	}

	append(
		&draw_calls,
		Scroll_Bar {
			pos = pos,
			size = size,
			color = color,
			offset = offset^,
			percent = percent,
		},
	)
}

draw_scroll_bar :: proc(using ctx: ^Context, using scroll_bar: Scroll_Bar) {
	using scroll_bar_renderer

	gl.Disable(gl.DEPTH_TEST)
	defer gl.Enable(gl.DEPTH_TEST)

	gl.BindVertexArray(vao)
	defer gl.BindVertexArray(0)

	gl.UseProgram(shader)
	defer gl.UseProgram(0)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, texture_array)
	defer gl.BindTexture(gl.TEXTURE_2D_ARRAY, 0)

	vertices := ICON_QUAD_VERTICES

	vertices[0].pos = to_screen_pos(pos)
	vertices[1].pos = to_screen_pos({pos.x + size.x, pos.y})
	vertices[2].pos = to_screen_pos({pos.x + size.x, pos.y + size.y})
	vertices[3].pos = vertices[0].pos
	vertices[4].pos = vertices[2].pos
	vertices[5].pos = to_screen_pos({pos.x, pos.y + size.y})

	scale := size.y / 32

	for &v in vertices {
		v.start = pos
		v.end = pos + size
		v.color = color
		v.texcoord.z = f32(Scroll_Bar_Texture.Background)
		v.texcoord.y *= scale
	}

	gl.BufferSubData(
		gl.ARRAY_BUFFER,
		0,
		len(vertices) * size_of(Icon_Vertex),
		raw_data(&vertices),
	)

	gl.DrawArrays(gl.TRIANGLES, 0, i32(len(vertices)))

	draw_rect(
		ctx,
		 {
			x = pos.x,
			y = pos.y + offset,
			w = size.x,
			h = size.y * percent,
			color = {0, .251, .502, 1},
		},
	)
}
