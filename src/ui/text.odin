package ui

import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:strings"

import gl "vendor:OpenGL"
import "vendor:fontstash"

import "../game"

FONT_VERTEX_SHADER :: "resources/shaders/ui/font.vert"
FONT_FRAGMENT_SHADER :: "resources/shaders/ui/font.frag"
FONT :: "resources/fonts/ComicMono.ttf"

FONT_QUAD_VERTICES := [?]Text_Vertex {
	{pos = {-1, -1}, texcoords = {0, 1}, color = {1, 1, 1, 1}},
	{pos = {1, -1}, texcoords = {1, 1}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, texcoords = {1, 0}, color = {1, 1, 1, 1}},
	{pos = {-1, -1}, texcoords = {0, 1}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, texcoords = {1, 0}, color = {1, 1, 1, 1}},
	{pos = {-1, 1}, texcoords = {0, 0}, color = {1, 1, 1, 1}},
}

Text_Renderer :: struct {
	fs:     fontstash.FontContext,
	id:     int,
	atlas:  u32,
	shader: u32,
	draws:  map[Text]Text_Draw,
}

Text_Vertex :: struct {
	pos:        glsl.vec2,
	texcoords:  glsl.vec2,
	color:      glsl.vec4,
	clip_start: glsl.vec2,
	clip_end:   glsl.vec2,
}

Text :: struct {
	position:   glsl.vec2,
	str:        string,
	ah:         fontstash.AlignHorizontal,
	av:         fontstash.AlignVertical,
	size:       f32,
	color:      glsl.vec4,
	clip_start: glsl.vec2,
	clip_end:   glsl.vec2,
}

Text_Draw :: struct {
	vao, vbo: u32,
	count:    i32,
	stale:    bool,
}

Text_Draw_Call :: struct {
	text: Text,
	draw: Text_Draw,
}


font_atlas_resize :: proc(data: rawptr, w, h: int) {
	using ctx := (^Context)(data)

	gl.DeleteTextures(1, &text_renderer.atlas)
	create_font_atlas_texture(ctx)
}

font_atlas_update :: proc(
	data: rawptr,
	dirty_rect: [4]f32,
	texture_data: rawptr,
) {
	using ctx := (^Context)(data)

	defer gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindTexture(gl.TEXTURE_2D, text_renderer.atlas)

	gl.TexSubImage2D(
		gl.TEXTURE_2D,
		0,
		0,
		0,
		i32(text_renderer.fs.width),
		i32(text_renderer.fs.height),
		gl.RED,
		gl.UNSIGNED_BYTE,
		raw_data(text_renderer.fs.textureData),
	)
}

create_font_atlas_texture :: proc(using ctx: ^Context) {
	gl.GenTextures(1, &text_renderer.atlas)

	defer gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindTexture(gl.TEXTURE_2D, text_renderer.atlas)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RED,
		i32(text_renderer.fs.width),
		i32(text_renderer.fs.height),
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		raw_data(text_renderer.fs.textureData),
	)
}

init_text_renderer :: proc(using ctx: ^Context) -> (ok: bool = false) {
	fontstash.Init(&text_renderer.fs, 1024, 1024, .TOPLEFT)
	text_renderer.fs.callbackResize = font_atlas_resize
	text_renderer.fs.callbackUpdate = font_atlas_update
	text_renderer.fs.userData = ctx
	text_renderer.id = fontstash.AddFont(
		&text_renderer.fs,
		"ComicMono",
		"resources/fonts/ComicMono.ttf",
	)
	// font = fontstash.AddFont(&fs, "ComicMono", "resources/fonts/ComicNeue-Regular.otf")
	fontstash.AddFallbackFont(
		&text_renderer.fs,
		text_renderer.id,
		fontstash.AddFont(
			&text_renderer.fs,
			"NotoSans-Regular",
			"resources/fonts/ComicNeue-Bold.otf",
		),
	)
	fontstash.AddFallbackFont(
		&text_renderer.fs,
		text_renderer.id,
		fontstash.AddFont(
			&text_renderer.fs,
			"NotoColorEmoji",
			"resources/fonts/Symbola_hint.ttf",
		),
	)
	fontstash.AddFallbackFont(
		&text_renderer.fs,
		text_renderer.id,
		fontstash.AddFont(
			&text_renderer.fs,
			"NotoSansJP-Regular",
			"resources/fonts/NotoSansJP-Regular.ttf",
		),
	)

	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	defer gl.UseProgram(0)
	defer gl.BindTexture(gl.TEXTURE_2D, 0)


	// gl.GenTextures(1, &font_atlas)
	// gl.ActiveTexture(gl.TEXTURE0)
	// gl.BindTexture(gl.TEXTURE_2D, font_atlas)

	create_font_atlas_texture(ctx)

	text_renderer.shader = game.load_shader_program(
		FONT_VERTEX_SHADER,
		FONT_FRAGMENT_SHADER,
	) or_return


	return true
}

deinit_text_renderer :: proc(using ctx: ^Context) {
	using text_renderer

	fontstash.Destroy(&fs)
}

