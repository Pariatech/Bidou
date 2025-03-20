package game

import "core:log"
import "core:math/bits"
import "core:math/linalg/glsl"
import "core:strings"
import "core:testing"

import gl "vendor:OpenGL"
import fs "vendor:fontstash"
import mu "vendor:microui"

@(private = "file")
TEXT_VERTEX_SHADER :: "resources/shaders/text.vert"
@(private = "file")
TEXT_FRAGMENT_SHADER :: "resources/shaders/text.frag"

@(private = "file")
RECT_VERTEX_SHADER :: "resources/shaders/rect.vert"
@(private = "file")
RECT_FRAGMENT_SHADER :: "resources/shaders/rect.frag"

DEFAULT_FONT_SIZE :: 32

@(private = "file")
TEXT_QUAD_VERTICES := [?]Text_Vertex {
	{pos = {1, 1}, texcoords = {1, 0}, color = {1, 1, 1, 1}},
	{pos = {1, -1}, texcoords = {1, 1}, color = {1, 1, 1, 1}},
	{pos = {-1, -1}, texcoords = {0, 1}, color = {1, 1, 1, 1}},
	{pos = {-1, 1}, texcoords = {0, 0}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, texcoords = {1, 0}, color = {1, 1, 1, 1}},
	{pos = {-1, -1}, texcoords = {0, 1}, color = {1, 1, 1, 1}},
}

@(private = "file")
RECT_QUAD_VERTICES := [?]Rect_Vertex {
	{pos = {1, 1}, color = {1, 1, 1, 1}},
	{pos = {1, -1}, color = {1, 1, 1, 1}},
	{pos = {-1, -1}, color = {1, 1, 1, 1}},
	{pos = {-1, 1}, color = {1, 1, 1, 1}},
	{pos = {1, 1}, color = {1, 1, 1, 1}},
	{pos = {-1, -1}, color = {1, 1, 1, 1}},
}

UI :: struct {
	mu_ctx:             mu.Context,
	fs_ctx:             fs.FontContext,
	font_atlas:         u32,
	text_shader:        u32,
	rect_shader:        u32,
	active_atlas:       u32,
	active_shader:      u32,
	text_vao, text_vbo: u32,
	rect_vao, rect_vbo: u32,
}

UI_Font :: struct {
	font: int,
	size: f32,
}

@(private = "file")
Text_Vertex :: struct {
	pos:       glsl.vec2,
	texcoords: glsl.vec2,
	color:     glsl.vec4,
}

@(private = "file")
Rect_Vertex :: struct {
	pos:   glsl.vec2,
	color: glsl.vec4,
}

UI_Icon :: enum u32 {
	None,
	Close,
	Check,
	Collapsed,
	Expanded,
	Resize,
}

ui :: proc() -> ^UI {
	return &game().ui
}

ui_init :: proc() -> bool {
	mu.init(&ui().mu_ctx)
	ui().mu_ctx.text_width = text_width
	ui().mu_ctx.text_height = text_height

	fs.Init(&ui().fs_ctx, 1024, 1024, .TOPLEFT)
	fs.SetColor(&ui().fs_ctx, {255, 255, 255, 255})
	ui().fs_ctx.callbackResize = resize_font_atlas
	ui().fs_ctx.callbackUpdate = update_font_atlas
	// ui().mu_ctx.style.font = transmute(mu.Font)int(12)

	font_id := fs.AddFont(
		&ui().fs_ctx,
		"ComicMono",
		"resources/fonts/ComicMono.ttf",
	)

	fs.AddFallbackFont(
		&ui().fs_ctx,
		font_id,
		fs.AddFont(
			&ui().fs_ctx,
			"NotoSans-Regular",
			"resources/fonts/ComicNeue-Bold.otf",
		),
	)
	fs.AddFallbackFont(
		&ui().fs_ctx,
		font_id,
		fs.AddFont(
			&ui().fs_ctx,
			"NotoColorEmoji",
			"resources/fonts/Symbola_hint.ttf",
		),
	)
	fs.AddFallbackFont(
		&ui().fs_ctx,
		font_id,
		fs.AddFont(
			&ui().fs_ctx,
			"NotoSansJP-Regular",
			"resources/fonts/NotoSansJP-Regular.ttf",
		),
	)

	create_font_atlas_texture()

	ui().text_shader = load_shader_program(
		TEXT_VERTEX_SHADER,
		TEXT_FRAGMENT_SHADER,
	) or_return
	ui().rect_shader = load_shader_program(
		RECT_VERTEX_SHADER,
		RECT_FRAGMENT_SHADER,
	) or_return

	init_text_buffers()
	init_rect_buffers()

	ui().active_atlas = bits.U32_MAX
	ui().active_shader = bits.U32_MAX

	return true
}

