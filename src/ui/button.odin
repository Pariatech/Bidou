package ui

import "../game"
import "core:math/linalg/glsl"

Button :: struct {}

button :: proc(
	ctx: ^Context,
	pos: glsl.vec2,
	size: glsl.vec2,
	txt: string,
	color: glsl.vec4 = ROYAL_BLUE,
	txt_size: f32 = 32,
	left_border_width: f32 = BORDER_WIDTH,
	right_border_width: f32 = BORDER_WIDTH,
	top_border_width: f32 = BORDER_WIDTH,
	bottom_border_width: f32 = BORDER_WIDTH,
	padding_top: f32 = 0,
) -> (
	clicked: bool = false,
) {
	rect(
		ctx,
		 {
			x = pos.x,
			y = pos.y,
			w = size.x,
			h = size.y,
			color = color,
			left_border_width = left_border_width,
			right_border_width = right_border_width,
			top_border_width = top_border_width,
			bottom_border_width = bottom_border_width,
		},
	)
	text(
		ctx,
		{pos.x + size.x / 2, pos.y + size.y / 2 + padding_top},
		txt,
		ah = .CENTER,
		av = .MIDDLE,
		clip_start = pos,
		clip_end = pos + size,
		size = txt_size,
	)

	if game.mouse_is_button_press(.Left) {
        cursor := game.get_cursor_context()
		if cursor.pos.x >= pos.x &&
		   cursor.pos.x < pos.x + size.x &&
		   cursor.pos.y >= pos.y &&
		   cursor.pos.y < pos.y + size.y {
			game.mouse_capture(.Left)

			return true
		}
	}

	return
}

icon_button :: proc(
	ctx: ^Context,
	pos: glsl.vec2,
	size: glsl.vec2,
	texture_array: u32,
	texture: int,
	color: glsl.vec4 = ROYAL_BLUE,
	left_border_width: f32 = BORDER_WIDTH,
	right_border_width: f32 = BORDER_WIDTH,
	top_border_width: f32 = BORDER_WIDTH,
	bottom_border_width: f32 = BORDER_WIDTH,
	left_padding: f32 = 0,
	right_padding: f32 = 0,
	top_padding: f32 = 0,
	bottom_padding: f32 = 0,
) -> (
	clicked: bool = false,
) {
	icon(
		ctx,
		 {
			pos = pos,
			size = size,
			color = color,
			texture_array = texture_array,
			texture = texture,
			left_border_width = left_border_width,
			right_border_width = right_border_width,
			top_border_width = top_border_width,
			bottom_border_width = bottom_border_width,
			left_padding = left_padding,
			right_padding = right_padding,
			top_padding = top_padding,
			bottom_padding = bottom_padding,
		},
	)

	if game.mouse_is_button_press(.Left) {
        cursor := game.get_cursor_context()
		if cursor.pos.x >= pos.x &&
		   cursor.pos.x < pos.x + size.x &&
		   cursor.pos.y >= pos.y &&
		   cursor.pos.y < pos.y + size.y {
			game.mouse_capture(.Left)

			return true
		}
	}

	return
}