text_bounds :: proc(
	using ctx: ^Context,
	position: glsl.vec2,
	str: string,
	ah: fontstash.AlignHorizontal = .LEFT,
	av: fontstash.AlignVertical = .BASELINE,
	size: f32 = 32,
) -> (
	min: glsl.vec2,
	max: glsl.vec2,
) {
	using text_renderer

	lines := strings.split_lines(str)
	defer delete(lines)

	min.x = position.x
	min.y = position.y

	max.x = position.x
	max.y = position.y

	fontstash.BeginState(&fs)
	fontstash.SetFont(&fs, id)
	fontstash.SetSize(&fs, size)
	fontstash.SetAlignVertical(&fs, av)
	fontstash.SetAlignHorizontal(&fs, ah)
	y := position.y
	for line in lines {
		it := fontstash.TextIterInit(&fs, position.x, y, line)

		miny, maxy := fontstash.LineBounds(&fs, y)
		y = maxy

		// min.y = miny

		quad: fontstash.Quad
		for fontstash.TextIterNext(&fs, &it, &quad) {
			if quad.x0 < min.x {
				min.x = quad.x0
			}
			if quad.x1 > max.x {
				max.x = quad.x1
			}
			if quad.y0 < min.y {
				min.y = quad.y0
			}
			if quad.y1 > max.y {
				max.y = quad.y1
			}
		}
	}
	fontstash.EndState(&fs)

	return
}

init_text_draw :: proc(using ctx: ^Text_Renderer, using text: Text) {
	draw: Text_Draw

	gl.GenVertexArrays(1, &draw.vao)
	gl.BindVertexArray(draw.vao)
	defer gl.BindVertexArray(0)

	gl.GenBuffers(1, &draw.vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, draw.vbo)
	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(
		0,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Text_Vertex),
		offset_of(Text_Vertex, pos),
	)

	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(
		1,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Text_Vertex),
		offset_of(Text_Vertex, texcoords),
	)

	gl.EnableVertexAttribArray(2)
	gl.VertexAttribPointer(
		2,
		4,
		gl.FLOAT,
		gl.FALSE,
		size_of(Text_Vertex),
		offset_of(Text_Vertex, color),
	)

	gl.EnableVertexAttribArray(3)
	gl.VertexAttribPointer(
		3,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Text_Vertex),
		offset_of(Text_Vertex, clip_start),
	)

	gl.EnableVertexAttribArray(4)
	gl.VertexAttribPointer(
		4,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(Text_Vertex),
		offset_of(Text_Vertex, clip_end),
	)

	lines := strings.split_lines(str)
	defer delete(lines)

	text_vertices: [dynamic]Text_Vertex
	defer delete(text_vertices)

	fontstash.BeginState(&fs)
	fontstash.SetFont(&fs, id)
	fontstash.SetSize(&fs, size)
	fontstash.SetAlignVertical(&fs, av)
	fontstash.SetAlignHorizontal(&fs, ah)
	y := position.y
	for line in lines {
		it := fontstash.TextIterInit(&fs, position.x, y, line)

		miny, maxy := fontstash.LineBounds(&fs, y)
		y = maxy

		quad: fontstash.Quad
		for fontstash.TextIterNext(&fs, &it, &quad) {
			vertices := FONT_QUAD_VERTICES
			vertices[0].pos = to_screen_pos({quad.x0, quad.y0})
			vertices[0].texcoords = glsl.vec2{quad.s0, quad.t0}
			vertices[1].pos = to_screen_pos({quad.x1, quad.y0})
			vertices[1].texcoords = glsl.vec2{quad.s1, quad.t0}
			vertices[2].pos = to_screen_pos({quad.x1, quad.y1})
			vertices[2].texcoords = glsl.vec2{quad.s1, quad.t1}
			vertices[3] = vertices[0]
			vertices[4] = vertices[2]
			vertices[5].pos = to_screen_pos({quad.x0, quad.y1})
			vertices[5].texcoords = glsl.vec2{quad.s0, quad.t1}
			for &v in vertices {
				v.color = color
				v.clip_start = clip_start
				v.clip_end = clip_end
			}
			append(&text_vertices, ..vertices[:])
		}
	}
	fontstash.EndState(&fs)

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(text_vertices) * size_of(Text_Vertex),
		raw_data(text_vertices),
		gl.STATIC_DRAW,
	)

	draw.count = i32(len(text_vertices))
	gl.DrawArrays(gl.TRIANGLES, 0, draw.count)

	draws[text] = draw
}

text :: proc(
	using ctx: ^Context,
	position: glsl.vec2,
	str: string,
	ah: fontstash.AlignHorizontal = .LEFT,
	av: fontstash.AlignVertical = .BASELINE,
	size: f32 = 32,
	color: glsl.vec4 = {1, 1, 1, 1},
	clip_start: glsl.vec2 = {math.F32_MIN, math.F32_MIN},
	clip_end: glsl.vec2 = {math.F32_MAX, math.F32_MAX},
) {
	text := Text {
		position   = position,
		str        = str,
		ah         = ah,
		av         = av,
		size       = size,
		color      = color,
		clip_start = clip_start * game.window().scale,
		clip_end   = clip_end * game.window().scale,
	}

	append(&draw_calls, text)
}

draw_text :: proc(using ctx: ^Context, text: Text) {
	using text_renderer

	gl.Disable(gl.DEPTH_TEST)
	defer gl.Enable(gl.DEPTH_TEST)

	gl.UseProgram(shader)
	defer gl.UseProgram(0)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, atlas)
	defer gl.BindTexture(gl.TEXTURE_2D, 0)

	if draw, ok := &draws[text]; ok {
		draw.stale = false

		gl.BindVertexArray(draw.vao)
		defer gl.BindVertexArray(0)

		gl.BindBuffer(gl.ARRAY_BUFFER, draw.vbo)
		defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

		gl.DrawArrays(gl.TRIANGLES, 0, draw.count)
	} else {
		init_text_draw(&text_renderer, text)
	}
}

update_text_draws :: proc(using ctx: ^Text_Renderer) {
	for k, v in draws {
		if v.stale {
			delete_key(&draws, k)
		} else {
			v := &draws[k]
			v.stale = true
		}
	}
}