ui_deinit :: proc() {
	fs.Destroy(&ui().fs_ctx)
}

ui_update :: proc() {
	// mu.input_mouse_move(&ui().mu_ctx, mouse().buttons)
	cursor_pos := cursor().pos
	// cursor_pos = window().size - cursor_pos
	mu.input_mouse_move(&ui().mu_ctx, i32(cursor_pos.x), i32(cursor_pos.y))

	buttons := mouse().buttons
	for btn, i in buttons {
		#partial switch btn {
		case .Press:
            log.info("Press?")
			mu.input_mouse_down(
				&ui().mu_ctx,
				i32(cursor_pos.x),
				i32(cursor_pos.y),
				mu.Mouse(i),
			)
		case .Up:
			mu.input_mouse_up(
				&ui().mu_ctx,
				i32(cursor_pos.x),
				i32(cursor_pos.y),
				mu.Mouse(i),
			)
		}
	}
}

ui_render :: proc() {
	gl.Disable(gl.CULL_FACE)
	defer gl.Enable(gl.CULL_FACE)

	gl.Enable(gl.BLEND)
	defer gl.Disable(gl.BLEND)
	// gl.BlendEquation(gl.FUNC_REVERSE_SUBTRACT)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	gl.Disable(gl.DEPTH_TEST)
	defer gl.Enable(gl.DEPTH_TEST)

	gl.Enable(gl.SCISSOR_TEST)
	defer gl.Disable(gl.SCISSOR_TEST)

	gl.Scissor(0, 0, i32(window().size.x), i32(window().size.y))

	defer gl.UseProgram(0)
	defer gl.BindTexture(gl.TEXTURE_2D, 0)

	defer ui().active_atlas = bits.U32_MAX
	defer ui().active_shader = bits.U32_MAX


	cmd: ^mu.Command
	for cmd_variant in mu.next_command_iterator(&ui().mu_ctx, &cmd) {
		// log.info(cmd_variant)
		switch c in cmd_variant {
		case ^mu.Command_Jump:
		case ^mu.Command_Clip:
			gl.Scissor(
				c.rect.x,
				i32(window().size.y) - (c.rect.y + c.rect.h),
				c.rect.w,
				c.rect.h,
			)
		case ^mu.Command_Rect:
			draw_rect(c)
		case ^mu.Command_Text:
			draw_text(c)
		case ^mu.Command_Icon:
		}
	}
}

@(deferred_out = scoped_end_window)
ui_window :: proc(title: string, rect: mu.Rect, opt := mu.Options{}) -> bool {
	return mu.begin_window(&ui().mu_ctx, title, rect, opt)
}

@(deferred_out = scoped_end_root)
ui_root :: proc() -> bool {
	mu.begin(&ui().mu_ctx)
	return true
}

ui_text :: proc(text: string) {
	mu.text(&ui().mu_ctx, text)
}

ui_button :: proc(
	label: string,
	icon: UI_Icon = .None,
	opt: mu.Options = {.ALIGN_CENTER},
) -> bool {
	return .SUBMIT in mu.button(&ui().mu_ctx, label, mu.Icon(icon), opt)
}

ui_layout_height :: proc(height: i32) {
	mu.layout_height(&ui().mu_ctx, height)
}

ui_layout_width :: proc(width: i32) {
	mu.layout_width(&ui().mu_ctx, width)
}

