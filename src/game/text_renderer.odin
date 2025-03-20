package game

import "core:math/linalg/glsl"
import "core:strings"

import gl "vendor:OpenGL"
import fs "vendor:fontstash"
import mu "vendor:microui"

@(private = "file")
FONT_VERTEX_SHADER :: "resources/shaders/text.vert"
@(private = "file")
FONT_FRAGMENT_SHADER :: "resources/shaders/text.frag"
@(private = "file")
FONT_QUAD_VERTICES := [?]Text_Vertex {
	{pos = {-1, -1}, texcoords = {0, 1}, color = {1, 1, 1, 1}},
	{pos = {1, -1}, texcoords = {1, 1}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, texcoords = {1, 0}, color = {1, 1, 1, 1}},
	{pos = {-1, -1}, texcoords = {0, 1}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, texcoords = {1, 0}, color = {1, 1, 1, 1}},
	{pos = {-1, 1}, texcoords = {0, 0}, color = {1, 1, 1, 1}},
}

Text_Renderer :: struct {
	using fs:     fs.FontContext,
	font_id:      int,
	atlas:        u32,
	shader:       u32,
	default_font: Text_Renderer_Font,
}

@(private = "file")
Text_Vertex :: struct {
	pos:       glsl.vec2,
	texcoords: glsl.vec2,
	color:     glsl.vec4,
}

Text_Renderer_Font :: struct {
	id:   int,
	size: u8,
}

text_renderer :: proc() -> ^Text_Renderer {
	return &game().text_renderer
}

text_renderer_init :: proc() -> bool {
	fs.Init(text_renderer(), 1024, 1024, .TOPLEFT)
	text_renderer().callbackResize = resize_font_atlas
	text_renderer().callbackUpdate = update_font_atlas

	text_renderer().font_id = fs.AddFont(
		text_renderer(),
		"ComicMono",
		"resources/fonts/ComicMono.ttf",
	)

	text_renderer().default_font = {
		id   = text_renderer().font_id,
		size = 32,
	}

	fs.AddFallbackFont(
		text_renderer(),
		text_renderer().font_id,
		fs.AddFont(
			text_renderer(),
			"NotoSans-Regular",
			"resources/fonts/ComicNeue-Bold.otf",
		),
	)
	fs.AddFallbackFont(
		text_renderer(),
		text_renderer().font_id,
		fs.AddFont(
			text_renderer(),
			"NotoColorEmoji",
			"resources/fonts/Symbola_hint.ttf",
		),
	)
	fs.AddFallbackFont(
		text_renderer(),
		text_renderer().font_id,
		fs.AddFont(
			text_renderer(),
			"NotoSansJP-Regular",
			"resources/fonts/NotoSansJP-Regular.ttf",
		),
	)

	create_font_atlas_texture()

	text_renderer().shader = load_shader_program(
		FONT_VERTEX_SHADER,
		FONT_FRAGMENT_SHADER,
	) or_return

	return true
}

text_renderer_text_width :: proc(mu_font: mu.Font, str: string) -> i32 {
	// font := (Text_Renderer_Font)(mu_font)
	// if font == nil {
	// 	font = &text_renderer().default_font
	// }
	// fs.SetFont(text_renderer(), font.id)
	// fs.SetSize(text_renderer(), font.size)
	return i32(fs.TextBounds(text_renderer(), str))
}

text_renderer_text_height :: proc(mu_font: mu.Font) -> i32 {
	// font := (^Text_Renderer_Font)(mu_font)
	// fs.SetFont(text_renderer(), font.id)
	// fs.SetSize(text_renderer(), font.size)
	miny, maxy := fs.LineBounds(text_renderer(), 0)
	return i32(maxy - miny)
}

text_renderer_draw_text :: proc(
	str: string,
	pos: glsl.vec2,
	color: glsl.vec4,
	font: Text_Renderer_Font,
) {

}

@(private = "file")
resize_font_atlas :: proc(data: rawptr, w, h: int) {
	gl.DeleteTextures(1, &text_renderer().atlas)
	create_font_atlas_texture()
}

@(private = "file")
update_font_atlas :: proc(
	data: rawptr,
	dirty_rect: [4]f32,
	texture_data: rawptr,
) {
	defer gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindTexture(gl.TEXTURE_2D, text_renderer().atlas)

	gl.TexSubImage2D(
		gl.TEXTURE_2D,
		0,
		0,
		0,
		i32(text_renderer().width),
		i32(text_renderer().height),
		gl.RED,
		gl.UNSIGNED_BYTE,
		raw_data(text_renderer().textureData),
	)
}

@(private = "file")
create_font_atlas_texture :: proc() {
	gl.GenTextures(1, &text_renderer().atlas)

	defer gl.BindTexture(gl.TEXTURE_2D, 0)
	gl.BindTexture(gl.TEXTURE_2D, text_renderer().atlas)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RED,
		i32(text_renderer().width),
		i32(text_renderer().height),
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		raw_data(text_renderer().textureData),
	)
}
