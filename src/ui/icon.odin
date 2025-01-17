package ui

import "core:log"
import "core:math/linalg/glsl"

import gl "vendor:OpenGL"
import stbi "vendor:stb/image"

import "../game"

ICON_VERTEX_SHADER :: "resources/shaders/ui/icon.vert"
ICON_FRAGMENT_SHADER :: "resources/shaders/ui/icon.frag"

ICON_QUAD_VERTICES := [?]Icon_Vertex {
	{pos = {-1, -1}, texcoord = {0, 0, 0}, color = {1, 1, 1, 1}},
	{pos = {1, -1}, texcoord = {1, 0, 0}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, texcoord = {1, 1, 0}, color = {1, 1, 1, 1}},
	{pos = {-1, -1}, texcoord = {0, 0, 0}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, texcoord = {1, 1, 0}, color = {1, 1, 1, 1}},
	{pos = {-1, 1}, texcoord = {0, 1, 0}, color = {1, 1, 1, 1}},
}

Icon_Vertex :: struct {
	pos:                 glsl.vec2,
	start:               glsl.vec2,
	end:                 glsl.vec2,
	color:               glsl.vec4,
	texcoord:            glsl.vec3,
	left_border_width:   f32,
	right_border_width:  f32,
	top_border_width:    f32,
	bottom_border_width: f32,
}

Icon_Renderer :: struct {
	vbo, vao:     u32,
	shader:       u32,
	texture_size: glsl.ivec2,
}

Icon :: struct {
	pos:                 glsl.vec2,
	size:                glsl.vec2,
	color:               glsl.vec4,
	texture_array:       u32,
	texture:             int,
	left_border_width:   f32,
	right_border_width:  f32,
	top_border_width:    f32,
	bottom_border_width: f32,
	left_padding:        f32,
	right_padding:       f32,
	top_padding:         f32,
	bottom_padding:      f32,
}

Icon_Draw_Call :: Icon

init_icon_renderer :: proc(using ctx: ^Context) -> (ok: bool = false) {
	using icon_renderer
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

	shader = game.load_shader_program(
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

	gl.EnableVertexAttribArray(5)
	gl.VertexAttribPointer(
		5,
		1,
		gl.FLOAT,
		gl.FALSE,
		size_of(Icon_Vertex),
		offset_of(Icon_Vertex, left_border_width),
	)

	gl.EnableVertexAttribArray(6)
	gl.VertexAttribPointer(
		6,
		1,
		gl.FLOAT,
		gl.FALSE,
		size_of(Icon_Vertex),
		offset_of(Icon_Vertex, right_border_width),
	)

	gl.EnableVertexAttribArray(7)
	gl.VertexAttribPointer(
		7,
		1,
		gl.FLOAT,
		gl.FALSE,
		size_of(Icon_Vertex),
		offset_of(Icon_Vertex, top_border_width),
	)

	gl.EnableVertexAttribArray(8)
	gl.VertexAttribPointer(
		8,
		1,
		gl.FLOAT,
		gl.FALSE,
		size_of(Icon_Vertex),
		offset_of(Icon_Vertex, bottom_border_width),
	)

	return true
}

init_icon_texture_array :: proc(
	texture_array: ^u32,
	textures: []cstring,
	wrap: i32 = gl.REPEAT,
) -> (
	ok: bool = true,
) {
	gl.GenTextures(1, texture_array)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, texture_array^)
	defer gl.BindTexture(gl.TEXTURE_2D_ARRAY, 0)

	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, wrap)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, wrap)

	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	border_color := []f32{0, 0, 0, 0}
	gl.TexParameterfv(
		gl.TEXTURE_2D_ARRAY,
		gl.TEXTURE_BORDER_COLOR,
		raw_data(border_color),
	)

	load_texture_2D_array(textures) or_return

	return
}

icon :: proc(using ctx: ^Context, icon: Icon) {
	append(&draw_calls, icon)
}

draw_icon :: proc(using ctx: ^Context, using icon: Icon) {
	using icon_renderer
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

	vertices[0].texcoord.x -= left_padding / size.x
	vertices[0].texcoord.y -= top_padding / size.y
	vertices[1].texcoord.x += right_padding / size.x
	vertices[1].texcoord.y -= top_padding / size.y
	vertices[2].texcoord.x += right_padding / size.x
	vertices[2].texcoord.y += bottom_padding / size.y
	vertices[3].texcoord = vertices[0].texcoord
	vertices[4].texcoord = vertices[2].texcoord
	vertices[5].texcoord.x -= left_padding / size.x
	vertices[5].texcoord.y += bottom_padding / size.y

	for &v in vertices {
		v.start = pos * game.window().scale
		v.end = (pos + size) * game.window().scale
		v.color = color
		v.texcoord.z = f32(texture)

		v.left_border_width = left_border_width * game.window().scale.x
		v.right_border_width = right_border_width * game.window().scale.x
		v.top_border_width = top_border_width * game.window().scale.y
		v.bottom_border_width = bottom_border_width * game.window().scale.y
	}

	gl.BufferSubData(
		gl.ARRAY_BUFFER,
		0,
		len(vertices) * size_of(Icon_Vertex),
		raw_data(&vertices),
	)
	gl.DrawArrays(gl.TRIANGLES, 0, i32(len(vertices)))
}

load_texture_2D_array :: proc(paths: []cstring) -> (ok: bool = true) {
	textures := i32(len(paths))
	if (textures == 0) {
		log.info("No textures to load.")
		return true
	}

	stbi.set_flip_vertically_on_load(0)
	stbi.set_flip_vertically_on_load_thread(false)

	width, height: i32
	stbi.info(paths[0], &width, &height, nil)

	gl.TexImage3D(
		gl.TEXTURE_2D_ARRAY,
		0,
		gl.RGBA8,
		width,
		height,
		textures,
		0,
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		nil,
	)

	for path, i in paths {
		w, h: i32
		pixels := stbi.load(path, &w, &h, nil, 4)
		defer stbi.image_free(pixels)

		if pixels == nil {
			log.error("Failed to load texture: ", path)
			return false
		}

		if w != width {
			log.error(
				"Texture: ",
				path,
				" is of a different width. expected: ",
				width,
				" got: ",
				w,
			)
			return false
		}

		if h != height {
			log.error(
				"Texture: ",
				path,
				" is of a different height. expected: ",
				height,
				" got: ",
				h,
			)
			return false
		}

		gl.TexSubImage3D(
			gl.TEXTURE_2D_ARRAY,
			0,
			0,
			0,
			i32(i),
			width,
			height,
			1,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			pixels,
		)
	}

	gl.GenerateMipmap(gl.TEXTURE_2D_ARRAY)

	return
}