@(private = "file")
scoped_end_window :: proc(ok: bool) {
	if ok {
		mu.end_window(&ui().mu_ctx)
	}
}

@(private = "file")
scoped_end_root :: proc(ok: bool) {
	if ok {
		mu.end(&ui().mu_ctx)
	}
}

@(private = "file")
draw_rect :: proc(cmd: ^mu.Command_Rect) {
	bind_shader(ui().rect_shader)

	gl.BindVertexArray(ui().rect_vao)
	defer gl.BindVertexArray(0)

	gl.BindBuffer(gl.ARRAY_BUFFER, ui().rect_vbo)
	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	vertices := RECT_QUAD_VERTICES
	vertices[0].pos = to_screen_pos({f32(cmd.rect.x), f32(cmd.rect.y)})
	vertices[1].pos = to_screen_pos(
		{f32(cmd.rect.x + cmd.rect.w), f32(cmd.rect.y)},
	)
	vertices[2].pos = to_screen_pos(
		{f32(cmd.rect.x + cmd.rect.w), f32(cmd.rect.y + cmd.rect.h)},
	)
	vertices[3] = vertices[0]
	vertices[4] = vertices[2]
	vertices[5].pos = to_screen_pos(
		{f32(cmd.rect.x), f32(cmd.rect.y + cmd.rect.h)},
	)

	for &v in vertices {
		v.color = {
			f32(cmd.color.r) / 255,
			f32(cmd.color.g) / 255,
			f32(cmd.color.b) / 255,
			f32(cmd.color.a) / 255,
		}
	}

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(Rect_Vertex),
		raw_data(&vertices),
		gl.STATIC_DRAW,
	)

	count := i32(len(vertices))
	gl.DrawArrays(gl.TRIANGLES, 0, count)
}

@(private = "file")
init_rect_buffers :: proc() {
	gl.GenVertexArrays(1, &ui().rect_vao)
	gl.BindVertexArray(ui().rect_vao)
	defer gl.BindVertexArray(0)

	gl.GenBuffers(1, &ui().rect_vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, ui().rect_vbo)
	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

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
		4,
		gl.FLOAT,
		gl.FALSE,
		size_of(Rect_Vertex),
		offset_of(Rect_Vertex, color),
	)
}

@(private = "file")
init_text_buffers :: proc() {
	gl.GenVertexArrays(1, &ui().text_vao)
	gl.BindVertexArray(ui().text_vao)
	defer gl.BindVertexArray(0)

	gl.GenBuffers(1, &ui().text_vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, ui().text_vbo)
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
}

@(private = "file")
draw_text :: proc(cmd: ^mu.Command_Text) {
	bind_shader(ui().text_shader)

	fs.BeginState(&ui().fs_ctx)
	defer fs.EndState(&ui().fs_ctx)
	set_font_size_from_microui_font(cmd.font)
	bind_atlas(ui().font_atlas)

	gl.BindVertexArray(ui().text_vao)
	defer gl.BindVertexArray(0)

	gl.BindBuffer(gl.ARRAY_BUFFER, ui().text_vbo)
	defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	lines := strings.split_lines(cmd.str)
	defer delete(lines)

	text_vertices: [dynamic]Text_Vertex
	defer delete(text_vertices)

	// fs.SetFont(&fs, id)
	// fs.SetSize(&fs, size)
	// fs.SetAlignVertical(&fs, av)
	// fs.SetAlignHorizontal(&fs, ah)
	y := f32(cmd.pos.y)
	for line in lines {
		it := fs.TextIterInit(&ui().fs_ctx, f32(cmd.pos.x), y, line)

		miny, maxy := fs.LineBounds(&ui().fs_ctx, y)
		h := maxy - miny
		y = maxy

		quad: fs.Quad
		for fs.TextIterNext(&ui().fs_ctx, &it, &quad) {
			vertices := TEXT_QUAD_VERTICES
			vertices[0].pos = to_screen_pos({quad.x0, quad.y0 + h})
			vertices[0].texcoords = glsl.vec2{quad.s0, quad.t0}
			vertices[1].pos = to_screen_pos({quad.x1, quad.y0 + h})
			vertices[1].texcoords = glsl.vec2{quad.s1, quad.t0}
			vertices[2].pos = to_screen_pos({quad.x1, quad.y1 + h})
			vertices[2].texcoords = glsl.vec2{quad.s1, quad.t1}
			vertices[3] = vertices[0]
			vertices[4] = vertices[2]
			vertices[5].pos = to_screen_pos({quad.x0, quad.y1 + h})
			vertices[5].texcoords = glsl.vec2{quad.s0, quad.t1}
			for &v in vertices {
				v.color = {
					f32(cmd.color.r) / 255,
					f32(cmd.color.g) / 255,
					f32(cmd.color.b) / 255,
					f32(cmd.color.a) / 255,
				}
			}
			append(&text_vertices, ..vertices[:])
		}
	}

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(text_vertices) * size_of(Text_Vertex),
		raw_data(text_vertices),
		gl.STATIC_DRAW,
	)

	count := i32(len(text_vertices))
	gl.DrawArrays(gl.TRIANGLES, 0, count)
}

@(private = "file")
set_font_size_from_microui_font :: proc(mu_font: mu.Font) {
	font_size := transmute(int)mu_font
	if font_size == 0 {
		font_size = DEFAULT_FONT_SIZE
	}
	fs.SetSize(&ui().fs_ctx, f32(font_size))
}

@(private = "file")
text_width :: proc(mu_font: mu.Font, str: string) -> i32 {
	set_font_size_from_microui_font(mu_font)
	return i32(fs.TextBounds(&ui().fs_ctx, str))
}

@(private = "file")
text_height :: proc(mu_font: mu.Font) -> i32 {
	set_font_size_from_microui_font(mu_font)
	miny, maxy := fs.LineBounds(&ui().fs_ctx, 0)
	return i32(maxy - miny)
}

@(private = "file")
resize_font_atlas :: proc(data: rawptr, w, h: int) {
	gl.DeleteTextures(1, &ui().font_atlas)
	create_font_atlas_texture()
}

@(private = "file")
update_font_atlas :: proc(
	data: rawptr,
	dirty_rect: [4]f32,
	texture_data: rawptr,
) {
	gl.BindTexture(gl.TEXTURE_2D, ui().font_atlas)
	defer gl.BindTexture(gl.TEXTURE_2D, 0)

	gl.TexSubImage2D(
		gl.TEXTURE_2D,
		0,
		0,
		0,
		i32(ui().fs_ctx.width),
		i32(ui().fs_ctx.height),
		gl.RED,
		gl.UNSIGNED_BYTE,
		raw_data(ui().fs_ctx.textureData),
	)
}

@(private = "file")
create_font_atlas_texture :: proc() {
	gl.GenTextures(1, &ui().font_atlas)

	gl.BindTexture(gl.TEXTURE_2D, ui().font_atlas)
	defer gl.BindTexture(gl.TEXTURE_2D, 0)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RED,
		i32(ui().fs_ctx.width),
		i32(ui().fs_ctx.height),
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		raw_data(ui().fs_ctx.textureData),
	)
}

@(private = "file")
bind_atlas :: proc(atlas: u32) {
	if ui().active_atlas == atlas {
		return
	}
	ui().active_atlas = atlas
	gl.BindTexture(gl.TEXTURE_2D, atlas)
}

@(private = "file")
bind_shader :: proc(shader: u32) {
	if ui().active_shader == shader {
		return
	}
	ui().active_shader = shader
	gl.UseProgram(shader)
}

@(private = "file")
to_screen_pos :: proc(pos: glsl.vec2) -> glsl.vec2 {
	return ({
				pos.x / window_get_scaled_size().x * 2 - 1,
				-(pos.y / window_get_scaled_size().y * 2 - 1),
			})
}

@(test)
ui_test :: proc(t: ^testing.T) {
	log.info("size_of rawptr", size_of(rawptr))
	log.info("size_of int", size_of(int))
	i: int = 69
	// p: rawptr = transmute(rawptr)i
	p: rawptr = nil
	i2 := transmute(int)p
	log.info(p)
	log.info(i2)
}
